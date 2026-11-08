extends TestCase
## The animated-movie look (docs/ART_DIRECTION.md): an animal whose model
## was built by tools/creatures/movie.py (its mesh named <id>_movie) is
## drawn by its own shader in the viewer (without an outline) and in battle
## (with the outline and team band, pushed back round its fur locks); the
## others keep the cartoon shader. The Yeti, the Komodo Dragon (scales) and
## the Peregrine Falcon (feathers) are the first three.

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
		if viewer.model() == null:
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


## The animals on the movie look so far (tools/creatures/movie.json).
const MOVIE := ["yeti", "komodo_dragon", "peregrine_falcon", "brown_bear", "giant_panda", "hippopotamus",
	"asian_elephant", "black_rhino", "snapping_turtle",
	"lion", "tiger", "wild_boar", "wolf_pack", "honey_badger", "cerberus",
	"gray_squirrel", "raccoon", "striped_skunk", "king_cobra", "wild_bactrian_camel", "sumatran_orangutan", "unicorn",
	"barn_owl", "harpy_eagle", "hyacinth_macaw", "california_condor", "dragon",
	"electric_eel", "harbor_seal", "red_fox", "mountain_gorilla", "red_panda", "pygmy_three_toed_sloth",
	"sunda_pangolin", "kraken"]


func test_every_movie_look_animal_gets_the_movie_shader() -> void:
	for id in MOVIE:
		var viewer := _viewer(id)
		check(viewer.model() != null, "%s's model loaded" % id)
		if viewer.model() == null:
			continue
		check(ModelStage.is_movie(viewer.model()), "%s is marked as the movie look" % id)
		var mesh := viewer.model().find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		check_eq(_shader_name(mesh.material_override), "model_movie.gdshader", "%s drawn with the movie shader" % id)
		var m := ModelStage.new_model(id, 1.5)
		check(m != null and m.movie and _shader_name(m.skin) == "model_movie.gdshader", "%s has the movie look in battle" % id)
		if m != null:
			_made.append(m.pivot)
		cleanup()


## Every animal in the roster is on the movie look now; a model is told to
## be on it by its mesh's name (<id>_movie), so an older model without the
## suffix would still get the cartoon look.
func test_the_movie_look_is_told_by_the_mesh_name() -> void:
	var plain := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.name = "red_fox"
	plain.add_child(mesh)
	_made.append(plain)
	check(not ModelStage.is_movie(plain), "a mesh without the suffix is the cartoon look")
	var movie := Node3D.new()
	var movie_mesh := MeshInstance3D.new()
	movie_mesh.name = "red_fox_movie"
	movie.add_child(movie_mesh)
	_made.append(movie)
	check(ModelStage.is_movie(movie), "a mesh named <id>_movie is the movie look")
	for id in GameData.cards:
		if not GameData.is_tool(id):
			check(MOVIE.has(id), "%s is on the movie look" % id)


## The Tanks have personas like the Yeti's (tools/creatures/motion.py
## PERSONAS, movie.json "motion"): their models carry their own idle,
## fidget and victory.
const PERSONAS := ["brown_bear", "giant_panda", "hippopotamus", "asian_elephant", "black_rhino", "snapping_turtle",
	"lion", "tiger", "wild_boar", "wolf_pack", "honey_badger", "cerberus"]


func test_the_persona_animals_have_their_own_animations() -> void:
	for id in PERSONAS:
		var viewer := _viewer(id)
		if viewer.model() == null:
			check(false, "%s's model loaded" % id)
			continue
		var player := viewer.model().find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		for anim in ["idle", "fidget", "victory"]:
			check(player.has_animation(anim) and player.get_animation(anim).length > 0.5, "%s has a %s" % [id, anim])
		cleanup()
