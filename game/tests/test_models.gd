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
		stage._pose(m, v, field.now(), 0.0, field.field_scale() * 1000.0, Vector3(1, 0, 0), Vector3(0, ModelStage.COS, -ModelStage.SIN), Vector3(0, -ModelStage.SIN, -ModelStage.COS))
		check_eq(String(m.player.current_animation), "attack", "%s plays the attack" % v.id)
		check(absf(m.player.current_animation_position - 0.5 * float(m.lengths.attack)) < 0.02, "%s halfway through it" % v.id)
		break


## A change of animation cross-fades (feel.json "acting" blend_seconds):
## for a moment the pose is between the old animation's and the new one's.
func test_a_change_of_animation_cross_fades() -> void:
	var field := _fight()
	var stage := field._stage
	var blend := Feel.num("acting", "blend_seconds", 0.12)
	check(blend >= 0.1 and blend <= 0.15, "blends take 100-150 ms (%.0f ms)" % (blend * 1000.0))
	var key: Variant = stage._models.keys()[0]
	var v: UnitView = field._views[key]
	var m: ModelStage.Model = stage._models[key]
	var skeleton := m.body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var bone := maxi(0, skeleton.find_bone("neck"))
	var args := [field.field_scale() * 1000.0, Vector3(1, 0, 0), Vector3(0, ModelStage.COS, -ModelStage.SIN), Vector3(0, -ModelStage.SIN, -ModelStage.COS)]
	v.m_anim = "idle"
	v.m_phase = 0.0
	stage._pose(m, v, field.now(), 0.0, args[0], args[1], args[2], args[3])
	var idle_pose := skeleton.get_bone_pose_rotation(bone)
	v.m_anim = "attack"
	v.m_phase = 0.5
	stage._pose(m, v, field.now(), 1.0 / 60.0, args[0], args[1], args[2], args[3])
	var first := skeleton.get_bone_pose_rotation(bone)
	for i in 3:
		stage._pose(m, v, field.now(), 1.0 / 60.0, args[0], args[1], args[2], args[3])
	var mid := skeleton.get_bone_pose_rotation(bone)
	for i in 30:
		stage._pose(m, v, field.now(), 1.0 / 60.0, args[0], args[1], args[2], args[3])
	var settled := skeleton.get_bone_pose_rotation(bone)
	var whole := idle_pose.angle_to(settled)
	check(whole > 0.02, "%s's attack pose differs from its idle (%.1f degrees)" % [v.id, rad_to_deg(whole)])
	check(idle_pose.angle_to(first) < whole * 0.5, "the first frame is still close to the idle (%.1f of %.1f degrees)" % [rad_to_deg(idle_pose.angle_to(first)), rad_to_deg(whole)])
	check(idle_pose.angle_to(mid) > whole * 0.15 and idle_pose.angle_to(mid) < whole * 0.95, "a few frames in it is between the two (%.1f of %.1f degrees)" % [rad_to_deg(idle_pose.angle_to(mid)), rad_to_deg(whole)])
	check(absf(m.player.current_animation_position - 0.5 * float(m.lengths.attack)) < 0.02, "the playhead stays where the view wants it")
	check(stage.blends >= 1, "the change was a cross-fade, not a cut")


## A swing plays to its end: a hit dealt while one is playing lands in it
## (at its hit frame, or now), never starting another over it.
func test_a_swing_is_never_cut_short_by_the_next_hit() -> void:
	var field := _fight()
	var v: UnitView = field._views.values()[0]
	var now := field.now() + 5.0
	var first := v.time_to_strike(now, Vector2.UP)
	check(first > 0.05, "%s's first hit starts a swing with a wind-up (%.2f s)" % [v.id, first])
	var started := v.attack_at
	var windup := v.windup_seconds()
	check(is_equal_approx(v.time_to_strike(now + windup * 0.5, Vector2.UP), windup * 0.5), "a hit mid wind-up waits for the hit frame")
	check(v.attack_at == started, "and starts no new swing")
	var recovery := now + windup + 0.05
	check(v.attacking(recovery), "the swing is still playing after its hit frame")
	check_eq(v.time_to_strike(recovery, Vector2.UP), 0.0, "a hit then lands at once")
	check(v.attack_at == started and v.attacks_cut == 0, "without cutting the swing short")
	var later := now + v._attack_length() + 0.5
	check(v.time_to_strike(later, Vector2.UP) > 0.05, "once it's over, the next hit starts a new swing")


func test_3d_is_on_everywhere_by_default() -> void:
	check(Feel.on("models", "enabled", false), "feel.json turns the 3D models on")
	var field := BattleField.new()
	_made.append(field)
	check(field.use_models, "a battle field shows 3D models unless a screen says otherwise")


func test_a_stunned_animal_looks_dizzy() -> void:
	var field := _fight()
	var stage := field._stage
	for key in stage._models:
		var v: UnitView = field._views[key]
		v.fighter.stun = 30
		v.animate(0.016, field.now())
		check_eq(v.m_face, "dizzy", "a stunned %s's face is dizzy" % v.id)
		stage.sync(field._views, field.now())
		var m: ModelStage.Model = stage._models[key]
		check_eq(m.face, "dizzy", "and so are its model's eyes")
		break


## A little fight of these animals ([team, id]), one each, under their
## uids (as the attack-style showcase has them).
func _little_fight(specs: Array, seed_value: int) -> BattleSim:
	var sim := BattleSim.new([{}, {}], seed_value)
	sim.army = BattleArmy.new(sim.rules, sim.tps)
	var y := 9000
	for spec in specs:
		var f: BattleSim.Fighter = sim.spawn_units(int(spec[0]), String(spec[1]), 1, 8000, y)[0]
		f.deploy_ticks = 0
		y += 1500
	return sim


func test_a_new_fight_gets_its_own_models() -> void:
	# A new fight's animals come under the same keys (its uids start over):
	# each must get its own model, not the one that stood there last.
	var field := BattleField.new()
	field.use_models = true
	field.size = Vector2(720, 1300)
	_made.append(field)
	_host().add_child(field)
	var stage := field._stage
	for specs in [[[0, "wild_boar"], [1, "wild_boar"], [1, "gray_squirrel"]], [[0, "red_fox"], [1, "brown_bear"], [1, "raccoon"]]]:
		field.sim = _little_fight(specs, 9)
		field.snap_camera()
		field._sync_views(0.0)
		stage.sync(field._views, field.now())
	var checked := 0
	for key in field._views:
		var v: UnitView = field._views[key]
		if v.modeled:
			check_eq(stage._models[key].id, v.id, "the %s is drawn as itself" % v.id)
			checked += 1
	check(checked >= 3, "checked every animal (%d)" % checked)


func test_sides_read_at_a_glance() -> void:
	# Every animal in battle has a bold band in its team's color (blue yours,
	# red the enemy's) outside its dark outline, behind it in depth.
	var field := _fight()
	var stage := field._stage
	var teams := {}
	for key in stage._models:
		var v: UnitView = field._views[key]
		var m: ModelStage.Model = stage._models[key]
		check(m.team_line != null, "the %s has a team band" % v.id)
		if m.team_line == null:
			continue
		teams[v.team] = true
		check_eq(m.team_line.get_shader_parameter("color"), BattleField.team_color(v.team), "in its team's color (%s)" % v.id)
		check(float(m.team_line.get_shader_parameter("width_px")) > float(m.outline.get_shader_parameter("width_px")) + 1.0, "wider than the dark outline")
		check(float(m.team_line.get_shader_parameter("depth_push")) > 0.0, "and behind it, so the dark line stays on top")
		check(m.outline.next_pass == m.team_line, "drawn with the model")
	check_eq(teams.size(), 2, "both sides checked")
	check(BattleField.team_color(0) != BattleField.team_color(1), "two different colors")
	# A model handed on to an animal of the other side changes color.
	var m: ModelStage.Model = stage._models.values()[0]
	stage._set_team(m, 1 - m.team)
	check_eq(m.team_line.get_shader_parameter("color"), BattleField.team_color(m.team), "a reused model takes its new side's color")


func test_sprites_have_the_team_band_too() -> void:
	var field := BattleField.new()
	field.use_models = false
	field.size = Vector2(720, 1300)
	_made.append(field)
	_host().add_child(field)
	field.sim = _little_fight([[0, "brown_bear"], [1, "wild_boar"]], 4)
	field.snap_camera()
	field._sync_views(0.0)
	for v: UnitView in field._views.values():
		var material := v._material
		check(material != null, "the %s has its shader" % v.id)
		if material != null:
			check_eq(material.get_shader_parameter("team_color"), BattleField.team_color(v.team), "with its team's band color (%s)" % v.id)


func test_shots_trail_their_team_color() -> void:
	var field := _fight()
	var shooter: UnitView = null
	var target: UnitView = null
	for v: UnitView in field._views.values():
		if v.team == 0 and shooter == null:
			shooter = v
		if v.team == 1 and target == null:
			target = v
	field.fx.shoot(shooter, target, Vector2(target.fighter.x, target.fighter.y), 0.0, 0.5)
	var pr: Dictionary = field.fx.projectiles[-1]
	check_eq(int(pr.team), 0, "a shot knows whose it is")
	pr.from = shooter.middle()
	var look: Dictionary = pr.look
	for i in 20:
		field.fx.time += 0.02
		field.fx.trail_step(pr, look, target.middle(), i / 20.0)
	var trail: Array = pr.team_trail
	check(trail.size() >= 2, "it leaves a streak (%d points)" % trail.size())
	var keep := Feel.num("readability", "shot_trail_seconds", 0.12)
	check(field.fx.time - float(trail[1][1]) <= keep + 0.001, "only the last %.2f s of it" % keep)


## A quick tap on the field at `point` (the field's own coordinates).
func _tap(field: BattleField, point: Vector2) -> void:
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = point
		field._gui_input(e)


## Plays the fight on the field for `seconds` (as the screen does), with
## the field's frames.
func _play(field: BattleField, seconds: float) -> void:
	var sim := field.sim
	for i in roundi(seconds * 60.0):
		if i % 3 == 0:
			sim.step()
			field.add_events(sim.take_events())
		field._process(1.0 / 60.0)


func test_tapping_a_squad_shows_what_it_is_doing() -> void:
	var field := _fight()
	_play(field, 6.0)
	var army: Array = field._views.values().filter(func(v): return v.team == 0 and v.fighter != null and v.fighter.target != null)
	check(not army.is_empty(), "animals of ours going for someone")
	if army.is_empty():
		return
	var v: UnitView = army[0]
	var group := int(v.fighter.memory.group)
	var scale_before := Engine.time_scale
	var tick_before := field.sim.tick
	# A tap on one of its animals picks its squad.
	_tap(field, v.position + v.head() * 0.5)
	check_eq(field.picked_group, group, "a tap on an animal picks its squad")
	field._process(1.0 / 60.0)
	for w: UnitView in field._views.values():
		var in_squad := w.fighter != null and int(w.fighter.memory.get("group", -1)) == group
		if in_squad:
			check(w.m_glow > 0.2, "its animals glow (%s)" % w.id)
		else:
			check_eq(w.m_glow, 0.0, "the others don't (%s)" % w.id)
	var pairs := field.picked_targets()
	check(not pairs.is_empty(), "lines to the enemies it's going for")
	for pair in pairs:
		check(pair[0].fighter.target == pair[1].fighter, "each line to that animal's own target")
		check(pair[1].team != pair[0].team, "an enemy")
	# The fight goes on: nothing paused or slowed.
	_play(field, 0.5)
	check(field.sim.tick > tick_before, "the fight goes on")
	check_eq(Engine.time_scale, scale_before, "at its usual speed")
	check_eq(field.playback, 1.0, "the field isn't slowed")
	# The lines show only for a moment; the glow stays.
	_play(field, Feel.num("readability", "squad_lines_seconds", 2.5) + 0.5)
	if field.picked_group >= 0:
		check(field.picked_targets().is_empty(), "the lines fade after a moment")
		check(not field.picked_views().is_empty(), "while the squad stays picked")
	# Tapping nothing lets go.
	_tap(field, Vector2(5, 5))
	check_eq(field.picked_group, -1, "a tap on nothing lets go")


func test_a_squad_by_its_banner_and_letting_go() -> void:
	var field := _fight()
	field._process(1.0 / 60.0)
	var flags := field.banners()
	check(not flags.is_empty(), "squads have banners")
	var flag: Dictionary = flags[0]
	_tap(field, flag.flag)
	check_eq(field.picked_group, int(flag.group), "a tap on a banner picks its squad")
	_tap(field, flag.flag)
	check_eq(field.picked_group, -1, "the same banner again lets go")
	# Aiming a tool, a tap is the tool's.
	field.highlight = "field"
	_tap(field, flag.flag)
	check_eq(field.picked_group, -1, "while a tool is aimed, a tap doesn't pick")
	field.highlight = ""


func test_busy_spots_keep_small_hits_quiet() -> void:
	# Ten animals packed together and one alone: in the pack only big hits
	# and knockouts always show, a strong one while no other number is up
	# there, the rest keep quiet; alone, every hit shows.
	var field := BattleField.new()
	field.use_models = false
	field.size = Vector2(720, 1300)
	_made.append(field)
	_host().add_child(field)
	var sim := BattleSim.new([{}, {}], 3)
	sim.army = BattleArmy.new(sim.rules, sim.tps)
	for i in 10:
		sim.spawn_units(i % 2, "wild_boar", 1, 8000 + (i % 4) * 400, 9000 + (i / 4) * 400)[0].deploy_ticks = 0
	sim.spawn_units(0, "brown_bear", 1, 2000, 17000)[0].deploy_ticks = 0
	field.sim = sim
	field.snap_camera()
	field._sync_views(0.0)
	var pack := Vector2(8600, 9400)
	var alone := Vector2(2000, 17000)
	check(field.crowd_near(pack) >= Feel.count("crowd", "busy_from_units", 8), "the pack is a busy spot (%d)" % field.crowd_near(pack))
	check(field.crowd_near(alone) < Feel.count("crowd", "busy_from_units", 8), "the lone bear isn't")
	check(field.quiet_hit(pack, false, false, false), "a small hit in the pack keeps quiet")
	check(not field.quiet_hit(pack, true, true, false), "a big hit there shows")
	check(not field.quiet_hit(pack, false, false, true), "so does a knockout")
	check(not field.quiet_hit(pack, true, false, false), "a strong hit shows while no number is up there")
	field.fx.number(field.to_screen(pack.x, pack.y), 300, "hurt_enemy", true, "x")
	check(field.quiet_hit(pack, true, false, false), "but not once one is")
	check(not field.quiet_hit(alone, false, false, false), "away from the crowd, a small hit shows as ever")


func test_the_arena_preview_shows_models() -> void:
	var preview := ArenaPreview.new()
	preview.animate = true
	preview.size = Vector2(600, 300)
	_made.append(preview)
	_host().add_child(preview)
	preview.arena_id = "rescue_center"
	check(preview._viewport != null, "the preview has its 3D view")
	check_eq(preview._models.size(), preview._cast.size(), "a model for each animal in it")
	check(preview._bodies.is_empty(), "and no sprites")
