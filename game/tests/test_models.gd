extends TestCase
## The animals as 3D models in battle (scripts/fx/model_stage.gd): every
## animal has a battle model and a size, and a model stands exactly where
## its sprite would, playing the animation its view chose.

var _made: Array = []


func _host() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_child(tree.root.get_child_count() - 1)


func cleanup() -> void:
	for node in _made:
		if is_instance_valid(node):
			node.free()
	_made.clear()


func test_every_animal_has_a_battle_model() -> void:
	for id in GameData.card_order:
		if GameData.is_tool(id):
			continue
		check(ModelStage.has_model(id), "%s has a battle model" % id)
		check(ModelStage.tile_scale(id) > 0.05 and ModelStage.tile_scale(id) < 20.0, "%s has a size in tiles" % id)


func _fight() -> BattleField:
	var levels := {}
	for id in GameData.card_order:
		levels[id] = GameData.start_level(GameData.cards[id].rarity)
	var duel := DraftMatch.new(5, {"levels": [levels, levels]})
	duel.herds[0] = [{"id": "brown_bear", "stars": 1, "squads": 1}, {"id": "red_fox", "stars": 1, "squads": 1}]
	duel.herds[1] = [{"id": "wild_boar", "stars": 1, "squads": 1}, {"id": "raccoon", "stars": 1, "squads": 1}]
	for team in 2:
		duel.picks_left[team] = 0
		duel.picks_made[team] = []
	duel._lay_out_herds()
	duel.set_ready(0)
	duel.set_ready(1)
	duel.take_events()
	var field := BattleField.new()
	field.use_models = true
	field.size = Vector2(720, 1300)
	_made.append(field)
	_host().add_child(field)
	field.sim = duel.sim
	field.snap_camera()
	field._sync_views(0.0)
	for v in field._views.values():
		v.animate(0.016, field.now())
		v.position = field.to_screen(v.render_pos().x, v.render_pos().y)
	field._stage.sync(field._views, field.now())
	return field


func test_a_model_stands_where_its_sprite_would() -> void:
	var field := _fight()
	var stage := field._stage
	check(stage.model_count() > 0, "the animals got models")
	var checked := 0
	for key in stage._models:
		var v: UnitView = field._views[key]
		var m: ModelStage.Model = stage._models[key]
		check(v.modeled, "%s is shown as a model" % v.id)
		# Its feet, through the 3D camera, land on the sprite's spot.
		var feet := stage.camera.unproject_position(m.pivot.global_position - Vector3(0, 0, 0)) / stage.render_scale
		var expected := v.position + v.m_offset
		check(feet.distance_to(expected) < 1.5, "%s stands on its spot (%s vs %s)" % [v.id, feet, expected])
		checked += 1
	check(checked >= 4, "checked every animal (%d)" % checked)


func test_a_model_plays_its_views_animation() -> void:
	var field := _fight()
	var stage := field._stage
	for key in stage._models:
		var v: UnitView = field._views[key]
		var m: ModelStage.Model = stage._models[key]
		check(m.player != null and m.lengths.has("idle") and m.lengths.has("walk") and m.lengths.has("attack"),
			"%s has idle, walk and attack" % v.id)
		v.m_anim = "attack"
		v.m_phase = 0.5
		stage._pose(m, v, field.now(), field.field_scale() * 1000.0, Vector3(1, 0, 0), Vector3(0, ModelStage.COS, -ModelStage.SIN), Vector3(0, -ModelStage.SIN, -ModelStage.COS))
		check_eq(String(m.player.current_animation), "attack", "%s plays the attack" % v.id)
		check(absf(m.player.current_animation_position - 0.5 * float(m.lengths.attack)) < 0.02, "%s halfway through it" % v.id)
		break
