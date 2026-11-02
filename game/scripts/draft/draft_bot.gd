class_name DraftBot
extends RefCounted
## The computer opponent in Draft Duel. It picks starters, shops (buying,
## training and rerolling), places its herd, and rallies and uses its tools
## in the fight, all through DraftMatch's public calls, so it follows the
## same rules as a person.
##
## `difficulty` (0 = first arena, 1 = top arena) sets how well it shops
## (less random), and how quickly and how well it uses tools.
##
## `style` is a Rival Ranger's personality (rivals.json): a favorite habitat
## it builds toward, and how much (0 to 1, 0.5 = ordinary) it rerolls, saves
## Acorns, trains stars and likes tools. Without a style it plays ordinarily.

const T := BattleSim.TILE
## How much more it wants an animal from its favorite habitat.
const FAVORITE_BONUS := 1.5

var duel: DraftMatch
var team := 1
var rng := RandomNumberGenerator.new()
var difficulty := 0.5
var style: Dictionary = {}
var favorite := ""   # the habitat it likes, if the pool has enough of it
var _tool_wait := 0
var _rerolls := 0


func _init(draft_match: DraftMatch, bot_team: int, seed_value: int, bot_difficulty := 0.5, bot_style: Dictionary = {}) -> void:
	duel = draft_match
	team = bot_team
	rng.seed = seed_value
	difficulty = clampf(bot_difficulty, 0.0, 1.0)
	style = bot_style
	var wanted: String = style.get("favorite", "")
	var available := duel.pool.filter(func(id): return not GameData.is_tool(id) and Synergies.habitat_of(id) == wanted).size()
	# Not enough of it to build around: it plays like anyone else.
	favorite = wanted if available >= int(GameData.synergy_tiers[0]) else ""
	_tool_wait = _reaction()


## A personality trait from `style`, from -0.5 to 0.5 (0 = ordinary).
func _lean(trait_name: String) -> float:
	return clampf(float(style.get(trait_name, 0.5)), 0.0, 1.0) - 0.5


# --- Starters ------------------------------------------------------------

## Picks its starters: a few tries at random sets within the budget, keeping
## the one worth the most (with some noise, less at higher difficulty).
func pick_starters() -> void:
	if duel.phase != "starters" or duel.starters_picked[team]:
		return
	var animals: Array = duel.pool.filter(func(id): return not GameData.is_tool(id))
	var best: Array = []
	var best_score := -1.0
	for attempt in 40:
		var pick: Array = []
		var shuffled := animals.duplicate()
		for i in range(shuffled.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var held: String = shuffled[i]
			shuffled[i] = shuffled[j]
			shuffled[j] = held
		for id in shuffled:
			if pick.size() < int(duel.rules.starters) and duel.starter_problem(pick + [id]) == "":
				pick.append(id)
		var score := 0.0
		for id in pick:
			score += float(GameData.get_card(id).cost)
		# Starters that share a habitat give it a head start.
		for habitat in Synergies.active(pick.map(func(id): return {"id": id})):
			score += 2.5 * synergy_iq()
		for id in pick:
			if favorite != "" and Synergies.habitat_of(id) == favorite:
				score += FAVORITE_BONUS
		score += rng.randf() * lerpf(4.0, 1.0, difficulty)
		if score > best_score:
			best = pick
			best_score = score
	duel.pick_starters(team, best)


# --- Shopping --------------------------------------------------------------

## Makes one shopping decision: buys the card it wants most, trains an
## animal, rerolls, or finishes shopping. Call it again until it's done.
func shop() -> void:
	if duel.phase != "draft" or duel.done_shopping[team]:
		return
	var reserve := _reserve()
	var spendable: int = duel.acorns[team] - reserve
	var best_score := 1.5
	var best_action := Callable()
	for i in duel.shops[team].size():
		var item: Dictionary = duel.shops[team][i]
		if duel.can_buy(team, i) != "":
			continue
		var score := _want(item)
		# Dipping into the savings costs interest: only for a great buy.
		if int(item.cost) > spendable and score < float(item.cost) + 3.0:
			continue
		if score > best_score:
			best_score = score
			best_action = duel.buy.bind(team, i)
	for i in duel.herds[team].size():
		var price := duel.train_cost(team, i)
		if duel.can_train(team, i) != "" or price > spendable:
			continue
		var score := _train_value(i, price)
		if score > best_score:
			best_score = score
			best_action = duel.train.bind(team, i)
	# Only weak picks and Acorns to spare: try a fresh shop first. Rerollers
	# do it sooner, more often and on less spare change.
	var rerolls := _lean("rerolls")
	var max_rerolls := roundi(2.0 + rerolls * 4.0)
	var rich: bool = spendable - int(duel.rules.reroll_cost) >= roundi(4.0 - rerolls * 4.0)
	if _rerolls < max_rerolls and rich and best_score < 4.0 + rerolls * 3.0:
		_rerolls += 1
		duel.reroll(team)
		return
	if best_action.is_valid():
		best_action.call()
		return
	if _rerolls < max_rerolls and rich:
		_rerolls += 1
		duel.reroll(team)
		return
	_rerolls = 0
	duel.finish_shopping(team)


## Acorns it keeps back to earn interest: once its herd is decent and it
## isn't in danger, it holds on to whole steps of interest (5, 10, ... up to
## the cap). Sharper opponents save more steadily, and so do savers.
func _reserve() -> int:
	var herd: int = duel.herds[team].size()
	var hearts: int = duel.hearts[team]
	if herd < 3 or hearts <= int(duel.rules.hearts) / 3:
		return 0
	var saving := _lean("saving")
	var per := maxi(1, int(duel.rules.interest_per))
	var steps := mini(int(duel.rules.interest_cap), duel.acorns[team] / per)
	# Still building its herd: keep fewer steps.
	if herd < int(duel.rules.herd_max) - 1:
		steps = mini(steps, roundi(2.0 + saving * 2.0))
	return roundi(steps * clampf(0.3 + difficulty * 0.7 + saving * 0.8, 0.0, 1.0)) * per


## How much it wants a shop card. Pricier animals are stronger; a copy of
## one it has upgrades it, which matters most once the herd is full; and it
## wants one tool.
func _want(item: Dictionary) -> float:
	var cost := int(item.cost)
	var herd_size: int = duel.herds[team].size()
	var full := herd_size >= int(duel.rules.herd_max)
	var noise := rng.randf() * lerpf(3.0, 0.8, difficulty)
	if GameData.is_tool(item.id):
		var tools := _lean("tools")
		return (3.0 + 2.0 * difficulty + tools * 4.0 if duel.tools[team].is_empty() else 0.5 + maxf(0.0, tools) * 6.0) + noise
	if duel.merge_target(team, item.id) >= 0:
		# A star for the price of a copy: good value, and it saves a herd spot.
		return float(cost) * (1.3 if full or herd_size >= 4 else 0.8) * (1.0 + _lean("stars")) + noise
	# Early on, numbers matter more than size: two cheap animals can beat one big one.
	var size_need := 1.5 if herd_size < 4 else 0.0
	var liked := FAVORITE_BONUS if favorite != "" and Synergies.habitat_of(item.id) == favorite else 0.0
	return float(cost) + size_need + _synergy_value(item.id) + liked + noise


## How much `id` would help its herd's habitat synergies: a lot if it turns
## a tier on, a little if it gets one closer. Sharper opponents care more.
func _synergy_value(id: String) -> float:
	if GameData.is_tool(id):
		return 0.0
	for entry in duel.herds[team]:
		if entry.id == id:
			return 0.0  # a copy doesn't count again
	var habitat := Synergies.habitat_of(id)
	var have := int(Synergies.counts(duel.herds[team]).get(habitat, 0))
	var iq := synergy_iq()
	var before := Synergies.tier_for(have)
	var after := Synergies.tier_for(have + 1)
	if after > before:
		return (2.5 + after) * iq
	if Synergies.next_needed(have + 1) - (have + 1) <= 1:
		return 1.0 * iq
	return 0.3 * iq


## How much it builds around habitats: a little in the first arena, fully
## at the top.
func synergy_iq() -> float:
	return lerpf(0.3, 1.0, difficulty)


## How much it wants to train herd animal `index` for `price` Acorns: worth
## more once the herd is full, and for animals that cost more.
func _train_value(index: int, price: int) -> float:
	var cost := float(GameData.get_card(duel.herds[team][index].id).cost)
	var full: bool = duel.herds[team].size() >= int(duel.rules.herd_max)
	var value := cost * float(duel.rules.star_bonus_pct) / 100.0 * (2.0 if full else 1.0) * (1.0 + _lean("stars"))
	return value * 5.0 / maxf(5.0, float(price)) + rng.randf() * lerpf(2.0, 0.5, difficulty)


# --- Placing ---------------------------------------------------------------

## Arranges its herd: the tough animals in front, ranged ones at the back, the
## rest in between, leaning toward the lane where the enemy is strongest.
func place() -> void:
	if duel.phase != "place":
		return
	var herd: Array = duel.herds[team]
	var front := []
	var middle := []
	var back := []
	for i in herd.size():
		var card := GameData.get_card(herd[i].id)
		if float(card.stats.range) > 1.0:
			back.append(i)
		elif float(card.stats.hp) >= 1500.0:
			front.append(i)
		else:
			middle.append(i)
	var strong_left := _enemy_strength(true) >= _enemy_strength(false)
	var lanes := [4.0, 12.0, 8.0, 6.0, 10.0, 2.5, 13.5] if strong_left else [12.0, 4.0, 8.0, 10.0, 6.0, 13.5, 2.5]
	# Rows in tiles from the far end (team 1's side; team 0 mirrors them).
	var rows := [[front, 7.5], [middle, 5.5], [back, 3.5]]
	var slot := 0
	for row in rows:
		for i in row[0]:
			var x := roundi(float(lanes[slot % lanes.size()]) * T) + rng.randi_range(-300, 300)
			var y := roundi(float(row[1]) * T) + rng.randi_range(-300, 300)
			if team == 0:
				y = BattleSim.HEIGHT - y
			if not duel.move(team, i, x, y):
				var spot := duel.default_spot(team)
				duel.move(team, i, spot.x, spot.y)
			slot += 1
	duel.set_ready(team)


func _enemy_strength(left: bool) -> float:
	var total := 0.0
	for entry in duel.herds[1 - team]:
		if (int(entry.x) < BattleSim.WIDTH / 2) == left:
			total += float(GameData.get_card(entry.id).cost)
	return total


# --- Fighting --------------------------------------------------------------

## Call every fight tick. Now and then it looks for a good moment to rally
## or use a tool.
func update() -> void:
	if duel.phase != "fight":
		return
	_tool_wait -= 1
	if _tool_wait > 0:
		return
	_tool_wait = _reaction()
	if duel.rally_ready[team]:
		var spot := _rally_spot()
		if not spot.is_empty():
			duel.rally(team, spot.x, spot.y)
			return
	for i in duel.tools[team].size():
		var aim := _aim(duel.tools[team][i])
		if not aim.is_empty():
			duel.use_tool(team, i, aim.x, aim.y)
			return


## Where its animals are fighting hardest, once at least two are at it.
func _rally_spot() -> Dictionary:
	var fighting := duel.sim.units(team).filter(func(f): return f.target != null and f.target.is_unit() and duel.sim.in_range(f, f.target))
	var radius := roundi(float(duel.rules.rally.radius) * T)
	var best := _best_cluster(fighting, radius, func(_f): return 1.0)
	return best if float(best.get("value", 0)) >= 2.0 else {}


func _reaction() -> int:
	return roundi(lerpf(1.6, 0.4, difficulty) * 20) + rng.randi_range(0, 10)


## Where to use a tool, or {} if there's no good target yet.
func _aim(tool_id: String) -> Dictionary:
	var card := GameData.get_card(tool_id)
	var radius := roundi(float(card.stats.get("radius", 1.0)) * T)
	var enemies := duel.sim.units(1 - team)
	match card.ability.id:
		"medkit":
			var allies := duel.sim.units(team)
			var best := _best_cluster(allies, radius, func(f): return f.max_hp - f.hp)
			return best if float(best.get("value", 0)) >= 600.0 else {}
		"tranq_dart":
			var biggest: BattleSim.Fighter = null
			for f in enemies:
				if f.target != null and (biggest == null or f.max_hp > biggest.max_hp):
					biggest = f
			return {"x": biggest.x, "y": biggest.y} if biggest != null and biggest.max_hp >= 1000 else {}
		"bait":
			var near := enemies.filter(func(f): return BattleSim.on_own_half(team, f.y))
			var lure := _best_cluster(near, radius, func(f): return float(f.card.cost) / int(f.card.get("count", 1)))
			if float(lure.get("value", 0)) < 4.0:
				return {}
			# Drop it just ahead of them, toward our herd: they stop to eat
			# while our animals get at them.
			var ahead := -2 * T if team == 1 else 2 * T
			return {"x": lure.x, "y": clampi(lure.y + ahead, 0, BattleSim.HEIGHT)}
		_:
			var hit := _best_cluster(enemies, radius, func(f): return float(f.card.cost) / int(f.card.get("count", 1)))
			return hit if float(hit.get("value", 0)) >= lerpf(5.0, 3.5, difficulty) else {}


## The fighter whose surroundings (within `radius`) add up to the most
## `value_of`: {"x", "y", "value"}, or {} if there are none.
func _best_cluster(candidates: Array, radius: int, value_of: Callable) -> Dictionary:
	var best := {}
	for center in candidates:
		var value := 0.0
		for other in candidates:
			if BattleSim.dist(center, other) <= radius:
				value += float(value_of.call(other))
		if best.is_empty() or value > float(best.value):
			best = {"x": center.x, "y": center.y, "value": value}
	return best
