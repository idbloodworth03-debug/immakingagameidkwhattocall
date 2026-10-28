extends TestCase


func test_data_files_have_no_problems() -> void:
	var problems := GameData.validate()
	check(problems.is_empty(), "GameData.validate() found problems:\n            " + "\n            ".join(problems))


func test_every_rarity_has_animals() -> void:
	var pools := GameData.cage_pools(GameData.arenas.size() - 1)
	for rarity in GameData.rarity_order:
		check(not pools[rarity].is_empty(), "no animals of rarity %s" % rarity)


func test_first_arena_fills_a_deck() -> void:
	check(GameData.animals_in_arena(0).size() >= int(GameData.progression.deck_size), "first arena can't fill a deck")


func test_rarity_matches_conservation_status() -> void:
	var expected := {"common": ["LC"], "rare": ["NT", "VU"], "epic": ["EN"], "legendary": ["CR"]}
	for id in GameData.animal_order:
		var animal: Dictionary = GameData.animals[id]
		check(expected[animal.rarity].has(animal.status), "%s is %s but has status %s" % [id, animal.rarity, animal.status])


func test_every_arena_unlocks_something() -> void:
	for i in GameData.arenas.size():
		check(not GameData.animals_in_arena(i).is_empty(), "arena %s unlocks no animals" % GameData.arenas[i].id)
