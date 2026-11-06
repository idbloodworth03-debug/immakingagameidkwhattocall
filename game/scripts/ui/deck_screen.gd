extends Control
## Before every Draft Duel match: your deck, the 8 animals your picks come
## from (your tools come along). Eight big slots at the top, filled with
## your last deck, so START is one tap if nothing changes; tap an animal
## from your collection below to add it, a card in the deck to take it out.
## After a ban phase (MatchPlan.banned), a slot that held a banned animal
## shows empty for you to fill, and banned animals are crossed out below.
## START saves the deck and begins the match once all 8 slots are full.
## The collection sorts by Level, Rarity, Class or Biome (SortBar), in
## groups with a header each; the deck's own slots keep their order.

const MENU_SCENE := "res://scenes/main.tscn"
const MATCH_SCENE := "res://scenes/draft.tscn"

## The deck's slots in order ("" for an empty one).
var _deck: Array = []
var _size := 8
## Animals nobody can use this match (the ban phase).
var _banned: Array = []
var _slots: GridContainer
## The collection: a header and a grid for each group of the sort.
var _collection: VBoxContainer
var _sort: SortBar
var _count: Label
var _done: Button


func _ready() -> void:
	theme = UIStyle.theme()
	add_child(UIStyle.backdrop())
	_size = int(GameData.draft_rules.get("deck_size", 8))
	_banned = MatchPlan.banned.duplicate()
	var saved: Array = Profile.get_deck()
	for i in _size:
		var id: String = saved[i] if i < saved.size() else ""
		_deck.append("" if _banned.has(id) else id)
	var safe := UIStyle.safe_margins(get_viewport())
	var column := UIKit.vbox(12)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 16
	column.offset_right = -16
	column.offset_top = 12 + float(safe.top)
	column.offset_bottom = -12 - float(safe.bottom)
	add_child(column)

	var top := UIKit.hbox(12)
	var back := UIStyle.button("Back", "secondary", "", -1, "small")
	back.pressed.connect(func() -> void:
		MatchPlan.clear()
		Transition.go(MENU_SCENE))
	top.add_child(back)
	var title := UIStyle.label("YOUR DECK", "title", Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_count = UIStyle.label("", "large", UIStyle.color("gold"), HORIZONTAL_ALIGNMENT_RIGHT)
	_count.custom_minimum_size = Vector2(90, 0)
	top.add_child(_count)
	column.add_child(top)

	# The deck sits on a darker tray, apart from the collection below.
	var tray := UIKit.panel(UIStyle.color("deck_tray"), 10, 22)
	tray.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_slots = _grid()
	tray.add_child(_slots)
	column.add_child(tray)

	# Sort the collection: Level, Rarity, Class, Biome.
	_sort = SortBar.make("deck")
	_sort.sort_changed.connect(func(_key: String, _desc: bool) -> void: _refresh())
	column.add_child(_sort)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_collection = UIStyle.vbox("s")
	_collection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_collection)

	_done = UIKit.button("START", UIKit.YELLOW, 44, Vector2(400, 104))
	_done.icon = UIKit.icon(GameData.ui_icon("tab_battle"))
	_done.add_theme_constant_override("icon_max_width", 52)
	_done.add_theme_constant_override("h_separation", 12)
	_done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_done.pressed.connect(_save)
	column.add_child(_done)
	_refresh()


func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	return grid


## Every animal you own, in groups by the chosen sort (AnimalSort).
func _owned_groups() -> Array:
	var ids: Array = GameData.card_order.filter(func(id): return Profile.has_card(id) and not GameData.is_tool(id))
	return AnimalSort.grouped(ids, _sort.key, _sort.desc, Profile.card_levels())


## The collection's animals in the order shown.
func shown_order() -> Array:
	var out := []
	for group in _owned_groups():
		out.append_array(group.ids)
	return out


func _refresh() -> void:
	for box in [_slots, _collection]:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
	for i in _size:
		if _deck[i] != "":
			var id: String = _deck[i]
			var card := AnimalCard.create(id)
			card.info = AnimalCard.Info.LEVEL
			UIKit.on_tap(card, func() -> void: _toggle(id))
			_slots.add_child(card)
		else:
			_slots.add_child(_EmptySlot.new())
	for group in _owned_groups():
		_collection.add_child(AnimalSort.header(group))
		var center := CenterContainer.new()
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var grid := _grid()
		# Always a full row wide, so a short group lines up on the left.
		grid.custom_minimum_size.x = grid.columns * AnimalCard.SIZE_NORMAL.x + (grid.columns - 1) * 12
		center.add_child(grid)
		_collection.add_child(center)
		for id: String in group.ids:
			var card := AnimalCard.create(id)
			card.info = AnimalCard.Info.LEVEL
			if _deck.has(id):
				# In your deck: fully bright, with a checkmark.
				card.checked = true
			elif _banned.has(id):
				# Banned: in full color under the red X.
				var x := BanX.new()
				x.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				card.add_child(x)
			UIKit.on_tap(card, func() -> void: _toggle(id))
			grid.add_child(card)
	_count.text = "%d/%d" % [_filled(), _size]
	_done.disabled = _filled() < _size


func _filled() -> int:
	return _deck.filter(func(id): return id != "").size()


## Adds an animal to the deck (in the first empty slot), or takes it out if
## it's in. A banned one can't go in.
func _toggle(id: String) -> void:
	if _deck.has(id):
		_deck[_deck.find(id)] = ""
		Sound.play("tap", -4.0)
	elif _banned.has(id):
		Sound.play("error", -4.0)
		return
	elif _deck.has(""):
		_deck[_deck.find("")] = id
		Sound.play("pop", -4.0)
	else:
		# Full: a little shake of the deck says so.
		Sound.play("error", -4.0)
		var tween := _slots.create_tween()
		var x := _slots.position.x
		for i in 3:
			tween.tween_property(_slots, "position:x", x + 10.0, 0.04)
			tween.tween_property(_slots, "position:x", x - 10.0, 0.04)
		tween.tween_property(_slots, "position:x", x, 0.04)
		return
	_refresh()


func _save() -> void:
	if _filled() < _size:
		return
	Profile.set_deck(_deck)
	Sound.play("upgrade", -4.0)
	Transition.go(MATCH_SCENE)


## An empty deck slot: a dashed card outline with a plus.
class _EmptySlot:
	extends Control

	func _init() -> void:
		custom_minimum_size = AnimalCard.SIZE_NORMAL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var rect := Rect2(Vector2(4, 4), size - Vector2(8, 8))
		draw_style_box(UIKit.box(UIStyle.color("slot_empty"), 16), rect)
		var points := 28
		for i in points:
			# A dashed rim, one dash in two.
			if i % 2 == 0:
				var a := _rim(rect, float(i) / points)
				var b := _rim(rect, float(i + 1) / points)
				draw_line(a, b, UIStyle.color("slot_dash"), 4.0)
		var c := rect.get_center()
		draw_line(c - Vector2(22, 0), c + Vector2(22, 0), UIStyle.color("slot_plus"), 8.0)
		draw_line(c - Vector2(0, 22), c + Vector2(0, 22), UIStyle.color("slot_plus"), 8.0)

	## A point `u` (0-1) of the way around the rectangle's edge.
	func _rim(rect: Rect2, u: float) -> Vector2:
		var w := rect.size.x
		var h := rect.size.y
		var d := u * 2.0 * (w + h)
		if d < w:
			return rect.position + Vector2(d, 0)
		d -= w
		if d < h:
			return rect.position + Vector2(w, d)
		d -= h
		if d < w:
			return rect.position + Vector2(w - d, h)
		return rect.position + Vector2(0, h - (d - w))
