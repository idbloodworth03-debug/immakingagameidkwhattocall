class_name ArenaPreview
extends Control
## A window onto an arena for the menus: the middle of the rendered field,
## cropped to fill the control, with two animals squaring up on each side
## (the arena's own new animals first). Draws nothing if the arena has no
## rendered picture.

## The part of the field shown, in tiles. Centered a little below the middle
## line, so the animals stand clear of the arena's name along the bottom.
const VIEW := Rect2(-1.0, 4.0, 18.0, 14.0)
## Where the animals stand, in tiles: the far pair (red), then the near
## pair (blue).
const SPOTS := [Vector2(4.6, 8.2), Vector2(11.4, 7.8), Vector2(5.4, 11.4), Vector2(10.6, 11.8)]
## Smaller than in a fight, so four fit in a small window.
const SPRITE_SCALE := 1.15
## Which way each one faces (degrees clockwise from up): toward the middle.
const FACING := [135.0, 225.0, 45.0, 315.0]

var arena_id := "":
	set(value):
		arena_id = value
		_cast = _pick_cast(value)
		queue_redraw()

var _cast: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


## Four animals with sprites: the ones unlocked in this arena, then the
## arenas before it.
static func _pick_cast(id: String) -> Array:
	var index := GameData.arena_index_by_id.get(id, 0) as int
	var cast := []
	for arena in range(index, -1, -1):
		for card_id in GameData.cards_in_arena(arena):
			if cast.size() < SPOTS.size() and not GameData.is_tool(card_id) and UnitSprites.has(card_id):
				cast.append(card_id)
	return cast


func _draw() -> void:
	var ground := BattleField.arena_art(arena_id)
	if ground.is_empty():
		return
	# Fill the control, cropping whatever doesn't fit.
	var px := maxf(size.x / VIEW.size.x, size.y / VIEW.size.y)
	var center := VIEW.get_center()
	var tile_to_screen := func(tx: float, ty: float) -> Vector2:
		return size / 2.0 + (Vector2(tx, ty) - center) * px
	var area: Rect2 = ground.area
	var top_left: Vector2 = tile_to_screen.call(area.position.x / BattleSim.TILE, area.position.y / BattleSim.TILE)
	var bottom_right: Vector2 = tile_to_screen.call(area.end.x / BattleSim.TILE, area.end.y / BattleSim.TILE)
	draw_texture_rect(ground.texture, Rect2(top_left, bottom_right - top_left), false)
	for i in _cast.size():
		var id: String = _cast[i]
		var far := i < 2
		var spot: Vector2 = SPOTS[i]
		var foot: Vector2 = tile_to_screen.call(spot.x, spot.y)
		var k := px / UnitSprites.pixels_per_tile(id) * SPRITE_SCALE
		var color := BattleField.ENEMY_COLOR if far else BattleField.OWN_COLOR
		var ring := px * 0.45
		draw_set_transform(foot, 0.0, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, ring, Color(color, 0.2))
		draw_arc(Vector2.ZERO, ring, 0, TAU, 32, Color(color, 0.85), 3.0)
		draw_set_transform(Vector2.ZERO)
		var info := UnitSprites.frame(id, "idle", FACING[i], 0)
		if info.is_empty():
			continue
		var region: Rect2 = info.region
		var anchor: Vector2 = info.anchor * k
		if info.flip:
			draw_set_transform(foot, 0.0, Vector2(-1, 1))
			draw_texture_rect_region(info.texture, Rect2(-anchor, region.size * k), region)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_texture_rect_region(info.texture, Rect2(foot - anchor, region.size * k), region)
