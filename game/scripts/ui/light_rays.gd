class_name LightRays
extends Control
## Soft rays of light turning slowly behind something special, like a cage
## being opened or a new animal.

var color := Color(1, 0.92, 0.6):
	set(value):
		color = value
		queue_redraw()
var rays := 14
var spin := 0.25
## How strong the rays and the glow are (1: for a dark backdrop; more on a
## bright one).
var strength := 1.0

var _angle := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_angle += delta * spin
	queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var reach := size.length() * 0.6
	var half := PI / rays * 0.45
	for i in rays:
		var a := _angle + TAU * i / rays
		var points := PackedVector2Array([center, center + Vector2.from_angle(a - half) * reach, center + Vector2.from_angle(a + half) * reach])
		draw_colored_polygon(points, Color(color, minf(1.0, 0.07 * strength)))
	var glow := AnimalCard._spot_texture()
	var side := minf(size.x, size.y) * 0.9
	draw_texture_rect(glow, Rect2(center - Vector2(side, side) / 2.0, Vector2(side, side)), false, Color(color, minf(1.0, 0.22 * strength)))
