class_name SortBar
extends HBoxContainer
## A row of four chunky buttons (Level, Rarity, Class, Biome) above a list
## of animals (AnimalSort, data/sorting.json). The chosen one is lit, with
## an arrow for its order; tapping it again flips the order. Each screen
## remembers its own choice. `compact` is the slimmer bar inside a match.

signal sort_changed(key: String, desc: bool)

var screen := ""
var key := "rarity"
var desc := true
var compact := false
var _buttons := {}


static func make(screen_id: String, compact_bar := false) -> SortBar:
	var bar := SortBar.new()
	bar.screen = screen_id
	bar.compact = compact_bar
	bar.name = "SortBar"
	var now := AnimalSort.choice(screen_id)
	bar.key = String(now.key)
	bar.desc = bool(now.desc)
	bar._build()
	return bar


func _look() -> Dictionary:
	return GameData.sorting.get("compact" if compact else "bar", {})


func _build() -> void:
	var look := _look()
	# The game's chunky buttons wherever it sits (the home screen's tabs
	# use an older theme).
	theme = UIStyle.theme()
	add_theme_constant_override("separation", int(look.get("gap", 8)))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for o: Dictionary in AnimalSort.options():
		var id := String(o.id)
		var b := UIStyle.button(String(o.label), "secondary", "", -1, String(look.get("text", "body")))
		b.fixed_height = float(look.get("height", 72))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.name = "Sort_" + id
		var arrow := _Arrow.new()
		var side := float(look.get("arrow", 20))
		arrow.custom_minimum_size = Vector2(side, side)
		arrow.name = "Arrow"
		b.content.add_child(arrow)
		b.pressed.connect(func() -> void: choose(id))
		add_child(b)
		_buttons[id] = b
	_show()


## Picks `id` (the one already chosen: flips its order) and tells the
## screen to re-sort.
func choose(id: String) -> void:
	if id == key:
		desc = not desc
	else:
		key = id
		desc = AnimalSort.starts_desc(id)
	AnimalSort.remember(screen, key, desc)
	_show()
	sort_changed.emit(key, desc)


func _show() -> void:
	for id: String in _buttons:
		var b: ChunkyButton = _buttons[id]
		var on := id == key
		b.kind = "primary" if on else "secondary"
		var arrow: _Arrow = b.content.get_node("Arrow")
		arrow.visible = on
		arrow.down = desc
		arrow.queue_redraw()


## A little outlined triangle: down for highest first, up the other way.
class _Arrow:
	extends Control
	var down := true

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var pts := PackedVector2Array([Vector2(2, h * 0.2), Vector2(w - 2, h * 0.2), Vector2(w / 2.0, h * 0.85)]) if down \
			else PackedVector2Array([Vector2(2, h * 0.8), Vector2(w - 2, h * 0.8), Vector2(w / 2.0, h * 0.15)])
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_colored_polygon(pts, Color.WHITE)
		draw_polyline(outline, UIStyle.color("outline"), 3.0, true)
