extends TestCase
## Bodies in battle (data/bodies.json; docs/ART_DIRECTION.md): every animal
## has a footprint and a width (its true size on the ground) and a reach
## (how far its strike extends); the fight gives it a room between the two
## and measures a melee animal's reach nose to nose; a fighter stands at its slot where its
## strike lands; a flier flies at a real height; and in a fight bodies
## don't overlap (more than a tenth of the smaller body into the other;
## touching is fine), striking least of all (under 1% of striking frames).

var _made: Array = []


func _host() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_child(tree.root.get_child_count() - 1)


func cleanup() -> void:
	for node in _made:
		if is_instance_valid(node):
			node.free()
	_made.clear()


func test_every_animal_has_a_footprint_and_a_reach() -> void:
	var animals: Dictionary = GameData.bodies.get("animals", {})
	for id in GameData.card_order:
		if GameData.is_tool(id):
			continue
		var body: Dictionary = animals.get(id, {})
		var footprint := float(body.get("footprint", 0.0))
		var reach := float(body.get("reach", 0.0))
		check(footprint >= 0.4 and footprint <= 2.5, "%s has a footprint (%.2f tiles)" % [id, footprint])
		check(reach > 0.0, "%s has a reach (%.2f tiles)" % [id, reach])
		if not body.get("shooter", false):
			check(reach >= 0.25 and reach <= 1.0, "%s's strike reaches a little past its body (%.2f tiles)" % [id, reach])
		var card: Dictionary = GameData.cards[id]
		var width := float(body.get("width", 0.0))
		check(width >= 0.25 and width <= footprint + 0.01, "%s has a width (%.2f tiles)" % [id, width])
		check_eq(BattleSim.unit_radius(card), roundi(sqrt(footprint * width) * BattleSim.TILE / 2.0), "%s's room in the fight is a circle between its width and its length" % id)
		check_eq(BattleSim.unit_half(card), roundi(footprint * BattleSim.TILE / 2.0), "%s strikes from half its length" % id)
		if not body.get("shooter", false):
			check_eq(BattleSim.unit_reach(card), roundi(reach * BattleSim.TILE), "%s hits as far as its reach" % id)


func _fight(seed_value: int) -> Dictionary:
	var levels := {}
	for id in GameData.card_order:
		levels[id] = GameData.start_level(GameData.cards[id].rarity)
	var duel := DraftMatch.new(seed_value, {"levels": [levels, levels]})
	duel.herds[0] = [{"id": "brown_bear", "stars": 1, "squads": 1}, {"id": "king_cobra", "stars": 1, "squads": 1}, {"id": "peregrine_falcon", "stars": 1, "squads": 1}]
	duel.herds[1] = [{"id": "wild_boar", "stars": 1, "squads": 1}, {"id": "red_fox", "stars": 1, "squads": 1}, {"id": "harpy_eagle", "stars": 1, "squads": 1}]
	for team in 2:
		duel.picks_left[team] = 0
		duel.picks_made[team] = []
	duel._lay_out_herds()
	duel.set_ready(0)
	duel.set_ready(1)
	duel.take_events()
	var field := BattleField.new()
	field.use_models = true
	field.size = Vector2(358, 680)
	field.screen_height_override = 844.0
	_made.append(field)
	_host().add_child(field)
	field.sim = duel.sim
	field.snap_camera()
	return {"duel": duel, "field": field}


func test_a_melee_fighter_takes_up_its_footprint_and_hits_from_its_reach() -> void:
	var fight := _fight(5)
	var duel: DraftMatch = fight.duel
	var bear: BattleSim.Fighter = null
	for f in duel.sim.fighters:
		if f.card.id == "brown_bear":
			bear = f
	check(bear != null, "a bear is on the field")
	if bear == null:
		return
	var body: Dictionary = GameData.bodies.animals.brown_bear
	check_eq(bear.half, roundi(float(body.footprint) * BattleSim.TILE / 2.0), "it strikes from its nose, half its footprint out")
	check(bear.radius < bear.half and bear.radius > bear.half / 2, "its room is a circle between its width and its length (%d of %d)" % [bear.radius, bear.half])
	check_eq(bear.attack_range, roundi(float(body.reach) * BattleSim.TILE), "it hits from its reach")
	check(bear.memory.spacing >= 2 * bear.radius, "its line gives its body room (%d for a %d radius)" % [bear.memory.spacing, bear.radius])


## Runs the fight for `seconds` through the real view at 60 frames a second
## (the fight stepping at its own rate), counting frames where bodies
## overlap, and striking frames where the striking body does.
func _run(fight: Dictionary, seconds: float) -> Dictionary:
	var duel: DraftMatch = fight.duel
	var field: BattleField = fight.field
	var out := {"frames": 0, "overlap_frames": 0, "strike_frames": 0, "strike_overlap_frames": 0, "flier_up": 0, "flier_frames": 0}
	var accumulator := 0.0
	var tick := 1.0 / duel.sim.tps
	for frame in int(seconds * 60.0):
		if duel.phase != "fight":
			break
		accumulator += 1.0 / 60.0
		while accumulator >= tick and duel.phase == "fight":
			duel.step()
			field.add_events(duel.sim.take_events())
			accumulator -= tick
		field.blend = clampf(accumulator / tick, 0.0, 1.0)
		field._process(1.0 / 60.0)
		var views: Array = field.views().filter(func(v): return v.fighter != null and v.pop >= 1.0)
		var any := false
		var striking := {}
		for i in views.size():
			var a: UnitView = views[i]
			if a.flying:
				out.flier_frames += 1
				if a.m_altitude > 0.3:
					out.flier_up += 1
			for j in range(i + 1, views.size()):
				var b: UnitView = views[j]
				if a.flying != b.flying:
					continue
				if UnitView.bodies_overlap(a, b):
					any = true
					if a.attacking(field.now()):
						striking[a] = true
					if b.attacking(field.now()):
						striking[b] = true
		out.frames += 1
		if any:
			out.overlap_frames += 1
		for v in views:
			if v.attacking(field.now()):
				out.strike_frames += 1
				if striking.has(v):
					out.strike_overlap_frames += 1
	return out


func test_bodies_do_not_overlap_in_a_fight_least_of_all_striking() -> void:
	var fight := _fight(5)
	var out := _run(fight, 20.0)
	check(out.frames > 300, "the fight ran a while (%d frames)" % out.frames)
	check(out.strike_frames > 60, "with strikes in it (%d striking frames)" % out.strike_frames)
	var strike_pct: float = 100.0 * out.strike_overlap_frames / maxf(1, out.strike_frames)
	check(strike_pct <= 1.0, "a striking body overlaps another in %.2f%% of striking frames (at most 1%%)" % strike_pct)
	var any_pct: float = 100.0 * out.overlap_frames / maxf(1, out.frames)
	check(any_pct <= 5.0, "any two bodies overlap in %.1f%% of frames" % any_pct)
	check(out.flier_up == out.flier_frames and out.flier_frames > 0, "the fliers fly above the ground (%d of %d frames)" % [out.flier_up, out.flier_frames])
