extends Control
## Your Draft Duel deck: the 8 animals your picks come from (and your tools
## come along). Eight big slots at the top fill up as you tap animals from
## your collection below; tap a card in the deck to take it out. DONE saves
## it once all 8 are filled. The deck is kept for every match after.

const MENU_SCENE := "res://scenes/main.tscn"

var _deck: Array = []
var _size := 8
var _slots: GridContainer
var _collection: GridContainer
var _count: Label
var _done: Button


func _ready() -> void:
	theme = UIStyle.theme()
	add_child(UIStyle.backdrop())
	_size = int(GameData.draft_rules.get("deck_size", 8))
	_deck = Profile.get_deck()
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
	back.pressed.connect(func() -> void: Transition.go(MENU_SCENE))
	top.add_child(back)
	var title := UIStyle.label("YOUR DECK", "title", Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	_count = UIStyle.label("", "large", UIStyle.color("gold"), HORIZONTAL_ALIGNMENT_RIGHT)
	_count.custom_minimum_size = Vector2(90, 0)
	top.add_child(_count)
	column.add_child(top)

	# The deck sits on a darker tray, apart from the collection below.
	var tray := UIKit.panel(Color(0.18, 0.1, 0.04, 0.45), 10, 22)
	tray.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_slots = _grid()
	tray.add_child(_slots)
	column.add_child(tray)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_collection = _grid()
	center.add_child(_collection)

	_done = UIKit.button("DONE", UIKit.YELLOW, 40, Vector2(360, 96))
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


## Every animal you own, by class (as they'd line up in battle), rarest
## first within a class.
func _owned_animals() -> Array:
	var ids: Array = GameData.card_order.filter(func(id): return Profile.has_card(id) and not GameData.is_tool(id))
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ca := GameData.class_order.find(GameData.class_of(a))
		var cb := GameData.class_order.find(GameData.class_of(b))
		if ca != cb:
			return ca < cb
		var ra := GameData.rarity_order.find(GameData.cards[a].rarity)
		var rb := GameData.rarity_order.find(GameData.cards[b].rarity)
		if ra != rb:
			return ra > rb
		return String(GameData.cards[a].name) < String(GameData.cards[b].name))
	return ids


func _refresh() -> void:
	for grid in [_slots, _collection]:
		for child in grid.get_children():
			grid.remove_child(child)
			child.queue_free()
	for i in _size:
		if i < _deck.size():
			var id: String = _deck[i]
			var card := AnimalCard.create(id)
			card.info = AnimalCard.Info.LEVEL
			UIKit.on_tap(card, func() -> void: _toggle(id))
			_slots.add_child(card)
		else:
			_slots.add_child(_EmptySlot.new())
	for id in _owned_animals():
		var card := AnimalCard.create(id)
		card.info = AnimalCard.Info.LEVEL
		if _deck.has(id):
			card.stamp = "IN DECK"
			card.modulate = Color(1, 1, 1, 0.55)
		UIKit.on_tap(card, func() -> void: _toggle(id))
		_collection.add_child(card)
	_count.text = "%d/%d" % [_deck.size(), _size]
	_done.disabled = _deck.size() < _size


## Adds an animal to the deck, or takes it out if it's in.
func _toggle(id: String) -> void:
	if _deck.has(id):
		_deck.erase(id)
		Sound.play("tap", -4.0)
	elif _deck.size() < _size:
		_deck.append(id)
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
	if _deck.size() < _size:
		return
	Profile.set_deck(_deck)
	Sound.play("upgrade", -4.0)
	Transition.go(MENU_SCENE)


## An empty deck slot: a dashed card outline with a plus.
class _EmptySlot:
	extends Control

	func _init() -> void:
		custom_minimum_size = AnimalCard.SIZE_NORMAL
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var rect := Rect2(Vector2(4, 4), size - Vector2(8, 8))
		draw_style_box(UIKit.box(Color(0, 0, 0, 0.22), 16), rect)
		var points := 28
		for i in points:
			# A dashed rim, one dash in two.
			if i % 2 == 0:
				var a := _rim(rect, float(i) / points)
				var b := _rim(rect, float(i + 1) / points)
				draw_line(a, b, Color(1, 1, 1, 0.55), 4.0)
		var c := rect.get_center()
		draw_line(c - Vector2(22, 0), c + Vector2(22, 0), Color(1, 1, 1, 0.7), 8.0)
		draw_line(c - Vector2(0, 22), c + Vector2(0, 22), Color(1, 1, 1, 0.7), 8.0)

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
