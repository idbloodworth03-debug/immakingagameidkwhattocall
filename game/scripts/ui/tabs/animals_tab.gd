extends Control
## Animals tab: every animal and tool you've found (your Draft Duel pool),
## the ones you haven't, and the ones that unlock in higher arenas.

var _content: VBoxContainer


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)
	_content = UIKit.vbox(16)
	margin.add_child(_content)

	Profile.changed.connect(_rebuild_later)
	_rebuild()


func _rebuild_later() -> void:
	_rebuild.call_deferred()


func _rebuild() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

	# How the collection plays: what you own is what you can draft.
	var intro := UIKit.panel(UIKit.PANEL, 16, 20)
	_content.add_child(intro)
	var intro_row := UIKit.hbox(14)
	intro.add_child(intro_row)
	var watering_hole := UIKit.icon_rect(GameData.ui_icon("paw"), UIKit.GREEN, 64)
	intro_row.add_child(watering_hole)
	var text := UIKit.paragraph("Your deck of 8 animals (change it from the Battle tab) and every tool you've found turn up in your Draft Duel picks, each at its level. Find more in cages, and level them up with copies and gold.", 21, UIKit.TEXT)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intro_row.add_child(text)

	var found := []
	var not_found := []
	var locked := []
	for id in _sorted_animals():
		if Profile.has_card(id):
			found.append(id)
		elif int(GameData.cards[id].unlock_arena_index) <= Profile.highest_arena():
			not_found.append(id)
		else:
			locked.append(id)

	_content.add_child(UIKit.heading("Collection  %d/%d" % [Profile.found_count(), GameData.card_order.size()]))
	_add_card_grid(found)
	if not not_found.is_empty():
		_content.add_child(UIKit.heading("Not found yet"))
		_content.add_child(UIKit.paragraph("These can drop from cages in your arena.", 20))
		_add_card_grid(not_found)
	if not locked.is_empty():
		_content.add_child(UIKit.heading("Unlock in higher arenas"))
		_add_card_grid(locked)


func _add_card_grid(ids: Array) -> void:
	var grid := _grid()
	_content.add_child(grid)
	for id in ids:
		var card := AnimalCard.create(id)
		UIKit.on_tap(card, func() -> void: _show_detail(id))
		grid.add_child(card)


func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	return grid


## Rarest first, then cheapest first - the usual collection order.
func _sorted_animals() -> Array:
	var ids := GameData.card_order.duplicate()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var animal_a: Dictionary = GameData.cards[a]
		var animal_b: Dictionary = GameData.cards[b]
		var rank_a := GameData.rarity_order.find(animal_a.rarity)
		var rank_b := GameData.rarity_order.find(animal_b.rarity)
		if rank_a != rank_b:
			return rank_a > rank_b
		if animal_a.cost != animal_b.cost:
			return animal_a.cost < animal_b.cost
		return String(animal_a.name) < String(animal_b.name)
	)
	return ids


## An animal opens the 3D viewer; a Ranger tool, its details.
func _show_detail(id: String) -> void:
	if GameData.is_tool(id):
		Modal.open(AnimalDetail.create(id), "")
	else:
		AnimalViewer.open(id)
