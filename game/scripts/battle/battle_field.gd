class_name BattleField
extends Control
## Draws a fight and turns taps into field positions. It only reads the
## BattleSim; it never changes it. Team 0 (the player) is at the bottom.
##
## It's built in layers, all inside a "world" node that shakes as one:
##   arena   the rendered arena picture, toned down a little (ground shader)
##   decor   the highlight, food bait, ground effects and ambient motion
##   units   one UnitView per animal, sorted by depth (scripts/fx/unit_view.gd)
##   fx      particles, damage numbers, health bars, projectiles (fx_layer.gd)
##
## Strong hits briefly freeze the fight (hit-stop): the screen asks
## is_frozen() before stepping the battle. How everything looks and moves
## comes from data/feel.json.

signal tapped(at: Vector2i)

const OWN_COLOR := Color("#3d7fd9")
const ENEMY_COLOR := Color("#d94a4a")
const EFFECT_COLORS := {
	"net": Color("#d8c08a"), "air_horn": Color("#ffffff"), "flare": Color("#ff8a3d"),
	"medkit": Color("#5ef08a"), "tranq_dart": Color("#b07cff"), "bait": Color("#c98b4a"),
	"heal": Color("#5ef08a"), "cloud": Color("#9bd36b"), "scare": Color("#ffd166"),
	"stun_pulse": Color("#ffe066"), "rage": Color("#ff9f43"), "tree": Color("#3fbf55"),
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
var _units: Node2D
## Animal views by their key (a herd slot, or the fighter's uid).
var _views := {}
var _by_uid := {}
var _time := 0.0
var _freeze := 0.0
var _freeze_ready := 0.0
var _trauma := 0.0

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
	return minf(size.x / (BattleSim.WIDTH + 2.0 * MARGIN), size.y / (BattleSim.HEIGHT + 2.0 * MARGIN))


func field_scale() -> float:
	return _scale()


## The field sits in the middle, with the arena's scenery around it.
func _origin() -> Vector2:
	var s := _scale()
	return (size - Vector2(BattleSim.WIDTH, BattleSim.HEIGHT) * s) / 2.0


func to_screen(x: float, y: float) -> Vector2:
	return _origin() + Vector2(x, y) * _scale()


func to_field(point: Vector2) -> Vector2i:
	var p := (point - _origin()) / _scale()
	return Vector2i(clampi(roundi(p.x), 0, BattleSim.WIDTH), clampi(roundi(p.y), 0, BattleSim.HEIGHT))


## Screen pixels per sprite pixel for an animal.
func sprite_k(id: String, swarm: bool) -> float:
	var c := "characters"
	var k := _scale() * 1000.0 / UnitSprites.pixels_per_tile(id) * Feel.num(c, "sprite_scale", 1.6)
	return k * (Feel.num(c, "swarm_scale", 0.8) if swarm else 1.0)


func views() -> Array:
	return _views.values()


func view_for_uid(uid: int) -> UnitView:
	return _by_uid.get(uid, null)


# --- Hit-stop and shake ----------------------------------------------------

## True during a hit-stop: the fight should not step.
func is_frozen() -> bool:
	return _freeze > 0.0


## Freezes the fight for `seconds` (not again until the cooldown passes).
func hit_stop(seconds: float) -> void:
	if seconds <= 0.0 or _freeze_ready > 0.0:
		return
	_freeze = maxf(_freeze, seconds)
	_freeze_ready = Feel.num("combat", "hitstop_cooldown", 0.3)


## Shakes the field; `amount` from 0 to 1 (bigger shakes stack).
func shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


# --- Input -----------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
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
	_time += dt
	_trauma = maxf(0.0, _trauma - delta / maxf(0.05, Feel.num("combat", "shake_seconds", 0.3)))
	var strength := Feel.num("combat", "shake_pixels", 8.0) * _trauma * _trauma
	_world.position = Vector2(randf_range(-strength, strength), randf_range(-strength, strength)) if strength > 0.1 else Vector2.ZERO
	if sim != null:
		_sync_views(dt)
	fx._process_fx(dt)
	_ambient(delta)
	for v in _views.values():
		v.animate(dt, _time)
		v.position = to_screen(v.render_pos().x, v.render_pos().y)
	_remove_finished()
	_decor.queue_redraw()
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
			_views[key] = v
			_units.add_child(v)
			v.position = to_screen(at.x, at.y)
			fx.burst_spawn(v.position)
		v.sync(f, at, dt, _time)
		seen[key] = true
		_by_uid[f.uid] = v
	for key in _views.keys():
		var v: UnitView = _views[key]
		if not seen.has(key) and v.defeat < 0.0:
			# Gone without a fight (the herds were cleared): no fuss.
			_drop_view(key)


func _remove_finished() -> void:
	for key in _views.keys():
		if _views[key].is_done():
			_drop_view(key)


func _drop_view(key: Variant) -> void:
	var v: UnitView = _views[key]
	_views.erase(key)
	v.queue_free()


# --- Ambient motion --------------------------------------------------------

## Cloud shadows and grass tufts (made again when the field's size changes),
## and drifting petals, leaves or snow to suit the arena.
func _ambient(delta: float) -> void:
	var b := "background"
	if size != _ambient_size and size.x > 0.0:
		_ambient_size = size
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
	var field := Rect2(_origin(), Vector2(BattleSim.WIDTH, BattleSim.HEIGHT) * s)
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

## Turns battle events into animation and effects.
func add_events(events: Array) -> void:
	var s := _scale()
	for e in events:
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
			"hit":
				_on_hit(e)
			"death":
				var v := view_for_uid(e.uid)
				if v != null:
					fx.burst_defeat(v.middle())
					v.start_defeat()
					hit_stop(Feel.num("combat", "hitstop_defeat_seconds", 0.07))
					shake(Feel.num("combat", "shake_defeat", 0.08))
				else:
					fx.burst("puff", to_screen(e.x, e.y), 6, 90.0, 0.4, 10.0, [Color(1, 1, 1, 0.9)], -30.0, 3.0)
			"heal":
				var at := to_screen(e.x, e.y)
				fx.effect("ring", at, mini(e.radius, BattleSim.WIDTH) * s, EFFECT_COLORS.heal, 0.6, "", true)
				fx.burst_heal(at - Vector2(0, 14))
			"cloud", "scare", "stun_pulse", "rage":
				fx.effect("ring", to_screen(e.x, e.y), mini(e.radius, BattleSim.WIDTH) * s, EFFECT_COLORS[e.type], 0.6, "", true)
				if e.type == "rage":
					fx.burst("sparkle", to_screen(e.x, e.y) - Vector2(0, 12), 8, 170.0, 0.5, 8.0, [Color("#ff9f43"), Color("#ffe14d")], -60.0, 3.0)
			"tree":
				fx.effect("area", to_screen(e.x, e.y), e.radius * s, EFFECT_COLORS.tree, e.seconds, "", true)
			"emerge":
				fx.effect("dust", to_screen(e.x, e.y), 800 * s, Color("#b49a78"), 0.5, "", true)
				fx.effect("text", to_screen(e.x, e.y), 0, Color.WHITE, 0.8, _event_word(e.type))
			"dodge", "play_dead", "revive", "roll_up", "sleep", "pounce":
				fx.effect("text", to_screen(e.x, e.y), 0, Color.WHITE, 0.8, _event_word(e.type))


func _on_hit(e: Dictionary) -> void:
	var s := _scale()
	var target := view_for_uid(e.to)
	var attacker := view_for_uid(e.from)
	var dir := Vector2(e.x - e.fx, e.y - e.fy).normalized()
	var strong := false
	if target != null and target.fighter != null:
		strong = float(e.amount) >= float(target.fighter.max_hp) * Feel.num("combat", "strong_hit_pct", 22) / 100.0
	var style := UnitSprites.attack_style(attacker.id) if attacker != null else ""
	if style in ["charge", "stomp", "pounce_bite", "dive"]:
		strong = strong or float(e.amount) >= 150.0
	if attacker != null:
		attacker.strike(_time, Vector2(e.x - e.fx, e.y - e.fy))
	var at := to_screen(e.x, e.y)
	if target != null:
		target.hurt(dir, strong)
		at = target.middle()
	_impact(style, at, dir, s)
	fx.burst_hit(at, strong, Vector2(dir.x, dir.y * 0.6))
	var kind := "hurt_enemy" if target == null or target.team == 1 else "hurt_own"
	fx.number(at + Vector2(0, -10), int(e.amount), kind, strong, target.key if target != null else null)
	if strong:
		hit_stop(Feel.num("combat", "hitstop_seconds", 0.055))
		shake(Feel.num("combat", "shake_strong_hit", 0.12))


## A hit effect that fits how the attacker fights.
func _impact(style: String, at: Vector2, dir: Vector2, s: float) -> void:
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
			shake(Feel.num("combat", "shake_stomp", 0.18))
		"dive":
			effect = fx.effect("feathers", at, 500 * s, Color("#f1ede4"), 0.5)
	if not effect.is_empty():
		effect.dir = dir


## The sounds that go with battle events (tools, hits, deaths...).
static func play_sounds(events: Array) -> void:
	for e in events:
		match e.type:
			"tool":
				Sound.play("horn" if e.card == "air_horn" else "tool")
			"hit":
				Sound.play("hit", -7.0, 0.2)
			"death":
				Sound.play("death", -6.0, 0.15)
			"heal", "tree":
				Sound.play("heal", -4.0)
			"dodge", "play_dead", "pounce", "emerge", "sleep":
				Sound.play("pop", -6.0, 0.2)


## A word floating up from a spot on the field, e.g. an animal's mood.
func say(x: int, y: int, text: String, color := Color.WHITE, life := 1.2) -> void:
	fx.effect("text", to_screen(x, y) - Vector2(0, 20), 0, color, life, text)


func _event_word(kind: String) -> String:
	return {
		"dodge": "Dodge!", "play_dead": "Playing dead...", "revive": "Back up!", "roll_up": "Rolled up!",
		"sleep": "Zzz", "pounce": "Pounce!", "emerge": "Surprise!",
	}.get(kind, "")


# --- Drawing ---------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), grass.darkened(0.25))


## The rendered arena (or plain grass), under everything.
func _draw_arena(canvas: CanvasItem) -> void:
	var s := _scale()
	var field := Rect2(_origin(), Vector2(BattleSim.WIDTH, BattleSim.HEIGHT) * s)
	var ground := arena_art(arena_id)
	if not ground.is_empty():
		# The rendered arena: the fenced field and themed scenery around it.
		var top_left := to_screen(ground.area.position.x, ground.area.position.y)
		var bottom_right := to_screen(ground.area.end.x, ground.area.end.y)
		canvas.draw_texture_rect(ground.texture, Rect2(top_left, bottom_right - top_left), false)
		return
	# Plain grass: tile stripes, the halfway line and the center ring.
	canvas.draw_rect(Rect2(Vector2.ZERO, size).grow(20), grass.darkened(0.15))
	canvas.draw_rect(field, grass)
	var tile := BattleSim.TILE * s
	for row in BattleSim.HEIGHT / BattleSim.TILE:
		for col in BattleSim.WIDTH / BattleSim.TILE:
			if (row + col) % 2 == 0:
				canvas.draw_rect(Rect2(field.position + Vector2(col, row) * tile, Vector2(tile, tile)), Color(1, 1, 1, 0.035))
	var middle := to_screen(0, BattleSim.MIDDLE).y
	canvas.draw_line(Vector2(field.position.x, middle), Vector2(field.end.x, middle), Color(1, 1, 1, 0.35), 3.0)
	canvas.draw_arc(field.get_center(), tile * 2.2, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
	canvas.draw_rect(field, Color(0.25, 0.18, 0.1, 0.8), false, 4.0)


## Over the ground, under the animals: the highlight, bait and ground effects.
func _draw_decor(canvas: CanvasItem) -> void:
	if sim == null:
		return
	var s := _scale()
	var field := Rect2(_origin(), Vector2(BattleSim.WIDTH, BattleSim.HEIGHT) * s)
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
			var top := to_screen(0, BattleSim.MIDDLE + DraftMatch.START_GAP).y
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
