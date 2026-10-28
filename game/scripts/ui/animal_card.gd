class_name AnimalCard
extends PanelContainer
## One collectible card: energy cost, placeholder art, name, level and a bar
## showing copies toward the next upgrade. Tap it to call `on_tap`.

const SIZE_NORMAL := Vector2(158, 214)
const SIZE_SMALL := Vector2(120, 160)

var animal_id := ""
var small := false
var highlighted := false:
	set(value):
		highlighted = value
		_restyle()

var _art: ArtPlaceholder
var _name_label: Label
var _level_label: Label
var _bar_holder: Control
var _cost: ArtPlaceholder
var _badge: Label


static func create(id: String, small_card := false) -> AnimalCard:
	var card := AnimalCard.new()
	card.animal_id = id
	card.small = small_card
	card._build()
	card.refresh()
	return card


func _build() -> void:
	custom_minimum_size = SIZE_SMALL if small else SIZE_NORMAL
	var animal := GameData.get_animal(animal_id)

	var column := UIKit.vbox(2 if small else 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	_art = ArtPlaceholder.new()
	_art.shape = ArtPlaceholder.Shape.ROUNDED
	_art.text = UIKit.initials(animal.get("name", "?"))
	_art.color = UIKit.habitat_color(animal)
	_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_art)

	_name_label = UIKit.label(animal.get("name", "?"), 15 if small else 18, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.add_theme_constant_override("outline_size", 4)
	column.add_child(_name_label)

	_level_label = UIKit.label("", 14 if small else 17, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_level_label.add_theme_constant_override("outline_size", 4)
	column.add_child(_level_label)

	_bar_holder = Control.new()
	_bar_holder.custom_minimum_size = Vector2(0, 18 if small else 22)
	_bar_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_bar_holder)

	# Energy cost bubble in the top-left corner, drawn over the art.
	_cost = ArtPlaceholder.new()
	_cost.color = UIKit.ENERGY
	_cost.text = str(int(animal.get("cost", 0)))
	var bubble := 34 if small else 42
	_cost.custom_minimum_size = Vector2(bubble, bubble)
	_cost.size = Vector2(bubble, bubble)
	_cost.position = Vector2(-6, -6)
	_art.add_child(_cost)

	_badge = UIKit.label("NEW", 15, UIKit.YELLOW)
	_badge.position = Vector2(4, 4)
	_badge.visible = false
	_art.add_child(_badge)
	_art.resized.connect(func() -> void: _badge.position = Vector2(_art.size.x - 44, 0))


## Re-reads the profile and updates the card. Call after the profile changes.
func refresh() -> void:
	var animal := GameData.get_animal(animal_id)
	var owned := Profile.has_card(animal_id)
	var reachable := int(animal.unlock_arena_index) <= Profile.highest_arena()

	_art.dimmed = not owned
	_cost.visible = owned or reachable
	_badge.visible = Profile.is_card_new(animal_id)
	for child in _bar_holder.get_children():
		child.queue_free()

	if owned:
		_level_label.text = "Level %d" % Profile.card_level(animal_id)
		var cost := Profile.upgrade_cost(animal_id)
		var bar: ProgressBar
		if cost.is_empty():
			bar = UIKit.progress(1.0, "MAX", UIKit.YELLOW.darkened(0.2), int(_bar_holder.custom_minimum_size.y))
		else:
			var copies := Profile.card_copies(animal_id)
			var enough := Profile.has_copies_for_upgrade(animal_id)
			bar = UIKit.progress(float(copies) / float(cost.copies), "%d/%d" % [copies, cost.copies],
					UIKit.GREEN if enough else UIKit.BLUE, int(_bar_holder.custom_minimum_size.y))
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_bar_holder.add_child(bar)
	elif reachable:
		_level_label.text = "Not found yet"
	else:
		_level_label.text = "Arena %d" % (int(animal.unlock_arena_index) + 1)
	_restyle()


func _restyle() -> void:
	var animal := GameData.get_animal(animal_id)
	var owned := Profile.has_card(animal_id)
	var frame := UIKit.box(UIKit.PANEL_DARK if owned else Color(0.08, 0.12, 0.2), 14, 6 if small else 8)
	frame.set_border_width_all(5 if highlighted else 3)
	frame.border_color = UIKit.YELLOW if highlighted else GameData.rarity_color(animal.get("rarity", "common")).darkened(0.0 if owned else 0.5)
	add_theme_stylebox_override("panel", frame)
