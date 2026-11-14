class_name KitBox
extends StyleBox
## A menu panel as a painted "Ranger Camp" piece (the SkinBox skins: a
## raised wooden panel, a small chip for a short box, a sunken well), tinted
## with `bg_color`. It takes the few settings the menus set on a panel, so
## UIKit.raised() and inset() hand these out and every menu panel is painted
## wood: a border color with a width of 3 or more draws a bright ring round
## the panel (a cage that's ready, the arena you're in, a picked banner).
## The drop shadow is the skin's own.

var bg_color := Color.WHITE:
	set(value):
		bg_color = value
		emit_changed()
## A well: darker wood, sunk into the panel it sits on.
var sunken := false:
	set(value):
		sunken = value
		emit_changed()
## The ring round the panel, `border_width` pixels wide (under 3: none).
var border_color := Color(0, 0, 0, 0):
	set(value):
		border_color = value
		emit_changed()
var border_width := 0:
	set(value):
		border_width = value
		emit_changed()
## A soft glow in the ring's color behind the panel.
var glow := false:
	set(value):
		glow = value
		emit_changed()
## Which skin to draw ("": a chip for a short box, a panel otherwise, a
## well when sunken).
var skin := ""

var _skins := {}
var _ring: StyleBoxFlat
var _glow: SkinBox


func set_border_width_all(width: int) -> void:
	border_width = width


func _skin_for(rect: Rect2) -> SkinBox:
	var skin_name := skin
	if skin_name == "":
		skin_name = "inset" if sunken else ("chip" if rect.size.y < UIStyle.num("kit", "chip_under", 72.0) else "panel")
	if not _skins.has(skin_name):
		_skins[skin_name] = SkinBox.make(skin_name)
	return _skins[skin_name]


func _draw(item: RID, rect: Rect2) -> void:
	var ringed := border_width >= 3 and border_color.a > 0.0
	if ringed and glow:
		if _glow == null:
			_glow = SkinBox.make("glow")
		_glow.tint = border_color
		_glow._draw(item, rect.grow(UIStyle.num("kit", "glow_grow", 14.0)))
	var box := _skin_for(rect)
	box.tint = bg_color
	box._draw(item, rect)
	if ringed:
		if _ring == null:
			_ring = StyleBoxFlat.new()
			_ring.draw_center = false
			_ring.anti_aliasing = true
		_ring.border_color = border_color
		_ring.set_border_width_all(border_width)
		var radius := UIStyle.radius("chip") if box.skin == "chip" else UIStyle.radius("panel")
		_ring.set_corner_radius_all(int(minf(radius, minf(rect.size.x, rect.size.y) / 2.0)))
		_ring.draw(item, rect)


func _get_draw_rect(rect: Rect2) -> Rect2:
	var box := _skin_for(rect)
	var out := Rect2(rect.position, rect.size + Vector2(0, box.shadow_height()))
	if glow:
		out = out.grow(UIStyle.num("kit", "glow_grow", 14.0))
	return out
