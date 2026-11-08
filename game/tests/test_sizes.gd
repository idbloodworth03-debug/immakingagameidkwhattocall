extends TestCase
## How big the animals are drawn in battle (data/bodies.json): every animal
## has a size, and on a phone-size field at the camera's closest zoom none
## stands taller on screen than its limit (bodies.json "limits": unit_max_pct
## of the screen's height for any animal, hero_max_pct for a Mythic hero),
## facing up or down the field as armies do, because the camera stops
## zooming in before that (BattleField._size_zoom_cap), whatever its zoom
## limit. SIZES_TABLE=1 prints every animal's share.

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
