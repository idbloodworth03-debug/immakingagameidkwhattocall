class_name BattleField
extends Control
## Draws a fight and turns taps into field positions. It only reads the
## BattleSim; it never changes it. Team 0 (the player) is at the bottom.
##
## It's built in layers, all inside a "world" node that shakes as one:
##   arena   the rendered arena picture, toned down a little (ground shader)
##   decor   the highlight, food bait, ground effects and ambient motion
##   ground  every animal's shadow, team ring and class badge
##   units   one UnitView per animal, sorted by depth (scripts/fx/unit_view.gd)
##   fx      particles, damage numbers, health bars, projectiles (fx_layer.gd)
##
## A hit shows when it lands, not when the fight deals it: the attacker's
## wind-up plays first (and a shot flies) and only then do the flash, the
## sparks, the number, the health bar's drop and a defeat show (_impacts).
## Big hits briefly freeze the fight (hit-stop): the screen asks
## is_frozen() before stepping the battle. Animals are nudged apart on
## screen so their pictures don't pile up (_spread_views); that never moves
## them in the fight. How everything looks and moves comes from
## data/feel.json.

signal tapped(at: Vector2i)
## A strong hit (see _land) by one of `team`'s animals.
signal strong_hit(team: int)

const OWN_COLOR := Color("#3d7fd9")
const ENEMY_COLOR := Color("#d94a4a")
const EFFECT_COLORS := {
	"net": Color("#d8c08a"), "air_horn": Color("#ffffff"), "flare": Color("#ff8a3d"),
	"medkit": Color("#5ef08a"), "tranq_dart": Color("#b07cff"), "bait": Color("#c98b4a"),
	"splash": Color("#7fd3ff"),
}
## How much of the arena around the field to show, in field units.
const MARGIN := 600.0
const ARENA_ART := "res://art/arenas/"
const GROUND_SHADER := preload("res://scripts/fx/ground.gdshader")

static var _arena_meta := {}
static var _arena_textures := {}
static var _soft: GradientTexture2D

var sim: BattleSim
var grass := Color("#5f9e4f")
## Which arena's rendered ground to draw (art/arenas/); plain grass without one.
var arena_id := ""
## How far we are between the last tick and the next (0-1), for smooth motion.
var blend := 0.0
## What to light up: "" (nothing), "own_half" (where the player's animals
## may start) or "field" (anywhere: aiming a tool or a Rally).
var highlight := ""

var fx: FxLayer

var _world: Node2D
var _arena: Node2D
var _decor: Node2D
## Every animal's shadow, team ring and class badge, in one layer under them
## all (so a big herd's are drawn in a few batches, not a few per animal).
var _ground: Node2D
var _units: Node2D
## Animal views by their key (a herd slot, or the fighter's uid).
var _views := {}
var _by_uid := {}
var _time := 0.0
## A celebration close-up: {"view", "age"} while zooming on an animal.
var _focus := {}
var _freeze := 0.0
var _freeze_ready := 0.0
var _trauma := 0.0
## Hits on their way: {"at": when they land, "e": the fight's event,
## "target", "attacker": views, "after": events that land with them}.
var _impacts: Array = []
## Set by a test to keep a note of every hit as it lands (see _land).
var impact_log: Array = []
var log_impacts := false

## The camera: how big a field it shows (1 = the smallest field), easing
## toward the field's real size so it zooms out smoothly as the field grows.
var _view_k := 1.0
var _arena_k := 0.0

var _plain := false
var _last_on_field := 0
var _k_frame := -1
var _k_base := 1.0
var _k_swarm := 1.0

var _press_at := Vector2.ZERO
var _pressed := false
## Ambient life: cloud shadows drifting over, grass tufts swaying.
var _clouds: Array = []
var _tufts: Array = []
var _ambient_size := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	# The arena and animals are drawn smaller than their pictures.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_world = Node2D.new()
	add_child(_world)
	_arena = _Painter.new(_draw_arena)
	var ground := ShaderMaterial.new()
	ground.shader = GROUND_SHADER
	ground.set_shader_parameter("saturation", Feel.num("background", "arena_saturation", 0.82))
	ground.set_shader_parameter("brightness", Feel.num("background", "arena_brightness", 1.02))
	_arena.material = ground
	_world.add_child(_arena)
	_decor = _Painter.new(_draw_decor)
	_world.add_child(_decor)
	_ground = _Painter.new(_draw_unit_ground)
	_world.add_child(_ground)
	_units = Node2D.new()
	_units.y_sort_enabled = true
	_world.add_child(_units)
	fx = FxLayer.new(self)
	_world.add_child(fx)
	resized.connect(_arena.queue_redraw)


## A node that draws with a function from the field.
class _Painter:
	extends Node2D
	var paint: Callable

	func _init(painter: Callable) -> void:
		paint = painter

	func _draw() -> void:
		paint.call(self)


# --- Coordinates -----------------------------------------------------------

func _scale() -> float:
	return minf(size.x / ((BattleSim.WIDTH + 2.0 * MARGIN) * _view_k), size.y / ((BattleSim.HEIGHT + 2.0 * MARGIN) * _view_k))


func field_scale() -> float:
	return _scale()


## The field's size this fight, in field units.
func _field_size() -> Vector2:
	return Vector2(sim.width, sim.height) if sim != null else Vector2(BattleSim.WIDTH, BattleSim.HEIGHT)


## How much bigger than its smallest size the field is this fight.
func _field_k() -> float:
	return _field_size().x / BattleSim.WIDTH


## The field sits in the middle, with the arena's scenery around it.
func _origin() -> Vector2:
	return (size - _field_size() * _scale()) / 2.0


func to_screen(x: float, y: float) -> Vector2:
	return _origin() + Vector2(x, y) * _scale()


func to_field(point: Vector2) -> Vector2i:
	var p := (point - _origin()) / _scale()
	var field := _field_size()
	return Vector2i(clampi(roundi(p.x), 0, int(field.x)), clampi(roundi(p.y), 0, int(field.y)))


## Shows the whole field right away, without the zoom (e.g. a new match).
func snap_camera() -> void:
	_view_k = _field_k()
	_arena.queue_redraw()


## A crowded field (feel.json "crowd"): simpler effects, so it stays readable
## and smooth.
func _check_crowd() -> void:
	var on_field := 0
	if sim != null:
		for f in sim.fighters:
			if f.alive and f.kind == "unit":
				on_field += 1
	fx.crowded = on_field >= Feel.count("crowd", "crowded_from_units", 24)
	fx.density = Feel.num("crowd", "particles_when_crowded", 0.5) if fx.crowded else 1.0
	# The plain look for animals is chosen when the herds come on (more
	# animals than before), so it doesn't change in the middle of a fight.
	if on_field > _last_on_field:
		var plain := fx.crowded and Feel.on("crowd", "plain_animals_when_crowded", true)
		if plain != _plain:
			_plain = plain
			for v in _views.values():
				v.set_shaded(not _plain)
	_last_on_field = on_field


## Eases the camera toward the field's size this fight.
func _follow_field(delta: float) -> void:
	var target := _field_k()
	if is_equal_approx(_view_k, target):
		return
	var rate := 1.0 / maxf(0.05, Feel.num("camera", "zoom_seconds", 0.8))
	_view_k = lerpf(_view_k, target, 1.0 - exp(-delta * rate * 3.0))
	if absf(_view_k - target) < 0.002:
		_view_k = target
	_arena.queue_redraw()


## Screen pixels per sprite pixel for an animal.
func sprite_k(id: String, swarm: bool) -> float:
	var c := "characters"
	var k := _scale() * 1000.0 / UnitSprites.pixels_per_tile(id) * Feel.num(c, "sprite_scale", 1.6)
	return k * (Feel.num(c, "swarm_scale", 0.8) if swarm else 1.0)


## The same for a sheet drawn at `per_tile` pixels per tile, with this
## frame's scale worked out once for every animal.
func sprite_k_per_tile(per_tile: float, swarm: bool) -> float:
	var frame := Engine.get_process_frames()
	if frame != _k_frame:
		_k_frame = frame
		var c := "characters"
		_k_base = _scale() * 1000.0 * Feel.num(c, "sprite_scale", 1.6)
		_k_swarm = Feel.num(c, "swarm_scale", 0.8)
	return _k_base / per_tile * (_k_swarm if swarm else 1.0)


func views() -> Array:
	return _views.values()


## The field's own clock (seconds; stops during hit-stop, slows in a close-up).
func now() -> float:
	return _time


## The winning herd celebrates, each a moment apart (feel.json "acting").
func celebrate_team(team: int) -> void:
	for v: UnitView in _views.values():
		if v.team == team and v.defeat < 0.0 and not v.doomed:
			v.celebrate(_time + randf() * 0.3)


func end_celebrations() -> void:
	for v: UnitView in _views.values():
		v.stop_celebrating()


func view_for_uid(uid: int) -> UnitView:
	return _by_uid.get(uid, null)


func view_for_key(key: Variant) -> UnitView:
	return _views.get(key, null)


# --- Hit-stop and shake ----------------------------------------------------

## True during a hit-stop: the fight should not step.
func is_frozen() -> bool:
	return _freeze > 0.0


## Freezes the fight for `seconds` (not again until the cooldown passes).
func hit_stop(seconds: float) -> void:
	if seconds <= 0.0 or _freeze_ready > 0.0:
		return
	_freeze = maxf(_freeze, seconds)
	# A crowded fight has a knockout every moment: pause for fewer of them.
	_freeze_ready = Feel.num("crowd", "hitstop_cooldown_when_crowded", 2.0) if fx.crowded else Feel.num("combat", "hitstop_cooldown", 0.9)


## Shakes the field; `amount` from 0 to 1 (bigger shakes stack).
func shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


## A slow-motion close-up on one animal (its view key): zoom in, hold,
## zoom out (data/feel.json, "celebrations"). False if it isn't on the field.
func celebrate(key: Variant) -> bool:
	var v: UnitView = _views.get(key, null)
	if v == null:
		return false
	_focus = {"view": v, "age": 0.0}
	return true


func is_celebrating() -> bool:
	return not _focus.is_empty()


## How far into the close-up we are (0 to 1 and back) this frame.
func _focus_amount(delta: float) -> float:
	if _focus.is_empty():
		return 0.0
	var c := "celebrations"
	var zoom_in := Feel.num(c, "star3_zoom_in_seconds", 0.28)
	var hold := Feel.num(c, "star3_hold_seconds", 0.9)
	var zoom_out := Feel.num(c, "star3_zoom_out_seconds", 0.4)
	_focus.age += delta
	var age: float = _focus.age
	if age < zoom_in:
		return Ease.out_cubic(age / zoom_in)
	if age < zoom_in + hold:
		return 1.0
	if age < zoom_in + hold + zoom_out:
		return 1.0 - Ease.in_out_sine((age - zoom_in - hold) / zoom_out)
	_focus = {}
	return 0.0


# --- Input -----------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if is_celebrating():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_at = event.position
			_pressed = true
		elif _pressed:
			_pressed = false
			if event.position.distance_to(_press_at) < 24.0:
				tapped.emit(to_field(event.position))


# --- Every frame -----------------------------------------------------------

func _process(delta: float) -> void:
	var dt := delta
	_freeze_ready = maxf(0.0, _freeze_ready - delta)
	if _freeze > 0.0:
		_freeze -= delta
		dt = 0.0
	# A celebration close-up slows everything down while it zooms in.
	var focus := _focus_amount(delta)
	dt *= lerpf(1.0, Feel.num("celebrations", "star3_slow_motion", 0.3), focus)
	_time += dt
	_trauma = maxf(0.0, _trauma - delta / maxf(0.05, Feel.num("combat", "shake_seconds", 0.3)))
	var strength := Feel.num("combat", "shake_pixels", 8.0) * _trauma * _trauma
	var shake_offset := Vector2(randf_range(-strength, strength), randf_range(-strength, strength)) if strength > 0.1 else Vector2.ZERO
	var zoom := 1.0
	var pan := Vector2.ZERO
	if focus > 0.0 and is_instance_valid(_focus.get("view")):
		var v: UnitView = _focus.view
		var target := v.position + Vector2(0, -UnitSprites.top(v.id) * v.body.k * 0.4)
		zoom = lerpf(1.0, Feel.num("celebrations", "star3_zoom", 1.45), focus)
		# Bring the animal toward the middle as we zoom in on it.
		pan = target.lerp(size / 2.0, focus) - target * zoom
	_world.scale = Vector2(zoom, zoom)
	_world.position = pan + shake_offset
	_follow_field(delta)
	_check_crowd()
	if sim != null:
		_sync_views(dt)
		_spread_views(dt)
	_land_due()
	fx._process_fx(dt)
	_ambient(delta)
	for v in _views.values():
		v.animate(dt, _time)
		v.position = to_screen(v.render_pos().x, v.render_pos().y)
	_remove_finished()
	_decor.queue_redraw()
	_ground.queue_redraw()
	fx.queue_redraw()


func _sync_views(dt: float) -> void:
	var seen := {}
	_by_uid.clear()
	for f in sim.fighters:
		if not f.alive or not f.is_unit() or not UnitSprites.has(f.card.id):
			continue
		var key: Variant = f.memory.get("view_key", f.uid)
		var v: UnitView = _views.get(key, null)
		if v != null and (v.defeat >= 0.0 or v.id != f.card.id):
			_drop_view(key)
			v = null
		var at := Vector2(lerpf(f.prev_x, f.x, blend), lerpf(f.prev_y, f.y, blend))
		if v == null:
			v = UnitView.make(self, f, key)
			v.set_shaded(not _plain)
			_views[key] = v
			_units.add_child(v)
			v.position = to_screen(at.x, at.y)
			fx.burst_spawn(v.position)
		v.sync(f, at, dt, _time)
		seen[key] = true
		_by_uid[f.uid] = v
	for key in _views.keys():
		var v: UnitView = _views[key]
		if v.doomed and v.defeat < 0.0:
			# Beaten, waiting for the last hits to land: settle where it stands.
			if dt > 0.0:
				v.follow(v.pos + v.spread, Vector2.ZERO, dt)
		elif not seen.has(key) and v.defeat < 0.0:
			# Gone without a fight (the herds were cleared): no fuss.
			_drop_view(key)


## Nudges animals apart on screen until their pictures don't cover each
## other (the pictures are bigger than the room each takes in the fight),
## easing back once there's space. Only the drawing moves. A flier and an
## animal under it are nudged less (they're at different heights).
## Neighbors are found with a coarse grid, so big herds stay cheap.
func _spread_views(dt: float) -> void:
	if dt <= 0.0:
		return
	var m := "movement"
	var enemy_share := Feel.num(m, "spread_enemy_share", 1.0)
	var sideways := Feel.num(m, "spread_sideways", 0.5)
	var air_share := Feel.num(m, "spread_air_share", 0.5)
	var cell := 2500.0
	var list: Array[UnitView] = []
	var grid := {}
	for v: UnitView in _views.values():
		if v.defeat >= 0.0 or v.doomed or v.fighter == null or v.fighter.memory.get("burrowing", false) or v.hop_t < 1.0:
			continue
		var c := v.pos + v.spread
		var gk := (floori(c.x / cell) + 64) * 4096 + floori(c.y / cell) + 64
		if not grid.has(gk):
			grid[gk] = []
		grid[gk].append(list.size())
		list.append(v)
	for i in list.size():
		var a := list[i]
		var ca := a.pos + a.spread
		var gx := floori(ca.x / cell) + 64
		var gy := floori(ca.y / cell) + 64
		for x in range(gx - 1, gx + 2):
			for y in range(gy - 1, gy + 2):
				for j: int in grid.get(x * 4096 + y, []):
					if j <= i:
						continue
					var b := list[j]
					var want := (a.spread_r + b.spread_r) * (1.0 if a.team == b.team else enemy_share)
					if a.flying != b.flying:
						want *= air_share
					var d := ca - (b.pos + b.spread)
					var dist2 := d.length_squared()
					if dist2 >= want * want:
						continue
					var dist := sqrt(dist2)
					# Exactly on top of each other: part them in a set direction.
					var n := d / dist if dist > 1.0 else Vector2.from_angle(float((a.uid * 31 + b.uid * 17) % 628) / 100.0)
					# One straight behind the other: step aside as well, so a
					# line staggers instead of staying single file.
					var side := 1.0 if (a.uid + b.uid) % 2 == 0 else -1.0
					n = (n + Vector2(side * sideways * (1.0 - absf(n.x)), 0.0)).normalized()
					var share := (want - dist) * 0.5
					a.push += n * share
					b.push -= n * share
	var k := 1.0 - exp(-dt * Feel.num(m, "spread_rate", 8.0))
	var back := exp(-dt * Feel.num(m, "spread_return_rate", 1.0))
	var most := Feel.num(m, "spread_max_tiles", 1.0) * 1000.0
	for v in list:
		v.spread = ((v.spread + v.push * k) * back).limit_length(most)
		v.push = Vector2.ZERO


func _remove_finished() -> void:
	for key in _views.keys():
		if _views[key].is_done():
			_drop_view(key)


## Every hit whose time has come lands, and every beaten animal whose last
## hit has landed is defeated.
func _land_due() -> void:
	if not _impacts.is_empty():
		var due: Array = []
		var later: Array = []
		for hit in _impacts:
			(due if float(hit.at) <= _time else later).append(hit)
		_impacts = later
		for hit in due:
			_land(hit)
	for v: UnitView in _views.values():
		if v.doomed and v.defeat < 0.0 and _time >= v.doom_at:
			_defeat_view(v)


func _drop_view(key: Variant) -> void:
	var v: UnitView = _views[key]
	_views.erase(key)
	v.queue_free()


# --- Ambient motion --------------------------------------------------------

## Cloud shadows and grass tufts (made again when the field's size changes),
## and drifting petals, leaves or snow to suit the arena.
func _ambient(delta: float) -> void:
	var b := "background"
	if (size != _ambient_size or _arena_k != _view_k) and size.x > 0.0:
		_ambient_size = size
		_arena_k = _view_k
		_make_ambient()
	var tile := BattleSim.TILE * _scale()
	for c in _clouds:
		c.pos += Vector2(1.0, 0.35) * Feel.num(b, "cloud_speed", 0.22) * tile * delta
		if c.pos.x - c.r > size.x:
			c.pos = Vector2(-c.r * 1.2, randf() * size.y)
	var wanted := Feel.count(b, "petals", 7)
	var drifting := 0
	for p in fx.particles:
		if p.kind == "petal":
			drifting += 1
	if drifting < wanted and randf() < delta * 1.5:
		var style := _ambient_style()
		var start := Vector2(randf_range(-0.2, 0.8) * size.x, -10.0) if randf() < 0.6 else Vector2(-10.0, randf() * size.y * 0.7)
		var vel := Vector2(randf_range(14.0, 30.0), randf_range(18.0, 32.0)) * (0.6 if style.snow else 1.0)
		var colors: Array = style.colors
		fx.particle("petal", start, vel, randf_range(9.0, 14.0), randf_range(2.5, 4.0), colors[randi() % colors.size()], 0.0, 0.0, randf_range(-1.5, 1.5))


## What drifts through this arena.
func _ambient_style() -> Dictionary:
	match arena_id:
		"frozen_tundra", "cloudpeak_mountains":
			return {"snow": true, "colors": [Color(1, 1, 1, 0.85), Color("#e6f3ff", 0.8)]}
		"whispering_woods", "emerald_jungle", "misty_marsh":
			return {"snow": false, "colors": [Color("#8fd16a", 0.8), Color("#d9b44a", 0.75), Color("#6fb84f", 0.8)]}
		"red_rock_canyon", "sunbaked_savanna":
			return {"snow": false, "colors": [Color("#f2d9a6", 0.6), Color("#e8c07a", 0.55)]}
	return {"snow": false, "colors": [Color("#ffc6dd", 0.85), Color(1, 1, 1, 0.8), Color("#fff1a8", 0.8)]}


func _make_ambient() -> void:
	var b := "background"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(arena_id)
	_clouds.clear()
	for i in Feel.count(b, "cloud_shadows", 3):
		_clouds.append({"pos": Vector2(rng.randf() * size.x, rng.randf() * size.y), "r": size.x * rng.randf_range(0.18, 0.3)})
	# Grass tufts around the edges, outside the fence and just inside it.
	_tufts.clear()
	var s := _scale()
	var field := Rect2(_origin(), _field_size() * s)
	var inner := field.grow(-BattleSim.TILE * s * 0.6)
	var tries := 0
	while _tufts.size() < Feel.count(b, "grass_tufts", 46) and tries < 2000:
		tries += 1
		var at := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		if inner.has_point(at):
			continue
		_tufts.append({"pos": at, "h": rng.randf_range(6.0, 11.0), "phase": rng.randf() * TAU, "shade": rng.randf_range(-0.15, 0.25)})


func _draw_ambient(canvas: CanvasItem) -> void:
	var b := "background"
	var alpha := Feel.num(b, "cloud_alpha", 0.09)
	var soft := _soft_texture()
	for c in _clouds:
		# A soft shadow, fading out to nothing at the edge.
		var r: float = c.r
		canvas.draw_texture_rect(soft, Rect2(c.pos - Vector2(r, r * 0.55), Vector2(r * 2.0, r * 1.1)), false, Color(0.02, 0.08, 0.14, alpha))
	var sway_amount := Feel.num(b, "grass_sway", 1.0)
	var snowy: bool = _ambient_style().snow
	var base := grass.lightened(0.05)
	for t in _tufts:
		# Three blades bending in the breeze (frosty ones on snow).
		var sway := sin(_time * 1.8 + float(t.phase) + float(t.pos.x) * 0.01) * 3.0 * sway_amount
		var color := base.lightened(t.shade) if float(t.shade) > 0.0 else base.darkened(-float(t.shade))
		var edge := color.darkened(0.25)
		if snowy:
			color = Color(1, 1, 1, 0.85)
			edge = Color("#9cc3dd", 0.5)
		for blade in 3:
			var foot: Vector2 = t.pos + Vector2((blade - 1) * 3.0, 0)
			var lean := (blade - 1) * 2.5 + sway * (0.7 + blade * 0.15)
			var tip := foot + Vector2(lean, -float(t.h) * (0.8 if blade != 1 else 1.0))
			canvas.draw_line(foot, tip, edge, 3.0)
			canvas.draw_line(foot, tip, color, 1.6)


## A soft round blob, solid in the middle and clear at the edge.
static func _soft_texture() -> GradientTexture2D:
	if _soft == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.55, Color(1, 1, 1, 0.65))
		_soft = GradientTexture2D.new()
		_soft.gradient = gradient
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(1.0, 0.5)
		_soft.width = 128
		_soft.height = 128
	return _soft


# --- Effects ---------------------------------------------------------------

## Turns battle events into animation and effects. A hit is shown when it
## lands (see _schedule_hit); what it caused (a defeat, a splash, a stun:
## the events right after it) waits and lands with it.
func add_events(events: Array) -> void:
	var chain: Dictionary = {}
	for e in events:
		match e.type:
			"hit":
				chain = _schedule_hit(e)
			"death":
				_doom(e, float(chain.at) if not chain.is_empty() else _time)
			"splash", "stun":
				if not chain.is_empty() and float(chain.at) > _time:
					chain.after.append(e)
				else:
					_show(e)
			_:
				chain = {}
				_show(e)


## Effects for an event, now.
func _show(e: Dictionary) -> void:
	var s := _scale()
	match e.type:
		"tool":
			var at := to_screen(e.x, e.y)
			var color: Color = EFFECT_COLORS.get(e.effect, Color.WHITE)
			fx.effect("ring", at, maxi(e.radius, 600) * s, color, 0.6, "", true)
			fx.effect("icon", at - Vector2(0, 10), maxi(e.radius, 900) * s, color, 0.7)
			fx.burst("puff", at, 8, 160.0, 0.5, 12.0, [Color(color, 0.85), Color(1, 1, 1, 0.8)], 0.0, 3.0)
			fx.burst("sparkle", at, 6, 200.0, 0.5, 7.0, [color.lightened(0.4), Color.WHITE], -40.0, 3.0)
			if e.effect in ["flare", "air_horn"]:
				shake(Feel.num("combat", "shake_tool", 0.25))
		"emerge":
			# A burrower pops up: a spray of earth.
			var at := to_screen(e.x, e.y)
			fx.effect("dust", at, 900 * s, Color("#b49a78"), 0.55, "", true)
			fx.burst("puff", at, 6, 120.0, 0.45, 9.0, [Color("#c9b08a"), Color("#e6d3b0")], 200.0, 2.0, 120.0)
		"splash":
			var at := to_screen(e.x, e.y)
			fx.effect("ring", at, e.radius * s, EFFECT_COLORS.splash, 0.45, "", true)
			fx.burst("puff", at, 6, 150.0, 0.4, 7.0, [Color("#bfeaff"), Color.WHITE], 260.0, 2.0, 140.0)
			Sound.play("pop", -6.0, 0.2)
		"stun":
			var v := view_for_uid(e.uid)
			var top := v.middle() - Vector2(0, 18) if v != null else to_screen(e.x, e.y)
			fx.burst("star", top, 4, 70.0, 0.9, 7.0, [Color("#ffe14d"), Color.WHITE], 0.0, 2.5)
			Sound.play("pop", -6.0, 0.2)
		"sleep":
			var at := to_screen(e.x, e.y) - Vector2(0, 18)
			fx.burst("sparkle", at, 5, 50.0, 1.0, 7.0, [EFFECT_COLORS.tranq_dart, Color.WHITE], -70.0, 2.0)


## A hit the fight just dealt: the attacker's strike plays (its wind-up
## first, if none is showing yet), a shot flies if it's thrown, and the hit
## lands when that strike or shot does. Until then the target's health bar
## doesn't drop.
func _schedule_hit(e: Dictionary) -> Dictionary:
	var target := view_for_uid(e.to)
	var attacker := view_for_uid(e.from)
	var hit := {"at": _time, "e": e, "target": target, "attacker": attacker, "after": [], "sim_at": _time, "read": false}
	if attacker != null and attacker.defeat < 0.0 and not attacker.doomed:
		var toward := Vector2(e.x - e.fx, e.y - e.fy)
		var delay := attacker.time_to_strike(_time, toward)
		var strike_at := _time + delay
		hit.read = attacker.attacking(strike_at) and strike_at - attacker.attack_at >= attacker.windup_seconds() * 0.6
		if bool(e.get("ranged", false)):
			var c := "combat"
			var tiles := toward.length() / 1000.0
			var flight := clampf(tiles / maxf(0.1, Feel.num(c, "shot_tiles_per_second", 14.0)), Feel.num(c, "shot_min_seconds", 0.12), Feel.num(c, "shot_max_seconds", 0.32))
			flight = fx.shoot(attacker, target, Vector2(e.x, e.y), delay, flight)
			delay += flight
		hit.at = _time + delay
	if target != null and target.fighter != null:
		hit.max_hp = target.fighter.max_hp
		target.pending_damage += int(e.get("dealt", e.amount))
		target.incoming += 1
		target.update_hp()
	if float(hit.at) <= _time:
		_land(hit)
	else:
		_impacts.append(hit)
	return hit


## A beaten animal: its defeat shows once the hits on their way to it land
## (at `at` or later), or now.
func _doom(e: Dictionary, at: float) -> void:
	var v := view_for_uid(e.uid)
	if v == null:
		fx.burst("puff", to_screen(e.x, e.y), 6, 90.0, 0.4, 10.0, [Color(1, 1, 1, 0.9)], -30.0, 3.0)
		return
	v.doomed = true
	v.doom_at = maxf(v.doom_at, at)
	for hit in _impacts:
		if hit.target == v:
			v.doom_at = maxf(v.doom_at, float(hit.at))
	# A beat after the last hit lands, so the flinch reads before the poof.
	v.doom_at += Feel.num("combat", "defeat_after_hit_seconds", 0.1)
	if v.doom_at <= _time:
		_defeat_view(v)


func _defeat_view(v: UnitView) -> void:
	fx.burst_defeat(v.middle())
	v.start_defeat()
	var winner := v.last_attacker
	if is_instance_valid(winner) and winner.defeat < 0.0 and not winner.doomed:
		winner.gloat(_time)
	Sound.play("death", -6.0, 0.15)
	# A pack animal's knockout is small news; anyone else's gets a beat.
	if not v.swarm:
		hit_stop(Feel.num("combat", "hitstop_defeat_seconds", 0.07))
	shake(Feel.num("combat", "shake_defeat", 0.08))


## A hit lands: the target flinches and flashes, sparks fly, its number pops
## and its bar drops. Big hits (feel.json big_hit_pct) also freeze the
## fight for a moment and shake it; ordinary ones don't.
func _land(hit: Dictionary) -> void:
	var e: Dictionary = hit.e
	var s := _scale()
	var target: UnitView = hit.target if is_instance_valid(hit.target) else null
	var attacker: UnitView = hit.attacker if is_instance_valid(hit.attacker) else null
	var dir := Vector2(e.x - e.fx, e.y - e.fy).normalized()
	var amount := int(e.amount)
	var max_hp := float(hit.get("max_hp", 0))
	var c := "combat"
	var strong := max_hp > 0.0 and amount >= max_hp * Feel.num(c, "strong_hit_pct", 22) / 100.0
	var big := max_hp > 0.0 and amount >= max_hp * Feel.num(c, "big_hit_pct", 35) / 100.0
	var style := UnitSprites.attack_style(attacker.id) if attacker != null else ""
	if style in ["charge", "stomp", "pounce_bite", "dive"]:
		strong = strong or amount >= 150
	var at := to_screen(e.x, e.y)
	if target != null:
		target.pending_damage = maxi(0, target.pending_damage - int(e.get("dealt", amount)))
		target.incoming = maxi(0, target.incoming - 1)
		target.update_hp()
		if attacker != null:
			target.last_attacker = attacker
		if target.defeat < 0.0:
			target.hurt(dir, strong)
		at = target.middle()
	# Busy fights keep the biggest hits' sparks and marks (fx.allow_sparks).
	if fx.allow_sparks(amount) or strong:
		if strong or not fx.crowded:
			_impact(style, at, dir, s, big)
		fx.burst_hit(at, strong, Vector2(dir.x, dir.y * 0.6))
	var kind := "hurt_enemy" if target == null or target.team == 1 else "hurt_own"
	fx.number(at + Vector2(0, -10), amount, kind, strong, target.key if target != null else null)
	Sound.play("hit", -7.0, 0.2)
	if big:
		hit_stop(Feel.num(c, "hitstop_seconds", 0.055))
		shake(Feel.num(c, "shake_strong_hit", 0.12))
	if strong and attacker != null:
		strong_hit.emit(attacker.team)
	for after in hit.after:
		_show(after)
	if log_impacts:
		impact_log.append({"time": _time, "team": attacker.team if attacker != null else -1, "read": bool(hit.get("read", false)), "late": _time - float(hit.sim_at)})


## A hit effect that fits how the attacker fights.
func _impact(style: String, at: Vector2, dir: Vector2, s: float, big: bool) -> void:
	var effect := {}
	match style:
		"swipe":
			effect = fx.effect("slash", at, 520 * s, Color.WHITE, 0.28)
		"bite", "pounce_bite":
			effect = fx.effect("chomp", at, 420 * s, Color.WHITE, 0.22)
		"charge":
			effect = fx.effect("dust", at, 700 * s, Color("#c9b08a"), 0.5)
		"stomp":
			fx.effect("ring", at, 1500 * s, Color("#a88a62"), 0.45, "", true)
			effect = fx.effect("dust", at, 1000 * s, Color("#c9b08a"), 0.6)
			if big:
				shake(Feel.num("combat", "shake_stomp", 0.18))
		"dive":
			effect = fx.effect("feathers", at, 500 * s, Color("#f1ede4"), 0.5)
	if not effect.is_empty():
		effect.dir = dir


## The sounds that go with battle events as they happen (tools, a burrower
## popping up...). Hits, defeats, splashes and stuns sound when they land
## on screen (see _land).
static func play_sounds(events: Array) -> void:
	for e in events:
		match e.type:
			"tool":
				Sound.play("horn" if e.card == "air_horn" else "tool")
			"emerge", "sleep":
				Sound.play("pop", -6.0, 0.2)


# --- Drawing ---------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), grass.darkened(0.25))


## The rendered arena (or plain grass), under everything. A bigger field
## (big herds) gets the same arena, bigger, so its fence still fits.
func _draw_arena(canvas: CanvasItem) -> void:
	var s := _scale()
	var field_k := _field_k()
	var field := Rect2(_origin(), _field_size() * s)
	var ground := arena_art(arena_id)
	if not ground.is_empty():
		# The rendered arena: the fenced field and themed scenery around it.
		var area: Rect2 = ground.area
		var top_left := to_screen(area.position.x * field_k, area.position.y * field_k)
		var bottom_right := to_screen(area.end.x * field_k, area.end.y * field_k)
		var art := Rect2(top_left, bottom_right - top_left)
		canvas.draw_texture_rect(ground.texture, art, false)
		# On a tall (or wide) screen the picture ends before the screen does:
		# mirrored copies carry the scenery on to the edges.
		if art.position.y > 0.0:
			canvas.draw_set_transform(Vector2(art.position.x, art.position.y), 0.0, Vector2(1, -1))
			canvas.draw_texture_rect(ground.texture, Rect2(Vector2.ZERO, art.size), false)
		if art.end.y < size.y:
			canvas.draw_set_transform(Vector2(art.position.x, art.end.y + art.size.y), 0.0, Vector2(1, -1))
			canvas.draw_texture_rect(ground.texture, Rect2(Vector2.ZERO, art.size), false)
		if art.position.x > 0.0:
			canvas.draw_set_transform(Vector2(art.position.x, art.position.y), 0.0, Vector2(-1, 1))
			canvas.draw_texture_rect(ground.texture, Rect2(Vector2.ZERO, art.size), false)
		if art.end.x < size.x:
			canvas.draw_set_transform(Vector2(art.end.x + art.size.x, art.position.y), 0.0, Vector2(-1, 1))
			canvas.draw_texture_rect(ground.texture, Rect2(Vector2.ZERO, art.size), false)
		canvas.draw_set_transform(Vector2.ZERO)
		return
	# Plain grass: tile stripes, the halfway line and the center ring.
	canvas.draw_rect(Rect2(Vector2.ZERO, size).grow(20), grass.darkened(0.15))
	canvas.draw_rect(field, grass)
	var tile := BattleSim.TILE * s
	var tiles := Vector2i((_field_size() / BattleSim.TILE).ceil())
	for row in tiles.y:
		for col in tiles.x:
			if (row + col) % 2 == 0:
				canvas.draw_rect(Rect2(field.position + Vector2(col, row) * tile, Vector2(tile, tile)).intersection(field), Color(1, 1, 1, 0.035))
	var middle := to_screen(0, sim.middle if sim != null else BattleSim.MIDDLE).y
	canvas.draw_line(Vector2(field.position.x, middle), Vector2(field.end.x, middle), Color(1, 1, 1, 0.35), 3.0)
	canvas.draw_arc(field.get_center(), tile * 2.2, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
	canvas.draw_rect(field, Color(0.25, 0.18, 0.1, 0.8), false, 4.0)


## Shadows and rings first, then the class badges: their circles, then the
## icons a class at a time, so each kind of picture is drawn in one batch.
func _draw_unit_ground(canvas: CanvasItem) -> void:
	var badges := []
	for v in _views.values():
		v.draw_ground(canvas, badges)
	for b in badges:
		var info := GameData.class_info(String(b[0]))
		if not info.is_empty():
			var r := float(b[2]) + 1.5
			GroundArt.draw(canvas, GroundArt.Cell.DISC, b[1] + Vector2(0, 1.5), r + 1.5, 1.0, Color(UIKit.INK, float(b[3]) * 0.8))
			GroundArt.draw(canvas, GroundArt.Cell.DISC, b[1], r, 1.0, Color(Color(String(info.color)), float(b[3])))
	for cls in GameData.class_order:
		var texture := UIKit.icon(GameData.ui_icon(String(GameData.class_info(cls).get("icon", ""))))
		if texture == null:
			continue
		for b in badges:
			if b[0] == cls:
				var side := float(b[2]) * 1.3
				canvas.draw_texture_rect(texture, Rect2(b[1] - Vector2(side, side) / 2.0, Vector2(side, side)), false, Color(1, 1, 1, float(b[3])))


## Over the ground, under the animals: the highlight, bait and ground effects.
func _draw_decor(canvas: CanvasItem) -> void:
	if sim == null:
		return
	var s := _scale()
	var field := Rect2(_origin(), _field_size() * s)
	_draw_ambient(canvas)
	_draw_highlight(canvas, field)
	fx.draw_ground(canvas)
	for f in sim.fighters:
		if f.alive and f.kind == "bait":
			_draw_bait(canvas, f, s)


func _draw_highlight(canvas: CanvasItem, field: Rect2) -> void:
	var area := field
	match highlight:
		"own_half":
			var top := to_screen(0, sim.middle).y
			area = Rect2(field.position.x, top, field.size.x, field.end.y - top)
		"field":
			pass
		_:
			return
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	canvas.draw_rect(area, Color(1, 1, 0.6, 0.1 + 0.06 * pulse))
	canvas.draw_rect(area.grow(-2), Color(1, 1, 0.6, 0.7), false, 3.0)


func _draw_bait(canvas: CanvasItem, f: BattleSim.Fighter, s: float) -> void:
	var p := to_screen(f.x, f.y)
	var r := f.radius * s
	var bob := sin(_time * 6.0) * 1.5
	canvas.draw_circle(p + Vector2(0, r * 0.4), r * 0.9, Color(0, 0, 0, 0.2))
	canvas.draw_circle(p + Vector2(0, bob), r + 2, Color("#5a3a1a"))
	canvas.draw_circle(p + Vector2(0, bob), r, Color("#c98b4a"))
	var bait_icon := UIKit.icon(GameData.ui_icon("bait"))
	if bait_icon != null:
		canvas.draw_texture_rect(bait_icon, Rect2(p + Vector2(0, bob) - Vector2(r, r) * 0.75, Vector2(r, r) * 1.5), false, Color.WHITE)


## An arena's rendered ground: {"texture", "area": the field units it covers}
## or {} if it has none.
static func arena_art(id: String) -> Dictionary:
	if id == "":
		return {}
	if _arena_meta.is_empty():
		var text := FileAccess.get_file_as_string(ARENA_ART + "arenas.json")
		_arena_meta = JSON.parse_string(text) if text != "" else {"none": true}
	if not _arena_meta.has("x"):
		return {}
	if not _arena_textures.has(id):
		var path := ARENA_ART + id + ".webp"
		_arena_textures[id] = load(path) if ResourceLoader.exists(path) else null
	if _arena_textures[id] == null:
		return {}
	var x: Array = _arena_meta.x
	var y: Array = _arena_meta.y
	var area := Rect2(float(x[0]) * BattleSim.TILE, float(y[0]) * BattleSim.TILE,
			(float(x[1]) - float(x[0])) * BattleSim.TILE, (float(y[1]) - float(y[0])) * BattleSim.TILE)
	return {"texture": _arena_textures[id], "area": area}
