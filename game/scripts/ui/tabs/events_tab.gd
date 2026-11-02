extends Control
## Events tab: a preview of the challenges, tournaments and seasons to come.

const EVENTS := [
	["calendar", "Daily Draft Challenge", "A fresh Draft Duel twist every day, with a cage for three wins."],
	["podium", "Weekend Tournament", "Climb a bracket against rangers from around the world."],
	["present", "Seasonal rewards", "Earn crowns all season to unlock exclusive banners and emotes."],
]


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	scroll.add_child(margin)
	var column := UIKit.vbox(16)
	margin.add_child(column)

	column.add_child(ComingSoon.hero("tab_events", UIKit.TROPHY.darkened(0.15), "Events",
			"Special challenges, weekend tournaments and ranked seasons will show up here."))
	column.add_child(UIKit.heading("On the way"))
	for event in EVENTS:
		column.add_child(ComingSoon.feature(event[0], event[1], event[2]))
