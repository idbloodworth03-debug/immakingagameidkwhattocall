class_name ArenaArt
extends Control
## A small scene for an arena: sky, sun, ground and habitat silhouettes
## (trees for the woods, cacti for the canyon...). The icons per arena are
## listed in data/art.json.

var arena_id := "":
	set(value):
		arena_id = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var arena := GameData.get_arena(int(GameData.arena_index_by_id.get(arena_id, 0)))
	var base := Color(arena.color)
	var rect := Rect2(Vector2.ZERO, size)
	var radius := int(minf(size.x, size.y) * 0.12)

	draw_style_box(UIKit.box(base.darkened(0.55), radius + 4), rect)
	var inner := rect.grow(-6)
	draw_style_box(UIKit.box(base.lightened(0.45).lerp(Color("#bfe3ff"), 0.35), radius), inner)
	var sun := inner.position + Vector2(inner.size.x * 0.82, inner.size.y * 0.24)
	draw_circle(sun, inner.size.y * 0.13, Color(1, 0.97, 0.75, 0.55))
	draw_circle(sun, inner.size.y * 0.09, Color(1, 0.97, 0.8, 0.8))

	var ground_top := inner.position.y + inner.size.y * 0.7
	var ground := StyleBoxFlat.new()
	ground.bg_color = base
	ground.corner_radius_bottom_left = radius
	ground.corner_radius_bottom_right = radius
	ground.anti_aliasing = true
	draw_style_box(ground, Rect2(inner.position.x, ground_top, inner.size.x, inner.end.y - ground_top))
	draw_line(Vector2(inner.position.x, ground_top), Vector2(inner.end.x, ground_top), base.lightened(0.25), 4.0)

	# Habitat silhouettes standing on the ground: two in the back, one big in front.
	var icons := GameData.arena_icons(arena_id)
	var spots := [[0.2, 0.42, 0.25], [0.8, 0.38, 0.25], [0.5, 0.62, 0.45]]
	for i in mini(icons.size(), spots.size()):
		var texture := UIKit.icon(icons[i])
		if texture == null:
			continue
		var spot: Array = spots[i]
		var side: float = inner.size.y * spot[1]
		var bottom := ground_top + inner.size.y * 0.06
		var shade := base.darkened(spot[2])
		var where := Rect2(Vector2(inner.position.x + inner.size.x * spot[0] - side / 2.0, bottom - side), Vector2(side, side))
		draw_texture_rect(texture, where, false, shade)
