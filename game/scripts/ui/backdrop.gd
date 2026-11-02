class_name Backdrop
extends Control
## The background behind the menus: a deep blue gradient, a faint pattern of
## paw prints and darker edges, so screens feel finished rather than flat.

## How visible the paw prints are.
var pattern_alpha := 0.05

static var _gradient: GradientTexture2D
static var _vignette: GradientTexture2D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_texture_rect(_gradient_texture(), rect, false, Color.WHITE)
	var paw := UIKit.icon(GameData.ui_icon("paw"))
	if paw != null:
		var step := 120.0
		var side := 46.0
		var row := 0
		var y := -step * 0.5
		while y < size.y + step:
			var x := -step * 0.5 + (step * 0.5 if row % 2 == 1 else 0.0)
			while x < size.x + step:
				var turn := 0.35 if (row + int(x / step)) % 2 == 0 else -0.25
				draw_set_transform(Vector2(x, y), turn)
				draw_texture_rect(paw, Rect2(-Vector2(side, side) / 2.0, Vector2(side, side)), false, Color(1, 1, 1, pattern_alpha))
				x += step
			y += step * 0.8
			row += 1
		draw_set_transform(Vector2.ZERO)
	draw_texture_rect(_vignette_texture(), rect, false, Color.WHITE)


func _gradient_texture() -> GradientTexture2D:
	if _gradient == null:
		var gradient := Gradient.new()
		gradient.set_color(0, UIKit.BG_TOP)
		gradient.set_color(1, UIKit.BG_BOTTOM)
		_gradient = GradientTexture2D.new()
		_gradient.gradient = gradient
		_gradient.fill_to = Vector2(0, 1)
		_gradient.width = 8
		_gradient.height = 256
	return _gradient


func _vignette_texture() -> GradientTexture2D:
	if _vignette == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(UIKit.INK, 0.0))
		gradient.set_color(1, Color(UIKit.INK, 0.45))
		gradient.add_point(0.6, Color(UIKit.INK, 0.0))
		_vignette = GradientTexture2D.new()
		_vignette.gradient = gradient
		_vignette.fill = GradientTexture2D.FILL_RADIAL
		_vignette.fill_from = Vector2(0.5, 0.42)
		_vignette.fill_to = Vector2(1.15, 1.05)
		_vignette.width = 128
		_vignette.height = 128
	return _vignette
