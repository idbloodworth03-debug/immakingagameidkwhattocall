class_name CageRules
extends RefCounted
## How cages are filled when opened. Cages are this game's loot boxes, and
## the app stores require showing the odds before anyone pays for one. So
## every number that affects the odds lives in data/cages.json, and `odds()`
## reports exactly the chances `roll()` uses.
##
## `pools` maps each rarity to the animal ids the player can get right now
## (see GameData.cage_pools). Locked rarities have an empty pool.


static func card_count(cage: Dictionary, arena_index: int) -> int:
	return int(cage.cards_base) + int(cage.get("cards_per_arena", 0)) * arena_index


static func gold_range(cage: Dictionary, arena_index: int) -> Vector2i:
	var bonus := int(cage.get("gold_per_arena", 0)) * arena_index
	return Vector2i(int(cage.gold_min) + bonus, int(cage.gold_max) + bonus)


## Percent chance (0-100) that each card rolled is of each rarity. If a
## rarity isn't unlocked yet, its chance goes to the best rarity below it that
## is (the same rule as guaranteed cards), so the odds always add up to 100.
static func odds(cage: Dictionary, pools: Dictionary, rarity_order: Array) -> Dictionary:
	var result := {}
	for rarity in rarity_order:
		result[rarity] = 0.0
	var total := 0.0
	var weights: Dictionary = cage.weights
	for rarity in weights:
		var index := _best_unlocked_index(rarity, pools, rarity_order)
		if index >= 0:
			result[rarity_order[index]] += float(weights[rarity])
			total += float(weights[rarity])
	for rarity in result:
		result[rarity] = 100.0 * result[rarity] / total if total > 0.0 else 0.0
	return result


## Guaranteed cards of each rarity. If a guaranteed rarity isn't unlocked
## yet, the guarantee moves down to the best rarity that is.
static func guaranteed(cage: Dictionary, pools: Dictionary, rarity_order: Array) -> Dictionary:
	var result := {}
	for rarity in rarity_order:
		result[rarity] = 0
	var promised: Dictionary = cage.get("guaranteed", {})
	for rarity in promised:
		var index := _best_unlocked_index(rarity, pools, rarity_order)
		if index >= 0:
			result[rarity_order[index]] += int(promised[rarity])
	return result


## Opens a cage. Returns { cage_id, gold, gems, cards: [{animal, rarity, count}] }
## with cards ordered from most common to rarest (best reveal last).
static func roll(cage: Dictionary, arena_index: int, pools: Dictionary, rarity_order: Array, rng: RandomNumberGenerator) -> Dictionary:
	var counts := guaranteed(cage, pools, rarity_order)
	var already_given := 0
	for rarity in counts:
		already_given += counts[rarity]

	var chances := odds(cage, pools, rarity_order)
	for i in maxi(0, card_count(cage, arena_index) - already_given):
		var rarity := _pick_rarity(chances, rarity_order, rng)
		if rarity != "":
			counts[rarity] += 1

	var cards := []
	var max_stacks := int(cage.get("max_stacks_per_rarity", 3))
	for rarity in rarity_order:
		if counts[rarity] > 0:
			cards.append_array(_split_into_stacks(rarity, counts[rarity], pools[rarity], max_stacks, rng))

	var gold := gold_range(cage, arena_index)
	return {
		"cage_id": cage.id,
		"gold": rng.randi_range(gold.x, gold.y),
		"gems": int(cage.get("gems", 0)),
		"cards": cards,
	}


## Gems to finish unlocking right away.
static func skip_cost_gems(seconds_left: float, cage: Dictionary) -> int:
	if seconds_left <= 0.0:
		return 0
	return maxi(1, ceili(seconds_left / 3600.0 * float(cage.get("skip_gems_per_hour", 6))))


## Index in `rarity_order` of `rarity`, or of the best unlocked rarity below it.
## -1 if nothing at or below it is unlocked.
static func _best_unlocked_index(rarity: String, pools: Dictionary, rarity_order: Array) -> int:
	var index := rarity_order.find(rarity)
	while index >= 0 and pools.get(rarity_order[index], []).is_empty():
		index -= 1
	return index


static func _pick_rarity(chances: Dictionary, rarity_order: Array, rng: RandomNumberGenerator) -> String:
	var pick := rng.randf() * 100.0
	var last := ""
	for rarity in rarity_order:
		var chance := float(chances.get(rarity, 0.0))
		if chance <= 0.0:
			continue
		last = rarity
		if pick < chance:
			return rarity
		pick -= chance
	return last  # only reached through floating point rounding


## Spreads `count` cards of one rarity over a few different animals.
static func _split_into_stacks(rarity: String, count: int, pool: Array, max_stacks: int, rng: RandomNumberGenerator) -> Array:
	var picks := pool.duplicate()
	# Shuffle with our own rng (not the global one) so tests can repeat results.
	for i in range(picks.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = picks[i]
		picks[i] = picks[j]
		picks[j] = swap

	var stack_count := mini(mini(count, picks.size()), maxi(1, max_stacks))
	var amounts := []
	for i in stack_count:
		amounts.append(1)
	for i in count - stack_count:
		amounts[rng.randi_range(0, stack_count - 1)] += 1

	var stacks := []
	for i in stack_count:
		stacks.append({"animal": picks[i], "rarity": rarity, "count": amounts[i]})
	return stacks
