extends Node
## Runs every tests/test_*.gd file and quits with exit code 1 if anything failed.
##
## From the repository root:
##   godot --headless --path game res://tests/test_runner.tscn

const TEST_DIR := "res://tests/"


## Counts engine and script errors, so a test that crashes partway through
## (and so never reaches its failing check) still fails.
class ErrorCounter extends Logger:
	var errors := 0
	var last := ""

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		errors += 1
		last = "%s (%s:%d)" % [rationale if not rationale.is_empty() else code, file, line]


func _ready() -> void:
	var total := 0
	var failed := 0
	var error_counter := ErrorCounter.new()
	OS.add_logger(error_counter)
	for file_name in DirAccess.get_files_at(TEST_DIR):
		if not (file_name.begins_with("test_") and file_name.ends_with(".gd")) or file_name == "test_runner.gd" or file_name == "test_case.gd":
			continue
		var script: GDScript = load(TEST_DIR + file_name)
		if script == null or not script.can_instantiate():
			# The test file (or a script it uses) doesn't compile.
			total += 1
			failed += 1
			print("  FAIL  %s doesn't compile (see SCRIPT ERROR above)" % file_name)
			continue
		for method in script.get_script_method_list():
			if not String(method.name).begins_with("test_"):
				continue
			var test: TestCase = script.new()
			var errors_before := error_counter.errors
			test.call(method.name)
			test.cleanup()
			test.return_borrowed()
			if error_counter.errors > errors_before:
				test.failures.append("error while running: " + error_counter.last)
			total += 1
			if test.failures.is_empty():
				print("  ok    %s.%s" % [file_name.get_basename(), method.name])
			else:
				failed += 1
				print("  FAIL  %s.%s" % [file_name.get_basename(), method.name])
				for failure in test.failures:
					print("          - " + failure)
	print("\n%d tests, %d failed" % [total, failed])
	OS.remove_logger(error_counter)
	get_tree().quit(1 if failed > 0 else 0)
