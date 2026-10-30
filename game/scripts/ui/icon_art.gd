class_name IconArt
extends Control
## Card and button art: a colored shape (circle, rounded square or cage) with
## either a rendered portrait of the animal, a white icon from
## game-icons.net, or (with neither) a few letters.

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
var icon: Texture2D:
	set(value):
		icon = value
		queue_redraw()
var flip_icon := false:
	set(value):
		flip_icon = value
		queue_redraw()
var icon_color := Color.WHITE
## A rendered picture of the animal (see UnitSprites.portrait). Wins over the icon.
var portrait: Texture2D:
	set(value):
		portrait = value
		queue_redraw()
## How much of the shape the icon fills.
var icon_scale := 0.68


static func make(icon_name: String, background: Color, art_shape := Shape.CIRCLE, art_size := Vector2.ZERO) -> IconArt:
	var art := IconArt.new()
	art.icon = UIKit.icon(icon_name)
	art.color = background
	art.shape = art_shape
	if art_size != Vector2.ZERO:
		art.custom_minimum_size = art_size
	return art


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
	var center := size / 2.0

	match shape:
		Shape.CIRCLE:
			draw_circle(center, short_side / 2.0, edge)
			draw_circle(center, short_side / 2.0 - maxf(2.0, short_side * 0.06), fill)
			draw_circle(center - Vector2(0, short_side * 0.12), short_side * 0.32, Color(1, 1, 1, 0.07))
		Shape.ROUNDED:
			draw_style_box(UIKit.box(edge, int(short_side * 0.18)), rect)
			var inner := rect.grow(-maxf(2.0, short_side * 0.05))
			draw_style_box(UIKit.box(fill, int(short_side * 0.15)), inner)
			var sheen := Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.45))
			draw_style_box(UIKit.box(Color(1, 1, 1, 0.08), int(short_side * 0.15)), sheen)
		Shape.CAGE:
			draw_style_box(UIKit.box(edge, int(short_side * 0.18)), rect)
			draw_style_box(UIKit.box(fill.darkened(0.45), int(short_side * 0.15)), rect.grow(-maxf(3.0, short_side * 0.06)))
			if icon == null:
				icon = UIKit.icon(GameData.ui_icon("cage"))
			icon_color = fill.lightened(0.35)

	if portrait != null:
		# The animal stands in the frame, a little bigger than the shape so
		# it pops out of it; its own transparent background shows the color.
		var side := short_side * 1.12
		var at := center - Vector2(side, side) / 2.0 + Vector2(0, -short_side * 0.04)
		var tint := Color(0.45, 0.45, 0.5, 0.8) if dimmed else Color.WHITE
		draw_texture_rect(portrait, Rect2(at, Vector2(side, side)), false, tint)
		return

	if icon != null:
		var side := short_side * icon_scale
		var icon_rect := Rect2(center - Vector2(side, side) / 2.0, Vector2(side, side))
		var tint := Color(icon_color, 0.45) if dimmed else icon_color
		_draw_icon(icon_rect.position + Vector2(0, short_side * 0.03), side, Color(0, 0, 0, 0.3 * tint.a))
		_draw_icon(icon_rect.position, side, tint)
		return

	if text.is_empty():
		return
	var font := get_theme_default_font()
	var font_size := int(short_side * (0.42 if text.length() <= 2 else 0.3))
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := Vector2((size.x - text_width) / 2.0, size.y / 2.0 + font_size * 0.36)
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(2, int(font_size * 0.18)), Color(0, 0, 0, 0.75))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.55) if dimmed else Color.WHITE)


func _draw_icon(top_left: Vector2, side: float, tint: Color) -> void:
	if flip_icon:
		draw_set_transform(Vector2(top_left.x + side, top_left.y), 0.0, Vector2(-1, 1))
		draw_texture_rect(icon, Rect2(Vector2.ZERO, Vector2(side, side)), false, tint)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture_rect(icon, Rect2(top_left, Vector2(side, side)), false, tint)
