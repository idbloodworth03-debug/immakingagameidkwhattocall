extends TestCase

var table := [0, 20, 50, 100]


func test_levels_from_xp() -> void:
	check_eq(AccountRules.level_info(0, table, 4), {"level": 1, "xp": 0, "xp_needed": 20}, "brand new")
	check_eq(AccountRules.level_info(19, table, 4), {"level": 1, "xp": 19, "xp_needed": 20}, "almost level 2")
	check_eq(AccountRules.level_info(20, table, 4), {"level": 2, "xp": 0, "xp_needed": 50}, "level 2")
	check_eq(AccountRules.level_info(75, table, 4), {"level": 3, "xp": 5, "xp_needed": 100}, "level 3")
	check_eq(AccountRules.level_info(99999, table, 4), {"level": 4, "xp": 99999 - 170, "xp_needed": 0}, "max level")
