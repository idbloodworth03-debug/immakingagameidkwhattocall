class_name Modal
extends Control
## A popup window over the current screen. Tap the dark area outside the
## window, or the X, to close it.

signal closed

var body: VBoxContainer


## Opens `content` in a popup and returns the popup. `content` can be any
## control; long content scrolls.
static func open(content: Control, title := "", width := 660.0) -> Modal:
	var modal := Modal.new()
	modal._build(content, title, width)
	var tree := Engine.get_main_loop() as SceneTree
	var layer := tree.get_first_node_in_group("popup_layer")
	(layer if layer else tree.current_scene).add_child(modal)
	return modal


## A yes/no question. `on_yes` runs only if the player confirms.
static func confirm(question: String, yes_text: String, on_yes: Callable, yes_color := UIKit.GREEN) -> Modal:
	var content := UIKit.vbox(20)
	var text := UIKit.paragraph(question, 26, UIKit.TEXT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(text)
	var row := UIKit.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(row)
	var modal := open(content, "", 560.0)
	var cancel := UIKit.button("Cancel", UIKit.BLUE, 26, Vector2(200, 76))
	cancel.pressed.connect(modal.close)
	row.add_child(cancel)
	var yes := UIKit.button(yes_text, yes_color, 26, Vector2(220, 76))
	yes.pressed.connect(func() -> void:
		modal.close()
		on_yes.call()
	)
	row.add_child(yes)
	return modal


func close() -> void:
	closed.emit()
	queue_free()


func _build(content: Control, title: String, width: float) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group(HoldInfo.COVER_GROUP)

	var dim := ColorRect.new()
	dim.color = Color(UIKit.INK, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIKit.on_tap(dim, close)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# A board of painted wood, its title on a trail sign across the top.
	var window := PanelContainer.new()
	window.add_theme_stylebox_override("panel", UIKit.raised(UIKit.PANEL, 26, 2))
	window.custom_minimum_size = Vector2(width, 0)
	center.add_child(window)

	var column := UIKit.vbox(0)
	window.add_child(column)

	var header := MarginContainer.new()
	header.add_theme_constant_override("margin_left", 12)
	header.add_theme_constant_override("margin_right", 8)
	header.add_theme_constant_override("margin_top", 8)
	column.add_child(header)
	var header_row := UIKit.hbox(8)
	header.add_child(header_row)
	if title != "":
		var plank := PanelContainer.new()
		plank.add_theme_stylebox_override("panel", UIStyle.sign_box())
		plank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plank.add_child(UIKit.label(title, 34))
		header_row.add_child(plank)
	header_row.add_child(UIKit.spacer())
	var close_button := UIKit.icon_button("close", UIKit.RED, 60)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	header_row.add_child(close_button)

	var margin := MarginContainer.new()
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	margin.add_theme_constant_override("margin_top", 6 if title == "" else 12)
	column.add_child(margin)
	body = UIKit.vbox(16)
	margin.add_child(body)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(width - 40, 0)
	body.add_child(scroll)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	# As tall as its content (wrapped text only knows its height once it
	# has its width, a frame on; and again whenever the content changes).
	_fit_scroll.call_deferred(scroll, content)
	content.minimum_size_changed.connect(_fit_scroll.bind(scroll, content))
	content.resized.connect(_fit_scroll.bind(scroll, content))

	# Pop in.
	dim.modulate.a = 0.0
	window.modulate.a = 0.0
	window.scale = Vector2(0.9, 0.9)
	window.resized.connect(func() -> void: window.pivot_offset = window.size / 2.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(dim, "modulate:a", 1.0, 0.15)
	tween.tween_property(window, "modulate:a", 1.0, 0.12)
	tween.tween_property(window, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Grow the scroll area to fit the content, up to 78% of the screen height.
func _fit_scroll(scroll: ScrollContainer, content: Control) -> void:
	if not is_instance_valid(scroll) or not is_instance_valid(content) or not is_inside_tree():
		return
	var limit := get_viewport_rect().size.y * 0.78 - 140.0
	var tall := minf(content.get_combined_minimum_size().y, limit)
	if not is_equal_approx(scroll.custom_minimum_size.y, tall):
		scroll.custom_minimum_size.y = tall
