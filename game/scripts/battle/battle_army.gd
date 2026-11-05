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
##     fighters take an open spot around one (the less crowded enemies
##     first, so the whole front line is fought along, not just the middle)
##     and walk around teammates and other enemies in the way, round the
##     flanks if they must; shooters close in until they're in reach and
##     shoot over everyone. (Before it, each animal only goes for what's in
##     front of its own place, within its leash.)
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
## How many of each team's fighters are going for each enemy: {uid: count}.
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
var crowd_cost := 600
var full_cost := 6000
var spot_ticks := 3
var switch_margin := 800
## Reach (field units) from which an animal counts as a shooter: it needs no
## spot of its own next to its target.
var shooter_reach := 1500
## Every animal's bite, as a share of its card's (battle_rules.json
## "army" damage_pct).
var bite_pct := 100


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
	crowd_cost = roundi(float(w.get("crowd_cost", 0.6)) * T)
	full_cost = roundi(float(w.get("full_cost", 6.0)) * T)
	spot_ticks = maxi(1, roundi(float(w.get("spot_seconds", 0.15)) * tps))
	switch_margin = roundi(float(w.get("switch_margin", 0.8)) * T)
	shooter_reach = roundi(float(w.get("shooter_reach", 1.5)) * T)
	bite_pct = int(a.get("damage_pct", 100))


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
		"rank": rank, "flank": flank, "hero": hero, "elite": bool(def.get("elite", false)),
		"hero_scale": float(def.get("hero_scale", 1.0)),
	}


## Gives one animal of a squad its share of the card's health and bite
## (and its army's bite_pct on top), and its squad's room on the field.
static func apply_share(f: BattleSim.Fighter, squad: Dictionary, bite: int) -> void:
	f.max_hp = maxi(1, f.max_hp * int(squad.hp_pct) / 100)
	f.hp = f.max_hp
	f.damage = maxi(1, f.damage * int(squad.damage_pct) * bite / 10000)
	f.radius = int(squad.radius)
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
		f.memory.elite = squad.elite
		f.memory.spacing = int(squad.spacing)
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

## Places for a list of animals ({rank, flank, hero, radius, spacing,
## line_max}, in army order): {"slots": [Vector2i(x across, y back from the
## front line)], "depth": the back line, "width": the widest line, "front":
## the first rank}, in field units.
static func plan(units: Array) -> Dictionary:
	var form: Dictionary = GameData.class_rules.get("formation", {})
	var rank_gap := roundi(float(form.get("rank_gap", 0.45)) * T)
	var line_gap := roundi(float(form.get("line_gap", 0.3)) * T)
	var flank_gap := roundi(float(form.get("flank_gap", 0.45)) * T)
	var stagger: Array = form.get("stagger", [])
	var over: Dictionary = form.get("over", {})
	var over_offset := roundi(float(form.get("over_offset", 0.35)) * T)
	var rank_depth := {}
	var by_rank := {}
	for i in units.size():
		var u: Dictionary = units[i]
		if not by_rank.has(u.rank):
			by_rank[u.rank] = {"main": [], "flank": []}
		by_rank[u.rank]["flank" if u.flank else "main"].append(i)
	var slots := []
	slots.resize(units.size())
	var depth := 0
	var widest := 0
	var first := ""
	var last_radius := -1
	for rank in form.get("ranks", ["wall", "td", "air", "ranged"]):
		if not by_rank.has(rank):
			continue
		var main: Array = by_rank[rank].main
		var flank: Array = by_rank[rank].flank
		var radius := 0
		for i in main + flank:
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
		# Lines of at most line_max, the heroes in the middle of the first.
		var line_max := 1 << 20
		for i in main:
			if not units[i].hero:
				line_max = int(units[i].line_max)
				break
		var heroes := main.filter(func(i): return units[i].hero)
		var rest := main.filter(func(i): return not units[i].hero)
		var lines := []
		var at := 0
		while at < rest.size() or (lines.is_empty() and not heroes.is_empty()):
			var line: Array = rest.slice(at, at + (maxi(1, line_max - heroes.size()) if lines.is_empty() else line_max))
			at += line.size()
			if lines.is_empty() and not heroes.is_empty():
				var half := line.size() / 2
				line = line.slice(0, half) + heroes + line.slice(half)
			lines.append(line)
		var half_front := 0
		for li in lines.size():
			if li > 0:
				depth += 2 * radius + line_gap
			var line: Array = lines[li]
			var total := 0
			for i in line:
				total += int(units[i].spacing)
			var x := -total / 2
			if stagger.has(rank) and li % 2 == 1 and not line.is_empty():
				x += int(units[line[0]].spacing) / 2
			for i in line:
				var w := int(units[i].spacing)
				slots[i] = Vector2i(x + w / 2, depth)
				x += w
			widest = maxi(widest, total)
			if li == 0:
				half_front = total / 2
		# Flankers: right, left, right... just past the ends of the first line.
		var right := half_front + (flank_gap if not lines.is_empty() else 0)
		var left := -right
		for k in flank.size():
			var i: int = flank[k]
			var w := int(units[i].spacing)
			if k % 2 == 0:
				slots[i] = Vector2i(right + w / 2, rank_front)
				right += w
			else:
				slots[i] = Vector2i(left - w / 2, rank_front)
				left -= w
		widest = maxi(widest, right - left)
		if hovering:
			depth = saved_depth
	return {"slots": slots, "depth": depth, "width": widest, "front": first}


## The animals a herd brings ({id, stars, squads} entries), in army order,
## as plan() wants them.
static func herd_units(herd: Array) -> Array:
	var units := []
	for entry in herd:
		var squad := squad_of(String(entry.id))
		for s in maxi(1, int(entry.get("squads", 1))):
			for i in int(squad.units):
				units.append(squad)
	return units


## How much bigger than its smallest size the field must be for both
## armies to line up (start_gap from the middle, `edge` from the back).
static func field_scale_for(herds: Array, field: Dictionary) -> float:
	var a: Dictionary = GameData.battle_rules.get("army", {})
	var need := 1.0
	for herd in herds:
		var units := herd_units(herd)
		if units.is_empty():
			continue
		var p := plan(units)
		var biggest := 0
		for u in units:
			biggest = maxi(biggest, int(u.radius))
		var deep := float(a.get("start_gap", 3.2)) * T + int(p.depth) + biggest + float(a.get("edge", 0.8)) * T
		var wide := int(p.width) + 2 * biggest + T
		need = maxf(need, maxf(deep / BattleSim.MIDDLE, float(wide) / BattleSim.WIDTH))
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
	var units := members.map(func(f): return {"rank": f.memory.rank, "flank": f.memory.flank, "hero": f.memory.hero,
		"radius": f.radius, "spacing": f.memory.spacing, "line_max": f.memory.line_max})
	var p := plan(units)
	front_rank[team] = p.front
	for i in members.size():
		var f: BattleSim.Fighter = members[i]
		f.memory.slot = p.slots[i]
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
	for f: BattleSim.Fighter in sim.fighters:
		if f.alive and f.is_unit() and f.memory.has("slot"):
			by_team[f.team].append(f)
		if f.alive and f.is_unit() and not f.memory.get("burrowing", false):
			var key := _cell(f.x, f.y, f.is_flying())
			if not _grid.has(key):
				_grid[key] = []
			_grid[key].append(f)
			if f.target != null and f.target.alive and f.attack_range < shooter_reach:
				crowd[f.team][f.target.uid] = int(crowd[f.team].get(f.target.uid, 0)) + 1
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
				if fighting or (near != null and BattleSim.edge_distance(f, near) <= engage):
					holding[team] = true
					if clash_tick < 0 and near != null and near.memory.get("rank", "") == front_rank[1 - team] and BattleSim.edge_distance(f, near) <= engage:
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
	if t != null and sim.in_range(f, t):
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
	if t != null:
		var goal := Vector2i(t.x, t.y)
		var speed := sim.current_speed(f)
		if (free or war) and f.attack_range < shooter_reach and t.is_unit():
			# A fighter heads for an open spot next to its target; with none
			# left, it picks an enemy with room around it.
			var spot := _spot(sim, f, t)
			if spot == NO_ROOM:
				f.memory.full = t.uid
				f.memory.full_until = sim.tick + spot_ticks * 4
				var other := _find(sim, f, place, leash, true, charging)
				_count(f, other)
				f.target = other
				if other == null:
					return
				t = other
				goal = Vector2i(t.x, t.y)
				if sim.in_range(f, t):
					return
			else:
				goal = spot
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
	# Nothing to fight: to its place, in step with the army.
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

## Keeps a good target, or finds one: food bait close by first; when
## charging, the nearest enemy Tank; otherwise what's in front of its own
## place within its leash (enemies off to the side count as further away),
## the class it goes after first.
func _choose_target(sim: BattleSim, f: BattleSim.Fighter, place: Vector2i, leash: int, free: bool, charging: bool) -> void:
	var t := f.target
	var turn := (sim.tick + f.uid) % sim.retarget_ticks == 0
	var keep := false
	if t != null and sim.can_target(f, t) and (free or _reachable(f, t, place, leash)):
		if sim.in_range(f, t) or not turn:
			if not (charging and t.cls != "tank"):
				return
		keep = not (charging and t.cls != "tank")
	elif t == null and not turn:
		# Nothing to fight: it looks around now and then (animals take
		# turns), which keeps big armies cheap on phones. One whose target
		# has just fallen looks at once.
		return
	var found := _find(sim, f, place, leash, free, charging)
	if keep and at_war() and found != null and found != t and t.is_unit() and found.kind != "bait":
		# In the war, only for one clearly better (so nobody dithers).
		if not sim.in_range(f, found) and _score(sim, f, found, place, free) + switch_margin >= _score(sim, f, t, place, free):
			return
	_count(f, found)
	f.target = found


## Keeps the count of who's going for whom up to date as `f` picks `t`
## (call before setting f.target).
func _count(f: BattleSim.Fighter, t: BattleSim.Fighter) -> void:
	if f.attack_range >= shooter_reach:
		return
	var mine: Dictionary = crowd[f.team]
	if f.target != null and mine.has(f.target.uid):
		mine[f.target.uid] = maxi(0, int(mine[f.target.uid]) - 1)
	if t != null:
		mine[t.uid] = int(mine.get(t.uid, 0)) + 1


## How far `t` counts as for `f`: its distance, plus (once free or at war,
## for a fighter) how crowded it already is with `f`'s teammates, a lot more
## once there's no room left around it; before the war, enemies off to the
## side of its place count as further away.
func _score(sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter, place: Vector2i, free: bool) -> int:
	var score := BattleSim.edge_distance(f, t)
	if not free:
		return score + absi(t.x - place.x) * lane_pct / 100
	if f.attack_range < shooter_reach:
		var others := int(crowd[f.team].get(t.uid, 0)) - (1 if f.target == t else 0)
		score += maxi(0, others) * crowd_cost
		var ring := t.radius + f.radius + f.attack_range / 2
		var room := maxi(1, 3141 * ring / (2000 * maxi(1, f.radius)))
		if others >= room or (int(f.memory.get("full", -1)) == t.uid and sim.tick < int(f.memory.get("full_until", 0))):
			score += full_cost
	return score


func _find(sim: BattleSim, f: BattleSim.Fighter, place: Vector2i, leash: int, free: bool, charging: bool) -> BattleSim.Fighter:
	var ground := not f.is_flying()
	var prefer: Dictionary = GameData.class_rules.get("prefer", {}).get(f.cls, {})
	var wanted := "tank" if charging else String(prefer.get("class", ""))
	var best: BattleSim.Fighter = null
	var best_score := 1 << 40
	var liked: BattleSim.Fighter = null
	var liked_score := 1 << 40
	var reach := leash + f.attack_range + f.radius
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
			var r := reach + t.radius
			if dx * dx + dy * dy > r * r:
				continue
		if free:
			# Further away than the best so far (of its kind) even before any
			# crowding: no need to look closer (squared distances: cheap).
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
		if score < best_score:
			best = t
			best_score = score
		if wanted != "" and t.cls == wanted and score < liked_score:
			# In the war, what its class goes after only within its
			# class's reach (classes.json "prefer"), and only with room.
			if not war or (BattleSim.edge_distance(f, t) <= prefer_reach and score - BattleSim.edge_distance(f, t) < full_cost):
				liked = t
				liked_score = score
	# Its style may have its own idea (the biggest enemy, a Tank to charge...).
	var picked := BattleStyles.prefer_target(sim, f)
	if picked != null and (free or _reachable(f, picked, place, leash)) and _score(sim, f, picked, place, free) - BattleSim.edge_distance(f, picked) < full_cost:
		return picked
	return liked if liked != null else best


## Whether `f` can hit `t` without leaving its leash around `place`.
func _reachable(f: BattleSim.Fighter, t: BattleSim.Fighter, place: Vector2i, leash: int) -> bool:
	var dx := t.x - place.x
	var dy := t.y - place.y
	var r := leash + f.attack_range + t.radius + f.radius
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


## An open spot next to `t` where `f` can fight it: the nearest way round
## from where `f` comes (a new one checked every spot_seconds), or NO_ROOM
## if teammates and other enemies fill every side.
func _spot(sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter) -> Vector2i:
	if int(f.memory.get("spot_for", -1)) == t.uid and sim.tick < int(f.memory.get("spot_at", 0)) + spot_ticks:
		var off: Vector2i = f.memory.spot
		return Vector2i(clampi(t.x + off.x, f.radius, sim.width - f.radius), clampi(t.y + off.y, f.radius, sim.height - f.radius))
	var ux := f.x - t.x
	var uy := f.y - t.y
	var d := BattleSim.isqrt(ux * ux + uy * uy)
	if d == 0:
		ux = 0
		uy = 1000 if f.team == 0 else -1000
	else:
		ux = ux * 1000 / d
		uy = uy * 1000 / d
	var ring := t.radius + f.radius + f.attack_range / 2
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
		var along := (ox * dx + oy * dy) / d
		if along <= 0 or along > look + o.radius:
			continue
		var side := (oy * dx - ox * dy) / d
		if absi(side) >= f.radius + o.radius:
			continue
		if along < block_along:
			block = o
			block_along = along
			block_side = side
	if block == null:
		f.memory.detour = 0
		sim.move_toward_point(f, goal, speed)
		return
	var turn := int(f.memory.get("detour", 0))
	if turn == 0:
		if block_side == 0:
			turn = 1 if f.uid % 2 == 0 else -1
		else:
			turn = -1 if block_side > 0 else 1
		f.memory.detour = turn
	var clear := f.radius + block.radius + avoid_margin
	var way := Vector2i(block.x - dy * turn * clear / d, block.y + dx * turn * clear / d)
	way.x = clampi(way.x, f.radius, sim.width - f.radius)
	way.y = clampi(way.y, f.radius, sim.height - f.radius)
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
