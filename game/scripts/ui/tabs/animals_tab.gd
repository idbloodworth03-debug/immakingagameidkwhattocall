extends Control
## Animals tab: every animal and tool you've found (your Draft Duel pool),
## the ones you haven't, and the ones that unlock in higher arenas. A sort
## bar (Level, Rarity, Class, Biome) stays at the top; the animals come in
## groups with a header each, the ones you don't own yet locked among them
## (last of all in the Level sort), then your tools.

var _content: VBoxContainer
var _sort: SortBar


func _ready() -> void:
	var layout := UIStyle.vbox("xs")
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
	var bar_margin := MarginContainer.new()
	for side in ["left", "right"]:
		bar_margin.add_theme_constant_override("margin_" + side, 16)
	# Below the version label in the corner.
	bar_margin.add_theme_constant_override("margin_top", int(GameData.sorting.get("tab_top", 40)))
	bar_margin.add_theme_constant_override("margin_bottom", 0)
	_sort = SortBar.make("animals")
	_sort.sort_changed.connect(func(_key: String, _desc: bool) -> void: _rebuild())
	bar_margin.add_child(_sort)
	layout.add_child(bar_margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
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

	_content.add_child(UIKit.heading("Collection  %d/%d" % [Profile.found_count(), GameData.card_order.size()]))
	for group in groups():
		_content.add_child(AnimalSort.header(group))
		_add_card_grid(group.ids, not AnimalSort.names_class(_sort.key))


## Every animal and tool in groups by the chosen sort (AnimalSort): the
## ones you don't own sort the same way (and show locked).
func groups() -> Array:
	return AnimalSort.grouped(GameData.card_order, _sort.key, _sort.desc, Profile.card_levels())


## The animals' and tools' ids in the order shown.
func shown_order() -> Array:
	var out := []
	for group in groups():
		out.append_array(group.ids)
	return out


func _add_card_grid(ids: Array, show_class := true) -> void:
	var grid := _grid()
	_content.add_child(grid)
	for id in ids:
		var card := AnimalCard.create(id)
		card.show_class = show_class
		UIKit.on_tap(card, func() -> void: _show_detail(id))
		grid.add_child(card)


func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	return grid


## An animal opens the 3D viewer; a Ranger tool, its details.
func _show_detail(id: String) -> void:
	if GameData.is_tool(id):
		Modal.open(AnimalDetail.create(id), "")
	else:
		AnimalViewer.open(id)
