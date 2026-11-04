extends Node
## Measures how fights LOOK: runs bot-vs-bot Draft Duel fights through the
## real battle view at a fixed 60 frames a second and counts the things that
## make combat look sloppy (twitching, flicker, overlaps, sliding feet, hits
## that land before the strike, robotic sync, stuck animals, dragging
## endings). A guide for polishing the feel, not a verdict; it never changes
## the fight. From the repository root:
##   godot --headless --fixed-fps 60 --path game res://tests/feel_report.tscn -- small 3
## (herd size: "small" = 4 a side, "big" = 22 a side; then how many fights).

const SIZE := Vector2(720, 1080)

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
		for i in herd_size:
			herd.append({"id": _pick(), "stars": 1})
		duel.herds[team] = herd
		duel.picks_left[team] = 0
		duel.picks_made[team] = []
	duel.set_ready(0)
	duel.set_ready(1)
	field.sim = duel.sim
	field.snap_camera()
	accumulator = 0.0
	started = now
	last.clear()
	targets.clear()
	still.clear()


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
		"covered_frames": 0, "lockstep_hits": 0, "was_frozen": false,
	}


func _process(delta: float) -> void:
	now += delta
	if duel.phase != "fight":
		_finish_fight()
		return
	if field.is_frozen():
		return
	var tick_length := 1.0 / duel.sim.tps
	accumulator += delta
	var steps := 0
	while accumulator >= tick_length and steps < 10 and duel.phase == "fight":
		_before_step()
		duel.step()
		var events := duel.sim.take_events()
		_check_hits(events)
		field.add_events(events)
		accumulator -= tick_length
		steps += 1
	if duel.phase == "fight":
		field.blend = clampf(accumulator / tick_length, 0.0, 1.0)
	_watch_views(delta)


func _before_step() -> void:
	var alive := 0
	for f in duel.sim.fighters:
		if f.alive and f.is_unit():
			alive += 1
			var old: int = int(targets.get(f.uid, -1))
			var new_uid: int = f.target.uid if f.target != null else -1
			if old != new_uid and old != -1 and new_uid != -1:
				stats.switches += 1
				# Switched away from a target that's still standing.
				for g in duel.sim.fighters:
					if g.uid == old and g.alive:
						stats.switches_alive += 1
						break
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
	if alive <= 4:
		stats.end_seconds += 1.0 / duel.sim.tps


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
		var v := field.view_for_uid(int(e.from))
		if v != null:
			# A readable hit: its attack showed a wind-up before it landed.
			var t: float = field._time
			var shown := t - v.attack_at
			if not v.attacking(t) or shown < v.windup_seconds() * 0.6:
				stats.hits_unread += 1
	if hits > 0:
		stats.ticks_with_hits += 1
		if hits > 1:
			stats.hits_same_tick += hits
		stats.max_hits_tick = maxi(int(stats.max_hits_tick), hits)


func _watch_views(delta: float) -> void:
	stats.frames += 1
	var frozen := field.is_frozen()
	if frozen:
		stats.frozen_frames += 1
		if not stats.was_frozen:
			stats.freezes += 1
	stats.was_frozen = frozen
	stats.number_frames += field.fx.numbers.size()
	var views := field.views()
	var placed := []
	for v in views:
		if v.defeat >= 0.0 or v.fighter == null:
			continue
		stats.unit_frames += 1
		if v.flash > 0.3:
			stats.flash_frames += 1
		if v.hp_ratio < 1.0:
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
				if now - float(info.anim_at) < 0.15:
					stats.anim_blips += 1
				info.anim = anim
				info.anim_at = now
			var vel: Vector2 = v.position - info.pos
			if vel.length() > 0.3 and info.vel.length() > 0.3 and vel.normalized().dot(info.vel.normalized()) < -0.3:
				stats.jitter += 1
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
			info = {"dir": dir, "dir_at": now, "anim": anim, "anim_at": now, "pos": v.position, "vel": Vector2.ZERO}
		last[v.key] = info
		placed.append(v)
	# Animals whose drawn picture is mostly covered by another's (sprites are
	# much bigger than the circles the fight keeps apart).
	for a: UnitView in placed:
		var ha := UnitSprites.top(a.id) * a.body.k
		for b: UnitView in placed:
			if a == b or a.flying != b.flying:
				continue
			var hb := UnitSprites.top(b.id) * b.body.k
			if a.position.distance_to(b.position) < 0.35 * (ha + hb):
				stats.covered_frames += 1
				break
	# Animals drawn on top of each other (the same height: both on the
	# ground, or both flying).
	var s := field.field_scale()
	for i in placed.size():
		for j in range(i + 1, placed.size()):
			var a: UnitView = placed[i]
			var b: UnitView = placed[j]
			if a.flying != b.flying:
				continue
			stats.pair_checks += 1
			var r := (a.fighter.radius + b.fighter.radius) * s
			if a.position.distance_to(b.position) < r * 0.7:
				stats.overlap_pairs += 1


func _finish_fight() -> void:
	stats.fights += 1
	var seconds := float(duel.fight_tick) / duel.sim.tps
	stats.fight_seconds += seconds
	if duel.wiped_at[0] < 0 and duel.wiped_at[1] < 0:
		stats.timeouts += 1
	fights_left -= 1
	if fights_left > 0:
		_next_fight()
		return
	_report()
	get_tree().quit()


func _report() -> void:
	var uf := maxf(1.0, float(stats.unit_frames))
	var secs := uf / 60.0  # animal-seconds watched
	var lines := [
		"Feel report: %d fights, %d a side, %.1f s per fight on average, %d hit the time limit" % [stats.fights, herd_size, stats.fight_seconds / maxf(1, stats.fights), stats.timeouts],
		"  facing changes        %.2f per animal-second; %.0f%% bounce straight back" % [stats.dir_changes / secs, 100.0 * stats.dir_bounces / maxf(1, stats.dir_changes)],
		"  animation changes     %.2f per animal-second; %.0f%% last under 0.15 s (flicker)" % [stats.anim_changes / secs, 100.0 * stats.anim_blips / maxf(1, stats.anim_changes)],
		"  jitter                %.1f%% of animal-frames reverse direction on screen" % [100.0 * stats.jitter / uf],
		"  walking               %.0f%% of frames; %.0f%% of those sideways/backwards (sliding), %.0f%% while in range (pushed)" % [100.0 * stats.walk_frames / uf, 100.0 * stats.strafe_frames / maxf(1, stats.walk_frames), 100.0 * stats.pushed_walk / maxf(1, stats.walk_frames)],
		"  overlaps              %.1f%% of pairs overlap as circles; %.0f%% of animal-frames have their picture mostly covered by another animal" % [100.0 * stats.overlap_pairs / maxf(1, stats.pair_checks), 100.0 * stats.covered_frames / uf],
		"  hit-stop              the whole fight is frozen %.0f%% of the time, %.1f freezes per second" % [100.0 * stats.frozen_frames / maxf(1, stats.frames), stats.freezes / maxf(0.1, stats.frames / 60.0)],
		"  clutter               %.0f%% of animal-frames flashing white, %.1f damage numbers on screen on average, %.0f%% of animal-frames show a health bar" % [100.0 * stats.flash_frames / uf, float(stats.number_frames) / maxf(1, stats.frames), 100.0 * stats.bar_frames / uf],
		"  hits                  %d; %.0f%% land without a visible wind-up; %.0f%% in lockstep with a teammate of the same rhythm (max %d hits in one tick)" % [stats.hits, 100.0 * stats.hits_unread / maxf(1, stats.hits), 100.0 * stats.lockstep_hits / maxf(1, stats.hits), stats.max_hits_tick],
		"  target switches       %.2f per animal-second; %.0f%% leave a target that's still standing" % [stats.switches / secs, 100.0 * stats.switches_alive / maxf(1, stats.switches)],
		"  stuck                 %.1f animal-seconds with a target out of reach and not moving" % [stats.stuck_seconds],
		"  endings               %.1f s per fight with 4 or fewer animals left (%.0f%% of fight time), %.2f hits/s then" % [stats.end_seconds / maxf(1, stats.fights), 100.0 * stats.end_seconds / maxf(0.1, stats.fight_seconds), stats.end_hits / maxf(0.1, stats.end_seconds)],
	]
	for line in lines:
		print(line)
	var out := OS.get_environment("OUT")
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string("\n".join(lines) + "\n")
		f.close()
