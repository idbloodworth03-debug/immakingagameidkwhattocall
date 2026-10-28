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
	var cancel := UIKit.button("Cancel", UIKit.GREY, 26, Vector2(200, 76))
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

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UIKit.on_tap(dim, close)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var window := UIKit.panel(UIKit.PANEL, 20, 24)
	var border := UIKit.box(UIKit.PANEL, 24, 20)
	border.set_border_width_all(4)
	border.border_color = UIKit.PANEL_LIGHT
	window.add_theme_stylebox_override("panel", border)
	window.custom_minimum_size = Vector2(width, 0)
	center.add_child(window)

	body = UIKit.vbox(16)
	window.add_child(body)

	var header := UIKit.hbox(8)
	body.add_child(header)
	var title_label := UIKit.label(title, 32)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var close_button := UIKit.button("X", UIKit.RED, 26, Vector2(64, 60))
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(width - 40, 0)
	body.add_child(scroll)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_fit_scroll.call_deferred(scroll, content)


## Grow the scroll area to fit the content, up to 78% of the screen height.
func _fit_scroll(scroll: ScrollContainer, content: Control) -> void:
	var limit := get_viewport_rect().size.y * 0.78 - 140.0
	scroll.custom_minimum_size.y = minf(content.get_combined_minimum_size().y, limit)
