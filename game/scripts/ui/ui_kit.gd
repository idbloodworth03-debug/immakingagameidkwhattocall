class_name UIKit
extends RefCounted
## Shared colors, the menu theme and small helpers that build styled controls
## in code. Every screen uses these so the whole game looks consistent. When
## real art arrives, most of the look can change in this one file.

const BG_TOP := Color("#3277c9")
const BG_BOTTOM := Color("#163a73")
const PANEL := Color("#1e4f96")
const PANEL_DARK := Color("#112f5e")
const PANEL_LIGHT := Color("#2f68b8")
const TEXT := Color("#ffffff")
const TEXT_DIM := Color("#b9cdee")
const GOLD := Color("#ffcf40")
const GEMS := Color("#5ef08a")
const ENERGY := Color("#e04dd8")
const YELLOW := Color("#ffc533")
const GREEN := Color("#3fbf55")
const BLUE := Color("#3a8ee6")
const RED := Color("#e5484d")
const GREY := Color("#7d8796")
const TROPHY := Color("#ffb627")

const DISPLAY_FONT := preload("res://art/fonts/LilitaOne-Regular.ttf")
const BODY_FONT := preload("res://art/fonts/Nunito.ttf")

## Background color behind each card's icon, by habitat.
const HABITAT_COLORS := {
	"urban": Color("#7a8494"),
	"forest": Color("#3d7a3a"),
	"prairie": Color("#b5a24a"),
	"wetland": Color("#3a7a6f"),
	"savanna": Color("#c9a14a"),
	"desert": Color("#c5703f"),
	"tundra": Color("#8fb6d1"),
	"jungle": Color("#2e8b57"),
	"mountain": Color("#7f88a0"),
	"marine": Color("#2f6fb5"),
	"island": Color("#3fa7a0"),
	"tool": Color("#a0703a"),
}


static var _icons := {}
static var _body_font: FontVariation


static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = DISPLAY_FONT
	theme.default_font_size = 24

	# Chunky outlined text, like most mobile card games.
	for type in ["Label", "Button", "LineEdit"]:
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_outline_color", type, Color(0, 0, 0, 0.85))
		theme.set_constant("outline_size", type, 6)
	theme.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.6))

	theme.set_stylebox("normal", "Button", chunky(BLUE))
	theme.set_stylebox("hover", "Button", chunky(BLUE.lightened(0.08)))
	theme.set_stylebox("pressed", "Button", chunky(BLUE.darkened(0.1), true))
	theme.set_stylebox("disabled", "Button", chunky(GREY.darkened(0.25)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())

	theme.set_stylebox("panel", "PanelContainer", box(PANEL, 18, 14))
	theme.set_stylebox("panel", "Panel", box(PANEL, 18))

	var field := box(PANEL_DARK, 12, 12)
	field.set_border_width_all(3)
	field.border_color = PANEL_LIGHT
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", field)

	theme.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.45), 8))
	theme.set_stylebox("fill", "ProgressBar", box(BLUE, 8))
	return theme


## A rounded rectangle style.
static func box(color: Color, radius := 16, padding := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	style.anti_aliasing = true
	return style


## A button style with a thick darker bottom edge so it looks pressable.
static func chunky(color: Color, pressed := false) -> StyleBoxFlat:
	var style := box(color, 16)
	style.border_color = color.darkened(0.45)
	style.set_border_width_all(2)
	style.border_width_bottom = 2 if pressed else 7
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12 if pressed else 8
	style.content_margin_bottom = 8
	return style


## A chunky button that squashes a little when pressed and clicks.
static func button(text: String, color := BLUE, font_size := 26, min_size := Vector2(0, 72)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	color_button(b, color)
	b.resized.connect(func() -> void: b.pivot_offset = b.size / 2.0)
	b.button_down.connect(func() -> void: _squash(b, 0.93))
	b.button_up.connect(func() -> void: _squash(b, 1.0))
	b.pressed.connect(func() -> void: Sound.play("tap"))
	return b


static func _squash(control: Control, amount: float) -> void:
	control.create_tween().tween_property(control, "scale", Vector2(amount, amount), 0.07)


static func color_button(b: Button, color: Color) -> void:
	b.add_theme_stylebox_override("normal", chunky(color))
	b.add_theme_stylebox_override("hover", chunky(color.lightened(0.08)))
	b.add_theme_stylebox_override("pressed", chunky(color.darkened(0.1), true))


static func label(text: String, font_size := 24, color := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


## A label that wraps onto several lines.
static func paragraph(text: String, font_size := 22, color := TEXT_DIM) -> Label:
	var l := label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", body_font())
	l.add_theme_constant_override("outline_size", 0)
	l.custom_minimum_size.x = 100
	return l


static func panel(color := PANEL, padding := 14, radius := 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, radius, padding))
	return p


static func vbox(separation := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


static func hbox(separation := 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## A section heading with a thin line, used inside scrolling pages.
static func heading(text: String) -> Control:
	var row := hbox(10)
	var l := label(text, 28, TEXT)
	row.add_child(l)
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.25)
	line.custom_minimum_size = Vector2(0, 3)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	return row


## A dark pill showing an amount, like the gold and gem counters.
## `icon_name` is a file in res://art/icons/ (see GameData.ui_icon).
static func pill(icon_name: String, icon_color: Color, amount_text: String) -> PanelContainer:
	var p := panel(Color(0, 0, 0, 0.35), 6, 22)
	var row := hbox(8)
	p.add_child(row)
	row.add_child(icon_rect(icon_name, icon_color, 36))
	var l := label(amount_text, 24)
	l.name = "Amount"
	row.add_child(l)
	return p


## A progress bar with centered text such as "12 / 20".
static func progress(ratio: float, text: String, fill := BLUE, height := 30) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = clampf(ratio, 0.0, 1.0)
	bar.custom_minimum_size = Vector2(0, height)
	bar.add_theme_stylebox_override("fill", box(fill, 8))
	var l := label(text, int(height * 0.7), TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.add_theme_constant_override("outline_size", 5)
	bar.add_child(l)
	return bar


## Calls `callback` when the control is tapped. Drags (for scrolling) don't
## count as taps. The control passes input on so a ScrollContainer it sits
## in can still scroll.
static func on_tap(control: Control, callback: Callable) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_PASS
	var press := {"position": Vector2.ZERO, "down": false}
	control.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				press.position = event.global_position
				press.down = true
			elif press.down:
				press.down = false
				if event.global_position.distance_to(press.position) < 24.0:
					Sound.play("select")
					callback.call()
	)


## A tinted icon from res://art/icons/ as a plain control.
static func icon_rect(icon_name: String, tint: Color, side: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = icon(icon_name)
	rect.modulate = tint
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(side, side)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Loads (once) an icon from res://art/icons/.
static func icon(icon_name: String) -> Texture2D:
	if icon_name == "":
		return null
	if not _icons.has(icon_name):
		var path := "res://art/icons/%s.svg" % icon_name
		_icons[icon_name] = load(path) if ResourceLoader.exists(path) else null
	return _icons[icon_name]


## The rounded body font (Nunito, bold) used for longer text.
static func body_font() -> Font:
	if _body_font == null:
		_body_font = FontVariation.new()
		_body_font.base_font = BODY_FONT
		_body_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 750}
	return _body_font


## Card art for an animal or tool: its icon on a habitat-colored background.
static func card_art(card_id: String, art_shape := IconArt.Shape.ROUNDED) -> IconArt:
	var card := GameData.get_card(card_id)
	var art := IconArt.make(GameData.card_icon(card_id), habitat_color(card), art_shape)
	art.flip_icon = GameData.card_icon_flipped(card_id)
	art.text = initials(card.get("name", "?"))
	art.portrait = UnitSprites.portrait(card_id)
	return art


## Two or three letters standing in for animal art: "Red Fox" -> "RF".
static func initials(name: String) -> String:
	var words := name.replace("-", " ").split(" ", false)
	if words.size() == 1:
		return words[0].left(2).to_upper()
	return (words[0].left(1) + words[words.size() - 1].left(1)).to_upper()


static func habitat_color(animal: Dictionary) -> Color:
	for tag in animal.get("tags", []):
		if HABITAT_COLORS.has(tag):
			return HABITAT_COLORS[tag]
	return GREY


static func format_number(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out


## "2h 59m", "4m 10s" or "45s".
static func format_duration(seconds: float) -> String:
	var total := maxi(0, ceili(seconds))
	var hours := floori(total / 3600.0)
	var minutes := floori((total % 3600) / 60.0)
	var secs := total % 60
	if hours > 0:
		return "%dh %dm" % [hours, minutes]
	if minutes > 0:
		return "%dm %ds" % [minutes, secs]
	return "%ds" % secs


## A toast for "can't do that" moments, with an error sound.
static func error_toast(text: String) -> void:
	Sound.play("error")
	toast(text, RED.darkened(0.35))


## A short message that floats at the top of the screen, then fades.
static func toast(text: String, color := PANEL_DARK) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var layer := tree.get_first_node_in_group("popup_layer") as Control
	if layer == null:
		layer = tree.current_scene as Control
	var p := panel(color, 16, 16)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := paragraph(text, 24, TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.set_anchors_preset(Control.PRESET_CENTER_TOP)
	p.custom_minimum_size = Vector2(560, 0)
	layer.add_child(p)
	p.position = Vector2((layer.size.x - 560) / 2.0, 140)
	var tween := p.create_tween()
	tween.tween_interval(1.8)
	tween.tween_property(p, "modulate:a", 0.0, 0.4)
	tween.tween_callback(p.queue_free)
