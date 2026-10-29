extends TestCase


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _total_cards(rewards: Dictionary) -> int:
	var total := 0
	for stack in rewards.cards:
		total += int(stack.count)
	return total


func test_card_count_and_gold() -> void:
	for cage_id in GameData.cage_order:
		var cage: Dictionary = GameData.cages[cage_id]
		for arena in [0, 4, GameData.arenas.size() - 1]:
			var rewards := CageRules.roll(cage, arena, GameData.cage_pools(arena), GameData.rarity_order, _rng(arena * 31 + 7))
			check_eq(_total_cards(rewards), CageRules.card_count(cage, arena), "%s in arena %d card count" % [cage_id, arena])
			var gold := CageRules.gold_range(cage, arena)
			check(rewards.gold >= gold.x and rewards.gold <= gold.y, "%s gold in range" % cage_id)


func test_only_unlocked_animals_drop() -> void:
	var cage: Dictionary = GameData.cages.crystal
	for seed_value in 30:
		var rewards := CageRules.roll(cage, 0, GameData.cage_pools(0), GameData.rarity_order, _rng(seed_value))
		for stack in rewards.cards:
			check_eq(int(GameData.cards[stack.animal].unlock_arena_index), 0, "%s isn't unlocked in arena 1" % stack.animal)
			check_eq(GameData.cards[stack.animal].rarity, stack.rarity, "stack rarity matches animal")


func test_odds_add_up_and_skip_locked_rarities() -> void:
	for cage_id in GameData.cage_order:
		var odds := CageRules.odds(GameData.cages[cage_id], GameData.cage_pools(0), GameData.rarity_order)
		var total := 0.0
		for rarity in odds:
			total += odds[rarity]
		check(is_equal_approx(total, 100.0), "%s odds add up to 100 (got %f)" % [cage_id, total])
		check_eq(odds.get("legendary", 0.0), 0.0, "%s: no legendary odds in arena 1" % cage_id)


func test_guarantees_are_kept() -> void:
	var top := GameData.arenas.size() - 1
	var golden: Dictionary = GameData.cages.golden
	for seed_value in 20:
		var rewards := CageRules.roll(golden, top, GameData.cage_pools(top), GameData.rarity_order, _rng(seed_value))
		var epics := 0
		for stack in rewards.cards:
			if stack.rarity == "epic":
				epics += int(stack.count)
		check(epics >= 1, "golden cage always has an epic")


func test_guarantee_moves_down_when_rarity_locked() -> void:
	# The Sanctuary Cage promises a Legendary; before any are unlocked the
	# promise falls to the best rarity that is unlocked (Rare in arena 1).
	var result := CageRules.guaranteed(GameData.cages.sanctuary, GameData.cage_pools(0), GameData.rarity_order)
	check_eq(result.legendary, 0, "no legendary in arena 1")
	check_eq(result.rare, 1, "falls back to rare")


func test_same_seed_same_result() -> void:
	var cage: Dictionary = GameData.cages.iron
	var a := CageRules.roll(cage, 5, GameData.cage_pools(5), GameData.rarity_order, _rng(42))
	var b := CageRules.roll(cage, 5, GameData.cage_pools(5), GameData.rarity_order, _rng(42))
	check_eq(a, b, "rolls repeat with the same seed")


func test_stacks_respect_limit() -> void:
	var cage: Dictionary = GameData.cages.twig
	var top := GameData.arenas.size() - 1
	var rewards := CageRules.roll(cage, top, GameData.cage_pools(top), GameData.rarity_order, _rng(3))
	var per_rarity := {}
	for stack in rewards.cards:
		per_rarity[stack.rarity] = per_rarity.get(stack.rarity, 0) + 1
	for rarity in per_rarity:
		check(per_rarity[rarity] <= int(cage.max_stacks_per_rarity), "%s stacks within limit" % rarity)


func test_skip_cost() -> void:
	var cage: Dictionary = GameData.cages.twig
	check_eq(CageRules.skip_cost_gems(0, cage), 0, "ready cage is free")
	check_eq(CageRules.skip_cost_gems(60, cage), 1, "at least one gem")
	check_eq(CageRules.skip_cost_gems(3 * 3600, cage), 18, "three hours")
