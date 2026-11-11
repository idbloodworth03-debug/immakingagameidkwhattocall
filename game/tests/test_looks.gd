extends TestCase
## The look of an animal's model, told by its mesh's name
## (docs/ART_DIRECTION.md). <id>_toon is a toy in the flat-color look (our
## own: tools/toys; or a pack's animal: tools/packs), drawn by
## model_toon.gdshader with its outline in the viewer and in battle, its
## face a small mesh of blendshapes. <id>_movie is the older animated-movie
## look (tools/creatures/movie.py), drawn by model_movie.gdshader (in the
## viewer without an outline; in battle with the outline and team band,
## pushed back round its fur locks). Anything else keeps the first cartoon
## shader. The roster is moving from the movie look to toys class by class:
## every animal is one or the other, and gets its look's shader.

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


## (The movie look's own details, for as long as an animal is still on it.)
func test_the_yeti_has_the_movie_look_in_the_viewer() -> void:
	var viewer := _viewer("yeti")
	check(viewer.model() != null, "the model loaded")
	if viewer.model() == null or not ModelStage.is_movie(viewer.model()):
		return
	var mesh := viewer.model().find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	check_eq(_shader_name(mesh.material_override), "model_movie.gdshader", "drawn with the movie shader")
	check((mesh.material_override as ShaderMaterial).next_pass == null, "with no outline (hero art)")
	var look: Dictionary = GameData.viewer.get("movie_look", {})
	check(look.has("key_dir") and look.has("iris_size") and look.has("lock_outline_push"), "its look is in viewer.json")
	# Its fur locks are in the mesh: vertices marked 2 in UV2.y.
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var locks := 0
	for v in uv2:
		if v.y > 1.5:
			locks += 1
	check(locks > 1000, "its coat is sculpted locks in the mesh (%d lock vertices)" % locks)


func test_the_yeti_keeps_its_outline_and_team_band_in_battle() -> void:
	var m := ModelStage.new_model("yeti", 1.5)
	check(m != null, "the battle model loaded")
	if m == null:
		return
	_made.append(m.pivot)
	if not m.movie:
		return
	check_eq(_shader_name(m.skin), "model_movie.gdshader", "drawn with the movie shader")
	check_eq(_shader_name(m.outline), "model_outline.gdshader", "with the dark outline")
	check(m.skin.next_pass == m.outline, "the outline drawn after the skin")
	check(float(m.outline.get_shader_parameter("lock_push")) > 0.0, "the outline pushed back round its fur locks")
	var arrays: Array = (m.body.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh.surface_get_arrays(0)
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var locks := 0
	for v in uv2:
		if v.y > 1.5:
			locks += 1
	check(locks > 100 and locks < 5000, "a few chunky locks for the battlefield (%d lock vertices)" % locks)


func _kind_counts(mesh: MeshInstance3D) -> Dictionary:
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var counts := {}
	for v in uv2:
		var kind := int(round(v.y))
		counts[kind] = int(counts.get(kind, 0)) + 1
	return counts


func test_the_komodo_dragon_is_scaly_and_the_falcon_feathered() -> void:
	# Scaly skin is marked 3 in UV2.y (the shader draws the cells); feather
	# cards are marked 4; both get the movie shader in the viewer and in battle.
	for id in ["komodo_dragon", "peregrine_falcon"]:
		var viewer := _viewer(id)
		check(viewer.model() != null, "%s's model loaded" % id)
		if viewer.model() == null or not ModelStage.is_movie(viewer.model()):
			continue
		var mesh := viewer.model().find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		check_eq(_shader_name(mesh.material_override), "model_movie.gdshader", "%s drawn with the movie shader" % id)
		var counts := _kind_counts(mesh)
		if id == "komodo_dragon":
			check(int(counts.get(3, 0)) > 5000, "the Komodo's skin is scaly (%d scaly vertices)" % int(counts.get(3, 0)))
		else:
			check(int(counts.get(4, 0)) > 500, "the Falcon wears feather cards (%d card vertices)" % int(counts.get(4, 0)))
		var m := ModelStage.new_model(id, 1.5)
		check(m != null and m.movie, "%s has the movie look in battle" % id)
		if m != null:
			_made.append(m.pivot)


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


## Every animal in the roster is a toy or on the movie look, and is drawn
## by its look's shader in the viewer and in battle: a toy with its
## outline in both, a movie-look animal without one in the viewer.
func test_every_animal_gets_its_looks_shader() -> void:
	var toys := 0
	for id: String in _roster():
		var viewer := _viewer(id)
		check(viewer.model() != null, "%s's model loaded" % id)
		if viewer.model() == null:
			continue
		var movie := ModelStage.is_movie(viewer.model())
		var toy := ModelStage.is_toon(viewer.model())
		check(movie != toy, "%s is a toy or on the movie look" % id)
		var shader := "model_toon.gdshader" if toy else "model_movie.gdshader"
		var mesh := viewer.model().find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		check_eq(_shader_name(mesh.material_override), shader, "%s drawn with its look's shader in the viewer" % id)
		if toy:
			toys += 1
			check((mesh.material_override as ShaderMaterial).next_pass != null, "%s the toy has its outline in the viewer" % id)
		var m := ModelStage.new_model(id, 1.5)
		check(m != null and m.movie == movie and m.toon == toy and _shader_name(m.skin) == shader, "%s has its look in battle" % id)
		if m != null:
			_made.append(m.pivot)
			check_eq(_shader_name(m.outline), "model_outline.gdshader", "%s has the dark outline in battle" % id)
		cleanup()
	check(toys >= 1, "the roster has toys (%d)" % toys)


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
