class_name DraftBot
extends RefCounted
## The computer opponent in Draft Duel. It picks (its starters, then three
## picks a round from its own options), and in the fight it rallies and uses
## its tools, all through DraftMatch's public calls, so it follows the same
## rules as a person.
##
## `difficulty` (0 = first arena, 1 = top arena) sets how well it picks (less
## random, more attention to counters) and how quickly and how well it uses
## tools. `style` is a Rival Ranger's personality (rivals.json): a favorite
## class it picks more of, and how much (0 to 1, 0.5 = ordinary) it likes
## adding stars over new animals, and likes tools.

const T := BattleSim.TILE
## How much more it wants an animal of its favorite class.
const FAVORITE_BONUS := 1.5

var duel: DraftMatch
var team := 1
var rng := RandomNumberGenerator.new()
var difficulty := 0.5
var style: Dictionary = {}
var _tool_wait := 0


func _init(draft_match: DraftMatch, bot_team: int, seed_value: int, bot_difficulty := 0.5, bot_style: Dictionary = {}) -> void:
	duel = draft_match
	team = bot_team
	rng.seed = seed_value
	difficulty = clampf(bot_difficulty, 0.0, 1.0)
	style = bot_style
	_tool_wait = _reaction()


## A rival's deck: `size` animals from `available` (what's unlocked up to
## its arena) that fit its personality: a few of its favorite class
## (draft_rules.json bot "deck_favorite"), then at least one of every other
## class, the rest its strongest picks. Tougher rivals (higher
## `difficulty`) lean toward stronger cards; there's always some luck.
static func build_deck(available: Array, bot_style: Dictionary, rng: RandomNumberGenerator, difficulty := 0.5, size := 8) -> Array:
	var weights: Dictionary = GameData.draft_rules.get("bot", {})
	var favorite := String(bot_style.get("favorite", ""))
	var animals: Array = available.filter(func(id): return not GameData.is_tool(id))
	var score := func(id: String) -> float:
		return float(GameData.get_card(id).get("cost", 4)) * difficulty + rng.randf() * 3.0
	var by_class := {}
	for id in animals:
		var cls := GameData.class_of(id)
		if not by_class.has(cls):
			by_class[cls] = []
		by_class[cls].append({"id": id, "score": score.call(id)})
	for cls in by_class:
		by_class[cls].sort_custom(func(a, b): return a.score > b.score)
	var deck := []
	var take := func(cls: String, count: int) -> void:
		for entry in by_class.get(cls, []):
			if count <= 0 or deck.size() >= size:
				return
			if not deck.has(entry.id):
				deck.append(entry.id)
				count -= 1
	if favorite != "":
		take.call(favorite, int(weights.get("deck_favorite", 3)))
	for cls in GameData.class_order:
		take.call(cls, 1)
	# The rest: the best of what's left, from any class.
	var rest := []
	for cls in by_class:
		for entry in by_class[cls]:
			if not deck.has(entry.id):
				rest.append(entry)
	rest.sort_custom(func(a, b): return a.score > b.score)
	for entry in rest:
		if deck.size() >= size:
			break
		deck.append(entry.id)
	return deck


## A rival's deck of `size`: from the animals unlocked up to its arena
## (topped up from the starting cards, then the earliest arenas' animals,
## where too few are unlocked yet), leaning to its favorite class
## (build_deck).
static func rival_deck(arena_index: int, bot_style: Dictionary, rng: RandomNumberGenerator, difficulty := 0.5, size := 8, banned: Array = []) -> Array:
	var unlocked: Array = GameData.card_order.filter(func(id): return not GameData.is_tool(id) and not banned.has(id) and int(GameData.cards[id].unlock_arena_index) <= arena_index)
	if unlocked.size() < size:
		var more: Array = GameData.progression.get("starting_cards", []).duplicate()
		var by_arena: Array = GameData.card_order.duplicate()
		by_arena.sort_custom(func(a, b): return int(GameData.cards[a].unlock_arena_index) < int(GameData.cards[b].unlock_arena_index))
		more.append_array(by_arena)
		for id in more:
			if unlocked.size() >= size:
				break
			if not GameData.is_tool(id) and not unlocked.has(id) and not banned.has(id):
				unlocked.append(id)
	return build_deck(unlocked, bot_style, rng, difficulty, size)


## A personality trait from `style`, from -0.5 to 0.5 (0 = ordinary).
func _lean(trait_name: String) -> float:
	return clampf(float(style.get(trait_name, 0.5)), 0.0, 1.0) - 0.5


# --- Picking -------------------------------------------------------------------

## Makes one pick (the one it wants most), or says it's ready when it has
## none left. Call it again until it's ready.
func pick() -> void:
	if duel.phase != "pick" or duel.ready[team]:
		return
	if not duel.has_any_pick(team):
		duel.set_ready(team)
		return
	var best_score := -1000.0
	var best_action := Callable()
	for slot in duel.offers[team].size():
		if duel.can_pick(team, slot) != "":
			continue
		var score := _offer_value(duel.offers[team][slot].id)
		if score > best_score:
			best_score = score
			var replace := _weakest_tool() if duel.needs_tool_swap(team, slot) else -1
			best_action = duel.pick.bind(team, slot, replace)
	# Or, for an animal in its army: an upgrade or another squad.
	for index in duel.herds[team].size():
		if duel.can_star(team, index) == "":
			var score := _star_value(index)
			if score > best_score:
				best_score = score
				best_action = duel.star.bind(team, index)
		if duel.can_reinforce(team, index) == "":
			var score := _reinforce_value(String(duel.herds[team][index].id))
			if score > best_score:
				best_score = score
				best_action = duel.reinforce.bind(team, index)
	if best_action.is_valid():
		best_action.call()
	else:
		duel.set_ready(team)


## Makes all of this round's picks at once (tests and reports).
func pick_all() -> void:
	var guard := 0
	while duel.phase == "pick" and not duel.ready[team] and guard < 20:
		pick()
		guard += 1


## How much it wants an offered card. Every pick costs the same, so what
## matters most is what its herd needs against yours (counters, and classes
## it doesn't have yet); a card's power ("cost" in animals.json) only tips
## the balance. Tools are worth more once its herd is big enough to use them.
func _offer_value(id: String) -> float:
	var weights: Dictionary = GameData.draft_rules.get("bot", {})
	var noise := rng.randf() * lerpf(3.0, 0.8, difficulty)
	if GameData.is_tool(id):
		var full: bool = duel.tools[team].size() >= int(duel.rules.tools_max)
		if full:
			return float(weights.get("tool_swap", 1.0)) + noise
		var herd_bonus := minf(float(duel.herds[team].size()) * float(weights.get("tool_per_animal", 0.25)), 2.0)
		return float(weights.get("tool", 4.0)) + herd_bonus + _lean("tools") * 4.0 + noise
	var index := duel.herd_index(team, id)
	var cls := GameData.class_of(id)
	if index >= 0:
		return _reinforce_value(id)
	var value := float(weights.get("new_animal", 5.0)) + _power(id) + _class_need(cls) + noise
	if not _class_counts(team).has(cls):
		value += float(weights.get("new_class", 1.5))
	if String(style.get("favorite", "")) == cls:
		value += FAVORITE_BONUS
	if duel.is_first_round():
		# Starters: a spread of classes beats three of a kind.
		for entry in duel.herds[team]:
			if GameData.class_of(entry.id) == cls:
				value -= 2.0 * (0.4 + difficulty)
	return value


## How much another squad of an animal in its army is worth: like a new
## animal of its class, without the bonus for a class it hasn't got; less
## for those who like stars.
func _reinforce_value(id: String) -> float:
	var weights: Dictionary = GameData.draft_rules.get("bot", {})
	var noise := rng.randf() * lerpf(3.0, 0.8, difficulty)
	return float(weights.get("squad", 4.6)) + _power(id) + _class_need(GameData.class_of(id)) + _lean("stars") * -2.0 + noise


## A card's power, centered on an ordinary card, as a small nudge.
func _power(id: String) -> float:
	var weights: Dictionary = GameData.draft_rules.get("bot", {})
	return (float(GameData.get_card(id).cost) - 4.5) * float(weights.get("power", 0.6)) * lerpf(0.6, 1.0, difficulty)


## How much an upgrade (a star for every squad) of herd animal `index` is
## worth: about a new animal's worth for its power, more the more squads it
## has, more for one that counters the other herd, and more for those who
## like stars.
func _star_value(index: int) -> float:
	var weights: Dictionary = GameData.draft_rules.get("bot", {})
	var id: String = duel.herds[team][index].id
	var squads := int(duel.herds[team][index].get("squads", 1))
	var value := float(weights.get("star", 4.0)) + _power(id) * 1.5 + maxf(0.0, _class_need(GameData.class_of(id))) * 0.5
	value += float(weights.get("star_per_squad", 0.6)) * (squads - 1)
	value += _lean("stars") * 4.0
	return value + rng.randf() * lerpf(2.0, 0.5, difficulty)


## How much its herd needs a class right now, against the other herd:
## Tank Destroyers when they have Tanks, Ranged when they have Air, Air when
## they have Tank Destroyers, a Tank to shield its own Ranged. Sharper
## opponents pay more attention.
func _class_need(cls: String) -> float:
	var theirs := _class_counts(1 - team)
	var mine := _class_counts(team)
	var need := 0.0
	match cls:
		"tank_destroyer":
			need = 0.8 * int(theirs.get("tank", 0)) - 0.3 * int(mine.get("tank_destroyer", 0))
		"ranged":
			need = 1.2 * int(theirs.get("air", 0)) - 0.3 * int(mine.get("ranged", 0)) + 0.6
		"air":
			need = 0.8 * int(theirs.get("tank_destroyer", 0)) - 0.8 * int(theirs.get("ranged", 0)) - 0.3 * int(mine.get("air", 0))
		"tank":
			need = 0.7 * int(mine.get("ranged", 0)) - 0.4 * int(mine.get("tank", 0)) + 0.8
		"specialist":
			need = 0.8 - 0.4 * int(mine.get("specialist", 0))
	return clampf(need, -2.0, 4.0) * lerpf(0.4, 1.0, difficulty)


## How many squads of each class a herd has: its own as it is now, the other's as
## it was when this round's picking started (a person can't see the other's
## new picks either).
func _class_counts(side: int) -> Dictionary:
	var counts := {}
	for entry in (duel.herds[side] if side == team else duel.herds_seen[side]):
		var cls := GameData.class_of(entry.id)
		counts[cls] = int(counts.get(cls, 0)) + int(entry.get("squads", 1))
	return counts


## The tool it would give up for a new one: the commonest.
func _weakest_tool() -> int:
	var weakest := 0
	for i in duel.tools[team].size():
		if GameData.rarity_rank(GameData.get_card(duel.tools[team][i]).rarity) < GameData.rarity_rank(GameData.get_card(duel.tools[team][weakest]).rarity):
			weakest = i
	return weakest


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
		if not bool(duel.tools_ready[team][i]):
			continue
		var aim := _aim(duel.tools[team][i])
		if not aim.is_empty():
			duel.use_tool(team, i, aim.x, aim.y)
			return


## When to blow the War Horn (it rouses the whole army): once at least a
## third of its army (and two or more) is in the thick of it. Where its
## animals are fighting hardest, or {} for not yet.
func _rally_spot() -> Dictionary:
	var mine := duel.sim.units(team)
	var fighting := mine.filter(func(f): return f.target != null and f.target.is_unit() and duel.sim.in_range(f, f.target))
	if fighting.size() < maxi(2, mine.size() / 3):
		return {}
	return _best_cluster(fighting, 3 * T, func(_f): return 1.0)


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
			var near := enemies.filter(func(f): return duel.sim.on_own_half(team, f.y))
			var lure := _best_cluster(near, radius, func(f): return float(f.card.cost) / int(f.memory.get("squad_units", 1)))
			if float(lure.get("value", 0)) < 4.0:
				return {}
			# Drop it just ahead of them, toward our herd: they stop to eat
			# while our animals get at them.
			var ahead := -2 * T if team == 1 else 2 * T
			return {"x": lure.x, "y": clampi(lure.y + ahead, 0, duel.sim.height)}
		_:
			var hit := _best_cluster(enemies, radius, func(f): return float(f.card.cost) / int(f.memory.get("squad_units", 1)))
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
