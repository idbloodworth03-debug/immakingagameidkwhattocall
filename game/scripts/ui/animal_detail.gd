class_name AnimalDetail
extends VBoxContainer
## Everything about one card: its class (and a Specialist's trait) in one
## line, stats at its current level, habitat and conservation status, plus
## the Upgrade button. Works for Ranger tools too. Shown inside a Modal.

const TARGET_NAMES := {"ground": "Ground", "air_ground": "Air & Ground"}
const SPEED_NAMES := {"slow": "Slow", "medium": "Medium", "fast": "Fast", "very_fast": "Very fast"}

var animal_id := ""


static func create(id: String) -> AnimalDetail:
	var detail := AnimalDetail.new()
	detail.animal_id = id
	detail.add_theme_constant_override("separation", 14)
	detail._build()
	return detail


func _ready() -> void:
	Profile.mark_card_seen(animal_id)


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var animal := GameData.get_card(animal_id)
	var rarity: String = animal.rarity
	var owned := Profile.has_card(animal_id)
	var level := Profile.card_level(animal_id)

	# Header: the card, name, rarity, conservation status
	var header := UIKit.hbox(18)
	add_child(header)
	var card := AnimalCard.create(animal_id)
	card.full_show = true
	card.info = AnimalCard.Info.NONE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(card)
	var info := UIKit.vbox(6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(info)
	var title := UIKit.label(animal.name, 38)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(title)
	info.add_child(_chip(GameData.rarity_name(rarity), GameData.rarity_color(rarity)))
	var is_tool: bool = animal.kind == "tool"
	if is_tool:
		info.add_child(UIKit.paragraph("Ranger tool", 20))
	elif rarity == "mythic":
		info.add_child(UIKit.paragraph("Mythical creature", 20))
	else:
		info.add_child(UIKit.paragraph("Real-world status: %s" % GameData.status_name(animal.status), 20))
	if owned:
		info.add_child(UIKit.label("Level %d" % level, 24, UIKit.YELLOW))
		var cost := Profile.upgrade_cost(animal_id)
		if not cost.is_empty():
			var copies := Profile.card_copies(animal_id)
			info.add_child(UIKit.progress(float(copies) / float(cost.copies), "%d / %d" % [copies, cost.copies],
					UIKit.GREEN if Profile.has_copies_for_upgrade(animal_id) else UIKit.BLUE))
	else:
		var arena_index := int(animal.unlock_arena_index)
		var where := "Found in cages from Arena %d: %s" % [arena_index + 1, GameData.get_arena(arena_index).name]
		info.add_child(UIKit.paragraph(where, 20, UIKit.YELLOW))

	# Stats, as a grid of tiles
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	add_child(grid)
	var growth := float(GameData.progression.stat_growth_per_level)
	var start := GameData.start_level(rarity)
	var stats: Dictionary = animal.stats
	if is_tool:
		_add_stat(grid, "Area", "%s tiles" % str(stats.get("radius", 0)))
		for key in ["damage", "heal", "hp"]:
			if stats.has(key):
				var label: String = {"damage": "Damage", "heal": "Healing", "hp": "Bait hitpoints"}[key]
				_add_stat(grid, label, UIKit.format_number(CardRules.stat_at_level(stats[key], level, start, growth)))
		if stats.has("duration"):
			_add_stat(grid, "Lasts", "%ss" % str(stats.duration))
	else:
		_add_stat(grid, "Hitpoints", UIKit.format_number(CardRules.stat_at_level(stats.hp, level, start, growth)))
		_add_stat(grid, "Damage", UIKit.format_number(CardRules.stat_at_level(stats.damage, level, start, growth)))
		_add_stat(grid, "Hit speed", "%.1fs" % float(stats.hit_speed))
		_add_stat(grid, "Speed", SPEED_NAMES.get(stats.speed, stats.speed))
		_add_stat(grid, "Range", "Melee" if float(stats.range) <= 1.0 else "%s tiles" % str(stats.range))
		_add_stat(grid, "Targets", TARGET_NAMES.get(stats.targets, stats.targets))
		# How many animals one card brings into a fight (its class's squad).
		_add_stat(grid, "Group", "x%d" % DraftMatch.squad_units(String(animal.id)))

	# What it does, in a line: its class (and trait), or the tool's effect.
	var what := UIKit.well(16)
	add_child(what)
	var what_row := UIKit.hbox(12)
	what.add_child(what_row)
	if is_tool:
		what_row.add_child(UIKit.paragraph(GameData.card_line(animal_id), 21, UIKit.TEXT))
	else:
		var cls := GameData.class_info(GameData.class_of(animal_id))
		what_row.add_child(UIKit.icon_rect(GameData.ui_icon(String(cls.icon)), Color(String(cls.color)), 44))
		var words := UIKit.vbox(2)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var trait_id := GameData.trait_of(animal_id)
		var title_text := String(cls.name) + (" · " + String(GameData.traits[trait_id].name) if trait_id != "" else "")
		words.add_child(UIKit.label(title_text, 26, Color(String(cls.color)).lightened(0.35)))
		words.add_child(UIKit.paragraph(GameData.card_line(animal_id), 20, UIKit.TEXT))
		what_row.add_child(words)
		var habitat: Dictionary = GameData.habitats.get(String(animal.get("habitat", "")), {})
		if not habitat.is_empty():
			# Its biome (the card's front leaves it out).
			info.add_child(_chip(String(habitat.name), Color(String(habitat.color)), 20, String(habitat.get("icon", ""))))

	# Ranger Journal: the real animal or history behind a Mythic's legend,
	# with a link to that animal's card when it's in the game.
	if String(animal.get("legend", "")) != "":
		var journal := UIKit.well(16)
		add_child(journal)
		var column := UIKit.vbox(8)
		journal.add_child(column)
		var heading := UIKit.hbox(10)
		heading.add_child(UIKit.icon_rect(GameData.ui_icon("journal"), UIKit.YELLOW, 34))
		heading.add_child(UIKit.label("Ranger Journal", 24, UIKit.YELLOW))
		column.add_child(heading)
		column.add_child(UIKit.paragraph(String(animal.legend), 20, UIKit.TEXT))
		var link := String(animal.get("legend_card", ""))
		if link != "" and GameData.cards.has(link):
			var meet := UIKit.button(GameData.get_card(link).name, UIKit.BLUE, 22, Vector2(0, 64))
			meet.icon = UIKit.icon(GameData.card_icon(link))
			meet.add_theme_constant_override("icon_max_width", 36)
			meet.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			meet.pressed.connect(func() -> void: Modal.open(AnimalDetail.create(link), GameData.get_card(link).name))
			column.add_child(meet)

	# Buttons
	if owned:
		var row := UIKit.hbox(14)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(row)
		var cost := Profile.upgrade_cost(animal_id)
		if cost.is_empty():
			row.add_child(UIKit.label("Max level!", 28, UIKit.YELLOW))
		else:
			var upgrade := UIKit.button("Upgrade\n%s gold" % UIKit.format_number(cost.gold), UIKit.GREEN, 24, Vector2(230, 84))
			upgrade.disabled = not Profile.can_upgrade(animal_id)
			upgrade.pressed.connect(_on_upgrade)
			row.add_child(upgrade)


## One stat: a small tile with the name over the value.
func _add_stat(grid: GridContainer, stat_name: String, value: String) -> void:
	var tile := UIKit.well(10, 14)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIKit.vbox(0)
	tile.add_child(column)
	column.add_child(UIKit.label(stat_name, 20, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UIKit.label(value, 26, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	grid.add_child(tile)


## A small colored pill with a word on it.
func _chip(text: String, color: Color, font_size := 20, icon_key := "") -> Control:
	var chip := PanelContainer.new()
	var style := UIKit.box(color.darkened(0.25), 14, 4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.set_border_width_all(2)
	style.border_color = color.lightened(0.2)
	chip.add_theme_stylebox_override("panel", style)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if icon_key == "":
		chip.add_child(UIKit.label(text, font_size))
		return chip
	var row := UIKit.hbox(6)
	row.add_child(UIKit.icon_rect(GameData.ui_icon(icon_key), Color.WHITE, font_size + 6))
	row.add_child(UIKit.label(text, font_size))
	chip.add_child(row)
	return chip


func _on_upgrade() -> void:
	if Profile.upgrade_card(animal_id):
		Sound.play("upgrade")
		UIKit.toast("%s is now Level %d!" % [GameData.get_card(animal_id).name, Profile.card_level(animal_id)], UIKit.GREEN.darkened(0.3))
		_build()
	else:
		UIKit.error_toast("Not enough gold or copies yet")
