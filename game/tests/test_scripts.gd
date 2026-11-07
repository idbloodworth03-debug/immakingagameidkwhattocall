extends TestCase
## Every script under res://scripts loads and parses. The main menu is never
## built by the other tests, so a script it alone depends on could break
## without them noticing (as a reference to a class that didn't exist did).


func test_every_script_parses() -> void:
	var paths: Array = []
	_walk("res://scripts", paths)
	check(paths.size() > 50, "found the scripts (%d)" % paths.size())
	for path in paths:
		var script := load(path) as GDScript
		check(script != null and script.can_instantiate(), "%s parses" % path)


func _walk(dir_path: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var path := dir_path.path_join(name)
		if dir.current_is_dir():
			_walk(path, out)
		elif name.ends_with(".gd"):
			out.append(path)
		name = dir.get_next()
	dir.list_dir_end()
