extends TestCase
## The animated-movie look (docs/ART_DIRECTION.md): an animal whose model
## was built by tools/creatures/movie.py (its mesh named <id>_movie) is
## drawn by its own shader in the viewer (without an outline) and in battle
## (with the outline and team band, pushed back round its fur locks); the
## others keep the cartoon shader. The Yeti is the first.

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


func test_the_yeti_has_the_movie_look_in_the_viewer() -> void:
	var viewer := _viewer("yeti")
	check(viewer.model() != null, "the model loaded")
	if viewer.model() == null:
		return
	check(ModelStage.is_movie(viewer.model()), "its mesh is marked as the movie look")
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
	check(m.movie, "it has the movie look")
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


func test_the_other_animals_keep_the_cartoon_look() -> void:
	var viewer := _viewer("red_fox")
	if viewer.model() == null:
		check(false, "the model loaded")
		return
	check(not ModelStage.is_movie(viewer.model()), "the fox is not on the movie look yet")
	var mesh := viewer.model().find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	check_eq(_shader_name(mesh.material_override), "model_skin.gdshader", "drawn with the cartoon shader")
	check((mesh.material_override as ShaderMaterial).next_pass != null, "with its outline")
	var m := ModelStage.new_model("red_fox", 1.5)
	if m != null:
		_made.append(m.pivot)
		check(not m.movie, "and the cartoon look in battle")
		check_eq(_shader_name(m.skin), "model_skin.gdshader", "with the cartoon shader")
