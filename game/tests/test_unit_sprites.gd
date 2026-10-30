extends TestCase


func _rendered() -> Array:
	return GameData.card_order.filter(func(id): return UnitSprites.has(id))


func test_every_frame_fits_its_sheet() -> void:
	for id in _rendered():
		for anim in ["idle", "walk", "attack", "death"]:
			var info := UnitSprites.animation(id, anim)
			check(not info.is_empty(), "%s has a %s animation" % [id, anim])
			if info.is_empty():
				continue
			for facing in [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]:
				for f in int(info.frames):
					var frame := UnitSprites.frame(id, anim, facing, f)
					var size: Vector2 = frame.texture.get_size()
					var region: Rect2 = frame.region
					check(region.position.x >= 0 and region.position.y >= 0 and region.end.x <= size.x and region.end.y <= size.y,
						"%s %s %d deg frame %d is inside the sheet" % [id, anim, facing, f])


func test_left_facing_frames_mirror_right_facing_ones() -> void:
	for id in _rendered():
		var right := UnitSprites.frame(id, "walk", 90.0, 2)
		var left := UnitSprites.frame(id, "walk", 270.0, 2)
		check(not right.flip and left.flip, "%s: facing left is facing right mirrored" % id)
		check_eq(left.region, right.region, "%s: same frame either way" % id)


func test_sheets_fit_phone_texture_limits() -> void:
	for id in _rendered():
		var size: Vector2 = UnitSprites.frame(id, "idle", 0.0, 0).texture.get_size()
		check(size.x <= 4096 and size.y <= 4096, "%s sheet is %dx%d, at most 4096 on a side" % [id, size.x, size.y])


func test_attacks_land_mid_animation() -> void:
	for id in _rendered():
		var hit := float(UnitSprites.animation(id, "attack").get("hit", -1.0))
		check(hit > 0.2 and hit < 0.8, "%s: the hit comes partway through the attack (%.2f)" % [id, hit])


func test_rendered_animals_have_portraits() -> void:
	for id in _rendered():
		check(UnitSprites.portrait(id) != null, "%s has a card portrait" % id)
