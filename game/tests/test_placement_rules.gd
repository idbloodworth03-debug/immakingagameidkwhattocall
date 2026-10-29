extends TestCase


func _state(overrides := {}) -> Dictionary:
	var state := {
		"energy": 10.0, "elapsed": 0.0, "zone": "own_side", "allies": [],
		"deployed_count": 0, "allies_defeated": 0, "own_tower_damaged": false,
	}
	state.merge(overrides, true)
	return state


func _allowed(id: String, overrides := {}) -> bool:
	return PlacementRules.blocking_reasons(GameData.cards[id], _state(overrides)).is_empty()


func test_energy() -> void:
	check(_allowed("raccoon"), "plenty of energy")
	check(not _allowed("raccoon", {"energy": 2.9}), "raccoon costs 3")


func test_zones() -> void:
	check(not _allowed("raccoon", {"zone": "river"}), "land animals can't go in the river")
	check(not _allowed("raccoon", {"zone": "enemy_side"}), "not on the enemy side")
	check(_allowed("bullfrog", {"zone": "river"}), "aquatic animals may use the river")
	check(_allowed("bullfrog"), "aquatic animals may also use their own side")
	check(not _allowed("hippopotamus"), "hippo must use the river")
	check(_allowed("hippopotamus", {"zone": "river"}), "hippo in the river")


func test_allies_with_tag() -> void:
	check(not _allowed("lion"), "lion needs a savanna ally")
	check(_allowed("lion", {"allies": [GameData.cards.cheetah]}), "cheetah is a savanna animal")


func test_unique_and_no_allies() -> void:
	var wolf: Dictionary = GameData.cards.red_wolf
	var fox: Dictionary = GameData.cards.red_fox
	check(_allowed("red_wolf", {"allies": [fox]}), "red wolf with a canine ally")
	check(not _allowed("red_wolf", {"allies": [fox, wolf]}), "only one red wolf at a time")
	check(not _allowed("amur_leopard", {"allies": [GameData.cards.cheetah]}), "amur leopard won't share with big cats")
	check(_allowed("amur_leopard", {"allies": [fox]}), "amur leopard alone is fine")


func test_timing_and_history() -> void:
	check(not _allowed("tiger", {"elapsed": 59.0}), "tiger waits for 1:00")
	check(_allowed("tiger", {"elapsed": 60.0}), "tiger at 1:00")
	check(not _allowed("black_footed_ferret", {"deployed_count": 1}), "ferret needs two releases first")
	check(_allowed("black_footed_ferret", {"deployed_count": 2}), "ferret after two releases")
	check(not _allowed("asian_elephant"), "elephant needs a damaged tower")
	check(_allowed("asian_elephant", {"own_tower_damaged": true}), "elephant after tower damage")
	check(_allowed("california_condor", {"allies_defeated": 2}), "condor after two defeats")


func test_tools_go_anywhere() -> void:
	check(_allowed("net", {"zone": "enemy_side"}), "net on the enemy side")
	check(_allowed("net", {"zone": "river"}), "net on the river")
	check(not _allowed("food_bait", {"zone": "enemy_side"}), "bait only on your side")
	check(_allowed("food_bait"), "bait on your side")


func test_descriptions_read_well() -> void:
	check_eq(PlacementRules.describe({"type": "allies_with_tag", "tag": "canine", "count": 1}), "Needs 1 allied Canine on the field", "singular")
	check_eq(PlacementRules.describe({"type": "allies_with_tag", "tag": "jungle", "count": 2}), "Needs 2 allied Jungle animals on the field", "plural")
	check_eq(PlacementRules.describe({"type": "match_time", "seconds": 90}), "Available after 1:30 of battle", "clock")
