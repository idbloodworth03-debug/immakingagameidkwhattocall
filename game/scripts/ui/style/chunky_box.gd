class_name ChunkyBox
extends StyleBox
## The one chunky look behind every panel, button, chip and pill (see
## UIStyle, which makes these from data/ui_style.json):
## a soft drop shadow, a thick dark outline, a darker lip along the bottom
## (so it looks pressable), a face that goes from lighter at the top to
## darker at the bottom, a bright line along the top edge and an optional
## gloss. `sink` lowers the face onto the lip, for a pressed button.
## `sunken` draws a well instead: darker at the top, with no lip or gloss.

var color := Color("#3a9cf0")
var light := 0.2
var dark := 0.14
var outline := Color("#0f2e5c")
var border := 4.0
var lip := 6.0
var sink := 0.0
var radius := 22.0
var highlight := 0.45
var gloss := 0.0
var shadow_alpha := 0.28
var shadow_size := 8.0
var shadow_offset := 5.0
var sunken := false
## Extra glow around the outside (e.g. a selected card), and its color.
var glow := 0.0
var glow_color := Color("#ffe14d")

var _boxes := {}


func _draw(item: RID, rect: Rect2) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	if glow > 0.0:
		_flat("glow", Color(glow_color, 0.0), r, glow_color, glow).draw(item, rect)
	if shadow_alpha > 0.0:
		var shadow_rect := Rect2(rect.position + Vector2(0, shadow_offset), rect.size)
		_flat("shadow", Color(outline, shadow_alpha * 0.7), r, Color(outline, shadow_alpha), shadow_size).draw(item, shadow_rect)
	_flat("outline", outline, r).draw(item, rect)
	var inner := rect.grow(-border)
	var inner_r := maxf(2.0, r - border * 0.8)
	if sunken:
		_gradient(item, inner, inner_r, color.darkened(dark + 0.08), color.lightened(light * 0.4))
		# A soft shadow inside along the top edge.
		var top := _round_rect(inner.grow(-1.5), inner_r - 1.5, true)
		RenderingServer.canvas_item_add_polyline(item, top, PackedColorArray([Color(outline, 0.45)]), 3.0, true)
		return
	var face_top := color.lightened(light)
	var face_bottom := color.darkened(dark)
	if lip > 0.0:
		_flat("lip", color.darkened(dark + 0.28), inner_r).draw(item, inner)
	var face := Rect2(inner.position + Vector2(0, sink), Vector2(inner.size.x, maxf(4.0, inner.size.y - lip)))
	_gradient(item, face, inner_r, face_top, face_bottom)
	if gloss > 0.0 and face.size.x > 14.0 and face.size.y > 8.0:
		var shine := Rect2(face.position + Vector2(5, 4), Vector2(face.size.x - 10, face.size.y * 0.44))
		var points := _round_rect(shine, maxf(2.0, inner_r - 4.0))
		var colors := PackedColorArray()
		for p in points:
			colors.append(Color(1, 1, 1, gloss * (1.0 - clampf((p.y - shine.position.y) / shine.size.y, 0.0, 1.0))))
		RenderingServer.canvas_item_add_polygon(item, points, colors)
	if highlight > 0.0:
		var line := _round_rect(face.grow(-2.5), maxf(2.0, inner_r - 2.5), true)
		RenderingServer.canvas_item_add_polyline(item, line, PackedColorArray([Color(1, 1, 1, highlight)]), 2.5, true)


func _get_draw_rect(rect: Rect2) -> Rect2:
	var spread := maxf(shadow_size, glow)
	return rect.grow(spread).grow_individual(0, 0, 0, shadow_offset)


## A rounded rectangle filled with a gradient from `top` to `bottom`, with a
## smoothed edge.
func _gradient(item: RID, rect: Rect2, r: float, top: Color, bottom: Color) -> void:
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return
	var points := _round_rect(rect, r)
	var colors := PackedColorArray()
	for p in points:
		colors.append(top.lerp(bottom, clampf((p.y - rect.position.y) / maxf(1.0, rect.size.y), 0.0, 1.0)))
	RenderingServer.canvas_item_add_polygon(item, points, colors)
	var loop := points.duplicate()
	loop.append(points[0])
	var loop_colors := colors.duplicate()
	loop_colors.append(colors[0])
	RenderingServer.canvas_item_add_polyline(item, loop, loop_colors, 1.2, true)


## A cached plain rounded box (antialiased), optionally with a blurred shadow.
func _flat(key: String, fill: Color, r: float, shadow := Color(0, 0, 0, 0), spread := 0.0) -> StyleBoxFlat:
	var box: StyleBoxFlat = _boxes.get(key)
	if box == null:
		box = StyleBoxFlat.new()
		box.anti_aliasing = true
		_boxes[key] = box
	box.bg_color = fill
	box.set_corner_radius_all(int(r))
	box.shadow_color = shadow
	box.shadow_size = int(spread)
	box.draw_center = fill.a > 0.0
	return box


## The outline of a rounded rectangle, clockwise from the top-left corner;
## or just its top edge (left middle, over the top, to the right middle).
static func _round_rect(rect: Rect2, r: float, top_only := false) -> PackedVector2Array:
	r = clampf(r, 0.0, minf(rect.size.x, rect.size.y) * 0.5)
	var points := PackedVector2Array()
	var steps := 6
	var corners := [
		[Vector2(rect.position.x + r, rect.position.y + r), PI],
		[Vector2(rect.end.x - r, rect.position.y + r), PI * 1.5],
		[Vector2(rect.end.x - r, rect.end.y - r), 0.0],
		[Vector2(rect.position.x + r, rect.end.y - r), PI * 0.5],
	]
	var count := 2 if top_only else 4
	for c in count:
		var center: Vector2 = corners[c][0]
		var start: float = corners[c][1]
		for i in steps + 1:
			var angle := start + PI * 0.5 * float(i) / steps
			var p := center + Vector2(cos(angle), sin(angle)) * r
			# Skip repeats (a pill exactly 2 radii tall has corners that meet):
			# a polygon with repeated points can't be filled.
			if points.is_empty() or p.distance_squared_to(points[points.size() - 1]) > 0.01:
				points.append(p)
	if not top_only and points.size() > 2 and points[0].distance_squared_to(points[points.size() - 1]) <= 0.01:
		points.remove_at(points.size() - 1)
	if top_only:
		# Down the sides a little, fading into the face.
		points.insert(0, points[0] + Vector2(0, minf(r * 0.6, rect.size.y * 0.25)))
		points.append(points[points.size() - 1] + Vector2(0, minf(r * 0.6, rect.size.y * 0.25)))
	return points
