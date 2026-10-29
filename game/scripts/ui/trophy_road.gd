class_name TrophyRoad
extends VBoxContainer
## All arenas from the top down, with their trophy requirement and the
## animals they unlock. Shown inside a Modal.


static func create() -> TrophyRoad:
	var road := TrophyRoad.new()
	road.add_theme_constant_override("separation", 12)
	road._build()
	return road


func _build() -> void:
	var trophies := Profile.get_trophies()
	var current := Profile.arena_index()
	add_child(UIKit.paragraph("Win battles to earn trophies and climb to new arenas. Each arena unlocks new animals in your cages. Most arenas have a floor: once you reach one you can't drop back below it.", 21))
	for i in range(GameData.arenas.size() - 1, -1, -1):
		var arena: Dictionary = GameData.arenas[i]
		var reached := i <= Profile.highest_arena()
		var color := Color(arena.color) if reached else Color(arena.color).darkened(0.6)
		var row := UIKit.panel(color.darkened(0.35), 14)
		if i == current:
			var style := UIKit.box(color.darkened(0.35), 18, 14)
			style.set_border_width_all(5)
			style.border_color = UIKit.YELLOW
			row.add_theme_stylebox_override("panel", style)
		add_child(row)
		var column := UIKit.vbox(6)
		row.add_child(column)
		var top := UIKit.hbox(8)
		column.add_child(top)
		var title := UIKit.label("Arena %d: %s" % [i + 1, arena.name], 26)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(title)
		top.add_child(UIKit.label("%s+" % UIKit.format_number(int(arena.min_trophies)), 24, UIKit.TROPHY))
		if i == current:
			column.add_child(UIKit.label("You are here: %s trophies" % UIKit.format_number(trophies), 20, UIKit.YELLOW))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 6)
		column.add_child(flow)
		for id in GameData.cards_in_arena(i):
			var animal := GameData.get_card(id)
			var chip := UIKit.panel(Color(0, 0, 0, 0.35), 6, 10)
			chip.add_child(UIKit.label(animal.name, 18, GameData.rarity_color(animal.rarity)))
			flow.add_child(chip)
