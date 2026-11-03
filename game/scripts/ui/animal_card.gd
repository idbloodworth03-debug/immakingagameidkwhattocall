class_name AnimalCard
extends Control
## One collectible card, drawn in code so it stays crisp at any size: a
## glossy rim in the rarity's color, the animal's portrait standing in a
## spotlight of its habitat color, a name plate, its class badge, and the
## level with copies toward the next upgrade. Epic and Legendary
## cards shine now and then. Tap it to call `on_tap`.

const SIZE_NORMAL := Vector2(158, 214)
const SIZE_SMALL := Vector2(120, 160)

## What the bottom of the card shows: the collection (level and copies, or
## where to find it), just the level, or nothing.
enum Info { COLLECTION, LEVEL, NONE }

var animal_id := ""
var small := false
var info := Info.COLLECTION
var highlighted := false:
	set(value):
		highlighted = value
		queue_redraw()
## A word stamped across the card, like "YOURS" ("" for none).
var stamp := ""
var stamp_color := UIKit.GREEN
## Draft Duel stars (2 or 3 show over the name; 0 or 1 show nothing).
var stars := 0

var _owned := false
var _level := 1
var _copies := 0
var _needed := 0
var _upgradable := false
var _new := false
var _reachable := false
var _time := 0.0

static var _spot: GradientTexture2D


static func create(id: String, small_card := false) -> AnimalCard:
	var card := AnimalCard.new()
	# Portraits are drawn much smaller than they're rendered.
	card.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	card.animal_id = id
	card.small = small_card
	card.custom_minimum_size = SIZE_SMALL if small_card else SIZE_NORMAL
	card.refresh()
	return card


## Re-reads the profile and redraws. Call after the profile changes.
func refresh() -> void:
	var animal := GameData.get_card(animal_id)
	_owned = Profile.has_card(animal_id)
	_level = Profile.card_level(animal_id)
	_reachable = int(animal.unlock_arena_index) <= Profile.highest_arena()
	_new = Profile.is_card_new(animal_id)
	var cost := Profile.upgrade_cost(animal_id) if _owned else {}
	_needed = int(cost.get("copies", 0))
	_copies = Profile.card_copies(animal_id) if _owned else 0
	_upgradable = _owned and Profile.has_copies_for_upgrade(animal_id)
	var rarity: String = animal.get("rarity", "common")
	set_process(_owned and rarity in ["epic", "legendary"])
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if is_visible_in_tree():
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var animal := GameData.get_card(animal_id)
	var w := size.x
	var h := size.y
	var rect := Rect2(Vector2.ZERO, size)
	var radius := int(w * 0.11)
	var rarity_color := GameData.rarity_color(animal.get("rarity", "common"))
	var dim := info == Info.COLLECTION and not _owned
	var rim := rarity_color.darkened(0.35) if dim else rarity_color
	var margin := w * 0.055

	# Glow when picked, a softer one for rare cards, and a drop shadow.
	if highlighted:
		var glow := UIKit.box(Color(UIKit.YELLOW, 0.0), radius + 4)
		glow.shadow_color = Color(UIKit.YELLOW, 0.85)
		glow.shadow_size = 12
		draw_style_box(glow, rect.grow(2))
	elif not dim and animal.get("rarity", "") in ["epic", "legendary"]:
		var aura := UIKit.box(Color(rarity_color, 0.0), radius + 2)
		aura.shadow_color = Color(rarity_color, 0.45)
		aura.shadow_size = 8
		draw_style_box(aura, rect)
	draw_style_box(UIKit.box(Color(UIKit.INK, 0.4), radius + 2), Rect2(rect.position + Vector2(0, 3), rect.size))

	# The rim: dark edge, rarity color, gloss along the top.
	draw_style_box(UIKit.box(UIKit.YELLOW if highlighted else rim.darkened(0.5).lerp(UIKit.INK, 0.3), radius + 2), rect)
	var inner := rect.grow(-3.0)
	draw_style_box(UIKit.box(rim, radius), inner)
	var gloss := UIKit.box(Color(1, 1, 1, 0.22), radius)
	gloss.corner_radius_bottom_left = 4
	gloss.corner_radius_bottom_right = 4
	draw_style_box(gloss, Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.35)))

	# The art window with a spotlight in the habitat's color.
	var art := Rect2(margin, margin, w - margin * 2, h * (0.66 if info != Info.NONE else 0.76) - margin)
	var habitat := UIKit.habitat_color(animal)
	if dim:
		habitat = habitat.darkened(0.55).lerp(Color(0.15, 0.17, 0.24), 0.5)
	var art_radius := int(radius * 0.75)
	draw_style_box(UIKit.box(habitat.darkened(0.3), art_radius), art)
	var spot_side := art.size.x
	var spot_center := art.get_center() - Vector2(0, art.size.y * 0.08)
	draw_texture_rect(_spot_texture(), Rect2(spot_center - Vector2(spot_side, spot_side) / 2.0, Vector2(spot_side, spot_side)),
			false, Color(habitat.lightened(0.45), 0.9))
	var feet := Vector2(art.get_center().x, art.end.y - art.size.y * 0.12)
	draw_set_transform(feet, 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, art.size.x * 0.36, Color(UIKit.INK, 0.28))
	draw_set_transform(Vector2.ZERO)
	_draw_animal(animal, art, dim)
	var frame := UIKit.box(Color(0, 0, 0, 0), art_radius)
	frame.draw_center = false
	frame.set_border_width_all(2)
	frame.border_color = Color(UIKit.INK, 0.45)
	draw_style_box(frame, art)
	if not dim:
		_draw_sheen(art)

	# Name plate across the bottom of the art.
	var font := get_theme_default_font()
	var plate_h := h * (0.12 if small else 0.11)
	var plate := Rect2(art.position.x, art.end.y - plate_h * 0.55, art.size.x, plate_h)
	var plate_style := UIKit.box(Color(UIKit.INK, 0.78), int(plate_h * 0.35))
	draw_style_box(plate_style, plate)
	_text(font, String(animal.get("name", "?")), plate, int(h * (0.075 if small else 0.072)), Color.WHITE)

	if stars > 1:
		UIKit.draw_stars(self, Vector2(w / 2.0, plate.position.y - h * 0.035), stars, w * 0.07)

	# Bottom: level and copies, or where to find it.
	if info != Info.NONE:
		_draw_info(font, Rect2(margin, plate.end.y + h * 0.025, w - margin * 2, h - margin - plate.end.y - h * 0.025), rarity_color)

	# Class badge, overlapping the top-left corner.
	if not dim or _reachable:
		UIStyle.draw_class_badge(self, Vector2(w * 0.13, w * 0.13), w * 0.115, GameData.class_of(animal_id))
	# Habitat badge, overlapping the top-right corner.
	var habitat_id := String(animal.get("habitat", ""))
	if habitat_id != "" and not (dim and not _reachable):
		UIKit.draw_habitat_badge(self, Vector2(w - w * 0.13, w * 0.13), w * 0.115, habitat_id)
	if _new and info == Info.COLLECTION:
		var tag := Rect2(w * 0.32, -h * 0.015, w * 0.36, h * 0.1)
		var tag_style := UIKit.box(UIKit.YELLOW, int(tag.size.y * 0.4))
		tag_style.set_border_width_all(2)
		tag_style.border_color = UIKit.INK
		draw_style_box(tag_style, tag)
		_text(font, "NEW", tag, int(tag.size.y * 0.62), Color.WHITE)
	if stamp != "":
		_draw_stamp(font, rect)


func _draw_animal(animal: Dictionary, art: Rect2, dim: bool) -> void:
	var portrait := UnitSprites.portrait(animal_id)
	if portrait != null:
		# A little bigger than the window, so the animal pops out of the top.
		var side := art.size.x * 1.12
		var at := Vector2(art.get_center().x - side / 2.0, art.end.y - side * 0.97)
		var tint := Color(0.22, 0.24, 0.32) if dim else Color.WHITE
		draw_texture_rect(portrait, Rect2(at, Vector2(side, side)), false, tint)
	else:
		var icon := UIKit.icon(GameData.card_icon(animal_id))
		if icon != null:
			var side := minf(art.size.x, art.size.y) * 0.7
			var at := art.get_center() - Vector2(side, side) / 2.0
			var flip := GameData.card_icon_flipped(animal_id)
			var tint := Color(1, 1, 1, 0.35) if dim else Color.WHITE
			draw_set_transform(at + Vector2(side if flip else 0.0, 0), 0.0, Vector2(-1 if flip else 1, 1))
			draw_texture_rect(icon, Rect2(Vector2(0, side * 0.04), Vector2(side, side)), false, Color(0, 0, 0, 0.3 * tint.a))
			draw_texture_rect(icon, Rect2(Vector2.ZERO, Vector2(side, side)), false, tint)
			draw_set_transform(Vector2.ZERO)
	if dim:
		var lock := UIKit.icon(GameData.ui_icon("locked"))
		if lock != null and not _reachable:
			var side := art.size.x * 0.34
			draw_texture_rect(lock, Rect2(art.get_center() - Vector2(side, side) / 2.0, Vector2(side, side)), false, Color(1, 1, 1, 0.85))


## A word stamped at an angle across the card.
func _draw_stamp(font: Font, rect: Rect2) -> void:
	var font_size := int(rect.size.x * 0.2)
	var width := font.get_string_size(stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_set_transform(rect.get_center(), -0.35)
	var band := Rect2(Vector2(-width / 2.0 - 10, -font_size * 0.75), Vector2(width + 20, font_size * 1.4))
	var style := UIKit.box(Color(stamp_color.darkened(0.2), 0.92), 8)
	style.set_border_width_all(3)
	style.border_color = Color.WHITE
	draw_style_box(style, band)
	draw_string_outline(font, Vector2(-width / 2.0, font_size * 0.36), stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, UIKit.INK)
	draw_string(font, Vector2(-width / 2.0, font_size * 0.36), stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	draw_set_transform(Vector2.ZERO)


## Now and then a band of light sweeps across rare cards.
func _draw_sheen(art: Rect2) -> void:
	if not is_processing():
		return
	var phase := fmod(_time, 3.6) / 3.6
	if phase > 0.3:
		return
	var x := lerpf(art.position.x - art.size.x * 0.6, art.end.x + art.size.x * 0.2, phase / 0.3)
	var band := PackedVector2Array([
		Vector2(x, art.end.y), Vector2(x + art.size.x * 0.22, art.end.y),
		Vector2(x + art.size.x * 0.62, art.position.y), Vector2(x + art.size.x * 0.4, art.position.y)])
	var window := PackedVector2Array([art.position, Vector2(art.end.x, art.position.y), art.end, Vector2(art.position.x, art.end.y)])
	for piece in Geometry2D.intersect_polygons(band, window):
		draw_colored_polygon(piece, Color(1, 1, 1, 0.22))


func _draw_info(font: Font, area: Rect2, rarity_color: Color) -> void:
	var h := area.size.y
	if info == Info.COLLECTION and not _owned:
		var animal := GameData.get_card(animal_id)
		var text := "Not found yet" if _reachable else "Arena %d" % (int(animal.unlock_arena_index) + 1)
		_text(font, text, area, int(h * 0.62), UIKit.TEXT_DIM)
		return
	var badge_r := h * 0.5
	var badge_c := Vector2(area.position.x + badge_r, area.get_center().y)
	if info == Info.LEVEL or _needed == 0:
		var label := "Level %d" % _level if _needed > 0 or info == Info.LEVEL else "MAX"
		_text(font, label, area, int(h * 0.66), UIKit.YELLOW if label == "MAX" else Color.WHITE)
		return
	var bar := Rect2(area.position.x + badge_r, area.position.y + h * 0.16, area.size.x - badge_r, h * 0.68)
	var track := UIKit.box(Color(UIKit.INK, 0.65), int(bar.size.y / 2))
	draw_style_box(track, bar)
	var ratio := clampf(float(_copies) / maxf(1.0, float(_needed)), 0.0, 1.0)
	if ratio > 0.0:
		var fill_color := UIKit.GREEN if _upgradable else UIKit.BLUE
		var fill := Rect2(bar.position + Vector2(2, 2), Vector2(maxf(bar.size.y - 4, (bar.size.x - 4) * ratio), bar.size.y - 4))
		draw_style_box(UIKit.bar_fill(fill_color, int(fill.size.y / 2)), fill)
	var count := "%d/%d" % [_copies, _needed]
	_text(font, count, Rect2(bar.position + Vector2(badge_r * 0.4, 0), bar.size - Vector2(badge_r * 0.4, 0)), int(h * 0.56), Color.WHITE)
	# Level badge on the left end of the bar.
	draw_circle(badge_c, badge_r, UIKit.INK)
	draw_circle(badge_c, badge_r - 2.0, rarity_color.darkened(0.15))
	draw_circle(badge_c - Vector2(0, badge_r * 0.25), badge_r * 0.55, Color(1, 1, 1, 0.18))
	_text(font, str(_level), Rect2(badge_c - Vector2(badge_r, badge_r), Vector2(badge_r, badge_r) * 2.0), int(badge_r * 1.15), Color.WHITE)
	if _upgradable:
		var arrow := UIKit.icon(GameData.ui_icon("upgrade"))
		if arrow != null:
			var side := h * 0.9
			draw_texture_rect(arrow, Rect2(Vector2(bar.end.x - side * 0.85, bar.get_center().y - side / 2.0), Vector2(side, side)), false, Color.WHITE)


## Centered outlined text, shrunk to fit the width if it has to.
func _text(font: Font, text: String, area: Rect2, font_size: int, color: Color) -> void:
	var size_now := font_size
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_now).x
	while width > area.size.x - 6 and size_now > 9:
		size_now -= 1
		width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_now).x
	var baseline := Vector2(area.get_center().x - width / 2.0, area.get_center().y + size_now * 0.36)
	var outline := maxi(3, int(size_now * 0.22))
	draw_string_outline(font, baseline + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_now, outline, Color(UIKit.INK, 0.5))
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_now, outline, UIKit.INK)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_now, color)


static func _spot_texture() -> GradientTexture2D:
	if _spot == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		_spot = GradientTexture2D.new()
		_spot.gradient = gradient
		_spot.fill = GradientTexture2D.FILL_RADIAL
		_spot.fill_from = Vector2(0.5, 0.5)
		_spot.fill_to = Vector2(1.0, 0.5)
		_spot.width = 128
		_spot.height = 128
	return _spot
