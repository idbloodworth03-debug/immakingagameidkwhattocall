extends TestCase
## The 3D animal viewer (scripts/ui/animal_viewer.gd, habitat_stage.gd): every
## animal has a model and a Ranger Journal entry, the model loads and idles,
## drag spins it, pinch zooms within limits, a tap plays a reaction, and a
## hold on the viewer never shows a card hidden under it.

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


func test_every_animal_has_a_model_a_journal_and_a_scene() -> void:
	var habitats: Dictionary = GameData.viewer.get("habitats", {})
	for id in GameData.card_order:
		if GameData.is_tool(id):
			continue
		check(AnimalViewer.has_model(id), "%s has a 3D model" % id)
		var entry: Dictionary = GameData.journal.get(id, {})
		check(String(entry.get("home", "")) != "", "%s's journal says where it lives" % id)
		check((entry.get("facts", []) as Array).size() >= 2, "%s's journal has at least two facts" % id)
		check(habitats.has(String(GameData.get_card(id).get("habitat", ""))), "%s's habitat has a scene" % id)


func test_every_habitat_builds_a_scene() -> void:
	for habitat in GameData.viewer.get("habitats", {}):
		var stage := HabitatStage.make(String(habitat))
		_made.append(stage)
		check(stage.get_child_count() >= 6, "%s has a stage and scenery" % habitat)
		var sky := stage.make_sky(70.0, 30.0, 1.0)
		_made.append(sky)
		check(sky.mesh != null, "%s has a sky" % habitat)


func test_the_model_loads_fits_and_idles() -> void:
	var viewer := _viewer("red_fox")
	check(viewer.model() != null, "the model loaded")
	if viewer.model() == null:
		return
	check_eq(viewer.animation(), "idle", "it idles")
	var meshes := viewer.model().find_children("*", "MeshInstance3D", true, false)
	check(not meshes.is_empty(), "it has a mesh")
	var mesh := meshes[0] as MeshInstance3D
	check(mesh.material_override is ShaderMaterial, "drawn with the animal shader")
	if ModelStage.is_movie(viewer.model()):
		check((mesh.material_override as ShaderMaterial).next_pass == null, "the movie look has no outline in the viewer")
	else:
		check((mesh.material_override as ShaderMaterial).next_pass != null, "with an outline")
	# Its biggest side as it idles, on the stage (its skinned points, scaled
	# as it stands there: a model may be made of more than one mesh, and its
	# idle pose isn't its pose at rest).
	var box := viewer._idle_box()
	var biggest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	check(absf(biggest - float(GameData.viewer.view.model_size)) < 0.05, "scaled to the viewer's size (%.2f)" % biggest)


func test_spin_zoom_and_tap() -> void:
	var viewer := _viewer("brown_bear")
	if viewer.model() == null:
		check(false, "the model loaded")
		return
	var yaw := viewer.yaw()
	viewer.spin(Vector2(40, 0))
	check(viewer.yaw() > yaw, "a drag to the right spins it")
	var limits: Array = GameData.viewer.view.distance_range
	viewer.zoom(0.01)
	check(is_equal_approx(viewer.distance(), float(limits[0])), "pinching in stops at the closest")
	viewer.zoom(100.0)
	check(is_equal_approx(viewer.distance(), float(limits[1])), "pinching out stops at the furthest")
	var first := viewer.react()
	var second := viewer.react()
	check(first != "" and second != "" and first != second, "taps play different reactions (%s, %s)" % [first, second])
	check_eq(viewer.animation(), second, "the reaction plays")


func test_a_hold_on_the_viewer_ignores_the_cards_under_it() -> void:
	var card := AnimalCard.create("red_fox")
	_made.append(card)
	_host().add_child(card)
	card.position = Vector2(100, 200)
	card.size = AnimalCard.SIZE_NORMAL
	var point := card.get_global_rect().get_center()
	check_eq(String(HoldInfo.target_at(point).get("id", "")), "red_fox", "the card alone can be held")
	var viewer := AnimalViewer.new()
	viewer.animal_id = "brown_bear"
	_made.append(viewer)
	_host().add_child(viewer)
	check(HoldInfo.target_at(point).is_empty(), "not through the viewer")
