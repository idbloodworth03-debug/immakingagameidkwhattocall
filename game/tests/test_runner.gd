extends Node
## Runs every tests/test_*.gd file and quits with exit code 1 if anything failed.
##
## From the repository root:
##   godot --headless --path game res://tests/test_runner.tscn

const TEST_DIR := "res://tests/"


func _ready() -> void:
	var total := 0
	var failed := 0
	for file_name in DirAccess.get_files_at(TEST_DIR):
		if not (file_name.begins_with("test_") and file_name.ends_with(".gd")) or file_name == "test_runner.gd" or file_name == "test_case.gd":
			continue
		var script: GDScript = load(TEST_DIR + file_name)
		for method in script.get_script_method_list():
			if not String(method.name).begins_with("test_"):
				continue
			var test: TestCase = script.new()
			test.call(method.name)
			test.cleanup()
			total += 1
			if test.failures.is_empty():
				print("  ok    %s.%s" % [file_name.get_basename(), method.name])
			else:
				failed += 1
				print("  FAIL  %s.%s" % [file_name.get_basename(), method.name])
				for failure in test.failures:
					print("          - " + failure)
	print("\n%d tests, %d failed" % [total, failed])
	get_tree().quit(1 if failed > 0 else 0)
