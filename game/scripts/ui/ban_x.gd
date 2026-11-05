class_name BanX
extends Control
## A big red X with a dark rim, drawn over a banned animal's card (the ban
## screen and the deck screen). Fill its parent with it.

var color := Color("#e0302a")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var inset := size * 0.14
	var a := inset
	var b := size - inset
	var width := minf(size.x, size.y) * 0.13
	var lines := [[a, b], [Vector2(b.x, a.y), Vector2(a.x, b.y)]]
	for pair in lines:
		draw_line(pair[0], pair[1], Color(0.12, 0.02, 0.02), width + 10.0, true)
	for pair in lines:
		draw_line(pair[0], pair[1], color, width, true)
	for pair in lines:
		draw_line(pair[0] + Vector2(0, -width * 0.22), pair[1] + Vector2(0, -width * 0.22), color.lightened(0.35), width * 0.25, true)
