extends Control
## Events tab: a placeholder for challenges, tournaments and seasons.


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := UIKit.vbox(18)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(column)
	column.add_child(UIKit.label("Events", 44, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var text := UIKit.paragraph("Special challenges, weekend tournaments and ranked seasons will show up here.", 24, UIKit.TEXT_DIM)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(text)
	column.add_child(UIKit.label("Coming soon", 30, UIKit.YELLOW, HORIZONTAL_ALIGNMENT_CENTER))
