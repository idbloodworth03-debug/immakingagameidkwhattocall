extends TestCase
## Keeping big fights readable (scripts/fx/fx_layer.gd, feel.json "crowd"):
## only so many sparks and numbers at once, the biggest hits first.

var fx: FxLayer


func _init() -> void:
	fx = FxLayer.new(null)


func cleanup() -> void:
	fx.free()


func test_sparks_are_capped_and_favor_big_hits() -> void:
	fx.crowded = true
	var most := Feel.count("crowd", "hit_sparks_when_crowded", 6)
	for i in most:
		check(fx.allow_sparks(100 + i), "room for spark %d" % i)
	check(not fx.allow_sparks(50), "full: a smaller hit gets none")
	check(fx.allow_sparks(900), "a bigger hit takes the smallest one's place")
	check_eq(fx._sparks.size(), most, "still no more than the cap")
	fx.time += 10.0
	check(fx.allow_sparks(1), "once they fade there's room again")


func test_numbers_are_capped_and_favor_big_hits() -> void:
	fx.crowded = true
	var most := Feel.count("crowd", "numbers_when_crowded", 6)
	for i in most:
		fx.number(Vector2.ZERO, 100 + i, "hurt_enemy", false)
	check_eq(fx.numbers.size(), most, "up to the cap")
	fx.number(Vector2.ZERO, 10, "hurt_enemy", false)
	check(fx.numbers.all(func(n): return int(n.amount) >= 100), "a small hit isn't shown")
	fx.number(Vector2.ZERO, 999, "hurt_enemy", false)
	check_eq(fx.numbers.size(), most, "still at the cap")
	check(fx.numbers.any(func(n): return int(n.amount) == 999), "the big hit is shown")
	check(not fx.numbers.any(func(n): return int(n.amount) == 100), "in place of the smallest")


func test_crowded_fights_use_fewer_particles() -> void:
	fx.density = 0.5
	fx.particles.clear()
	fx.burst("puff", Vector2.ZERO, 10, 100.0, 0.5, 5.0, [Color.WHITE])
	check_eq(fx.particles.size(), 5, "half the particles")


## A field (built by hand: not in the scene tree), with a bear and a boar
## squaring up.
func _field() -> Dictionary:
	var field := BattleField.new()
	field.size = Vector2(720, 1080)
	field._ready()
	var sim := BattleSim.new([{}, {}], 1)
	field.sim = sim
	field.blend = 1.0
	var bear: BattleSim.Fighter = sim.spawn(0, "brown_bear", 8 * BattleSim.TILE, 11 * BattleSim.TILE)[0]
	var boar: BattleSim.Fighter = sim.spawn(1, "wild_boar", 8 * BattleSim.TILE, 9 * BattleSim.TILE)[0]
	field._process(1.0 / 60.0)
	return {"field": field, "bear": bear, "boar": boar}


func test_hits_show_when_the_strike_lands() -> void:
	var made := _field()
	var field: BattleField = made.field
	var bear: BattleSim.Fighter = made.bear
	var boar: BattleSim.Fighter = made.boar
	var target := field.view_for_uid(boar.uid)
	var hit := {"type": "hit", "from": bear.uid, "to": boar.uid, "x": boar.x, "y": boar.y, "fx": bear.x, "fy": bear.y,
		"amount": 100, "dealt": 100, "ranged": false}
	field.add_events([hit])
	var windup := field.view_for_uid(bear.uid).windup_seconds()
	check(windup > 0.1, "the bear winds up first (%.2f s)" % windup)
	check(target.flash == 0.0 and target.pending_damage == 100, "nothing shows on the boar yet, and its bar holds")
	var waited := 0.0
	while target.flash == 0.0 and waited < 2.0:
		field._process(1.0 / 60.0)
		waited += 1.0 / 60.0
	check(absf(waited - windup) < 0.05, "it lands on the strike (%.2f s for a %.2f s wind-up)" % [waited, windup])
	check_eq(target.pending_damage, 0, "and the bar drops then")
	field.free()


func test_a_knockout_waits_for_its_hit() -> void:
	var made := _field()
	var field: BattleField = made.field
	var bear: BattleSim.Fighter = made.bear
	var boar: BattleSim.Fighter = made.boar
	var target := field.view_for_uid(boar.uid)
	boar.alive = false
	field.add_events([
		{"type": "hit", "from": bear.uid, "to": boar.uid, "x": boar.x, "y": boar.y, "fx": bear.x, "fy": bear.y, "amount": 900, "dealt": 900, "ranged": false},
		{"type": "death", "uid": boar.uid, "kind": "unit", "team": 1, "x": boar.x, "y": boar.y},
	])
	field._process(1.0 / 60.0)
	check(target.defeat < 0.0, "no poof before the blow lands")
	for i in 60:
		field._process(1.0 / 60.0)
	check(target.defeat >= 0.0, "then it's knocked out")
	check(field.view_for_uid(bear.uid)._smug_until > field.now(), "and the bear looks smug")
	field.free()


func test_the_last_knockout_gets_a_close_up() -> void:
	var made := _field()
	var field: BattleField = made.field
	var bear: BattleSim.Fighter = made.bear
	var boar: BattleSim.Fighter = made.boar
	boar.alive = false
	field.add_events([
		{"type": "hit", "from": bear.uid, "to": boar.uid, "x": boar.x, "y": boar.y, "fx": bear.x, "fy": bear.y, "amount": 900, "dealt": 900, "ranged": false},
		{"type": "death", "uid": boar.uid, "kind": "unit", "team": 1, "x": boar.x, "y": boar.y},
	])
	var wait := field.finish_fight(0)
	check(wait > 0.5, "the score waits for the slow-motion knockout (%.2f s)" % wait)
	check(field.is_celebrating(), "the camera pushes in on it")
	check(field.view_for_uid(bear.uid).is_celebrating(field.now() + 5.0) == false, "the winner's celebration doesn't last forever")
	field.free()


## Slow frames (a phone hitching while pictures load, or a slow browser)
## must not make an animal's bounce blow up: it stays its own shape.
func test_slow_frames_keep_animals_in_shape() -> void:
	var made := _field()
	var field: BattleField = made.field
	var view := field.view_for_uid(made.boar.uid)
	for frame_seconds in [1.0 / 9.0, 0.2, 0.35]:
		view.hurt(Vector2(0, 1), true)
		for i in 40:
			field._process(frame_seconds)
			check(absf(view.squash) < 1.0, "%.0f frames a second: its squash stays small (%.2f)" % [1.0 / frame_seconds, view.squash])
			check(view.body.scale.y < 3.0 and view.body.scale.x > 0.2, "%.0f frames a second: no strips or lines (%.2f x %.2f)" % [1.0 / frame_seconds, view.body.scale.x, view.body.scale.y])
	field.free()
