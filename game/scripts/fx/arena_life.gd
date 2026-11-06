class_name ArenaLife
extends Node2D
## Life round an arena, outside the field's fence (data/arena_life.json):
## animals watching from behind the far fence, one scurrying along its rail
## or pouncing in the snow, flags fluttering, a ranger waving, the arena's
## sign, northern lights, twinkles on the ice. It sits in the battle field's
## world under the animals, so it never covers them, and it's skipped
## entirely while it's off screen.
##
## Gentle loops all the time; big moments (a clash, a knockout, a strong hit,
## the War Horn: cheer()) make the crowd hop and cheer in a wave from where
## it happened, flags whip and the lights flare. Everything is a few small
## pictures (the crowd strips, tools/creatures/crowd.py) and simple shapes.

const CROWD := "res://art/arenas/crowd/"
## A height straight up shows this much of itself on screen (the camera
## looks down at 50 degrees).
const UP := 0.643

var field: BattleField
var arena_id := ""
var spec: Dictionary = {}

var _actors: Array = []
var _strips := {}
var _clock := 0.0
var _flutter_until := -10.0
var _flare := 0.0
var _last_cheer := -10.0
var _rng := RandomNumberGenerator.new()


static func make(on: BattleField, id: String) -> ArenaLife:
	var life := ArenaLife.new()
	life.field = on
	life.arena_id = id
	life._load()
	return life


static func all_specs() -> Dictionary:
	var file := FileAccess.open("res://data/arena_life.json", FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _load() -> void:
	var specs := all_specs()
	spec = specs.get(arena_id, {})
	var defaults: Dictionary = specs.get("_defaults", {})
	for key in defaults:
		if not spec.has(key):
			spec[key] = defaults[key]
	_rng.seed = hash(arena_id)
	for raw in spec.get("actors", []):
		var actor: Dictionary = (raw as Dictionary).duplicate(true)
		actor.phase = _rng.randf() * 10.0
		actor.cheer_at = -10.0
		match String(actor.kind):
			"runner":
				var path: Array = actor.path
				actor.pos = _rng.randf()
				actor.dir = 1.0 if _rng.randf() < 0.5 else -1.0
				actor.wait = _rng.randf_range(0.5, 2.0)
				actor.length = Vector2(float(path[0][0]), float(path[0][1])).distance_to(Vector2(float(path[1][0]), float(path[1][1])))
			"pouncer":
				actor.home = float(actor.at[0])
				actor.x = actor.home
				actor.leap_at = _rng.randf_range(1.0, 3.0)
				actor.leap_from = actor.x
				actor.leap_to = actor.x
			"sparkles":
				var area: Array = actor.area
				var points := []
				for i in int(actor.get("count", 12)):
					points.append([_rng.randf_range(float(area[0]), float(area[2])), _rng.randf_range(float(area[1]), float(area[3])), _rng.randf() * TAU, _rng.randf_range(2.0, 4.0)])
				actor.points = points
		if actor.has("animal"):
			_strip(String(actor.animal))
		_actors.append(actor)
	# The far fence again, over the crowd standing behind it.
	if spec.has("fence") and not _actors.is_empty():
		_actors.append({"kind": "fence", "color": spec.fence, "phase": 0.0})
	# The far ones first, so nearer ones stand in front of them.
	_actors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _depth(a) < _depth(b))


func _depth(actor: Dictionary) -> float:
	match String(actor.kind):
		"aurora":
			return -100.0
		"sparkles":
			return -50.0
		"fence":
			return -0.3
		"runner":
			# On top of the fence's rail.
			return float(actor.path[0][1]) + 0.1
		"sign":
			return float(actor.at[1]) + 0.05
	return float(actor.get("at", [0, 0])[1]) if actor.has("at") else 0.0


func _strip(animal: String) -> Dictionary:
	if _strips.has(animal):
		return _strips[animal]
	var strip := {}
	var file := FileAccess.open(CROWD + animal + ".json", FileAccess.READ)
	if file != null and ResourceLoader.exists(CROWD + animal + ".webp"):
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			strip = parsed
			strip.texture = load(CROWD + animal + ".webp")
	_strips[animal] = strip
	return strip


func has_life() -> bool:
	return not _actors.is_empty()


# --- Big moments ---------------------------------------------------------------

## A big moment at field x (in tiles): the crowd cheers in a wave from
## there, flags whip, the lights flare. `power` 0-1.
func cheer(at_x: float, power := 1.0) -> void:
	var c: Dictionary = spec.get("cheer", {})
	if _clock - _last_cheer < float(c.get("cooldown_seconds", 0.6)) * (1.0 - power * 0.5):
		return
	_last_cheer = _clock
	var wave := float(c.get("wave_seconds_per_tile", 0.035))
	for actor in _actors:
		match String(actor.kind):
			"spectator", "ranger":
				if _clock - float(actor.cheer_at) > 0.9:
					actor.cheer_at = _clock + absf(float(actor.at[0]) - at_x) * wave + _rng.randf_range(0.0, 0.08)
					actor.cheer_power = clampf(power, 0.3, 1.0)
			"pouncer":
				if float(actor.leap_at) - _clock > 0.4:
					actor.leap_at = _clock + 0.15
	_flutter_until = _clock + float(c.get("flutter_seconds", 1.6)) * power
	_flare = maxf(_flare, power)


# --- Every frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	if _actors.is_empty() or field == null:
		return
	_clock += delta
	_flare = maxf(0.0, _flare - delta * 0.8)
	for actor in _actors:
		match String(actor.kind):
			"runner":
				_run(actor, delta)
			"pouncer":
				_pounce(actor)
	if _on_screen():
		queue_redraw()


func _run(actor: Dictionary, delta: float) -> void:
	if float(actor.wait) > 0.0:
		actor.wait = float(actor.wait) - delta
		return
	var step := float(actor.get("tiles_per_second", 2.4)) * delta / maxf(0.1, float(actor.length))
	actor.pos = float(actor.pos) + step * float(actor.dir)
	if float(actor.pos) >= 1.0 or float(actor.pos) <= 0.0:
		actor.pos = clampf(float(actor.pos), 0.0, 1.0)
		actor.dir = -float(actor.dir)
		actor.wait = _rng.randf_range(0.5, 1.5)
	elif _rng.randf() < delta * 0.25:
		# Stops now and then to watch the fight.
		var pause: Array = actor.get("pause", [1.0, 4.0])
		actor.wait = _rng.randf_range(float(pause[0]), float(pause[1]))
		if _rng.randf() < 0.3:
			actor.dir = -float(actor.dir)


func _pounce(actor: Dictionary) -> void:
	if _clock < float(actor.leap_at):
		return
	var flight := 0.6
	if float(actor.leap_from) == float(actor.leap_to) or _clock > float(actor.leap_at) + flight:
		if float(actor.leap_from) != float(actor.leap_to):
			# Landed: a puff of snow, and wait for the next leap.
			actor.x = actor.leap_to
			actor.landed_at = _clock
			var every: Array = actor.get("every", [3.0, 6.0])
			actor.leap_at = _clock + _rng.randf_range(float(every[0]), float(every[1]))
			actor.leap_from = actor.x
			actor.leap_to = actor.x
			return
		# Off again: toward home if it's wandered, else either way.
		var leap := float(actor.get("leap", 1.5))
		var away := float(actor.x) - float(actor.home)
		var dir := -signf(away) if absf(away) > leap * 1.2 else (1.0 if _rng.randf() < 0.5 else -1.0)
		actor.leap_from = actor.x
		actor.leap_to = float(actor.x) + dir * leap
		actor.leap_at = _clock


## True when the strip behind the far fence is on screen.
func _on_screen() -> bool:
	var top := _point(0.0, -3.4)
	var bottom := _point(0.0, 0.0)
	return bottom.y > -20.0 and top.y < field.size.y + 20.0


# --- Drawing --------------------------------------------------------------------------

## A spot in arena tiles (x across, t down the field) on screen.
func _point(x: float, t: float) -> Vector2:
	var k := field.field_k_now() * 1000.0
	return field.to_screen(x * k, t * k)


func _tile_px() -> float:
	return field.field_scale() * 1000.0 * field.field_k_now()


func _draw() -> void:
	if not _on_screen():
		return
	var tile := _tile_px()
	for actor in _actors:
		match String(actor.kind):
			"aurora":
				_draw_aurora(actor, tile)
			"sparkles":
				_draw_sparkles(actor, tile)
			"spectator":
				_draw_spectator(actor, tile)
			"runner":
				_draw_runner(actor, tile)
			"pouncer":
				_draw_pouncer(actor, tile)
			"flag":
				_draw_flag(actor, tile)
			"sign":
				_draw_sign(actor, tile)
			"ranger":
				_draw_ranger(actor, tile)
			"fence":
				_draw_fence(actor, tile)


func _scale_for(strip: Dictionary, tile: float) -> float:
	return tile / float(strip.get("pixels_per_tile", 64)) * Feel.num("characters", "sprite_scale", 1.6) * float(spec.get("scale", 0.72))


## One frame of an animal's strip, standing at `feet`.
func _draw_frame(strip: Dictionary, anim: String, frame: int, feet: Vector2, k: float, flip: bool, squash := 1.0) -> void:
	var info: Dictionary = strip.get("animations", {}).get(anim, {})
	if info.is_empty() or strip.get("texture") == null:
		return
	var frames: Array = info.frames
	var rect: Array = frames[posmod(frame, frames.size())]
	var anchor: Array = info.anchor
	var region := Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
	var sx := k / sqrt(squash)
	var sy := k * squash
	draw_set_transform(feet, 0.0, Vector2(-sx if flip else sx, sy))
	draw_texture_rect_region(strip.texture, Rect2(-Vector2(float(anchor[0]), float(anchor[1])), region.size), region)
	draw_set_transform(Vector2.ZERO)


func _shadow(feet: Vector2, width: float) -> void:
	GroundArt.draw(self, GroundArt.Cell.SHADOW, feet, width, 0.4, Color(0.05, 0.08, 0.12, 0.35))


func _draw_spectator(actor: Dictionary, tile: float) -> void:
	var strip := _strip(String(actor.animal))
	if strip.is_empty():
		return
	var feet := _point(float(actor.at[0]), float(actor.at[1]))
	var k := _scale_for(strip, tile)
	var since := _clock - float(actor.cheer_at)
	var cheer: Dictionary = strip.animations.get("cheer", {})
	var cheer_frames: Array = cheer.get("frames", [])
	var cheering: bool = since >= 0.0 and not cheer.is_empty() and since < cheer_frames.size() / float(cheer.get("fps", 10))
	var lift := 0.0
	var squash := 1.0
	if since >= 0.0 and since < 0.5:
		# A hop: up and down, a squash on the way up and on landing.
		var p := since / 0.5
		lift = 4.0 * p * (1.0 - p) * float(spec.get("cheer", {}).get("hop_tiles", 0.32)) * float(actor.get("cheer_power", 1.0))
		squash = 1.0 + 0.12 * sin(p * TAU)
	else:
		squash = 1.0 + 0.025 * sin(_clock * 2.4 + float(actor.phase))
	_shadow(feet, tile * 0.32)
	var anim := "cheer" if cheering else "idle"
	var info: Dictionary = strip.animations.get(anim, {})
	var fps := float(info.get("fps", 6))
	var frame := int((since if cheering else _clock + float(actor.phase)) * fps)
	_draw_frame(strip, anim, frame, feet - Vector2(0, lift * tile * UP), k, bool(actor.get("flip", false)), squash)


func _draw_runner(actor: Dictionary, tile: float) -> void:
	var strip := _strip(String(actor.animal))
	if strip.is_empty():
		return
	var path: Array = actor.path
	var a := Vector2(float(path[0][0]), float(path[0][1]))
	var b := Vector2(float(path[1][0]), float(path[1][1]))
	var at := a.lerp(b, float(actor.pos))
	var rail := float(actor.get("rail", 0.0))
	var feet := _point(at.x, at.y) - Vector2(0, rail * UP * tile)
	var k := _scale_for(strip, tile) * float(actor.get("size", 0.85))
	if float(actor.wait) > 0.0:
		_draw_frame(strip, "idle", int((_clock + float(actor.phase)) * 6.0), feet, k, false)
	else:
		var hop := absf(sin(_clock * 11.0 + float(actor.phase))) * 0.05 * tile
		var fps := float(strip.animations.get("run", {}).get("fps", 12))
		_draw_frame(strip, "run", int(_clock * fps * 1.3), feet - Vector2(0, hop), k, float(actor.dir) < 0.0)


func _draw_pouncer(actor: Dictionary, tile: float) -> void:
	var strip := _strip(String(actor.animal))
	if strip.is_empty():
		return
	var t := float(actor.at[1])
	var k := _scale_for(strip, tile)
	var leaping := float(actor.leap_from) != float(actor.leap_to)
	if leaping:
		var p := clampf((_clock - float(actor.leap_at)) / 0.6, 0.0, 1.0)
		var x := lerpf(float(actor.leap_from), float(actor.leap_to), p)
		var lift := 4.0 * p * (1.0 - p) * 0.55
		var feet := _point(x, t)
		_shadow(feet, tile * 0.3 * (1.0 - lift * 0.6))
		var info: Dictionary = strip.animations.get("pounce", {})
		var pounce_frames: Array = info.get("frames", [])
		var frames := maxi(1, pounce_frames.size())
		_draw_frame(strip, "pounce" if not info.is_empty() else "idle", int(p * frames), feet - Vector2(0, lift * tile * UP * 1.6), k,
			float(actor.leap_to) < float(actor.leap_from))
		return
	var feet := _point(float(actor.x), t)
	_shadow(feet, tile * 0.3)
	_draw_frame(strip, "idle", int((_clock + float(actor.phase)) * 6.0), feet, k, false)
	var since := _clock - float(actor.get("landed_at", -10.0))
	if since < 0.5:
		# Snow kicked up on landing.
		var puff := Color(String(actor.get("puff", "#f4fbff")))
		for i in 5:
			var angle := PI + i * PI / 4.0
			var r := tile * (0.15 + since * 0.7)
			var spot := feet + Vector2(cos(angle) * r, sin(angle) * r * 0.45)
			draw_circle(spot, tile * 0.07 * (1.0 - since * 1.6), Color(puff, 1.0 - since * 2.0))


## The far fence (as in the arena's picture, tools/creatures/arena.py): a
## post every tile and two rails.
func _draw_fence(actor: Dictionary, tile: float) -> void:
	var wood := Color(String(actor.color)) * Color(1.02, 1.02, 1.02)
	var edge := wood.darkened(0.6)
	var t := -0.3
	var left := _point(-0.3, t)
	var right := _point(16.3, t)
	var line := maxf(1.0, tile * 0.02)
	for h in [0.17, 0.33]:
		var up := Vector2(0, -h * UP * tile)
		draw_line(left + up, right + up, edge, tile * 0.07 * UP + line * 2.0)
		draw_line(left + up, right + up, wood, tile * 0.07 * UP)
		draw_line(left + up - Vector2(0, tile * 0.02), right + up - Vector2(0, tile * 0.02), wood.lightened(0.18), maxf(1.0, tile * 0.015))
	for i in 17:
		var foot := _point(-0.3 + i * (16.6 / 16.0), t)
		var post := Rect2(foot + Vector2(-tile * 0.055, -0.42 * UP * tile - tile * 0.03), Vector2(tile * 0.11, 0.42 * UP * tile + tile * 0.06))
		draw_rect(post.grow(line), edge)
		draw_rect(post, wood)
		draw_rect(Rect2(post.position, Vector2(post.size.x, tile * 0.035)), wood.lightened(0.2))


func _draw_flag(actor: Dictionary, tile: float) -> void:
	var foot := _point(float(actor.at[0]), float(actor.at[1]))
	var tall := float(actor.get("height", 2.0)) * UP * tile
	var top := foot - Vector2(0, tall)
	var line := maxf(1.5, tile * 0.03)
	_shadow(foot, tile * 0.12)
	draw_line(foot, top, UIKit.INK, tile * 0.07 + line * 2.0)
	draw_line(foot, top, Color("#efe6cf"), tile * 0.07)
	draw_circle(top, tile * 0.07 + line, UIKit.INK)
	draw_circle(top, tile * 0.07, UIKit.GOLD)
	# The cloth: two stripes, waving harder for a while after a big moment.
	var colors: Array = actor.get("colors", ["#ec4b52", "#ffffff"])
	var fast := _clock < _flutter_until
	var speed := 9.0 if fast else 4.0
	var amp := tile * (0.09 if fast else 0.05)
	var length := tile * 0.95
	var height := tile * 0.5
	var steps := 10
	var upper := PackedVector2Array()
	var middle := PackedVector2Array()
	var lower := PackedVector2Array()
	for i in steps + 1:
		var f := float(i) / steps
		var wave := sin(_clock * speed + float(actor.phase) - f * 4.0) * amp * f
		var at := top + Vector2(f * length, tile * 0.08 + wave)
		upper.append(at)
		middle.append(at + Vector2(0, height * 0.5))
		lower.append(at + Vector2(0, height))
	var outline := upper.duplicate()
	for i in range(steps, -1, -1):
		outline.append(lower[i])
	draw_colored_polygon(outline, Color(String(colors[1])))
	var top_half := upper.duplicate()
	for i in range(steps, -1, -1):
		top_half.append(middle[i])
	draw_colored_polygon(top_half, Color(String(colors[0])))
	outline.append(outline[0])
	draw_polyline(outline, UIKit.INK, line, true)


func _draw_sign(actor: Dictionary, tile: float) -> void:
	var colors: Array = actor.get("colors", ["#2f8f4a", "#ffd23f", "#6b4424"])
	var middle := _point(float(actor.at[0]), float(actor.at[1]))
	var width := float(actor.get("width", 3.0)) * tile
	var height := tile * 0.5
	var bounce := 0.0
	var since := _clock - _last_cheer
	if since < 0.6:
		bounce = sin(since * 18.0) * (0.6 - since) * tile * 0.05
	var box := Rect2(middle + Vector2(-width / 2.0, -height - tile * 0.06 - bounce), Vector2(width, height))
	var line := maxf(2.0, tile * 0.04)
	# Two posts it hangs from.
	for side in [-1.0, 1.0]:
		var x: float = middle.x + side * width * 0.4
		draw_line(Vector2(x, middle.y), Vector2(x, box.position.y), UIKit.INK, tile * 0.09)
		draw_line(Vector2(x, middle.y), Vector2(x, box.position.y), Color(String(colors[2])), tile * 0.06)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(String(colors[2]))
	frame.set_corner_radius_all(int(tile * 0.12))
	frame.border_color = UIKit.INK
	frame.set_border_width_all(int(line))
	frame.anti_aliasing = true
	draw_style_box(frame, box)
	var face := StyleBoxFlat.new()
	face.bg_color = Color(String(colors[0]))
	face.set_corner_radius_all(int(tile * 0.08))
	face.border_color = Color(String(colors[1]))
	face.set_border_width_all(int(maxf(1.5, tile * 0.03)))
	face.anti_aliasing = true
	draw_style_box(face, box.grow(-tile * 0.06))
	var name := String(GameData.get_arena(int(GameData.arena_index_by_id.get(arena_id, 0))).get("name", "")).to_upper()
	var font := UIKit.DISPLAY_FONT
	var size := int(maxf(8.0, height * 0.52))
	while size > 8 and font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width * 0.86:
		size -= 1
	var text := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var at := box.get_center() + Vector2(-text.x / 2.0, size * 0.36)
	draw_string_outline(font, at, name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(maxf(2.0, size * 0.22)), UIKit.INK)
	draw_string(font, at, name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(String(colors[1])))


func _draw_ranger(actor: Dictionary, tile: float) -> void:
	var colors: Dictionary = actor.get("colors", {})
	var feet := _point(float(actor.at[0]), float(actor.at[1]))
	var since := _clock - float(actor.cheer_at)
	var lift := 0.0
	if since >= 0.0 and since < 0.45:
		var p := since / 0.45
		lift = 4.0 * p * (1.0 - p) * tile * 0.12
	var base := feet - Vector2(0, lift)
	var u := tile * 0.95 * UP
	var line := maxf(1.5, tile * 0.035)
	var skin := Color(String(colors.get("skin", "#e8b48a")))
	var shirt := Color(String(colors.get("shirt", "#c8a86a")))
	var shorts := Color(String(colors.get("shorts", "#5a7a3a")))
	var hat := Color(String(colors.get("hat", "#8a5a2e")))
	_shadow(feet, tile * 0.22)
	# Legs, shorts, shirt, head, hat; one arm waving (harder when cheering).
	for side in [-1.0, 1.0]:
		var hip := base + Vector2(side * u * 0.09, -u * 0.42)
		_limb(hip, base + Vector2(side * u * 0.1, 0), skin, u * 0.075, line)
	_blob(Rect2(base + Vector2(-u * 0.17, -u * 0.52), Vector2(u * 0.34, u * 0.14)), shorts, line, u * 0.05)
	_blob(Rect2(base + Vector2(-u * 0.19, -u * 0.86), Vector2(u * 0.38, u * 0.38)), shirt, line, u * 0.1)
	var shoulder := base + Vector2(u * 0.17, -u * 0.8)
	var wave := sin(_clock * (14.0 if since >= 0.0 and since < 1.2 else 7.0) + float(actor.phase)) * 0.45
	var hand := shoulder + Vector2(u * 0.3, 0).rotated(-PI * 0.42 + wave)
	_limb(shoulder, hand, shirt, u * 0.08, line)
	draw_circle(hand, u * 0.06, skin)
	_limb(base + Vector2(-u * 0.17, -u * 0.8), base + Vector2(-u * 0.22, -u * 0.5), shirt, u * 0.08, line)
	var head := base + Vector2(0, -u * 1.02)
	draw_circle(head, u * 0.17 + line, UIKit.INK)
	draw_circle(head, u * 0.17, skin)
	draw_circle(head + Vector2(-u * 0.06, u * 0.0), u * 0.025, UIKit.INK)
	draw_circle(head + Vector2(u * 0.06, u * 0.0), u * 0.025, UIKit.INK)
	draw_arc(head + Vector2(0, u * 0.05), u * 0.06, 0.3, PI - 0.3, 8, UIKit.INK, line * 0.7, true)
	_blob(Rect2(head + Vector2(-u * 0.28, -u * 0.14), Vector2(u * 0.56, u * 0.08)), hat, line, u * 0.04)
	_blob(Rect2(head + Vector2(-u * 0.15, -u * 0.3), Vector2(u * 0.3, u * 0.19)), hat, line, u * 0.08)


func _limb(from: Vector2, to: Vector2, color: Color, width: float, line: float) -> void:
	draw_line(from, to, UIKit.INK, width + line * 2.0)
	draw_circle(from, (width + line * 2.0) / 2.0, UIKit.INK)
	draw_circle(to, (width + line * 2.0) / 2.0, UIKit.INK)
	draw_line(from, to, color, width)
	draw_circle(from, width / 2.0, color)
	draw_circle(to, width / 2.0, color)


func _blob(rect: Rect2, color: Color, line: float, radius: float) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	box.border_color = UIKit.INK
	box.set_border_width_all(int(maxf(1.0, line)))
	box.anti_aliasing = true
	draw_style_box(box, rect)


func _draw_aurora(actor: Dictionary, tile: float) -> void:
	var colors: Array = actor.get("colors", ["#5dffb0", "#3fd6ff", "#b07cff"])
	var near := float(actor.get("from", -0.9))
	var far := float(actor.get("to", -3.0))
	var glow := 0.55 + 0.45 * _flare
	# A dusky sky glow first, so the lights show even over snow.
	var dusk := Color(String(actor.get("dusk", "#1c2a6e")))
	var sky := PackedVector2Array([_point(-3.0, far - 0.6), _point(19.0, far - 0.6), _point(19.0, near), _point(-3.0, near)])
	draw_polygon(sky, PackedColorArray([Color(dusk, float(actor.get("dusk_alpha", 0.55))), Color(dusk, float(actor.get("dusk_alpha", 0.55))), Color(dusk, 0.0), Color(dusk, 0.0)]))
	for c in colors.size():
		var color := Color(String(colors[c]))
		var points := PackedVector2Array()
		var tints := PackedColorArray()
		var steps := 24
		var bottoms := PackedVector2Array()
		for i in steps + 1:
			var x := lerpf(-3.0, 19.0, float(i) / steps)
			var sway := sin(x * 0.5 + _clock * (0.35 + c * 0.12) + c * 2.1) * 0.35 + sin(x * 1.3 - _clock * 0.6 + c) * 0.12
			var top_t := far + sway + c * 0.25
			var bottom_t := near - 0.2 - c * 0.15 + sway * 0.4
			points.append(_point(x, top_t))
			tints.append(Color(color, 0.0))
			bottoms.append(_point(x, bottom_t))
		for i in range(steps, -1, -1):
			points.append(bottoms[i])
			var shimmer := 0.5 + 0.5 * sin(float(i) * 0.9 + _clock * 1.7 + c * 1.3)
			tints.append(Color(color, (0.3 + 0.25 * shimmer) * glow))
		draw_polygon(points, tints)


func _draw_sparkles(actor: Dictionary, tile: float) -> void:
	var color := Color(String(actor.get("color", "#ffffff")))
	for p in actor.points:
		var twinkle := pow(maxf(0.0, sin(_clock * TAU / float(p[3]) + float(p[2]))), 6.0)
		if twinkle < 0.05:
			continue
		var at := _point(float(p[0]), float(p[1]))
		var r := tile * 0.11 * twinkle
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r), at + Vector2(r * 0.22, 0), at + Vector2(0, r), at + Vector2(-r * 0.22, 0)]), Color(color, twinkle))
		draw_colored_polygon(PackedVector2Array([at + Vector2(-r, 0), at + Vector2(0, r * 0.22), at + Vector2(r, 0), at + Vector2(0, -r * 0.22)]), Color(color, twinkle))
