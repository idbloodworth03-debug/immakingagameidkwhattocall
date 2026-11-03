class_name UIStyle
extends RefCounted
## The design system: every color, text size, gap, corner and chunky
## component comes from here, read from data/ui_style.json. Screens build
## their controls with these helpers (or use the shared theme's type
## variations) and never pick their own colors or sizes.
##
## Components:
## - Panels: panel() (the bright main panel), inset() (a sunken well inside
##   one), chip() (a small rounded chip). All ChunkyBox.
## - Buttons: button() makes a ChunkyButton: "primary" (green), "secondary"
##   (blue), "danger" (red), "tool" (purple), "gold" or "disabled".
## - Text: label() with one of four sizes (small, body, large, title), in the
##   display font with a thick outline and a drop shadow; body_text() in the
##   rounded body font.
## - Pills: pill() makes a ValuePill (icon and a number that ticks).
## - Cards: GameCard.
## - Popups: Popup (see popup.gd).

const SIZES := ["small", "body", "large", "title"]
const KINDS := ["primary", "secondary", "danger", "tool", "gold", "disabled"]

static var _theme: Theme
static var _display: Font
static var _body: FontVariation


static func data() -> Dictionary:
	return GameData.ui_style


# --- Values ----------------------------------------------------------------

static func color(key: String) -> Color:
	var value: Variant = data().get("colors", {}).get(key, null)
	if value is String:
		return Color(String(value))
	push_warning("ui_style.json: no color '%s'" % key)
	return Color.MAGENTA


## The lighter top of a gradient made from `base`.
static func top_of(base: Color) -> Color:
	return base.lightened(float(data().get("gradient_light", 0.2)))


## The darker bottom of a gradient made from `base`.
static func bottom_of(base: Color) -> Color:
	return base.darkened(float(data().get("gradient_dark", 0.14)))


## One of the four text sizes: "small", "body", "large" or "title".
static func text_size(key: String) -> int:
	return int(data().get("text_sizes", {}).get(key, 32))


## One of the spacing steps: "xs" (8), "s" (16), "m" (24) or "l" (32).
static func space(key: String) -> int:
	return int(data().get("space", {}).get(key, 16))


static func radius(key: String) -> int:
	return int(data().get("radius", {}).get(key, 20))


static func num(section: String, key: String, fallback := 0.0) -> float:
	return float(data().get(section, {}).get(key, fallback))


static func outline_for(font_size: int) -> int:
	return maxi(4, roundi(font_size * float(data().get("text_outline", 0.24))))


static func shadow_for(font_size: int) -> int:
	return maxi(2, roundi(font_size * float(data().get("text_shadow", 0.12))))


static func rarity_color(rarity: String) -> Color:
	return color("rarity_" + rarity) if data().get("colors", {}).has("rarity_" + rarity) else color("rarity_common")


static func display_font() -> Font:
	if _display == null:
		_display = load(String(data().get("fonts", {}).get("display", "res://art/fonts/LilitaOne-Regular.ttf")))
	return _display


static func body_font() -> Font:
	if _body == null:
		_body = FontVariation.new()
		_body.base_font = load(String(data().get("fonts", {}).get("body", "res://art/fonts/Nunito.ttf")))
		_body.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
	return _body


# --- Boxes -----------------------------------------------------------------

## The main panel: painted wood with a chunky lip and a soft shadow.
static func panel_box(base := Color(0, 0, 0, 0)) -> SkinBox:
	var box := SkinBox.make("panel", base if base.a > 0.0 else color("panel"))
	_pad(box, space("s"), num("panel", "border", 5), num("panel", "lip", 6))
	return box


## A sunken well inside a panel (darker wood).
static func inset_box(base := Color(0, 0, 0, 0)) -> SkinBox:
	var box := SkinBox.make("inset", base if base.a > 0.0 else color("panel_inset"))
	_pad(box, space("xs"), 3.0, 0.0)
	return box


## A small chip (pills, badges, tags): wood, or brass for money (`brass`).
static func chip_box(base := Color(0, 0, 0, 0), brass := false) -> SkinBox:
	var box := SkinBox.make("chip_brass" if brass else "chip", base if base.a > 0.0 else (color("gold") if brass else color("chip")))
	var border := num("chip", "border", 3)
	box.content_margin_left = space("xs") + border
	box.content_margin_right = space("s") + border
	box.content_margin_top = 2 + border
	box.content_margin_bottom = 2 + border + num("chip", "lip", 4)
	return box


## A wooden trail-sign plank, for a panel's title.
static func sign_box() -> SkinBox:
	var box := SkinBox.make("sign", color("sign"))
	box.content_margin_left = space("m") + 8
	box.content_margin_right = space("m") + 8
	box.content_margin_top = 6
	box.content_margin_bottom = 12
	return box


## A button face of `kind` in one state: "normal", "hover", "pressed" or
## "disabled". Painted wood in the kind's color.
static func button_box(kind: String, state := "normal") -> SkinBox:
	var base := color(kind if kind != "disabled" else "disabled")
	if state == "disabled":
		base = color("disabled")
	elif state == "hover":
		base = base.lightened(0.05)
	var box := SkinBox.make("button_pressed" if state == "pressed" else "button", base)
	_pad(box, space("m"), num("button", "border", 4), num("button", "lip", 8))
	return box


static func _pad(box: StyleBox, padding: float, border: float, lip: float) -> void:
	box.content_margin_left = padding + border
	box.content_margin_right = padding + border
	box.content_margin_top = padding + border
	box.content_margin_bottom = padding + border + lip


# --- The theme ---------------------------------------------------------------

## The shared theme every screen uses.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = display_font()
	t.default_font_size = text_size("body")
	var ink := color("outline")
	var shadow := Color(ink, float(data().get("text_shadow_alpha", 0.55)))

	var label_sizes := {"Label": "body", "SmallLabel": "small", "LargeLabel": "large", "TitleLabel": "title"}
	for type in label_sizes:
		if type != "Label":
			t.set_type_variation(type, "Label")
		var px := text_size(label_sizes[type])
		t.set_font_size("font_size", type, px)
		t.set_color("font_color", type, color("text"))
		t.set_color("font_outline_color", type, ink)
		t.set_constant("outline_size", type, outline_for(px))
		t.set_color("font_shadow_color", type, shadow)
		t.set_constant("shadow_offset_x", type, 0)
		t.set_constant("shadow_offset_y", type, shadow_for(px))
		t.set_constant("shadow_outline_size", type, outline_for(px))
	# The rounded body font for the few longer lines.
	t.set_type_variation("BodyText", "Label")
	t.set_font("font", "BodyText", body_font())
	t.set_font_size("font_size", "BodyText", text_size("small"))
	t.set_color("font_color", "BodyText", color("text"))
	t.set_color("font_outline_color", "BodyText", ink)
	t.set_constant("outline_size", "BodyText", 5)
	t.set_color("font_shadow_color", "BodyText", Color(ink, 0.4))
	t.set_constant("shadow_offset_y", "BodyText", 2)
	t.set_constant("shadow_outline_size", "BodyText", 5)

	for kind in KINDS:
		var type: String = kind.capitalize() + "Button"
		t.set_type_variation(type, "Button")
		t.set_stylebox("normal", type, button_box(kind))
		t.set_stylebox("hover", type, button_box(kind, "hover"))
		t.set_stylebox("pressed", type, button_box(kind, "pressed"))
		t.set_stylebox("hover_pressed", type, button_box(kind, "pressed"))
		t.set_stylebox("disabled", type, button_box(kind, "disabled"))
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(state, "Button", t.get_stylebox(state, "SecondaryButton"))
	t.set_font_size("font_size", "Button", text_size("large"))
	t.set_color("font_outline_color", "Button", ink)
	t.set_constant("outline_size", "Button", outline_for(text_size("large")))

	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_type_variation("InsetPanel", "PanelContainer")
	t.set_stylebox("panel", "InsetPanel", inset_box())
	t.set_type_variation("ChipPanel", "PanelContainer")
	t.set_stylebox("panel", "ChipPanel", chip_box())
	t.set_type_variation("BrassPanel", "PanelContainer")
	t.set_stylebox("panel", "BrassPanel", chip_box(Color(0, 0, 0, 0), true))
	t.set_type_variation("SignPanel", "PanelContainer")
	t.set_stylebox("panel", "SignPanel", sign_box())

	# Thin, rounded scroll bars.
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(1, 1, 1, 0.45)
	grabber.set_corner_radius_all(6)
	grabber.content_margin_left = 6
	grabber.content_margin_right = 6
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	t.set_stylebox("grabber_pressed", "VScrollBar", grabber)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(ink, 0.2)
	track.set_corner_radius_all(6)
	t.set_stylebox("scroll", "VScrollBar", track)
	_theme = t
	return t


# --- Components ----------------------------------------------------------------

## Display-font text in one of the four sizes, outlined, with a drop shadow.
static func label(text: String, size_key := "body", tint := Color(0, 0, 0, 0), align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = {"small": "SmallLabel", "body": "", "large": "LargeLabel", "title": "TitleLabel"}.get(size_key, "")
	if tint.a > 0.0:
		l.add_theme_color_override("font_color", tint)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A line or two in the rounded body font (wraps).
static func body_text(text: String, tint := Color(0, 0, 0, 0), align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := label(text, "small", tint, align)
	l.theme_type_variation = "BodyText"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120
	return l


## A chunky button: kind is "primary", "secondary", "danger", "tool", "gold"
## or "disabled" (looks off but can still be tapped, e.g. to say why).
## `icon_key` shows an icon before the text; `cost` >= 0 shows an Acorn
## price after it.
static func button(text: String, kind := "secondary", icon_key := "", cost := -1, size_key := "large") -> ChunkyButton:
	return ChunkyButton.make(text, kind, icon_key, cost, size_key)


## A square icon-only button.
static func icon_button(icon_key: String, kind := "secondary") -> ChunkyButton:
	var b := ChunkyButton.make("", kind, icon_key, -1, "large")
	b.square = true
	return b


static func panel(content: Control = null) -> PanelContainer:
	var p := PanelContainer.new()
	if content != null:
		p.add_child(content)
	return p


static func inset(content: Control = null) -> PanelContainer:
	var p := panel(content)
	p.theme_type_variation = "InsetPanel"
	return p


## A wooden trail sign holding a title, cut short (…) past `widest` pixels.
static func sign(title: String, size_key := "large", widest := 0.0) -> PanelContainer:
	var l := label(title, size_key, Color(0, 0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER)
	if widest > 0.0:
		var px := text_size(size_key)
		var width := display_font().get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + outline_for(px) * 2.0
		if width > widest:
			l.clip_text = true
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			l.custom_minimum_size.x = widest
	var p := panel(l)
	p.theme_type_variation = "SignPanel"
	return p


## A small chip holding `content`, in `base` color (wood by default).
static func chip(content: Control, base := Color(0, 0, 0, 0)) -> PanelContainer:
	var p := panel(content)
	if base.a > 0.0:
		p.add_theme_stylebox_override("panel", chip_box(base))
	else:
		p.theme_type_variation = "ChipPanel"
	return p


## A pill with an icon and a number that ticks up and down (ValuePill).
## `brass` for money: shiny, and its icon catches a glint now and then.
static func pill(icon_key: String, icon_tint: Color, value := 0, brass := false) -> ValuePill:
	return ValuePill.make(icon_key, icon_tint, value, brass)


## Makes a shiny thing (a brass or gold icon) catch a sweeping glint now
## and then (feel.json "ui": glint_seconds).
static func add_glint(item: CanvasItem) -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/fx/glint.gdshader")
	material.set_shader_parameter("period", Feel.num("ui", "glint_seconds", 3.5))
	material.set_shader_parameter("offset", randf() * 10.0)
	item.material = material


## A tinted icon from res://art/icons/ by its art.json "ui" key.
static func icon(icon_key: String, tint := Color.WHITE, side := 40) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = UIKit.icon(GameData.ui_icon(icon_key))
	rect.modulate = tint
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(side, side)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func hbox(gap_key := "xs") -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", space(gap_key))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


static func vbox(gap_key := "xs") -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", space(gap_key))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


## The screen backdrop: a warm summer sky fading to sunshine.
static func backdrop() -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, color("sky"))
	gradient.set_color(1, color("sky_deep"))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 8
	texture.height = 256
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## One cell of the particle sheet (a star, a brass coin, a leaf...) centered
## on `center`, `radius` across its shape, tinted. Cards use these so their
## stars and coins batch with each other.
static func draw_particle(canvas: CanvasItem, kind: String, center: Vector2, radius: float, tint := Color.WHITE) -> void:
	var info: Dictionary = SkinBox.meta().get("particles", {})
	var cell := float(info.get("cell", 128))
	var columns := int(info.get("columns", 4))
	var index := ParticleLayer.cell_of(kind)
	var src := Rect2((index % columns) * cell, floori(index / float(columns)) * cell, cell, cell)
	var side := radius * 2.5
	canvas.draw_texture_rect_region(SkinBox.texture("particles.png"), Rect2(center - Vector2(side, side) / 2.0, Vector2(side, side)), src, tint)


## A gold star with a dark outline, filled or as an empty socket.
static func draw_star(canvas: CanvasItem, center: Vector2, r: float, filled := true, alpha := 1.0) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var angle := -PI / 2.0 + i * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * (r if i % 2 == 0 else r * 0.48))
	var outline := points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(_offset(outline, Vector2(0, r * 0.14)), Color(color("outline"), 0.5 * alpha), r * 0.42, true)
	canvas.draw_polyline(outline, Color(color("outline"), alpha), r * 0.42, true)
	if filled:
		canvas.draw_colored_polygon(points, Color(color("gold"), alpha))
		canvas.draw_colored_polygon(_scaled(points, center, 0.5, Vector2(-r * 0.1, -r * 0.18)), Color(1, 1, 1, 0.45 * alpha))
	else:
		canvas.draw_colored_polygon(points, Color(color("outline"), 0.55 * alpha))


static func _offset(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p + by)
	return out


static func _scaled(points: PackedVector2Array, center: Vector2, k: float, shift: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(center + (p - center) * k + shift)
	return out


## Outlined display-font text centered in `area`, cut to fit (never smaller
## than the small size).
static func draw_text(canvas: CanvasItem, text: String, area: Rect2, size_key := "body", tint := Color.WHITE) -> void:
	var font := display_font()
	var px := text_size(size_key)
	var shown := text
	var width := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	while width > area.size.x and shown.length() > 2:
		shown = shown.substr(0, shown.length() - 2) + "…"
		width = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var baseline := Vector2(area.get_center().x - width / 2.0, area.get_center().y + px * 0.36)
	var outline := outline_for(px)
	canvas.draw_string_outline(font, baseline + Vector2(0, shadow_for(px)), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, px, outline, Color(color("outline"), 0.55))
	canvas.draw_string_outline(font, baseline, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, px, outline, color("outline"))
	canvas.draw_string(font, baseline, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, px, tint)


## How far in from each edge (in game pixels) to keep clear of a notch or
## home bar: {"top", "bottom", "left", "right"}.
static func safe_margins(viewport: Viewport) -> Dictionary:
	var extra := num("screen", "safe_area_extra", 0)
	var out := {"top": extra, "bottom": extra, "left": 0.0, "right": 0.0}
	var window := DisplayServer.window_get_size()
	if window.x <= 0 or window.y <= 0:
		return out
	var k := viewport.get_visible_rect().size.y / float(window.y)
	if OS.has_feature("web"):
		var insets: Variant = JavaScriptBridge.eval("(function(){var d=document.createElement('div');d.style.cssText='position:fixed;visibility:hidden;padding-top:env(safe-area-inset-top);padding-bottom:env(safe-area-inset-bottom)';document.body.appendChild(d);var s=getComputedStyle(d);var r=[parseFloat(s.paddingTop)||0,parseFloat(s.paddingBottom)||0,window.devicePixelRatio||1];d.remove();return r.join(',');})()", true)
		if insets is String:
			var parts := String(insets).split(",")
			if parts.size() == 3:
				var css_to_window := float(parts[2])
				out.top += float(parts[0]) * css_to_window * k
				out.bottom += float(parts[1]) * css_to_window * k
		return out
	if not OS.has_feature("mobile"):
		return out
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if safe.size.x > 0 and screen.y > 0:
		out.top += safe.position.y * k
		out.bottom += maxf(0.0, screen.y - safe.end.y) * k
	return out
