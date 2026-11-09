extends TestCase
## How big the animals are drawn in battle (data/bodies.json): every animal
## has a size, and on a phone-size field at the camera's closest zoom none
## stands taller on screen than its limit (bodies.json "limits": unit_max_pct
## of the screen's height for any animal, hero_max_pct for a Mythic hero),
## facing up or down the field as armies do, because the camera stops
## zooming in before that (BattleField._size_zoom_cap), whatever its zoom
## limit; nor in any frame of a real fight. Heights are the real outline on
## the screen, posed (ModelStage.model_height_units). SIZES_TABLE=1 prints
## every animal's share.

## The field's room on an iPhone's screen (390 x 844 points) and the
## screen's height (as tests/feel_report.gd measures it).
const FIELD := Vector2(358, 680)
const SCREEN := 844.0

var _made: Array = []


func _host() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_child(tree.root.get_child_count() - 1)


func cleanup() -> void:
	for node in _made:
		if is_instance_valid(node):
			node.free()
	_made.clear()


func test_every_animal_has_a_drawn_size_and_the_limits_are_in_data() -> void:
	var animals: Dictionary = GameData.bodies.get("animals", {})
	for id in GameData.card_order:
		if GameData.is_tool(id):
			continue
		var size := float(animals.get(id, {}).get("size", 0.0))
		check(size >= 0.5 and size <= 3.5, "%s is drawn %.2f tiles long" % [id, size])
	var limits: Dictionary = GameData.bodies.get("limits", {})
	for key in ["average_target_pct", "unit_max_pct", "hero_max_pct"]:
		check(float(limits.get(key, 0.0)) > 0.0, "limits has %s" % key)
	check(float(limits.get("unit_max_pct", 0.0)) <= float(limits.get("hero_max_pct", 0.0)), "a hero may be the biggest")


## One squad of `id` a side, the camera framing `team`'s alone (so it zooms
## in as far as it may), posed and measured. `max_zoom`: the camera's own
## zoom limit (10: only the size limit holds it back).
func _fight(id: String, team: int, max_zoom: float) -> BattleField:
	var levels := {}
	for card in GameData.card_order:
		levels[card] = GameData.start_level(GameData.cards[card].rarity)
	var duel := DraftMatch.new(5, {"levels": [levels, levels]})
	duel.herds[0] = [{"id": id, "stars": 1, "squads": 1}]
	duel.herds[1] = [{"id": id, "stars": 1, "squads": 1}]
	for t in 2:
		duel.picks_left[t] = 0
		duel.picks_made[t] = []
	duel._lay_out_herds()
	duel.set_ready(0)
	duel.set_ready(1)
	duel.take_events()
	var field := BattleField.new()
	field.use_models = true
	field.size = FIELD
	field.screen_height_override = SCREEN
	field.camera_max_zoom = max_zoom
	field.frame_team = team
	_made.append(field)
	_host().add_child(field)
	field.sim = duel.sim
	field.snap_camera()
	field._sync_views(0.0)
	for v in field._views.values():
		v.pop = 1.0  # popped in already (it starts tiny and bounces up)
		v.animate(0.016, field.now())
		v.position = field.to_screen(v.render_pos().x, v.render_pos().y)
	field._stage.sync(field._views, field.now())
	return field


func _limit_of(v: UnitView) -> float:
	var limits: Dictionary = GameData.bodies.get("limits", {})
	return float(limits.get("hero_max_pct", 10.0)) if v.fighter.memory.get("hero", false) else float(limits.get("unit_max_pct", 9.0))


func test_no_animal_stands_taller_on_screen_than_its_limit() -> void:
	var table := OS.get_environment("SIZES_TABLE") != ""
	var lines := []
	for id in GameData.card_order:
		if GameData.is_tool(id):
			continue
		var shares := []
		for team in 2:
			# With the camera's own zoom limit out of the way, the size limit
			# alone must hold it back (then with the real one, for the table).
			for max_zoom in [10.0, -1.0]:
				var field := _fight(id, team, max_zoom)
				var views: Array = field._views.values()
				check(not views.is_empty(), "%s is on the field" % id)
				for v: UnitView in views:
					var pct := field.unit_height_share(v) * 100.0
					check(pct > 0.5, "%s is measured on screen (%.1f%%)" % [id, pct])
					check(pct <= _limit_of(v) + 0.05, "%s facing %s is %.1f%% of the screen's height, at most %.0f%% (zoom limit %.0f)" % [id, "up" if team == 0 else "down", pct, _limit_of(v), max_zoom])
					if max_zoom < 0.0:
						shares.append("%.1f" % pct)
				cleanup()
		if table:
			lines.append("%s %s" % [id, " ".join(shares)])
	if table:
		print("SIZES (share of the screen's height, facing up then down, at the camera's closest zoom):")
		for line in lines:
			print("  " + line)


## Every animal's bodies.json pose_up (the tallest it stands in a fight's
## animations, its real outline posed by its skeleton, as a share of its
## bounding box at rest) is what its model measures.
func test_every_animals_tallest_pose_is_in_data_and_true() -> void:
	var animals: Dictionary = GameData.bodies.get("animals", {})
	for id in GameData.card_order:
		if GameData.is_tool(id) or not ModelStage.has_model(id):
			continue
		var m := ModelStage.new_model(id, 1.0, true)
		_host().add_child(m.pivot)
		var measured := ModelStage.tallest_share(m)
		m.pivot.free()
		var data := float(animals.get(id, {}).get("pose_up", 0.0))
		check(absf(measured - data) <= 0.03, "%s's tallest pose is %.3f of its box (bodies.json pose_up %.3f)" % [id, measured, data])


## In a real fight through the real view, no animal ever rises over its
## limit times pose_allowance (bodies.json "limits") on screen, mid-stride,
## mid-swing or hit (its model's pose and the touch of squash and stretch
## on top, feel.json acting model_squash_share).
func test_no_animal_gets_over_its_limit_in_a_fight() -> void:
	var levels := {}
	for card in GameData.card_order:
		levels[card] = GameData.start_level(GameData.cards[card].rarity)
	var duel := DraftMatch.new(3, {"levels": [levels, levels]})
	duel.herds[0] = [{"id": "brown_bear", "stars": 1, "squads": 1}, {"id": "hippopotamus", "stars": 1, "squads": 1}, {"id": "yeti", "stars": 1, "squads": 1}, {"id": "king_cobra", "stars": 1, "squads": 1}]
	duel.herds[1] = [{"id": "asian_elephant", "stars": 1, "squads": 1}, {"id": "black_rhino", "stars": 1, "squads": 1}, {"id": "wild_boar", "stars": 1, "squads": 1}, {"id": "peregrine_falcon", "stars": 1, "squads": 1}]
	for t in 2:
		duel.picks_left[t] = 0
		duel.picks_made[t] = []
	duel._lay_out_herds()
	duel.set_ready(0)
	duel.set_ready(1)
	duel.take_events()
	var field := BattleField.new()
	field.use_models = true
	field.size = FIELD
	field.screen_height_override = SCREEN
	_made.append(field)
	_host().add_child(field)
	field.sim = duel.sim
	field.snap_camera()
	var worst := {}
	var frames := 0
	var accumulator := 0.0
	var tick := 1.0 / duel.sim.tps
	for frame in 60 * 14:
		if duel.phase != "fight":
			break
		accumulator += 1.0 / 60.0
		while accumulator >= tick and duel.phase == "fight":
			duel.step()
			field.add_events(duel.sim.take_events())
			accumulator -= tick
		field.blend = clampf(accumulator / tick, 0.0, 1.0)
		field._process(1.0 / 60.0)
		frames += 1
		for v: UnitView in field.views():
			if v.fighter == null or v.defeat >= 0.0 or v.pop < 1.0:
				continue
			# (Standing it keeps to its limit; an attack or a celebration may
			# rise above it by at most bodies.json limits pose_allowance.)
			var over := field.unit_height_share(v) * 100.0 - _limit_of(v) * float(GameData.bodies.limits.get("pose_allowance", 1.0))
			if over > float(worst.get(v.id, -100.0)):
				worst[v.id] = over
	check(frames > 300, "the fight ran a while (%d frames)" % frames)
	check(worst.size() >= 6, "the animals were measured (%d kinds)" % worst.size())
	for id in worst:
		check(float(worst[id]) <= 0.05, "%s at most %.1f points %s its limit" % [id, absf(float(worst[id])), "over" if float(worst[id]) > 0.0 else "under"])
