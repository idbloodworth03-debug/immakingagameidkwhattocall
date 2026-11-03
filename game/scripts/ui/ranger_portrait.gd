class_name RangerPortrait
extends Control
## A Rival Ranger's portrait, drawn in code from the "look" in rivals.json:
## a cartoon head and shoulders on their banner colors, lit from the top
## left with a cool rim light on the right, and outlines in a dark shade of
## each part's own color (like the animals). A placeholder until there is
## painted art.
##
## `mood` changes the face: "normal" (their own look), "happy" or "sad".
##
## The drawing is about fifty shapes, so each portrait (per look, mood and
## size) is drawn once into a texture at twice its size and reused: one
## draw call a frame instead of fifty, and still crisp on a 3x screen.

const SKIN_SHADE := 0.17
const OUTLINE := 2.6
const RIM := Color("#b9e2ff")
const MOUTH := Color("#5a1620")
const TONGUE := Color("#ff7a8a")
const BLUSH := Color("#ff6f7d")

var look: Dictionary = {}
var banner_id := ""
var background := true
var mood := "normal":
	set(value):
		mood = value
		queue_redraw()
## Draw from the shared texture (false: draw the shapes, e.g. into it).
var cached := true

## Rendered portraits: key -> {"viewport", "ready"}.
static var _cache: Dictionary = {}
static var _waiting: Array = []


static func create(rival: Dictionary, side := 120.0) -> RangerPortrait:
	var portrait := RangerPortrait.new()
	portrait.look = rival.get("look", {})
	portrait.banner_id = rival.get("banner", "")
	portrait.custom_minimum_size = Vector2(side, side)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return portrait


func _ready() -> void:
	resized.connect(_on_resized)
	_on_resized()


func _on_resized() -> void:
	pivot_offset = size / 2.0
	queue_redraw()


# --- The shared texture ---------------------------------------------------------

## This portrait's texture, or null until it has been drawn (then this
## portrait redraws itself).
func _texture(side: float) -> Texture2D:
	var px := int(ceilf(side * 2.0 / 32.0) * 32.0)
	var key := "%s|%s|%s|%s|%d" % [str(look), banner_id, mood, background, px]
	if not _cache.has(key):
		var holder := get_tree().root if is_inside_tree() else null
		if holder == null:
			return null
		var viewport := SubViewport.new()
		viewport.size = Vector2i(px, px)
		viewport.transparent_bg = true
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		var painter := RangerPortrait.new()
		painter.cached = false
		painter.look = look
		painter.banner_id = banner_id
		painter.mood = mood
		painter.background = background
		painter.size = Vector2(px, px)
		viewport.add_child(painter)
		holder.add_child.call_deferred(viewport)
		var entry := {"viewport": viewport, "ready": false}
		_cache[key] = entry
		# It's added at the end of this frame and drawn during the next one.
		_after_frames(entry, 2)
	var found: Dictionary = _cache[key]
	if not bool(found.ready):
		if not _waiting.has(self):
			_waiting.append(self)
		return null
	return (found.viewport as SubViewport).get_texture()


static func _after_frames(entry: Dictionary, frames: int) -> void:
	RenderingServer.frame_post_draw.connect(func() -> void:
		if frames > 1:
			_after_frames(entry, frames - 1)
			return
		entry.ready = true
		for waiting in _waiting:
			if is_instance_valid(waiting):
				(waiting as CanvasItem).queue_redraw()
		_waiting.clear()
	, CONNECT_ONE_SHOT)


# --- Drawing ---------------------------------------------------------------
# Everything is laid out on a 100 x 100 canvas, scaled to fit.

func _draw() -> void:
	var side := minf(size.x, size.y)
	if side <= 0.0:
		return
	# Headless runs (tests, tools) have no real renderer to draw into.
	if cached and DisplayServer.get_name() != "headless":
		var texture := _texture(side)
		if texture != null:
			draw_texture_rect(texture, Rect2((size - Vector2(side, side)) / 2.0, Vector2(side, side)), false)
			return
	draw_set_transform((size - Vector2(side, side)) / 2.0, 0.0, Vector2(side, side) / 100.0)
	var skin := Color(look.get("skin", "#f1c7a0"))
	var hair := Color(look.get("hair", "#5a3a1e"))
	var shirt := Color(look.get("shirt", "#3b8ff0"))
	var hat_color := Color(look.get("hat_color", "#3b8ff0"))
	var clip := _ellipse(Vector2(50, 50), 46.5, 46.5)

	if background:
		var banner := GameData.find_by_id(GameData.banners, banner_id)
		var colors: Array = banner.get("colors", ["#1e4f96", "#3277c9"])
		draw_circle(Vector2(50, 50), 49.0, UIKit.INK)
		draw_colored_polygon(clip, Color(colors[0]))
		draw_colored_polygon(_ellipse(Vector2(42, 38), 34, 32), Color(colors[1], 0.5))
		draw_colored_polygon(_ellipse(Vector2(36, 28), 16, 12), Color(1, 1, 1, 0.12))

	var style: String = look.get("hair_style", "short")
	if style == "long":
		_shape(_clipped(_ellipse(Vector2(50, 60), 31, 33), clip), hair)
	if style == "ponytail":
		_shape(_ellipse(Vector2(78, 50), 8, 17), hair)

	# Shoulders and neck.
	_shape(_clipped(_ellipse(Vector2(50, 106), 39, 30), clip), shirt, shirt.darkened(0.15))
	_shape(_rect(43, 64, 14, 15), skin.darkened(SKIN_SHADE))
	if look.get("extra", "none") == "scarf":
		var scarf := hat_color if look.get("hat", "none") != "none" else Color("#ec4b52")
		_shape(_rect(56, 76, 8, 16), scarf.darkened(0.1))
		_shape(_ellipse(Vector2(50, 77), 17, 6), scarf)

	# Ears, then the head: shaded, with the lit part toward the top left.
	for x in [25.5, 74.5]:
		_shape(_ellipse(Vector2(x, 50), 5.5, 6.5), skin.darkened(0.08))
	var head := _ellipse(Vector2(50, 47), 25, 27)
	_shape(head, skin, skin.darkened(SKIN_SHADE), Vector2(-3, -3))
	_rim(Vector2(50, 47), 25, 27, -1.0, 0.9)
	draw_colored_polygon(_ellipse(Vector2(36, 58), 4.6, 3.4), Color(BLUSH, 0.32))
	draw_colored_polygon(_ellipse(Vector2(64, 58), 4.6, 3.4), Color(BLUSH, 0.32))
	if look.get("extra", "none") == "freckles":
		for dot in [Vector2(33, 56), Vector2(37, 59), Vector2(35, 54.5), Vector2(63, 56), Vector2(67, 59), Vector2(65, 54.5)]:
			draw_circle(dot, 0.9, skin.darkened(0.35))

	_hair(style, hair, clip)
	_face(skin, hair)
	_hat(look.get("hat", "none"), hat_color)
	if look.get("extra", "none") == "glasses":
		for x in [40.0, 60.0]:
			draw_colored_polygon(_ellipse(Vector2(x, 50), 8, 7.5), Color(1, 1, 1, 0.16))
			draw_polyline(_closed(_ellipse(Vector2(x, 50), 8, 7.5)), UIKit.INK, 2.2, true)
		draw_line(Vector2(48, 49), Vector2(52, 49), UIKit.INK, 2.2, true)

	if background:
		draw_arc(Vector2(50, 50), 47.5, 0.0, TAU, 64, UIKit.INK, 3.0, true)


func _hair(style: String, hair: Color, clip: PackedVector2Array) -> void:
	if style == "bald":
		draw_colored_polygon(_ellipse(Vector2(41, 27), 7, 3.5), Color(1, 1, 1, 0.35))
		return
	# A cap of hair over the top of the head, down to a bumpy hairline.
	var hairline := PackedVector2Array([Vector2(5, 0), Vector2(95, 0), Vector2(95, 50), Vector2(77, 41), Vector2(68, 33), Vector2(58, 37), Vector2(48, 32), Vector2(38, 37), Vector2(28, 40), Vector2(5, 50)])
	var shape := _clipped(_ellipse(Vector2(50, 45), 27.5, 29.5), hairline)
	match style:
		"spiky":
			shape = _merged(shape, PackedVector2Array([Vector2(26, 34), Vector2(27, 15), Vector2(37, 24), Vector2(42, 7), Vector2(51, 21), Vector2(60, 8), Vector2(64, 24), Vector2(74, 15), Vector2(75, 34)]))
		"bun":
			shape = _merged(shape, _ellipse(Vector2(50, 17), 10, 9))
		"curly":
			for i in 9:
				var angle := lerpf(PI * 1.05, PI * 1.95, i / 8.0)
				shape = _merged(shape, _ellipse(Vector2(50, 45) + Vector2(cos(angle) * 26.0, sin(angle) * 27.0), 7.5, 7.5))
		"long":
			shape = _merged(shape, PackedVector2Array([Vector2(23, 40), Vector2(30, 40), Vector2(28, 66), Vector2(21, 70)]))
			shape = _merged(shape, PackedVector2Array([Vector2(77, 40), Vector2(70, 40), Vector2(72, 66), Vector2(79, 70)]))
	_shape(shape, hair, hair.darkened(0.2), Vector2(-2, -3))
	draw_colored_polygon(_ellipse(Vector2(40, 24), 8, 3), Color(1, 1, 1, 0.22))


func _face(skin: Color, hair: Color) -> void:
	var eyes: String = look.get("eyes", "happy")
	var mouth: String = look.get("mouth", "smile")
	if mood == "happy":
		eyes = "happy"
		mouth = "grin"
	elif mood == "sad":
		eyes = "sad"
		mouth = "frown"
	var brow := hair.darkened(0.25)
	for side in [-1.0, 1.0]:
		var c := Vector2(50 + side * 10.0, 50)
		match eyes:
			"happy":
				draw_arc(c + Vector2(0, 2), 5.0, PI + 0.25, TAU - 0.25, 12, UIKit.INK, 2.8, true)
				draw_line(c + Vector2(-5 * side, -9), c + Vector2(4.5 * side, -10), brow, 3.0, true)
			"wide":
				_eye(c, 6.2, 7.2, Vector2(0, 0.8), 3.6)
				draw_arc(c + Vector2(0, -6), 7.5, PI + 0.6, TAU - 0.6, 10, brow, 3.0, true)
			"sly":
				_eye(c, 6.0, 5.0, Vector2(2.2, 1.0), 3.0)
				_lid(c, 6.0, 5.0, 0.0, skin)
				var raised := 2.5 if side > 0 else 0.0
				draw_line(c + Vector2(-5.5 * side, -8 - raised), c + Vector2(5 * side, -7 - raised), brow, 3.0, true)
			"determined":
				_eye(c, 5.6, 6.0, Vector2(0, 0.5), 3.2)
				_lid(c, 5.6, 6.0, 0.35 * side, skin)
				draw_line(c + Vector2(-6.5 * side, -10), c + Vector2(5 * side, -6.5), brow, 3.4, true)
			"sleepy":
				_eye(c, 5.6, 5.2, Vector2(0, 1.5), 3.0)
				_lid(c, 5.6, 5.2, 0.0, skin, 1.5)
				draw_line(c + Vector2(-5 * side, -9), c + Vector2(5 * side, -9), brow, 2.8, true)
			"sad":
				_eye(c, 5.6, 6.4, Vector2(0, 2.0), 3.2)
				draw_line(c + Vector2(-5.5 * side, -7), c + Vector2(5 * side, -10), brow, 3.0, true)
	# Nose.
	draw_colored_polygon(_ellipse(Vector2(50, 56), 3.2, 2.5), skin.darkened(0.2))
	draw_circle(Vector2(49, 55.2), 0.9, Color(1, 1, 1, 0.45))
	match mouth:
		"grin":
			var grin := _ellipse(Vector2(50, 61), 9.5, 8.0, 18, 0.0, PI)
			draw_colored_polygon(grin, MOUTH)
			draw_colored_polygon(_clipped(_ellipse(Vector2(50, 70), 5, 3.5), grin), TONGUE)
			draw_colored_polygon(_clipped(_rect(40, 61, 20, 2.6), grin), Color.WHITE)
			draw_polyline(_closed(grin), UIKit.INK, 2.4, true)
		"smile":
			draw_arc(Vector2(50, 57), 8.5, 0.45, PI - 0.45, 14, UIKit.INK, 2.8, true)
		"smirk":
			draw_arc(Vector2(52, 58), 8.0, 0.25, 1.75, 12, UIKit.INK, 2.8, true)
			draw_line(Vector2(43, 64), Vector2(49.5, 66), UIKit.INK, 2.8, true)
		"open":
			var open := _ellipse(Vector2(50, 64.5), 4.6, 5.2)
			draw_colored_polygon(open, MOUTH)
			draw_colored_polygon(_clipped(_ellipse(Vector2(50, 69), 3.5, 2.5), open), TONGUE)
			draw_polyline(_closed(open), UIKit.INK, 2.4, true)
		"frown":
			draw_arc(Vector2(50, 72), 8.0, PI + 0.55, TAU - 0.55, 12, UIKit.INK, 2.8, true)
		_:
			draw_line(Vector2(44, 64), Vector2(56, 64), UIKit.INK, 2.8, true)
	if look.get("extra", "none") == "mustache":
		var stache := _merged(_ellipse(Vector2(44.5, 61), 6.5, 3.2), _ellipse(Vector2(55.5, 61), 6.5, 3.2))
		_shape(stache, hair, hair.darkened(0.2), Vector2(0, -1))


func _eye(c: Vector2, rx: float, ry: float, look_at: Vector2, pupil: float) -> void:
	var white := _ellipse(c, rx, ry)
	draw_colored_polygon(white, Color.WHITE)
	draw_circle(c + look_at, pupil, UIKit.INK)
	draw_circle(c + look_at + Vector2(-1.2, -1.3), pupil * 0.36, Color.WHITE)
	draw_polyline(_closed(white), UIKit.INK, 2.0, true)


## A skin-colored eyelid over the top of an eye, tilted by `tilt` (radians),
## lowered by `drop`.
func _lid(c: Vector2, rx: float, ry: float, tilt: float, skin: Color, drop := 0.0) -> void:
	var edge := Vector2(cos(tilt), sin(tilt))
	var middle := c + Vector2(0, -ry * 0.25 + drop)
	var a := middle - edge * (rx + 2.0)
	var b := middle + edge * (rx + 2.0)
	var lid := _clipped(_ellipse(c, rx + 0.8, ry + 0.8), PackedVector2Array([a, a + Vector2(0, -20), b + Vector2(0, -20), b]))
	if lid.is_empty():
		return
	draw_colored_polygon(lid, skin.darkened(0.06))
	draw_line(a + edge * 1.8, b - edge * 1.8, UIKit.INK, 2.4, true)


func _hat(hat: String, color: Color) -> void:
	var band := color.darkened(0.3)
	match hat:
		"cap":
			_shape(_clipped(_ellipse(Vector2(50, 33), 27, 17), _rect(0, 0, 100, 34)), color, color.darkened(0.18), Vector2(-3, -2))
			_shape(_ellipse(Vector2(50, 34), 29, 6, 20, 0.0, PI), color.darkened(0.25))
			draw_circle(Vector2(50, 16.5), 2.4, color.lightened(0.3))
		"beanie":
			_shape(_clipped(_ellipse(Vector2(50, 35), 28, 21), _rect(0, 0, 100, 35)), color, color.darkened(0.18), Vector2(-3, -2))
			_shape(_rect(22, 29, 56, 9), band)
			for x in [30.0, 40.0, 50.0, 60.0, 70.0]:
				draw_line(Vector2(x, 30.5), Vector2(x, 36.5), band.darkened(0.25), 1.6, true)
			_shape(_ellipse(Vector2(50, 13), 6, 6), color.lightened(0.55))
		"bandana":
			_shape(_clipped(_ellipse(Vector2(50, 47), 27, 29), _rect(0, 30, 100, 9)), color)
			_shape(PackedVector2Array([Vector2(75, 34), Vector2(88, 27), Vector2(86, 39)]), color.darkened(0.15))
			_shape(PackedVector2Array([Vector2(75, 36), Vector2(90, 42), Vector2(83, 49)]), color.darkened(0.15))
			for dot in [Vector2(32, 34.5), Vector2(44, 34.5), Vector2(56, 34.5), Vector2(68, 34.5)]:
				draw_circle(dot, 1.3, Color(1, 1, 1, 0.8))
		"safari":
			_shape(_ellipse(Vector2(50, 33), 40, 8), color.darkened(0.12))
			_shape(_clipped(_ellipse(Vector2(50, 30), 23, 17), _rect(0, 0, 100, 32)), color, color.darkened(0.15), Vector2(-3, -2))
			_shape(_rect(27.5, 25, 45, 5), band)
		"ranger":
			_shape(_ellipse(Vector2(50, 32), 42, 7), color.darkened(0.12))
			_shape(PackedVector2Array([Vector2(30, 31), Vector2(35, 15), Vector2(44, 9), Vector2(50, 15), Vector2(56, 9), Vector2(65, 15), Vector2(70, 31)]), color, color.darkened(0.15), Vector2(-2, -2))
			_shape(_rect(31, 25.5, 38, 5), band)
		"crown":
			_shape(PackedVector2Array([Vector2(27, 33), Vector2(27, 16), Vector2(36, 24), Vector2(43, 9), Vector2(50, 22), Vector2(57, 9), Vector2(64, 24), Vector2(73, 16), Vector2(73, 33)]), color, color.darkened(0.2), Vector2(-2, -2))
			for jewel in [[Vector2(38, 28.5), Color("#ec4b52")], [Vector2(50, 28.5), Color("#3b8ff0")], [Vector2(62, 28.5), Color("#45c35a")]]:
				draw_circle(jewel[0], 2.6, jewel[1])
				draw_circle(jewel[0] + Vector2(-0.8, -0.8), 0.9, Color(1, 1, 1, 0.7))


## Fills `points` with a light part toward the top left (`light_shift` moves
## the lit copy; zero for a flat fill), a cool rim on the right, and an
## outline in a dark shade of the color.
func _shape(points: PackedVector2Array, color: Color, shade := Color(0, 0, 0, 0), light_shift := Vector2.ZERO) -> void:
	if points.size() < 3:
		return
	if shade.a > 0.0:
		draw_colored_polygon(points, shade)
		var lit := PackedVector2Array()
		for p in points:
			lit.append(p + light_shift)
		for part in Geometry2D.intersect_polygons(points, lit):
			draw_colored_polygon(part, color)
	else:
		draw_colored_polygon(points, color)
	draw_polyline(_closed(points), _outline(color), OUTLINE, true)


func _rim(center: Vector2, rx: float, ry: float, from: float, to: float) -> void:
	var arc := _ellipse(center + Vector2(-1.6, 0), rx - 1.2, ry - 1.2, 16, from, to)
	draw_polyline(arc, Color(RIM, 0.55), 2.2, true)


static func _outline(color: Color) -> Color:
	return color.darkened(0.62).lerp(UIKit.INK, 0.35)


static func _ellipse(center: Vector2, rx: float, ry: float, steps := 36, from := 0.0, to := TAU) -> PackedVector2Array:
	var points := PackedVector2Array()
	var full := is_equal_approx(to - from, TAU)
	var count := steps if full else steps + 1
	for i in count:
		var angle := lerpf(from, to, float(i) / steps)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return points


static func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var loop := points.duplicate()
	if not loop.is_empty():
		loop.append(points[0])
	return loop


## The part of `a` inside `b` (the biggest piece, if it splits).
static func _clipped(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	return _biggest(Geometry2D.intersect_polygons(a, b))


## `a` and `b` together (the outline; any holes are dropped).
static func _merged(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	return _biggest(Geometry2D.merge_polygons(a, b))


static func _biggest(parts: Array) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_area := -1.0
	for part in parts:
		var area := absf(_area(part))
		if area > best_area:
			best = part
			best_area = area
	return best


static func _area(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		total += a.x * b.y - b.x * a.y
	return total / 2.0
