class_name BattleArmy
extends RefCounted
## Draft Duel's armies: every animal has a place in its army's formation and
## the army moves and fights as one. Numbers: classes.json "squads" and
## "formation", battle_rules.json "army".
##
## Formation: from the front, the Tank wall (shoulder to shoulder, a second
## line if it's too long), the Tank Destroyer line, Air hovering over the
## middle, then the Ranged ranks (every other line shifted half a place).
## Specialists stand on the flanks of their trait's rank; a Mythic hero
## stands in the middle of its rank. Each place is kept as an offset from
## the army's front line (memory.slot: x across, y back from the front).
##
## The fight, in phases:
##   March: the front line moves at one pace for the whole army; everyone
##     keeps their place (an animal out of place catches up).
##   Volleys: Ranged ranks stop while an enemy is in reach and all fire
##     together on the army's volley clock.
##   Clash: the front lines meet ("clash" event); the front holds while its
##     first rank is fighting.
##   Charge: a moment after the clash, Tank Destroyers leave their line for
##     the enemy Tanks, around the end of their own wall ("charge" event),
##     and go back to their places once no enemy Tanks are left.
##   All-out war: once the lines have clashed (or a front has been held up
##     by a fight for a moment), nobody keeps its place or waits for a fight
##     to come to it. Every animal goes for an enemy anywhere on the field:
##     fighters take a slot round one (see below) and walk around teammates
##     and other enemies in the way, round the flanks if they must; shooters
##     close in until they're in reach and shoot over everyone. (Before it,
##     each animal only goes for what's in front of its own place, within
##     its leash.)
##
## Engagement slots (battle_rules.json "engagement"): only so many fighters
## (reach under shooter_reach) may attack one enemy at once, its class's
## slots (a Tank's are more: it's bigger). Each takes one of the enemy's
## slots, evenly spaced round it on its own side, and stands there, never on
## top of another. An enemy with no free slot is passed over for the next
## closest that has one; only when every enemy is full does a fighter wait
## just outside reach for a slot to come free. Shooters take no slot.
##
## Like the rest of the fight it's whole numbers only, so it plays out the
## same way every time.

const T := BattleSim.TILE

## Each team's front line (y, field units) and the middle of its army (x).
var front := [0, 0]
var center := [0, 0]
## The rank at each team's front (its first rank with anyone in it).
var front_rank := ["", ""]
## How far each rank has dropped back from its place (Ranged stopping to
## shoot while the front marches on): {rank: field units}.
var lag := [{}, {}]
## The fight tick of each team's next volley (-1: nothing in reach yet), and
## whether one is being fired this tick.
var next_volley := [-1, -1]
var volley_now := [false, false]
## Every volley each team has fired: the fight ticks.
var volleys := [[], []]
## When the front lines met (-1: not yet), and whether each team's Tank
## Destroyers have charged.
var clash_tick := -1
var charged := [false, false]
## When each team's ranks close up next (-1: nothing to do).
var repack_at := [-1, -1]
## How far each army has marched in all, and this tick (for the screen: its
## feet keep step with it).
var marched := [0, 0]
var moved_now := [0, 0]
## When the all-out war started (-1: not yet), and since when each team's
## front has been held up by a fight (-1: it isn't).
var war_tick := -1
var hold_since := [-1, -1]
## How many of each team's fighters hold a slot on each enemy: {uid: count}.
var crowd := [{}, {}]
## Every animal on the field by square of a coarse grid (rebuilt each tick),
## to find the ones in the way cheaply.
var _grid := {}

var pace := 0
var catch_up_pct := 170
var engage := 0
var volley_ticks := 40
var first_volley_ticks := 10
var charge_ticks := 16
var charge_pct := 160
var repack_ticks := 12
var lane_pct := 120
var contact := 0
var war_hold := 20
var avoid_look := 1200
var avoid_margin := 150
## Engagement slots: how many fighters may attack an enemy at once (by its
## class), how many degrees apart their spots stand round it, and how far
## outside its reach one waits for a slot.
var slots := 2
var slots_by_class := {}
var slot_turn := 50
var wait_gap := 600
var slot_gap_pct := 85
var formation_gap := 100
var spot_ticks := 3
var detour_ticks := 8
## Reach (field units) from which an animal counts as a shooter: it needs no
## spot of its own next to its target.
var shooter_reach := 1500
## Every animal's bite, as a share of its card's (battle_rules.json
## "army" damage_pct).
var bite_pct := 100
## Lanes and the battle line (battle_rules.json "lanes"): how close to its
## lane an enemy still counts as in it, how much further one in another
## lane counts (a fighter's, a shooter's), how far past the line a fighter
## goes (and how much further one beyond counts), how far behind it Ranged
## stay, how fast it moves, and who roams free of it all.
var lane_slack := 800
var fighter_lane_cost := 50000
var shooter_lane_cost := 3000
var line_reach := 1500
var line_cost := 50000
var ranged_gap := 1200
var line_pace := 75
var flankers := {}
var air_over := true
## Where the battle line is in each lane, left to right (y, field units;
## -1: no line there, one side has nobody on the ground in that lane).
var line := [-1, -1, -1]


func _init(rules: Dictionary = {}, tps := 20) -> void:
	var a: Dictionary = rules.get("army", GameData.battle_rules.get("army", {}))
	pace = roundi(float(a.get("march_pace", 54)) * T / (60.0 * tps))
	catch_up_pct = int(a.get("catch_up_pct", 170))
	engage = roundi(float(a.get("engage", 1.1)) * T)
	volley_ticks = maxi(1, roundi(float(a.get("volley_seconds", 2.0)) * tps))
	first_volley_ticks = maxi(1, roundi(float(a.get("first_volley_seconds", 0.5)) * tps))
	charge_ticks = roundi(float(a.get("charge_after_seconds", 0.8)) * tps)
	charge_pct = int(a.get("charge_speed_pct", 160))
	repack_ticks = maxi(1, roundi(float(a.get("repack_seconds", 0.6)) * tps))
	lane_pct = int(a.get("lane_pct", 120))
	contact = roundi(float(a.get("contact_gap", 1.6)) * T)
	var w: Dictionary = a.get("war", {})
	war_hold = roundi(float(w.get("after_hold_seconds", 1.0)) * tps)
	avoid_look = roundi(float(w.get("look_ahead", 1.2)) * T)
	avoid_margin = roundi(float(w.get("pass_margin", 0.15)) * T)
	var e: Dictionary = rules.get("engagement", GameData.battle_rules.get("engagement", {}))
	slots = maxi(1, int(e.get("slots", 2)))
	slots_by_class = e.get("slots_by_class", {})
	slot_turn = int(e.get("slot_degrees", 50))
	wait_gap = roundi(float(e.get("wait_gap", 0.6)) * T)
	# A fighter stands slot_gap_pct of its reach from its target's body (its
	# strike lands there, with a little to spare); a line gives each body
	# its footprint and formation_gap between.
	slot_gap_pct = int(e.get("slot_gap_pct", 85))
	formation_gap = roundi(float(rules.get("spacing", GameData.battle_rules.get("spacing", {})).get("formation_gap", 0.1)) * T)
	spot_ticks = maxi(1, roundi(float(w.get("spot_seconds", 0.15)) * tps))
	detour_ticks = maxi(1, roundi(float(w.get("detour_seconds", 0.4)) * tps))
	shooter_reach = roundi(float(w.get("shooter_reach", 1.5)) * T)
	bite_pct = int(a.get("damage_pct", 100))
	var l: Dictionary = rules.get("lanes", GameData.battle_rules.get("lanes", {}))
	lane_slack = roundi(float(l.get("slack", 0.8)) * T)
	fighter_lane_cost = roundi(float(l.get("fighter_lane_cost", 50.0)) * T)
	shooter_lane_cost = roundi(float(l.get("shooter_lane_cost", 3.0)) * T)
	line_reach = roundi(float(l.get("line_reach", 1.5)) * T)
	line_cost = roundi(float(l.get("line_cost", 50.0)) * T)
	ranged_gap = roundi(float(l.get("ranged_gap", 1.2)) * T)
	line_pace = maxi(1, roundi(float(l.get("line_pace", 90)) * T / (60.0 * tps)))
	for id in l.get("flankers", []):
		flankers[String(id)] = true
	air_over = bool(l.get("air_flies_over", true))


func copy() -> BattleArmy:
	var twin := BattleArmy.new()
	for prop in get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = get(prop.name)
			twin.set(prop.name, value.duplicate(true) if value is Array or value is Dictionary else value)
	return twin


# --- Squads ----------------------------------------------------------------

## What one card brings to the army: classes.json "squads" for its class (a
## Mythic's own numbers on top), with its rank and whether it's a flanker or
## a hero. Distances in field units.
static func squad_of(card_id: String) -> Dictionary:
	var card := GameData.get_card(card_id)
	var squads: Dictionary = GameData.class_rules.get("squads", {})
	var form: Dictionary = GameData.class_rules.get("formation", {})
	var cls := String(card.get("class", ""))
	var def: Dictionary = squads.get(cls, {}).duplicate()
	var hero := String(card.get("rarity", "")) == "mythic"
	if hero:
		# One big hero with (a share of) a whole squad's health and bite.
		var whole := maxi(1, int(def.get("units", 1)))
		var mythic: Dictionary = squads.get("mythic", {})
		var share := int(mythic.get("share_pct", 100))
		var hp_pct := int(def.get("hp_pct", 100)) * whole * share / 100
		var damage_pct := int(def.get("damage_pct", 100)) * whole * share / 100
		def.merge(mythic, true)
		def.hp_pct = hp_pct
		def.damage_pct = damage_pct
	var rank := String(form.get("rank_of_class", {}).get(cls, ""))
	# A long reach (its card's, or its style's) stands at the very back of
	# its rank, so it shows (classes.json formation back_reach).
	var stats: Dictionary = card.get("stats", {})
	var style: Dictionary = GameData.styles.get(card_id, {})
	var reach := maxf(float(stats.get("range", 0)), float(style.get("range", 0)) if style.has("kind") else 0.0)
	var back := reach >= float(form.get("back_reach", 1000.0))
	var flank := rank == ""
	if flank:
		rank = String(form.get("rank_of_row", {}).get(DraftMatch.row_of(card_id), "td"))
	return {
		"units": maxi(1, int(def.get("units", 1))),
		"hp_pct": int(def.get("hp_pct", 100)),
		"damage_pct": int(def.get("damage_pct", 100)),
		"radius": roundi(float(def.get("radius", 0.45)) * T),
		"spacing": roundi(float(def.get("spacing", 1.0)) * T),
		"line_max": maxi(1, int(def.get("line_max", 8))),
		"leash": roundi(float(def.get("leash", 1.5)) * T),
		"rank": rank, "flank": flank, "hero": hero, "elite": bool(def.get("elite", false)), "back": back,
	}


## Gives one animal of a squad its share of the card's health and bite
## (and its army's bite_pct on top), and its squad's room on the field.
static func apply_share(f: BattleSim.Fighter, squad: Dictionary, bite: int) -> void:
	f.max_hp = maxi(1, f.max_hp * int(squad.hp_pct) / 100)
	f.hp = f.max_hp
	f.damage = maxi(1, f.damage * int(squad.damage_pct) * bite / 10000)
	# (Its room is its body's, bodies.json footprint: BattleSim.unit_radius.)
	f.memory.squad_units = int(squad.units)


## Puts one squad of `card_id` on the field for `team` (all at `x`, `y`
## until layout() gives them places). Each animal gets its share of the
## card's health and bite, its room and leash, and a number for its place
## in the army's order.
func spawn_squad(sim: BattleSim, team: int, card_id: String, order: int) -> Array:
	var squad := squad_of(card_id)
	var made := sim.spawn_units(team, card_id, int(squad.units), 0, 0)
	for i in made.size():
		var f: BattleSim.Fighter = made[i]
		apply_share(f, squad, bite_pct)
		f.memory.rank = squad.rank
		f.memory.flank = squad.flank
		f.memory.hero = squad.hero
		f.memory.back = squad.back
		f.memory.elite = squad.elite
		# Room in the line for its body (its class's spacing, or its footprint
		# and a gap, battle_rules.json spacing formation_gap, if that's more).
		f.memory.spacing = maxi(int(squad.spacing), 2 * BattleSim.side_room(f) + formation_gap)
		f.memory.line_max = int(squad.line_max)
		f.memory.leash = int(squad.leash)
		f.memory.order = order * 16 + i
		f.memory.slot = Vector2i.ZERO
		if f.memory.get("burrowing", false):
			# Burrowers line up with everyone and dig in when the march starts.
			f.memory.burrowing = false
			f.memory.dig_in = true
	return made


# --- Formation -------------------------------------------------------------

## Places for a list of animals ({rank, flank, hero, back, radius,
## spacing, line_max, group, lane}, in army order; `back`: in a line of its
## own behind the rest of its rank; `group`: its squad; `lane`: a lane it
## already has, kept), with the field `lane_w` wide a lane: {"slots":
## [Vector2i(x across, y back from the front line)], "lanes": [-1 left, 0
## center, 1 right, as the army sees it], "depth": the back line, "width": from the leftmost to
## the rightmost, "block": the widest any lane's lines get, "front": the
## first rank}, in field units. `side_first`: the side lane taken first on
## a tie (-1 left, 1 right; as the army sees it).
##
## Lanes (battle_rules.json "lanes"): each rank's squads are spread over the
## three lanes, the center one first, then the emptier side (so an army
## with one squad of a class keeps one column in the middle, and a big one
## lines up in three), each lane with its own lines of that rank (at most
## as many as fit in the lane) at the rank's depth. A Mythic hero stands in
## the middle of the center lane's first line, a flanker at the outer end
## of its lane's first line, a long reach in a line of its own at the back.
static func plan(units: Array, lane_w: int = BattleSim.WIDTH / 3, side_first := -1) -> Dictionary:
	var form: Dictionary = GameData.class_rules.get("formation", {})
	var rank_gap := roundi(float(form.get("rank_gap", 0.45)) * T)
	var line_gap := roundi(float(form.get("line_gap", 0.3)) * T)
	var margin := roundi(float(form.get("lane_margin", 0.6)) * T)
	var stagger: Array = form.get("stagger", [])
	var over: Dictionary = form.get("over", {})
	var over_offset := roundi(float(form.get("over_offset", 0.35)) * T)
	# Each rank's squads, in army order.
	var squads_of := {}
	var squad_at := {}
	for i in units.size():
		var u: Dictionary = units[i]
		var rank := String(u.rank)
		var key := "%s/%s" % [rank, u.get("group", "u%d" % i)]
		if not squad_at.has(key):
			var squad := {"members": [], "hero": bool(u.hero), "flank": bool(u.flank), "lane": u.get("lane")}
			squad_at[key] = squad
			(squads_of.get_or_add(rank, []) as Array).append(squad)
		squad_at[key].members.append(i)
	var slots := []
	slots.resize(units.size())
	var lanes := []
	lanes.resize(units.size())
	var lane_load := {-1: 0, 0: 0, 1: 0}
	var depth := 0
	var left := 1 << 30
	var right := -(1 << 30)
	var block := 0
	var first := ""
	var last_radius := -1
	var rank_depth := {}
	for rank in form.get("ranks", ["wall", "td", "air", "ranged"]):
		if not squads_of.has(rank):
			continue
		var squads: Array = squads_of[rank]
		var radius := 0
		for sq in squads:
			for i in sq.members:
				radius = maxi(radius, int(units[i].radius))
		# A rank drawn over another (Air over the Tank Destroyers) takes no
		# room of its own: it hovers just behind that rank's first line.
		var hover := String(over.get(rank, ""))
		var saved_depth := depth
		var hovering := hover != "" and rank_depth.has(hover)
		if hovering:
			depth = int(rank_depth[hover]) + over_offset
		elif last_radius >= 0:
			depth += last_radius + radius + rank_gap
		if first == "":
			first = rank
		if not hovering:
			last_radius = radius
		var rank_front := depth
		rank_depth[rank] = depth
		# Its squads over the lanes: the emptiest for this rank, the middle
		# first, then the side with fewer animals so far.
		var rank_load := {-1: 0, 0: 0, 1: 0}
		# The rank's own squads take their lanes first; Specialists on its
		# flanks join after (a Fox listed first doesn't push the Tank off
		# the middle).
		var in_order: Array = squads.filter(func(sq): return not sq.flank) + squads.filter(func(sq): return sq.flank)
		for sq in in_order:
			var lane := 0
			if sq.lane != null:
				lane = int(sq.lane)
			elif not sq.hero:
				var best := 1 << 60
				for l in [0, side_first, -side_first]:
					var key: int = int(rank_load[l]) * 1000000 + (0 if l == 0 else 100000) + int(lane_load[l])
					if key < best:
						best = key
						lane = l
			sq.lane = lane
			rank_load[lane] += sq.members.size()
			lane_load[lane] += sq.members.size()
			for i in sq.members:
				lanes[i] = lane
		var rank_lines := 1
		for lane in [-1, 0, 1]:
			var heroes := []
			var main := []
			var flank := []
			var back := []
			for sq in squads:
				if int(sq.lane) != lane:
					continue
				for i in sq.members:
					if units[i].hero:
						heroes.append(i)
					elif units[i].flank:
						flank.append(i)
					elif units[i].get("back", false):
						back.append(i)
					else:
						main.append(i)
			if heroes.is_empty() and main.is_empty() and flank.is_empty() and back.is_empty():
				continue
			# Lines of at most line_max (and as many as fit in the lane), the
			# heroes in the middle of the first; the long reaches behind.
			var line_max := 1 << 20
			for i in main + back + flank:
				var fit := maxi(1, (lane_w - 2 * margin) / maxi(1, int(units[i].spacing)))
				line_max = mini(int(units[i].line_max), fit)
				break
			# The first line: the heroes in the middle, the others either side
			# of them (right, left, right...), flankers at the outer ends (a
			# side lane's own outer end; in the middle lane, the shorter side).
			var room := maxi(1, line_max - heroes.size() - flank.size())
			var firsts: Array = main.slice(0, room)
			var to_left := []
			var to_right := []
			for k in firsts.size():
				if k % 2 == 0:
					to_right.append(firsts[k])
				else:
					to_left.push_front(firsts[k])
			for i in flank:
				if lane == -1 or (lane == 0 and to_left.size() < to_right.size()):
					to_left.push_front(i)
				else:
					to_right.append(i)
			var lines := [to_left + heroes + to_right]
			var at := firsts.size()
			while at < main.size():
				lines.append(main.slice(at, at + line_max))
				at += line_max
			at = 0
			while at < back.size():
				lines.append(back.slice(at, at + line_max))
				at += line_max
			var middle: int = int(lane) * lane_w
			for li in lines.size():
				var line: Array = lines[li]
				var y := rank_front + li * (2 * radius + line_gap)
				var total := 0
				for i in line:
					total += int(units[i].spacing)
				var x: int = middle - total / 2
				if li == 0 and not heroes.is_empty():
					# Centered on the heroes.
					x = middle
					for i in to_left:
						x -= int(units[i].spacing)
					for i in heroes:
						x -= int(units[i].spacing) / 2
				if stagger.has(rank) and li % 2 == 1 and not line.is_empty():
					x += int(units[line[0]].spacing) / 2
				for i in line:
					var w := int(units[i].spacing)
					slots[i] = Vector2i(x + w / 2, y)
					x += w
				block = maxi(block, total)
			rank_lines = maxi(rank_lines, lines.size())
		for i in units.size():
			if slots[i] != null and String(units[i].rank) == rank:
				left = mini(left, int(slots[i].x) - int(units[i].spacing) / 2)
				right = maxi(right, int(slots[i].x) + int(units[i].spacing) / 2)
		depth = rank_front + (rank_lines - 1) * (2 * radius + line_gap)
		if hovering:
			depth = saved_depth
	return {"slots": slots, "lanes": lanes, "depth": depth, "width": maxi(0, right - left), "block": block, "front": first}


## The room one of `card_id`'s animals takes in a line, as spawn_squad()
## gives it on the field: {"radius": its footprint's, "spacing": its class's,
## or its body's and battle_rules.json spacing formation_gap if that's more}.
static func body_room(card_id: String) -> Dictionary:
	var card := GameData.get_card(card_id)
	var squad := squad_of(card_id)
	var flying := bool(GameData.class_info(String(card.get("class", ""))).get("flying", false))
	var across := flying or bool(GameData.bodies.get("animals", {}).get(card_id, {}).get("across", false))
	var radius := BattleSim.unit_radius(card)
	var side := BattleSim.unit_half(card) if across else radius
	var gap := roundi(float(GameData.battle_rules.get("spacing", {}).get("formation_gap", 0.1)) * T)
	return {"radius": radius, "spacing": maxi(int(squad.spacing), 2 * side + gap)}


## The animals a herd brings ({id, stars, squads} entries), in army order,
## as plan() wants them (with the room their bodies take, as on the field).
static func herd_units(herd: Array) -> Array:
	var units := []
	var group := 0
	for entry in herd:
		var squad := squad_of(String(entry.id))
		squad.merge(body_room(String(entry.id)), true)
		for s in maxi(1, int(entry.get("squads", 1))):
			group += 1
			var one := squad.duplicate()
			one.group = group
			for i in int(squad.units):
				units.append(one)
	return units


## The field's smallest size (draft_rules.json "field" width_tiles and
## height_tiles), in field units.
static func base_size(field: Dictionary) -> Vector2i:
	var w := float(field.get("width_tiles", float(BattleSim.WIDTH) / T))
	var h := float(field.get("height_tiles", float(BattleSim.HEIGHT) / T))
	return Vector2i(roundi(w * T), roundi(h * T))


## How much bigger than its smallest size (base_size) the field must be for
## both armies to line up (start_gap from the middle, `edge` from the back).
static func field_scale_for(herds: Array, field: Dictionary) -> float:
	var a: Dictionary = GameData.battle_rules.get("army", {})
	var base := base_size(field)
	var need := 1.0
	for herd in herds:
		var units := herd_units(herd)
		if units.is_empty():
			continue
		var p := plan(units, base.x / 3)
		var biggest := 0
		for u in units:
			biggest = maxi(biggest, int(u.radius))
		var deep := float(a.get("start_gap", 3.2)) * T + int(p.depth) + biggest + float(a.get("edge", 0.8)) * T
		# Every lane's lines fit in a third of the field.
		var form: Dictionary = GameData.class_rules.get("formation", {})
		var wide := int(p.block) + 2 * roundi(float(form.get("lane_margin", 0.6)) * T)
		need = maxf(need, maxf(deep / (base.y / 2.0), float(wide) / (base.x / 3.0)))
	return minf(ceilf(need * 20.0) / 20.0, float(field.get("max_scale", 1.5)))


## Where each army starts: its front line start_gap tiles from the middle,
## in the middle of the field.
func set_up(sim: BattleSim) -> void:
	var gap := roundi(float(GameData.battle_rules.get("army", {}).get("start_gap", 3.2)) * T)
	front = [sim.middle + gap, sim.middle - gap]
	center = [sim.width / 2, sim.width / 2]


## Gives `team`'s animals their places (the ones still standing in the
## formation, in army order), so the ranks close up after losses. With
## `snap`, they're put there at once (lining up before a fight).
func layout(sim: BattleSim, team: int, snap := false) -> void:
	var members: Array = sim.units(team).filter(func(f): return f.memory.has("slot") and not f.memory.get("free", false))
	members.sort_custom(func(a, b): return int(a.memory.order) < int(b.memory.order))
	var side := 1 if team == 0 else -1
	var units := members.map(func(f): return {"rank": f.memory.rank, "flank": f.memory.flank, "hero": f.memory.hero,
		"back": f.memory.get("back", false), "radius": f.radius, "spacing": f.memory.spacing, "line_max": f.memory.line_max,
		"group": int(f.memory.get("group", f.uid)), "lane": (int(f.memory.lane) * side) if f.memory.has("lane") else null})
	# Lanes are the field's (left is the left of the screen for both armies;
	# the far army faces the other way), so each fills the same side first.
	var p := plan(units, sim.width / 3, -side)
	front_rank[team] = p.front
	for i in members.size():
		var f: BattleSim.Fighter = members[i]
		f.memory.slot = p.slots[i]
		# A squad keeps its lane the whole fight.
		f.memory.lane = int(p.lanes[i]) * side
		if snap:
			var at := place_of(f)
			f.x = clampi(at.x, f.radius, sim.width - f.radius)
			f.y = clampi(at.y, f.radius, sim.height - f.radius)
			f.prev_x = f.x
			f.prev_y = f.y


## Where an animal's place is on the field right now (`lagging`: as far back
## as its rank has dropped while shooting).
func place_of(f: BattleSim.Fighter, lagging := true) -> Vector2i:
	var slot: Vector2i = f.memory.get("slot", Vector2i.ZERO)
	var back := 1 if f.team == 0 else -1
	var behind := slot.y + (int(lag[f.team].get(f.memory.get("rank", ""), 0)) if lagging else 0)
	return Vector2i(center[f.team] + slot.x * back, front[f.team] + behind * back)


# --- Every tick --------------------------------------------------------------

## The army's moves for this tick, before any animal acts: the ranks close
## up, the front marches or holds, Ranged ranks stop to shoot or catch up,
## the volley clock, the clash and the charge.
func before_tick(sim: BattleSim) -> void:
	var by_team := [[], []]
	_grid = {}
	crowd = [{}, {}]
	var holders := {}
	for f: BattleSim.Fighter in sim.fighters:
		if f.alive and f.is_unit() and f.memory.has("slot"):
			by_team[f.team].append(f)
		if f.alive and f.is_unit() and not f.memory.get("burrowing", false):
			var key := _cell(f.x, f.y, f.is_flying())
			if not _grid.has(key):
				_grid[key] = []
			_grid[key].append(f)
		# Who holds which slots: a slot goes with its target.
		var on := int(f.memory.get("engage_on", -1))
		if on >= 0:
			if not f.alive or f.target == null or not f.target.alive or f.target.uid != on:
				f.memory.engage_on = -1
			else:
				(holders.get_or_add(f.target, []) as Array).append(f)
	for t: BattleSim.Fighter in holders:
		var on: Array = holders[t]
		var cap := cap_of(t)
		if on.size() > cap:
			# More than fit (a style put one there): the first to come keep
			# theirs.
			on.sort_custom(func(a: BattleSim.Fighter, b: BattleSim.Fighter) -> bool:
				return int(a.memory.engage_at) < int(b.memory.engage_at) or (int(a.memory.engage_at) == int(b.memory.engage_at) and a.uid < b.uid))
			for k in range(cap, on.size()):
				on[k].memory.engage_on = -1
		crowd[on[0].team][t.uid] = mini(cap, on.size())
	for team in 2:
		if repack_at[team] >= 0 and sim.tick >= repack_at[team]:
			repack_at[team] = -1
			layout(sim, team)
	var holding := [false, false]
	for team in 2:
		var shooting := false
		for f: BattleSim.Fighter in by_team[team]:
			if f.memory.get("free", false) or f.memory.get("charging", false):
				continue
			var fighting := f.target != null and f.target.alive and sim.in_range(f, f.target)
			if f.memory.rank == front_rank[team]:
				var near := _nearest_enemy(sim, f)
				if fighting or (near != null and BattleSim.gap(f, near) <= engage):
					holding[team] = true
					if clash_tick < 0 and near != null and near.memory.get("rank", "") == front_rank[1 - team] and BattleSim.gap(f, near) <= engage:
						clash_tick = sim.tick
						sim.events.append({"type": "clash", "x": (f.x + near.x) / 2, "y": (f.y + near.y) / 2})
			if f.cls == "ranged" and fighting:
				shooting = true
		# March: the front moves up at one pace unless it's holding, and
		# never past the enemy's front line (the lines meet, they don't pass
		# through each other). Ranks that are shooting stay where they are;
		# the others catch up.
		var dir := -1 if team == 0 else 1
		var moved := 0 if holding[team] or by_team[team].is_empty() else pace
		if moved > 0 and not by_team[1 - team].is_empty():
			var room: int = (int(front[team]) - int(front[1 - team])) * -dir - contact
			moved = clampi(room, 0, moved)
			if room <= 0:
				# The fronts have met, even if their animals are in other
				# lanes and nobody's in reach yet: that holds it up too (so
				# the war starts after_hold_seconds on).
				holding[team] = true
		front[team] = clampi(front[team] + moved * dir, 0, sim.height)
		marched[team] += moved
		moved_now[team] = moved
		for rank in ["ranged"]:
			var lagging := int(lag[team].get(rank, 0))
			if shooting and rank != front_rank[team]:
				lagging += moved
			else:
				lagging = maxi(0, lagging - pace * (catch_up_pct - 100) / 100)
			lag[team][rank] = lagging
		# The volley clock.
		volley_now[team] = false
		if next_volley[team] < 0 and shooting:
			next_volley[team] = sim.tick + first_volley_ticks
		elif next_volley[team] >= 0 and sim.tick >= next_volley[team]:
			volley_now[team] = true
			next_volley[team] = sim.tick + volley_ticks if shooting else -1
		if volley_now[team]:
			volleys[team].append(sim.tick)
			var x := 0
			var y := 0
			var count := 0
			for f: BattleSim.Fighter in by_team[team]:
				if f.cls == "ranged" and f.target != null and f.target.alive and sim.in_range(f, f.target):
					x += f.x
					y += f.y
					count += 1
			if count > 0:
				sim.events.append({"type": "volley", "team": team, "count": count, "x": x / count, "y": y / count})
	# All-out war: from the clash, or once a front has been held up by a
	# fight for a moment (whatever met it first).
	if war_tick < 0:
		for team in 2:
			if not holding[team]:
				hold_since[team] = -1
			elif hold_since[team] < 0:
				hold_since[team] = sim.tick
			if clash_tick >= 0 or (hold_since[team] >= 0 and sim.tick >= hold_since[team] + war_hold):
				war_tick = sim.tick
	if at_war():
		_move_line(sim)
	# The charge, a moment after the clash: Tank Destroyers go for the enemy
	# Tanks (and back to their line once there are none).
	for team in 2:
		var enemy_tanks := false
		for f: BattleSim.Fighter in by_team[1 - team]:
			if f.cls == "tank":
				enemy_tanks = true
				break
		if not charged[team] and clash_tick >= 0 and sim.tick >= clash_tick + charge_ticks and enemy_tanks:
			charged[team] = true
			var x := 0
			var y := 0
			var count := 0
			for f: BattleSim.Fighter in by_team[team]:
				if f.cls == "tank_destroyer" and not f.memory.get("free", false):
					f.memory.charging = true
					f.target = null
					x += f.x
					y += f.y
					count += 1
			if count > 0:
				sim.events.append({"type": "charge", "team": team, "count": count, "x": x / count, "y": y / count})
		if charged[team] and not enemy_tanks:
			for f: BattleSim.Fighter in by_team[team]:
				if f.memory.get("charging", false):
					f.memory.charging = false
					f.target = null


## One animal's move in formation (called instead of the plain "go for the
## nearest enemy").
func update_unit(sim: BattleSim, f: BattleSim.Fighter) -> void:
	if f.memory.get("dig_in", false):
		# A burrower dives as the march starts and fights on its own after.
		f.memory.dig_in = false
		f.memory.burrowing = true
		f.memory.free = true
		repack_at[f.team] = sim.tick
		return
	var place := place_of(f)
	var charging := bool(f.memory.get("charging", false))
	var free := bool(f.memory.get("free", false)) or charging
	var war := at_war()
	var leash := int(f.memory.leash)
	_choose_target(sim, f, place, leash, free or war, charging)
	var t := f.target
	if not war and f.cls == "ranged" and (t == null or not sim.in_range(f, t)):
		# Its rank stopped to shoot, but nothing's in its reach yet: it
		# keeps on with the army.
		place = place_of(f, false)
	var waiting := t != null and not has_slot(f, t)
	sim.note_swing(f, t != null and sim.in_range(f, t) and not waiting)
	if t != null and sim.in_range(f, t) and not waiting:
		if f.cls == "ranged" and not free and not BattleStyles.own_rhythm(f):
			# Ranged fire together, on the volley clock; each shot carries
			# the damage of the time since the last.
			if volley_now[f.team]:
				var first := sim.events.size()
				sim.attack(f, t, 100 * volley_ticks / maxi(1, f.hit_ticks))
				# Every shot of it (a Squirrel's pinecones too) is part of the
				# volley.
				for k in range(first, sim.events.size()):
					if sim.events[k].type == "hit" and int(sim.events[k].from) == f.uid:
						sim.events[k].volley = sim.tick
			f.cooldown = maxi(0, next_volley[f.team] - sim.tick) * 100 if next_volley[f.team] >= 0 else f.cooldown
		elif f.cooldown <= 0:
			sim.attack(f, t)
			f.cooldown = f.hit_ticks * 100
		return
	if t != null and sim.mid_swing(f):
		return  # mid-swing: it stands still for its strike (charging too)
	if t != null:
		var goal := Vector2i(t.x, t.y)
		var speed := sim.current_speed(f)
		if waiting:
			# Every enemy's slots are taken: it waits just outside reach for
			# one to come free.
			goal = _wait_spot(sim, f, t)
		elif (free or war) and f.attack_range < shooter_reach and t.is_unit():
			# A fighter heads for its slot next to its target (the nearest
			# open spot to it); with no way in, it picks an enemy with room.
			var spot := _spot(sim, f, t)
			if spot == NO_ROOM:
				f.memory.full = t.uid
				f.memory.full_until = sim.tick + sim.targeting.commit_ticks
				var other := _find(sim, f, place, leash, true, charging)
				_take(sim, f, other)
				Targeting.lock(sim, f, other, "no_room")
				f.target = other
				if other == null:
					return
				t = other
				goal = Vector2i(t.x, t.y)
				if sim.in_range(f, t) and has_slot(f, t):
					return
			else:
				goal = spot
		elif f.attack_range < shooter_reach and t.is_unit():
			# Before the war: toward its slot, as far as its leash lets it.
			goal = _slot_spot(f, t)
		elif (free or war) and t.is_unit() and not crosses(f):
			# A shooter closes in, but stays behind the battle line (when it
			# can hit its target from there).
			var at_line := int(line[lane_at(sim, goal.x) + 1])
			if at_line >= 0 and past_line(sim, f.team, t) + ranged_gap <= f.attack_range + BattleSim.reach_to(f, t):
				goal.y = maxi(goal.y, at_line + ranged_gap) if f.team == 0 else mini(goal.y, at_line - ranged_gap)
		if charging:
			speed = speed * charge_pct / 100
			goal = _around_own_wall(sim, f, goal)
		elif not (free or war):
			goal = _within(goal, place, leash)
		if free or war:
			_go(sim, f, goal, speed)
		else:
			sim.move_toward_point(f, goal, speed)
		return
	if war:
		# Nothing it can hit (only flyers left for a ground fighter): it
		# stays in the fight all the same, under the nearest enemy.
		var near := _nearest_any_enemy(sim, f)
		if near != null and BattleSim.edge_distance(f, near) > T:
			_go(sim, f, Vector2i(near.x, near.y), sim.current_speed(f))
			return
	# Nothing to fight: to its place, in step with the army (once its swing
	# is done).
	if sim.mid_swing(f):
		return
	var step := maxi(sim.current_speed(f), pace * catch_up_pct / 100)
	sim.move_toward_point(f, place, step)


## Whether the all-out war is on: everyone fights, nobody keeps its place.
func at_war() -> bool:
	return war_tick >= 0


## An animal fell: its army's ranks close up in a moment.
func fell(sim: BattleSim, f: BattleSim.Fighter) -> void:
	if f.memory.has("slot") and repack_at[f.team] < 0:
		repack_at[f.team] = sim.tick + repack_ticks


# --- Targets -----------------------------------------------------------------

## Who `f` fights, by the targeting rules (targeting.gd): it keeps its
## target while it's still good (one it can attack and, before the war,
## reach without leaving its leash; for a fighter, one it holds a slot on
## or can take one; for a charging Tank Destroyer, a Tank, unless every
## enemy Tank is full), and finds one with _find: food bait close by first;
## when charging, the nearest enemy Tank; otherwise what's in front of its
## own place within its leash (enemies off to the side count as further
## away), the class it goes after or its ability's pick first, and for a
## fighter, one with a free slot.
func _choose_target(sim: BattleSim, f: BattleSim.Fighter, place: Vector2i, leash: int, free: bool, charging: bool) -> void:
	var t := f.target
	var turn := (sim.tick + f.uid) % sim.targeting.recheck_ticks == 0
	if t == null and not charging and not turn:
		# Nothing to fight: it looks around now and then (animals take
		# turns), which keeps big armies cheap on phones. One whose target
		# has just fallen looks at once.
		return
	if t != null and t.alive and not has_slot(f, t):
		# Waiting for a slot: it takes one as soon as one's free, and looks
		# for another enemy with room only now and then.
		if room(sim, f, t):
			_take(sim, f, t)
		elif not turn:
			return
	var ok := t != null and sim.can_target(f, t) and (free or _reachable(f, t, place, leash)) and room(sim, f, t) \
			and not (charging and t.cls != "tank" and _free_tank(sim, f))
	var find := func() -> BattleSim.Fighter: return _find(sim, f, place, leash, free, charging)
	var reach := -1 if at_war() and not charging else 1 << 30
	var has_room := func(e: BattleSim.Fighter) -> bool: return room(sim, f, e)
	var found := sim.targeting.decide(sim, f, ok, find, sim.prefers_of(f, "tank" if charging else "", reach), has_room)
	if found != t:
		_take(sim, f, found)
		f.target = found


## How many fighters may attack `t` at once: its class's slots
## (battle_rules.json "engagement").
func cap_of(t: BattleSim.Fighter) -> int:
	return int(slots_by_class.get(t.cls, slots))


## Whether `f` may attack `t` now: a shooter always, a fighter only from a
## slot of its own.
func has_slot(f: BattleSim.Fighter, t: BattleSim.Fighter) -> bool:
	return f.attack_range >= shooter_reach or not t.is_unit() or int(f.memory.get("engage_on", -1)) == t.uid


## Whether `f` could go for `t`: a shooter always; a fighter if it holds one
## of `t`'s slots or one is free (and `t` didn't turn out to have no way in
## to it a moment ago).
func room(sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter) -> bool:
	if t == null or has_slot(f, t):
		return true
	if int(f.memory.get("full", -1)) == t.uid and sim.tick < int(f.memory.get("full_until", 0)):
		return false
	return int(crowd[f.team].get(t.uid, 0)) < cap_of(t)


## `f` now goes for `t`: it lets go of its old slot and, a fighter, takes
## the free slot of `t`'s nearest to it (if none is free, it waits).
func _take(sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter) -> void:
	var on := int(f.memory.get("engage_on", -1))
	if on >= 0:
		crowd[f.team][on] = maxi(0, int(crowd[f.team].get(on, 0)) - 1)
		f.memory.engage_on = -1
	if t == null or f.attack_range >= shooter_reach or not t.is_unit():
		return
	var cap := cap_of(t)
	if int(crowd[f.team].get(t.uid, 0)) >= cap:
		return
	crowd[f.team][t.uid] = int(crowd[f.team].get(t.uid, 0)) + 1
	var used := {}
	for o: BattleSim.Fighter in sim.fighters:
		if o != f and o.team == f.team and int(o.memory.get("engage_on", -1)) == t.uid:
			used[int(o.memory.get("engage_k", 0))] = true
	var best := 0
	var best_d := 1 << 60
	for k in cap:
		if used.has(k):
			continue
		var dir := _slot_dir(f.team, k, cap, BattleSim.side_room(f), _ring(f, t))
		var dx := t.x + dir.x - f.x
		var dy := t.y + dir.y - f.y
		if dx * dx + dy * dy < best_d:
			best = k
			best_d = dx * dx + dy * dy
	f.memory.engage_on = t.uid
	f.memory.engage_at = sim.tick
	f.memory.engage_k = best


## The way (thousandths of a tile) from an enemy to slot `k` of its `cap`
## for `team`'s fighters: spread evenly, slot_degrees apart (or as far
## apart as `body` radii on a ring of `ring` need to stand clear of each
## other, if that's more: big bodies round a small target), facing their
## own side of the field.
func _slot_dir(team: int, k: int, cap: int, body := 0, ring := 0) -> Vector2i:
	var turn := float(slot_turn)
	if body > 0 and ring > 0:
		turn = maxf(turn, rad_to_deg(2.0 * asin(minf(0.99, float(body) / float(ring)))))
	var degrees := float((k * 2 - (cap - 1)) * turn) / 2.0
	var toward := 1000 if team == 0 else -1000
	var a := deg_to_rad(degrees)
	return Vector2i(-roundi(toward * sin(a)), roundi(toward * cos(a)))


## Where `f` stands to fight `t` from its slot (no check for room: before
## the war, held back by its leash anyway).
func _slot_spot(f: BattleSim.Fighter, t: BattleSim.Fighter) -> Vector2i:
	var ring := _ring(f, t)
	var dir := _slot_dir(f.team, int(f.memory.get("engage_k", 0)), cap_of(t), BattleSim.side_room(f), ring)
	return Vector2i(t.x + dir.x * ring / 1000, t.y + dir.y * ring / 1000)


## How far from `t`'s middle `f` stands to strike it: the two half bodies,
## nose to nose, and slot_gap_pct of its reach between (where its strike
## lands).
func _ring(f: BattleSim.Fighter, t: BattleSim.Fighter) -> int:
	return t.nose + f.nose + f.attack_range * slot_gap_pct / 100


## Where `f` waits for a slot on `t` to come free: just outside its reach,
## on its side of `t`.
func _wait_spot(sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter) -> Vector2i:
	var dx := f.x - t.x
	var dy := f.y - t.y
	var d := BattleSim.isqrt(dx * dx + dy * dy)
	if d == 0:
		dx = 0
		dy = 1000 if f.team == 0 else -1000
		d = 1000
	var ring := t.nose + f.nose + f.attack_range + wait_gap
	return Vector2i(clampi(t.x + dx * ring / d, f.radius, sim.width - f.radius), clampi(t.y + dy * ring / d, f.radius, sim.height - f.radius))


## Whether any enemy Tank in `f`'s lane has a slot free for it (a charging
## Tank Destroyer settles for another enemy only while none has).
func _free_tank(sim: BattleSim, f: BattleSim.Fighter) -> bool:
	for e: BattleSim.Fighter in sim.fighters:
		if e.team != f.team and e.alive and e.cls == "tank" and sim.can_target(f, e) and room(sim, f, e) \
				and (roams(f) or lane_steps(sim, f, e) == 0):
			return true
	return false


## How far `t` counts as for `f`: its distance; before the war, enemies
## off to the side of its place count as further away; in the war, enemies
## in another lane (unless `f` roams) and past the battle line (unless `f`
## crosses it) count as a lot further (battle_rules.json "lanes").
func _score(sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter, place: Vector2i, free: bool) -> int:
	var score := BattleSim.edge_distance(f, t)
	if not free:
		return score + absi(t.x - place.x) * lane_pct / 100
	var fighter := f.attack_range < shooter_reach
	if not roams(f):
		score += lane_steps(sim, f, t) * (fighter_lane_cost if fighter else shooter_lane_cost)
	if not crosses(f) and t.is_unit():
		var past := past_line(sim, f.team, t)
		if (fighter and past > line_reach) or (not fighter and past + ranged_gap > f.attack_range + BattleSim.reach_to(f, t)):
			score += line_cost
	return score


# --- Lanes and the battle line ---------------------------------------------

## The lane a point across the field is in: -1 left, 0 middle, 1 right.
static func lane_at(sim: BattleSim, x: int) -> int:
	return clampi(x * 3 / maxi(1, sim.width), 0, 2) - 1


## How many lanes away from `f`'s own lane `t` is (0: in it, or within
## slack of it).
func lane_steps(sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter) -> int:
	var own := int(f.memory.get("lane", 0))
	var start := (own + 1) * sim.width / 3
	var end := (own + 2) * sim.width / 3
	if t.x >= start - lane_slack and t.x <= end + lane_slack:
		return 0
	return absi(lane_at(sim, t.x) - own)


## Whether `f` roams free of the lanes and the battle line (a flanker).
func roams(f: BattleSim.Fighter) -> bool:
	return flankers.has(String(f.card.get("id", "")))


## Whether `f` may go past the battle line (a flanker; Air flies over it).
func crosses(f: BattleSim.Fighter) -> bool:
	return roams(f) or (air_over and f.is_flying())


## How far `t` stands past the battle line in its lane, seen from `team`'s
## side (field units: 0 or less on `team`'s side; 0 with no line there).
func past_line(sim: BattleSim, team: int, t: BattleSim.Fighter) -> int:
	var y := int(line[lane_at(sim, t.x) + 1])
	if y < 0:
		return 0
	return y - t.y if team == 0 else t.y - y


## The battle line in each lane: halfway between the two sides' front
## animals on the ground there (flankers aside), moving at most line_pace a
## tick, so it pushes back and forth as one side wins ground.
func _move_line(sim: BattleSim) -> void:
	var fronts := [[-1, -1, -1], [-1, -1, -1]]
	for f: BattleSim.Fighter in sim.fighters:
		if not f.alive or not f.is_unit() or f.is_flying() or not f.memory.has("slot") or roams(f) or f.memory.get("burrowing", false):
			continue
		var l := lane_at(sim, f.x) + 1
		var at: int = fronts[f.team][l]
		if at < 0 or (f.team == 0 and f.y < at) or (f.team == 1 and f.y > at):
			fronts[f.team][l] = f.y
	for l in 3:
		if int(fronts[0][l]) < 0 or int(fronts[1][l]) < 0:
			line[l] = -1
			continue
		var want: int = (int(fronts[0][l]) + int(fronts[1][l])) / 2
		if int(line[l]) < 0:
			line[l] = want
		else:
			line[l] = int(line[l]) + clampi(want - int(line[l]), -line_pace, line_pace)


func _find(sim: BattleSim, f: BattleSim.Fighter, place: Vector2i, leash: int, free: bool, charging: bool) -> BattleSim.Fighter:
	var ground := not f.is_flying()
	var prefer: Dictionary = GameData.class_rules.get("prefer", {}).get(f.cls, {})
	var wanted := "tank" if charging else String(prefer.get("class", ""))
	var best: BattleSim.Fighter = null
	var best_score := 1 << 40
	var best_steps := 0
	var liked: BattleSim.Fighter = null
	var liked_score := 1 << 40
	var liked_steps := 0
	# The closest with no free slot, for when every enemy is full.
	var spare: BattleSim.Fighter = null
	var spare_score := 1 << 40
	var reach := leash + f.attack_range + BattleSim.reach_from(f)
	var war := at_war() and not charging
	var prefer_reach := roundi(float(prefer.get("tiles", 0)) * T)
	for t: BattleSim.Fighter in sim.fighters:
		if t.team == f.team or not t.alive:
			continue
		if t.kind == "bait":
			if ground and BattleSim.dist(f, t) <= t.lure_radius:
				return t
			continue
		if not free:
			# Too far from its place to reach (squared distances: cheap).
			var dx := t.x - place.x
			var dy := t.y - place.y
			var r := reach + BattleSim.reach_to(f, t)
			if dx * dx + dy * dy > r * r:
				continue
		if free:
			# Further away than the best so far (of its kind): no need to
			# look closer (squared distances: cheap).
			var bound := best_score if best != null else -1
			if wanted != "" and t.cls == wanted:
				bound = liked_score if liked != null else -1
			if bound >= 0:
				var gap := bound + f.radius + t.radius
				var ex := t.x - f.x
				var ey := t.y - f.y
				if ex * ex + ey * ey > gap * gap:
					continue
		if not sim.can_target(f, t):
			continue
		var score := _score(sim, f, t, place, free)
		if not room(sim, f, t):
			# No free slot: passed over for the next closest with one.
			if score < spare_score:
				spare = t
				spare_score = score
			continue
		if score < best_score:
			best = t
			best_score = score
			best_steps = lane_steps(sim, f, t) if free and not roams(f) else 0
		if wanted != "" and t.cls == wanted and score < liked_score:
			# In the war, what its class goes after only within its
			# class's reach (classes.json "prefer").
			if not war or BattleSim.edge_distance(f, t) <= prefer_reach:
				liked = t
				liked_score = score
				liked_steps = lane_steps(sim, f, t) if free and not roams(f) else 0
	# Its style may have its own idea (the biggest enemy, a Tank to charge...).
	var picked := BattleStyles.prefer_target(sim, f)
	if picked != null and (free or _reachable(f, picked, place, leash)) and room(sim, f, picked):
		return picked
	# What its class goes after (a charge: the Tanks), if it's no further out
	# of its lane than the best.
	if liked != null and liked_steps <= best_steps:
		return liked
	return best if best != null else spare


## Whether `f` can hit `t` without leaving its leash around `place`.
func _reachable(f: BattleSim.Fighter, t: BattleSim.Fighter, place: Vector2i, leash: int) -> bool:
	var dx := t.x - place.x
	var dy := t.y - place.y
	var r := leash + f.attack_range + BattleSim.reach_to(f, t) + BattleSim.reach_from(f)
	return dx * dx + dy * dy <= r * r


## The nearest enemy animal, whether or not `f` can hit it.
static func _nearest_any_enemy(sim: BattleSim, f: BattleSim.Fighter) -> BattleSim.Fighter:
	var best: BattleSim.Fighter = null
	var best_d := 1 << 60
	for t: BattleSim.Fighter in sim.fighters:
		if t.team != f.team and t.alive and t.is_unit() and not t.memory.get("burrowing", false):
			var dx := t.x - f.x
			var dy := t.y - f.y
			var d := dx * dx + dy * dy
			if d < best_d:
				best = t
				best_d = d
	return best


static func _nearest_enemy(sim: BattleSim, f: BattleSim.Fighter) -> BattleSim.Fighter:
	var best: BattleSim.Fighter = null
	var best_d := 1 << 60
	for t: BattleSim.Fighter in sim.fighters:
		if t.team != f.team and t.alive and t.is_unit():
			var dx := t.x - f.x
			var dy := t.y - f.y
			var d := dx * dx + dy * dy
			if d < best_d and sim.can_target(f, t):
				best = t
				best_d = d
	return best


# --- Moving ----------------------------------------------------------------

const NO_ROOM := Vector2i(-1, -1)
## Directions around a target to try for a spot, from straight at it out:
## [cos, sin] in thousandths, every 30 degrees.
const TURNS := [[1000, 0], [866, 500], [866, -500], [500, 866], [500, -866], [0, 1000], [0, -1000],
	[-500, 866], [-500, -866], [-866, 500], [-866, -500], [-1000, 0]]


## The grid square a point is in (flyers and walkers apart).
static func _cell(x: int, y: int, flying: bool) -> int:
	return ((x / BattleSim.SEPARATE_CELL) * 4096 + y / BattleSim.SEPARATE_CELL) * 2 + (1 if flying else 0)


## The animals near a point, at one height (flyers or walkers).
func _near(x: int, y: int, flying: bool) -> Array:
	var found := []
	var cx := x / BattleSim.SEPARATE_CELL
	var cy := y / BattleSim.SEPARATE_CELL
	for gx in range(cx - 1, cx + 2):
		for gy in range(cy - 1, cy + 2):
			var key := (gx * 4096 + gy) * 2 + (1 if flying else 0)
			if _grid.has(key):
				found.append_array(_grid[key])
	return found


## An open spot next to `t` where `f` can fight it: its slot's spot, or the
## nearest open one round from it (a new one checked every spot_seconds),
## or NO_ROOM if teammates and other enemies fill every side.
func _spot(sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter) -> Vector2i:
	if int(f.memory.get("spot_for", -1)) == t.uid and sim.tick < int(f.memory.get("spot_at", 0)) + spot_ticks:
		var off: Vector2i = f.memory.spot
		return Vector2i(clampi(t.x + off.x, f.radius, sim.width - f.radius), clampi(t.y + off.y, f.radius, sim.height - f.radius))
	# From its slot's way round (or, with none, from where it comes).
	var ux := f.x - t.x
	var uy := f.y - t.y
	if int(f.memory.get("engage_on", -1)) == t.uid:
		var dir := _slot_dir(f.team, int(f.memory.get("engage_k", 0)), cap_of(t), BattleSim.side_room(f), _ring(f, t))
		ux = dir.x
		uy = dir.y
	else:
		var d := BattleSim.isqrt(ux * ux + uy * uy)
		if d == 0:
			ux = 0
			uy = 1000 if f.team == 0 else -1000
		else:
			ux = ux * 1000 / d
			uy = uy * 1000 / d
	var ring := _ring(f, t)
	var flying := f.is_flying()
	# Only those close enough to the target to be in the way of a spot.
	var near := []
	for o: BattleSim.Fighter in _near(t.x, t.y, flying):
		if o != f and o != t and o.alive:
			var reach := ring + f.radius + o.radius
			var ox := o.x - t.x
			var oy := o.y - t.y
			if ox * ox + oy * oy < reach * reach:
				near.append(o)
	var flip := 1 if f.uid % 2 == 0 else -1
	for turn in TURNS:
		var c: int = turn[0]
		var s: int = turn[1] * flip
		var rx := (ux * c - uy * s) / 1000
		var ry := (ux * s + uy * c) / 1000
		var sx := t.x + rx * ring / 1000
		var sy := t.y + ry * ring / 1000
		if sx < f.radius or sx > sim.width - f.radius or sy < f.radius or sy > sim.height - f.radius:
			continue
		var open := true
		for o: BattleSim.Fighter in near:
			var room := f.radius + o.radius - avoid_margin
			var dx := o.x - sx
			var dy := o.y - sy
			if dx * dx + dy * dy < room * room:
				open = false
				break
		if open:
			f.memory.spot_for = t.uid
			f.memory.spot_at = sim.tick
			f.memory.spot = Vector2i(sx - t.x, sy - t.y)
			return Vector2i(sx, sy)
	f.memory.spot_for = -1
	return NO_ROOM


## Moves `f` toward `goal`, walking around anyone in the way (teammates,
## and enemies it isn't after): past the first one in its path, on the
## side it's less in the way, and on round the same side if the next one
## is in the way too, so a line is walked round at its end.
func _go(sim: BattleSim, f: BattleSim.Fighter, goal: Vector2i, speed: int) -> void:
	var dx := goal.x - f.x
	var dy := goal.y - f.y
	var d := BattleSim.isqrt(dx * dx + dy * dy)
	if d == 0 or speed <= 0:
		return
	var look := mini(d, avoid_look)
	var mid_x := f.x + dx * look / (2 * d)
	var mid_y := f.y + dy * look / (2 * d)
	var block: BattleSim.Fighter = null
	var block_along := 1 << 30
	var block_side := 0
	for o: BattleSim.Fighter in _near(mid_x, mid_y, f.is_flying()):
		if o == f or o == f.target or not o.alive:
			continue
		var ox := o.x - f.x
		var oy := o.y - f.y
		# (Its whole body in the way, whichever way it faces: half its
		# length out from its middle.)
		var along := (ox * dx + oy * dy) / d
		if along <= 0 or along > look + o.half:
			continue
		var side := (oy * dx - ox * dy) / d
		if absi(side) >= f.radius + o.half:
			continue
		if along < block_along:
			block = o
			block_along = along
			block_side = side
	if block == null:
		# On its way round someone: it keeps on to the spot beside them for a
		# moment, rather than turning straight back into them.
		var way_until := int(f.memory.get("way_until", -1))
		if way_until > sim.tick:
			var spot: Vector2i = f.memory.way
			if BattleSim.dist_to_point(f, spot.x, spot.y) > speed:
				sim.move_toward_point(f, spot, speed)
				return
		f.memory.detour = 0
		f.memory.way_until = -1
		sim.move_toward_point(f, goal, speed)
		return
	var turn := int(f.memory.get("detour", 0))
	if turn == 0:
		if block_side == 0:
			turn = 1 if f.uid % 2 == 0 else -1
		else:
			turn = -1 if block_side > 0 else 1
		f.memory.detour = turn
	var clear := f.half + block.half + avoid_margin
	var way := Vector2i(block.x - dy * turn * clear / d, block.y + dx * turn * clear / d)
	way.x = clampi(way.x, f.radius, sim.width - f.radius)
	way.y = clampi(way.y, f.radius, sim.height - f.radius)
	f.memory.way = way
	f.memory.way_until = sim.tick + detour_ticks
	sim.move_toward_point(f, way, speed)

## The nearest point to `goal` no more than `leash` from `place`.
static func _within(goal: Vector2i, place: Vector2i, leash: int) -> Vector2i:
	var dx := goal.x - place.x
	var dy := goal.y - place.y
	var d := BattleSim.isqrt(dx * dx + dy * dy)
	if d <= leash or d == 0:
		return goal
	return Vector2i(place.x + dx * leash / d, place.y + dy * leash / d)


## A charging Tank Destroyer still behind its own Tank wall heads for the
## nearer end of the wall first, so it goes around rather than into it.
func _around_own_wall(sim: BattleSim, f: BattleSim.Fighter, goal: Vector2i) -> Vector2i:
	var ahead := -1 if f.team == 0 else 1
	var left := 1 << 30
	var right := -(1 << 30)
	var wall_y := 0
	var count := 0
	for o: BattleSim.Fighter in sim.fighters:
		if o.team == f.team and o.alive and o.cls == "tank" and o.memory.has("slot"):
			left = mini(left, o.x - o.radius)
			right = maxi(right, o.x + o.radius)
			wall_y += o.y
			count += 1
	if count == 0:
		return goal
	wall_y /= count
	# Already level with the wall or past it, or the target is beside it.
	if (wall_y - f.y) * ahead <= T / 2 or goal.x < left or goal.x > right:
		return goal
	if f.x < left - f.radius or f.x > right + f.radius:
		return goal
	var side := left - f.radius - T / 3 if absi(f.x - left) <= absi(right - f.x) else right + f.radius + T / 3
	return Vector2i(clampi(side, f.radius, sim.width - f.radius), wall_y)
