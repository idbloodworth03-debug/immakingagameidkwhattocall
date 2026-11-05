class_name ArenaPreview
extends Control
## A window onto an arena for the menus: the middle of the rendered field,
## cropped to fill the control, with two animals squaring up on each side
## (the arena's own new animals first). The animals get the same shader as
## in a fight and, if `animate` is on, breathe and bob. Draws nothing if the
## arena has no rendered picture.

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
		_make_bodies()
		queue_redraw()
## Breathing animals (the home screen); off for small thumbnails.
var animate := false

var _cast: Array = []
var _bodies: Array = []
var _time := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place_bodies()
		queue_redraw()


func _process(delta: float) -> void:
	if not animate or _bodies.is_empty():
		return
	_time += delta
	var c := "characters"
	for i in _bodies.size():
		var body: UnitView.Body = _bodies[i]
		var b := sin(_time * Feel.num(c, "breathe_speed", 2.4) + i * 1.7)
		var amount := Feel.num(c, "breathe_amount", 0.035)
		body.scale = Vector2(1.0 - b * amount * 0.6, 1.0 + b * amount)
		body.position.y = body.get_meta("foot_y", 0.0) - (b * 0.5 + 0.5) * Feel.num(c, "bob_pixels", 1.5)


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


func _make_bodies() -> void:
	for body in _bodies:
		body.queue_free()
	_bodies.clear()
	for i in _cast.size():
		var body := UnitView.Body.new()
		var id: String = _cast[i]
		body.frame = UnitSprites.frame(id, "idle", FACING[i], 0)
		if Feel.on("characters", "shader_enabled"):
			var material := ShaderMaterial.new()
			material.shader = UnitView.SHADER
			UnitView._apply_look(material)
			material.set_shader_parameter("flip", 1.0 if body.frame.flip else 0.0)
			material.set_shader_parameter("region", UnitView.region_uv(body.frame))
			body.material = material
		add_child(body)
		_bodies.append(body)
	_place_bodies()


## How big a tile is on screen, and where the view's center sits.
func _px() -> float:
	return maxf(size.x / VIEW.size.x, size.y / VIEW.size.y)


func _tile_to_screen(tx: float, ty: float) -> Vector2:
	return size / 2.0 + (Vector2(tx, ty) - VIEW.get_center()) * _px()


func _place_bodies() -> void:
	var px := _px()
	for i in _bodies.size():
		var body: UnitView.Body = _bodies[i]
		var spot: Vector2 = SPOTS[i]
		body.position = _tile_to_screen(spot.x, spot.y)
		body.set_meta("foot_y", body.position.y)
		body.k = px / UnitSprites.pixels_per_tile(_cast[i]) * SPRITE_SCALE
		body.queue_redraw()


func _draw() -> void:
	var ground := BattleField.arena_art(arena_id)
	if ground.is_empty():
		return
	# Fill the control, cropping whatever doesn't fit.
	var px := _px()
	var area: Rect2 = ground.area
	var top_left := _tile_to_screen(area.position.x / BattleSim.TILE, area.position.y / BattleSim.TILE)
	var bottom_right := _tile_to_screen(area.end.x / BattleSim.TILE, area.end.y / BattleSim.TILE)
	draw_texture_rect(ground.texture, Rect2(top_left, bottom_right - top_left), false)
	# Ground shadows and team rings under the animals.
	for i in _cast.size():
		var spot: Vector2 = SPOTS[i]
		var foot := _tile_to_screen(spot.x, spot.y)
		var color := BattleField.enemy_color() if i < 2 else BattleField.own_color()
		var ring := px * 0.45
		draw_set_transform(foot, 0.0, Vector2(1.0, 0.42))
		draw_circle(Vector2.ZERO, ring * 1.2, Color(0.05, 0.1, 0.05, 0.3))
		draw_circle(Vector2.ZERO, ring, Color(color, 0.18))
		draw_arc(Vector2.ZERO, ring, 0, TAU, 32, color.darkened(0.45), 5.0 / 0.42)
		draw_arc(Vector2.ZERO, ring, 0, TAU, 32, color, 3.0 / 0.42)
		draw_set_transform(Vector2.ZERO)
