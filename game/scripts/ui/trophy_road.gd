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
		var row := UIKit.panel(color.darkened(0.4), 12, 20)
		if i == current:
			var style := UIKit.raised(color.darkened(0.35), 20, 12)
			style.set_border_width_all(5)
			style.border_color = UIKit.YELLOW
			row.add_theme_stylebox_override("panel", style)
		add_child(row)
		var line := UIKit.hbox(14)
		row.add_child(line)
		line.add_child(_thumbnail(arena, reached))
		var column := UIKit.vbox(6)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(column)
		var top := UIKit.hbox(8)
		column.add_child(top)
		var title := UIKit.label("%d. %s" % [i + 1, arena.name], 26)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.clip_text = true
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		top.add_child(title)
		top.add_child(UIKit.pill(GameData.ui_icon("trophy"), UIKit.TROPHY, UIKit.format_number(int(arena.min_trophies))))
		if i == current:
			column.add_child(UIKit.label("You are here: %s trophies" % UIKit.format_number(trophies), 20, UIKit.YELLOW))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 6)
		column.add_child(flow)
		for id in GameData.cards_in_arena(i):
			var animal := GameData.get_card(id)
			var chip := UIKit.panel(Color(UIKit.INK, 0.45), 6, 12)
			chip.add_child(UIKit.label(animal.name, 18, GameData.rarity_color(animal.rarity)))
			flow.add_child(chip)


## A little window onto the arena; dark with a lock until you reach it.
func _thumbnail(arena: Dictionary, reached: bool) -> Control:
	var window := PanelContainer.new()
	window.add_theme_stylebox_override("panel", UIKit.box(Color(arena.color).darkened(0.5), 14, 0))
	window.custom_minimum_size = Vector2(150, 104)
	window.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	window.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if BattleField.arena_art(arena.id).is_empty():
		var art := ArenaArt.new()
		art.arena_id = arena.id
		window.add_child(art)
	else:
		var preview := ArenaPreview.new()
		preview.arena_id = arena.id
		window.add_child(preview)
	if not reached:
		window.modulate = Color(0.35, 0.37, 0.45)
		var lock := UIKit.icon_rect(GameData.ui_icon("locked"), Color.WHITE, 44)
		lock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		window.add_child(lock)
	return window
