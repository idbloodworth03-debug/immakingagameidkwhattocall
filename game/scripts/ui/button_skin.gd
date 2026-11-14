class_name ButtonSkin
extends Control
## The look of a chunky game button, drawn behind its button's own text:
## the painted button piece (SkinBox "button": a thick dark outline, a
## deeper-colored edge underneath so it looks like you can press it in, the
## colored face and a glossy highlight) in the button's color. The face
## sinks onto the edge while the button is held down. UIKit.button() adds
## one to every button it makes.

var color := UIKit.BLUE:
	set(value):
		color = value
		queue_redraw()

var _up: SkinBox
var _down: SkinBox


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
		# Solid and muted, never faded.
		base = UIKit.GREY
	elif mode == BaseButton.DRAW_HOVER:
		base = base.lightened(0.06)
	if _up == null:
		_up = SkinBox.make("button")
		_down = SkinBox.make("button_pressed")
	var box := _down if pressed else _up
	box.tint = base
	box.shine_alpha = 0.55 if button.disabled else 1.0
	draw_style_box(box, Rect2(Vector2.ZERO, size))
