class_name UIKit
extends RefCounted
## Shared colors, the menu theme and small helpers that build styled controls
## in code. Every screen uses these so the whole game looks consistent: most
## of the look can change in this one file.
##
## The style is "Ranger Camp", as in a match (docs/ART_DIRECTION.md): the
## same painted pieces drawn by tools/make_ui_art.py (SkinBox): wooden panels
## with a lip and a soft shadow (KitBox), glossy painted buttons with a
## pressable edge, sunken dark-wood wells for lists, wooden chips for
## amounts, trail-sign planks for headings, and bold outlined text.

## The palette lives in data/ui_style.json ("kit_*"), like every color.
## The menus' backdrop, top and bottom (a summer sky to sunshine).
static var BG_TOP: Color:
	get: return UIStyle.color("kit_bg_top")
static var BG_BOTTOM: Color:
	get: return UIStyle.color("kit_bg_bottom")
## Panels: painted wood (raised()), darker wood for wells and slots, light wood for highlights.
static var PANEL: Color:
	get: return UIStyle.color("kit_panel")
static var PANEL_DARK: Color:
	get: return UIStyle.color("kit_panel_dark")
static var PANEL_LIGHT: Color:
	get: return UIStyle.color("kit_panel_light")
## The dark brown used for outlines and shadows instead of plain black.
static var INK: Color:
	get: return UIStyle.color("kit_ink")
static var TEXT: Color:
	get: return UIStyle.color("kit_text")
## Secondary text: a solid, warm cream (outlined, so it reads on wood and sky).
static var TEXT_DIM: Color:
	get: return UIStyle.color("kit_text_dim")
## Solid dark wood for tracks, pills, fields and bars.
static var DEEP: Color:
	get: return UIStyle.color("kit_deep")
static var GOLD: Color:
	get: return UIStyle.color("kit_gold")
static var GEMS: Color:
	get: return UIStyle.color("kit_gems")
static var ENERGY: Color:
	get: return UIStyle.color("kit_energy")
static var YELLOW: Color:
	get: return UIStyle.color("kit_yellow")
static var GREEN: Color:
	get: return UIStyle.color("kit_green")
static var BLUE: Color:
	get: return UIStyle.color("kit_blue")
static var RED: Color:
	get: return UIStyle.color("kit_red")
## Solid muted gray: disabled, bought, owned, off.
static var GREY: Color:
	get: return UIStyle.color("kit_grey")
static var TROPHY: Color:
	get: return UIStyle.color("kit_trophy")
static var ACORN: Color:
	get: return UIStyle.color("kit_acorn")
static var HEART: Color:
	get: return UIStyle.color("kit_heart")

const DISPLAY_FONT := preload("res://art/fonts/LilitaOne-Regular.ttf")
const BODY_FONT := preload("res://art/fonts/Nunito.ttf")



static var _icons := {}
static var _body_font: FontVariation


static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = DISPLAY_FONT
	theme.default_font_size = 24

	# Chunky outlined text with a drop shadow, like most mobile card games.
	for type in ["Label", "Button", "LineEdit"]:
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_outline_color", type, INK)
		theme.set_constant("outline_size", type, 7)
		theme.set_color("font_shadow_color", type, Color(INK, 0.5))
		theme.set_constant("shadow_offset_x", type, 0)
		theme.set_constant("shadow_offset_y", type, 3)
		theme.set_constant("shadow_outline_size", type, 7)
	# Disabled: a solid gray button with clear light text (it lights up in
	# its color when it can be pressed).
	theme.set_color("font_disabled_color", "Button", Color("#eef2f8"))
	theme.set_color("font_hover_color", "Button", TEXT)
	theme.set_color("font_pressed_color", "Button", TEXT)
	theme.set_color("font_focus_color", "Button", TEXT)
	theme.set_color("font_hover_pressed_color", "Button", TEXT)

	theme.set_stylebox("normal", "Button", chunky(BLUE))
	theme.set_stylebox("hover", "Button", chunky(BLUE.lightened(0.08)))
	theme.set_stylebox("pressed", "Button", chunky(BLUE.darkened(0.1), true))
	theme.set_stylebox("disabled", "Button", chunky(GREY))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())

	theme.set_stylebox("panel", "PanelContainer", raised(PANEL, 18, 14))
	theme.set_stylebox("panel", "Panel", raised(PANEL, 18))

	var field := inset(DEEP, 14, 12)
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", field)

	theme.set_stylebox("background", "ProgressBar", bar_track(10))
	theme.set_stylebox("fill", "ProgressBar", bar_fill(BLUE, 10))

	# Thin, rounded scroll bars.
	var grabber := box(PANEL_LIGHT, 6)
	grabber.content_margin_left = 6
	grabber.content_margin_right = 6
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	theme.set_stylebox("grabber_pressed", "VScrollBar", box(PANEL_LIGHT.lightened(0.2), 6))
	theme.set_stylebox("scroll", "VScrollBar", box(DEEP, 6))
	return theme


## A rounded rectangle style.
static func box(color: Color, radius := 16, padding := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	style.anti_aliasing = true
	return style


## A raised panel: painted wood in `color` with a thick dark outline, a
## lip along the bottom and a soft shadow underneath (a KitBox; a short one
## is drawn as a chip). `padding` is the room inside its outline.
static func raised(color: Color, _radius := 18, padding := 14) -> KitBox:
	var style := KitBox.new()
	style.bg_color = color
	var edge := UIStyle.num("kit", "edge", 3.0)
	style.content_margin_left = padding + edge
	style.content_margin_right = padding + edge
	style.content_margin_top = padding + edge
	style.content_margin_bottom = padding + edge + UIStyle.num("kit", "lip", 6.0)
	return style


## A sunken area inside a panel (lists, stat boxes): a well of darker wood.
static func inset(color := PANEL_DARK, _radius := 14, padding := 12) -> KitBox:
	var style := KitBox.new()
	style.sunken = true
	style.bg_color = color.darkened(UIStyle.num("kit", "well_dark", 0.12))
	style.set_content_margin_all(padding + UIStyle.num("kit", "edge", 3.0))
	return style


## The track of a progress bar: a slot of dark wood with a dark outline.
static func bar_track(radius := 10) -> StyleBoxFlat:
	var style := box(DEEP, radius)
	style.set_border_width_all(3)
	style.border_color = INK
	return style


## The filled part of a progress bar: the color with a bright line on top.
static func bar_fill(color: Color, radius := 10) -> StyleBoxFlat:
	var style := box(color, radius)
	style.border_width_top = 3
	style.border_color = color.lightened(0.35)
	return style


## A plain button face in `color` (for buttons not made with button()): the
## painted button piece, sunk onto its edge when `pressed`.
static func chunky(color: Color, pressed := false) -> SkinBox:
	var style := SkinBox.make("button_pressed" if pressed else "button", color)
	var lip := UIStyle.num("button", "lip", 8.0)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8 + (lip - 2.0 if pressed else 0.0)
	style.content_margin_bottom = 8 + (2.0 if pressed else lip)
	return style


## A chunky game button (see ButtonSkin) that squashes a little when
## pressed and clicks.
static func button(text: String, color := BLUE, font_size := 26, min_size := Vector2(0, 72)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	var edge := ButtonSkin.edge_for(min_size.y if min_size.y > 0 else 72.0)
	for state in ["normal", "hover", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, _text_margins(edge, false))
	b.add_theme_stylebox_override("pressed", _text_margins(edge, true))
	b.add_theme_stylebox_override("hover_pressed", _text_margins(edge, true))
	ButtonSkin.attach(b, color)
	b.resized.connect(func() -> void: b.pivot_offset = b.size / 2.0)
	b.button_down.connect(func() -> void: press_squash(b))
	b.button_up.connect(func() -> void: release_bounce(b))
	b.pressed.connect(func() -> void: Sound.play("tap"))
	return b


## Fades a screen in from dark when it opens, so changing screens is smooth.
static func fade_in(screen: Control, seconds := 0.25) -> void:
	var cover := ColorRect.new()
	cover.color = INK
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(cover)
	var tween := cover.create_tween()
	tween.tween_property(cover, "modulate:a", 0.0, seconds)
	tween.tween_callback(cover.queue_free)


## A dark pill holding a control, for scores and clocks over the battle.
static func hud_pill(content: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var style := box(DEEP, 18, 4)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.set_border_width_all(3)
	style.border_color = INK
	p.add_theme_stylebox_override("panel", style)
	p.add_child(content)
	return p


## A buy button: the price next to a toy coin or gem (MenuArt).
static func price_button(price_text: String, icon_key: String, color := GREEN, font_size := 22, min_size := Vector2(0, 62)) -> Button:
	var b := button(price_text, color, font_size, min_size)
	b.icon = MenuArt.icon_texture(GameData.ui_icon(icon_key))
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", int(font_size * 1.7))
	b.add_theme_constant_override("h_separation", 6)
	return b


## A round button with an icon instead of text, e.g. the X that closes a popup.
static func icon_button(icon_key: String, color := RED, side := 60) -> Button:
	var b := button("", color, 20, Vector2(side, side))
	b.icon = icon(GameData.ui_icon(icon_key))
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", int(side * 0.48))
	return b


## Where a skinned button's text sits: on the face, which sinks when pressed.
static func _text_margins(edge: float, pressed: bool) -> StyleBoxEmpty:
	var style := StyleBoxEmpty.new()
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 6 + (edge - 2 if pressed else 0.0)
	style.content_margin_bottom = 6 + (2.0 if pressed else edge)
	return style


static func _squash(control: Control, amount: float) -> void:
	control.create_tween().tween_property(control, "scale", Vector2(amount, amount), 0.07)


## Squashes a control down while it's held (wider than tall, like a
## cushion), from data/feel.json ("ui").
static func press_squash(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	var amount := Feel.num("ui", "press_scale", 0.9)
	# Big panels squash less than buttons and cards.
	amount = 1.0 - (1.0 - amount) * clampf(140.0 / maxf(control.size.y, 1.0), 0.2, 1.0)
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2(amount + (1.0 - amount) * 0.4, amount), 0.06).set_ease(Tween.EASE_OUT)


## Springs a control back past full size and settles, on release.
static func release_bounce(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	var over := Feel.num("ui", "release_overshoot", 1.07)
	over = 1.0 + (over - 1.0) * clampf(140.0 / maxf(control.size.y, 1.0), 0.2, 1.0)
	var seconds := Feel.num("ui", "release_seconds", 0.28)
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2(over, over), seconds * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, seconds * 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Pops a control in: from small and see-through to full size, overshooting.
static func pop_in(control: Control, from_scale := 0.85, seconds := 0.3) -> void:
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2(from_scale, from_scale)
	control.modulate.a = 0.0
	var tween := control.create_tween().set_parallel()
	tween.tween_property(control, "scale", Vector2.ONE, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, seconds * 0.5)


static func color_button(b: Button, color: Color) -> void:
	for child in b.get_children():
		if child is ButtonSkin:
			child.color = color
			return
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


## A label that wraps onto several lines, in the rounded body font.
static func paragraph(text: String, font_size := 22, color := TEXT_DIM) -> Label:
	var l := label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", body_font())
	# A thinner outline than the titles' (it reads on wood and on the sky
	# alike), and no drop shadow.
	l.add_theme_constant_override("outline_size", maxi(4, roundi(font_size * UIStyle.num("kit", "body_outline", 0.2))))
	l.add_theme_constant_override("shadow_outline_size", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_color_override("font_shadow_color", Color(INK, 0.0))
	l.custom_minimum_size.x = 100
	return l


## A panel. Solid colors get the raised look; see-through ones stay flat.
static func panel(color := PANEL, padding := 14, radius := 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", raised(color, radius, padding) if color.a >= 0.99 else box(color, radius, padding))
	return p


## A sunken panel for lists and stats inside another panel.
static func well(padding := 12, radius := 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", inset(PANEL_DARK, radius, padding))
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


## A section heading: the title on a wooden trail-sign plank, then a line
## fading out.
static func heading(text: String) -> Control:
	var row := hbox(10)
	var plank := PanelContainer.new()
	plank.add_theme_stylebox_override("panel", UIStyle.sign_box())
	plank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, 30, TEXT)
	plank.add_child(l)
	row.add_child(plank)
	var line := TextureRect.new()
	line.texture = _fade_texture()
	line.modulate = INK
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.custom_minimum_size = Vector2(0, 5)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	return row


static var _fade: GradientTexture2D


static func _fade_texture() -> GradientTexture2D:
	if _fade == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 0.8))
		gradient.set_color(1, Color(1, 1, 1, 0.0))
		_fade = GradientTexture2D.new()
		_fade.gradient = gradient
		_fade.width = 64
		_fade.height = 4
	return _fade


## A chip of dark wood showing an amount (trophies, a reward), with the
## icon on the left. `icon_name` is a file in res://art/icons/ (see
## GameData.ui_icon); the menu's toy props stand in for the ones they
## replace (MenuArt).
static func pill(icon_name: String, icon_color: Color, amount_text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var style := UIStyle.chip_box(DEEP)
	style.content_margin_left = 10
	style.content_margin_right = 18
	p.add_theme_stylebox_override("panel", style)
	var row := hbox(8)
	p.add_child(row)
	row.add_child(MenuArt.icon_or(icon_name, icon_color, 40))
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
	bar.add_theme_stylebox_override("fill", bar_fill(fill, int(height / 3.0)))
	bar.add_theme_stylebox_override("background", bar_track(int(height / 3.0)))
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
				press_squash(control)
			elif press.down:
				press.down = false
				release_bounce(control)
				# The release that ends a hold for info isn't a tap.
				if HoldInfo.just_held():
					return
				if event.global_position.distance_to(press.position) < 24.0:
					Sound.play("select")
					UIFx.tap(event.global_position)
					callback.call()
	)


## Draws `count` gold stars in a row centered on `center` (an animal's stars
## in Draft Duel), each `radius` across, with a dark outline.
static func draw_stars(canvas: CanvasItem, center: Vector2, count: int, radius: float) -> void:
	var gap := radius * 1.9
	for i in count:
		var c := center + Vector2((i - (count - 1) / 2.0) * gap, 0)
		canvas.draw_colored_polygon(_star_points(c, radius + 2.0), INK)
		canvas.draw_colored_polygon(_star_points(c, radius), GOLD)
		canvas.draw_colored_polygon(_star_points(c - Vector2(0, radius * 0.12), radius * 0.45), Color(1, 1, 1, 0.45))


static func _star_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var r := radius if i % 2 == 0 else radius * 0.45
		var angle := -PI / 2.0 + i * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	return points


## A habitat's badge: a round chip in the habitat's color with its icon, a
## dark outline and a little shine. Used on cards, on the field and in the
## synergy tracker.
static func draw_habitat_badge(canvas: CanvasItem, center: Vector2, radius: float, habitat: String, alpha := 1.0) -> void:
	var info: Dictionary = GameData.habitats.get(habitat, {})
	if info.is_empty():
		return
	var color := UIStyle.habitat_color(habitat)
	# The disc is a cell of the particle sheet: one batched draw, not five.
	UIStyle.draw_particle(canvas, "badge", center, radius + 1.5, Color(color, alpha))
	var texture := icon(GameData.ui_icon(String(info.get("icon", ""))))
	if texture != null:
		var side := radius * 1.25
		canvas.draw_texture_rect(texture, Rect2(center - Vector2(side, side) / 2.0, Vector2(side, side)), false, Color(1, 1, 1, alpha))


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


## The color behind a card's picture: its habitat's (ui_style.json
## "habitat_*"); a tool's, the tool color.
static func habitat_color(animal: Dictionary) -> Color:
	if String(animal.get("kind", "")) == "tool":
		return UIStyle.color("tool")
	return UIStyle.habitat_color(String(animal.get("habitat", "")))


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
	toast(text, RED)


## A short message that drops in at the top of the screen, then fades.
static func toast(text: String, color := PANEL_DARK) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var layer := tree.get_first_node_in_group("popup_layer") as Control
	if layer == null:
		layer = tree.current_scene as Control
	var p := PanelContainer.new()
	var style := raised(color, 24, 16)
	style.border_color = color.lightened(0.3)
	style.set_border_width_all(3)
	p.add_theme_stylebox_override("panel", style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, 24, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A fixed width, so the wrapped text knows how tall it is.
	l.custom_minimum_size = Vector2(528, 0)
	p.add_child(l)
	layer.add_child(p)
	p.reset_size()
	var x := (layer.size.x - 560) / 2.0
	p.position = Vector2(x, 100)
	p.modulate.a = 0.0
	var tween := p.create_tween()
	tween.set_parallel()
	tween.tween_property(p, "position:y", 140.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(p, "modulate:a", 1.0, 0.15)
	tween.chain().tween_interval(1.7)
	tween.chain().tween_property(p, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(p.queue_free)
