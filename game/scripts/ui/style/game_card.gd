class_name GameCard
extends Control
## The one card look (UIStyle): a frame in the card's rarity color, the
## animal (or tool) big in the middle on a soft spotlight of its habitat
## color, the Acorn cost in the top-left corner, a small habitat badge in
## the top-right, stars along the bottom and, if there's room, the name.
## With no card id it's an empty slot.
##
## Drawn in code so it stays crisp at any size. Tap handling is up to the
## screen (UIKit.on_tap).

var card_id := ""
## The price in the corner (-1 hides it), red when you can't afford it.
var cost := -1
var affordable := true
## Stars along the bottom (0 hides them). `star_preview` makes the last one
## pulse: what buying this would make it.
var stars := 0
var star_preview := false
var show_name := false
var show_habitat := true
## Picked: a thick glowing outline (the screen lifts it).
var selected := false:
	set(value):
		selected = value
		queue_redraw()
## Bought, sold out...: dimmed, with a check mark.
var done := false

var _time := 0.0
var _box := ChunkyBox.new()
var _well := ChunkyBox.new()
static var _spot: GradientTexture2D


static func make(id: String, card_size: Vector2) -> GameCard:
	var card := GameCard.new()
	card.card_id = id
	card.custom_minimum_size = card_size
	card.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	return card


func _ready() -> void:
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	pivot_offset = size / 2.0
	set_process(false)


## Called by the screen after setting star_preview, so the star can pulse.
func animate(on: bool) -> void:
	set_process(on)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var rect := Rect2(Vector2.ZERO, size)
	var r := minf(float(UIStyle.radius("card")), w * 0.18)
	var ink := UIStyle.color("outline")
	if card_id == "":
		_draw_empty(rect, r)
		return
	var card := GameData.get_card(card_id)
	var is_tool := GameData.is_tool(card_id)
	var frame_color := UIStyle.rarity_color(String(card.get("rarity", "common")))

	# Shadow, outline (glowing gold when picked), and the rarity frame.
	var box := _box
	box.color = frame_color
	box.outline = UIStyle.color("selected") if selected else ink
	box.border = UIStyle.num("card", "border", 4) + (2.0 if selected else 0.0)
	box.lip = 5.0
	box.radius = r
	box.highlight = 0.6
	box.shadow_alpha = 0.3
	box.shadow_size = 5
	box.shadow_offset = 5
	box.glow = 14.0 if selected else 0.0
	box.glow_color = Color(UIStyle.color("selected"), 0.8)
	draw_style_box(box, rect)

	# The art window: a soft spotlight in the habitat color.
	var frame := UIStyle.num("card", "frame", 7) + box.border
	var name_h := float(UIStyle.text_size("small")) * 1.15 if show_name else 0.0
	var art := Rect2(frame, frame, w - frame * 2.0, h - frame * 2.0 - box.lip - name_h)
	var back := UIStyle.color("tool") if is_tool else _habitat_color(card)
	var well := _well
	well.color = back.darkened(0.15)
	well.outline = Color(ink, 0.55)
	well.sunken = true
	well.border = 2.0
	well.radius = maxf(4.0, r - frame * 0.6)
	well.shadow_alpha = 0.0
	draw_style_box(well, art)
	var spot := art.size.x * 1.1
	draw_texture_rect(_spot_texture(), Rect2(art.get_center() - Vector2(spot, spot) / 2.0 - Vector2(0, art.size.y * 0.05), Vector2(spot, spot)), false, Color(back.lightened(0.55), 0.85))
	_draw_art(card, art, is_tool)

	if show_name:
		var name_area := Rect2(frame * 0.5, art.end.y + 1.0, w - frame, name_h)
		UIStyle.draw_text(self, String(card.get("name", "?")), name_area, "small")

	# Stars along the bottom edge.
	if stars > 0:
		var sr := clampf(w * 0.075, 11.0, 18.0)
		var gap := sr * 2.05
		var y := art.end.y - sr * 0.55
		for i in stars:
			var at := Vector2(w / 2.0 + (i - (stars - 1) / 2.0) * gap, y)
			var pulse := star_preview and i == stars - 1
			var k := 1.0 + (0.18 * (0.5 + 0.5 * sin(_time * 7.0)) if pulse else 0.0)
			UIStyle.draw_star(self, at, sr * k, true, 0.75 + 0.25 * (0.5 + 0.5 * sin(_time * 7.0)) if pulse else 1.0)

	# Cost in the top-left corner, habitat in the top-right.
	var corner := clampf(w * 0.14, 20.0, 30.0)
	if cost >= 0:
		_draw_cost(Vector2(corner * 0.9, corner * 0.9), corner, str(cost))
	var habitat := String(card.get("habitat", ""))
	if show_habitat and habitat != "":
		UIKit.draw_habitat_badge(self, Vector2(w - corner * 0.85, corner * 0.85), corner * 0.62, habitat)

	if done:
		draw_style_box(_dim_box(r), rect)
		var c := rect.get_center()
		var cr := minf(w, h) * 0.2
		draw_circle(c + Vector2(0, 3), cr + 3, Color(ink, 0.4))
		draw_circle(c, cr + 3, ink)
		draw_circle(c, cr, UIStyle.color("primary"))
		var check := UIKit.icon(GameData.ui_icon("check"))
		if check != null:
			draw_texture_rect(check, Rect2(c - Vector2(cr, cr) * 0.7, Vector2(cr, cr) * 1.4), false)


func _draw_art(card: Dictionary, art: Rect2, is_tool: bool) -> void:
	var portrait := UnitSprites.portrait(card_id) if not is_tool else null
	if portrait != null:
		# Big: the animal fills the window, standing near its bottom.
		# Big, standing near the bottom of the window, and kept inside the card.
		var side := minf(art.size.x * 1.02, (art.end.y - 2.0) / 0.96)
		side = minf(side, art.size.y * 1.25)
		var at := Vector2(art.get_center().x - side / 2.0, art.end.y - side * 0.96)
		draw_set_transform(Vector2.ZERO)
		var shadow_at := Vector2(art.get_center().x, art.end.y - art.size.y * 0.1)
		draw_set_transform(shadow_at, 0.0, Vector2(1.0, 0.25))
		draw_circle(Vector2.ZERO, art.size.x * 0.32, Color(UIStyle.color("outline"), 0.25))
		draw_set_transform(Vector2.ZERO)
		draw_texture_rect(portrait, Rect2(at, Vector2(side, side)), false)
		return
	var icon := UIKit.icon(GameData.card_icon(card_id))
	if icon != null:
		var side := minf(art.size.x, art.size.y) * 0.72
		var at := art.get_center() - Vector2(side, side) / 2.0
		draw_texture_rect(icon, Rect2(at + Vector2(0, side * 0.05), Vector2(side, side)), false, Color(UIStyle.color("outline"), 0.35))
		draw_texture_rect(icon, Rect2(at, Vector2(side, side)), false)


func _draw_cost(center: Vector2, radius: float, text: String) -> void:
	var ink := UIStyle.color("outline")
	var fill := UIStyle.color("acorn") if affordable else UIStyle.color("danger")
	draw_circle(center + Vector2(0, 3), radius, Color(ink, 0.45))
	draw_circle(center, radius, ink)
	draw_circle(center, radius - 3.0, UIStyle.bottom_of(fill))
	draw_circle(center - Vector2(0, radius * 0.12), radius - 5.0, UIStyle.top_of(fill))
	draw_circle(center - Vector2(radius * 0.3, radius * 0.38), radius * 0.26, Color(1, 1, 1, 0.4))
	UIStyle.draw_text(self, text, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), "small")


func _draw_empty(rect: Rect2, r: float) -> void:
	var box := _well
	box.color = UIStyle.color("panel_inset")
	box.outline = Color(UIStyle.color("outline"), 0.5)
	box.sunken = true
	box.border = 3.0
	box.radius = r
	box.shadow_alpha = 0.0
	draw_style_box(box, rect)
	var c := rect.get_center()
	var paw := UIKit.icon(GameData.ui_icon("paw"))
	if paw != null:
		var side := minf(rect.size.x, rect.size.y) * 0.4
		draw_texture_rect(paw, Rect2(c - Vector2(side, side) / 2.0, Vector2(side, side)), false, Color(1, 1, 1, 0.18))


static func _dim_box(r: float) -> StyleBoxFlat:
	var dim := StyleBoxFlat.new()
	dim.bg_color = Color(UIStyle.color("outline"), 0.5)
	dim.set_corner_radius_all(int(r))
	dim.anti_aliasing = true
	return dim


static func _habitat_color(card: Dictionary) -> Color:
	var info: Dictionary = GameData.synergies.get(String(card.get("habitat", "")), {})
	return Color(String(info.get("color", "#6fae5a")))


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
