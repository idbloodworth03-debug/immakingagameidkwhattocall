extends TestCase
## Arena life (scripts/fx/arena_life.gd, data/arena_life.json): everything
## stands outside the fence, every animal in it has its crowd strip, it's
## drawn under the fighters, and big moments make the crowd cheer.

var _made: Array = []


func _host() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_child(tree.root.get_child_count() - 1)


func cleanup() -> void:
	for node in _made:
		if is_instance_valid(node):
			node.free()
	_made.clear()


func _outside(x: float, t: float) -> bool:
	return t < -0.25 or t > 20.25 or x < -0.25 or x > 16.25


func test_everything_stands_outside_the_fence() -> void:
	var specs := ArenaLife.all_specs()
	for arena in specs:
		if String(arena).begins_with("_"):
			continue
		for actor in specs[arena].get("actors", []):
			if actor.has("at"):
				check(_outside(float(actor.at[0]), float(actor.at[1])) or String(actor.kind) == "sign",
					"%s: the %s stands outside the fence" % [arena, actor.kind])
			if actor.has("path"):
				for p in actor.path:
					check(_outside(float(p[0]), float(p[1])) or absf(float(p[1]) + 0.3) < 0.01, "%s: the runner keeps to the fence or beyond" % arena)
			if String(actor.kind) == "aurora":
				check(float(actor.from) < 0.0 and float(actor.to) < 0.0, "%s: the lights are behind the far fence" % arena)
		for piece in specs[arena].get("pieces", []):
			check(_outside(float(piece[1]), float(piece[2])), "%s: the %s is outside the fence" % [arena, piece[0]])


func test_every_animal_has_its_crowd_strip() -> void:
	var specs := ArenaLife.all_specs()
	for arena in specs:
		if String(arena).begins_with("_"):
			continue
		for actor in specs[arena].get("actors", []):
			if actor.has("animal"):
				var animal := String(actor.animal)
				check(ResourceLoader.exists("res://art/arenas/crowd/%s.webp" % animal), "%s has a crowd strip" % animal)
				check(FileAccess.file_exists("res://art/arenas/crowd/%s.json" % animal), "%s's strip says where its frames are" % animal)


func test_life_is_drawn_under_the_animals_and_cheers() -> void:
	var field := BattleField.new()
	field.arena_id = "rescue_center"
	field.size = Vector2(720, 1300)
	_made.append(field)
	_host().add_child(field)
	field._keep_life()
	var life: ArenaLife = field._life
	check(life != null and life.has_life(), "the Rescue Center has life")
	if life == null:
		return
	check(life.get_index() < field._units.get_index(), "drawn before (under) the animals")
	check(life.get_index() > field._arena.get_index(), "and over the arena's picture")
	life.cheer(8.0, 1.0)
	var cheering := 0
	for actor in life._actors:
		if String(actor.kind) == "spectator" and float(actor.cheer_at) >= 0.0:
			cheering += 1
	check(cheering >= 5, "a big moment sets the whole crowd cheering (%d)" % cheering)
	var near: float = INF
	var far: float = -INF
	for actor in life._actors:
		if String(actor.kind) == "spectator":
			var delay := float(actor.cheer_at)
			if absf(float(actor.at[0]) - 8.0) < 3.0:
				near = minf(near, delay)
			if absf(float(actor.at[0]) - 8.0) > 5.0:
				far = maxf(far, delay)
	check(far > near, "in a wave from where it happened")


func test_a_tundra_and_a_plain_arena() -> void:
	var field := BattleField.new()
	field.arena_id = "frozen_tundra"
	_made.append(field)
	_host().add_child(field)
	field._keep_life()
	var kinds := {}
	for actor in field._life._actors:
		kinds[String(actor.kind)] = true
	check(kinds.has("aurora") and kinds.has("pouncer") and kinds.has("spectator"), "the Tundra has its lights, its fox and its crowd")
	var plain := ArenaLife.make(field, "no_such_arena")
	_made.append(plain)
	check(not plain.has_life(), "an arena without life draws nothing")
