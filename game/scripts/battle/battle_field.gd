class_name BattleField
extends Control
## Draws the battlefield (both halves, the river, bridges and towers) and
## reports where the player taps. Your side is the bottom half.

signal tapped(at: Vector2, zone: String)

const RIVER_TOP := 0.465
const RIVER_BOTTOM := 0.535
const LANES := [0.22, 0.78]
## Towers on the player's side as [x, y, is_king] (0-1 of the field size).
## The opponent's towers are mirrored at the top.
const TOWERS := [[0.22, 0.82, false], [0.78, 0.82, false], [0.5, 0.93, true]]

var grass := Color("#5f9e4f")
## Zones to softly highlight while a card is selected.
var highlight_zones: Array = []:
	set(value):
		highlight_zones = value
		queue_redraw()
var own_tower_damaged := false:
	set(value):
		own_tower_damaged = value
		queue_redraw()

var _press_at := Vector2.ZERO
var _pressed := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)


func zone_at(point: Vector2) -> String:
	var y := point.y / size.y
	if y < RIVER_TOP:
		return "enemy_side"
	if y <= RIVER_BOTTOM:
		return "river"
	return "own_side"


func king_position(own: bool) -> Vector2:
	var king: Array = TOWERS[2]
	var y: float = king[1] if own else 1.0 - king[1]
	return Vector2(king[0] * size.x, y * size.y)


func token_size() -> float:
	return size.x * 0.095


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_at = event.position
			_pressed = true
		elif _pressed:
			_pressed = false
			if event.position.distance_to(_press_at) < 24.0:
				tapped.emit(event.position, zone_at(event.position))


func _draw() -> void:
	var w := size.x
	var h := size.y
	var river_top := h * RIVER_TOP
	var river_bottom := h * RIVER_BOTTOM

	# Grass with a faint checker pattern so the field reads as tiles.
	draw_rect(Rect2(0, 0, w, river_top), grass.darkened(0.1))
	draw_rect(Rect2(0, river_bottom, w, h - river_bottom), grass)
	var tile := w / 18.0
	var rows := ceili(h / tile)
	for row in rows:
		for col in 18:
			if (row + col) % 2 == 0:
				draw_rect(Rect2(col * tile, row * tile, tile, tile), Color(1, 1, 1, 0.04))

	# River and bridges
	draw_rect(Rect2(0, river_top, w, river_bottom - river_top), Color("#3a8fd6"))
	for i in 6:
		var x := w * (i + 0.5) / 6.0
		draw_line(Vector2(x - 20, (river_top + river_bottom) / 2.0), Vector2(x + 20, (river_top + river_bottom) / 2.0), Color(1, 1, 1, 0.35), 3.0)
	for lane in LANES:
		var bridge := Rect2(lane * w - w * 0.07, river_top - 8, w * 0.14, river_bottom - river_top + 16)
		draw_style_box(UIKit.box(Color("#9a6b3f"), 6), bridge)
		for plank in 4:
			var y := bridge.position.y + bridge.size.y * (plank + 1) / 5.0
			draw_line(Vector2(bridge.position.x + 4, y), Vector2(bridge.end.x - 4, y), Color("#6e4a2a"), 2.0)

	# Where the selected card may be released
	var glow := Color(1, 1, 0.6, 0.18)
	if highlight_zones.has("own_side"):
		draw_rect(Rect2(0, river_bottom, w, h - river_bottom), glow)
		draw_rect(Rect2(2, river_bottom + 2, w - 4, h - river_bottom - 4), Color(1, 1, 0.6, 0.6), false, 4.0)
	if highlight_zones.has("river"):
		draw_rect(Rect2(0, river_top, w, river_bottom - river_top), glow)
		draw_rect(Rect2(2, river_top + 2, w - 4, river_bottom - river_top - 4), Color(1, 1, 0.6, 0.8), false, 4.0)

	# Towers
	for tower in TOWERS:
		_draw_tower(tower, true)
		_draw_tower(tower, false)


func _draw_tower(tower: Array, own: bool) -> void:
	var king: bool = tower[2]
	var tower_width := size.x * (0.2 if king else 0.15)
	var center := Vector2(tower[0] * size.x, (tower[1] if own else 1.0 - tower[1]) * size.y)
	var rect := Rect2(center - Vector2(tower_width, tower_width) / 2.0, Vector2(tower_width, tower_width))
	var color := Color("#3d7fd9") if own else Color("#d94a4a")
	var style := UIKit.box(color, 12)
	style.set_border_width_all(4)
	style.border_color = Color("#ffcf40") if own and own_tower_damaged else color.darkened(0.45)
	draw_style_box(style, rect)
	draw_style_box(UIKit.box(color.lightened(0.25), 8), rect.grow(-tower_width * 0.22))
