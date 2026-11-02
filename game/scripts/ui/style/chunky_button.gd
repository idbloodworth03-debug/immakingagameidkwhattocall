class_name ChunkyButton
extends Button
## A chunky game button (make it with UIStyle.button). Its look comes from
## the shared theme ("PrimaryButton", "SecondaryButton"...): a lighter top,
## a darker lip underneath and a thick outline. Its content (icon, outlined
## text, Acorn price) sits on the face and sinks with it when pressed; the
## button squashes down on press, bounces back on release, and clicks.

var kind := "secondary":
	set(value):
		kind = value
		theme_type_variation = kind.capitalize() + "Button"
var square := false:
	set(value):
		square = value
		_fit()
## The narrowest it gets, whatever its content.
var min_width := 0.0:
	set(value):
		min_width = value
		_fit()
var content: HBoxContainer
var text_label: Label
var cost_label: Label
var _sunk := false


static func make(text_value: String, button_kind: String, icon_key := "", cost := -1, size_key := "large") -> ChunkyButton:
	var b := ChunkyButton.new()
	b.kind = button_kind
	b.focus_mode = Control.FOCUS_NONE
	b.content = UIStyle.hbox("xs")
	b.content.alignment = BoxContainer.ALIGNMENT_CENTER
	b.content.set_anchors_preset(Control.PRESET_FULL_RECT)
	var side := roundi(UIStyle.text_size(size_key) * 1.1)
	if icon_key != "":
		b.content.add_child(UIStyle.icon(icon_key, Color.WHITE, side))
	if text_value != "":
		b.text_label = UIStyle.label(text_value, size_key)
		b.content.add_child(b.text_label)
	if cost >= 0:
		var price := UIStyle.hbox("xs")
		price.add_theme_constant_override("separation", 2)
		price.add_child(UIStyle.icon("acorn", UIStyle.color("acorn").lightened(0.15), side))
		b.cost_label = UIStyle.label(str(cost), size_key)
		price.add_child(b.cost_label)
		b.content.add_child(price)
	b.add_child(b.content)
	b.content.minimum_size_changed.connect(b._fit)
	b.button_down.connect(func() -> void: UIKit.press_squash(b))
	b.button_up.connect(func() -> void: UIKit.release_bounce(b))
	b.pressed.connect(func() -> void: Sound.play("tap"))
	b.resized.connect(func() -> void: b.pivot_offset = b.size / 2.0)
	return b


func _ready() -> void:
	_fit()
	_place_content()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_THEME_CHANGED:
			_fit()
			_place_content()
		NOTIFICATION_DRAW:
			var mode := get_draw_mode()
			var sunk := mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
			if sunk != _sunk:
				_sunk = sunk
				_place_content.call_deferred()


## As wide as its content (at least as tall as a finger needs).
func _fit() -> void:
	if content == null:
		return
	var box := get_theme_stylebox("normal")
	var tall := UIStyle.num("button", "min_height", 88)
	var wide := content.get_combined_minimum_size().x + box.content_margin_left + box.content_margin_right
	custom_minimum_size = Vector2(tall if square else maxf(wide, min_width), tall)


## The content sits on the face: above the lip, lower while pressed.
func _place_content() -> void:
	if content == null:
		return
	var border := UIStyle.num("button", "border", 4)
	var lip := UIStyle.num("button", "lip", 8)
	var sink := lip - UIStyle.num("button", "pressed_lip", 2) if _sunk else 0.0
	content.offset_left = border
	content.offset_right = -border
	content.offset_top = border + sink
	content.offset_bottom = -border - lip + sink
	content.modulate = Color(1, 1, 1, 0.8) if disabled or kind == "disabled" else Color.WHITE


## Changes the text (and the price, if it has one).
func set_label(text_value: String, cost := -1) -> void:
	if text_label != null:
		text_label.text = text_value
	if cost_label != null and cost >= 0:
		cost_label.text = str(cost)
