class_name TestCase
extends RefCounted
## Base class for tests. Every method whose name starts with "test_" is run
## by tests/test_runner.gd.

var failures: Array = []
var _borrowed: Array = []
var _listed: Array = []
var _tools_were: Dictionary = {}


## Called after each test. Override to free anything the test created.
func cleanup() -> void:
	pass


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


## Puts animals that are out of the game for now (data/animals_later.json)
## back into GameData for this test, to test abilities only they have.
## The test runner takes them out again afterwards.
func borrow_later_animals() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals_later.json"))
	for card in parsed:
		if GameData.cards.has(card.id):
			continue
		card["kind"] = "animal"
		card["unlock_arena_index"] = GameData.arena_index_by_id.get(card.unlock_arena, -1)
		GameData.cards[card.id] = card
		_borrowed.append(card.id)


## Puts a card's animals on the field round (x, y) as its class's squad is
## written (classes.json "squads": `units` animals at hp_pct and damage_pct
## of the card's each), whatever group its build brings in the game: for
## tests about who fights whom, laid out to the tile for those few animals.
func spawn_squad(sim: BattleSim, team: int, card_id: String, x: int, y: int) -> Array:
	var squad: Dictionary = GameData.class_rules.squads[GameData.class_of(card_id)]
	var count := int(squad.units)
	var made := sim.spawn_units(team, card_id, count, x, y)
	for i in made.size():
		var f: BattleSim.Fighter = made[i]
		var offset := BattleSim.formation(i, count)
		var room := maxf(1.0, float(2 * BattleSim.side_room(f) + BattleSim.TILE / 10) / 800.0)
		f.x = clampi(x + roundi(offset.x * room), f.radius, sim.width - f.radius)
		f.y = clampi(y + roundi(offset.y * room), f.radius, sim.height - f.radius)
		f.prev_x = f.x
		f.prev_y = f.y
		BattleArmy.apply_share(f, {"hp_share": int(squad.hp_pct) * 100, "damage_share": int(squad.damage_pct) * 100, "units": count}, 100)
	return made


## Puts the Ranger tools (data/tools.json; switched off for now:
## draft_rules.json offer_tools) back into GameData for this test, to test
## what they do; with `listed`, in the game's card list too (as when they're
## on). The test runner takes them out again afterwards.
func borrow_tools(listed := false) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/tools.json"))
	for card in parsed:
		if not GameData.cards.has(card.id):
			card["unlock_arena_index"] = GameData.arena_index_by_id.get(card.unlock_arena, -1)
			GameData.cards[card.id] = card
			_borrowed.append(card.id)
		if listed and not GameData.card_order.has(card.id):
			GameData.card_order.append(card.id)
			_listed.append(card.id)


## Switches the Ranger tools on for this test, as draft_rules.json
## offer_tools 2 does: the tools among the game's cards and in its card
## list, two offered in Draft Duel, the starting tools among the starting
## cards. The test runner switches them off again afterwards.
func turn_tools_on() -> void:
	borrow_tools(true)
	if _tools_were.is_empty():
		_tools_were = {"offer": GameData.draft_rules.offer_tools, "starters": GameData.progression.starting_cards}
	GameData.draft_rules.offer_tools = 2
	GameData.progression.starting_cards = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json")).starting_cards


func return_borrowed() -> void:
	for id in _borrowed:
		GameData.cards.erase(id)
	for id in _listed:
		GameData.card_order.erase(id)
	_borrowed.clear()
	_listed.clear()
	if not _tools_were.is_empty():
		GameData.draft_rules.offer_tools = _tools_were.offer
		GameData.progression.starting_cards = _tools_were.starters
		_tools_were = {}
