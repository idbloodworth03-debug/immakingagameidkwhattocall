class_name TestCase
extends RefCounted
## Base class for tests. Every method whose name starts with "test_" is run
## by tests/test_runner.gd.

var failures: Array = []
var _borrowed: Array = []


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


func return_borrowed() -> void:
	for id in _borrowed:
		GameData.cards.erase(id)
	_borrowed.clear()
