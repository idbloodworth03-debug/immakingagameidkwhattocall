extends TestCase

var prog: Dictionary = GameData.progression


func test_upgrade_costs() -> void:
	check_eq(CardRules.copies_to_upgrade("common", 1, prog), 2, "common 1->2 copies")
	check_eq(CardRules.gold_to_upgrade(1, prog), 5, "1->2 gold")
	check_eq(CardRules.copies_to_upgrade("rare", 3, prog), 2, "rare 3->4 copies")
	check_eq(CardRules.copies_to_upgrade("epic", 6, prog), 2, "epic 6->7 copies")
	check_eq(CardRules.copies_to_upgrade("legendary", 9, prog), 2, "legendary 9->10 copies")


func test_every_rarity_can_reach_max_level() -> void:
	var max_level := int(prog.card_max_level)
	for rarity in GameData.rarity_order:
		for level in range(GameData.start_level(rarity), max_level):
			check(CardRules.copies_to_upgrade(rarity, level, prog) > 0, "%s level %d has no copy cost" % [rarity, level])
			check(CardRules.gold_to_upgrade(level, prog) > 0, "level %d has no gold cost" % level)


func test_max_level() -> void:
	var max_level := int(prog.card_max_level)
	check(CardRules.is_max_level(max_level, prog), "max level detected")
	check_eq(CardRules.copies_to_upgrade("common", max_level, prog), 0, "no cost at max")
	check(not CardRules.can_upgrade("common", max_level, 99999, 9999999, prog), "can't upgrade past max")


func test_can_upgrade_needs_copies_and_gold() -> void:
	check(CardRules.can_upgrade("common", 1, 2, 5, prog), "exactly enough")
	check(not CardRules.can_upgrade("common", 1, 1, 5, prog), "one copy short")
	check(not CardRules.can_upgrade("common", 1, 2, 4, prog), "one gold short")


func test_stats_grow_ten_percent_per_level() -> void:
	check_eq(CardRules.stat_at_level(100, 1, 1, 0.1), 100, "start level")
	check_eq(CardRules.stat_at_level(100, 2, 1, 0.1), 110, "one level up")
	check_eq(CardRules.stat_at_level(100, 11, 9, 0.1), 121, "legendary two levels up")
