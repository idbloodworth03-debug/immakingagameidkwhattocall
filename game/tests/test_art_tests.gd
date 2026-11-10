extends TestCase
## Art tests (data/art_tests.json, made by tools/packs): animals from an
## outside art pack, tried out next to ours. They stay out of the roster
## until a dev shortcut asks for them, they fight exactly as the animal
## they play as (only their drawing is their own), and all their art is
## there: models in the flat-color look with a face of blendshapes, a
## portrait, and a sprite sheet timed like the animal they play as.

const ANIMATIONS := ["idle", "walk", "attack", "attack2", "special", "fidget", "victory"]

var _made: Array = []


func _host() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_child(tree.root.get_child_count() - 1)


func cleanup() -> void:
	for node in _made:
		if is_instance_valid(node):
			node.free()
	_made.clear()
	GameData.remove_art_tests()


func _ids() -> Array:
	return GameData.art_tests.get("animals", {}).keys()


func test_there_are_art_tests_and_they_play_as_real_animals() -> void:
	check(not _ids().is_empty(), "art_tests.json has art tests")
	for id: String in _ids():
		var like := GameData.plays_as(id)
		check(like != id and GameData.cards.has(like) and GameData.card_order.has(like), "%s plays as an animal in the game (%s)" % [id, like])


func test_art_tests_stay_out_of_the_game_until_asked_for() -> void:
	for id: String in _ids():
		check(not GameData.cards.has(id), "%s isn't a card until a dev shortcut asks for it" % id)
	GameData.install_art_tests()
	for id: String in _ids():
		check(GameData.cards.has(id), "%s is a card once asked for" % id)
		check(GameData.is_art_test(id), "%s is known as an art test" % id)
		check(not GameData.card_order.has(id), "%s is still not in the roster (collection, cages, drafts, bots)" % id)
	GameData.remove_art_tests()
	for id: String in _ids():
		check(not GameData.cards.has(id) and not GameData.bodies.animals.has(id), "%s is gone again" % id)


func test_an_art_test_is_a_copy_of_the_animal_it_plays_as() -> void:
	GameData.install_art_tests()
	var bodies: Dictionary = GameData.bodies.animals
	for id: String in _ids():
		var like := GameData.plays_as(id)
		var mine: Dictionary = GameData.cards[id]
		var theirs: Dictionary = GameData.cards[like]
		for key in ["kind", "class", "rarity", "cost", "stats", "ability", "shot", "habitat", "tags", "trait"]:
			check_eq(mine.get(key), theirs.get(key), "%s's %s is the %s's" % [id, key, like])
		for key in ["footprint", "width", "reach", "shooter", "across"]:
			check_eq(bodies[id].get(key), bodies[like].get(key), "%s's %s is the %s's" % [id, key, like])
		check_eq(GameData.styles.get(id), GameData.styles.get(like), "%s's attack style is the %s's" % [id, like])
		check_eq(GameData.class_of(id), GameData.class_of(like), "%s's class" % id)


## One fight to the end: `mine` against `theirs`, one squad each, every
## animal two levels above its start (an art test at the level of the
## animal it plays as).
func _fight(mine: Array, theirs: Array) -> DraftMatch:
	var levels := {}
	for id in GameData.card_order:
		levels[id] = GameData.start_level(GameData.cards[id].rarity) + 2
	var m := DraftMatch.new(31, {"levels": [levels.duplicate(), levels.duplicate()]})
	m.sim.level_art_tests()
	m.herds[0] = mine.map(func(id: String) -> Dictionary: return {"id": id, "stars": 1, "squads": 1})
	m.herds[1] = theirs.map(func(id: String) -> Dictionary: return {"id": id, "stars": 1, "squads": 1})
	for team in 2:
		m.picks_left[team] = 0
		m.picks_made[team] = []
	m.set_ready(0)
	m.set_ready(1)
	var guard := 0
	while m.phase == "fight" and guard < 100000:
		m.step()
		guard += 1
	return m


## The same fight twice, with the pack's animals and with ours in their
## places: everything happens the same, tick for tick.
func test_an_art_test_fights_exactly_like_the_animal_it_plays_as() -> void:
	GameData.install_art_tests()
	var ours := _ids().map(func(id: String) -> String: return GameData.plays_as(id))
	var against := ["wolf_pack", "raccoon", "harpy_eagle"]
	var a := _fight(ours, against)
	var b := _fight(_ids(), against)
	check(a.sim.tick > 0, "the fight ran")
	for id: String in _ids():
		check_eq(b.sim.level_of(0, id), a.sim.level_of(0, GameData.plays_as(id)), "%s fights at the %s's level" % [id, GameData.plays_as(id)])
	check_eq(b.sim.tick, a.sim.tick, "the fight lasts as long")
	check_eq(b.sim.checksum(), a.sim.checksum(), "everyone ends where they did, with the health they had")
	check_eq(b.wins, a.wins, "the same side wins")


func test_every_art_test_has_its_art() -> void:
	var faces: Dictionary = GameData.viewer.get("toon_look", {}).get("faces", {})
	check(not faces.is_empty(), "viewer.json toon_look maps the game's faces to blendshapes")
	for id: String in _ids():
		check(ResourceLoader.exists("res://art/units/%s/portrait.webp" % id), "%s has a card portrait" % id)
		check(FileAccess.file_exists("res://art/units/%s/sheet.json" % id), "%s has a sprite sheet" % id)
		check(AnimalViewer.has_model(id), "%s has a 3D viewer model" % id)
		check(ModelStage.has_model(id), "%s has a battle model" % id)
		check(ModelStage.tile_scale(id) > 0.0 and ModelStage.tile_scale(id) != 1.0, "%s's battle model has its size in models.json" % id)
		if not ModelStage.has_model(id):
			continue
		var root := (load("res://art/models/battle/%s.glb" % id) as PackedScene).instantiate()
		_made.append(root)
		check(ModelStage.is_toon(root), "%s's battle model is in the flat-color look" % id)
		var names := {}
		for mi: MeshInstance3D in ModelStage.toon_faces(root):
			for i in mi.get_blend_shape_count():
				names[String(mi.mesh.get_blend_shape_name(i))] = true
		for face: String in faces:
			var want: Dictionary = faces[face]
			var shapes: Array = want.get("cycle", want.keys())
			for shape in shapes:
				if shape == "per_second":
					continue
				check(names.has(shape), "%s's face can look %s (blendshape %s)" % [id, face if face != "" else "plain", shape])
		var players := root.find_children("*", "AnimationPlayer", true, false)
		check(not players.is_empty(), "%s's battle model is animated" % id)
		if players.is_empty():
			continue
		var player := players[0] as AnimationPlayer
		var like := GameData.plays_as(id)
		for anim in ANIMATIONS:
			var theirs := UnitSprites.animation(like, anim)
			var mine := UnitSprites.animation(id, anim)
			if theirs.is_empty():
				continue
			check(player.has_animation(anim), "%s's battle model has a %s" % [id, anim])
			check(not mine.is_empty(), "%s's sheet has a %s" % [id, anim])
			for key in ["frames", "fps", "loop", "hit"]:
				check_eq(mine.get(key), theirs.get(key), "%s's %s %s is the %s's" % [id, anim, key, like])


func test_an_art_test_is_drawn_in_the_flat_color_look() -> void:
	GameData.install_art_tests()
	var id: String = _ids()[0]
	var m := ModelStage.new_model(id, 1.5)
	check(m != null, "the battle model loaded")
	if m == null:
		return
	_made.append(m.pivot)
	check(m.toon and not m.movie, "it's the flat-color look")
	check_eq((m.skin.shader as Shader).resource_path.get_file(), "model_toon.gdshader", "drawn with the flat-color shader")
	check(m.outline_k > 1.0, "a bolder outline")
	check(not m.face_meshes.is_empty(), "its face has blendshapes")
	ModelStage.set_toon_face(m.face_meshes, "blink")
	var mi := m.face_meshes[0] as MeshInstance3D
	var blink := mi.find_blend_shape_by_name("eyes.blink")
	check(blink >= 0 and is_equal_approx(mi.get_blend_shape_value(blink), 1.0), "a blink closes its eyes")
	ModelStage.set_toon_face(m.face_meshes, "")
	check(is_zero_approx(mi.get_blend_shape_value(blink)), "and opens them again")
	ModelStage.set_toon_face(m.face_meshes, "dizzy", 0.0)
	var first := []
	for i in mi.get_blend_shape_count():
		first.append(mi.get_blend_shape_value(i))
	ModelStage.set_toon_face(m.face_meshes, "dizzy", 0.15)
	var later := []
	for i in mi.get_blend_shape_count():
		later.append(mi.get_blend_shape_value(i))
	check(first != later, "dizzy eyes spin")
	var viewer := AnimalViewer.new()
	viewer.animal_id = id
	_made.append(viewer)
	_host().add_child(viewer)
	viewer.load_model_now()
	check(viewer.model() != null, "the 3D viewer loaded it")
	if viewer.model() != null:
		var mesh := viewer.model().find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var skin := mesh.material_override as ShaderMaterial
		check(skin != null and (skin.shader as Shader).resource_path.get_file() == "model_toon.gdshader", "the viewer draws it in the flat-color look")
		check(skin != null and skin.next_pass != null, "with its outline")
