extends Control
## Animals tab: your 8-card battle deck on top, then every animal you've
## found, the ones you haven't, and the ones that unlock in higher arenas.

var _content: VBoxContainer
## Animal waiting to be swapped into the deck ("" when not swapping).
var _swap_id := ""


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
	visibility_changed.connect(func() -> void:
		if not visible:
			_swap_id = ""
	)
	_rebuild()


func _rebuild_later() -> void:
	_rebuild.call_deferred()


func _rebuild() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

	var deck := Profile.get_deck()

	# Deck
	var deck_panel := UIKit.panel(UIKit.PANEL_DARK, 14)
	_content.add_child(deck_panel)
	var deck_box := UIKit.vbox(10)
	deck_panel.add_child(deck_box)
	var title_row := UIKit.hbox(8)
	deck_box.add_child(title_row)
	var title := UIKit.label("Battle Deck", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	title_row.add_child(UIKit.label("Average cost: %.1f" % Profile.average_deck_cost(), 22, UIKit.ENERGY.lightened(0.3)))

	if _swap_id != "":
		var swap_row := UIKit.hbox(10)
		deck_box.add_child(swap_row)
		var hint := UIKit.paragraph("Tap a card in your deck to swap in the %s." % GameData.get_animal(_swap_id).name, 22, UIKit.YELLOW)
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		swap_row.add_child(hint)
		var cancel := UIKit.button("Cancel", UIKit.GREY, 22, Vector2(130, 60))
		cancel.pressed.connect(func() -> void:
			_swap_id = ""
			_rebuild()
		)
		swap_row.add_child(cancel)

	var deck_grid := _grid()
	deck_box.add_child(deck_grid)
	for slot in deck.size():
		var card := AnimalCard.create(deck[slot])
		card.highlighted = _swap_id != ""
		UIKit.on_tap(card, func() -> void: _on_deck_card_tapped(slot))
		deck_grid.add_child(card)

	# Collection
	var found := []
	var not_found := []
	var locked := []
	for id in _sorted_animals():
		if deck.has(id):
			continue
		if Profile.has_card(id):
			found.append(id)
		elif int(GameData.animals[id].unlock_arena_index) <= Profile.highest_arena():
			not_found.append(id)
		else:
			locked.append(id)

	_content.add_child(UIKit.heading("Collection  %d/%d" % [Profile.found_count(), GameData.animal_order.size()]))
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
	var ids := GameData.animal_order.duplicate()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var animal_a: Dictionary = GameData.animals[a]
		var animal_b: Dictionary = GameData.animals[b]
		var rank_a := GameData.rarity_order.find(animal_a.rarity)
		var rank_b := GameData.rarity_order.find(animal_b.rarity)
		if rank_a != rank_b:
			return rank_a > rank_b
		if animal_a.cost != animal_b.cost:
			return animal_a.cost < animal_b.cost
		return String(animal_a.name) < String(animal_b.name)
	)
	return ids


func _on_deck_card_tapped(slot: int) -> void:
	if _swap_id != "":
		Profile.set_deck_slot(slot, _swap_id)
		_swap_id = ""
		_rebuild()
	else:
		_show_detail(Profile.get_deck()[slot], false)


func _show_detail(id: String, allow_use := true) -> void:
	var detail := AnimalDetail.create(id, allow_use)
	var modal := Modal.open(detail, "")
	detail.use_pressed.connect(func(animal_id: String) -> void:
		modal.close()
		_swap_id = animal_id
		_rebuild()
	)
