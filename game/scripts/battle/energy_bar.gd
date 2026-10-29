class_name EnergyBar
extends Control
## The energy meter under the hand: one segment per point of energy, the
## next segment filling up as energy comes in, and the whole number in a
## bubble on the left. It pulses while energy comes in at double speed.

var max_value := 10:
	set(v):
		max_value = maxi(1, v)
		queue_redraw()
var value := 0.0:
	set(v):
		if not is_equal_approx(v, value):
			value = v
			queue_redraw()
var double_speed := false

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if double_speed:
		_time += delta
		queue_redraw()


func _draw() -> void:
	var bubble := size.y
	var left := bubble * 0.9
	var gap := 3.0
	var bar := Rect2(left, size.y * 0.2, size.x - left, size.y * 0.6)
	draw_style_box(UIKit.box(Color(0, 0, 0, 0.5), 10), bar.grow(3))
	var segment := (bar.size.x - gap * (max_value - 1)) / max_value
	var full_color := UIKit.ENERGY
	if double_speed:
		full_color = full_color.lightened(0.15 + 0.12 * sin(_time * 6.0))
	for i in max_value:
		var rect := Rect2(bar.position.x + i * (segment + gap), bar.position.y, segment, bar.size.y)
		draw_style_box(UIKit.box(Color(1, 1, 1, 0.08), 5), rect)
		var fill := clampf(value - i, 0.0, 1.0)
		if fill >= 1.0:
			draw_style_box(UIKit.box(full_color, 5), rect)
			draw_rect(Rect2(rect.position + Vector2(3, 3), Vector2(rect.size.x - 6, rect.size.y * 0.22)), Color(1, 1, 1, 0.3))
		elif fill > 0.0:
			draw_rect(Rect2(rect.position, Vector2(rect.size.x * fill, rect.size.y)), full_color.darkened(0.35))

	# The bubble with the whole number.
	var center := Vector2(bubble / 2.0, size.y / 2.0)
	draw_circle(center, bubble / 2.0, UIKit.ENERGY.darkened(0.5))
	draw_circle(center, bubble / 2.0 - 3.0, UIKit.ENERGY)
	draw_circle(center - Vector2(0, bubble * 0.12), bubble * 0.3, Color(1, 1, 1, 0.12))
	var font := get_theme_default_font()
	var text := str(floori(value))
	var font_size := int(bubble * 0.55)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := Vector2(center.x - width / 2.0, center.y + font_size * 0.36)
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color(0, 0, 0, 0.8))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
