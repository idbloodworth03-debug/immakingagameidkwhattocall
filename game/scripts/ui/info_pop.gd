class_name InfoPop
extends Control
## The info popup you get by holding a card or an animal (HoldInfo): its
## name, class icon, rarity, stars, squad size ("×3"), its attack style in
## one line, and bars for Health, Damage, Speed and Range, pictures rather
## than numbers. A Ranger tool shows its name, rarity and what it does.
## Sizes and colors: feel.json "info".

const BAR_COLORS := {"health": Color("#ff4f6d"), "damage": Color("#ffa21f"), "speed": Color("#3fcf74"), "range": Color("#3b9bff")}
const BAR_ICONS := {"health": "stat_health", "damage": "stat_damage", "speed": "stat_speed", "range": "stat_range"}

var card_id := ""
var stars := 0
var level := 1
var _bars := {}

## The strongest squad in the game (health, damage a second), at its
## starting level: what the bars are measured against.
static var _strongest := {}


static func make(id: String, star_count := 0, at_level := -1) -> InfoPop:
	var pop := InfoPop.new()
	pop.card_id = id
	pop.stars = star_count
	pop.level = at_level if at_level > 0 else Profile.card_level(id)
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var size_list: Array = GameData.feel.get("info", {}).get("size", [460, 276])
	pop.size = Vector2(float(size_list[0]), float(size_list[1]) * (1.0 if not GameData.is_tool(id) else 0.62))
	pop.custom_minimum_size = pop.size
	if not GameData.is_tool(id):
		pop._bars = bars(id, pop.level)
	return pop


## The four bars (0 to 1) for an animal at `at_level`.
static func bars(id: String, at_level: int) -> Dictionary:
	var mine := _squad_power(id, at_level)
	if _strongest.is_empty():
		for other in GameData.card_order:
			if GameData.is_tool(other) or not GameData.cards.has(other):
				continue
			var p := _squad_power(other, GameData.start_level(String(GameData.get_card(other).rarity)))
			_strongest.health = maxf(float(_strongest.get("health", 1.0)), p.health)
			_strongest.damage = maxf(float(_strongest.get("damage", 1.0)), p.damage)
	var stats: Dictionary = GameData.get_card(id).get("stats", {})
	var info: Dictionary = GameData.feel.get("info", {})
	var speeds: Dictionary = info.get("speed_bars", {})
	# Square roots, so an everyday animal doesn't look nearly empty next to
	# a Mythic hero.
	return {
		"health": clampf(sqrt(mine.health / float(_strongest.health)), 0.06, 1.0),
		"damage": clampf(sqrt(mine.damage / float(_strongest.damage)), 0.06, 1.0),
		"speed": clampf(float(speeds.get(String(stats.get("speed", "medium")), 0.5)), 0.06, 1.0),
		"range": clampf(_reach_tiles(id) / float(info.get("range_full_tiles", 10.0)), 0.06, 1.0),
	}


## A whole squad's health and damage a second, at a level.
static func _squad_power(id: String, at_level: int) -> Dictionary:
	var card := GameData.get_card(id)
	var stats: Dictionary = card.get("stats", {})
	var growth := float(GameData.progression.get("stat_growth_per_level", 0.1))
	var start := GameData.start_level(String(card.get("rarity", "common")))
	var squad := BattleArmy.squad_of(id)
	var hp := float(CardRules.stat_at_level(float(stats.get("hp", 1)), at_level, start, growth))
	var bite := float(CardRules.stat_at_level(float(stats.get("damage", 1)), at_level, start, growth))
	var units := float(squad.units)
	return {
		"health": hp * float(squad.hp_pct) / 100.0 * units,
		"damage": bite * float(squad.damage_pct) / 100.0 * units / maxf(0.1, float(stats.get("hit_speed", 1.0))),
	}


## How far it reaches, in tiles: its own reach, its class's (Ranged), or its
## style's (the Cobra's sniping).
static func _reach_tiles(id: String) -> float:
	var reach := float(GameData.get_card(id).get("stats", {}).get("range", 1))
	reach = maxf(reach, float(GameData.class_info(GameData.class_of(id)).get("range", 0.0)))
	return maxf(reach, float(GameData.styles.get(id, {}).get("range", 0.0)))


func _ready() -> void:
	# A quick pop from where the finger is.
	scale = Vector2.ONE * 0.82
	create_tween().tween_property(self, "scale", Vector2.ONE, Feel.num("info", "pop_seconds", 0.14)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var card := GameData.get_card(card_id)
	var is_tool := GameData.is_tool(card_id)
	var w := size.x
	var h := size.y
	var rarity := String(card.get("rarity", "common"))
	var rarity_color := GameData.rarity_color(rarity)
	var font := UIKit.DISPLAY_FONT
	var body := UIKit.body_font()

	# The panel: solid, with the rarity's color across the top.
	var panel := Rect2(Vector2.ZERO, size)
	draw_style_box(_box(UIKit.INK, 26), panel.grow(4))
	draw_style_box(_box(UIKit.DEEP, 24), panel)
	var band := Rect2(Vector2.ZERO, Vector2(w, 62))
	var band_style := _box(rarity_color.darkened(0.12), 24)
	band_style.corner_radius_bottom_left = 0
	band_style.corner_radius_bottom_right = 0
	draw_style_box(band_style, band)
	_outlined(font, String(card.get("name", "?")), Vector2(18, 43), 30, Color.WHITE, w - 170)
	var rarity_text := GameData.rarity_name(rarity).to_upper()
	var rw := font.get_string_size(rarity_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	_outlined(font, rarity_text, Vector2(w - rw - 18, 41), 20, Color.WHITE, rw + 4)

	# The animal (or tool), on a disc of its habitat's color.
	var art := Rect2(14, 72, 120, 120)
	draw_circle(art.get_center(), 60, UIKit.habitat_color(card).darkened(0.1))
	draw_arc(art.get_center(), 60, 0, TAU, 40, UIKit.INK, 4.0, true)
	var picture: Texture2D = UnitSprites.portrait(card_id) if not is_tool else UIKit.icon(GameData.card_icon(card_id))
	if picture != null:
		var side := 132.0 if not is_tool else 84.0
		draw_texture_rect(picture, Rect2(art.get_center() - Vector2(side, side) / 2.0 - Vector2(0, 6 if not is_tool else 0), Vector2(side, side)), false)

	var x := 150.0
	var line_y := 112.0
	if not is_tool:
		# Class icon, stars, squad size.
		var cls := GameData.class_info(GameData.class_of(card_id))
		var class_color := Color(String(cls.get("color", "#ffffff")))
		var icon := UIKit.icon(GameData.ui_icon(String(cls.get("icon", ""))))
		draw_circle(Vector2(x + 20, 92), 21, UIKit.INK)
		draw_circle(Vector2(x + 20, 92), 18, class_color)
		if icon != null:
			draw_texture_rect(icon, Rect2(Vector2(x + 8, 80), Vector2(24, 24)), false)
		var cursor := x + 50
		if stars > 0:
			UIKit.draw_stars(self, Vector2(cursor + stars * 11.0, 92), stars, 10.0)
			cursor += stars * 22.0 + 14.0
		var squad := "×%d" % DraftMatch.squad_units(card_id)
		var sw := font.get_string_size(squad, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		var chip := Rect2(cursor, 76, sw + 20, 32)
		draw_style_box(_box(UIKit.INK, 12), chip.grow(2))
		draw_style_box(_box(UIKit.PANEL_LIGHT, 12), chip)
		_outlined(font, squad, Vector2(cursor + 10, 101), 26, Color.WHITE, sw + 4)
		line_y = 132.0
	# The one-line style (or what a tool does).
	var line := GameData.card_line(card_id)
	_wrapped(body, line, Vector2(x, line_y), w - x - 16, 21, UIKit.TEXT_DIM)
	if is_tool:
		return

	# Health, Damage, Speed, Range: an icon and a bar each.
	var keys := ["health", "damage", "speed", "range"]
	for i in keys.size():
		var key: String = keys[i]
		var col := i % 2
		var row := i / 2
		var at := Vector2(14 + col * (w - 28) / 2.0, 206 + row * 34)
		var bar_w := (w - 28) / 2.0 - 52
		var icon := UIKit.icon(GameData.ui_icon(BAR_ICONS[key]))
		if icon != null:
			draw_texture_rect(icon, Rect2(at, Vector2(28, 28)), false, BAR_COLORS[key].lightened(0.25))
		var track := Rect2(at + Vector2(36, 7), Vector2(bar_w, 15))
		draw_style_box(_box(UIKit.INK, 8), track.grow(2))
		draw_style_box(_box(Color("#081430"), 7), track)
		var fill := Rect2(track.position, Vector2(track.size.x * float(_bars.get(key, 0.0)), track.size.y))
		draw_style_box(_box(BAR_COLORS[key], 7), fill)
		draw_style_box(_box(BAR_COLORS[key].lightened(0.35), 4), Rect2(fill.position + Vector2(3, 2), Vector2(maxf(0.0, fill.size.x - 6), 4)))


func _box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	return box


func _outlined(font: Font, text: String, at: Vector2, font_size: int, color: Color, max_width: float) -> void:
	var fs := font_size
	while fs > 12 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_width:
		fs -= 1
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, UIKit.INK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


## Text wrapped to `width`, at most two lines.
func _wrapped(font: Font, text: String, at: Vector2, width: float, font_size: int, color: Color) -> void:
	var words := text.split(" ")
	var lines: Array[String] = [""]
	for word in words:
		var trial := (lines[-1] + " " + word).strip_edges()
		if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and lines[-1] != "":
			if lines.size() == 2:
				lines[-1] += "…"
				break
			lines.append(word)
		else:
			lines[-1] = trial
	for i in lines.size():
		var y := at.y + i * (font_size + 6)
		draw_string_outline(font, Vector2(at.x, y), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, UIKit.INK)
		draw_string(font, Vector2(at.x, y), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
