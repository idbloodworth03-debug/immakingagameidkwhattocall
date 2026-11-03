class_name GameCard
extends Control
## The one card look (UIStyle, "Ranger Camp"): a painted-wood frame in the
## card's rarity color, the animal (or tool) big in a sunken window lit in
## its habitat color, its class badge in the top-left corner (a tool badge
## for tools), stars along the bottom, an upgrade arrow when a pick would
## add a star and, if there's room, the name. No other text. With no card
## id it's an empty slot.
##
## The frame, window, glow, coin and stars are regions of a few shared
## textures (tools/make_ui_art.py), so cards batch well. Tap handling is up
## to the screen (UIKit.on_tap).

var card_id := ""
## A green arrow in the top-right corner: a pick here adds a star.
var upgrade_arrow := false:
	set(value):
		if value != upgrade_arrow:
			upgrade_arrow = value
			queue_redraw()
## Stars along the bottom (0 hides them). `star_preview` makes the last one
## pulse: what buying this would make it.
var stars := 0
var star_preview := false
var show_name := false
var show_class := true
## Picked: a warm glow around it and a gold rim.
var selected := false:
	set(value):
		if value != selected:
			selected = value
			queue_redraw()
## 0..1: bought, sold out...: dimmed, with a check mark.
var done := 0.0:
	set(value):
		done = value
		queue_redraw()
## 0..1: a bright flash (a star added).
var flash := 0.0:
	set(value):
		flash = value
		queue_redraw()

var _time := 0.0
var _frame := SkinBox.make("card")
var _window := SkinBox.make("window")
var _glow := SkinBox.make("glow")
var _slot := SkinBox.make("inset")


static func make(id: String, card_size: Vector2) -> GameCard:
	var card := GameCard.new()
	card.card_id = id
	card.custom_minimum_size = card_size
	card.size = card_size
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	return card


func _ready() -> void:
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	pivot_offset = size / 2.0
	set_process(false)


## Lets the star preview pulse (only while it's on screen).
func animate(on: bool) -> void:
	set_process(on)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var rect := Rect2(Vector2.ZERO, size)
	if card_id == "":
		_slot.tint = UIStyle.color("panel_inset")
		draw_style_box(_slot, rect)
		var paw := UIKit.icon(GameData.ui_icon("paw"))
		if paw != null:
			var side := minf(w, h) * 0.4
			draw_texture_rect(paw, Rect2(rect.get_center() - Vector2(side, side) / 2.0, Vector2(side, side)), false, Color(1, 1, 1, 0.16))
		return
	var card := GameData.get_card(card_id)
	var is_tool := GameData.is_tool(card_id)

	if selected:
		_glow.tint = Color(UIStyle.color("selected"), 0.95)
		draw_style_box(_glow, rect.grow(18.0))
	_frame.tint = UIStyle.rarity_color(String(card.get("rarity", "common")))
	if selected:
		_frame.tint = _frame.tint.lerp(UIStyle.color("selected"), 0.25)
	draw_style_box(_frame, rect)

	# The art window: sunken, lit in the habitat's color.
	var border := UIStyle.num("card", "border", 4)
	var inset := UIStyle.num("card", "frame", 7) + border
	var lip := 5.0
	var name_h := float(UIStyle.text_size("small")) * 1.15 if show_name else 0.0
	var art := Rect2(inset, inset, w - inset * 2.0, h - inset * 2.0 - lip - name_h)
	_window.tint = UIStyle.color("tool") if is_tool else _habitat_color(card).lightened(0.15)
	draw_style_box(_window, art)
	_draw_art(card, art, is_tool)

	if show_name:
		UIStyle.draw_text(self, String(card.get("name", "?")), Rect2(inset * 0.5, art.end.y + 1.0, w - inset, name_h), "small")

	# Stars along the bottom edge of the window.
	if stars > 0:
		var sr := clampf(w * 0.085, 12.0, 20.0)
		var gap := sr * 1.9
		for i in stars:
			var at := Vector2(w / 2.0 + (i - (stars - 1) / 2.0) * gap, art.end.y - sr * 0.5)
			var pulse := 0.5 + 0.5 * sin(_time * 7.0) if star_preview and i == stars - 1 else 0.0
			UIStyle.draw_particle(self, "star", at, sr * (1.0 + 0.2 * pulse), UIStyle.color("gold").lightened(0.25 * pulse))

	# Its class (or a tool badge) in the top-left corner; an upgrade arrow
	# in the top-right.
	var corner := clampf(w * 0.15, 18.0, 30.0)
	if show_class:
		var at := Vector2(corner * 0.85, corner * 0.85)
		if is_tool:
			UIStyle.draw_particle(self, "badge", at, corner * 0.75, UIStyle.color("tool"))
			var box := UIKit.icon(GameData.ui_icon("toolbox"))
			if box != null:
				var side := corner * 0.95
				draw_texture_rect(box, Rect2(at - Vector2(side, side) / 2.0, Vector2(side, side)), false)
		else:
			UIStyle.draw_class_badge(self, at, corner * 0.72, GameData.class_of(card_id))
	if upgrade_arrow:
		var at := Vector2(w - corner * 0.85, corner * 0.85)
		var bob := 2.0 * sin(_time * 5.0)
		UIStyle.draw_particle(self, "badge", at + Vector2(0, bob), corner * 0.72, UIStyle.color("primary"))
		var arrow := UIKit.icon(GameData.ui_icon("upgrade"))
		if arrow != null:
			var side := corner * 1.0
			draw_texture_rect(arrow, Rect2(at + Vector2(0, bob) - Vector2(side, side) / 2.0, Vector2(side, side)), false)

	if flash > 0.0:
		_glow.tint = Color(1, 1, 0.85, flash * 0.9)
		draw_style_box(_glow, rect.grow(6.0))
	if done > 0.0:
		var dim := StyleBoxFlat.new()
		dim.bg_color = Color(UIStyle.color("outline"), 0.5 * done)
		dim.set_corner_radius_all(int(UIStyle.radius("card")))
		dim.anti_aliasing = true
		draw_style_box(dim, rect)
		var c := rect.get_center()
		var cr := minf(w, h) * 0.2 * (0.6 + 0.4 * done)
		draw_circle(c + Vector2(0, 3), cr + 3, Color(UIStyle.color("outline"), 0.4 * done))
		draw_circle(c, cr + 3, Color(UIStyle.color("outline"), done))
		draw_circle(c, cr, Color(UIStyle.color("primary"), done))
		var check := UIKit.icon(GameData.ui_icon("check"))
		if check != null:
			draw_texture_rect(check, Rect2(c - Vector2(cr, cr) * 0.7, Vector2(cr, cr) * 1.4), false, Color(1, 1, 1, done))


func _draw_art(card: Dictionary, art: Rect2, is_tool: bool) -> void:
	var portrait := UnitSprites.portrait(card_id) if not is_tool else null
	if portrait != null:
		# Big, standing near the bottom of the window, kept inside the card.
		var side := minf(art.size.x * 1.02, (art.end.y - 2.0) / 0.96)
		side = minf(side, art.size.y * 1.25)
		var at := Vector2(art.get_center().x - side / 2.0, art.end.y - side * 0.96)
		draw_set_transform(Vector2(art.get_center().x, art.end.y - art.size.y * 0.1), 0.0, Vector2(1.0, 0.25))
		draw_circle(Vector2.ZERO, art.size.x * 0.32, Color(UIStyle.color("outline"), 0.22))
		draw_set_transform(Vector2.ZERO)
		draw_texture_rect(portrait, Rect2(at, Vector2(side, side)), false)
		return
	var icon := UIKit.icon(GameData.card_icon(card_id))
	if icon != null:
		var side := minf(art.size.x, art.size.y) * 0.72
		var at := art.get_center() - Vector2(side, side) / 2.0
		draw_texture_rect(icon, Rect2(at + Vector2(0, side * 0.05), Vector2(side, side)), false, Color(UIStyle.color("outline"), 0.35))
		draw_texture_rect(icon, Rect2(at, Vector2(side, side)), false)


static func _habitat_color(card: Dictionary) -> Color:
	var info: Dictionary = GameData.habitats.get(String(card.get("habitat", "")), {})
	return Color(String(info.get("color", "#6fae5a")))
