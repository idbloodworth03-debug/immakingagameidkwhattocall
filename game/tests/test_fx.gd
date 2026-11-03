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
