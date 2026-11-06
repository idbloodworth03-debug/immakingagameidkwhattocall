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
## The animals as 3D models (as in a fight, feel.json "models"): a small 3D
## view over the picture. Still thumbnails (animate off) are rendered once.
var _viewport: SubViewport
var _camera: Camera3D
var _models: Array = []


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
	if _viewport != null:
		_viewport.queue_free()
		_viewport = null
	_models.clear()
	if Feel.on("models", "enabled", false) and _cast.all(func(id: String) -> bool: return ModelStage.has_model(id)):
		_make_models()
		return
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


func _make_models() -> void:
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if animate else SubViewport.UPDATE_ONCE
	add_child(_viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world := WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)
	_camera = Camera3D.new()
	_camera.near = 0.5
	_camera.far = 400.0
	_viewport.add_child(_camera)
	for i in _cast.size():
		var id: String = _cast[i]
		var m := ModelStage.new_model(id, ModelStage.outline_px(_render_scale()), not animate)
		if m == null:
			continue
		m.body.scale = Vector3.ONE * ModelStage.tile_scale(id) * SPRITE_SCALE
		var spot: Vector2 = SPOTS[i]
		m.pivot.position = ModelStage.ground(spot * BattleSim.TILE)
		ModelStage.face_toward(m, FACING[i])
		_viewport.add_child(m.pivot)
		if m.player != null and m.lengths.has("idle"):
			if animate:
				# Breathing and looking about, each in its own time.
				m.player.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
				m.player.play("idle")
				m.player.seek(randf() * float(m.lengths.idle), true)
			else:
				m.player.current_animation = "idle"
				m.player.seek(0.0, true)
		_models.append(m)
	_place_models()


func _render_scale() -> float:
	var stretch := get_viewport().get_final_transform().get_scale().x if is_inside_tree() else 1.0
	return clampf(stretch, 1.0, Feel.num("models", "render_scale_max", 2.0))


func _place_models() -> void:
	if _viewport == null or size.x <= 0.0:
		return
	_viewport.size = Vector2i((size * _render_scale()).round())
	ModelStage.aim(_camera, VIEW.get_center() * BattleSim.TILE, _px(), size.y)
	if not animate:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	queue_redraw()


## How big a tile is on screen, and where the view's center sits.
func _px() -> float:
	return maxf(size.x / VIEW.size.x, size.y / VIEW.size.y)


func _tile_to_screen(tx: float, ty: float) -> Vector2:
	return size / 2.0 + (Vector2(tx, ty) - VIEW.get_center()) * _px()


func _place_bodies() -> void:
	_place_models()
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
	if _viewport != null:
		draw_texture_rect(_viewport.get_texture(), Rect2(Vector2.ZERO, size), false)
