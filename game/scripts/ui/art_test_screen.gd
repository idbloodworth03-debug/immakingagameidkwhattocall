class_name ArtTestScreen
extends Control
## For testing art (dev tools on; the website opened with ?arttest=1): each
## art test (data/art_tests.json: an animal from an outside art pack, or
## one of our own in a new style) next to the animal it plays as, as their
## cards, pack by pack. Tap a card for its 3D viewer. Each pack's "Test
## fight" starts a fight of its animals against the game's current ones,
## played by the computer for both sides (main_menu.gd's ?fight= shortcut).

## The fight's seed (the same fight every time).
const FIGHT_SEED := 7


static func open() -> ArtTestScreen:
	var screen := ArtTestScreen.new()
	var tree := Engine.get_main_loop() as SceneTree
	var layer := tree.get_first_node_in_group("popup_layer")
	(layer if layer else tree.current_scene).add_child(screen)
	return screen


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group(HoldInfo.COVER_GROUP)
	var back := ColorRect.new()
	back.color = UIKit.DEEP
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(margin)
	var column := UIKit.vbox(18)
	margin.add_child(column)
	column.add_child(UIKit.heading("Art test"))
	var tests: Dictionary = GameData.art_tests.get("animals", {})
	# Pack by pack, in the order the packs first appear.
	var packs := {}
	for id: String in tests:
		if GameData.cards.has(id):
			(packs.get_or_add(String(tests[id].get("pack", "")), []) as Array).append(id)
	column.add_child(UIKit.paragraph("The game's animal now on the left, the test on the right. Each test plays exactly as the animal beside it. Tap a card for its 3D viewer.", 22))
	for pack: String in packs:
		var ids: Array = packs[pack]
		column.add_child(UIKit.label(pack, 26, UIKit.GREEN))
		for id: String in ids:
			column.add_child(_pair(GameData.plays_as(id), id))
		var fight := UIKit.button("Test fight: these vs now", UIKit.GREEN, 24)
		fight.pressed.connect(_start_fight.bind(ids))
		column.add_child(fight)
	var close := UIKit.button("Close", UIKit.BLUE, 26)
	close.pressed.connect(queue_free)
	column.add_child(close)
	UIKit.fade_in(self, 0.18)


## Ours and the art test side by side, each with its name and where it's from.
func _pair(ours: String, theirs: String) -> Control:
	var row := UIKit.hbox(28)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for id in [ours, theirs]:
		var cell := UIKit.vbox(8)
		var card := AnimalCard.create(id)
		UIKit.on_tap(card, func() -> void: AnimalViewer.open(id))
		cell.add_child(card)
		var line := "Now: %s" if id == ours else "Test: %s"
		cell.add_child(UIKit.label(line % String(GameData.get_card(id).get("name", id)), 20, UIKit.YELLOW if id == ours else UIKit.GREEN, HORIZONTAL_ALIGNMENT_CENTER))
		row.add_child(cell)
	return row


## A pack's animals (team 0, blue) against the ones they play as (team 1,
## red), one squad each, played by the computer.
func _start_fight(theirs: Array) -> void:
	var ours := []
	for id: String in theirs:
		ours.append(GameData.plays_as(id))
	DraftScreen.dev_auto = {"seed": FIGHT_SEED, "mine": "", "theirs": "", "sizes": false, "track": "", "slow": 0.0,
		"herds": ",".join(theirs) + "|" + ",".join(ours)}
	queue_free()
	Transition.go("res://scenes/draft.tscn")
