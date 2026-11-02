class_name DraftMatch
extends RefCounted
## Draft Duel. Each player starts with hearts (30), and the match goes round
## by round until someone runs out.
##
## Before the first round, each player picks starters: up to 3 animals they
## own, within an Acorn budget. They start the match in the herd.
##
## Each round has four parts:
##
##   1. Shop: each player has their own Watering Hole, drawn from the cards
##      they own: animals and a Ranger tool. Both shop at the same time: buy
##      cards, reroll the shop for an Acorn, or train an animal in the herd
##      up a star (1 to 3; every star adds health and bite). Buying a copy
##      of an animal you already have gives it a free star instead. Herds
##      carry over from round to round.
##   2. Place: each player arranges their whole herd on their own half of the
##      field. Nothing moves and there's no clock: this is the time to think.
##   3. Fight: the herds fight on their own (BattleSim does the fighting),
##      with some luck: every animal's mood, and every hit. Players can use
##      the tools they bought, and once a fight they can Rally the animals
##      around a spot.
##   4. Round over: the fight ends when a herd is wiped out (or at the bell:
##      then the herd with more of itself left wins). The loser loses hearts:
##      the round number, plus 1 for every enemy animal still standing, and
##      gets a few extra Acorns next round, to help it catch up.
##
## Acorns are the match's only money, for animals, tools, training and
## rerolls. Both players start with the same Acorns, and they're gone when
## the match ends.
##
## Like BattleSim, a match plays out the same way for the same seed and the
## same actions.

## Where new animals stand until they're moved, in tiles, for team 0 (team 1
## uses the same spots mirrored).
const SPOTS := [
	Vector2(5.0, 12.5), Vector2(11.0, 12.5), Vector2(8.0, 13.5),
	Vector2(3.0, 14.5), Vector2(13.0, 14.5), Vector2(6.0, 16.0),
	Vector2(10.0, 16.0), Vector2(8.0, 17.5),
]
## How close to the middle line animals may start, in field units.
const START_GAP := 1000
const NO_WINNER := -1

var rules: Dictionary
var sim: BattleSim
var rng := RandomNumberGenerator.new()
## "starters", "draft" (shopping), "place", "fight", "round_over" or "over".
var phase := ""
var round_number := 0
var hearts := [0, 0]
var acorns := [0, 0]
## Each team's animals: {"id": String, "x": int, "y": int (field units),
## "stars": 1 to star_max}.
var herds := [[], []]
## Each team's Ranger tools, by card id. Hidden from the other player.
var tools := [[], []]
## The cards the Watering Holes draw from.
var pool: Array = []
## Each team's own Watering Hole: {"id", "cost", "taken": team or -1}.
var shops := [[], []]
## Each team's starters, once picked.
var starters := [[], []]
var starters_picked := [false, false]
var done_shopping := [false, false]
var ready := [false, false]
## Each player's Rally for this fight (true until used).
var rally_ready := [true, true]
var fight_tick := 0
var fight_ticks := 0
## The fight tick each herd was wiped out (-1 while it still stands).
var wiped_at := [-1, -1]
## What happened last round: {"round", "winner", "standing": [team 0's animals still standing, team 1's], "hearts_lost":
## [int, int], "stolen": [Acorns each team stole]}.
var last_round: Dictionary = {}
## Things that happened, for the screen to show: buys, training, tools...
var events: Array = []
## The battle-field groups of each herd's animals, in herd order, so a tap on
## an animal finds its herd entry.
var groups := [[], []]
## The loser of the last round (-1 for none), who gets bonus Acorns.
var _last_loser := -1
var _stolen := [0, 0]
## Each team's own dice for its shop, so one player's rerolls never change
## what the other is offered.
var _shop_dice := [RandomNumberGenerator.new(), RandomNumberGenerator.new()]


## `setup` may hold "levels" (two dictionaries of card id -> level; a card
## not listed fights at its rarity's starting level) and "pool" (the card
## ids the Watering Hole draws from; every card if left out).
func _init(seed_value: int, setup: Dictionary = {}, draft_rules: Dictionary = {}) -> void:
	rules = draft_rules if not draft_rules.is_empty() else GameData.draft_rules
	rng.seed = seed_value
	sim = BattleSim.new(setup.get("levels", [{}, {}]), seed_value)
	pool = setup.get("pool", GameData.card_order).duplicate()
	fight_ticks = roundi(float(rules.fight_seconds) * sim.tps)
	hearts = [int(rules.hearts), int(rules.hearts)]
	acorns = [int(rules.acorns_start), int(rules.acorns_start)]
	for team in 2:
		_shop_dice[team].seed = seed_value * 31 + team + 1
	phase = "starters"


## The cards a player's Watering Hole draws from: the animals and tools they
## own, topped up with the first arena's cards if that's too few to fill it.
static func pool_from_collection(owned: Callable, draft_rules: Dictionary = {}) -> Array:
	var r: Dictionary = draft_rules if not draft_rules.is_empty() else GameData.draft_rules
	var cards := []
	var animals := 0
	var tool_count := 0
	for id in GameData.card_order:
		if owned.call(id):
			cards.append(id)
			if GameData.is_tool(id):
				tool_count += 1
			else:
				animals += 1
	for id in GameData.card_order:
		if cards.has(id) or int(GameData.cards[id].unlock_arena_index) > 0:
			continue
		var is_tool := GameData.is_tool(id)
		if is_tool and tool_count < int(r.market_tools) + 1:
			cards.append(id)
			tool_count += 1
		elif not is_tool and animals < int(r.market_animals) + 2:
			cards.append(id)
			animals += 1
	return cards


# --- Info ------------------------------------------------------------------

func is_over() -> bool:
	return phase == "over"


func max_rounds() -> int:
	return int(rules.max_rounds)


## Who won the match: 0, 1 or NO_WINNER (a draw). Only meaningful when over.
func match_winner() -> int:
	if hearts[0] != hearts[1]:
		return 0 if hearts[0] > hearts[1] else 1
	return NO_WINNER


## Who wins a round, judged on `battle` (the real fight or a copy of it):
## the herd that outlasts the other; if both are standing at
## the bell, the one with more of its herd left. NO_WINNER if they're level.
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


## How many of `team`'s herd (a pack counts once) are still standing.
func standing(team: int) -> int:
	var alive := {}
	for f in sim.units(team):
		alive[int(f.memory.get("group", -1))] = true
	var count := 0
	for g in groups[team]:
		if alive.has(g):
			count += 1
	return count


## The hearts the loser of this round loses: the round's base, plus the
## winner's animals still standing.
func heart_loss(winner_standing: int) -> int:
	return round_number * int(rules.heart_loss_per_round) + winner_standing * int(rules.heart_loss_per_animal)


func take_events() -> Array:
	var taken := events
	events = []
	return taken


# --- Starters --------------------------------------------------------------

## Why `ids` can't be `team`'s starters. Empty means they can.
func starter_problem(ids: Array) -> String:
	if ids.size() > int(rules.starters):
		return "Pick up to %d" % int(rules.starters)
	var total := 0
	for i in ids.size():
		var id: String = ids[i]
		if not pool.has(id) or GameData.is_tool(id):
			return "Starters must be animals you own"
		if ids.find(id) != i:
			return "Pick different animals"
		total += int(GameData.get_card(id).cost)
	if total > int(rules.starter_budget):
		return "Over budget: %d of %d Acorns" % [total, int(rules.starter_budget)]
	return ""


## Picks `team`'s starters. When both players have, the first round starts.
func pick_starters(team: int, ids: Array) -> bool:
	if phase != "starters" or starters_picked[team] or starter_problem(ids) != "":
		return false
	starters[team] = ids.duplicate()
	starters_picked[team] = true
	for id in ids:
		var spot := default_spot(team)
		herds[team].append({"id": id, "x": spot.x, "y": spot.y, "stars": 1})
	events.append({"type": "starters", "team": team})
	if starters_picked[0] and starters_picked[1]:
		_start_round()
	else:
		_lay_out_herds()
	return true


# --- Shopping --------------------------------------------------------------

## Why `team` can't buy slot `slot` of its shop right now. Empty means it can.
func can_buy(team: int, slot: int) -> String:
	if phase != "draft":
		return "The shop is closed"
	if done_shopping[team]:
		return "You're done shopping"
	if slot < 0 or slot >= shops[team].size() or int(shops[team][slot].taken) >= 0:
		return "Already bought"
	var item: Dictionary = shops[team][slot]
	if acorns[team] < int(item.cost):
		return "Not enough Acorns"
	if GameData.is_tool(item.id):
		if tools[team].size() >= int(rules.tools_max):
			return "Your tool belt is full"
	elif herds[team].size() >= int(rules.herd_max) and merge_target(team, item.id) < 0:
		return "Your herd is full"
	return ""


## The herd animal a bought copy of `id` would upgrade (the one with the
## fewest stars that can still go up), or -1 if it would join as a new one.
func merge_target(team: int, id: String) -> int:
	var best := -1
	for i in herds[team].size():
		var entry: Dictionary = herds[team][i]
		if entry.id == id and int(entry.stars) < int(rules.star_max):
			if best < 0 or int(entry.stars) < int(herds[team][best].stars):
				best = i
	return best


func buy(team: int, slot: int) -> bool:
	if can_buy(team, slot) != "":
		return false
	var item: Dictionary = shops[team][slot]
	acorns[team] -= int(item.cost)
	item.taken = team
	var merged := -1
	if GameData.is_tool(item.id):
		tools[team].append(item.id)
	else:
		merged = merge_target(team, item.id)
		if merged >= 0:
			herds[team][merged].stars = int(herds[team][merged].stars) + 1
		else:
			var spot := default_spot(team)
			herds[team].append({"id": item.id, "x": spot.x, "y": spot.y, "stars": 1})
		_lay_out_herds()
	events.append({"type": "buy", "team": team, "slot": slot, "id": item.id,
		"merged": merged >= 0, "stars": int(herds[team][merged].stars) if merged >= 0 else 1})
	return true


## What training herd animal `index` up a star costs, or -1 if it can't go
## higher: its card's cost times the stars it has, plus train_extra.
func train_cost(team: int, index: int) -> int:
	if index < 0 or index >= herds[team].size():
		return -1
	var stars := int(herds[team][index].stars)
	if stars >= int(rules.star_max):
		return -1
	return int(GameData.get_card(herds[team][index].id).cost) * stars + int(rules.train_extra)


## Why `team` can't train herd animal `index` now. Empty means it can.
func can_train(team: int, index: int) -> String:
	if phase != "draft":
		return "Train while shopping"
	if done_shopping[team]:
		return "You're done shopping"
	var price := train_cost(team, index)
	if price < 0:
		return "Already %d stars" % int(rules.star_max)
	if acorns[team] < price:
		return "Not enough Acorns"
	return ""


func train(team: int, index: int) -> bool:
	if can_train(team, index) != "":
		return false
	acorns[team] -= train_cost(team, index)
	herds[team][index].stars = int(herds[team][index].stars) + 1
	_lay_out_herds()
	events.append({"type": "train", "team": team, "id": herds[team][index].id, "stars": herds[team][index].stars})
	return true


## A fresh shop for `reroll_cost` Acorns.
func reroll(team: int) -> bool:
	if phase != "draft" or done_shopping[team] or acorns[team] < int(rules.reroll_cost):
		return false
	acorns[team] -= int(rules.reroll_cost)
	shops[team] = _roll_shop(team)
	events.append({"type": "reroll", "team": team})
	return true


## Done shopping for this round. When both are, it's time to place.
func finish_shopping(team: int) -> bool:
	if phase != "draft" or done_shopping[team]:
		return false
	done_shopping[team] = true
	events.append({"type": "done", "team": team})
	if done_shopping[0] and done_shopping[1]:
		_start_placing()
	return true


## Something `team` could still buy or train this round.
func can_shop_more(team: int) -> bool:
	for i in shops[team].size():
		if can_buy(team, i) == "":
			return true
	for i in herds[team].size():
		if can_train(team, i) == "":
			return true
	return false


func _roll_shop(team: int) -> Array:
	var dice: RandomNumberGenerator = _shop_dice[team]
	var slots := []
	var animals := []
	var tool_ids := []
	for id in pool:
		if GameData.is_tool(id):
			tool_ids.append(id)
		else:
			animals.append(id)
	var shown := []
	for i in int(rules.market_animals):
		var id := _weighted_pick(animals, shown, dice)
		if id != "":
			shown.append(id)
			slots.append({"id": id, "cost": int(GameData.get_card(id).cost), "taken": -1})
	for i in int(rules.market_tools):
		var choices := tool_ids.filter(func(t): return not shown.has(t))
		if not choices.is_empty():
			var id: String = choices[dice.randi_range(0, choices.size() - 1)]
			shown.append(id)
			slots.append({"id": id, "cost": int(GameData.get_card(id).cost), "taken": -1})
	return slots


## A random animal, rarer ones less often. Each rarity's weight in
## draft_rules is shared among its animals.
func _weighted_pick(ids: Array, exclude: Array, dice: RandomNumberGenerator) -> String:
	var per_rarity := {}
	for id in ids:
		var rarity: String = GameData.get_card(id).rarity
		per_rarity[rarity] = int(per_rarity.get(rarity, 0)) + 1
	var weights: Dictionary = rules.rarity_weights
	var total := 0.0
	for id in ids:
		if not exclude.has(id):
			var rarity: String = GameData.get_card(id).rarity
			total += float(weights.get(rarity, 0)) / per_rarity[rarity]
	var roll := dice.randf() * total
	for id in ids:
		if exclude.has(id):
			continue
		var rarity: String = GameData.get_card(id).rarity
		roll -= float(weights.get(rarity, 0)) / per_rarity[rarity]
		if roll <= 0.0:
			return id
	for id in ids:
		if not exclude.has(id):
			return id
	return ""


# --- Placing ---------------------------------------------------------------

## Animals start on their own half, at least START_GAP from the middle line.
static func can_start_at(team: int, y: int) -> bool:
	if team == 0:
		return y >= BattleSim.MIDDLE + START_GAP
	return y <= BattleSim.MIDDLE - START_GAP


## The first free starting spot for a new animal.
func default_spot(team: int) -> Vector2i:
	var fallback := Vector2i(-1, -1)
	for tiles in SPOTS:
		var spot := Vector2i(roundi(tiles.x * BattleSim.TILE), roundi(tiles.y * BattleSim.TILE))
		if team == 1:
			spot.y = BattleSim.HEIGHT - spot.y
		if fallback.x < 0:
			fallback = spot
		var free := true
		for entry in herds[team]:
			if Vector2(entry.x - spot.x, entry.y - spot.y).length() < 1.5 * BattleSim.TILE:
				free = false
		if free:
			return spot
	return fallback


## Moves a herd animal's starting spot, kept on its own half. False if it
## can't be moved now.
func move(team: int, index: int, x: int, y: int) -> bool:
	if phase != "place" or ready[team] or index < 0 or index >= herds[team].size():
		return false
	x = clampi(x, 500, BattleSim.WIDTH - 500)
	if team == 0:
		y = clampi(y, BattleSim.MIDDLE + START_GAP, BattleSim.HEIGHT - 500)
	else:
		y = clampi(y, 500, BattleSim.MIDDLE - START_GAP)
	herds[team][index].x = x
	herds[team][index].y = y
	_lay_out_herds()
	return true


## The herd entry of the animal standing nearest (x, y), or -1.
func herd_index_at(team: int, x: int, y: int) -> int:
	var best := -1
	var best_dist := 1.4 * BattleSim.TILE
	for f in sim.units(team):
		var d := Vector2(f.x - x, f.y - y).length()
		if d < best_dist:
			best = groups[team].find(int(f.memory.get("group", -1)))
			best_dist = d
	return best


func set_ready(team: int) -> void:
	if phase != "place":
		return
	ready[team] = true
	if ready[0] and ready[1]:
		_start_fight()


## Puts both herds on the field where they'll start, standing still, so the
## players can see them while they arrange them.
func _lay_out_herds() -> void:
	sim.clear_units()
	groups = [[], []]
	for team in 2:
		for index in herds[team].size():
			var entry: Dictionary = herds[team][index]
			var made := sim.spawn(team, entry.id, int(entry.x), int(entry.y))
			for member in made.size():
				var f: BattleSim.Fighter = made[member]
				f.deploy_ticks = 0
				apply_stars(f, int(entry.get("stars", 1)), rules)
				# For the screen only: the same animal keeps the same view when
				# the herds are laid out again, so it hops instead of popping in.
				f.memory.view_key = "%d/%d/%d" % [team, index, member]
			groups[team].append(int(made[0].memory.group) if not made.is_empty() else -1)
	sim.take_events()


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


func use_tool(team: int, index: int, x: int, y: int) -> bool:
	if phase != "fight" or index < 0 or index >= tools[team].size():
		return false
	var id: String = tools[team][index]
	var card := GameData.get_card(id)
	tools[team].remove_at(index)
	ToolEffects.use(sim, team, card, sim.level_of(team, id), clampi(x, 0, BattleSim.WIDTH), clampi(y, 0, BattleSim.HEIGHT))
	events.append({"type": "tool", "team": team, "id": id, "x": x, "y": y})
	return true


## Every animal comes to a fight in a mood: up to `pct` percent harder or
## softer bites for the whole fight. Moods are rolled at the whistle, after
## the bets, so nobody knows them while betting.
static func roll_moods(battle: BattleSim, dice: RandomNumberGenerator, pct: int) -> void:
	for f in battle.fighters:
		if f.is_unit():
			var mood := dice.randi_range(-pct, pct)
			f.damage = f.damage * (100 + mood) / 100
			f.memory.mood = mood


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
	rally_ready = [true, true]
	roll_moods(sim, rng, int(rules.get("mood_pct", 0)))
	_steal_acorns()
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


## Animals with "acorn_steal" (the Raccoon) take Acorns from the other
## player as the fight starts.
func _steal_acorns() -> void:
	_stolen = [0, 0]
	for team in 2:
		for entry in herds[team]:
			var ability: Dictionary = GameData.get_card(entry.id).get("ability", {})
			if ability.get("id", "") != "acorn_steal":
				continue
			var amount := mini(int(ability.get("params", {}).get("amount", 1)), acorns[1 - team])
			if amount <= 0:
				continue
			acorns[1 - team] -= amount
			acorns[team] += amount
			_stolen[team] += amount
			events.append({"type": "steal", "team": team, "id": entry.id, "amount": amount})


# --- Rounds ----------------------------------------------------------------

func _start_round() -> void:
	round_number += 1
	var bonus_team := -1
	if round_number > 1:
		for team in 2:
			acorns[team] += int(rules.acorns_per_round)
		if _last_loser >= 0:
			acorns[_last_loser] += int(rules.loser_bonus)
			bonus_team = _last_loser
	for team in 2:
		shops[team] = _roll_shop(team)
	_lay_out_herds()
	done_shopping = [false, false]
	ready = [false, false]
	phase = "draft"
	events.append({"type": "round", "round": round_number, "bonus_team": bonus_team, "bonus": int(rules.loser_bonus)})


func _start_placing() -> void:
	phase = "place"
	_lay_out_herds()
	events.append({"type": "place"})


func _end_round() -> void:
	var winner := judge(sim, wiped_at)
	var standing_now := [standing(0), standing(1)]
	var lost := [0, 0]
	if winner != NO_WINNER:
		var loser := 1 - winner
		lost[loser] = mini(hearts[loser], heart_loss(standing_now[winner]))
		hearts[loser] -= lost[loser]
		_last_loser = loser
	else:
		_last_loser = -1
	last_round = {
		"round": round_number, "winner": winner, "standing": standing_now,
		"hearts_lost": lost, "stolen": _stolen.duplicate(),
	}
	events.append({"type": "round_over", "winner": winner, "hearts_lost": lost})
	var out: bool = hearts[0] <= 0 or hearts[1] <= 0
	phase = "over" if out or round_number >= max_rounds() else "round_over"
	if phase == "over":
		events.append({"type": "match_over", "winner": match_winner()})


## From "round_over" to the next round's draft.
func next_round() -> void:
	if phase == "round_over":
		_start_round()
