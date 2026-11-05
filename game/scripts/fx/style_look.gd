class_name StyleLook
extends Node2D
## What an animal's attack style looks like on the animal itself
## (styles.json; the fight's side is BattleStyles): poses and props that read
## without any text, drawn over its body. The one-off effects of a style
## (a swipe, a ground pound, a hit bouncing back) are the field's
## (battle_field.gd).
##   shell (Snapping Turtle): squashed flat under a green domed shell.
##   snack (Giant Panda): sitting down, munching a bamboo stalk, leaves
##     dropping.
##   rhino_charge (Black Rhino): low and leaning into the charge, dust
##     kicked up behind.
##   pound (Yeti): the hit before a ground pound, it glows icy blue with
##     frost rising off it (the tell).
## Sizes and colors: feel.json "styles".

var view: UnitView
var kind := ""
var _state := ""
var _time := 0.0
var _puff_in := 0.0


static func make(v: UnitView) -> StyleLook:
	var look := StyleLook.new()
	look.view = v
	look.kind = String(GameData.styles.get(v.id, {}).get("kind", ""))
	return look


func _num(key: String, fallback: float) -> float:
	return Feel.num("styles", key, fallback)


func _color(key: String, fallback: String) -> Color:
	return Color(String(GameData.feel.get("styles", {}).get(key, fallback)))


## How the body is posed this frame ({"sx", "sy", "lift", "rot", "tint"}),
## and the props and particles that go with it.
func pose(f: BattleSim.Fighter, now: float, dt: float) -> Dictionary:
	var p := {"sx": 1.0, "sy": 1.0, "lift": 0.0, "rot": 0.0, "tint": Color.WHITE}
	_time = now
	var state := ""
	if f != null and view.defeat < 0.0 and kind != "":
		match kind:
			"shell":
				if int(f.memory.get("shell", 0)) > 0:
					state = "shell"
					p.sx = 1.14
					p.sy = 0.5
					p.tint = Color(0.78, 0.84, 0.78)
			"snack":
				if int(f.memory.get("snack", 0)) > 0:
					state = "snack"
					p.sx = 1.1
					p.sy = 0.84 + sin(now * 14.0) * 0.025
					_puffs(dt, "leaf", _color("bamboo_leaf", "#6fcf4a"), Vector2(0.25, -0.55), Vector2(30, 40), 0.35)
			"rhino_charge":
				if int(f.memory.get("charge_state", 0)) == 1:
					state = "charge"
					p.sx = 1.08
					p.sy = 0.9
					# Dust kicked up behind it as it thunders along.
					var behind := -view.move_dir * 0.45
					_puffs(dt, "puff", _color("charge_dust", "#c9b08a"), Vector2(behind.x, behind.y * 0.6 - 0.05), -view.move_dir * 120.0 + Vector2(0, -30), 0.04, 14.0)
			"pound":
				var every := maxi(1, int(f.sp("every", 3)))
				if int(f.memory.get("pounds", 0)) % every == every - 1:
					state = "frost"
					var glow := 0.5 + 0.5 * sin(now * 8.0)
					p.tint = Color(1.0, 1.0, 1.0).lerp(_color("frost", "#9fe6ff"), 0.35 + 0.2 * glow)
					_puffs(dt, "sparkle", _color("frost", "#9fe6ff"), Vector2(0.0, -0.3), Vector2(0, -60), 0.12)
	if state != _state or state in ["snack", "shell"]:
		_state = state
		queue_redraw()
	return p


## Particles every `every` seconds at a spot on the animal (`spot`: a share
## of its width and height from its feet), drifting at `vel`.
func _puffs(dt: float, particle: String, color: Color, spot: Vector2, vel: Vector2, every: float, size := 7.0) -> void:
	_puff_in -= dt
	if _puff_in > 0.0 or view.field == null:
		return
	_puff_in = every
	var h := _height()
	var at := view.position + position + Vector2(spot.x * h + randf_range(-0.15, 0.15) * h, spot.y * h)
	view.field.fx.particle(particle, at, vel + Vector2(randf_range(-20, 20), randf_range(-10, 10)), 0.6, size, color, 60.0 if particle == "leaf" else -20.0, 2.0, randf_range(-4, 4))


## The animal's drawn height in pixels.
func _height() -> float:
	return UnitSprites.top(view.id) * view.body.k


func _draw() -> void:
	match _state:
		"shell":
			_draw_shell()
		"snack":
			_draw_bamboo()


## A green domed shell over the flattened turtle, with plates and a shine.
func _draw_shell() -> void:
	var h := _height()
	var w := h * _num("shell_width", 1.25)
	var tall := w * 0.42
	var base := Vector2(0, -h * 0.05)
	var points := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		points.append(base + Vector2(cos(a) * w * 0.5, sin(a) * tall))
	var dark := _color("shell_dark", "#3d6b2c")
	var light := _color("shell_light", "#7fb04a")
	draw_colored_polygon(points, dark)
	var inner := PackedVector2Array()
	for point in points:
		inner.append(base + (point - base) * 0.82)
	draw_colored_polygon(inner, light)
	# Plates.
	var top := base + Vector2(0, -tall * 0.82)
	for x in [-0.22, 0.0, 0.22]:
		draw_line(base + Vector2(x * w, -tall * 0.05), top + Vector2(x * w * 0.6, tall * 0.25), dark, maxf(2.0, h * 0.025))
	draw_line(base + Vector2(-w * 0.38, -tall * 0.45), base + Vector2(w * 0.38, -tall * 0.45), dark, maxf(2.0, h * 0.025))
	draw_polyline(points, UIKit.INK, maxf(2.0, h * 0.03))
	draw_circle(top + Vector2(-w * 0.12, tall * 0.18), h * 0.05, Color(1, 1, 1, 0.45))


## A bamboo stalk held up to the mouth, bobbing as it munches.
func _draw_bamboo() -> void:
	var h := _height()
	var bob := sin(_time * 14.0) * h * 0.03
	var a := Vector2(h * 0.18, -h * 0.05 + bob)
	var b := Vector2(h * 0.42, -h * 1.0 + bob)
	var width := maxf(6.0, h * 0.11)
	var green := _color("bamboo", "#8fd14f")
	var dark := green.darkened(0.35)
	draw_line(a, b, UIKit.INK, width + 4.0)
	draw_line(a, b, green, width)
	for u in [0.3, 0.62]:
		var at: Vector2 = a.lerp(b, u)
		var across := (b - a).normalized().orthogonal() * width * 0.55
		draw_line(at - across, at + across, dark, maxf(2.0, width * 0.3))
	var leaf := _color("bamboo_leaf", "#6fcf4a")
	for side in [-1.0, 1.0]:
		var tip := b + Vector2(side * h * 0.26, -h * 0.08)
		var leaf_shape := PackedVector2Array([b, b.lerp(tip, 0.5) + Vector2(0, -h * 0.07), tip, b.lerp(tip, 0.5) + Vector2(0, h * 0.05)])
		draw_colored_polygon(leaf_shape, leaf)
		draw_polyline(leaf_shape + PackedVector2Array([b]), UIKit.INK, 2.0)
