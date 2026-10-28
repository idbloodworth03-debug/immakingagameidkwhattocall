extends TestCase

var settings := {"base": 30, "min_change": 20, "max_change": 40, "difference_divisor": 25}


func test_even_match_is_worth_base() -> void:
	check_eq(TrophyRules.change_for_match(1000, 1000, true, settings), 30, "even win")
	check_eq(TrophyRules.change_for_match(1000, 1000, false, settings), -30, "even loss")


func test_beating_a_stronger_player_pays_more() -> void:
	check_eq(TrophyRules.change_for_match(1000, 1100, true, settings), 34, "underdog win")
	check_eq(TrophyRules.change_for_match(1000, 1100, false, settings), -26, "underdog loss")
	check_eq(TrophyRules.change_for_match(1000, 3000, true, settings), 40, "capped at max")
	check_eq(TrophyRules.change_for_match(3000, 1000, true, settings), 20, "capped at min")


func test_arena_index() -> void:
	var arenas := GameData.arenas
	check_eq(TrophyRules.arena_index_for(0, arenas), 0, "0 trophies")
	check_eq(TrophyRules.arena_index_for(299, arenas), 0, "just below arena 2")
	check_eq(TrophyRules.arena_index_for(300, arenas), 1, "exactly arena 2")
	check_eq(TrophyRules.arena_index_for(999999, arenas), arenas.size() - 1, "top arena")


func test_trophy_floor_and_zero() -> void:
	var arenas := GameData.arenas
	check_eq(TrophyRules.trophies_after_match(310, 310, false, settings, arenas), 300, "floor keeps you in City Park")
	check_eq(TrophyRules.trophies_after_match(10, 10, false, settings, arenas), 0, "never below zero")
	var coast := int(GameData.get_arena(GameData.arena_index_by_id.coral_coast).min_trophies)
	check_eq(TrophyRules.trophies_after_match(coast + 5, coast + 5, false, settings, arenas), coast - 25, "no floor at Coral Coast")
