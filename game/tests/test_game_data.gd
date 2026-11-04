extends TestCase


func test_data_files_have_no_problems() -> void:
	var problems := GameData.validate()
	check(problems.is_empty(), "GameData.validate() found problems:\n            " + "\n            ".join(problems))


func test_every_rarity_cages_drop_has_animals() -> void:
	var pools := GameData.cage_pools(GameData.arenas.size() - 1)
	for rarity in GameData.rarity_order:
		var dropped := GameData.cages.values().any(func(c): return float(c.weights.get(rarity, 0.0)) > 0.0)
		if dropped:
			check(not pools[rarity].is_empty(), "no animals of rarity %s" % rarity)


func test_starting_cards_fill_the_options() -> void:
	var cards: Array = GameData.progression.starting_cards
	var animals := cards.filter(func(id): return not GameData.is_tool(id))
	check(cards.size() >= int(GameData.draft_rules.offer_count), "enough cards to fill the options")
	check(animals.size() >= int(GameData.draft_rules.picks_per_round), "enough animals for round 1's picks")
	var classes := {}
	for id in animals:
		classes[GameData.class_of(id)] = true
	check_eq(classes.size(), animals.size(), "each starting animal is a different class")


func test_rarity_matches_conservation_status() -> void:
	var expected := {"common": ["LC", "NE"], "rare": ["NT", "VU"], "epic": ["EN"], "legendary": ["CR"]}
	for id in GameData.card_order:
		var card: Dictionary = GameData.cards[id]
		if card.kind == "animal" and card.rarity != "mythic":
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


func test_ranged_animals_have_known_shots() -> void:
	check(GameData.shots.has(ShotLooks.DEFAULT), "a default shot look")
	var later: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals_later.json"))
	for card in GameData.cards.values() + Array(later):
		if card.get("class", "") == "ranged" and card.has("shot"):
			check(GameData.shots.has(String(card.shot)), "%s's shot '%s' is in shots.json" % [card.id, card.shot])
	for card in Array(later):
		if card.get("class", "") == "ranged":
			check(card.has("shot"), "%s (on the way) has a shot" % card.id)
	check(not ShotLooks.look_for({"shot": "lightning"}).is_empty(), "looks are found by name")
	check_eq(ShotLooks.look_for({}), GameData.shots[ShotLooks.DEFAULT], "no shot: the default")
