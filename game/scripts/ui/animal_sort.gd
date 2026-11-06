class_name AnimalSort
extends RefCounted
## Sorting animals four ways (data/sorting.json), the same on every screen
## that shows them: Your Deck, the bans, the Animals tab, and inside a match
## your starters (round 1) and your army row.
##
##   Level:  highest first (tap again: lowest first). Animals you don't own
##           yet always come last, both ways.
##   Rarity: Mythic first (or Common first).
##   Class:  in classes.json order (Tank first), or the other way round.
##   Biome:  in habitats.json order. Mythics have no real habitat: they get
##           a "Legends" group of their own.
## Ties always fall back to rarest first, then the name, so the order never
## jumps about. Tools (the Animals tab, your army row) come after every
## animal, in a group of their own.
##
## `levels` is the animals you own and their levels (Profile.card_levels()):
## an animal not in it is one you don't own yet.

const KEYS := ["level", "rarity", "class", "biome"]


## The four ways, in sorting.json order: [{id, label, highest_first}].
static func options() -> Array:
	return GameData.sorting.get("options", [])


static func option(key: String) -> Dictionary:
	for o: Dictionary in options():
		if String(o.id) == key:
			return o
	return {}


## The order a sort starts in when first picked: Level and Rarity highest
## first, Class and Biome in data order.
static func starts_desc(key: String) -> bool:
	return bool(option(key).get("highest_first", false))


## How `screen` is sorted now: the player's last choice there, or the
## screen's default (sorting.json "screens").
static func choice(screen: String) -> Dictionary:
	var saved := Profile.sort_choice(screen)
	var key := String(saved.get("key", ""))
	if KEYS.has(key):
		return {"key": key, "desc": bool(saved.get("desc", starts_desc(key)))}
	key = String(GameData.sorting.get("screens", {}).get(screen, "rarity"))
	if not KEYS.has(key):
		key = "rarity"
	return {"key": key, "desc": starts_desc(key)}


static func remember(screen: String, key: String, desc: bool) -> void:
	Profile.set_sort_choice(screen, key, desc)


## `ids` sorted by `key` (see the top), `desc` flipping the main order.
static func sorted(ids: Array, key: String, desc: bool, levels: Dictionary) -> Array:
	var out := ids.duplicate()
	out.sort_custom(func(a: String, b: String) -> bool: return _before(a, b, key, desc, levels))
	return out


## `ids` sorted and cut into groups for headers or dividers, in order:
## [{"group": its key ("forest", "legends", "12", "not_owned", "tools"...),
## "label", "short" (for the small tags in a match), "icon" (art.json "ui"
## key, maybe ""), "color", "ids"}].
static func grouped(ids: Array, key: String, desc: bool, levels: Dictionary) -> Array:
	var out := []
	for id: String in sorted(ids, key, desc, levels):
		var group := group_of(id, key, levels)
		if out.is_empty() or String(out[-1].group) != group:
			var info := group_info(group, key)
			info.ids = []
			out.append(info)
		out[-1].ids.append(id)
	return out


## Which group `id` falls in under `key`.
static func group_of(id: String, key: String, levels: Dictionary) -> String:
	if GameData.is_tool(id):
		return "tools"
	var card := GameData.get_card(id)
	match key:
		"level":
			return str(int(levels[id])) if levels.has(id) else "not_owned"
		"rarity":
			return String(card.get("rarity", "common"))
		"class":
			return GameData.class_of(id)
		"biome":
			if String(card.get("rarity", "")) == "mythic":
				return "legends"
			return String(card.get("habitat", ""))
	return ""


## A group's name, short name, icon and color.
static func group_info(group: String, key: String) -> Dictionary:
	var data := GameData.sorting
	for special in ["tools", "not_owned", "legends"]:
		if group == special:
			var s: Dictionary = data.get(special, {})
			return {"group": group, "label": String(s.get("label", group)), "short": String(s.get("short", s.get("label", group))),
				"icon": String(s.get("icon", "")), "color": Color(String(s.get("color", "#7d8799")))}
	match key:
		"level":
			return {"group": group, "label": String(data.get("level_label", "Level %d")) % int(group),
				"short": String(data.get("level_short", "Lv %d")) % int(group), "icon": "",
				"color": Color(String(data.get("level_color", "#47a9ec")))}
		"rarity":
			var name := GameData.rarity_name(group)
			return {"group": group, "label": name, "short": name, "icon": String(data.get("rarity_icon", "star")),
				"color": UIStyle.rarity_color(group)}
		"class":
			var info := GameData.class_info(group)
			return {"group": group, "label": String(info.get("name", group)), "short": String(info.get("short", info.get("name", group))),
				"icon": String(info.get("icon", "")), "color": Color(String(info.get("color", "#7d8799")))}
		"biome":
			var h: Dictionary = GameData.habitats.get(group, {})
			return {"group": group, "label": String(h.get("name", group)), "short": String(h.get("name", group)),
				"icon": String(h.get("icon", "")), "color": Color(String(h.get("color", "#7d8799")))}
	return {"group": group, "label": group, "short": group, "icon": "", "color": Color("#7d8799")}


## Whether `a` goes before `b`.
static func _before(a: String, b: String, key: String, desc: bool, levels: Dictionary) -> bool:
	var ta := _tier(a, key, levels)
	var tb := _tier(b, key, levels)
	if ta != tb:
		return ta < tb
	var pa := _main(a, key, levels)
	var pb := _main(b, key, levels)
	if pa != pb:
		return pa > pb if desc else pa < pb
	# Ties: rarest first, then by name (never flipped).
	var ra := GameData.rarity_rank(String(GameData.get_card(a).get("rarity", "common")))
	var rb := GameData.rarity_rank(String(GameData.get_card(b).get("rarity", "common")))
	if ra != rb:
		return ra > rb
	var na := String(GameData.get_card(a).get("name", a))
	var nb := String(GameData.get_card(b).get("name", b))
	if na != nb:
		return na < nb
	return a < b


## Which block `id` sorts into before anything else: animals (0), animals
## you don't own yet in the Level sort (1, last both ways), tools (2; ones
## you don't own last in the Level sort, 3).
static func _tier(id: String, key: String, levels: Dictionary) -> int:
	if GameData.is_tool(id):
		return 3 if key == "level" and not levels.has(id) else 2
	if key == "level" and not levels.has(id):
		return 1
	return 0


## The number `key` sorts `id` by.
static func _main(id: String, key: String, levels: Dictionary) -> int:
	var card := GameData.get_card(id)
	match key:
		"level":
			return int(levels.get(id, 0))
		"rarity":
			return GameData.rarity_rank(String(card.get("rarity", "common")))
		"class":
			return 0 if GameData.is_tool(id) else GameData.class_order.find(GameData.class_of(id))
		"biome":
			if GameData.is_tool(id):
				return 0
			if String(card.get("rarity", "")) == "mythic":
				return GameData.habitat_order.size()
			return GameData.habitat_order.find(String(card.get("habitat", "")))
	return 0


# --- Showing the groups ----------------------------------------------------------

## A section header for the big grids: the group's icon and name on a chip
## in its color, how many it holds, and a line to the edge.
static func header(group: Dictionary) -> Control:
	var h: Dictionary = GameData.sorting.get("header", {})
	var row := UIStyle.hbox("s")
	var inner := UIStyle.hbox("xs")
	var icon := String(group.get("icon", ""))
	if icon != "":
		inner.add_child(UIStyle.icon(icon, Color.WHITE, int(h.get("icon", 34))))
	inner.add_child(UIStyle.label(String(group.label), String(h.get("text", "body"))))
	var chip := UIStyle.chip(inner, group.color)
	chip.name = "Header"
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chip)
	var count := UIStyle.label(str(group.ids.size()), "small", UIStyle.color("text_soft"))
	row.add_child(count)
	var line := ColorRect.new()
	line.color = Color(group.color, 1.0).darkened(0.15)
	line.custom_minimum_size = Vector2(0, 4)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	row.set_meta("group", group.group)
	return row


## A small tag for the first card of a group inside a match (round 1):
## the group's icon and short name on a pill in its color (`icon_only`:
## just the icon, when it has one).
static func tag(group: Dictionary, icon_only := false) -> Control:
	var m: Dictionary = GameData.sorting.get("marker", {})
	var inner := UIStyle.hbox("xs")
	inner.add_theme_constant_override("separation", 4)
	var icon := String(group.get("icon", ""))
	if icon != "":
		inner.add_child(UIStyle.icon(icon, Color.WHITE, int(m.get("tag_icon", 24))))
	if icon == "" or not icon_only:
		inner.add_child(UIStyle.label(String(group.short), "small"))
	var pill := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = group.color
	box.border_color = UIStyle.color("outline")
	box.set_border_width_all(3)
	box.set_corner_radius_all(int(m.get("tag_height", 34)) / 2)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	box.anti_aliasing = true
	pill.add_theme_stylebox_override("panel", box)
	pill.custom_minimum_size.y = float(m.get("tag_height", 34))
	pill.add_child(inner)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.name = "SortTag"
	pill.set_meta("group", group.group)
	return pill


## Whether a tag with the group's icon and short name fits in `width`.
static func label_fits(group: Dictionary, width: float) -> bool:
	var m: Dictionary = GameData.sorting.get("marker", {})
	var px := UIStyle.text_size("small")
	var text := UIStyle.display_font().get_string_size(String(group.short), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + UIStyle.outline_for(px) * 2.0
	var icon := float(m.get("tag_icon", 24)) + 4.0 if String(group.get("icon", "")) != "" else 0.0
	return text + icon + 26.0 <= width


## A line in the group's color, `width` long, centered in a strip `height`
## tall (under a group's cards in round 1 of a match).
static func line(group: Dictionary, width: float, height: float) -> Control:
	var l := _Line.new()
	l.color = group.color
	l.thickness = float(GameData.sorting.get("marker", {}).get("line", 8))
	l.size = Vector2(width, height)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.name = "SortLine"
	l.set_meta("group", group.group)
	return l


class _Line:
	extends Control
	var color := Color.WHITE
	var thickness := 8.0

	func _draw() -> void:
		var box := StyleBoxFlat.new()
		box.bg_color = color
		box.border_color = UIStyle.color("outline")
		box.set_border_width_all(2)
		box.set_corner_radius_all(int(thickness / 2.0))
		draw_style_box(box, Rect2(2.0, (size.y - thickness) / 2.0, size.x - 4.0, thickness))


## A thin divider between groups in a row (your army row in a match): a
## bar in the group's color with its icon (or its short name, stacked).
static func divider(group: Dictionary, height: float) -> Control:
	var d := _Divider.new()
	var m: Dictionary = GameData.sorting.get("marker", {})
	d.color = group.color
	d.icon = UIKit.icon(GameData.ui_icon(String(group.icon))) if String(group.get("icon", "")) != "" else null
	d.text = String(group.short)
	d.icon_side = float(m.get("divider_icon", 24))
	d.custom_minimum_size = Vector2(float(m.get("divider_width", 30)), height)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.set_meta("group", group.group)
	d.name = "SortDivider"
	return d


class _Divider:
	extends Control
	var color := Color.WHITE
	var icon: Texture2D
	var text := ""
	var icon_side := 24.0

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var bar := Rect2(w / 2.0 - 4.0, 6.0, 8.0, h - 12.0)
		var box := StyleBoxFlat.new()
		box.bg_color = color
		box.border_color = UIStyle.color("outline")
		box.set_border_width_all(2)
		box.set_corner_radius_all(4)
		draw_style_box(box, bar)
		var c := Vector2(w / 2.0, h / 2.0)
		var r := w / 2.0 - 1.0
		draw_circle(c, r + 2.0, UIStyle.color("outline"))
		draw_circle(c, r, color)
		if icon != null:
			draw_texture_rect(icon, Rect2(c - Vector2(icon_side, icon_side) / 2.0, Vector2(icon_side, icon_side)), false)
		elif text != "":
			# No icon (a level): its number in the disc.
			var digits := text.right(text.length() - text.rfind(" ") - 1) if text.contains(" ") else text
			UIStyle.draw_text(self, digits, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), "small")
