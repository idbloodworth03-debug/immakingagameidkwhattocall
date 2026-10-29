class_name AnimalDetail
extends VBoxContainer
## Everything about one card: stats at its current level, ability, release
## requirements and (for animals) conservation status, plus Upgrade and Use
## buttons. Works for Ranger tools too. Shown inside a Modal.

signal use_pressed(animal_id: String)

const TARGET_NAMES := {"ground": "Ground", "air_ground": "Air & Ground", "buildings": "Dens only"}
const SPEED_NAMES := {"slow": "Slow", "medium": "Medium", "fast": "Fast", "very_fast": "Very fast"}

var animal_id := ""
var show_use_button := true


static func create(id: String, allow_use := true) -> AnimalDetail:
	var detail := AnimalDetail.new()
	detail.animal_id = id
	detail.show_use_button = allow_use
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

	# Header: art, name, rarity, conservation status
	var header := UIKit.hbox(16)
	add_child(header)
	var art := UIKit.card_art(animal_id)
	art.dimmed = not owned
	art.custom_minimum_size = Vector2(150, 170)
	header.add_child(art)
	var info := UIKit.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(info)
	var title := UIKit.label(animal.name, 34)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(title)
	info.add_child(UIKit.label(GameData.rarity_name(rarity), 26, GameData.rarity_color(rarity)))
	var is_tool: bool = animal.kind == "tool"
	if is_tool:
		info.add_child(UIKit.paragraph("Ranger tool", 20))
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

	# Stats
	var stats_panel := UIKit.panel(UIKit.PANEL_DARK, 14)
	add_child(stats_panel)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	stats_panel.add_child(grid)
	var growth := float(GameData.progression.stat_growth_per_level)
	var start := GameData.start_level(rarity)
	var stats: Dictionary = animal.stats
	_add_stat(grid, "Energy cost", str(int(animal.cost)))
	if is_tool:
		_add_stat(grid, "Area", "%s tiles" % str(stats.get("radius", 0)))
		for key in ["damage", "heal", "hp"]:
			if stats.has(key):
				var label: String = {"damage": "Damage", "heal": "Healing", "hp": "Bait hitpoints"}[key]
				_add_stat(grid, label, UIKit.format_number(CardRules.stat_at_level(stats[key], level, start, growth)))
		if int(stats.get("tower_damage_pct", 0)) > 0:
			_add_stat(grid, "Den damage", "%d%%" % int(stats.tower_damage_pct))
		if stats.has("duration"):
			_add_stat(grid, "Lasts", "%ss" % str(stats.duration))
	else:
		_add_stat(grid, "Hitpoints", UIKit.format_number(CardRules.stat_at_level(stats.hp, level, start, growth)))
		_add_stat(grid, "Damage", UIKit.format_number(CardRules.stat_at_level(stats.damage, level, start, growth)))
		_add_stat(grid, "Hit speed", "%.1fs" % float(stats.hit_speed))
		_add_stat(grid, "Speed", SPEED_NAMES.get(stats.speed, stats.speed))
		_add_stat(grid, "Range", "Melee" if float(stats.range) <= 1.0 else "%s tiles" % str(stats.range))
		_add_stat(grid, "Targets", TARGET_NAMES.get(stats.targets, stats.targets))
		if int(animal.count) > 1:
			_add_stat(grid, "Count", "x%d" % int(animal.count))

	# Ability
	var ability_panel := UIKit.panel(UIKit.PANEL_DARK, 14)
	add_child(ability_panel)
	var ability_box := UIKit.vbox(4)
	ability_panel.add_child(ability_box)
	ability_box.add_child(UIKit.label(("Effect: " if is_tool else "Ability: ") + String(animal.ability.name), 24, UIKit.YELLOW))
	ability_box.add_child(UIKit.paragraph(animal.ability.text, 21, UIKit.TEXT))

	# Release requirements
	var req_panel := UIKit.panel(UIKit.PANEL_DARK, 14)
	add_child(req_panel)
	var req_box := UIKit.vbox(4)
	req_panel.add_child(req_box)
	req_box.add_child(UIKit.label("How to play it" if is_tool else "Release requirements", 24, UIKit.YELLOW))
	var lines := ["Costs %d energy" % int(animal.cost)]
	for req in animal.prerequisites:
		lines.append(PlacementRules.describe(req))
	var zones := PlacementRules.allowed_zones(animal)
	if zones.size() == 3:
		lines.append("Use it anywhere on the field")
	elif zones == ["own_side", "river"]:
		lines.append("Can also be released in the river")
	for line in lines:
		req_box.add_child(UIKit.paragraph("-  " + line, 21, UIKit.TEXT))

	# Tags
	if not is_tool:
		var tag_names := []
		for tag in animal.tags:
			tag_names.append(GameData.tag_name(tag))
		add_child(UIKit.paragraph("Traits: " + ", ".join(tag_names), 19))

	# Buttons
	if owned:
		var row := UIKit.hbox(14)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(row)
		if show_use_button and not Profile.get_deck().has(animal_id):
			var use := UIKit.button("Use in deck", UIKit.BLUE, 26, Vector2(230, 84))
			use.pressed.connect(func() -> void: use_pressed.emit(animal_id))
			row.add_child(use)
		var cost := Profile.upgrade_cost(animal_id)
		if cost.is_empty():
			row.add_child(UIKit.label("Max level!", 28, UIKit.YELLOW))
		else:
			var upgrade := UIKit.button("Upgrade\n%s gold" % UIKit.format_number(cost.gold), UIKit.GREEN, 24, Vector2(230, 84))
			upgrade.disabled = not Profile.can_upgrade(animal_id)
			upgrade.pressed.connect(_on_upgrade)
			row.add_child(upgrade)


func _add_stat(grid: GridContainer, stat_name: String, value: String) -> void:
	grid.add_child(UIKit.label(stat_name, 21, UIKit.TEXT_DIM))
	grid.add_child(UIKit.label(value, 23))


func _on_upgrade() -> void:
	if Profile.upgrade_card(animal_id):
		Sound.play("upgrade")
		UIKit.toast("%s is now Level %d!" % [GameData.get_card(animal_id).name, Profile.card_level(animal_id)], UIKit.GREEN.darkened(0.3))
		_build()
	else:
		UIKit.error_toast("Not enough gold or copies yet")
