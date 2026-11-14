class_name Backdrop
extends Control
## The background behind the menus: a summer sky fading to sunshine (as
## behind a match's screens), with a few soft clouds drifting across the
## top and a faint pattern of paw prints, so screens feel finished rather
## than flat. Colors stay bold out to the corners (nothing darkened).
## Settings: feel.json "menu" (cloud_*, paw_*).

const C := "menu"

## How visible the paw prints are (0: none).
var pattern_alpha := -1.0
## Still, for a screen that shouldn't redraw every frame.
var still := false

var _time := 0.0

static var _gradient: GradientTexture2D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_time = randf() * 100.0
	set_process(not still and Feel.num(C, "cloud_speed", 6.0) > 0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_texture_rect(_gradient_texture(), rect, false, Color.WHITE)
	_draw_paws()
	_draw_clouds()


func _draw_paws() -> void:
	var alpha := pattern_alpha if pattern_alpha >= 0.0 else Feel.num(C, "paw_alpha", 0.07)
	var paw := UIKit.icon(GameData.ui_icon("paw"))
	if paw == null or alpha <= 0.0:
		return
	var step := Feel.num(C, "paw_step", 120.0)
	var side := Feel.num(C, "paw_size", 46.0)
	var row := 0
	var y := -step * 0.5
	while y < size.y + step:
		var x := -step * 0.5 + (step * 0.5 if row % 2 == 1 else 0.0)
		while x < size.x + step:
			var turn := 0.35 if (row + int(x / step)) % 2 == 0 else -0.25
			draw_set_transform(Vector2(x, y), turn)
			draw_texture_rect(paw, Rect2(-Vector2(side, side) / 2.0, Vector2(side, side)), false, Color(1, 1, 1, alpha))
			x += step
		y += step * 0.8
		row += 1
	draw_set_transform(Vector2.ZERO)


## A few puffy clouds, each a row of overlapping discs on a flat base,
## drifting slowly and coming round again.
func _draw_clouds() -> void:
	var count := Feel.count(C, "cloud_count", 4)
	var speed := Feel.num(C, "cloud_speed", 6.0)
	var band := size.y * Feel.num(C, "cloud_band", 0.42)
	var color := UIStyle.color("cloud")
	var span := size.x + 520.0
	for i in count:
		var k := float(i) / maxf(1.0, count)
		var big := 0.7 + 0.6 * fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
		var x := fposmod(k * span * 1.7 + _time * speed * (0.6 + 0.5 * k) + i * 97.0, span) - 260.0
		var y := 150.0 + band * fposmod(sin(i * 78.233) * 12543.123, 1.0)
		_cloud(Vector2(x, y), 54.0 * big, color)


func _cloud(at: Vector2, r: float, color: Color) -> void:
	draw_circle(at + Vector2(-r * 1.25, r * 0.18), r * 0.62, color)
	draw_circle(at + Vector2(-r * 0.45, -r * 0.22), r * 0.86, color)
	draw_circle(at + Vector2(r * 0.5, -r * 0.05), r * 0.74, color)
	draw_circle(at + Vector2(r * 1.25, r * 0.22), r * 0.56, color)
	draw_rect(Rect2(at + Vector2(-r * 1.3, r * 0.18), Vector2(r * 2.6, r * 0.6)), color)
	draw_circle(at + Vector2(-r * 1.3, r * 0.48), r * 0.3, color)
	draw_circle(at + Vector2(r * 1.3, r * 0.48), r * 0.3, color)


func _gradient_texture() -> GradientTexture2D:
	if _gradient == null:
		var gradient := Gradient.new()
		gradient.set_color(0, UIKit.BG_TOP)
		gradient.set_color(1, UIKit.BG_BOTTOM)
		_gradient = GradientTexture2D.new()
		_gradient.gradient = gradient
		_gradient.fill_to = Vector2(0, 1)
		_gradient.width = 8
		_gradient.height = 256
	return _gradient
