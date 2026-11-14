extends Control
## Clan tab. Clans need the online server, so for now this previews what's
## planned. See docs/GAME_DESIGN.md for the full clan design.

const FEATURES := [
	["chat", "Clan chat", "Talk with your clanmates using quick chats and emotes."],
	["trade", "Animal requests", "Ask your clan for copies of an animal, and donate to others for gold and Ranger XP."],
	["tab_battle", "Friendly battles", "Challenge clanmates and friends without risking trophies."],
	["wars", "Clan Wars", "Team up against other clans in weekly wars for big cage rewards."],
	["roles", "Clan roles", "Leader, Co-leader, Elder and Member, with up to 50 rangers per clan."],
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

	column.add_child(ComingSoon.hero("tab_clan", UIKit.BLUE, "Clans",
			"Join a clan with your friends to chat, trade animals, battle each other and take on other clans. Clans arrive with online play.", "tab_clan"))
	var row := UIKit.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	for text in ["Search clans", "Create clan"]:
		var b := UIKit.button(text, UIKit.BLUE, 24, Vector2(260, 76))
		b.disabled = true
		row.add_child(b)

	column.add_child(UIKit.heading("Planned features"))
	for feature in FEATURES:
		column.add_child(ComingSoon.feature(feature[0], feature[1], feature[2]))
