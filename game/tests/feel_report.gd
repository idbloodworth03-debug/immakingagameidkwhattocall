extends Node
## Measures how fights LOOK: runs bot-vs-bot Draft Duel fights through the
## real battle view at a fixed 60 frames a second and counts the things that
## make combat look sloppy (twitching, flicker, overlaps, sliding feet, hits
## that land before the strike, robotic sync, stuck animals, dragging
## endings). A guide for polishing the feel, not a verdict; it never changes
## the fight. From the repository root:
##   godot --headless --fixed-fps 60 --path game res://tests/feel_report.tscn -- small 3
## (herd size: "small" = 4 a side, "big" = 22 a side; then how many fights).
## HERD_A=id,id and HERD_B=id,id fight those herds instead of random ones
## ("id*2": two squads of it); OUT=file saves the report.
##
## Idle check: of the time animals spend on the field while the other side
## still has animals, the share spent standing about: not fighting (no
## target in reach, nor in the last half second) and not getting anywhere
## (moved less than a quarter of what it could in the last half second). Animals stunned, still arriving
## or underground don't count. Should be close to zero: everyone fights.
##
## Readability checks (the mosh pit): overlap is the share of animals whose
## body overlaps another's (same height, by more than a fifth of the smaller
## one's radius), every tick; pile-ups the most melee attackers fighting one
## enemy at once (in reach of it), the worst moment and on average over the
## ticks with a fight; spread how the fighting (melee pairs in reach, and
## shots) is shared across the field's three lanes, left, center and right,
## with an evenness score (1 = perfectly even, 0 = all in one lane); how
## much of the fighting is in each animal's own lane, and how often Ranged
## stand in front of their battle line (battle_rules.json "lanes"). Target
## switches (the targeting rules, scripts/battle/targeting.gd): per animal
## per minute, in each third of the fights (steady or bunched?), why (its
## target fell, slipped away, was out of reach, had no way in to it, a
## threat up close, a much closer enemy, its ability's pick), and those by
## choice (away from a target still standing): how many come within two
## seconds of the last and how many go back to one it left within three
## (flip-flopping); and the threat reactions (the "!") per fight.
##
## Army checks (Draft Duel's formations): how far animals are from their
## places while their army marches, how straight each line is, whether the
## whole army's feet are in step, whether the Ranged fire together and their
## shots land together, and when the volleys, the clash and the charge come.

## The field's room on a phone's screen (an iPhone, 390 x 844 points: the
## screen less the margins, the score bar and the action row), and the
## screen's height, for measuring the animals as a share of it.
const SIZE := Vector2(358, 680)
const SCREEN_HEIGHT := 844.0

var field: BattleField
var duel: DraftMatch
var herd_size := 4
var fights_left := 3
var fight_index := 0
var accumulator := 0.0
var now := 0.0
var started := 0.0
var stats := {}
var last := {}      # per view key: {"dir", "dir_at", "anim", "anim_at", "pos", "vel", "since_dir"}
var targets := {}   # per fighter uid: last target uid
var still := {}     # per fighter uid: [time, position] when last seen moving
var trail := {}     # per fighter uid: its positions over the last IDLE_WINDOW ticks
var fought := {}    # per fighter uid: the last tick it had a target in reach
var switched_at := {}  # per fighter uid: the tick it last switched targets
var left_at := {}      # per fighter uid: {target uid it left: tick}
var fight_alive: Array = []     # this fight: animals standing, each tick
var _seen_numbers: Array = []   # last frame's damage numbers
var _seen_sparks: Array = []    # last frame's spark bursts
var fight_switches: Array = []  # this fight: the tick of every switch
## How many ticks back the idle check looks to see if an animal got anywhere.
const IDLE_WINDOW := 10
var rng := RandomNumberGenerator.new()
var weights: Array = []
var pool: Array = []
var total := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1 and args[0] == "big":
		herd_size = 22
	if args.size() >= 2 and args[1].is_valid_int():
		fights_left = maxi(1, args[1].to_int())
	rng.seed = 7 + herd_size
	for id in GameData.card_order:
		if not GameData.is_tool(id):
			pool.append(id)
			total += float(GameData.draft_rules.rarity_weights.get(GameData.cards[id].rarity, 1))
			weights.append(total)
	field = BattleField.new()
	field.size = SIZE
	field.screen_height_override = SCREEN_HEIGHT
	field.log_impacts = true
	add_child(field)
	_reset_stats()
	_next_fight()


func _pick() -> String:
	var roll := rng.randf() * total
	for i in weights.size():
		if roll < float(weights[i]):
			return String(pool[i])
	return String(pool[-1])


func _next_fight() -> void:
	fight_index += 1
	duel = DraftMatch.new(rng.randi())
	for team in 2:
		var herd := []
		var given := OS.get_environment("HERD_A" if team == 0 else "HERD_B")
		for i in herd_size:
			herd.append({"id": _pick(), "stars": 1})
		if given != "":
			herd = []
			for spec in given.split(","):
				var parts := spec.split("*")
				herd.append({"id": parts[0], "stars": 1, "squads": int(parts[1]) if parts.size() > 1 else 1})
		duel.herds[team] = herd
		duel.picks_left[team] = 0
		duel.picks_made[team] = []
	duel.set_ready(0)
	duel.set_ready(1)
	field.sim = duel.sim
	field.snap_camera()
	accumulator = 0.0
	started = now
	_volley_lands.clear()
	_charged = false
	last.clear()
	targets.clear()
	switched_at.clear()
	left_at.clear()
	fight_alive.clear()
	fight_switches.clear()
	still.clear()
	trail.clear()
	fought.clear()


func _reset_stats() -> void:
	stats = {
		"frames": 0, "unit_frames": 0, "fight_seconds": 0.0, "fights": 0,
		"dir_changes": 0, "dir_bounces": 0, "anim_changes": 0, "anim_blips": 0,
		"jitter": 0, "walk_frames": 0, "strafe_frames": 0, "pushed_walk": 0,
		"overlap_pairs": 0, "pair_checks": 0,
		"hits": 0, "hits_unread": 0, "hits_same_tick": 0, "ticks_with_hits": 0, "max_hits_tick": 0,
		"switches": 0, "switches_alive": 0, "stuck_seconds": 0.0,
		"end_seconds": 0.0, "end_hits": 0, "timeouts": 0,
		"frozen_frames": 0, "freezes": 0, "flash_frames": 0, "number_frames": 0, "bar_frames": 0,
		"covered_frames": 0, "covered_by_team": 0, "lockstep_hits": 0, "was_frozen": false, "spread": 0.0,
		"blips": {},
		"impacts": 0, "impacts_unread": 0, "impact_late": 0.0, "impacts_together": 0,
		"march_frames": 0, "march_off": 0.0, "march_close": 0, "line_spread": 0.0, "lines": 0,
		"battle_frames": 0, "battle_off": 0.0, "cuts": 0, "blends": 0,
		"body_frames": 0, "body_overlap_frames": 0, "strike_frames": 0, "strike_overlap_frames": 0,
		"ranged_shots": 0, "volley_shots": 0, "volleys": 0, "volley_land_spread": 0.0,
		"first_volley": 0.0, "clash": 0.0, "charge": 0.0, "with_volley": 0, "with_clash": 0, "with_charge": 0,
		"volley_first": 0, "charge_after_clash": 0,
		"war_ticks": 0, "idle_ticks": 0, "fighting_ticks": 0, "idle_no_target": 0,
		"war_by_class": {}, "idle_by_class": {}, "idle_why": {}, "idle_waiting": 0,
		"unit_ticks": 0, "overlap_units": 0, "pile_max": 0, "pile_sum": 0, "pile_ticks": 0, "pile_over": 0, "ranged_ticks": 0, "ranged_past": 0, "lane_checks": 0, "own_lane": 0,
		"lane_fights": [0, 0, 0], "quick_switches": 0, "alerts": 0,
		"third_switches": [0, 0, 0], "third_ticks": [0, 0, 0], "busy_numbers": 0, "spark_frames": 0, "new_numbers_busy": 0, "new_numbers_calm": 0, "new_sparks": 0, "switch_why": {}, "quick_choice": 0, "back_and_forth": 0, "bnf_why": {},
		"size_sum": 0.0, "size_n": 0, "size_by_id": {}, "size_by_class": {}, "size_n_by_class": {}, "size_over": 0, "zoom_sum": 0.0, "zoom_n": 0, "ppu_max": 0.0,
		"attack_frames": 0, "attack_slide_frames": 0, "air_attack_frames": 0, "air_attack_slide_frames": 0, "design_attack_frames": 0, "design_attack_slide_frames": 0, "attack_dbg": {}, "snap_turns": 0, "pos_snaps": 0, "attacks_started": 0, "attacks_cut": 0, "seen_views": {},
		"anim_time": {}, "walk_slide": 0.0, "walk_slide_n": 0,
	}
	switched_at.clear()
var _volley_lands := {}
var _charged := false


func _process(delta: float) -> void:
	now += delta
	if duel.phase != "fight":
		_finish_fight()
		return
	# Hit-stop: counted here, as the fight holds still.
	var frozen := field.is_frozen()
	stats.frames += 1
	if frozen:
		stats.frozen_frames += 1
		if not stats.was_frozen:
			stats.freezes += 1
	stats.was_frozen = frozen
	if frozen:
		return
	var tick_length := 1.0 / duel.sim.tps
	accumulator += delta
	var steps := 0
	while accumulator >= tick_length and steps < 10 and duel.phase == "fight":
		_before_step()
		duel.step()
		var events := duel.sim.take_events()
		_check_hits(events)
		for e in events:
			if e.type == "alert":
				stats.alerts += 1
		field.add_events(events)
		accumulator -= tick_length
		steps += 1
	if duel.phase == "fight":
		field.blend = clampf(accumulator / tick_length, 0.0, 1.0)
	_watch_views(delta)
	_watch_zoom()
	_watch_army()


func _before_step() -> void:
	var alive := 0
	for f in duel.sim.fighters:
		if f.alive and f.is_unit():
			alive += 1
			var old: int = int(targets.get(f.uid, -1))
			var new_uid: int = f.target.uid if f.target != null else -1
			if old != new_uid and old != -1 and new_uid != -1:
				stats.switches += 1
				fight_switches.append(duel.sim.tick)
				var since_last: int = duel.sim.tick - int(switched_at.get(f.uid, -1000))
				if since_last < 2 * duel.sim.tps:
					stats.quick_switches += 1
				switched_at[f.uid] = duel.sim.tick
				# Switched away from a target that's still standing, and why.
				var why := "fell"
				for g in duel.sim.fighters:
					if g.uid == old and g.alive:
						stats.switches_alive += 1
						why = "slipped away" if not duel.sim.can_target(f, g) else "other"
						if int(f.memory.get("locked", -1)) == duel.sim.tick:
							why = String(f.memory.get("locked_why", "other"))
							if why == "lost":
								why = "out of reach"
						break
				stats.switch_why[why] = int(stats.switch_why.get(why, 0)) + 1
				if why != "fell" and since_last < 2 * duel.sim.tps:
					stats.quick_choice += 1
				# Back and forth: back to one it left within the last 3 s.
				var left: Dictionary = left_at.get(f.uid, {})
				if duel.sim.tick - int(left.get(new_uid, -1000)) < 3 * duel.sim.tps:
					stats.back_and_forth += 1
					var key := "%s %s" % [f.cls, why]
					stats.bnf_why[key] = int(stats.bnf_why.get(key, 0)) + 1
				left[old] = duel.sim.tick
				left_at[f.uid] = left
			targets[f.uid] = new_uid
			# Stuck: has a target out of reach and hasn't moved for a second.
			if f.target != null and not duel.sim.in_range(f, f.target) and f.deploy_ticks <= 0 and f.stun <= 0:
				var p := Vector2(f.x, f.y)
				var seen: Array = still.get(f.uid, [now, p])
				if p.distance_to(seen[1]) > 150.0:
					still[f.uid] = [now, p]
				elif now - float(seen[0]) > 1.0:
					stats.stuck_seconds += 1.0 / duel.sim.tps
				else:
					still[f.uid] = seen
			else:
				still[f.uid] = [now, Vector2(f.x, f.y)]
	fight_alive.append(alive)
	if alive <= 4:
		stats.end_seconds += 1.0 / duel.sim.tps
	_watch_idle()
	_watch_crowding()


## Readability, every tick: overlapping bodies, pile-ups on one enemy, and
## which lanes the fighting is in.
func _watch_crowding() -> void:
	var sim := duel.sim
	var units: Array = sim.fighters.filter(func(f): return f.alive and f.is_unit() and not f.memory.get("burrowing", false))
	var on: Dictionary = {}
	var lane_w := float(sim.width) / 3.0
	for f in units:
		stats.unit_ticks += 1
		for g in units:
			if g == f or g.is_flying() != f.is_flying():
				continue
			var dx: int = g.x - f.x
			var dy: int = g.y - f.y
			var need: int = f.radius + g.radius - mini(f.radius, g.radius) / 5
			if dx * dx + dy * dy < need * need:
				stats.overlap_units += 1
				break
		var lined: bool = sim.army != null and sim.army.has_method("lane_steps") and sim.army.at_war()
		if lined and f.cls == "ranged" and not sim.army.crosses(f) and f.memory.has("slot"):
			# Ranged in front of their lane's battle line.
			var y := int(sim.army.line[clampi(f.x * 3 / maxi(1, sim.width), 0, 2)])
			stats.ranged_ticks += 1
			if y >= 0 and (y - f.y if f.team == 0 else f.y - y) > 0:
				stats.ranged_past += 1
		var t: BattleSim.Fighter = f.target
		if t == null or not t.alive or not sim.in_range(f, t):
			continue
		var lane := clampi(int(float(t.x) / lane_w), 0, 2)
		stats.lane_fights[lane] += 1
		if lined and f.memory.has("slot") and not sim.army.roams(f):
			stats.lane_checks += 1
			if sim.army.lane_steps(sim, f, t) == 0:
				stats.own_lane += 1
		# An attacker: a fighter allowed to strike it (one waiting for a slot
		# isn't, even standing close).
		if f.attack_range < 1500 and (sim.army == null or not sim.army.has_method("has_slot") or sim.army.has_slot(f, t)):
			if not on.has(t):
				on[t] = 0
			on[t] += 1
	if not on.is_empty():
		var most := 0
		var over := false
		for t in on:
			most = maxi(most, int(on[t]))
			over = over or int(on[t]) > _slots_of(t)
		if over:
			stats.pile_over += 1
			if OS.get_environment("PILE_LOG") != "":
				for t in on:
					if int(on[t]) > _slots_of(t):
						var who := []
						for f in units:
							if f.target == t and f.attack_range < 1500 and sim.in_range(f, t):
								who.append("%s slot=%s on=%s k=%s why=%s" % [f.card.id, sim.army.has_slot(f, t), f.memory.get("engage_on", -1) == t.uid, f.memory.get("engage_k", "-"), f.memory.get("locked_why", "-")])
						print("PILE t=%d on %s(%s): %s" % [sim.tick, t.card.id, t.cls, " | ".join(who)])
		stats.pile_max = maxi(stats.pile_max, most)
		stats.pile_sum += most
		stats.pile_ticks += 1


## How many animals stand around a field point (as BattleField.crowd_near:
## read here so older fights can be measured the same way).
func _crowd_near(at: Vector2) -> int:
	var cell := Feel.num("crowd", "busy_cell_tiles", 1.5) * BattleSim.TILE
	var n := 0
	for f in duel.sim.fighters:
		if f.alive and f.is_unit() and absf(f.x - at.x) < cell * 1.5 and absf(f.y - at.y) < cell * 1.5:
			n += 1
	return n


## Hits that landed in busy spots, and how many kept quiet there.
func _noise_line() -> String:
	if not ("noise" in field):
		return "(not in this version)"
	var nz: Dictionary = field.noise
	return "%.0f%% of hits land where at least %d animals stand round; %.0f%% of those are small and keep quiet (no sparks, no new number); strong and big hits and knockouts always show" % [100.0 * int(nz.busy) / maxf(1, int(nz.hits)), Feel.count("crowd", "busy_from_units", 8), 100.0 * int(nz.quieted) / maxf(1, int(nz.busy))]


## How many fighters may attack `t` at once (battle_rules.json
## "engagement"; read here so older fights can be measured the same way).
func _slots_of(t: BattleSim.Fighter) -> int:
	var e: Dictionary = GameData.battle_rules.get("engagement", {"slots": 2, "slots_by_class": {"tank": 3}})
	return int(e.get("slots_by_class", {}).get(t.cls, e.get("slots", 2)))


## The idle check, every tick: is each animal fighting, on its way
## somewhere, or standing about while there are enemies left?
func _watch_idle() -> void:
	var sim := duel.sim
	var standing := [0, 0]
	for f in sim.fighters:
		if f.alive and f.is_unit():
			standing[f.team] += 1
	for f in sim.fighters:
		if not f.alive or not f.is_unit():
			continue
		var path: Array = trail.get(f.uid, [])
		path.append(Vector2i(f.x, f.y))
		if path.size() > IDLE_WINDOW + 1:
			path.pop_front()
		trail[f.uid] = path
		if standing[0] == 0 or standing[1] == 0:
			continue
		if f.deploy_ticks > 0 or f.stun > 0 or f.memory.get("burrowing", false) or BattleStyles.busy(sim, f):
			continue
		stats.war_ticks += 1
		stats.war_by_class[f.cls] = int(stats.war_by_class.get(f.cls, 0)) + 1
		if f.target != null and f.target.alive and sim.in_range(f, f.target):
			stats.fighting_ticks += 1
			fought[f.uid] = sim.tick
			continue
		# Just done with a fight (its target fell, or moved off): it's on to
		# the next, not standing about.
		if path.size() <= IDLE_WINDOW or sim.tick - int(fought.get(f.uid, -1000)) <= IDLE_WINDOW:
			continue
		var moved: float = Vector2(path[-1] - path[0]).length()
		if moved * 4.0 >= float(f.speed * IDLE_WINDOW):
			continue
		stats.idle_ticks += 1
		stats.idle_by_class[f.cls] = int(stats.idle_by_class.get(f.cls, 0)) + 1
		var can_hit := false
		var open_slot := false
		for t in sim.fighters:
			if sim.can_target(f, t) and t.is_unit():
				can_hit = true
				if sim.army == null or not sim.army.has_method("room") or sim.army.room(sim, f, t):
					open_slot = true
					break
		var why := "nothing it can hit"
		if can_hit and not open_slot:
			# Every enemy it could fight has all its engagement slots taken:
			# it waits its turn (the rule, not standing about).
			why = "waiting for a slot"
			stats.idle_waiting += 1
		elif can_hit:
			if sim.army != null and sim.army.has_method("at_war") and not sim.army.at_war():
				why = "before the war"
			elif f.target == null:
				why = "no target picked"
			else:
				why = "on its way, held up"
		else:
			stats.idle_no_target += 1
		stats.idle_why[why] = int(stats.idle_why.get(why, 0)) + 1
		if OS.get_environment("IDLE_LOG") != "":
			var foes := []
			if not can_hit:
				for t in sim.fighters:
					if t.alive and t.team != f.team:
						foes.append("%s%s%s%s" % [t.card.get("id", t.kind), "(fly)" if t.is_flying() else "", "(under)" if t.memory.get("burrowing", false) else "", "(hidden)" if t.stealthed else ""])
			print("idle %s %s t=%d team=%d (%d,%d) target=%s %s" % [why, f.card.id, sim.tick, f.team, f.x, f.y, (f.target.card.get("id", "bait") + " %d,%d" % [f.target.x, f.target.y]) if f.target != null else "-", ",".join(foes)])


func _check_hits(events: Array) -> void:
	var hits := 0
	# Lockstep: two animals of a team with the same rhythm hitting on the
	# same tick (robotic sync).
	var rhythm := {}
	for e in events:
		if e.type == "hit":
			for f in duel.sim.fighters:
				if f.uid == int(e.from):
					var k := "%d/%d" % [f.team, f.hit_ticks]
					rhythm[k] = int(rhythm.get(k, 0)) + 1
	for k in rhythm:
		if int(rhythm[k]) > 1:
			stats.lockstep_hits += int(rhythm[k])
	var army: BattleArmy = duel.sim.army
	var at := float(duel.fight_tick) / duel.sim.tps
	for e in events:
		match e.type:
			"volley":
				if int(e.team) == 0 and army != null and army.volleys[0].size() == 1:
					stats.first_volley += at
					stats.with_volley += 1
			"clash":
				stats.clash += at
				stats.with_clash += 1
				if army != null and (not army.volleys[0].is_empty() or not army.volleys[1].is_empty()):
					stats.volley_first += 1
			"charge":
				if not _charged:
					_charged = true
					stats.charge += at
					stats.with_charge += 1
					if army != null and army.clash_tick >= 0:
						stats.charge_after_clash += 1
		if e.type == "hit" and bool(e.get("ranged", false)):
			for f in duel.sim.fighters:
				if f.uid == int(e.from) and f.cls == "ranged":
					stats.ranged_shots += 1
					if e.has("volley"):
						stats.volley_shots += 1
	for e in events:
		if e.type != "hit":
			continue
		hits += 1
		stats.hits += 1
		var alive := 0
		for f in duel.sim.fighters:
			if f.alive and f.is_unit():
				alive += 1
		if alive <= 4:
			stats.end_hits += 1
	if hits > 0:
		stats.ticks_with_hits += 1
		if hits > 1:
			stats.hits_same_tick += hits
		stats.max_hits_tick = maxi(int(stats.max_hits_tick), hits)


func _watch_views(_delta: float) -> void:
	stats.number_frames += field.fx.numbers.size()
	# Effects in busy spots: numbers and spark bursts drawn where at least
	# busy_from_units animals stand round them.
	var busy_from := Feel.count("crowd", "busy_from_units", 8)
	for n in field.fx.numbers:
		var at := field.screen_to_field(n.at)
		var busy := _crowd_near(at) >= busy_from
		if busy:
			stats.busy_numbers += 1
		# A number that's new this frame (popping up now).
		if not _seen_numbers.any(func(m): return is_same(m, n)):
			stats["new_numbers_busy" if busy else "new_numbers_calm"] += 1
	_seen_numbers = field.fx.numbers.duplicate()
	var sparks: Array = field.fx._sparks.filter(func(sp): return float(sp.until) > field.fx.time)
	stats.spark_frames += sparks.size()
	for sp in field.fx._sparks:
		if not _seen_sparks.any(func(m): return is_same(m, sp)):
			stats.new_sparks += 1
	_seen_sparks = field.fx._sparks.duplicate()
	# Hits as they land on screen: did a wind-up show first, how long after
	# the fight dealt them, and did a teammate's land on the same frame?
	var landed := {}
	for hit in field.impact_log:
		if int(hit.get("volley", -1)) >= 0:
			# A volley's shots, as they land: how far apart.
			var vk := "%d/%d" % [hit.team, hit.volley]
			var span: Array = _volley_lands.get(vk, [hit.time, hit.time])
			_volley_lands[vk] = [minf(span[0], hit.time), maxf(span[1], hit.time)]
		stats.impacts += 1
		if not hit.read:
			stats.impacts_unread += 1
		if String(hit.get("id", "")) != "":
			var tally := _per(String(hit.id))
			tally.hits += 1
			if not hit.read:
				tally.unread += 1
		stats.impact_late += float(hit.late)
		landed[hit.team] = int(landed.get(hit.team, 0)) + 1
	for team in landed:
		if int(landed[team]) > 1:
			stats.impacts_together += int(landed[team])
	field.impact_log.clear()
	var views := field.views()
	var placed := []
	for v in views:
		if v.defeat >= 0.0 or v.fighter == null:
			continue
		stats.unit_frames += 1
		_watch_size(v)
		if v.flash > 0.3:
			stats.flash_frames += 1
		# A health bar showing (hurt, and not yet faded away).
		var shown_for := Feel.num("combat", "health_bar_hide_after", 2.5) + Feel.num("combat", "health_bar_fade_seconds", 0.5)
		if v.hp_ratio < 1.0 and field.now() - v.hurt_time() < shown_for:
			stats.bar_frames += 1
		var key_text: String = v._frame_key
		var anim := key_text.rstrip("0123456789/")
		var cut := key_text.find("/")
		var dir := key_text.substr(cut + 1) if cut >= 0 else ""
		var info: Dictionary = last.get(v.key, {})
		if not info.is_empty():
			if dir != info.dir:
				stats.dir_changes += 1
				# Back to the direction it just left within half a second.
				if dir == info.get("prev_dir", "") and now - float(info.dir_at) < 0.5:
					stats.dir_bounces += 1
				info.prev_dir = info.dir
				info.dir = dir
				info.dir_at = now
			if anim != info.anim:
				stats.anim_changes += 1
				# (Not its first change: standing at the start, then off.)
				if now - float(info.anim_at) < 0.15 and info.has("prev_anim"):
					stats.anim_blips += 1
					var what := "%s>%s>%s" % [info.get("prev_anim", "?"), info.anim, anim]
					stats.blips[what] = int(stats.blips.get(what, 0)) + 1
				info.prev_anim = info.anim
				info.anim = anim
				info.anim_at = now
			var vel: Vector2 = v.position - info.pos
			if vel.length() > 0.3 and info.vel.length() > 0.3 and vel.normalized().dot(info.vel.normalized()) < -0.3:
				stats.jitter += 1
			# Animation quality (Battle, part 2): a body sliding while its
			# attack plays, a turn too sharp to be a turn (a snap), a drawn
			# position that jumps. Measured on the field (tiles), not the
			# screen: the camera moves too.
			var rpos: Vector2 = v.render_pos()
			var fvel: Vector2 = rpos - Vector2(info.get("rpos", rpos))
			info.rpos = rpos
			var tiles_per_s := fvel.length() / 1000.0 * 60.0
			if anim in UnitView.ATTACK_ANIMS:
				# (On the ground; a flier's dive moves its body by design.)
				if v.flying:
					stats.air_attack_frames += 1
					if tiles_per_s > 0.25:
						stats.air_attack_slide_frames += 1
				elif (v.fighter != null and BattleStyles.busy(field.sim, v.fighter)) or v.hop_t < 1.0:
					# A move that carries its body by design (a Seal's
					# belly-slide, a Rhino's charge; a hop to a new place, laid
					# out for the next round or knocked back): counted apart.
					stats.design_attack_frames += 1
					if tiles_per_s > 0.25:
						stats.design_attack_slide_frames += 1
				else:
					stats.attack_frames += 1
					var tally := _per(v.id)
					tally.att += 1
					if tiles_per_s > 0.25:
						stats.attack_slide_frames += 1
						tally.slid += 1
				if OS.get_environment("ATTACK_DEBUG") != "":
					# Who slides while hitting, and why: a flier's dive, a push
					# by a body, a body still walking into place.
					var spos := Vector2i(v.fighter.x, v.fighter.y) if v.fighter != null else Vector2i.ZERO
					var walking: bool = v.fighter != null and v.fighter.walked != v.fighter.prev_walked
					var why := "flying" if v.flying else ("walking" if walking else ("pushed" if spos != Vector2i(info.get("spos", spos)) else "drawn only"))
					info.spos = spos
					var key := "%s %s %s" % [v.id, anim, why]
					var d: Array = stats.attack_dbg.get(key, [0, 0])
					d[0] += 1
					if tiles_per_s > 0.25:
						d[1] += 1
					stats.attack_dbg[key] = d
			var turned := absf(wrapf(v.facing - float(info.get("facing", v.facing)), -180.0, 180.0))
			if turned > 30.0:
				stats.snap_turns += 1
			info.facing = v.facing
			if fvel.length() > 500.0 and v.pop >= 1.0 and v.hop_t >= 1.0:
				stats.pos_snaps += 1
			stats.anim_time[anim] = int(stats.anim_time.get(anim, 0)) + 1
			if anim == "walk" and v.move_dir.length() > 0.0 and tiles_per_s > 0.3:
				# The feet against the ground: how far the walk cycle says it
				# went this frame against how far it was drawn going (while
				# really walking; the last steps of a stop are a held walk).
				var stride: float = v._walk_tiles * v.size_k * Feel.num("movement", "walk_stride_match", 1.0)
				var cycle_rate := float(info.get("walk_v", 0.0))
				if cycle_rate > 0.0:
					stats.walk_slide += absf(cycle_rate * stride - tiles_per_s) / tiles_per_s
					stats.walk_slide_n += 1
					var feet := _per(v.id)
					feet.feet += absf(cycle_rate * stride - tiles_per_s) / tiles_per_s
					feet.feet_n += 1
					if OS.get_environment("WALK_DEBUG") != "":
						var dbg: Array = stats.get_or_add("walk_dbg", {}).get_or_add("%s%s" % [v.id, " march" if v._placed and field.marching(v.fighter.team) else ""], [0.0, 0.0, 0])
						dbg[0] += cycle_rate * stride
						dbg[1] += tiles_per_s
						dbg[2] += 1
						if dbg.size() < 4:
							dbg.append(0.0)
						dbg[3] += v.shown_v.length() / 1000.0
			info.walk_v = wrapf(v.walk - float(info.get("walk", v.walk)), -0.5, 0.5) * 60.0
			info.walk = v.walk
			info.vel = vel
			info.pos = v.position
			if anim == "walk":
				stats.walk_frames += 1
				var heading := Vector2(sin(deg_to_rad(v.facing)), -cos(deg_to_rad(v.facing)))
				if v.move_dir.length() > 0.0 and heading.dot(v.move_dir) < 0.5:
					stats.strafe_frames += 1
				var f: BattleSim.Fighter = v.fighter
				if f.target != null and duel.sim.in_range(f, f.target):
					stats.pushed_walk += 1
		else:
			info = {"dir": dir, "dir_at": now, "anim": anim, "anim_at": now, "pos": v.position, "vel": Vector2.ZERO, "facing": v.facing, "walk": v.walk, "rpos": v.render_pos()}
		last[v.key] = info
		placed.append(v)
		stats.seen_views[v.key] = v
	# Animals whose drawn picture is mostly covered by another's (sprites are
	# much bigger than the circles the fight keeps apart).
	for a: UnitView in placed:
		stats.spread += a.spread.length()
		var ha := UnitSprites.top(a.id) * a.body.k
		var by_enemy := false
		for b: UnitView in placed:
			if a == b or a.flying != b.flying:
				continue
			var hb := UnitSprites.top(b.id) * b.body.k
			if a.position.distance_to(b.position) < 0.35 * (ha + hb):
				if a.team == b.team:
					stats.covered_by_team += 1
					by_enemy = false
					break
				by_enemy = true
		if by_enemy:
			stats.covered_frames += 1
	# Bodies overlapping (the same height: both on the ground, or both
	# flying): their footprints (bodies.json, the fight's radii) where
	# they're drawn, with a strike's lunge on top; any frame with one, and
	# the frames an attacking body overlaps another (what a clipping strike
	# looks like). Bodies going down count too: the living keep clear.
	var bodies: Array = []
	for v: UnitView in field.views():
		if v.fighter == null and v.defeat < 0.0:
			continue
		if v.fighter != null and v.fighter.memory.get("burrowing", false):
			continue
		bodies.append(v)
	var any_overlap := false
	var attack_overlap := {}
	for i in bodies.size():
		var a: UnitView = bodies[i]
		for j in range(i + 1, bodies.size()):
			var b: UnitView = bodies[j]
			if a.flying != b.flying:
				continue
			stats.pair_checks += 1
			if UnitView.bodies_overlap(a, b):
				stats.overlap_pairs += 1
				any_overlap = true
				if OS.get_environment("BODY_DEBUG") != "":
					var why := "other"
					if a.defeat >= 0.0 or b.defeat >= 0.0:
						why = "one dying"
					elif a.flying:
						why = "fliers"
					elif a.fighter.target == b.fighter or b.fighter.target == a.fighter:
						why = "fighter and its target"
					elif a.team == b.team:
						why = "teammates"
					# Do their bodies overlap in the fight too (its spines: three
					# circles along the body, BattleSim.spine), or only as drawn?
					var sim_over := false
					if a.fighter != null and b.fighter != null:
						var fa: BattleSim.Fighter = a.fighter
						var fb: BattleSim.Fighter = b.fighter
						var sa := BattleSim.spine(fa.x, fa.y, fa.half, fa.hw, fa.heading, fa.across)
						var sb := BattleSim.spine(fb.x, fb.y, fb.half, fb.hw, fb.heading, fb.across)
						var seg := Geometry2D.get_closest_points_between_segments(Vector2(sa[0]), Vector2(sa[-1]), Vector2(sb[0]), Vector2(sb[-1]))
						sim_over = seg[0].distance_to(seg[1]) < fa.hw + fb.hw - 0.1 * minf(fa.hw, fb.hw)
					var key := "%s%s" % [why, " (in the fight too)" if sim_over else " (drawn only)"]
					if why == "one dying" and int(stats.get("dying_dumps", 0)) < 24 and stats.frames % 4 == 0:
						stats.dying_dumps = int(stats.get("dying_dumps", 0)) + 1
						var dying: UnitView = a if a.defeat >= 0.0 else b
						var live: UnitView = b if a.defeat >= 0.0 else a
						var live_f: BattleSim.Fighter = live.fighter
						print("  BODY DYING %s %.2f (%s, fighter %s) under %s(%s, target %s, walked %s) drawn %.2f tiles apart (lunge %.2f); rooms %.2f+%.2f, halves %.2f+%.2f, widths %.2f+%.2f" % [dying.id, dying.defeat, dying._defeat_kind, "gone" if dying.fighter == null else ("alive" if dying.fighter.alive else "dead"), live.id, live.m_anim, (live_f.target.card.id if live_f.target != null else "-") if live_f != null else "?", (live_f.walked != live_f.prev_walked) if live_f != null else "?", (a.render_pos() - b.render_pos()).length() / 1000.0, live.m_lunge.length() / 1000.0, dying.body_radius / 1000.0, live.body_radius / 1000.0, dying.body_half / 1000.0, live.body_half / 1000.0, dying.body_half_width / 1000.0, live.body_half_width / 1000.0])
					var tally: Dictionary = stats.get_or_add("body_why", {})
					tally[key] = int(tally.get(key, 0)) + 1
					if (a.defeat < 0.0 and a.attacking(field.now())) or (b.defeat < 0.0 and b.attacking(field.now())):
						var striking: Dictionary = stats.get_or_add("strike_why", {})
						var who := "%s striking %s" % [a.id if a.attacking(field.now()) and a.defeat < 0.0 else b.id, b.id if a.attacking(field.now()) and a.defeat < 0.0 else a.id]
						striking["%s: %s" % [why, who]] = int(striking.get("%s: %s" % [why, who], 0)) + 1
					var pair := "%s/%s" % [a.id, b.id] if a.id <= b.id else "%s/%s" % [b.id, a.id]
					var pairs: Dictionary = stats.get_or_add("body_pairs", {})
					pairs[pair] = int(pairs.get(pair, 0)) + 1
				if a.attacking(field.now()) and a.defeat < 0.0:
					attack_overlap[a] = true
				if b.attacking(field.now()) and b.defeat < 0.0:
					attack_overlap[b] = true
	stats.body_frames += 1
	if any_overlap:
		stats.body_overlap_frames += 1
	if OS.get_environment("BODY_DEBUG") != "":
		# How far the drawn body sits from its place in the fight.
		for v: UnitView in bodies:
			if v.fighter == null:
				continue
			var off: float = v.render_pos().distance_to(Vector2(v.fighter.x, v.fighter.y)) / 1000.0
			var state := "striking" if v.attacking(field.now()) else ("hopping" if v.hop_t < 1.0 else "walking/standing")
			var d: Array = stats.get_or_add("diverge", {}).get_or_add(state, [0.0, 0.0, 0])
			d[0] += off
			d[1] = maxf(d[1], off)
			d[2] += 1
	for v: UnitView in bodies:
		if v.defeat < 0.0 and v.attacking(field.now()):
			stats.strike_frames += 1
			var tally := _per(v.id)
			tally.strike += 1
			if attack_overlap.has(v):
				stats.strike_overlap_frames += 1
				tally.strike_over += 1




## How big the animals are drawn (bodies.json "limits"): each
## one's standing height as a share of the phone screen's height, every
## frame; the average, the biggest Tank, the Mythic hero, and how many
## animal-frames are over their limit; and the camera's zoom.
func _watch_size(v: UnitView) -> void:
	var share := field.unit_height_share(v)
	if share <= 0.0:
		return
	var pct := share * 100.0
	stats.size_sum += pct
	stats.size_n += 1
	var cls := String(v.cls)
	stats.size_by_class[cls] = float(stats.size_by_class.get(cls, 0.0)) + pct
	stats.size_n_by_class[cls] = int(stats.size_n_by_class.get(cls, 0)) + 1
	var hero: bool = v.fighter != null and bool(v.fighter.memory.get("hero", false))
	# Per animal: its average over the fight and its peak (a strike's
	# stretch or a flinch's lean makes its box taller for a moment).
	var tally: Dictionary = stats.size_by_id.get_or_add(v.id, {"sum": 0.0, "n": 0, "max": 0.0, "hero": hero, "cls": cls})
	tally.sum += pct
	tally.n += 1
	if pct > float(tally.max):
		tally.max_why = "%s scale=%.2f,%.2f lift=%.2f lunge=%.2f zoom=%.1f" % [v.m_anim, v.m_scale.x, v.m_scale.y, v.m_altitude, v.m_lunge.length() / 1000.0, field.field_scale() * 1000.0]
	tally.max = maxf(float(tally.max), pct)
	if OS.get_environment("SIZE_DEBUG") != "" and pct > 9.0:
		print("  SIZE OVER %s %.1f%% %s scale=%.2f,%.2f defeat=%.2f" % [v.id, pct, v.m_anim, v.m_scale.x, v.m_scale.y, v.defeat])
	var limits: Dictionary = GameData.bodies.get("limits", {})
	var limit := float(limits.get("hero_max_pct", 10.0)) if hero else float(limits.get("unit_max_pct", 9.0))
	if pct > limit:
		stats.size_over += 1


## The animal of `kind` ("tank": Tanks that aren't heroes; "hero": Mythic
## heroes; "": any) drawn biggest on average, as "8.7% (hippopotamus,
## peaks 10.9%)", or "none".
func _biggest(kind: String) -> String:
	var best := ""
	var best_mean := -1.0
	for id in stats.size_by_id:
		var t: Dictionary = stats.size_by_id[id]
		if kind == "hero" and not t.hero:
			continue
		if kind == "tank" and (t.hero or t.cls != "tank"):
			continue
		var mean := float(t.sum) / maxi(1, int(t.n))
		if mean > best_mean:
			best_mean = mean
			best = id
	if best == "":
		return "none"
	if OS.get_environment("SIZE_DEBUG") != "":
		print("  SIZE PEAK %s: %s" % [best, stats.size_by_id[best].get("max_why", "")])
	return "%.1f%% (%s, peaks %.1f%%)" % [best_mean, best, float(stats.size_by_id[best].max)]


func _watch_zoom() -> void:
	var ppu := field.field_scale() * 1000.0
	stats.zoom_sum += ppu
	stats.zoom_n += 1
	stats.ppu_max = maxf(float(stats.ppu_max), ppu)


## The army checks for this frame: animals in their places while their army
## marches (how far off, lines straight, feet in step) and once the fight
## is on (how far from their places).
func _watch_army() -> void:
	var army: BattleArmy = duel.sim.army
	if army == null:
		return
	var lines := {}
	for v: UnitView in field.views():
		if v.defeat >= 0.0 or v.fighter == null or not v.in_formation() or v.fighter.memory.get("burrowing", false):
			continue
		var f := v.fighter
		var place := army.place_of(f)
		var off := Vector2(f.x - place.x, f.y - place.y).length() / 1000.0
		var fighting := f.target != null and f.target.alive and duel.sim.in_range(f, f.target)
		if field.marching(f.team) and not fighting:
			stats.march_frames += 1
			stats.march_off += off
			if off <= 0.25:
				stats.march_close += 1
			var key := "%d/%s/%d" % [f.team, f.memory.rank, int(f.memory.slot.y)]
			if not lines.has(key):
				lines[key] = []
			lines[key].append(v.render_pos().y)
		elif army.clash_tick >= 0:
			stats.battle_frames += 1
			stats.battle_off += off
	for key in lines:
		var ys: Array = lines[key]
		if ys.size() < 2:
			continue
		var mean := 0.0
		for y in ys:
			mean += float(y)
		mean /= ys.size()
		var dev := 0.0
		for y in ys:
			dev = maxf(dev, absf(float(y) - mean))
		stats.line_spread += dev / 1000.0
		stats.lines += 1


func _finish_fight() -> void:
	stats.fights += 1
	for v in stats.seen_views.values():
		if is_instance_valid(v):
			stats.attacks_started += v.attacks_started
			stats.attacks_cut += v.attacks_cut
	stats.seen_views.clear()
	if field._stage != null:
		stats.cuts += field._stage.cuts
		stats.blends += field._stage.blends
		field._stage.cuts = 0
		field._stage.blends = 0
	for vk in _volley_lands:
		var span: Array = _volley_lands[vk]
		stats.volleys += 1
		stats.volley_land_spread += float(span[1]) - float(span[0])
	var seconds := float(duel.fight_tick) / duel.sim.tps
	stats.fight_seconds += seconds
	# Switching by thirds of the fight (steady, or bunched at one point?).
	var n := maxi(1, fight_alive.size())
	for i in fight_alive.size():
		stats.third_ticks[mini(2, i * 3 / n)] += int(fight_alive[i])
	var first := duel.sim.tick - fight_alive.size()
	for k in fight_switches:
		stats.third_switches[clampi((int(k) - first) * 3 / n, 0, 2)] += 1
	if duel.wiped_at[0] < 0 and duel.wiped_at[1] < 0:
		stats.timeouts += 1
		if OS.get_environment("IDLE_LOG") != "":
			for f in duel.sim.fighters:
				if f.alive and f.is_unit():
					print("TIMEOUT left %s team=%d hp=%d/%d (%d,%d) target=%s burrowing=%s ball=%s engage=%s" % [f.card.id, f.team, f.hp, f.max_hp, f.x, f.y, f.target.card.id if f.target != null else "-", f.memory.get("burrowing", false), f.memory.get("ball", 0), f.memory.get("engage_on", -1)])
	fights_left -= 1
	if fights_left > 0:
		_next_fight()
		return
	_report()
	get_tree().quit()


## Why animals switched targets: its target fell, slipped away (burrowed,
## hid, flew off), was out of its reach, had no way in to it (no_room), a
## threat up close, a much closer enemy, one its ability or class prefers,
## or something else (a charge, a stun...).
func _switch_whys() -> String:
	var parts := []
	var whys: Array = stats.switch_why.keys()
	whys.sort_custom(func(a, b): return int(stats.switch_why[a]) > int(stats.switch_why[b]))
	for why in whys:
		parts.append("%s %.0f%%" % [why, 100.0 * int(stats.switch_why[why]) / maxf(1, stats.switches)])
	return ", ".join(parts)


## The biggest few of a {name: count} tally, as "name count, ...".
func _top(tally: Dictionary, most: int) -> String:
	var keys: Array = tally.keys()
	keys.sort_custom(func(a, b): return int(tally[a]) > int(tally[b]))
	var parts := []
	for k in keys.slice(0, most):
		parts.append("%s %d" % [k, int(tally[k])])
	return ", ".join(parts)


## Target switches per animal per minute in each third of the fights.
func _thirds() -> String:
	var parts := []
	for i in 3:
		var minutes := float(stats.third_ticks[i]) / duel.sim.tps / 60.0
		parts.append("%.1f" % (stats.third_switches[i] / maxf(0.001, minutes)))
	return " / ".join(parts)


func _body_debug() -> void:
	if not stats.has("body_why"):
		return
	print("  BODY overlaps by cause: ", _top(stats.body_why, 12))
	print("  BODY overlaps while striking: ", _top(stats.get("strike_why", {}), 12))
	print("  BODY overlaps by pair: ", _top(stats.body_pairs, 10))
	for state in stats.get("diverge", {}):
		var d: Array = stats.diverge[state]
		print("  BODY drawn vs fight position, %s: %.3f tiles on average, %.2f at most (%d frames)" % [state, d[0] / maxi(1, d[2]), d[1], d[2]])


## One animal's running tally for the PER ANIMAL table.
func _per(id: String) -> Dictionary:
	return stats.get_or_add("per", {}).get_or_add(id, {"frames": 0, "att": 0, "slid": 0, "strike": 0, "strike_over": 0, "feet": 0.0, "feet_n": 0, "hits": 0, "unread": 0})


## Every animal's line: how big it stands (its average and its tallest, and
## its limit), how often its striking body overlaps another, how often it
## slides while hitting on the ground, how far its feet are off the ground
## they cover, and how many of its hits land without a visible wind-up.
func _per_animal() -> String:
	var per: Dictionary = stats.get("per", {})
	if per.is_empty():
		return ""
	var ids: Array = per.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ca := GameData.class_order.find(GameData.class_of(a))
		var cb := GameData.class_order.find(GameData.class_of(b))
		return ca < cb if ca != cb else a < b)
	var limits: Dictionary = GameData.bodies.get("limits", {})
	var lines := ["  PER ANIMAL            %-22s %-15s %13s %9s %9s %8s %9s %7s" % ["", "class", "size (peak)", "limit", "overlap", "slides", "feet off", "unread"]]
	for id: String in ids:
		var t: Dictionary = per[id]
		var size: Dictionary = stats.size_by_id.get(id, {})
		var avg := float(size.get("sum", 0.0)) / maxi(1, int(size.get("n", 0)))
		var hero: bool = bool(size.get("hero", false))
		var limit := float(limits.get("hero_max_pct", 10.0)) if hero else float(limits.get("unit_max_pct", 9.0))
		lines.append("  PER ANIMAL            %-22s %-15s %5.1f%% (%4.1f%%) %8.0f%% %8.1f%% %8.1f%% %8.0f%% %6.0f%%" % [id, GameData.class_of(id), avg, float(size.get("max", 0.0)), limit,
			100.0 * int(t.strike_over) / maxi(1, int(t.strike)), 100.0 * int(t.slid) / maxi(1, int(t.att)),
			100.0 * float(t.feet) / maxi(1, int(t.feet_n)), 100.0 * int(t.unread) / maxi(1, int(t.hits))])
		if OS.get_environment("PER_RAW") != "":
			# (The counts, for adding up several reports.)
			lines.append("  PER RAW %s %d %d %d %d %.3f %d %d %d %.3f %d %.3f %d" % [id, int(t.att), int(t.slid), int(t.strike), int(t.strike_over), float(t.feet), int(t.feet_n), int(t.hits), int(t.unread), float(size.get("sum", 0.0)), int(size.get("n", 0)), float(size.get("max", 0.0)), 1 if hero else 0])
	return "\n".join(lines)


func _attack_debug() -> void:
	var dbg: Dictionary = stats.get("attack_dbg", {})
	var keys: Array = dbg.keys()
	keys.sort_custom(func(a, b): return int(dbg[a][1]) > int(dbg[b][1]))
	for k in keys:
		var d: Array = dbg[k]
		if int(d[1]) > 0:
			print("  ATTACK %-44s slid in %4d of %4d attack frames (%.0f%%)" % [k, d[1], d[0], 100.0 * d[1] / maxi(1, d[0])])


func _walk_debug() -> void:
	var dbg: Dictionary = stats.get("walk_dbg", {})
	for k in dbg:
		var d: Array = dbg[k]
		print("  WALK %-26s feet say %.2f tiles/s, body went %.2f tiles/s, spring speed %.2f (%d frames)" % [k, d[0] / maxi(1, d[2]), d[1] / maxi(1, d[2]), (d[3] if d.size() > 3 else 0.0) / maxi(1, d[2]), d[2]])


func _anim_time() -> String:
	var total := 0
	for n in stats.anim_time.values():
		total += int(n)
	var parts := []
	var keys: Array = stats.anim_time.keys()
	keys.sort_custom(func(a, b): return int(stats.anim_time[a]) > int(stats.anim_time[b]))
	for k in keys:
		parts.append("%s %.0f%%" % [k, 100.0 * int(stats.anim_time[k]) / maxf(1, total)])
	return ", ".join(parts)


func _size_by_class() -> String:
	var parts := []
	for cls in GameData.class_order:
		var n := int(stats.size_n_by_class.get(cls, 0))
		if n > 0:
			parts.append("%s %.1f%%" % [GameData.class_info(cls).get("name", cls), float(stats.size_by_class.get(cls, 0.0)) / n])
	return ", ".join(parts)


func _idle_by_class() -> String:
	var whys := []
	for why in stats.idle_why:
		whys.append("%s %.0f%%" % [why, 100.0 * int(stats.idle_why[why]) / maxf(1, stats.idle_ticks)])
	var parts := []
	for cls in GameData.class_order:
		var war := int(stats.war_by_class.get(cls, 0))
		if war > 0:
			parts.append("%s %.1f%%" % [GameData.class_info(cls).get("name", cls), 100.0 * int(stats.idle_by_class.get(cls, 0)) / war])
	return "why: %s; by class: %s" % [", ".join(whys), ", ".join(parts)]


func _report() -> void:
	_walk_debug()
	_attack_debug()
	_body_debug()
	var uf := maxf(1.0, float(stats.unit_frames))
	var secs := uf / 60.0  # animal-seconds watched
	var lines := [
		"Feel report: %d fights, %d a side, %.1f s per fight on average, %d hit the time limit" % [stats.fights, herd_size, stats.fight_seconds / maxf(1, stats.fights), stats.timeouts],
		"  facing changes        %.2f per animal-second; %.0f%% bounce straight back" % [stats.dir_changes / secs, 100.0 * stats.dir_bounces / maxf(1, stats.dir_changes)],
		"  animation changes     %.2f per animal-second; %.0f%% last under 0.15 s (flicker)" % [stats.anim_changes / secs, 100.0 * stats.anim_blips / maxf(1, stats.anim_changes)],
		"  jitter                %.1f%% of animal-frames reverse direction on screen" % [100.0 * stats.jitter / uf],
		"  walking               %.0f%% of frames; %.0f%% of those sideways/backwards (sliding), %.0f%% while in range (pushed)" % [100.0 * stats.walk_frames / uf, 100.0 * stats.strafe_frames / maxf(1, stats.walk_frames), 100.0 * stats.pushed_walk / maxf(1, stats.walk_frames)],
		"  overlaps              %.1f%% of pairs overlap as bodies (footprints where they're drawn); %.0f%% of animal-frames have their picture mostly covered by a teammate, %.0f%% only by an enemy it's fighting (screen nudge %.2f tiles on average)" % [100.0 * stats.overlap_pairs / maxf(1, stats.pair_checks), 100.0 * stats.covered_by_team / uf, 100.0 * stats.covered_frames / uf, stats.spread / uf / 1000.0],
		"  BODIES                %.2f%% of frames any two bodies overlap; %.2f%% of striking frames the striking body overlaps another (should be near 0)" % [100.0 * stats.body_overlap_frames / maxf(1, stats.body_frames), 100.0 * stats.strike_overlap_frames / maxf(1, stats.strike_frames)],
		"  hit-stop              the whole fight is frozen %.0f%% of the time, %.1f freezes per second" % [100.0 * stats.frozen_frames / maxf(1, stats.frames), stats.freezes / maxf(0.1, stats.frames / 60.0)],
		"  clutter               %.0f%% of animal-frames flashing white, %.1f damage numbers on screen on average (%.1f in busy spots), %.1f spark bursts, %.0f%% of animal-frames show a health bar" % [100.0 * stats.flash_frames / uf, float(stats.number_frames) / maxf(1, stats.frames), float(stats.busy_numbers) / maxf(1, stats.frames), float(stats.spark_frames) / maxf(1, stats.frames), 100.0 * stats.bar_frames / uf],
		"  new effects           %.1f damage numbers a second pop up in busy spots, %.1f elsewhere; %.1f spark bursts a second" % [stats.new_numbers_busy / maxf(0.1, stats.fight_seconds), stats.new_numbers_calm / maxf(0.1, stats.fight_seconds), stats.new_sparks / maxf(0.1, stats.fight_seconds)],
		"  busy spots            %s" % [_noise_line()],
		"  hits                  %d; %.0f%% land on screen without a visible wind-up, %.2f s after the fight deals them on average; %.0f%% land on the same frame as a teammate's (%.0f%% dealt in step with a teammate of the same rhythm, max %d in one tick)" % [stats.hits, 100.0 * stats.impacts_unread / maxf(1, stats.impacts), stats.impact_late / maxf(1, stats.impacts), 100.0 * stats.impacts_together / maxf(1, stats.impacts), 100.0 * stats.lockstep_hits / maxf(1, stats.hits), stats.max_hits_tick],
		"  target switches       %.1f per animal per minute (start / middle / end of the fight: %s); %.0f%% leave a target that's still standing; %.0f%% within 2 s of the last switch (flip-flops); %.1f threat reactions (\"!\") per fight" % [stats.switches / secs * 60.0, _thirds(), 100.0 * stats.switches_alive / maxf(1, stats.switches), 100.0 * stats.quick_switches / maxf(1, stats.switches), float(stats.alerts) / maxf(1, stats.fights)],
		"  why they switched     %s" % [_switch_whys()],
		"  by choice             %.1f switches per animal per minute away from a target still standing; %.1f of those within 2 s of its last switch; %.2f back and forth (back to one it left within 3 s: %s)" % [stats.switches_alive / secs * 60.0, stats.quick_choice / secs * 60.0, stats.back_and_forth / secs * 60.0, _top(stats.bnf_why, 5)],
		"  stuck                 %.1f animal-seconds with a target out of reach and not moving" % [stats.stuck_seconds],
		"  IDLE                  %.1f%% of animal-time while enemies are alive spent standing about with an enemy it could fight (%.1f%% more with nothing it can hit: a ground fighter with only flyers left; %.1f%% more waiting for a slot while every enemy it could fight is full); %.0f%% fighting; %s" % [100.0 * (stats.idle_ticks - stats.idle_no_target - stats.idle_waiting) / maxf(1, stats.war_ticks), 100.0 * stats.idle_no_target / maxf(1, stats.war_ticks), 100.0 * stats.idle_waiting / maxf(1, stats.war_ticks), 100.0 * stats.fighting_ticks / maxf(1, stats.war_ticks), _idle_by_class()],
		"  endings               %.1f s per fight with 4 or fewer animals left (%.0f%% of fight time), %.2f hits/s then" % [stats.end_seconds / maxf(1, stats.fights), 100.0 * stats.end_seconds / maxf(0.1, stats.fight_seconds), stats.end_hits / maxf(0.1, stats.end_seconds)],
		"  SIZE                  share of the phone screen's height (%dx%d, field %dx%d): average animal %.1f%% (target %.0f%%); biggest Tank %s, Mythic hero %s, biggest of all %s; %.1f%% of animal-frames over their limit (%.0f%%, heroes %.0f%%); by class: %s; camera %.1f px a tile on average, %.1f at most" % [
			int(SIZE.x) + 32, int(SCREEN_HEIGHT), int(SIZE.x), int(SIZE.y), stats.size_sum / maxf(1, stats.size_n), float(GameData.bodies.get("limits", {}).get("average_target_pct", 6.0)), _biggest("tank"), _biggest("hero"), _biggest(""),
			100.0 * stats.size_over / maxf(1, stats.size_n), float(GameData.bodies.get("limits", {}).get("unit_max_pct", 9.0)), float(GameData.bodies.get("limits", {}).get("hero_max_pct", 10.0)), _size_by_class(), stats.zoom_sum / maxf(1, stats.zoom_n), stats.ppu_max],
	]
	var windups: Dictionary = GameData.feel.get("acting", {}).get("windup_scale", {})
	var scaled := []
	for cls in windups:
		if not is_equal_approx(float(windups[cls]), 1.0):
			scaled.append("%s x%.2f" % [cls, float(windups[cls])])
	lines.append_array([
		"Animation (part 2)",
		"  hard cuts             %.1f animation changes per animal-minute; %d cut hard, %d cross-faded over %.0f ms (%.0f%% of changes last under 0.15 s)" % [stats.anim_changes / secs * 60.0, stats.cuts, stats.blends, Feel.num("acting", "blend_seconds", 0.0) * 1000.0, 100.0 * stats.anim_blips / maxf(1, stats.anim_changes)],
		"  attacks cut short     %d of %d attacks started over one still playing (%.0f%%)" % [stats.attacks_cut, stats.attacks_started, 100.0 * stats.attacks_cut / maxf(1, stats.attacks_started)],
		"  sliding while hitting %.1f%% of attack frames on the ground the body moves faster than a quarter tile a second (moving by design and counted apart: fliers' dives %.0f%% of theirs, slides, charges and hops %.0f%%)" % [100.0 * stats.attack_slide_frames / maxf(1, stats.attack_frames), 100.0 * stats.air_attack_slide_frames / maxf(1, stats.air_attack_frames), 100.0 * stats.design_attack_slide_frames / maxf(1, stats.design_attack_frames)],
		"  snap turns            %.2f per animal-minute (more than 30 degrees in one frame)" % [stats.snap_turns / secs * 60.0],
		"  position snaps        %.2f per animal-minute (the drawn body jumps more than half a tile in one frame, hops aside)" % [stats.pos_snaps / secs * 60.0],
		"  feet on the ground    walk cycle against the ground covered: %.0f%% off on average" % [100.0 * stats.walk_slide / maxf(1, stats.walk_slide_n)],
		"  speed scaling         wind-ups stretched by class: %s; stall speed-up to x%.1f (choreography)" % [", ".join(scaled) if not scaled.is_empty() else "none", Feel.num("choreography", "stall_max_speed", 1.0)],
		"  time in animations    %s" % [_anim_time()],
	])
	var lanes: Array = stats.lane_fights
	var lane_total := maxf(1.0, float(lanes[0] + lanes[1] + lanes[2]))
	var entropy := 0.0
	for n in lanes:
		var p := float(n) / lane_total
		if p > 0.0:
			entropy -= p * log(p)
	lines.append_array([
		"Readability",
		"  overlap               %.1f%% of animals overlap another one" % [100.0 * stats.overlap_units / maxf(1, stats.unit_ticks)],
		"  pile-ups              at most %d melee attackers on one enemy at once; %.1f on average (the busiest enemy, each tick with a fight); %.1f%% of those ticks have an enemy with more in reach than its slots" % [stats.pile_max, float(stats.pile_sum) / maxf(1, stats.pile_ticks), 100.0 * stats.pile_over / maxf(1, stats.pile_ticks)],
		"  spread                left %.0f%% / center %.0f%% / right %.0f%% of the fighting; evenness %.2f" % [100.0 * lanes[0] / lane_total, 100.0 * lanes[1] / lane_total, 100.0 * lanes[2] / lane_total, entropy / log(3.0)],
		"  lanes and the line    %.0f%% of the fighting (flankers aside) in an animal's own lane; Ranged in front of their battle line %.1f%% of the time" % [100.0 * stats.own_lane / maxf(1, stats.lane_checks), 100.0 * stats.ranged_past / maxf(1, stats.ranged_ticks)],
	])
	lines.append_array([
		"Army checks",
		"  in place on the march %.2f tiles from its place on average; %.0f%% within a quarter tile" % [stats.march_off / maxf(1, stats.march_frames), 100.0 * stats.march_close / maxf(1, stats.march_frames)],
		"  straight lines        %.2f tiles: the furthest any animal is drawn out of its line while marching, on average" % [stats.line_spread / maxf(1, stats.lines)],
		"  holding the line      %.2f tiles from its place on average once the fight is on" % [stats.battle_off / maxf(1, stats.battle_frames)],
		"  volleys               %.0f%% of Ranged shots fired in a volley; %d volleys, each one's shots land within %.2f s of each other on average" % [100.0 * stats.volley_shots / maxf(1, stats.ranged_shots), stats.volleys, stats.volley_land_spread / maxf(1, stats.volleys)],
		"  the sequence          first volley at %.1f s (%d of %d fights), clash at %.1f s (%d), charge at %.1f s (%d); the volley came before the clash in %d, the charge after it in %d" % [stats.first_volley / maxf(1, stats.with_volley), stats.with_volley, stats.fights, stats.clash / maxf(1, stats.with_clash), stats.with_clash, stats.charge / maxf(1, stats.with_charge), stats.with_charge, stats.volley_first, stats.charge_after_clash],
	])
	var blips: Array = stats.blips.keys()
	blips.sort_custom(func(x, y): return int(stats.blips[x]) > int(stats.blips[y]))
	var top := []
	for b in blips.slice(0, 4):
		top.append("%s %d" % [b, stats.blips[b]])
	lines.append("  flicker kinds         " + ", ".join(top))
	var per := _per_animal()
	if per != "":
		lines.append(per)
	for line in lines:
		print(line)
	var out := OS.get_environment("OUT")
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string("\n".join(lines) + "\n")
		f.close()
