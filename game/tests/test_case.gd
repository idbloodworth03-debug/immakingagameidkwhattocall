class_name TestCase
extends RefCounted
## Base class for tests. Every method whose name starts with "test_" is run
## by tests/test_runner.gd.

var failures: Array = []


## Called after each test. Override to free anything the test created.
func cleanup() -> void:
	pass


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
