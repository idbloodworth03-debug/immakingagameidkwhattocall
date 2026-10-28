extends TestCase

var profile: Node


func _init() -> void:
	profile = load("res://scripts/autoload/profile.gd").new()
	profile.autosave = false
	profile.reset()


func cleanup() -> void:
	profile.free()


func test_new_profile() -> void:
	check_eq(profile.get_deck().size(), 8, "full starting deck")
	check_eq(profile.found_count(), 8, "eight starter animals")
	check_eq(profile.get_trophies(), 0, "no trophies yet")
	check_eq(profile.cage_slot_state(0), "locked", "starter cage waiting")


func test_win_gives_trophies_and_cage() -> void:
	var result: Dictionary = profile.record_match(true, 0)
	check_eq(result.trophy_change, 30, "even win")
	check(result.cage_id != "", "got a cage")
	check_eq(profile.cage_slot_state(1), "locked", "cage went to the next free slot")


func test_full_slots_give_no_cage() -> void:
	for i in 3:
		profile.record_match(true, 0)
	var result: Dictionary = profile.record_match(true, 0)
	check_eq(result.cage_id, "", "no room left")
	check(result.slots_full, "slots_full flag set")


func test_reaching_a_new_arena() -> void:
	profile.data.trophies = 290
	var result: Dictionary = profile.record_match(true, 290)
	check(result.new_arena, "crossed 300 trophies")
	check_eq(profile.highest_arena(), 1, "highest arena updated")


func test_cage_unlock_flow() -> void:
	check(profile.start_cage_unlock(0), "start unlocking")
	check_eq(profile.cage_slot_state(0), "unlocking", "now unlocking")
	profile.record_match(true, 0)
	check(not profile.start_cage_unlock(1), "only one cage unlocks at a time")
	profile.time_offset = 3 * 3600 + 1
	check_eq(profile.cage_slot_state(0), "ready", "ready after three hours")
	var found_before: int = profile.found_count()
	var rewards: Dictionary = profile.open_cage_slot(0)
	check(not rewards.is_empty(), "opened")
	check_eq(profile.cage_slot_state(0), "empty", "slot freed")
	check(profile.found_count() >= found_before, "collection kept")


func test_skip_with_gems() -> void:
	var gems: int = profile.get_gems()
	var cost: int = profile.cage_skip_cost(0)
	check(cost > 0, "skipping costs gems")
	check(profile.skip_cage_unlock(0), "skipped")
	check_eq(profile.get_gems(), gems - cost, "gems spent")
	check_eq(profile.cage_slot_state(0), "ready", "ready right away")


func test_upgrade_card() -> void:
	var id: String = profile.get_deck()[0]
	check(not profile.can_upgrade(id), "no spare copies yet")
	profile.grant_rewards({"cards": [{"animal": id, "rarity": GameData.animals[id].rarity, "count": 50}]})
	var level: int = profile.card_level(id)
	var gold: int = profile.get_gold()
	var cost: Dictionary = profile.upgrade_cost(id)
	check(profile.upgrade_card(id), "upgraded")
	check_eq(profile.card_level(id), level + 1, "level went up")
	check_eq(profile.get_gold(), gold - int(cost.gold), "gold spent")
	check(profile.ranger_info().xp > 0 or profile.ranger_info().level > 1, "earned ranger xp")


func test_new_cards_are_flagged() -> void:
	var rewards := {"gold": 10, "cards": [{"animal": "tiger", "rarity": "epic", "count": 3}]}
	profile.grant_rewards(rewards)
	check(rewards.cards[0].is_new, "first tiger is new")
	check_eq(profile.card_copies("tiger"), 2, "first copy unlocks, the rest count toward upgrades")
	check(profile.is_card_new("tiger"), "shows NEW badge")


func test_deck_swap() -> void:
	var deck: Array = profile.get_deck()
	profile.set_deck_slot(0, deck[3])
	var after: Array = profile.get_deck()
	check_eq(after[0], deck[3], "moved into slot 0")
	check_eq(after[3], deck[0], "old card swapped out")


func test_daily_offers_are_stable() -> void:
	var a: Array = profile.daily_offers()
	var b: Array = profile.daily_offers()
	check_eq(a, b, "same offers all day")
	check(not a.is_empty(), "has offers")


func test_cosmetic_unlocks() -> void:
	var ember := GameData.find_by_id(GameData.banners, "ember")
	check(not profile.is_unlocked(ember), "ember needs level 5")
	profile.set_banner("ember")
	check(profile.data.banner != "ember", "can't equip a locked banner")
	var midnight := GameData.find_by_id(GameData.banners, "midnight")
	check(not profile.buy_cosmetic(midnight), "100 starting gems can't buy a 300 gem banner")
	profile.add_gems(300)
	check(profile.buy_cosmetic(midnight), "bought with enough gems")
	check(profile.is_unlocked(midnight), "now unlocked")
	profile.set_banner("midnight")
	check_eq(profile.data.banner, "midnight", "equipped")
