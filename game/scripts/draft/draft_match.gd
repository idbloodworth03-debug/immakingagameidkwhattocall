class_name DraftMatch
extends RefCounted
## Draft Duel: best of 7. The first player to win 4 rounds wins (at most 7
## rounds; then the most wins, or a draw). Numbers: draft_rules.json.
##
## Each round: Pick, then Fight, then a quick result.
##
##   Pick: each player makes 3 picks. In round 1, three starting animals
##   from their collection. After that, from 5 options (animals and tools
##   from their collection), each pick is one of:
##     - an offered animal (one already in the herd gets a star instead),
##     - an offered tool (two at most; a third replaces one of them),
##     - a star for an animal already in the herd.
##   Picks can be taken back until the player is ready. There's no money
##   and no limit on the herd: it grows every round.
##
##   Fight: the herds take their places by class (Tanks in front, Tank
##   Destroyers in the middle, Ranged at the back, Air over the middle,
##   Specialists where their trait works best) and fight on their own
##   (BattleSim). Each player can Rally once and use each tool once.
##
##   Result: the herd that outlasts the other wins the round (at the bell,
##   the one with more of itself left).
##
## Like BattleSim, a match plays out the same way for the same seed and the
## same actions.

const NO_WINNER := -1

var rules: Dictionary
var sim: BattleSim
var rng := RandomNumberGenerator.new()
## "pick", "fight", "round_over" or "over".
var phase := ""
var round_number := 0
## Rounds won.
var wins := [0, 0]
## Each team's animals: {"id": String, "stars": 1 to star_max}.
var herds := [[], []]
## Each team's tools (card ids), and which can still be used this fight.
var tools := [[], []]
var tools_ready := [[], []]
## The cards each player's options come from (their collection).
var pools := [[], []]
## This round's options for each team: {"id": String, "taken": bool}. In
## round 1, every animal in the player's collection.
var offers := [[], []]
var picks_left := [0, 0]
## This round's picks, in order, for the screen: {"kind": "animal", "star"
## or "tool", "id", "index" (herd or tool slot)}.
var picks_made := [[], []]
var ready := [false, false]
## Each player's Rally for this fight (true until used).
var rally_ready := [true, true]
var fight_tick := 0
var fight_ticks := 0
## The fight tick each herd was wiped out (-1 while it still stands).
var wiped_at := [-1, -1]
## What happened last round: {"round", "winner", "wins", "animals_lost",
## "flawless"}.
var last_round: Dictionary = {}
## Things that happened, for the screen to show.
var events: Array = []
## The battle-field groups of each herd's animals, in herd order, so a tap on
## an animal finds its herd entry.
var groups := [[], []]
var _defeated_at_start := [0, 0]
var _undo := [[], []]
## Each team's own dice for its options, so one player's picks never
## change what the other is offered.
var _dice := [RandomNumberGenerator.new(), RandomNumberGenerator.new()]


## `setup` may hold "levels" (two dictionaries of card id -> level; a card
## not listed fights at its rarity's starting level) and "pool" (the card
## ids both players draw from) or "pools" (one list per player).
func _init(seed_value: int, setup: Dictionary = {}, draft_rules: Dictionary = {}) -> void:
	rules = draft_rules if not draft_rules.is_empty() else GameData.draft_rules
	rng.seed = seed_value
	sim = BattleSim.new(setup.get("levels", [{}, {}]), seed_value)
	var pool: Array = setup.get("pool", GameData.card_order)
	var both: Array = setup.get("pools", [pool, pool])
	pools = [both[0].duplicate(), both[1].duplicate()]
	fight_ticks = roundi(float(rules.fight_seconds) * sim.tps)
	for team in 2:
		_dice[team].seed = seed_value * 31 + team + 1
	_start_round()


## The cards a player draws from: the animals and tools they own, topped up
## with the first arena's cards if that's too few to fill the options.
static func pool_from_collection(owned: Callable, draft_rules: Dictionary = {}) -> Array:
	var r: Dictionary = draft_rules if not draft_rules.is_empty() else GameData.draft_rules
	var cards := []
	var animals := 0
	for id in GameData.card_order:
		if owned.call(id):
			cards.append(id)
			if not GameData.is_tool(id):
				animals += 1
	for id in GameData.card_order:
		if cards.size() >= int(r.offer_count) and animals >= int(r.picks_per_round):
			break
		if cards.has(id) or int(GameData.cards[id].unlock_arena_index) > 0:
			continue
		cards.append(id)
		if not GameData.is_tool(id):
			animals += 1
	return cards


# --- Info ------------------------------------------------------------------

func is_over() -> bool:
	return phase == "over"


func max_rounds() -> int:
	return int(rules.max_rounds)


func is_first_round() -> bool:
	return round_number == 1


## Who won the match: 0, 1 or NO_WINNER (a draw). Only meaningful when over.
func match_winner() -> int:
	if wins[0] != wins[1]:
		return 0 if wins[0] > wins[1] else 1
	return NO_WINNER


## Who wins a round, judged on `battle` (the real fight or a copy of it):
## the herd that outlasts the other; if both are standing at the bell, the
## one with more of its herd left. NO_WINNER if they're level.
static func judge(battle: BattleSim, wiped: Array) -> int:
	if wiped[0] >= 0 or wiped[1] >= 0:
		if wiped[0] < 0:
			return 0
		if wiped[1] < 0:
			return 1
		if wiped[0] != wiped[1]:
			return 0 if wiped[0] > wiped[1] else 1
		return NO_WINNER
	var left := [battle.herd_value(0), battle.herd_value(1)]
	if left[0] != left[1]:
		return 0 if left[0] > left[1] else 1
	return NO_WINNER


## How many of `team`'s herd (a swarm counts once) are still standing.
func standing(team: int) -> int:
	var alive := {}
	for f in sim.units(team):
		alive[int(f.memory.get("group", -1))] = true
	var count := 0
	for g in groups[team]:
		if alive.has(g):
			count += 1
	return count


## Where `id` is in `team`'s herd, or -1.
func herd_index(team: int, id: String) -> int:
	for i in herds[team].size():
		if herds[team][i].id == id:
			return i
	return -1


func take_events() -> Array:
	var taken := events
	events = []
	return taken


# --- Picking -------------------------------------------------------------------

## Why `team` can't take option `slot` right now ("" if it can).
func can_pick(team: int, slot: int) -> String:
	if phase != "pick" or ready[team]:
		return "Not now"
	if picks_left[team] <= 0:
		return "No picks left"
	if slot < 0 or slot >= offers[team].size():
		return "Pick a card"
	var item: Dictionary = offers[team][slot]
	if item.taken:
		return "Already picked"
	if not GameData.is_tool(item.id):
		var index := herd_index(team, item.id)
		if index >= 0 and (is_first_round() or int(herds[team][index].stars) >= int(rules.star_max)):
			return "Already picked" if is_first_round() else "Fully trained"
	return ""


## True if taking option `slot` needs a tool to make room (choose one with
## `replace` in pick()).
func needs_tool_swap(team: int, slot: int) -> bool:
	if slot < 0 or slot >= offers[team].size():
		return false
	return GameData.is_tool(offers[team][slot].id) and tools[team].size() >= int(rules.tools_max)


## Takes option `slot`: an animal joins the herd (or, if it's already there,
## gets a star); a tool joins the tool belt (replacing tool `replace` if
## the belt is full).
func pick(team: int, slot: int, replace := -1) -> bool:
	if can_pick(team, slot) != "":
		return false
	if needs_tool_swap(team, slot) and (replace < 0 or replace >= tools[team].size()):
		return false
	_save_undo(team)
	var item: Dictionary = offers[team][slot]
	var id: String = item.id
	item.taken = true
	var made := {"kind": "animal", "id": id, "index": -1, "slot": slot}
	if GameData.is_tool(id):
		made.kind = "tool"
		if tools[team].size() >= int(rules.tools_max):
			made["replaced"] = tools[team][replace]
			tools[team][replace] = id
			made.index = replace
		else:
			tools[team].append(id)
			made.index = tools[team].size() - 1
	else:
		var index := herd_index(team, id)
		if index >= 0:
			made.kind = "star"
			herds[team][index].stars = int(herds[team][index].stars) + 1
			made.index = index
		else:
			herds[team].append({"id": id, "stars": 1})
			made.index = herds[team].size() - 1
	_picked(team, made)
	return true


## Why `team` can't add a star to herd animal `index` ("" if it can).
func can_star(team: int, index: int) -> String:
	if phase != "pick" or ready[team]:
		return "Not now"
	if is_first_round():
		return "Pick your starters first"
	if picks_left[team] <= 0:
		return "No picks left"
	if index < 0 or index >= herds[team].size():
		return "Pick an animal"
	if int(herds[team][index].stars) >= int(rules.star_max):
		return "Fully trained"
	return ""


## Uses a pick to add a star to herd animal `index`.
func star(team: int, index: int) -> bool:
	if can_star(team, index) != "":
		return false
	_save_undo(team)
	herds[team][index].stars = int(herds[team][index].stars) + 1
	_picked(team, {"kind": "star", "id": herds[team][index].id, "index": index, "slot": -1})
	return true


## Takes back the last pick this round.
func undo(team: int) -> bool:
	if phase != "pick" or ready[team] or _undo[team].is_empty():
		return false
	var state: Dictionary = _undo[team].pop_back()
	herds[team] = state.herds
	tools[team] = state.tools
	offers[team] = state.offers
	picks_made[team] = state.picks
	picks_left[team] += 1
	_lay_out_herds()
	events.append({"type": "undo", "team": team})
	return true


## True if `team` has anything left it could pick.
func has_any_pick(team: int) -> bool:
	if picks_left[team] <= 0:
		return false
	for slot in offers[team].size():
		if can_pick(team, slot) == "":
			return true
	for index in herds[team].size():
		if can_star(team, index) == "":
			return true
	return false


## Done picking (all picks made, or nothing left to pick). When both
## players are ready, the fight starts.
func set_ready(team: int) -> bool:
	if phase != "pick" or ready[team] or has_any_pick(team):
		return false
	ready[team] = true
	events.append({"type": "ready", "team": team})
	if ready[0] and ready[1]:
		_start_fight()
	return true


func _save_undo(team: int) -> void:
	_undo[team].append({"herds": herds[team].duplicate(true), "tools": tools[team].duplicate(),
		"offers": offers[team].duplicate(true), "picks": picks_made[team].duplicate(true)})


func _picked(team: int, made: Dictionary) -> void:
	picks_left[team] -= 1
	picks_made[team].append(made)
	_lay_out_herds()
	var event := made.duplicate()
	event["type"] = "pick"
	event["team"] = team
	if made.kind != "tool":
		event["stars"] = int(herds[team][made.index].stars)
	events.append(event)


## This round's options: five cards from the collection, a mix of animals
## and tools (between offer_tools_min and offer_tools_max tools when there
## are any), rarer ones less often, never a fully trained animal.
func _roll_offers(team: int) -> Array:
	var dice: RandomNumberGenerator = _dice[team]
	var animals: Array = pools[team].filter(func(id): return not GameData.is_tool(id) and not _fully_trained(team, id))
	var tool_ids: Array = pools[team].filter(func(id): return GameData.is_tool(id))
	var count := int(rules.offer_count)
	var want_tools := mini(tool_ids.size(), dice.randi_range(int(rules.offer_tools_min), int(rules.offer_tools_max)))
	# With few animals to offer, fill up with tools instead.
	want_tools = clampi(maxi(want_tools, count - animals.size()), 0, tool_ids.size())
	var chosen := []
	for i in want_tools:
		chosen.append(_weighted_pick(tool_ids, chosen, dice))
	while chosen.size() < count:
		var id := _weighted_pick(animals, chosen, dice)
		if id == "":
			break
		chosen.append(id)
	# Animals first, then tools.
	chosen.sort_custom(func(a, b): return int(GameData.is_tool(a)) < int(GameData.is_tool(b)))
	return chosen.map(func(id): return {"id": id, "taken": false})


func _fully_trained(team: int, id: String) -> bool:
	var index := herd_index(team, id)
	return index >= 0 and int(herds[team][index].stars) >= int(rules.star_max)


## A card from `ids` (not in `exclude`), rarer rarities less often.
func _weighted_pick(ids: Array, exclude: Array, dice: RandomNumberGenerator) -> String:
	var weights: Dictionary = rules.rarity_weights
	var total := 0.0
	for id in ids:
		if not exclude.has(id):
			total += float(weights.get(GameData.get_card(id).rarity, 1))
	if total <= 0.0:
		return ""
	var roll := dice.randf() * total
	for id in ids:
		if exclude.has(id):
			continue
		roll -= float(weights.get(GameData.get_card(id).rarity, 1))
		if roll <= 0.0:
			return id
	for id in ids:
		if not exclude.has(id):
			return id
	return ""


# --- Taking places ---------------------------------------------------------

## Which row an animal takes: its class's, or for a Specialist its trait's.
static func row_of(card_id: String) -> String:
	var trait_id := GameData.trait_of(card_id)
	if trait_id != "":
		return String(GameData.traits[trait_id].get("row", "middle"))
	return String(GameData.class_info(GameData.class_of(card_id)).get("row", "middle"))


## Every animal takes its place by class (classes.json "rows"): rows run
## across the field, evenly spaced; a row too full for the field's width
## wraps into another row further back. Air hovers just behind the middle
## row, over the ground animals.
func _lay_out_herds() -> void:
	sim.clear_units()
	groups = [[], []]
	var layout: Dictionary = GameData.class_rules.get("rows", {})
	for team in 2:
		var by_row := {}
		for index in herds[team].size():
			var id: String = herds[team][index].id
			var row := row_of(id)
			if GameData.class_of(id) == "air":
				row = "air"
			if not by_row.has(row):
				by_row[row] = []
			by_row[row].append(index)
		var spots := {}
		for row in by_row:
			var depth := float(layout.get("middle" if row == "air" else row, 4.0)) + (0.6 if row == "air" else 0.0)
			var places := row_spots(by_row[row].size(), depth, layout)
			for i in by_row[row].size():
				spots[by_row[row][i]] = places[i]
		for index in herds[team].size():
			var entry: Dictionary = herds[team][index]
			var at: Vector2 = spots[index]
			var y := BattleSim.MIDDLE + roundi(at.y * BattleSim.TILE) * (1 if team == 0 else -1)
			var made := sim.spawn(team, entry.id, roundi(at.x * BattleSim.TILE), y)
			for member in made.size():
				var f: BattleSim.Fighter = made[member]
				f.deploy_ticks = 0
				apply_stars(f, int(entry.get("stars", 1)), rules)
				# For the screen only: the same animal keeps the same view when
				# the herds are laid out again, so it hops instead of popping in.
				f.memory.view_key = "%d/%d/%d" % [team, index, member]
			groups[team].append(int(made[0].memory.group) if not made.is_empty() else -1)
	sim.take_events()


## Where `count` animals of one row stand (x across in tiles, y back from
## the middle line in tiles): evenly across the field, wrapping into more
## rows further back when there are too many for one.
static func row_spots(count: int, depth: float, layout: Dictionary) -> Array:
	var width := float(BattleSim.WIDTH) / BattleSim.TILE
	var half := float(BattleSim.MIDDLE) / BattleSim.TILE
	var spacing := float(layout.get("spacing", 1.7))
	var per_line := maxi(1, floori((width - 1.0) / spacing))
	var spots := []
	var lines := ceili(count / float(per_line))
	for line in lines:
		var in_line := mini(per_line, count - line * per_line)
		var y := minf(depth + line * float(layout.get("depth", 1.2)), half - 0.6)
		for i in in_line:
			spots.append(Vector2(0.5 + (width - 1.0) * (i + 0.5) / in_line, y))
	return spots


## Every star after the first adds star_bonus_pct to an animal's health
## and bite.
static func apply_stars(f: BattleSim.Fighter, stars: int, draft_rules: Dictionary) -> void:
	f.memory.stars = stars
	if stars <= 1:
		return
	var pct := 100 + int(draft_rules.star_bonus_pct) * (stars - 1)
	f.max_hp = f.max_hp * pct / 100
	f.hp = f.max_hp
	f.damage = f.damage * pct / 100


# --- Fighting --------------------------------------------------------------

func step() -> void:
	if phase != "fight":
		return
	sim.step()
	fight_tick += 1
	for team in 2:
		if wiped_at[team] < 0 and sim.units(team).is_empty():
			wiped_at[team] = fight_tick
	if fight_tick >= fight_ticks or wiped_at[0] >= 0 or wiped_at[1] >= 0:
		_end_round()


## Uses tool `index` at (x, y). Each tool works once a fight and stays in
## the tool belt for the next one.
func use_tool(team: int, index: int, x: int, y: int) -> bool:
	if phase != "fight" or index < 0 or index >= tools[team].size() or not bool(tools_ready[team][index]):
		return false
	var id: String = tools[team][index]
	tools_ready[team][index] = false
	ToolEffects.use(sim, team, GameData.get_card(id), sim.level_of(team, id), clampi(x, 0, BattleSim.WIDTH), clampi(y, 0, BattleSim.HEIGHT))
	events.append({"type": "tool", "team": team, "id": id, "x": x, "y": y})
	return true


## Rally, once a fight: your animals near (x, y) bite harder, attack faster
## and run faster for a few seconds.
func rally(team: int, x: int, y: int) -> bool:
	if phase != "fight" or not rally_ready[team]:
		return false
	rally_ready[team] = false
	var r: Dictionary = rules.rally
	var radius := roundi(float(r.radius) * BattleSim.TILE)
	var duration := roundi(float(r.seconds) * sim.tps)
	for f in sim.allies_near(team, x, y, radius):
		f.rage = maxi(f.rage, duration)
		f.rage_damage_pct = maxi(f.rage_damage_pct, int(r.damage_pct))
		f.rage_speed_pct = maxi(f.rage_speed_pct, int(r.speed_pct))
		f.rage_attack_pct = maxi(f.rage_attack_pct, int(r.attack_pct))
	sim.events.append({"type": "rage", "x": x, "y": y, "radius": radius})
	events.append({"type": "rally", "team": team, "x": x, "y": y})
	return true


func _start_fight() -> void:
	_lay_out_herds()
	_defeated_at_start = [int(sim.teams[0].defeated), int(sim.teams[1].defeated)]
	rally_ready = [true, true]
	for team in 2:
		tools_ready[team] = tools[team].map(func(_id): return true)
	wiped_at = [-1, -1]
	for team in 2:
		if sim.units(team).is_empty():
			wiped_at[team] = 0
	fight_tick = 0
	phase = "fight"
	events.append({"type": "fight"})
	if wiped_at[0] >= 0 or wiped_at[1] >= 0:
		# A herd with nothing in it loses at once (and if both are empty,
		# nobody does).
		_end_round()


# --- Rounds ----------------------------------------------------------------

func _start_round() -> void:
	round_number += 1
	for team in 2:
		picks_left[team] = int(rules.picks_per_round)
		picks_made[team] = []
		_undo[team] = []
		if is_first_round():
			var animals: Array = pools[team].filter(func(id): return not GameData.is_tool(id))
			offers[team] = animals.map(func(id): return {"id": id, "taken": false})
		else:
			offers[team] = _roll_offers(team)
	ready = [false, false]
	_lay_out_herds()
	phase = "pick"
	events.append({"type": "round", "round": round_number})


func _end_round() -> void:
	var winner := judge(sim, wiped_at)
	if winner != NO_WINNER:
		wins[winner] += 1
	var lost := [0, 0]
	for team in 2:
		lost[team] = int(sim.teams[team].defeated) - int(_defeated_at_start[team])
	last_round = {
		"round": round_number, "winner": winner, "wins": wins.duplicate(), "animals_lost": lost,
		"flawless": winner != NO_WINNER and int(lost[winner]) == 0,
	}
	events.append({"type": "round_over", "winner": winner, "wins": wins.duplicate()})
	var decided: bool = wins[0] >= int(rules.wins_needed) or wins[1] >= int(rules.wins_needed)
	phase = "over" if decided or round_number >= max_rounds() else "round_over"
	if phase == "over":
		events.append({"type": "match_over", "winner": match_winner()})


## From "round_over" to the next round's picks.
func next_round() -> void:
	if phase == "round_over":
		_start_round()
