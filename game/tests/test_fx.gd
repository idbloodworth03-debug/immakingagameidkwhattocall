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


func test_a_quiet_hit_adds_to_a_number_but_never_makes_one() -> void:
	fx.crowded = false
	fx.numbers.clear()
	fx.number(Vector2.ZERO, 40, "hurt_enemy", false, "bear", true)
	check_eq(fx.numbers.size(), 0, "no new number from a quiet hit")
	fx.number(Vector2.ZERO, 300, "hurt_enemy", true, "bear")
	fx.numbers[0].age = 0.2
	fx.number(Vector2.ZERO, 40, "hurt_enemy", false, "bear", true)
	check_eq(fx.numbers.size(), 1, "still one number")
	check_eq(int(fx.numbers[0].amount), 340, "the quiet hit is counted in it")
	check_eq(float(fx.numbers[0].age), 0.2, "without making it pop again or stay longer")


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


func test_the_yetis_pound_rings_out_in_ice() -> void:
	# The pound: a layered ice blast (core, glow, shockwave, shards, cracks)
	# over the frost patch it leaves; a frozen animal gets a smaller one.
	var made := _field()
	var field: BattleField = made.field
	var bear: BattleSim.Fighter = made.bear
	var boar: BattleSim.Fighter = made.boar
	field.add_events([
		{"type": "pound", "uid": bear.uid, "x": bear.x, "y": bear.y, "radius": 2000},
		{"type": "frost", "uid": bear.uid, "x": bear.x, "y": bear.y, "radius": 2200, "seconds": 5.0},
	])
	field._process(1.0 / 60.0)
	var blasts: Array = field.fx.effects.filter(func(f: Dictionary) -> bool: return f.kind == "ice_blast")
	check_eq(blasts.size(), 1, "one ice blast")
	if blasts.size() == 1:
		var blast: Dictionary = blasts[0]
		check(int(blast.get("shards", 0)) >= 6 and int(blast.get("cracks", 0)) >= 3, "with ice shards and frost cracks (%d, %d)" % [int(blast.get("shards", 0)), int(blast.get("cracks", 0))])
		check(float(blast.radius) > 2000.0 * field._scale(), "reaching past the pound's radius")
		check(blast.has("dark") and blast.has("core"), "in the ice colors")
	check(not field.fx.effects.filter(func(f: Dictionary) -> bool: return f.kind == "frost_patch").is_empty(), "the frost patch stays behind")
	check(field._trauma > 0.0, "and the field shakes")
	for i in 80:
		field._process(1.0 / 60.0)
	check(field.fx.effects.filter(func(f: Dictionary) -> bool: return f.kind == "ice_blast").is_empty(), "the blast melts away within a second and a half")
	field.add_events([{"type": "freeze", "uid": boar.uid, "x": boar.x, "y": boar.y}])
	field._process(1.0 / 60.0)
	var small: Array = field.fx.effects.filter(func(f: Dictionary) -> bool: return f.kind == "ice_blast")
	check(small.size() == 1 and float(small[0].radius) < 2000.0 * field._scale(), "a frozen animal gets a smaller burst")
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


## Every attack style's impact has an element look (feel.json "elements"),
## and plain hits have the "impact" look.
func test_every_attack_style_has_an_element_look() -> void:
	var elements: Dictionary = GameData.feel.get("elements", {})
	var by_style: Dictionary = elements.get("style_elements", {})
	for id in GameData.styles:
		if not GameData.styles[id] is Dictionary:
			continue  # the file's note
		var kind := String(GameData.styles[id].get("kind", ""))
		check(by_style.has(kind), "%s's %s has an element" % [id, kind])
		var el: Dictionary = elements.get(String(by_style.get(kind, "")), {})
		check(el.has("core") and el.has("glow") and el.has("dark") and el.has("bits"), "%s's element has its colors and bits" % kind)
	check(elements.has("impact"), "plain hits have the impact look")


## An impact bursts in layers (a blast: core, glow, ring, the element's
## bits) and leaves a fade on the ground; a Mythic's big one has two rings,
## more bits and shakes the field.
func test_an_impact_bursts_in_layers_and_leaves_a_mark() -> void:
	var made := _field()
	var field: BattleField = made.field
	var small: Dictionary = field._blast("fire", Vector2(300, 400), 60.0, false)
	check_eq(String(small.get("kind", "")), "blast", "a blast")
	check(small.has("core") and small.has("dark") and String(small.get("bits", "")) == "flame", "in fire's look: core, dark edge, flames")
	check_eq(int(small.get("rings", 0)), 1, "one shockwave ring")
	var big: Dictionary = field._blast("water", Vector2(300, 500), 80.0, true)
	check(int(big.get("rings", 0)) >= 2 and int(big.get("count", 0)) > int(small.get("count", 0)), "a Mythic's big one: two rings and more bits")
	check(field._trauma > 0.0, "and it shakes the field")
	check(not field.fx.effects.filter(func(f: Dictionary) -> bool: return f.kind == "linger").is_empty(), "the fade stays on the ground")
	for i in 130:
		field._process(1.0 / 60.0)
	check(field.fx.effects.filter(func(f: Dictionary) -> bool: return f.kind == "blast").is_empty(), "the bursts are gone within two seconds")
	field.free()


## A plain hit gets the small layered burst too.
func test_a_plain_hit_gets_its_layers() -> void:
	var made := _field()
	var field: BattleField = made.field
	field._impact("swipe", Vector2(300, 400), Vector2.RIGHT, 1.0, false)
	var blasts: Array = field.fx.effects.filter(func(f: Dictionary) -> bool: return f.kind == "blast")
	check_eq(blasts.size(), 1, "one small blast")
	if blasts.size() == 1:
		check_eq(String(blasts[0].bits), "spark", "in the impact look")
		check(blasts[0].dir == Vector2.RIGHT, "pushed along the hit")
	field.free()
