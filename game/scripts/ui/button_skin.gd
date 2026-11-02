class_name ButtonSkin
extends Control
## The look of a chunky game button, drawn behind its button's own text:
## a soft shadow, a dark rim, a deeper-colored edge underneath (so it looks
## like you can press it in), the colored face and a glossy highlight. The
## face sinks onto the edge while the button is held down. UIKit.button()
## adds one to every button it makes.

var color := UIKit.BLUE:
	set(value):
		color = value
		queue_redraw()


static func attach(button: Button, button_color: Color) -> ButtonSkin:
	var skin := ButtonSkin.new()
	skin.color = button_color
	skin.show_behind_parent = true
	skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(skin)
	# The button redraws whenever it's pressed, hovered or disabled.
	button.draw.connect(skin.queue_redraw)
	return skin


## How deep the pressable edge is for a button this tall.
static func edge_for(height: float) -> float:
	return clampf(height * 0.09, 4.0, 8.0)


func _draw() -> void:
	var button := get_parent() as Button
	if button == null:
		return
	var mode := button.get_draw_mode()
	var pressed := mode == BaseButton.DRAW_PRESSED or mode == BaseButton.DRAW_HOVER_PRESSED
	var base := color
	if button.disabled:
		base = Color(0.5, 0.54, 0.62).lerp(color, 0.15)
	elif mode == BaseButton.DRAW_HOVER:
		base = base.lightened(0.06)
	var rect := Rect2(Vector2.ZERO, size)
	var radius := int(clampf(size.y * 0.3, 8.0, 22.0))
	var edge := edge_for(size.y)
	var sink := edge - 2.0 if pressed else 0.0

	if not pressed:
		draw_style_box(UIKit.box(Color(UIKit.INK, 0.35), radius + 2), Rect2(rect.position + Vector2(0, 3), rect.size))
	draw_style_box(UIKit.box(base.darkened(0.55).lerp(UIKit.INK, 0.3), radius + 2), rect)
	var inner := rect.grow(-2.5)
	draw_style_box(UIKit.box(base.darkened(0.3), radius), inner)
	var face := Rect2(inner.position + Vector2(0, sink), Vector2(inner.size.x, inner.size.y - edge))
	draw_style_box(UIKit.box(base, radius), face)
	# The lower part of the face a touch darker, for a rounded look.
	var lower := UIKit.box(base.darkened(0.07), radius)
	lower.corner_radius_top_left = 0
	lower.corner_radius_top_right = 0
	draw_style_box(lower, Rect2(face.position + Vector2(0, face.size.y * 0.55), Vector2(face.size.x, face.size.y * 0.45)))
	# Gloss across the top.
	var gloss := UIKit.box(Color(1, 1, 1, 0.24 if not button.disabled else 0.1), maxi(radius - 3, 4))
	gloss.corner_radius_bottom_left = maxi(radius / 3, 3)
	gloss.corner_radius_bottom_right = maxi(radius / 3, 3)
	draw_style_box(gloss, Rect2(face.position + Vector2(4, 3), Vector2(face.size.x - 8, face.size.y * 0.42)))
