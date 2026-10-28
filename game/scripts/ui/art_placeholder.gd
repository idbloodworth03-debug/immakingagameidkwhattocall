class_name ArtPlaceholder
extends Control
## Stand-in art drawn in code: a colored circle (or rounded square, or cage)
## with a few letters. Swap these for real images once the art is made.

enum Shape { CIRCLE, ROUNDED, CAGE }

var text := "":
	set(value):
		text = value
		queue_redraw()
var color := Color.GRAY:
	set(value):
		color = value
		queue_redraw()
var shape := Shape.CIRCLE:
	set(value):
		shape = value
		queue_redraw()
var dimmed := false:
	set(value):
		dimmed = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var fill := color.darkened(0.55).lerp(Color(0.2, 0.2, 0.25), 0.5) if dimmed else color
	var edge := fill.darkened(0.4)
	var rect := Rect2(Vector2.ZERO, size)
	var short_side := minf(size.x, size.y)

	match shape:
		Shape.CIRCLE:
			var center := size / 2.0
			draw_circle(center, short_side / 2.0, edge)
			draw_circle(center, short_side / 2.0 - maxf(2.0, short_side * 0.06), fill)
		Shape.ROUNDED:
			draw_style_box(UIKit.box(edge, int(short_side * 0.18)), rect)
			var inner := rect.grow(-maxf(2.0, short_side * 0.05))
			draw_style_box(UIKit.box(fill, int(short_side * 0.15)), inner)
		Shape.CAGE:
			draw_style_box(UIKit.box(edge, int(short_side * 0.18)), rect)
			var inner := rect.grow(-maxf(3.0, short_side * 0.06))
			draw_style_box(UIKit.box(fill.darkened(0.25), int(short_side * 0.14)), inner)
			# Bars across the front of the cage.
			var bars := 5
			for i in bars:
				var x := inner.position.x + inner.size.x * (i + 1) / (bars + 1)
				draw_line(Vector2(x, inner.position.y + 4), Vector2(x, inner.end.y - 4), fill.lightened(0.35), maxf(2.0, short_side * 0.045))
			draw_line(Vector2(inner.position.x + 4, inner.position.y + inner.size.y * 0.18), Vector2(inner.end.x - 4, inner.position.y + inner.size.y * 0.18), fill.lightened(0.2), maxf(2.0, short_side * 0.035))

	if text.is_empty():
		return
	var font := get_theme_default_font()
	var font_size := int(short_side * (0.42 if text.length() <= 2 else 0.3))
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := Vector2((size.x - text_width) / 2.0, size.y / 2.0 + font_size * 0.36)
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(2, int(font_size * 0.18)), Color(0, 0, 0, 0.75))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.55) if dimmed else Color.WHITE)
