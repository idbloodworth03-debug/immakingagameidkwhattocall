class_name DraftMatch
extends RefCounted
## Draft Duel, the round-based mode. Each round has five parts:
##
##   1. Draft: cards sit face up at the Watering Hole (animals, a Ranger tool
##      and a face-down Mystery Crate). The players take turns buying one
##      with Acorns, or pass. Whoever lost the last round picks first.
##   2. Place: each player arranges their whole herd on their own side.
##      Nothing moves and there's no clock: this is the time to think.
##   3. Wager: the Bookie (see bookie.gd) posts the odds of the fight, and
##      each player may back their own herd at those odds. Long shots pay more.
##   4. Fight: the herds fight on their own (BattleSim does the fighting),
##      with some luck: every animal's mood, and every hit. Players can use
##      the tools they bought, and once a fight they can Rally the animals
##      around a spot.
##      At the halftime whistle the fight pauses for a round of betting on
##      the Pot.
##   5. Round over: the winner takes the Pot, and the Bookie pays winning
##      wagers. Dens keep their damage from round to round, so they're the
##      players' lives: lose your main den and you lose the match. After the
##      last round, whoever destroyed more dens wins (then: whoever has more
##      den health left).
##
## Acorns are the match's only money: spend them on animals and tools, or
## keep them to bet. Both players start with the same Acorns, and they're
## gone when the match ends. Every animal fights at its starting level, so
## the draft decides the match, not the collection.
##
## The Pot: both players put in an ante when the fight starts. At halftime
## the player (team 0) may raise or check, then the opponent; a raise must
## be called or folded. Folding ends the round at once: the folder loses the
## Pot, but their dens take no more damage this round. So the side that's
## ahead chooses: raise to win Acorns (and offer a way out), or check and let
## its herd at the dens. Which tools each player holds is hidden (only how
## many shows), so a raise can be a bluff.
##
## Like BattleSim, a match plays out the same way for the same seed and the
## same actions.

## Where new animals stand until they're moved, in tiles, for team 0 (team 1
## uses the same spots mirrored).
const SPOTS := [
	Vector2(4.5, 18.5), Vector2(13.5, 18.5), Vector2(9.0, 19.5),
	Vector2(6.5, 21.5), Vector2(11.5, 21.5), Vector2(9.0, 23.5),
	Vector2(3.0, 22.5), Vector2(15.0, 22.5),
]
## Spots in the river, for animals that must start there.
const RIVER_SPOTS := [Vector2(9.0, 15.0), Vector2(7.0, 15.0), Vector2(11.0, 15.0)]
const NO_WINNER := -1

var rules: Dictionary
var sim: BattleSim
var rng := RandomNumberGenerator.new()
## "draft", "place", "wager", "fight", "halftime", "round_over" or "over".
var phase := ""
var round_number := 0
var acorns := [0, 0]
## Each team's animals: {"id": String, "x": int, "y": int}, in field units.
var herds := [[], []]
## Each team's Ranger tools, by card id. Hidden from the other player.
var tools := [[], []]
## The Watering Hole: {"id", "cost", "mystery": bool, "taken": team or -1}.
var market: Array = []
var turn := 0
var passed := [false, false]
var ready := [false, false]
## Each player's Rally for this fight (true until used).
var rally_ready := [true, true]
var pot := 0
## The Bookie's chance that team 0 wins this round's fight (-1 until posted).
var line := -1.0
## Acorns each team has bet on its own herd this round (-1 until it decides).
var wagers := [-1, -1]
## While the halftime betting is open: {"turn": team to act, "raise": the
## raise waiting for an answer (0 when none), "raiser": team, "checks": int}.
var halftime := {}
var fight_tick := 0
var fight_ticks := 0
var halftime_ticks := 0
## The fight tick each herd was wiped out (-1 while it still stands).
var wiped_at := [-1, -1]
## Each team's total den health when the fight started.
var den_before := [0, 0]
## What happened last round: {"round", "winner", "pot", "dealt": [team 0's
## den damage dealt, team 1's], "folded": team or -1, "wagers": [int, int],
## "paid": [Acorns the Bookie paid each team, stake included]}.
var last_round: Dictionary = {}
## Things that happened, for the screen to show: buys, passes, bets, tools.
var events: Array = []
## The battle-field groups of each herd's animals, in herd order, so a tap on
## an animal finds its herd entry.
var groups := [[], []]
var _first_picker := 0


func _init(seed_value: int, draft_rules: Dictionary = {}) -> void:
	rules = draft_rules if not draft_rules.is_empty() else GameData.draft_rules
	rng.seed = seed_value
	var battle: Dictionary = GameData.battle_rules.duplicate(true)
	battle.merge(rules.get("battle", {}), true)
	sim = BattleSim.new([[], []], [{}, {}], seed_value, battle)
	fight_ticks = roundi(float(rules.fight_seconds) * sim.tps)
	halftime_ticks = roundi(float(rules.halftime_seconds) * sim.tps)
	acorns = [int(rules.acorns_start), int(rules.acorns_start)]
	_first_picker = rng.randi_range(0, 1)
	_start_round()


# --- Info ------------------------------------------------------------------

func is_over() -> bool:
	return phase == "over"


func rounds() -> int:
	return int(rules.rounds)


## Total den health a team has left.
static func den_health(battle: BattleSim, team: int) -> int:
	var total := 0
	for t in battle.towers(team):
		total += maxi(0, t.hp)
	return total


## Who won the match: 0, 1 or NO_WINNER (a draw). Only meaningful when over.
func match_winner() -> int:
	if sim.is_over():
		return sim.outcome if sim.outcome >= 0 else NO_WINNER
	var crowns := [sim.teams[0].towers_destroyed, sim.teams[1].towers_destroyed]
	if crowns[0] != crowns[1]:
		return 0 if crowns[0] > crowns[1] else 1
	var health := [den_health(sim, 0), den_health(sim, 1)]
	if health[0] != health[1]:
		return 0 if health[0] > health[1] else 1
	return NO_WINNER


## Who wins a round, judged on `battle` (the real fight or one of the
## Bookie's tries): the herd that outlasts the other; if both are standing at
## the bell, the one that did more den damage this round; then the one with
## more of its herd left. NO_WINNER if they're level.
static func judge(battle: BattleSim, wiped: Array, dens_at_start: Array) -> int:
	if battle.is_over():
		return battle.outcome if battle.outcome >= 0 else NO_WINNER
	if wiped[0] >= 0 or wiped[1] >= 0:
		if wiped[0] < 0:
			return 0
		if wiped[1] < 0:
			return 1
		if wiped[0] != wiped[1]:
			return 0 if wiped[0] > wiped[1] else 1
	var dealt := [dens_at_start[1] - den_health(battle, 1), dens_at_start[0] - den_health(battle, 0)]
	if dealt[0] != dealt[1]:
		return 0 if dealt[0] > dealt[1] else 1
	var left := [battle.herd_value(0), battle.herd_value(1)]
	if left[0] != left[1]:
		return 0 if left[0] > left[1] else 1
	return NO_WINNER


func take_events() -> Array:
	var taken := events
	events = []
	return taken


# --- Draft -----------------------------------------------------------------

## Why `team` can't buy market slot `slot` right now. Empty means it can.
func can_buy(team: int, slot: int) -> String:
	if phase != "draft":
		return "The draft is over"
	if turn != team or passed[team]:
		return "Not your turn"
	return _buy_problem(team, slot)


func _buy_problem(team: int, slot: int) -> String:
	if slot < 0 or slot >= market.size() or int(market[slot].taken) >= 0:
		return "Already taken"
	var item: Dictionary = market[slot]
	if acorns[team] < int(item.cost):
		return "Not enough Acorns"
	if GameData.is_tool(item.id):
		if tools[team].size() >= int(rules.tools_max):
			return "Your tool belt is full"
	elif herds[team].size() >= int(rules.herd_max):
		return "Your herd is full"
	return ""


func buy(team: int, slot: int) -> bool:
	if can_buy(team, slot) != "":
		return false
	var item: Dictionary = market[slot]
	acorns[team] -= int(item.cost)
	item.taken = team
	if GameData.is_tool(item.id):
		tools[team].append(item.id)
	else:
		var spot := default_spot(team, item.id)
		herds[team].append({"id": item.id, "x": spot.x, "y": spot.y})
		_lay_out_herds()
	events.append({"type": "buy", "team": team, "slot": slot, "id": item.id, "mystery": item.mystery})
	_next_turn()
	return true


## Done buying for this round.
func pass_turn(team: int) -> bool:
	if phase != "draft" or turn != team or passed[team]:
		return false
	passed[team] = true
	events.append({"type": "pass", "team": team})
	_next_turn()
	return true


func can_buy_anything(team: int) -> bool:
	for i in market.size():
		if _buy_problem(team, i) == "":
			return true
	return false


## Hands the turn to the other player, skipping anyone who has passed or
## can't buy anything. When nobody can go on, the draft ends.
func _next_turn() -> void:
	for i in 2:
		turn = 1 - turn
		if passed[turn]:
			continue
		if can_buy_anything(turn):
			return
		passed[turn] = true
		events.append({"type": "pass", "team": turn, "auto": true})
	_start_placing()


func _roll_market() -> Array:
	var slots := []
	var animals := []
	var tool_ids := []
	for id in GameData.card_order:
		if GameData.is_tool(id):
			tool_ids.append(id)
		else:
			animals.append(id)
	var shown := []
	for i in int(rules.market_animals):
		var id := _weighted_pick(animals, shown)
		if id != "":
			shown.append(id)
			slots.append({"id": id, "cost": int(GameData.get_card(id).cost), "mystery": false, "taken": -1})
	for i in int(rules.market_tools):
		var choices := tool_ids.filter(func(t): return not shown.has(t))
		if not choices.is_empty():
			var id: String = choices[rng.randi_range(0, choices.size() - 1)]
			shown.append(id)
			slots.append({"id": id, "cost": int(GameData.get_card(id).cost), "mystery": false, "taken": -1})
	for i in int(rules.mystery_crates):
		var id := _weighted_pick(animals, [])
		slots.append({"id": id, "cost": int(rules.mystery_cost), "mystery": true, "taken": -1})
	return slots


## A random animal, rarer ones less often. Each rarity's weight in
## draft_rules is shared among its animals.
func _weighted_pick(ids: Array, exclude: Array) -> String:
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
	var roll := rng.randf() * total
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

## Where an animal may stand at the start of a fight: on its own bank (not
## in a pocket won from the enemy), or in the river if it must start there.
func placement_problem(team: int, card_id: String, x: int, y: int) -> String:
	var card := GameData.get_card(card_id)
	var zone := "river"
	if y >= BattleSim.RIVER_BOTTOM:
		zone = "own_side" if team == 0 else "enemy_side"
	elif y <= BattleSim.RIVER_TOP:
		zone = "own_side" if team == 1 else "enemy_side"
	if PlacementRules.allowed_zones(card).has(zone):
		return ""
	if zone == "enemy_side":
		return "Start on your own side"
	return "%s can't start %s" % [card.name, "in the river" if zone == "river" else "on land"]


## The first free starting spot for a new animal.
func default_spot(team: int, card_id: String) -> Vector2i:
	var candidates: Array = SPOTS + RIVER_SPOTS
	var fallback := Vector2i(-1, -1)
	for tiles in candidates:
		var spot := Vector2i(roundi(tiles.x * BattleSim.TILE), roundi(tiles.y * BattleSim.TILE))
		if team == 1:
			spot.y = BattleSim.HEIGHT - spot.y
		if placement_problem(team, card_id, spot.x, spot.y) != "":
			continue
		if fallback.x < 0:
			fallback = spot
		var free := true
		for entry in herds[team]:
			if Vector2(entry.x - spot.x, entry.y - spot.y).length() < 1.5 * BattleSim.TILE:
				free = false
		if free:
			return spot
	return fallback


func move(team: int, index: int, x: int, y: int) -> bool:
	if phase != "place" or ready[team] or index < 0 or index >= herds[team].size():
		return false
	x = clampi(x, 500, BattleSim.WIDTH - 500)
	y = clampi(y, 500, BattleSim.HEIGHT - 500)
	if placement_problem(team, herds[team][index].id, x, y) != "":
		return false
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
		phase = "wager"
		_lay_out_herds()
		events.append({"type": "wager"})


## Puts both herds on the field where they'll start, standing still, so the
## players can see them while they arrange them.
func _lay_out_herds() -> void:
	sim.clear_units()
	groups = [[], []]
	for team in 2:
		for entry in herds[team]:
			var made := sim.spawn(team, entry.id, int(entry.x), int(entry.y))
			for f in made:
				f.deploy_ticks = 0
			groups[team].append(int(made[0].memory.group) if not made.is_empty() else -1)
	sim.take_events()


# --- Backing your herd -----------------------------------------------------

## Sets the Bookie's odds: `chance` is how likely team 0 is to win the fight.
func post_line(chance: float) -> void:
	if phase == "wager" and line < 0.0:
		line = clampf(chance, 0.0, 1.0)


## How much a winning bet of 1 Acorn on `team` pays back, stake included,
## in hundredths. Long shots pay more; the Bookie keeps a small edge.
func payout(team: int) -> int:
	var chance := line if team == 0 else 1.0 - line
	var fair := (1.0 - float(rules.bookie_edge)) / maxf(chance, 0.01)
	return roundi(clampf(fair, 1.1, float(rules.payout_max)) * 100.0)


## The most `team` may bet on its herd. Never so much it can't pay the
## ante, and nothing on a sure thing.
func max_wager(team: int) -> int:
	if phase != "wager" or line < 0.0 or wagers[team] >= 0:
		return 0
	var chance := line if team == 0 else 1.0 - line
	if chance > float(rules.no_bets_above):
		return 0
	return clampi(acorns[team] - int(rules.ante), 0, int(rules.wager_max))


## Bets `amount` Acorns (0 for no bet) on `team`'s own herd.
func wager(team: int, amount: int) -> bool:
	if phase != "wager" or line < 0.0 or wagers[team] >= 0 or amount < 0 or amount > max_wager(team):
		return false
	wagers[team] = amount
	acorns[team] -= amount
	events.append({"type": "bet", "team": team, "amount": amount})
	if wagers[0] >= 0 and wagers[1] >= 0:
		_start_fight()
	return true


# --- Fighting --------------------------------------------------------------

func step() -> void:
	if phase != "fight":
		return
	sim.step()
	fight_tick += 1
	for team in 2:
		if wiped_at[team] < 0 and sim.units(team).is_empty():
			wiped_at[team] = fight_tick
	if sim.is_over() or fight_tick >= fight_ticks or (wiped_at[0] >= 0 and wiped_at[1] >= 0):
		_end_round(-1)
	elif fight_tick == halftime_ticks and wiped_at[0] < 0 and wiped_at[1] < 0:
		phase = "halftime"
		halftime = {"turn": 0, "raise": 0, "raiser": -1, "checks": 0}
		events.append({"type": "halftime"})


func use_tool(team: int, index: int, x: int, y: int) -> bool:
	if phase != "fight" or index < 0 or index >= tools[team].size():
		return false
	var id: String = tools[team][index]
	var card := GameData.get_card(id)
	tools[team].remove_at(index)
	ToolEffects.use(sim, team, card, GameData.start_level(card.rarity), clampi(x, 0, BattleSim.WIDTH), clampi(y, 0, BattleSim.HEIGHT))
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
	var ante := int(rules.ante)
	for team in 2:
		var paid := mini(ante, acorns[team])
		acorns[team] -= paid
		pot += paid
	den_before = [den_health(sim, 0), den_health(sim, 1)]
	wiped_at = [-1, -1]
	for team in 2:
		if sim.units(team).is_empty():
			wiped_at[team] = 0
	fight_tick = 0
	phase = "fight"
	events.append({"type": "fight"})
	if wiped_at[0] >= 0 and wiped_at[1] >= 0:
		# Nobody has a herd: nothing to fight.
		_end_round(-1)


# --- Halftime betting ------------------------------------------------------

## The most `team` may raise right now (0 if it can't). A raise is never more
## than the other player can call.
func max_raise(team: int) -> int:
	if phase != "halftime" or int(halftime.turn) != team or int(halftime.raise) > 0:
		return 0
	return mini(int(rules.raise_max), mini(acorns[team], acorns[1 - team]))


func raise_pot(team: int, amount: int) -> bool:
	if amount < 1 or amount > max_raise(team):
		return false
	acorns[team] -= amount
	pot += amount
	halftime.raise = amount
	halftime.raiser = team
	halftime.turn = 1 - team
	events.append({"type": "raise", "team": team, "amount": amount})
	return true


func check(team: int) -> bool:
	if phase != "halftime" or int(halftime.turn) != team or int(halftime.raise) > 0:
		return false
	halftime.checks = int(halftime.checks) + 1
	events.append({"type": "check", "team": team})
	if int(halftime.checks) >= 2:
		_resume()
	else:
		halftime.turn = 1 - team
	return true


func call_raise(team: int) -> bool:
	if phase != "halftime" or int(halftime.turn) != team or int(halftime.raise) <= 0:
		return false
	var paid := mini(int(halftime.raise), acorns[team])
	acorns[team] -= paid
	pot += paid
	events.append({"type": "call", "team": team, "amount": paid})
	_resume()
	return true


## Gives up the round, in answer to a raise, to save your dens.
func fold(team: int) -> bool:
	if phase != "halftime" or int(halftime.turn) != team or int(halftime.raise) <= 0:
		return false
	events.append({"type": "fold", "team": team})
	halftime = {}
	_end_round(team)
	return true


func _resume() -> void:
	halftime = {}
	phase = "fight"


# --- Rounds ----------------------------------------------------------------

func _start_round() -> void:
	round_number += 1
	if round_number > 1:
		for team in 2:
			acorns[team] += int(rules.acorns_per_round)
	market = _roll_market()
	_lay_out_herds()
	passed = [false, false]
	ready = [false, false]
	line = -1.0
	wagers = [-1, -1]
	phase = "draft"
	events.append({"type": "round", "round": round_number, "first": _first_picker})
	turn = 1 - _first_picker
	_next_turn()


func _start_placing() -> void:
	phase = "place"
	_lay_out_herds()
	events.append({"type": "place"})


func _end_round(folder: int) -> void:
	var winner := 1 - folder if folder >= 0 else judge(sim, wiped_at, den_before)
	var paid := [0, 0]
	for team in 2:
		var stake := maxi(0, wagers[team])
		if winner == team:
			paid[team] = stake * payout(team) / 100
		elif winner == NO_WINNER:
			paid[team] = stake
		acorns[team] += paid[team]
	var won_pot := pot
	if winner != NO_WINNER:
		acorns[winner] += pot
		pot = 0
		_first_picker = 1 - winner
	else:
		won_pot = 0
		_first_picker = 1 - _first_picker
	last_round = {
		"round": round_number, "winner": winner, "pot": won_pot, "folded": folder,
		"dealt": [den_before[1] - den_health(sim, 1), den_before[0] - den_health(sim, 0)],
		"wagers": [maxi(0, wagers[0]), maxi(0, wagers[1])], "paid": paid,
	}
	events.append({"type": "round_over", "winner": winner, "pot": won_pot, "folded": folder})
	phase = "over" if sim.is_over() or round_number >= rounds() else "round_over"
	if phase == "over":
		events.append({"type": "match_over", "winner": match_winner()})


## From "round_over" to the next round's draft.
func next_round() -> void:
	if phase == "round_over":
		_start_round()
