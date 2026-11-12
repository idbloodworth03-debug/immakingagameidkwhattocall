class_name BattleArmy
extends RefCounted
## Draft Duel's armies: every animal has a place in its army's formation and
## the army moves and fights as one. Numbers: classes.json "squads" and
## "formation", battle_rules.json "army".
##
## Every card brings a group of its animal, sized by the animal's build
## (classes.json "groups": a bunch of small ones, a few big ones), sharing
## what its class's squad carries.
##
## Formation: one block across the field. From the front, the Tank wall
## (shoulder to shoulder, a second line if it's too long), the Tank
## Destroyer line, Air hovering over it, then the Ranged ranks (every
## other line shifted half a place). Each group stands together; the
## Specialists' at the outer ends of their trait's rank, a Mythic's heroes
## in the middle of theirs. Each place is kept as an offset from the army's
## front line (memory.slot: x across, y back from the front).
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
##     to come to it. Every animal charges whichever enemy is best for it,
##     anywhere on the field (there are no lanes): fighters take a slot
##     round one (see below) and walk around teammates and other enemies in
##     the way, round the flanks if they must; shooters close in until
##     they're in reach and shoot over everyone, from behind the battle
##     line. (Before it, each animal only goes for what's in front of its
##     own place, within its leash.)
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
var side_pct := 120
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
## The battle line (battle_rules.json "line"): how far behind it Ranged
## stay (and how much further an enemy they couldn't hit from there
## counts), how fast it moves, and who isn't counted as an army's front (a
## flanker, off on its own).
var ranged_gap := 1200
var beyond_cost := 50000
var line_pace := 75
var flankers := {}
var air_over := true
## Where the battle line is (y, field units; -1: no line, one side has
## nobody on the ground).
var line := -1


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
	side_pct = int(a.get("side_pct", 120))
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
	var l: Dictionary = rules.get("line", GameData.battle_rules.get("line", {}))
	ranged_gap = roundi(float(l.get("ranged_gap", 1.2)) * T)
	beyond_cost = roundi(float(l.get("beyond_cost", 50.0)) * T)
	line_pace = maxi(1, roundi(float(l.get("pace", 90)) * T / (60.0 * tps)))
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

## What one card brings to the army: a group of its animal, as many as its
## build brings (classes.json "groups"), sharing what its class's squad
## carries (classes.json "squads") equally, with its rank and whether it
## stands at its rank's ends (a Specialist) or is a hero (a Mythic).
## Distances in field units; hp_share and damage_share: each animal's part
## of the card's health and bite, in hundredths of a percent.
static func squad_of(card_id: String) -> Dictionary:
	var card := GameData.get_card(card_id)
	var squads: Dictionary = GameData.class_rules.get("squads", {})
	var form: Dictionary = GameData.class_rules.get("formation", {})
	var cls := String(card.get("class", ""))
	var def: Dictionary = squads.get(cls, {}).duplicate()
	var hero := String(card.get("rarity", "")) == "mythic"
	var whole := maxi(1, int(def.get("units", 1)))
	var units := group_units(card_id, whole)
	var tune := int(GameData.class_rules.get("groups", {}).get("tune", {}).get(GameData.plays_as(card_id), 100))
	var hp_share := int(def.get("hp_pct", 100)) * whole * tune / units
	var damage_share := int(def.get("damage_pct", 100)) * whole * tune / units
	if hero:
		# (A hero's room in the line.)
		def.merge(squads.get("mythic", {}), true)
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
		"units": units,
		"hp_share": hp_share,
		"damage_share": damage_share,
		"radius": roundi(float(def.get("radius", 0.45)) * T),
		"spacing": roundi(float(def.get("spacing", 1.0)) * T),
		"line_max": maxi(1, int(def.get("line_max", 8))),
		"leash": roundi(float(def.get("leash", 1.5)) * T),
		"rank": rank, "flank": flank, "hero": hero, "back": back,
	}


## How many animals one card of `card_id` brings: its build's group
## (classes.json "groups"; `fallback` with no groups in the data).
static func group_units(card_id: String, fallback := 1) -> int:
	var groups: Dictionary = GameData.class_rules.get("groups", {})
	var by_build: Dictionary = groups.get("by_build", {})
	if by_build.is_empty():
		return maxi(1, fallback)
	# (An art test stands in for an animal: as many as that one.)
	var build := String(groups.get("builds", {}).get(GameData.plays_as(card_id), groups.get("default", "")))
	return maxi(1, int(by_build.get(build, fallback)))


## Gives one animal of a squad its share of the card's health and bite
## (and its army's bite_pct on top), and its squad's room on the field.
static func apply_share(f: BattleSim.Fighter, squad: Dictionary, bite: int) -> void:
	f.max_hp = maxi(1, f.max_hp * int(squad.hp_share) / 10000)
	f.hp = f.max_hp
	f.damage = maxi(1, f.damage * int(squad.damage_share) * bite / 1000000)
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
## spacing, line_max, group}, in army order; `flank`: at its rank's outer
## ends (a Specialist); `back`: in a line of its own behind the rest of its
## rank; `group`: its card's group), on a field `width` across: {"slots":
## [Vector2i(x across from the army's middle, y back from the front line)],
## "depth": the back line, "width": from the leftmost to the rightmost,
## "block": the longest line, "front": the first rank}, in field units.
##
## One block: each rank has its own lines at its depth, at most line_max
## in a line (and as many as fit across the field). A group stands
## together: the first in the middle of the line, the next ones to its
## right and left in turn, the Specialists' groups after their rank's own
## (so at its outer ends, or in the next line); a Mythic's heroes in the
## middle of the first line, a long reach in a line of its own at the back.
static func plan(units: Array, width: int = BattleSim.WIDTH) -> Dictionary:
	var form: Dictionary = GameData.class_rules.get("formation", {})
	var rank_gap := roundi(float(form.get("rank_gap", 0.45)) * T)
	var line_gap := roundi(float(form.get("line_gap", 0.3)) * T)
	var margin := roundi(float(form.get("edge_margin", 0.6)) * T)
	var stagger: Array = form.get("stagger", [])
	var over: Dictionary = form.get("over", {})
	var over_offset := roundi(float(form.get("over_offset", 0.35)) * T)
	var slots := []
	slots.resize(units.size())
	var depth := 0
	var left := 1 << 30
	var right := -(1 << 30)
	var block := 0
	var first := ""
	var last_radius := -1
	var rank_depth := {}
	for rank in form.get("ranks", ["wall", "td", "air", "ranged"]):
		# The rank's animals, in army order: its heroes, its own, the
		# Specialists that stand with it, and the long reaches.
		var heroes := []
		var main := []
		var flank := []
		var back := []
		var radius := 0
		var widest := 1
		for i in units.size():
			var u: Dictionary = units[i]
			if String(u.rank) != rank:
				continue
			radius = maxi(radius, int(u.radius))
			widest = maxi(widest, int(u.spacing))
			if u.hero:
				heroes.append(i)
			elif u.get("back", false):
				back.append(i)
			elif u.flank:
				flank.append(i)
			else:
				main.append(i)
		if heroes.is_empty() and main.is_empty() and flank.is_empty() and back.is_empty():
			continue
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
		# Lines of at most line_max (and as many as fit across the field).
		var line_max := 1 << 20
		for i in main + flank + back + heroes:
			line_max = mini(int(units[i].line_max), maxi(1, (width - 2 * margin) / widest))
			break
		var ordered: Array = main + flank
		var room := maxi(1, line_max - heroes.size())
		var lines := [{"middle": heroes, "rest": ordered.slice(0, room)}]
		var at := mini(room, ordered.size())
		while at < ordered.size():
			lines.append({"middle": [], "rest": ordered.slice(at, at + line_max)})
			at += line_max
		at = 0
		while at < back.size():
			lines.append({"middle": [], "rest": back.slice(at, at + line_max)})
			at += line_max
		for li in lines.size():
			# Each group as one block: the first in the middle (or beside
			# the heroes), the next to the right and to the left in turn,
			# whichever side is shorter.
			var to_left := []
			var to_right := []
			var left_w := 0
			var right_w := 0
			var middle: Array = lines[li].middle
			var blocks := []
			for i in lines[li].rest:
				var g: Variant = units[i].get("group", "u%d" % i)
				if blocks.is_empty() or blocks[-1].group != g:
					blocks.append({"group": g, "members": [], "wide": 0})
				blocks[-1].members.append(i)
				blocks[-1].wide += int(units[i].spacing)
			for k in blocks.size():
				var blk: Dictionary = blocks[k]
				if k == 0 and middle.is_empty():
					middle = blk.members
				elif right_w <= left_w:
					to_right.append_array(blk.members)
					right_w += int(blk.wide)
				else:
					to_left = blk.members + to_left
					left_w += int(blk.wide)
			var line: Array = to_left + middle + to_right
			var y := rank_front + li * (2 * radius + line_gap)
			var total := 0
			for i in line:
				total += int(units[i].spacing)
			# The line across the army's middle: the heroes (or the first
			# group) in it, the others either side.
			var x := -total / 2
			if stagger.has(rank) and li % 2 == 1 and not line.is_empty():
				x += int(units[line[0]].spacing) / 2
			for i in line:
				var w := int(units[i].spacing)
				slots[i] = Vector2i(x + w / 2, y)
				x += w
			block = maxi(block, total)
		for i in units.size():
			if slots[i] != null and String(units[i].rank) == rank:
				left = mini(left, int(slots[i].x) - int(units[i].spacing) / 2)
				right = maxi(right, int(slots[i].x) + int(units[i].spacing) / 2)
		depth = rank_front + (lines.size() - 1) * (2 * radius + line_gap)
		if hovering:
			# (No room of its own, unless it has more lines than the rank it
			# hovers over: the ranks behind stand clear of those too.)
			depth = maxi(saved_depth, int(rank_depth[hover]) + (lines.size() - 1) * (2 * radius + line_gap))
	return {"slots": slots, "depth": depth, "width": maxi(0, right - left), "block": block, "front": first}


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
		var p := plan(units, base.x)
		var biggest := 0
		for u in units:
			biggest = maxi(biggest, int(u.radius))
		var deep := float(a.get("start_gap", 3.2)) * T + int(p.depth) + biggest + float(a.get("edge", 0.8)) * T
		# Its longest line fits across the field.
		var form: Dictionary = GameData.class_rules.get("formation", {})
		var wide := int(p.width) + 2 * roundi(float(form.get("edge_margin", 0.6)) * T)
		need = maxf(need, maxf(deep / (base.y / 2.0), float(wide) / float(base.x)))
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
		"back": f.memory.get("back", false), "radius": f.radius, "spacing": f.memory.spacing, "line_max": f.memory.line_max,
		"group": int(f.memory.get("group", f.uid))})
	var p := plan(units, sim.width)
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
				# The fronts have met, even if their animals stand apart
				# across the field and nobody's in reach yet: that holds it
				# up too (so the war starts after_hold_seconds on).
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
		# (Its place at the end of its rank stays empty until the ranks next
		# close up: nobody shuffles forward the moment the march starts.)
		f.memory.dig_in = false
		f.memory.burrowing = true
		f.memory.free = true
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
			if line >= 0 and past_line(f.team, t) + ranged_gap <= f.attack_range + BattleSim.reach_to(f, t):
				goal.y = maxi(goal.y, line + ranged_gap) if f.team == 0 else mini(goal.y, line - ranged_gap)
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


## Whether any enemy Tank has a slot free for `f` (a charging Tank
## Destroyer settles for another enemy only while none has).
func _free_tank(sim: BattleSim, f: BattleSim.Fighter) -> bool:
	for e: BattleSim.Fighter in sim.fighters:
		if e.team != f.team and e.alive and e.cls == "tank" and sim.can_target(f, e) and room(sim, f, e):
			return true
	return false


## How far `t` counts as for `f`: its distance; before the war, enemies
## off to the side of its place count as further away; in the war a
## fighter goes for whichever is closest, anywhere on the field, and a
## shooter for one it can hit from behind the battle line (one it would
## have to cross the line for counts as a lot further: battle_rules.json
## "line").
func _score(_sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter, place: Vector2i, free: bool) -> int:
	var score := BattleSim.edge_distance(f, t)
	if not free:
		return score + absi(t.x - place.x) * side_pct / 100
	if f.attack_range >= shooter_reach and not crosses(f) and t.is_unit() \
			and past_line(f.team, t) + ranged_gap > f.attack_range + BattleSim.reach_to(f, t):
		score += beyond_cost
	return score


# --- The battle line ---------------------------------------------------------

## Whether `f` isn't counted as its army's front (a flanker, off on its
## own).
func roams(f: BattleSim.Fighter) -> bool:
	return flankers.has(GameData.plays_as(String(f.card.get("id", ""))))


## Whether `f` may go past the battle line: every fighter, and a shooter
## that flies over it.
func crosses(f: BattleSim.Fighter) -> bool:
	return f.attack_range < shooter_reach or (air_over and f.is_flying())


## How far `t` stands past the battle line, seen from `team`'s side (field
## units: 0 or less on `team`'s side; 0 with no line).
func past_line(team: int, t: BattleSim.Fighter) -> int:
	if line < 0:
		return 0
	return line - t.y if team == 0 else t.y - line


## The battle line: halfway between the two sides' front animals on the
## ground (flankers aside), moving at most line_pace a tick, so it pushes
## back and forth as one side wins ground.
func _move_line(sim: BattleSim) -> void:
	var fronts := [-1, -1]
	for f: BattleSim.Fighter in sim.fighters:
		if not f.alive or not f.is_unit() or f.is_flying() or not f.memory.has("slot") or roams(f) or f.memory.get("burrowing", false):
			continue
		var at: int = fronts[f.team]
		if at < 0 or (f.team == 0 and f.y < at) or (f.team == 1 and f.y > at):
			fronts[f.team] = f.y
	if int(fronts[0]) < 0 or int(fronts[1]) < 0:
		line = -1
		return
	var want: int = (int(fronts[0]) + int(fronts[1])) / 2
	line = want if line < 0 else line + clampi(want - line, -line_pace, line_pace)


func _find(sim: BattleSim, f: BattleSim.Fighter, place: Vector2i, leash: int, free: bool, charging: bool) -> BattleSim.Fighter:
	var ground := not f.is_flying()
	var prefer: Dictionary = GameData.class_rules.get("prefer", {}).get(f.cls, {})
	var wanted := "tank" if charging else String(prefer.get("class", ""))
	var best: BattleSim.Fighter = null
	var best_score := 1 << 40
	var liked: BattleSim.Fighter = null
	var liked_score := 1 << 40
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
		if wanted != "" and t.cls == wanted and score < liked_score:
			# In the war, what its class goes after only within its
			# class's reach (classes.json "prefer").
			if not war or BattleSim.edge_distance(f, t) <= prefer_reach:
				liked = t
				liked_score = score
	# Its style may have its own idea (the biggest enemy, a Tank to charge...).
	var picked := BattleStyles.prefer_target(sim, f)
	if picked != null and (free or _reachable(f, picked, place, leash)) and room(sim, f, picked):
		return picked
	# What its class goes after (a charge: the Tanks).
	if liked != null:
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
