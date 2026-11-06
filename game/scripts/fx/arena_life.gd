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
## Every kind of life there is (data/arena_life.json "actors").
const KINDS := ["spectator", "runner", "pouncer", "flag", "sign", "ranger", "aurora", "sparkles", "birds", "popper",
	"roller", "drifter", "walker", "fire", "glow", "fireflies", "jumper", "mist", "waterfall", "butterflies", "swinger",
	"pennants", "lights", "water", "fireworks", "dust", "blinker"]
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
			"sparkles", "fireflies", "butterflies", "mist":
				var area: Array = actor.area
				var points := []
				for i in int(actor.get("count", 12)):
					points.append([_rng.randf_range(float(area[0]), float(area[2])), _rng.randf_range(float(area[1]), float(area[3])), _rng.randf() * TAU, _rng.randf_range(2.0, 4.0)])
				actor.points = points
			"birds":
				var flock := []
				for i in int(actor.get("count", 5)):
					flock.append({"x": _rng.randf_range(-1.0, 1.0), "t": _rng.randf_range(-1.0, 1.0), "phase": _rng.randf() * TAU})
				actor.flock = flock
				actor.away = -10.0
			"popper":
				var holes := []
				for at in actor.holes:
					var out := _rng.randf() < 0.5
					holes.append({"x": float(at[0]), "t": float(at[1]), "up": 1.0 if out else 0.0, "until": _rng.randf_range(0.5, 4.0), "out": out, "phase": _rng.randf() * TAU})
				actor.state = holes
			"roller", "drifter", "walker":
				actor.x = _rng.randf_range(-2.0, 18.0)
				actor.dir = 1.0 if _rng.randf() < 0.5 or String(actor.kind) == "drifter" else -1.0
				actor.wait = _rng.randf_range(0.0, 3.0) if String(actor.kind) == "roller" else 0.0
			"jumper":
				actor.next = _rng.randf_range(1.0, 3.0)
				actor.jump_at = -10.0
				actor.spot = 0
			"fireworks":
				actor.bursts = []
				actor.next = _rng.randf_range(4.0, 8.0)
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
		"aurora", "water":
			return -100.0
		"drifter":
			return -90.0 + float(actor.get("t", -2.0)) * 0.01
		"mist", "fireworks":
			return 5.0
		"sparkles", "lights":
			return -50.0
		"birds", "butterflies", "fireflies":
			return 2.0
		"popper":
			return float(actor.holes[0][1])
		"pennants":
			return float(actor.from[1])
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
			"birds":
				if String(actor.get("mode", "ground")) == "ground" and _clock - float(actor.away) > 6.0:
					actor.away = _clock
			"popper":
				for hole in actor.state:
					hole.out = true
					hole.until = _clock + _rng.randf_range(1.5, 3.0)
			"jumper":
				actor.next = minf(float(actor.next), _clock + 0.2)
			"fireworks":
				if power >= 0.7:
					_firework(actor, _rng.randf_range(2.0, 14.0))
					_firework(actor, _rng.randf_range(2.0, 14.0))
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
			"popper":
				_pop(actor, delta)
			"roller":
				_roll(actor, delta)
			"drifter", "walker":
				var span := 24.0
				actor.x = float(actor.x) + float(actor.get("tiles_per_second", 0.3)) * delta * float(actor.dir)
				if float(actor.x) > 19.5 or float(actor.x) < -3.5:
					if String(actor.kind) == "walker":
						actor.dir = -float(actor.dir)
					else:
						actor.x = float(actor.x) - span * float(actor.dir)
			"jumper":
				if _clock >= float(actor.next):
					actor.jump_at = _clock
					actor.spot = _rng.randi_range(0, (actor.spots as Array).size() - 1)
					var every: Array = actor.get("every", [2.5, 5.0])
					actor.next = _clock + _rng.randf_range(float(every[0]), float(every[1]))
			"fireworks":
				if _clock >= float(actor.next):
					_firework(actor, _rng.randf_range(1.0, 15.0))
					actor.next = _clock + _rng.randf_range(5.0, 9.0)
				var live: Array = []
				for b in actor.bursts:
					if _clock - float(b.at) < 1.4:
						live.append(b)
				actor.bursts = live
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
			"birds":
				_draw_birds(actor, tile)
			"popper":
				_draw_popper(actor, tile)
			"roller":
				_draw_roller(actor, tile)
			"drifter":
				_draw_drifter(actor, tile)
			"walker":
				_draw_walker(actor, tile)
			"fire":
				_draw_fire(actor, tile)
			"glow":
				_draw_glow(actor, tile)
			"fireflies":
				_draw_fireflies(actor, tile)
			"jumper":
				_draw_jumper(actor, tile)
			"mist":
				_draw_mist(actor, tile)
			"waterfall":
				_draw_waterfall(actor, tile)
			"butterflies":
				_draw_butterflies(actor, tile)
			"swinger":
				_draw_swinger(actor, tile)
			"pennants":
				_draw_pennants(actor, tile)
			"lights":
				_draw_lights(actor, tile)
			"water":
				_draw_water(actor, tile)
			"fireworks":
				_draw_fireworks(actor, tile)
			"dust":
				_draw_dust(actor, tile)
			"blinker":
				_draw_blinker(actor, tile)


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



# --- More kinds of life (the other arenas) --------------------------------------------

func _pop(actor: Dictionary, delta: float) -> void:
	for hole in actor.state:
		if _clock >= float(hole.until):
			hole.out = not bool(hole.out)
			hole.until = _clock + (_rng.randf_range(2.0, 5.0) if hole.out else _rng.randf_range(1.0, 4.0))
		hole.up = move_toward(float(hole.up), 1.0 if hole.out else 0.0, delta * 4.0)


func _roll(actor: Dictionary, delta: float) -> void:
	if float(actor.wait) > 0.0:
		actor.wait = float(actor.wait) - delta
		return
	actor.x = float(actor.x) + float(actor.get("tiles_per_second", 1.6)) * delta * float(actor.dir)
	if float(actor.x) > 19.0 or float(actor.x) < -3.0:
		actor.dir = -float(actor.dir)
		actor.wait = _rng.randf_range(3.0, 8.0)


func _firework(actor: Dictionary, x: float) -> void:
	var colors: Array = actor.get("colors", ["#ffd23f", "#ff5a8a", "#5ad1ff"])
	(actor.bursts as Array).append({"x": x, "t": _rng.randf_range(float(actor.get("from", -1.2)), float(actor.get("to", -2.0))),
		"at": _clock, "color": Color(String(colors[_rng.randi_range(0, colors.size() - 1)]))})


## A little cartoon bird (a pigeon, a gull, a crow), facing `dir`, wings up
## or down with `flap` (-1 to 1); on the ground when `flap` is null.
func _bird(at: Vector2, size: float, color: Color, dir: float, flap: float, flying: bool) -> void:
	var line := maxf(1.0, size * 0.12)
	var ink := color.darkened(0.65)
	if flying:
		var wing := Vector2(size * 0.9, -size * 0.55 * flap)
		draw_polyline(PackedVector2Array([at - Vector2(wing.x, wing.y), at + Vector2(-size * 0.2, size * 0.1), at, at + Vector2(size * 0.2, size * 0.1), at + Vector2(wing.x, wing.y) * Vector2(1, 1)]), ink, line * 2.2, true)
		draw_polyline(PackedVector2Array([at - Vector2(wing.x, wing.y), at + Vector2(-size * 0.2, size * 0.1), at, at + Vector2(size * 0.2, size * 0.1), at + Vector2(wing.x, wing.y)]), color, line, true)
		return
	draw_circle(at + Vector2(0, -size * 0.35), size * 0.42 + line, ink)
	draw_circle(at + Vector2(dir * size * 0.32, -size * 0.7), size * 0.24 + line, ink)
	draw_circle(at + Vector2(0, -size * 0.35), size * 0.42, color)
	draw_circle(at + Vector2(dir * size * 0.32, -size * 0.7), size * 0.24, color.lightened(0.1))
	draw_circle(at + Vector2(dir * size * 0.4, -size * 0.74), size * 0.05, ink)
	draw_colored_polygon(PackedVector2Array([at + Vector2(dir * size * 0.5, -size * 0.72), at + Vector2(dir * size * 0.72, -size * 0.66), at + Vector2(dir * size * 0.5, -size * 0.6)]), Color("#f0a020"))


func _draw_birds(actor: Dictionary, tile: float) -> void:
	var color := Color(String(actor.get("color", "#8a8f9e")))
	var size := tile * float(actor.get("size", 0.16))
	var mode := String(actor.get("mode", "ground"))
	var at: Array = actor.get("at", [8.0, -1.2])
	var spread: Array = actor.get("spread", [1.2, 0.3])
	match mode:
		"ground":
			var since := _clock - float(actor.away)
			for b in actor.flock:
				var home := Vector2(float(at[0]) + float(b.x) * float(spread[0]), float(at[1]) + float(b.t) * float(spread[1]))
				var feet := _point(home.x, home.y)
				if since < 6.0:
					# Startled: up and away, back a few seconds later.
					var out := clampf(since / 1.2, 0.0, 1.0) if since < 4.5 else clampf((6.0 - since) / 1.5, 0.0, 1.0)
					var off := Vector2((1.0 if float(b.x) > 0.0 else -1.0) * 4.0, -3.0) * out * tile
					_bird(feet + off, size, color, 1.0, sin(_clock * 22.0 + float(b.phase)), true)
					continue
				var peck := maxf(0.0, sin(_clock * 3.0 + float(b.phase)))
				_shadow(feet, size * 0.6)
				_bird(feet + Vector2(0, peck * size * 0.3), size, color, 1.0 if float(b.x) < 0.3 else -1.0, 0.0, false)
		"circle":
			var radius := float(actor.get("radius", 2.0))
			for i in (actor.flock as Array).size():
				var b: Dictionary = actor.flock[i]
				var angle := _clock * 0.35 + i * TAU / (actor.flock as Array).size()
				var spot := _point(float(at[0]) + cos(angle) * radius, float(at[1]) + sin(angle) * radius * 0.35)
				_bird(spot, size, color, 1.0, sin(_clock * 3.0 + float(b.phase)) * 0.4, true)
		_:
			# Flying across, now and then.
			var period := float(actor.get("every", 9.0))
			var p := fmod(_clock + float(actor.flock[0].phase), period) / period
			if p > 0.6:
				return
			var x := lerpf(-3.0, 19.0, p / 0.6)
			for b in actor.flock:
				var spot := _point(x + float(b.x) * 1.2, float(at[1]) + float(b.t) * 0.4)
				_bird(spot, size, color, 1.0, sin(_clock * 12.0 + float(b.phase)), true)


func _draw_popper(actor: Dictionary, tile: float) -> void:
	var fur := Color(String(actor.get("color", "#b0844a")))
	var belly := fur.lightened(0.35)
	var ink := fur.darkened(0.7)
	var tall := float(actor.get("height", 0.5)) * tile
	var line := maxf(1.0, tile * 0.025)
	for hole in actor.state:
		var at := _point(float(hole.x), float(hole.t))
		draw_set_transform(at, 0.0, Vector2(1, 0.45))
		draw_circle(Vector2.ZERO, tile * 0.16 + line, ink)
		draw_circle(Vector2.ZERO, tile * 0.16, Color("#3a2a1e"))
		draw_set_transform(Vector2.ZERO)
		var up := float(hole.up)
		if up <= 0.02:
			continue
		var h := tall * up
		var look := sin(_clock * 1.3 + float(hole.phase))
		var body := Rect2(at + Vector2(-tile * 0.1, -h), Vector2(tile * 0.2, h))
		draw_rect(body.grow(line), ink)
		draw_rect(body, fur)
		draw_rect(Rect2(body.position + Vector2(tile * 0.05, tile * 0.12), Vector2(tile * 0.1, maxf(0.0, h - tile * 0.14))), belly)
		var head := at + Vector2(look * tile * 0.02, -h)
		draw_circle(head, tile * 0.11 + line, ink)
		draw_circle(head, tile * 0.11, fur)
		for side in [-1.0, 1.0]:
			draw_circle(head + Vector2(side * tile * 0.045 + look * tile * 0.015, -tile * 0.01), tile * 0.022, ink)
		draw_circle(head + Vector2(look * tile * 0.03, tile * 0.04), tile * 0.02, ink)
		# Over the hole's front edge, so it pops out of the ground.
		draw_set_transform(at + Vector2(0, tile * 0.03), 0.0, Vector2(1, 0.3))
		draw_arc(Vector2.ZERO, tile * 0.17, 0.2, PI - 0.2, 12, Color("#5a4028"), line * 3.0)
		draw_set_transform(Vector2.ZERO)


func _draw_roller(actor: Dictionary, tile: float) -> void:
	if float(actor.wait) > 0.0:
		return
	var t := float(actor.get("t", -0.9))
	if String(actor.get("style", "")) == "crab":
		_crab(_point(float(actor.x), t), tile * float(actor.get("size", 0.2)), Color(String(actor.get("color", "#e8503a"))))
		return
	var r := tile * float(actor.get("size", 0.28))
	var hop := absf(sin(_clock * 4.0)) * tile * 0.25
	var center := _point(float(actor.x), t) - Vector2(0, r + hop)
	_shadow(_point(float(actor.x), t), r)
	var spin := _clock * 5.0 * float(actor.dir)
	var color := Color(String(actor.get("color", "#b08a50")))
	draw_circle(center, r, Color(color.darkened(0.5), 0.35))
	for i in 7:
		var a := spin + i * 0.9
		draw_arc(center + Vector2(cos(a), sin(a)) * r * 0.3, r * 0.65, a, a + 2.4, 10, color.darkened(0.3 if i % 2 == 0 else 0.0), maxf(1.0, tile * 0.025), true)


func _draw_drifter(actor: Dictionary, tile: float) -> void:
	var t := float(actor.get("t", -2.0))
	var at := _point(float(actor.x), t) + Vector2(0, sin(_clock * 0.8) * tile * 0.05)
	if String(actor.get("style", "")) == "kite":
		_kite(actor, tile)
		return
	var colors: Array = actor.get("colors", ["#ff6a5a", "#ffd23f"])
	var ink := UIKit.INK
	var line := maxf(1.5, tile * 0.03)
	match String(actor.get("style", "cloud")):
		"balloon":
			var r := tile * 0.5
			draw_line(at + Vector2(-r * 0.4, r * 0.7), at + Vector2(-r * 0.2, r * 1.3), ink, line)
			draw_line(at + Vector2(r * 0.4, r * 0.7), at + Vector2(r * 0.2, r * 1.3), ink, line)
			draw_rect(Rect2(at + Vector2(-r * 0.25, r * 1.3), Vector2(r * 0.5, r * 0.32)).grow(line), ink)
			draw_rect(Rect2(at + Vector2(-r * 0.25, r * 1.3), Vector2(r * 0.5, r * 0.32)), Color("#a8743f"))
			draw_circle(at, r + line, ink)
			draw_circle(at, r, Color(String(colors[0])))
			for i in [-1, 1]:
				draw_set_transform(at, 0.0, Vector2(0.38, 1.0))
				draw_circle(Vector2(i * r * 1.3, 0), r * 0.55, Color(String(colors[1])))
				draw_set_transform(Vector2.ZERO)
			draw_circle(at + Vector2(-r * 0.35, -r * 0.35), r * 0.15, Color(1, 1, 1, 0.5))
		"boat":
			var w := tile * 0.9
			var hull := PackedVector2Array([at + Vector2(-w * 0.5, 0), at + Vector2(w * 0.5, 0), at + Vector2(w * 0.35, w * 0.2), at + Vector2(-w * 0.35, w * 0.2)])
			draw_colored_polygon(hull, Color(String(colors[1])))
			draw_polyline(hull + PackedVector2Array([hull[0]]), ink, line, true)
			draw_line(at, at - Vector2(0, w * 0.9), ink, line * 1.5)
			var sail := PackedVector2Array([at - Vector2(-w * 0.04, w * 0.85), at - Vector2(-w * 0.04, w * 0.1), at + Vector2(w * 0.42, -w * 0.12)])
			draw_colored_polygon(sail, Color(String(colors[0])))
			draw_polyline(sail + PackedVector2Array([sail[0]]), ink, line, true)
		_:
			var soft := BattleField._soft_texture()
			var w := tile * float(actor.get("size", 2.0))
			for i in 4:
				var off := Vector2((i - 1.5) * w * 0.28, sin(i * 1.7) * w * 0.08)
				draw_texture_rect(soft, Rect2(at + off - Vector2(w * 0.3, w * 0.2), Vector2(w * 0.6, w * 0.4)), false, Color(String(colors[0]), float(actor.get("alpha", 0.85))))


func _draw_walker(actor: Dictionary, tile: float) -> void:
	var strip := _strip(String(actor.animal))
	if strip.is_empty():
		return
	var feet := _point(float(actor.x), float(actor.get("t", -1.8)))
	var k := _scale_for(strip, tile) * float(actor.get("size", 0.8))
	var fps := float(strip.animations.get("run", {}).get("fps", 12)) * 0.6
	_shadow(feet, tile * 0.4)
	_draw_frame(strip, "run", int(_clock * fps), feet, k, float(actor.dir) < 0.0)


func _draw_fire(actor: Dictionary, tile: float) -> void:
	var at := _point(float(actor.at[0]), float(actor.at[1]))
	var line := maxf(1.0, tile * 0.025)
	var soft := BattleField._soft_texture()
	draw_texture_rect(soft, Rect2(at - Vector2(tile * 0.7, tile * 0.45), Vector2(tile * 1.4, tile * 0.9)), false, Color(1.0, 0.7, 0.3, 0.35 + 0.1 * sin(_clock * 9.0)))
	for i in 3:
		var a := i * PI / 3.0
		var d := Vector2(cos(a), sin(a) * 0.4) * tile * 0.22
		draw_line(at - d, at + d, Color("#3a2414"), tile * 0.08 + line * 2.0)
		draw_line(at - d, at + d, Color("#8a5a33"), tile * 0.08)
	for i in 3:
		var flick := sin(_clock * (11.0 + i * 3.0) + i) * tile * 0.03
		var h := tile * (0.45 - i * 0.1) + flick
		var w := tile * (0.16 - i * 0.03)
		var flames: Array[Color] = [Color("#ff6a1f"), Color("#ffb52e"), Color("#fff07a")]
		var color: Color = flames[i]
		draw_colored_polygon(PackedVector2Array([at + Vector2(-w, 0), at + Vector2(0, -h), at + Vector2(w, 0), at + Vector2(0, tile * 0.04)]), color)
	for i in 4:
		var p := fmod(_clock * 0.35 + i * 0.25, 1.0)
		var puff := at + Vector2(sin(p * 6.0 + i) * tile * 0.15, -tile * (0.5 + p * 1.6))
		draw_texture_rect(soft, Rect2(puff - Vector2.ONE * tile * (0.12 + p * 0.25), Vector2.ONE * tile * (0.24 + p * 0.5)), false, Color(0.85, 0.85, 0.9, 0.5 * (1.0 - p)))


func _draw_glow(actor: Dictionary, tile: float) -> void:
	var color := Color(String(actor.get("color", "#7fffd4")))
	var soft := BattleField._soft_texture()
	var boost := 1.0 + _flare * 0.6
	for i in (actor.spots as Array).size():
		var spot: Array = actor.spots[i]
		var at := _point(float(spot[0]), float(spot[1]))
		var pulse := 0.6 + 0.4 * sin(_clock * 1.6 + i * 1.3)
		var r := tile * 0.18
		draw_texture_rect(soft, Rect2(at - Vector2(r * 2.5, r * 2.2), Vector2(r * 5.0, r * 3.6)), false, Color(color, 0.35 * pulse * boost))
		draw_line(at, at - Vector2(0, r * 0.9), Color("#f2ead8"), r * 0.45)
		draw_set_transform(at - Vector2(0, r * 0.9), 0.0, Vector2(1.0, 0.6))
		draw_circle(Vector2.ZERO, r * 0.8, color.lerp(Color.WHITE, 0.3 * pulse))
		draw_set_transform(Vector2.ZERO)


func _draw_fireflies(actor: Dictionary, tile: float) -> void:
	var color := Color(String(actor.get("color", "#fff36a")))
	var soft := BattleField._soft_texture()
	for p in actor.points:
		var drift := Vector2(sin(_clock * 0.5 + float(p[2])) * 0.6, cos(_clock * 0.4 + float(p[2]) * 1.3) * 0.25)
		var at := _point(float(p[0]) + drift.x, float(p[1]) + drift.y) - Vector2(0, tile * 0.4)
		var glow := 0.5 + 0.5 * sin(_clock * TAU / float(p[3]) + float(p[2]))
		draw_texture_rect(soft, Rect2(at - Vector2.ONE * tile * 0.12, Vector2.ONE * tile * 0.24), false, Color(color, 0.6 * glow))
		draw_circle(at, tile * 0.025, Color(color.lightened(0.5), 0.5 + 0.5 * glow))


func _draw_jumper(actor: Dictionary, tile: float) -> void:
	var spots: Array = actor.get("spots", [[8.0, -1.4]])
	var since := _clock - float(actor.jump_at)
	var spot: Array = spots[clampi(int(actor.spot), 0, spots.size() - 1)]
	var at := _point(float(spot[0]), float(spot[1]))
	var color := Color(String(actor.get("color", "#ff9a3a")))
	var length := tile * float(actor.get("size", 0.32))
	var line := maxf(1.0, tile * 0.025)
	# Rings where it left the water and where it splashed back in.
	for ring in [[0.0, Vector2(-length * 1.2, 0)], [0.8, Vector2(length * 1.2, 0)]]:
		var age: float = since - float(ring[0])
		if age > 0.0 and age < 1.0:
			draw_set_transform(at + ring[1], 0.0, Vector2(1, 0.4))
			draw_arc(Vector2.ZERO, tile * (0.08 + age * 0.3), 0, TAU, 20, Color(1, 1, 1, 0.8 * (1.0 - age)), line * 1.5, true)
			draw_set_transform(Vector2.ZERO)
	if since < 0.0 or since > 0.8:
		return
	var p := since / 0.8
	var pos := at + Vector2(lerpf(-length * 1.2, length * 1.2, p), -4.0 * p * (1.0 - p) * tile * float(actor.get("height", 0.6)))
	var angle := lerpf(-0.9, 0.9, p)
	draw_set_transform(pos, angle, Vector2.ONE)
	var body := PackedVector2Array()
	for i in 16:
		var a := i * TAU / 16.0
		body.append(Vector2(cos(a) * length * 0.5, sin(a) * length * 0.2))
	var ink := color.darkened(0.6)
	draw_colored_polygon(PackedVector2Array([Vector2(-length * 0.45, 0), Vector2(-length * 0.75, -length * 0.2), Vector2(-length * 0.75, length * 0.2)]), ink)
	draw_colored_polygon(body, color)
	draw_polyline(body + PackedVector2Array([body[0]]), ink, line, true)
	draw_circle(Vector2(length * 0.3, -length * 0.04), maxf(1.0, length * 0.05), ink)
	draw_set_transform(Vector2.ZERO)


func _draw_mist(actor: Dictionary, tile: float) -> void:
	var soft := BattleField._soft_texture()
	var color := Color(String(actor.get("color", "#eef6f4")))
	for p in actor.points:
		var x := fposmod(float(p[0]) + _clock * 0.15 * float(p[3]) * 0.3, 22.0) - 3.0
		var at := _point(x, float(p[1]))
		var w := tile * 1.6 * float(p[3]) * 0.4
		draw_texture_rect(soft, Rect2(at - Vector2(w, w * 0.35), Vector2(w * 2.0, w * 0.7)), false, Color(color, float(actor.get("alpha", 0.35))))


func _draw_waterfall(actor: Dictionary, tile: float) -> void:
	var top := _point(float(actor.at[0]), float(actor.at[1]) - float(actor.get("height", 1.4)))
	var foot := _point(float(actor.at[0]), float(actor.at[1]))
	var w := tile * float(actor.get("width", 0.8))
	var water := Color(String(actor.get("color", "#7fd6ff")))
	draw_rect(Rect2(Vector2(top.x - w / 2.0, top.y), Vector2(w, foot.y - top.y)), water)
	for i in 6:
		var x := top.x - w / 2.0 + (i + 0.5) * w / 6.0
		var p := fmod(_clock * 1.6 + i * 0.37, 1.0)
		var y := lerpf(top.y, foot.y, p)
		draw_line(Vector2(x, y), Vector2(x, minf(foot.y, y + tile * 0.3)), Color(1, 1, 1, 0.7), maxf(1.0, w * 0.05))
	var soft := BattleField._soft_texture()
	for i in 4:
		var p := fmod(_clock * 0.6 + i * 0.25, 1.0)
		draw_texture_rect(soft, Rect2(foot + Vector2((i - 1.5) * w * 0.35, -tile * 0.1) - Vector2.ONE * tile * (0.2 + p * 0.3), Vector2.ONE * tile * (0.4 + p * 0.6)), false, Color(1, 1, 1, 0.55 * (1.0 - p)))


func _draw_butterflies(actor: Dictionary, tile: float) -> void:
	var colors: Array = actor.get("colors", ["#ff8a3a", "#ffd23f", "#5ad1ff"])
	for i in (actor.points as Array).size():
		var p: Array = actor.points[i]
		var drift := Vector2(sin(_clock * 0.45 + float(p[2])) * 1.2, cos(_clock * 0.6 + float(p[2])) * 0.3)
		var at := _point(float(p[0]) + drift.x, float(p[1]) + drift.y) - Vector2(0, tile * 0.5)
		var flap := absf(sin(_clock * 14.0 + float(p[2])))
		var color := Color(String(colors[i % colors.size()]))
		var w := tile * 0.12
		for side in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([at, at + Vector2(side * w * (0.3 + flap), -w * 0.9), at + Vector2(side * w * (0.4 + flap * 0.8), w * 0.4)]), color)
		draw_line(at - Vector2(0, w * 0.4), at + Vector2(0, w * 0.4), UIKit.INK, maxf(1.0, w * 0.15))


func _draw_swinger(actor: Dictionary, tile: float) -> void:
	var strip := _strip(String(actor.animal))
	var pivot := _point(float(actor.at[0]), float(actor.at[1])) - Vector2(0, tile * float(actor.get("height", 2.0)) * UP)
	var length := tile * float(actor.get("length", 1.0))
	var swing := sin(_clock * 1.8) * 0.6 * (1.0 + _flare * 0.5)
	var hand := pivot + Vector2(0, length).rotated(swing)
	draw_line(pivot, hand, Color("#2f7a3a"), maxf(2.0, tile * 0.05))
	if strip.is_empty():
		return
	var k := _scale_for(strip, tile) * 0.8
	var info: Dictionary = strip.animations.get("idle", {})
	if info.is_empty():
		return
	var anchor: Array = info.anchor
	var rect: Array = (info.frames as Array)[int(_clock * 6.0) % (info.frames as Array).size()]
	draw_set_transform(hand, swing, Vector2(k, k))
	draw_texture_rect_region(strip.texture, Rect2(Vector2(-float(anchor[0]), -float(rect[3]) * 0.12), Vector2(float(rect[2]), float(rect[3]))), Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3])))
	draw_set_transform(Vector2.ZERO)


func _draw_pennants(actor: Dictionary, tile: float) -> void:
	var a := _point(float(actor.from[0]), float(actor.from[1])) - Vector2(0, tile * float(actor.get("height", 1.4)) * UP)
	var b := _point(float(actor.to[0]), float(actor.to[1])) - Vector2(0, tile * float(actor.get("height", 1.4)) * UP)
	var colors: Array = actor.get("colors", ["#3f8fff", "#ffffff", "#ff4f4f", "#3fcf74", "#ffd23f"])
	var count := int(actor.get("count", 12))
	var sag := tile * 0.35
	var fast := _clock < _flutter_until
	var line := maxf(1.0, tile * 0.02)
	for post: Vector2 in [a, b]:
		var ground: Vector2 = post + Vector2(0, tile * float(actor.get("height", 1.4)) * UP)
		draw_line(ground, post, UIKit.INK, tile * 0.06 + line * 2.0)
		draw_line(ground, post, Color("#8a5a33"), tile * 0.06)
	var previous := a
	for i in range(1, count + 2):
		var f := float(i) / (count + 1)
		var at := a.lerp(b, f) + Vector2(0, sin(f * PI) * sag)
		draw_line(previous, at, UIKit.INK, line)
		previous = at
	for i in count:
		var f := (i + 0.5) / (count + 1) + 0.5 / (count + 1)
		var at := a.lerp(b, f) + Vector2(0, sin(f * PI) * sag)
		var wave := sin(_clock * (10.0 if fast else 4.0) + i * 0.8) * tile * 0.05
		var size := tile * 0.22
		var flag := PackedVector2Array([at + Vector2(-size * 0.5, 0), at + Vector2(size * 0.5, 0), at + Vector2(wave, size)])
		draw_colored_polygon(flag, Color(String(colors[i % colors.size()])))
		draw_polyline(flag + PackedVector2Array([flag[0]]), UIKit.INK, line, true)


func _draw_lights(actor: Dictionary, tile: float) -> void:
	var a := _point(float(actor.from[0]), float(actor.from[1])) - Vector2(0, tile * float(actor.get("height", 1.2)) * UP)
	var b := _point(float(actor.to[0]), float(actor.to[1])) - Vector2(0, tile * float(actor.get("height", 1.2)) * UP)
	var colors: Array = actor.get("colors", ["#ffd23f", "#ff5a8a", "#5ad1ff", "#7dff8a"])
	var count := int(actor.get("count", 14))
	var soft := BattleField._soft_texture()
	var sag := tile * 0.25
	var previous := a
	for i in range(1, count + 2):
		var f := float(i) / (count + 1)
		var at := a.lerp(b, f) + Vector2(0, sin(f * PI) * sag)
		draw_line(previous, at, Color("#2a2a2e"), maxf(1.0, tile * 0.02))
		previous = at
	for i in count:
		var f := float(i + 1) / (count + 1)
		var at := a.lerp(b, f) + Vector2(0, sin(f * PI) * sag + tile * 0.06)
		var on := 0.55 + 0.45 * sin(_clock * 3.0 + i * 1.1) + _flare * 0.4
		var color := Color(String(colors[i % colors.size()]))
		draw_texture_rect(soft, Rect2(at - Vector2.ONE * tile * 0.13, Vector2.ONE * tile * 0.26), false, Color(color, 0.45 * on))
		draw_circle(at, tile * 0.045, color.lerp(Color.WHITE, 0.3 * on))


func _draw_water(actor: Dictionary, tile: float) -> void:
	var near := float(actor.get("from", -1.6))
	var far := float(actor.get("to", -4.0))
	var deep := Color(String(actor.get("color", "#2f9be8")))
	var a := _point(-3.0, far)
	var b := _point(19.0, near)
	draw_rect(Rect2(a, b - a), deep)
	# Foam lines rolling in toward the shore.
	for i in 4:
		var p := fmod(_clock * 0.18 + i * 0.25, 1.0)
		var t := lerpf(far, near, p)
		var points := PackedVector2Array()
		for j in 25:
			var x := lerpf(-3.0, 19.0, j / 24.0)
			points.append(_point(x, t) + Vector2(0, sin(x * 1.3 + _clock + i) * tile * 0.05))
		draw_polyline(points, Color(1, 1, 1, 0.6 * sin(p * PI)), maxf(1.5, tile * 0.04), true)
	var shore := PackedVector2Array()
	for j in 25:
		var x := lerpf(-3.0, 19.0, j / 24.0)
		shore.append(_point(x, near) + Vector2(0, sin(x * 0.9 + _clock * 1.2) * tile * 0.06))
	draw_polyline(shore, Color(1, 1, 1, 0.85), maxf(2.0, tile * 0.07), true)


func _draw_fireworks(actor: Dictionary, tile: float) -> void:
	for burst in actor.bursts:
		var age := _clock - float(burst.at)
		var center := _point(float(burst.x), float(burst.t)) - Vector2(0, tile * 0.6)
		var color: Color = burst.color
		var r := tile * 0.9 * (1.0 - pow(1.0 - minf(age / 0.8, 1.0), 3.0))
		var fade := clampf(1.4 - age, 0.0, 1.0)
		for i in 12:
			var a := i * TAU / 12.0
			var tip := center + Vector2(cos(a), sin(a)) * r + Vector2(0, age * age * tile * 0.4)
			draw_line(center + Vector2(cos(a), sin(a)) * r * 0.6 + Vector2(0, age * age * tile * 0.3), tip, Color(color, fade), maxf(1.5, tile * 0.04), true)
			draw_circle(tip, maxf(1.5, tile * 0.035), Color(color.lightened(0.4), fade))


func _draw_dust(actor: Dictionary, tile: float) -> void:
	var color := Color(String(actor.get("color", "#d8a070")))
	var x := float(actor.at[0]) + sin(_clock * 0.3) * 2.0
	var foot := _point(x, float(actor.at[1]))
	var soft := BattleField._soft_texture()
	for i in 10:
		var h := float(i) / 10.0
		var a := _clock * 6.0 + i * 0.9
		var r := tile * (0.1 + h * 0.4)
		var at := foot + Vector2(cos(a) * r, -h * tile * 1.2 + sin(a) * r * 0.25)
		draw_texture_rect(soft, Rect2(at - Vector2.ONE * tile * 0.1, Vector2.ONE * tile * 0.2), false, Color(color, 0.55 * (1.0 - h * 0.6)))


func _draw_blinker(actor: Dictionary, tile: float) -> void:
	var at := _point(float(actor.at[0]), float(actor.at[1])) - Vector2(0, tile * float(actor.get("height", 1.0)) * UP)
	var r := tile * 0.11
	draw_set_transform(at, 0.0, Vector2(1.0, 0.75))
	draw_circle(Vector2.ZERO, r * 2.6, Color("#1c140e"))
	draw_set_transform(Vector2.ZERO)
	var shut := fmod(_clock + float(actor.phase), 4.0) > 3.8
	for side in [-1.0, 1.0]:
		var eye := at + Vector2(side * r * 1.1, 0)
		if shut:
			draw_line(eye - Vector2(r * 0.8, 0), eye + Vector2(r * 0.8, 0), Color("#ffcf3a"), maxf(1.5, r * 0.25))
			continue
		draw_circle(eye, r, Color("#ffcf3a"))
		draw_circle(eye + Vector2(sin(_clock * 0.7) * r * 0.25, 0), r * 0.45, Color("#120c08"))
	draw_colored_polygon(PackedVector2Array([at + Vector2(-r * 0.25, r * 0.5), at + Vector2(r * 0.25, r * 0.5), at + Vector2(0, r * 1.0)]), Color("#f0a020"))



## A crab scuttling sideways, claws up.
func _crab(at: Vector2, size: float, color: Color) -> void:
	var ink := color.darkened(0.6)
	var line := maxf(1.0, size * 0.12)
	var bob := absf(sin(_clock * 16.0)) * size * 0.12
	var body := at - Vector2(0, size * 0.5 + bob)
	_shadow(at, size * 1.1)
	for side in [-1.0, 1.0]:
		for leg in 3:
			var foot := at + Vector2(side * size * (0.55 + leg * 0.22), -size * 0.05)
			draw_line(body + Vector2(side * size * 0.4, size * 0.1), foot, ink, line)
		var claw := body + Vector2(side * size * 0.75, -size * 0.45 - absf(sin(_clock * 3.0)) * size * 0.15)
		draw_line(body + Vector2(side * size * 0.45, -size * 0.1), claw, ink, line * 1.5)
		draw_circle(claw, size * 0.2 + line, ink)
		draw_circle(claw, size * 0.2, color)
	draw_set_transform(body, 0.0, Vector2(1.0, 0.65))
	draw_circle(Vector2.ZERO, size * 0.55 + line, ink)
	draw_circle(Vector2.ZERO, size * 0.55, color)
	draw_set_transform(Vector2.ZERO)
	for side in [-1.0, 1.0]:
		var eye := body + Vector2(side * size * 0.18, -size * 0.38)
		draw_line(body + Vector2(side * size * 0.15, -size * 0.2), eye, ink, line)
		draw_circle(eye, size * 0.1, Color.WHITE)
		draw_circle(eye, size * 0.05, ink)


## A kite on its string, dipping and swooping (City Park).
func _kite(actor: Dictionary, tile: float) -> void:
	var colors: Array = actor.get("colors", ["#ff5a5a", "#ffd23f"])
	var holder := _point(float(actor.get("at", [12.0, -0.9])[0]), float(actor.get("at", [12.0, -0.9])[1]))
	var sway := Vector2(sin(_clock * 0.9) * tile * 0.6, cos(_clock * 1.3) * tile * 0.15)
	var kite := _point(float(actor.get("at", [12.0, -0.9])[0]) - 1.5, float(actor.get("t", -2.0))) + sway - Vector2(0, tile * 0.6)
	var line := maxf(1.0, tile * 0.02)
	var mid := holder.lerp(kite, 0.5) + Vector2(tile * 0.3, tile * 0.2)
	draw_polyline(PackedVector2Array([holder, mid, kite]), Color(1, 1, 1, 0.8), line, true)
	var r := tile * 0.32
	var angle := sin(_clock * 1.7) * 0.25
	draw_set_transform(kite, angle, Vector2.ONE)
	var shape := PackedVector2Array([Vector2(0, -r), Vector2(r * 0.7, 0), Vector2(0, r * 1.2), Vector2(-r * 0.7, 0)])
	draw_colored_polygon(shape, Color(String(colors[0])))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -r), Vector2(r * 0.7, 0), Vector2(0, 0)]), Color(String(colors[1])))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(-r * 0.7, 0), Vector2(0, r * 1.2)]), Color(String(colors[1])))
	draw_polyline(shape + PackedVector2Array([shape[0]]), UIKit.INK, line * 1.5, true)
	var tail := PackedVector2Array()
	for i in 8:
		tail.append(Vector2(sin(_clock * 6.0 + i * 0.8) * r * 0.25, r * 1.2 + i * r * 0.3))
	draw_polyline(tail, UIKit.INK, line, true)
	draw_set_transform(Vector2.ZERO)
