class_name ArenaPreview
extends Control
## A window onto an arena for the menus: the far half of the rendered arena
## with its three treehouse dens, cropped to fill the control. Falls back to
## ArenaArt's little scene if the arena has no rendered picture.

## The part of the field shown, in tiles.
const VIEW := Rect2(-3.0, -3.6, 24.0, 19.6)

var arena_id := "":
	set(value):
		arena_id = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var ground := BattleField.arena_art(arena_id)
	if ground.is_empty():
		return
	# Fill the control, cropping whatever doesn't fit; keep the dens in view.
	var px := maxf(size.x / VIEW.size.x, size.y / VIEW.size.y)
	var center := VIEW.get_center() + Vector2(0, -1.5)
	var tile_to_screen := func(tx: float, ty: float) -> Vector2:
		return size / 2.0 + (Vector2(tx, ty) - center) * px
	var area: Rect2 = ground.area
	var top_left: Vector2 = tile_to_screen.call(area.position.x / BattleSim.TILE, area.position.y / BattleSim.TILE)
	var bottom_right: Vector2 = tile_to_screen.call(area.end.x / BattleSim.TILE, area.end.y / BattleSim.TILE)
	draw_texture_rect(ground.texture, Rect2(top_left, bottom_right - top_left), false)
	# Farthest first, so nearer dens overlap it.
	for den in [["main_red", 9.0, 1.8], ["side_red", 4.0, 4.5], ["side_red", 14.0, 4.5]]:
		var art := BattleField._den_art(den[0])
		if art.is_empty():
			continue
		var k: float = art.scale * px / BattleSim.TILE * BattleField.DEN_SCALE
		var texture: Texture2D = art.texture
		var foot: Vector2 = tile_to_screen.call(den[1], den[2])
		draw_texture_rect(texture, Rect2(foot - art.anchor * k, texture.get_size() * k), false)
