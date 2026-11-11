extends TestCase
## The look of an animal's model, told by its mesh's name
## (docs/ART_DIRECTION.md). <id>_toon is a toy in the flat-color look (our
## own: tools/toys; or a pack's animal: tools/packs), drawn by
## model_toon.gdshader with its outline in the viewer and in battle, its
## face a small mesh of blendshapes. <id>_movie is the older animated-movie
## look (tools/creatures/movie.py, model_movie.gdshader), which no animal
## in the roster is on any more. Anything else keeps the first cartoon
## shader. The whole roster is toys.

var _made: Array = []


func _host() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_child(tree.root.get_child_count() - 1)


func cleanup() -> void:
	for node in _made:
		if is_instance_valid(node):
			node.free()
	_made.clear()


func _viewer(id: String) -> AnimalViewer:
	var viewer := AnimalViewer.new()
	viewer.animal_id = id
	_made.append(viewer)
	_host().add_child(viewer)
	viewer.load_model_now()
	return viewer


func _shader_name(material: Material) -> String:
	return (material as ShaderMaterial).shader.resource_path.get_file() if material is ShaderMaterial else ""


func test_the_yeti_has_its_own_animations() -> void:
	# Its pound lands at the sheet's hit time (the battle times strikes to
	# it), and the viewer can hold a pose for a screenshot (dev).
	check_eq(float(UnitSprites.animation("yeti", "attack").get("hit", 0.0)), 0.6, "the pound lands at 0.6 of the attack")
	var viewer := _viewer("yeti")
	if viewer.model() == null:
		check(false, "the model loaded")
		return
	for anim in ["idle", "fidget", "attack", "victory"]:
		check(viewer.model().find_children("*", "AnimationPlayer", true, false)[0].has_animation(anim), "it has a %s" % anim)
	viewer.pose_at("attack:0.6")
	var player: AnimationPlayer = viewer.model().find_children("*", "AnimationPlayer", true, false)[0]
	check_eq(player.assigned_animation, "attack", "holding the attack")
	check(not player.is_playing(), "paused")
	check(absf(player.current_animation_position - 0.6 * player.get_animation("attack").length) < 0.02, "at its hit")


func _roster() -> Array:
	var out := []
	for id: String in GameData.card_order:
		if not GameData.is_tool(id):
			out.append(id)
	return out


## Every animal in the roster is a toy, drawn by the toy shader with its
## dark outline, in the viewer and in battle.
func test_every_animal_is_a_toy_with_its_outline() -> void:
	var toys := 0
	for id: String in _roster():
		var viewer := _viewer(id)
		check(viewer.model() != null, "%s's model loaded" % id)
		if viewer.model() == null:
			continue
		check(ModelStage.is_toon(viewer.model()) and not ModelStage.is_movie(viewer.model()), "%s is a toy" % id)
		var mesh := viewer.model().find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		check_eq(_shader_name(mesh.material_override), "model_toon.gdshader", "%s drawn with the toy shader in the viewer" % id)
		check(mesh.material_override is ShaderMaterial and (mesh.material_override as ShaderMaterial).next_pass != null,
			"%s has its outline in the viewer" % id)
		var m := ModelStage.new_model(id, 1.5)
		check(m != null and m.toon and not m.movie and _shader_name(m.skin) == "model_toon.gdshader", "%s is a toy in battle" % id)
		if m != null:
			_made.append(m.pivot)
			check_eq(_shader_name(m.outline), "model_outline.gdshader", "%s has the dark outline in battle" % id)
			toys += 1
		cleanup()
	check_eq(toys, _roster().size(), "every animal in the roster is a toy")


## A model is told to be a toy or on the movie look by its mesh's name
## (<id>_toon, <id>_movie); one with neither keeps the first cartoon look.
func test_a_look_is_told_by_the_mesh_name() -> void:
	var looks := {"red_fox": [false, false], "red_fox_movie": [true, false], "red_fox_toon": [false, true]}
	for mesh_name: String in looks:
		var root := Node3D.new()
		var mesh := MeshInstance3D.new()
		mesh.name = mesh_name
		root.add_child(mesh)
		_made.append(root)
		check_eq(ModelStage.is_movie(root), looks[mesh_name][0], "a mesh named %s: the movie look" % mesh_name)
		check_eq(ModelStage.is_toon(root), looks[mesh_name][1], "a mesh named %s: a toy" % mesh_name)


## A toy's face is a small mesh of blendshapes beside its body, with every
## face the game shows (viewer.json "toon_look" "faces": blink, squint,
## drowsy, smug, wide, happy, dizzy), in the viewer's model and in the
## lighter battle model.
func test_a_toy_has_every_face_the_game_shows() -> void:
	var faces: Dictionary = GameData.viewer.get("toon_look", {}).get("faces", {})
	check(not faces.is_empty(), "viewer.json toon_look maps the game's faces to blendshapes")
	for id: String in _roster():
		for path in ["res://art/models/%s.glb" % id, "res://art/models/battle/%s.glb" % id]:
			var root := (load(path) as PackedScene).instantiate()
			_made.append(root)
			if not ModelStage.is_toon(root):
				continue
			var names := {}
			for mi: MeshInstance3D in ModelStage.toon_faces(root):
				for i in mi.get_blend_shape_count():
					names[String(mi.mesh.get_blend_shape_name(i))] = true
			check(not names.is_empty(), "%s has a face of blendshapes (%s)" % [id, path.get_file()])
			for face: String in faces:
				var want: Dictionary = faces[face]
				var shapes: Array = want.get("cycle", want.keys())
				for shape in shapes:
					check(names.has(String(shape)), "%s's face has %s (the game's %s face)" % [id, shape, face])
		cleanup()


## Every animal has a persona (tools/creatures/motion.py PERSONAS): its
## model carries its own idle, fidget and victory, whatever its look.
func test_every_animal_has_its_own_animations() -> void:
	for id: String in _roster():
		var viewer := _viewer(id)
		if viewer.model() == null:
			check(false, "%s's model loaded" % id)
			continue
		var player := viewer.model().find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		for anim in ["idle", "fidget", "victory"]:
			check(player.has_animation(anim) and player.get_animation(anim).length > 0.5, "%s has a %s" % [id, anim])
		cleanup()
