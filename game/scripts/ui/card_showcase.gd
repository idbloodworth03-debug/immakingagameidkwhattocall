extends Control
## For testing (Profile > Developer tools > Card show): one card of each
## rarity side by side, as they show off (CardShow): the collection cards
## with the full show and in a grid's lighter version, and the match cards;
## "Mythic moment" plays the flash and burst a Mythic gets when it's offered
## or picked.

const MENU_SCENE := "res://scenes/main.tscn"
const CARDS := ["brown_bear", "lion", "tiger", "black_rhino", "dragon"]

var _mythics: Array = []


func _ready() -> void:
	theme = UIStyle.theme()
	add_child(UIStyle.backdrop())
	var safe := UIStyle.safe_margins(get_viewport())
	var column := UIStyle.vbox("s")
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 16
	column.offset_right = -16
	column.offset_top = 12 + float(safe.top)
	column.offset_bottom = -12 - float(safe.bottom)
	add_child(column)
	var top := UIStyle.hbox("s")
	var back := UIStyle.button("Back", "secondary", "", -1, "small")
	back.pressed.connect(func() -> void: Transition.go(MENU_SCENE))
	top.add_child(back)
	var title := UIStyle.label("CARD SHOW", "title", Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	column.add_child(top)
	var side := AnimalCard.SIZE_NORMAL * 0.82
	for row in [["The full show", true], ["In a big grid (lighter)", false]]:
		column.add_child(AnimalSort.header({"group": row[0], "label": row[0], "icon": "sparkles", "color": UIStyle.color("rarity_mythic"), "ids": CARDS}))
		var line := _row()
		column.add_child(line)
		for id: String in CARDS:
			var card := AnimalCard.create(id)
			card.info = AnimalCard.Info.LEVEL
			card.full_show = row[1]
			card.custom_minimum_size = side
			line.add_child(_with_name(card, id))
			if row[1] and GameData.cards[id].rarity == "mythic":
				_mythics.append(card)
	column.add_child(AnimalSort.header({"group": "match", "label": "In a match", "icon": "tab_battle", "color": UIStyle.color("rarity_mythic"), "ids": CARDS}))
	var match_row := _row()
	column.add_child(match_row)
	for id: String in CARDS:
		var card := GameCard.make(id, Vector2(side.x, side.x * 1.18))
		match_row.add_child(_with_name(card, id))
		if GameData.cards[id].rarity == "mythic":
			_mythics.append(card)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var play := UIStyle.button("Mythic moment", "primary", "sparkles")
	play.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play.name = "MythicMoment"
	play.pressed.connect(func() -> void:
		for card in _mythics:
			CardShow.moment(card, 0.0))
	column.add_child(play)


func _row() -> HBoxContainer:
	var line := UIStyle.hbox("xs")
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	return line


func _with_name(card: Control, id: String) -> Control:
	var box := UIStyle.vbox("xs")
	box.add_child(card)
	box.add_child(UIStyle.label(GameData.rarity_name(String(GameData.cards[id].rarity)), "small", UIStyle.rarity_color(String(GameData.cards[id].rarity)), HORIZONTAL_ALIGNMENT_CENTER))
	return box
