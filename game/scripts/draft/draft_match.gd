class_name DraftMatch
extends RefCounted
## Draft Duel: best of 7. The first player to win 4 rounds wins (at most 7
## rounds; then the most wins, or a draw). Numbers: draft_rules.json.
##
## Each round: Pick, then Fight, then a quick result.
##
##   Pick: each player makes 3 picks. In round 1, three starting animals
##   from their deck. After that, from 4 animals from their deck and 2 of
##   their tools, each pick is one of:
##     - an offered animal: a new squad of it joins the army (another squad
##       if the army has it already),
##     - an offered tool (two at most; a third replaces one of them),
##     - an upgrade: a star for every squad of an animal in the army,
##     - a reinforcement: another full squad of an animal in the army.
##   Picks can be taken back until the player is ready. There's no money;
##   the army grows every round, up to army_max_units animals.
##
##   Fight: each army lines up in formation (Tank wall in front, Tank
##   Destroyers behind it, Air over the middle, Ranged ranks at the back,
##   Specialists on the flanks) and fights as one (BattleArmy). Each player
##   can blow the War Horn once and use each tool once.
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
## Each team's animals: {"id": String, "stars": 1 to star_max, "squads":
## how many squads of it}.
var herds := [[], []]
## Each team's tools (card ids), and which can still be used this fight.
var tools := [[], []]
var tools_ready := [[], []]
## The cards each player's options come from: their deck of animals and
## their tools.
var pools := [[], []]
## Animals nobody can use this match (the ban phase): left out of both
## pools, so they're never offered or put in an army.
var banned: Array = []
## This round's options for each team: {"id": String, "taken": bool}. In
## round 1, every animal in the player's deck.
var offers := [[], []]
var picks_left := [0, 0]
## This round's picks, in order, for the screen: {"kind": "animal",
## "squad" (another squad of one in the army), "star" or "tool", "id",
## "index" (herd or tool slot)}.
var picks_made := [[], []]
var ready := [false, false]
## Each player's War Horn for this fight (true until used).
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
## The herds as they were when this round's picking started: what each
## player has seen of the other's (the computer opponent goes by this, not by
## picks it can't see yet).
var herds_seen := [[], []]
## How much bigger than its smallest size the field is this fight (see
## BattleArmy.field_scale_for).
var field_scale := 1.0
## The battle-field groups (one per squad) of each herd entry, in herd
## order, so a tap on an animal finds its herd entry.
var groups := [[], []]
var _defeated_at_start := [0, 0]
var _undo := [[], []]
## Each team's own dice for its options, so one player's picks never
## change what the other is offered.
var _dice := [RandomNumberGenerator.new(), RandomNumberGenerator.new()]


## `setup` may hold "levels" (two dictionaries of card id -> level; a card
## not listed fights at its rarity's starting level), "pool" (the card ids
## both players draw from) or "pools" (one list per player), and "banned"
## (animals nobody may use this match).
func _init(seed_value: int, setup: Dictionary = {}, draft_rules: Dictionary = {}) -> void:
	rules = draft_rules if not draft_rules.is_empty() else GameData.draft_rules
	rng.seed = seed_value
	sim = BattleSim.new(setup.get("levels", [{}, {}]), seed_value)
	var pool: Array = setup.get("pool", GameData.card_order)
	var both: Array = setup.get("pools", [pool, pool])
	banned = setup.get("banned", []).duplicate()
	pools = [both[0].filter(func(id): return not banned.has(id)), both[1].filter(func(id): return not banned.has(id))]
	fight_ticks = roundi(float(rules.fight_seconds) * sim.tps)
	for team in 2:
		_dice[team].seed = seed_value * 31 + team + 1
	_start_round()


## The cards a player draws from: the animals and tools they own, topped up
## with the starting cards (then the first arena's) if that's too few to fill
## the options (offer_animals animals, and enough for round 1's picks;
## offer_tools tools).
static func pool_from_collection(owned: Callable, draft_rules: Dictionary = {}) -> Array:
	var r: Dictionary = draft_rules if not draft_rules.is_empty() else GameData.draft_rules
	var cards := []
	for id in GameData.card_order:
		if owned.call(id):
			cards.append(id)
	return with_enough(cards, r)


## `cards` topped up with the starting cards (then the first arena's) until
## there are enough animals and tools to fill the options.
static func with_enough(cards: Array, draft_rules: Dictionary = {}) -> Array:
	var r: Dictionary = draft_rules if not draft_rules.is_empty() else GameData.draft_rules
	var out := cards.duplicate()
	var animals := out.filter(func(id): return not GameData.is_tool(id)).size()
	var tools := out.size() - animals
	var want_animals := maxi(int(r.offer_animals), int(r.picks_per_round))
	var extra: Array = GameData.progression.get("starting_cards", []).duplicate()
	extra.append_array(GameData.cards_in_arena(0))
	for id in extra:
		if out.has(id):
			continue
		if GameData.is_tool(id) and tools < int(r.offer_tools):
			out.append(id)
			tools += 1
		elif not GameData.is_tool(id) and animals < want_animals:
			out.append(id)
			animals += 1
	return out


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


## How many of `team`'s herd entries (any of their squads) are still
## standing.
func standing(team: int) -> int:
	var alive := {}
	for f in sim.units(team):
		alive[int(f.memory.get("group", -1))] = true
	var count := 0
	for entry_groups in groups[team]:
		for g in entry_groups:
			if alive.has(g):
				count += 1
				break
	return count


## How many animals `team`'s army brings to a fight.
func army_units(team: int) -> int:
	var total := 0
	for entry in herds[team]:
		total += squad_units(String(entry.id)) * int(entry.get("squads", 1))
	return total


## How many animals one squad of `id` is.
static func squad_units(id: String) -> int:
	return int(BattleArmy.squad_of(id).units)


## True if another squad of `id` would make `team`'s army too big.
func army_full(team: int, id: String) -> bool:
	return army_units(team) + squad_units(id) > int(rules.get("army_max_units", 40))


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
		if is_first_round() and herd_index(team, item.id) >= 0:
			return "Already picked"
		if army_full(team, item.id):
			return "Army full"
	return ""


## True if taking option `slot` needs a tool to make room (choose one with
## `replace` in pick()).
func needs_tool_swap(team: int, slot: int) -> bool:
	if slot < 0 or slot >= offers[team].size():
		return false
	return GameData.is_tool(offers[team][slot].id) and tools[team].size() >= int(rules.tools_max)


## Takes option `slot`: a squad of an animal joins the army (another squad
## if it's there already); a tool joins the tool belt (replacing tool
## `replace` if the belt is full).
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
			made.kind = "squad"
			herds[team][index].squads = int(herds[team][index].get("squads", 1)) + 1
			made.index = index
		else:
			herds[team].append({"id": id, "stars": 1, "squads": 1})
			made.index = herds[team].size() - 1
	_picked(team, made)
	return true


## Why `team` can't upgrade herd animal `index` ("" if it can).
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


## Uses a pick to upgrade herd animal `index`: a star for all its squads.
func star(team: int, index: int) -> bool:
	if can_star(team, index) != "":
		return false
	_save_undo(team)
	herds[team][index].stars = int(herds[team][index].stars) + 1
	_picked(team, {"kind": "star", "id": herds[team][index].id, "index": index, "slot": -1})
	return true


## Why `team` can't add another squad of herd animal `index` ("" if it
## can).
func can_reinforce(team: int, index: int) -> String:
	if phase != "pick" or ready[team]:
		return "Not now"
	if is_first_round():
		return "Pick your starters first"
	if picks_left[team] <= 0:
		return "No picks left"
	if index < 0 or index >= herds[team].size():
		return "Pick an animal"
	if army_full(team, String(herds[team][index].id)):
		return "Army full"
	return ""


## Uses a pick to add another full squad of herd animal `index`
## (Reinforce): it joins the army's formation in the next fight.
func reinforce(team: int, index: int) -> bool:
	if can_reinforce(team, index) != "":
		return false
	_save_undo(team)
	herds[team][index].squads = int(herds[team][index].get("squads", 1)) + 1
	_picked(team, {"kind": "squad", "id": herds[team][index].id, "index": index, "slot": -1})
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
		if can_star(team, index) == "" or can_reinforce(team, index) == "":
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
		event["squads"] = int(herds[team][made.index].get("squads", 1))
	events.append(event)


## This round's options: offer_animals different animals from the deck,
## then offer_tools different tools (rarer ones less often). The screen
## shows them as two groups.
func _roll_offers(team: int) -> Array:
	var dice: RandomNumberGenerator = _dice[team]
	var animals: Array = pools[team].filter(func(id): return not GameData.is_tool(id))
	var tool_ids: Array = pools[team].filter(func(id): return GameData.is_tool(id))
	var chosen := []
	for i in mini(int(rules.offer_animals), animals.size()):
		chosen.append(_weighted_pick(animals, chosen, dice))
	var picked_tools := []
	for i in mini(int(rules.offer_tools), tool_ids.size()):
		picked_tools.append(_weighted_pick(tool_ids, picked_tools, dice))
	chosen.append_array(picked_tools)
	return chosen.map(func(id): return {"id": id, "taken": false})


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


## Both armies line up in formation (BattleArmy): one squad per pick,
## each animal in its place. The field grows (draft_rules.json "field") so
## both formations fit.
func _lay_out_herds() -> void:
	sim.clear_units()
	groups = [[], []]
	var field: Dictionary = rules.get("field", {})
	field_scale = BattleArmy.field_scale_for(herds, field)
	sim.set_size(field_scale, BattleArmy.base_size(field))
	sim.army = BattleArmy.new(sim.rules, sim.tps)
	sim.army.set_up(sim)
	for team in 2:
		var order := 0
		for index in herds[team].size():
			var entry: Dictionary = herds[team][index]
			var entry_groups := []
			for squad in maxi(1, int(entry.get("squads", 1))):
				var made := sim.army.spawn_squad(sim, team, entry.id, order)
				order += 1
				for member in made.size():
					var f: BattleSim.Fighter = made[member]
					f.deploy_ticks = 0
					apply_stars(f, int(entry.get("stars", 1)), rules)
					# For the screen only: the same animal keeps the same view
					# when the armies line up again, so it moves instead of
					# popping in.
					f.memory.view_key = "%d/%d/%d/%d" % [team, index, squad, member]
				if not made.is_empty():
					entry_groups.append(int(made[0].memory.group))
			groups[team].append(entry_groups)
		sim.army.layout(sim, team, true)
	sim.take_events()


## Every star after the first adds star_bonus_pct to an animal's health
## and bite (every animal of every squad of it).
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
	ToolEffects.use(sim, team, GameData.get_card(id), sim.level_of(team, id), clampi(x, 0, sim.width), clampi(y, 0, sim.height))
	events.append({"type": "tool", "team": team, "id": id, "x": x, "y": y})
	return true


## The War Horn, once a fight: the whole army surges, biting harder,
## attacking faster and running faster for a few seconds. (x, y) is only
## where the screen shows it.
func rally(team: int, x: int, y: int) -> bool:
	if phase != "fight" or not rally_ready[team]:
		return false
	rally_ready[team] = false
	var r: Dictionary = rules.rally
	var duration := roundi(float(r.seconds) * sim.tps)
	for f in sim.units(team):
		f.rage = maxi(f.rage, duration)
		f.rage_damage_pct = maxi(f.rage_damage_pct, int(r.damage_pct))
		f.rage_speed_pct = maxi(f.rage_speed_pct, int(r.speed_pct))
		f.rage_attack_pct = maxi(f.rage_attack_pct, int(r.attack_pct))
	sim.events.append({"type": "war_horn", "team": team, "x": x, "y": y})
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
	herds_seen = herds.duplicate(true)
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
