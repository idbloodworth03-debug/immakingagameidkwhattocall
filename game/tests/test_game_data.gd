extends TestCase


func test_data_files_have_no_problems() -> void:
	var problems := GameData.validate()
	check(problems.is_empty(), "GameData.validate() found problems:\n            " + "\n            ".join(problems))


func test_every_rarity_has_animals() -> void:
	var pools := GameData.cage_pools(GameData.arenas.size() - 1)
	for rarity in GameData.rarity_order:
		check(not pools[rarity].is_empty(), "no animals of rarity %s" % rarity)


func test_first_arena_fills_the_watering_hole() -> void:
	var animals := GameData.cards_in_arena(0).filter(func(id): return not GameData.is_tool(id))
	check(animals.size() >= int(GameData.draft_rules.market_animals), "new players own enough animals for a draft")


func test_rarity_matches_conservation_status() -> void:
	var expected := {"common": ["LC"], "rare": ["NT", "VU"], "epic": ["EN"], "legendary": ["CR"]}
	for id in GameData.card_order:
		var card: Dictionary = GameData.cards[id]
		if card.kind == "animal":
			check(expected[card.rarity].has(card.status), "%s is %s but has status %s" % [id, card.rarity, card.status])


func test_every_arena_unlocks_something() -> void:
	for i in GameData.arenas.size():
		check(not GameData.cards_in_arena(i).is_empty(), "arena %s unlocks no animals" % GameData.arenas[i].id)


func test_feel_settings_load() -> void:
	for section in ["characters", "combat", "effects", "ui", "background"]:
		check(GameData.feel.has(section), "feel.json has a '%s' section" % section)
	check(Feel.num("combat", "hitstop_seconds", -1.0) >= 0.0, "hit-stop length is set")
	check(Feel.count("effects", "max_particles", 0) > 0, "a particle cap is set")
	check_eq(Feel.num("characters", "no_such_value", 1.5), 1.5, "missing values fall back to the default")
