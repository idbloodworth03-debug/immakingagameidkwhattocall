class_name BattleField
extends Control
## Draws a fight and turns taps into field positions. It only reads the
## BattleSim; it never changes it. Team 0 (the player) is at the bottom.
##
## It's built in layers, all inside a "world" node that shakes as one:
##   arena   the rendered arena picture, toned down a little (ground shader)
##   decor   the highlight, food bait, ground effects and ambient motion
##   life    the crowd, flags and the rest outside the fence (ArenaLife)
##   ground  every animal's shadow, team ring and class badge
##   models  the animals as real 3D models, when use_models (ModelStage)
##   units   one UnitView per animal, sorted by depth (scripts/fx/unit_view.gd):
##           its sprite, or (use_models) only its style props over its model
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

## The two sides' colors in battle (rings, health bars, banners): the UI's
## own bold player and enemy colors (ui_style.json).
static func own_color() -> Color:
	return UIStyle.color("player")


static func enemy_color() -> Color:
	return UIStyle.color("enemy")


static func team_color(team: int) -> Color:
	return own_color() if team == 0 else enemy_color()

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
## How fast the field plays (the screen speeds a dragging ending up; it
## steps the fight at the same pace).
var playback := 1.0
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
## A close-up: {"view", "age", and its zoom, slow motion and timings} while
## zooming on an animal (a 3-star upgrade, the last knockout of a fight).
var _focus := {}
var _freeze := 0.0
var _freeze_ready := 0.0
var _trauma := 0.0
## Hits on their way: {"at": when they land, "e": the fight's event,
## "target", "attacker": views, "after": events that land with them}.
var _impacts: Array = []
## When each shooter's latest shot lands (field time, by its uid): what it
## sets off (a bounce, a pierce, a spray) lands with it.
var _shot_land := {}
## Set by a test to keep a note of every hit as it lands (see _land).
var impact_log: Array = []
var log_impacts := false
## The last animal knocked out, and when (for the fight's final close-up).
var _last_defeated: UnitView
var _last_defeat_at := -1.0
var _spread_dt := 0.0

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
var _press_ms := 0
## The squad picked with a tap (its group; -1: none), its team, and when
## its target lines started showing (field time) (feel.json "readability"
## squad_*).
var picked_group := -1
var picked_team := 0
var _picked_at := -100.0
## Busy spots (feel.json "crowd" busy_*): how many animals stand in each
## square of a coarse grid, made once a frame; and what happened to the
## hits that landed (for reports).
var _busy_grid := {}
var _busy_stamp := []
var noise := {"hits": 0, "busy": 0, "quieted": 0}
## Ambient life: cloud shadows drifting over, grass tufts swaying.
var _clouds: Array = []
var _tufts: Array = []
var _ambient_size := Vector2.ZERO
## The battle-line camera (armies only): how far it's zoomed in from the
## whole field, and the point of the field in the middle of the screen.
var _zoom := 1.0
var _cam := Vector2(-1, -1)
## Which army the camera frames: -1 both (a fight), 0 or 1 just that one
## (the army shown while picking); only that army is drawn then.
var frame_team := -1
## New animals walk into their places instead of popping in, and animals
## moved to new places walk there instead of hopping (the army shown while
## picking).
var walk_in := false
## The camera's limits here, if not feel.json's (the army shown while
## picking is a short, wide strip: it needs to zoom in much further).
var camera_max_zoom := -1.0
var camera_min_tiles := -1.0
var camera_margin := -1.0
var _banners: Node2D
var _last_steps := [-1, -1]
var _life: ArenaLife
## Show the animals as real 3D models (ModelStage) instead of sprites:
## feel.json "models" "enabled" unless a screen says otherwise before adding
## the field.
var use_models := Feel.on("models", "enabled", false)
var _stage: ModelStage


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	# Hold an animal for its info (HoldInfo).
	add_to_group("hold_info_field")
	# The arena and animals are drawn smaller than their pictures.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_world = Node2D.new()
	add_child(_world)
	_arena = _Painter.new(_draw_arena)
	var ground := ShaderMaterial.new()
	ground.shader = GROUND_SHADER
	ground.set_shader_parameter("saturation", Feel.num("background", "arena_saturation", 1.0))
	ground.set_shader_parameter("brightness", Feel.num("background", "arena_brightness", 1.02))
	_arena.material = ground
	_world.add_child(_arena)
	_decor = _Painter.new(_draw_decor)
	_world.add_child(_decor)
	_ground = _Painter.new(_draw_unit_ground)
	_world.add_child(_ground)
	if use_models:
		_stage = ModelStage.make(self)
		_world.add_child(_stage)
	_units = Node2D.new()
	_units.y_sort_enabled = true
	_world.add_child(_units)
	_banners = _Painter.new(_draw_banners)
	_world.add_child(_banners)
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
	return _base_scale() * _zoom


## The scale that shows the whole field.
func _base_scale() -> float:
	return minf(size.x / ((BattleSim.WIDTH + 2.0 * MARGIN) * _view_k), size.y / ((BattleSim.HEIGHT + 2.0 * MARGIN) * _view_k))


func field_scale() -> float:
	return _scale()


## How much bigger than its smallest size the field is this fight (the
## arena picture and its life grow with it).
func field_k_now() -> float:
	return _field_k()


## The arena's life (ArenaLife), made for the arena shown, under the animals.
func _keep_life() -> void:
	if _life != null and _life.arena_id == arena_id:
		return
	if _life != null:
		_life.queue_free()
	_life = ArenaLife.make(self, arena_id)
	_world.add_child(_life)
	# Over the arena and its grass tufts, under the animals' shadows.
	_world.move_child(_life, _decor.get_index() + 1)


## A big moment at field point `at`: the crowd cheers.
func _cheer(at: Vector2, power: float) -> void:
	if _life != null:
		_life.cheer(at.x / (1000.0 * _field_k()), power)


## The field's size this fight, in field units.
func _field_size() -> Vector2:
	return Vector2(sim.width, sim.height) if sim != null else Vector2(BattleSim.WIDTH, BattleSim.HEIGHT)


## How much bigger than its smallest size the field is this fight.
func _field_k() -> float:
	return _field_size().x / BattleSim.WIDTH


## The field sits in the middle, with the arena's scenery around it (or,
## with the battle-line camera, the point it looks at does).
func _origin() -> Vector2:
	var look := _cam if _cam.x >= 0.0 else _field_size() / 2.0
	return size / 2.0 - look * _scale()


func to_screen(x: float, y: float) -> Vector2:
	return _origin() + Vector2(x, y) * _scale()


## A screen point as a field position (field units, not clamped).
func screen_to_field(point: Vector2) -> Vector2:
	return (point - _origin()) / _scale()


func to_field(point: Vector2) -> Vector2i:
	var p := (point - _origin()) / _scale()
	var field := _field_size()
	return Vector2i(clampi(roundi(p.x), 0, int(field.x)), clampi(roundi(p.y), 0, int(field.y)))


## Shows the whole field right away, without the zoom (e.g. a new match),
## or the armies, framed.
func snap_camera() -> void:
	_view_k = _field_k()
	_frame_armies(0.0, true)
	_arena.queue_redraw()


## The battle-line camera: frames every animal still standing (or one
## army's, frame_team), with some room around them (feel.json "army"),
## never closer than camera_min_tiles across and never beyond the arena.
## Eases there over camera_seconds; `snap` goes at once.
func _frame_armies(delta: float, snap := false) -> void:
	if sim == null or sim.army == null or size.x <= 0.0:
		if _zoom != 1.0 or _cam.x >= 0.0:
			_zoom = 1.0
			_cam = Vector2(-1, -1)
			_arena.queue_redraw()
		return
	var a := "army"
	var box := Rect2()
	var first := true
	for f: BattleSim.Fighter in sim.fighters:
		if not f.alive or not f.is_unit() or (frame_team >= 0 and f.team != frame_team):
			continue
		var p := Vector2(f.x, f.y)
		if first:
			box = Rect2(p, Vector2.ZERO)
			first = false
		else:
			box = box.expand(p)
	if first:
		return
	var margin := (camera_margin if camera_margin >= 0.0 else Feel.num(a, "camera_margin_tiles", 2.2)) * 1000.0
	box = box.grow(margin)
	# Room above for the animals' heads and banners.
	box = box.grow_individual(0, margin * 0.6 + Feel.num(a, "camera_head_room_tiles", 1.2) * 1000.0, 0, 0)
	# Near the far fence, the camera eases on past it to show the crowd
	# (ArenaLife): all of scenery_back_tiles when the view already reaches
	# the fence, none from scenery_reach_tiles away.
	var back := Feel.num("camera", "scenery_back_tiles", 1.7) * 1000.0 * _field_k()
	var reach := Feel.num("camera", "scenery_reach_tiles", 3.0) * 1000.0 * _field_k()
	if box.position.y < reach and back > 0.0:
		var near := clampf((reach - box.position.y) / reach, 0.0, 1.0)
		var top := minf(box.position.y, lerpf(box.position.y, -back, near))
		box = box.grow_individual(0, box.position.y - top, 0, 0)
	var base := _base_scale()
	var least := (camera_min_tiles if camera_min_tiles > 0.0 else Feel.num(a, "camera_min_tiles", 10.0)) * 1000.0
	var w := maxf(box.size.x, least)
	var h := maxf(box.size.y, least * size.y / maxf(1.0, size.x))
	var most := minf(camera_max_zoom if camera_max_zoom > 0.0 else Feel.num(a, "camera_max_zoom", 1.7), _size_zoom_cap(base))
	var zoom := clampf(minf(size.x / (w * base), size.y / (h * base)), 1.0, maxf(1.0, most))
	var look := box.get_center()
	# Keep the view on the arena.
	var half := size / (2.0 * base * zoom)
	var field := _field_size()
	look.x = clampf(look.x, half.x - MARGIN, field.x + MARGIN - half.x) if half.x * 2.0 < field.x + 2.0 * MARGIN else field.x / 2.0
	var above := maxf(MARGIN, back)
	look.y = clampf(look.y, half.y - above, field.y + MARGIN - half.y) if half.y * 2.0 < field.y + MARGIN + above else (field.y + MARGIN - above) / 2.0
	if snap or _cam.x < 0.0:
		_zoom = zoom
		_cam = look
	else:
		var k := 1.0 - exp(-delta * 3.0 / maxf(0.05, Feel.num(a, "camera_seconds", 0.9)))
		_zoom = lerpf(_zoom, zoom, k)
		_cam = _cam.lerp(look, k)
	_arena.queue_redraw()


## The zoom past which an animal on the field would look bigger than
## bodies.json "limits" allows (a share of the screen's height: unit_max_pct
## for any animal, hero_max_pct for a Mythic hero), from each one's standing
## height at its drawn size (ModelStage.natural_box "up"; a bird's is its
## body's, not its wingspan). So animals never get bigger than that, even
## in a small fight. INF with nothing on the field.
func _size_zoom_cap(base: float) -> float:
	if sim == null:
		return INF
	var limits: Dictionary = GameData.bodies.get("limits", {})
	var short := 1.0 - float(limits.get("camera_margin_pct", 4.0)) / 100.0
	var unit_max := float(limits.get("unit_max_pct", 9.0)) / 100.0 * short
	var hero_max := float(limits.get("hero_max_pct", 10.0)) / 100.0 * short
	var screen := screen_height()
	var cap := INF
	for f: BattleSim.Fighter in sim.fighters:
		if not f.alive or not f.is_unit() or (frame_team >= 0 and f.team != frame_team):
			continue
		var up := float(ModelStage.natural_box(f.card.id).up) * UnitView.draw_k(f)
		if up <= 0.0:
			continue
		var limit := hero_max if f.memory.get("hero", false) else unit_max
		cap = minf(cap, limit * screen / (up * base * 1000.0))
	return cap


## True while `team`'s army is marching forward this tick.
func marching(team: int) -> bool:
	return sim != null and sim.army != null and int(sim.army.moved_now[team]) > 0


## Where in its walk cycle (0-1) a marching army's feet are, keeping pace
## with the ground it covers: with `cycle` (field units), an animal's own
## stride (its legs cover the ground they walk, no sliding); without, the
## army's shared step (feel.json "army" march_stride_tiles: the stomps).
func march_walk(team: int, cycle := -1.0) -> float:
	if sim == null or sim.army == null:
		return 0.0
	var marched := float(sim.army.marched[team]) - float(sim.army.moved_now[team]) * (1.0 - blend)
	var stride := cycle if cycle > 0.0 else Feel.num("army", "march_stride_tiles", 0.6) * 1000.0
	return fposmod(marched / maxf(1.0, stride), 1.0)


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


## Screen pixels per sprite pixel for an animal at its natural size (the
## view's size_k, from bodies.json, goes on top).
func sprite_k(id: String, swarm: bool) -> float:
	var k := _scale() * 1000.0 / UnitSprites.pixels_per_tile(id)
	return k * (Feel.num("characters", "swarm_scale", 0.8) if swarm else 1.0)


## The same for a sheet drawn at `per_tile` pixels per tile, with this
## frame's scale worked out once for every animal.
func sprite_k_per_tile(per_tile: float, swarm: bool) -> float:
	var frame := Engine.get_process_frames()
	if frame != _k_frame:
		_k_frame = frame
		_k_base = _scale() * 1000.0
		_k_swarm = Feel.num("characters", "swarm_scale", 0.8)
	return _k_base / per_tile * (_k_swarm if swarm else 1.0)


func views() -> Array:
	return _views.values()


## How tall an animal stands on screen now, as a share of the screen's
## height (0 if it isn't a 3D model): the size the player sees it at.
## feel.json "characters" size_pct says how big that may be.
func unit_height_share(v: UnitView) -> float:
	if _stage == null or not v.modeled:
		return 0.0
	return _stage.height_px(v.key) / maxf(1.0, screen_height())


## The screen's height in the field's pixels (the window's, or a stand-in
## for a phone's when a report says so: screen_height_override).
var screen_height_override := 0.0


func screen_height() -> float:
	if screen_height_override > 0.0:
		return screen_height_override
	var viewport := get_viewport()
	return viewport.get_visible_rect().size.y if viewport != null else size.y


## The animal drawn under a point (viewport coordinates), or null: the one
## whose picture's middle is nearest, among those the point is on.
func view_at(point: Vector2) -> UnitView:
	var best: UnitView = null
	var best_d := INF
	for v: UnitView in _views.values():
		if v.defeat >= 0.0 or v.doomed or v.fighter == null or not v.visible or v.body == null:
			continue
		var to_screen_k := v.get_global_transform_with_canvas()
		var feet: Vector2 = to_screen_k * v.body.position
		var h: float = UnitSprites.top(v.id) * v.body.k * absf(v.body.scale.y) * to_screen_k.get_scale().y
		var center := feet - Vector2(0, h * 0.5)
		if absf(point.x - center.x) <= maxf(h * 0.45, 22.0) and absf(point.y - center.y) <= maxf(h * 0.6, 26.0):
			var d := point.distance_to(center)
			if d < best_d:
				best = v
				best_d = d
	return best


## Picks the squad whose banner or animal is at `point` (the field's own
## coordinates): it glows, and lines show to the enemies it's going for.
## The same squad again, or a tap on nothing, lets go of it. The fight
## goes on as ever.
func pick_squad_at(point: Vector2) -> void:
	var group := -1
	var team := 0
	var r := Feel.num("readability", "squad_banner_tap_px", 30.0)
	var best := r
	for b: Dictionary in banners():
		var d := point.distance_to(b.flag)
		if d <= best:
			best = d
			group = int(b.group)
			team = int(b.team)
	if group < 0:
		var v := view_at(get_global_transform_with_canvas() * point)
		if v != null and v.army and v.fighter != null:
			group = int(v.fighter.memory.get("group", -1))
			team = v.team
	if group < 0 or group == picked_group:
		picked_group = -1
		return
	picked_group = group
	picked_team = team
	_picked_at = _time
	Sound.play("pop", -10.0, 0.15)


## The picked squad's animals still standing.
func picked_views() -> Array:
	if picked_group < 0:
		return []
	return _views.values().filter(func(v: UnitView) -> bool:
		return v.fighter != null and v.defeat < 0.0 and not v.doomed and int(v.fighter.memory.get("group", -1)) == picked_group)


## While the picked squad's target lines show: [its animal, the enemy it's
## going for] for each of them with a target on the field.
func picked_targets() -> Array:
	var out := []
	if picked_group < 0 or _time - _picked_at > Feel.num("readability", "squad_lines_seconds", 2.5):
		return out
	for v: UnitView in picked_views():
		var t: BattleSim.Fighter = v.fighter.target
		if t != null and t.alive and t.is_unit():
			var tv := view_for_uid(t.uid)
			if tv != null and tv.defeat < 0.0:
				out.append([v, tv])
	return out


## How many animals stand around a field point (field units): in its square
## of a grid busy_cell_tiles across and the eight round it.
func crowd_near(at: Vector2) -> int:
	var cell := maxf(100.0, Feel.num("crowd", "busy_cell_tiles", 1.5) * BattleSim.TILE)
	var stamp := [Engine.get_process_frames(), _time, _views.size()]
	if stamp != _busy_stamp:
		_busy_stamp = stamp
		_busy_grid.clear()
		for v: UnitView in _views.values():
			if v.defeat < 0.0 and not v.doomed and v.fighter != null:
				var k := Vector2i(floori(v.fighter.x / cell), floori(v.fighter.y / cell))
				_busy_grid[k] = int(_busy_grid.get(k, 0)) + 1
	var c := Vector2i(floori(at.x / cell), floori(at.y / cell))
	var n := 0
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			n += int(_busy_grid.get(c + Vector2i(dx, dy), 0))
	return n


## Whether a hit at `at` (field units) keeps quiet: where at least
## busy_from_units animals stand round it, only big hits and knockouts
## always show; a strong hit shows while fewer than busy_numbers_max numbers
## are up in that spot; anything smaller keeps quiet. A quiet hit still
## lands (the flash, the health bar); only its sparks and a new damage
## number are left out.
func quiet_hit(at: Vector2, strong: bool, big: bool, knockout: bool) -> bool:
	noise.hits += 1
	if crowd_near(at) < Feel.count("crowd", "busy_from_units", 8):
		return false
	noise.busy += 1
	if big or knockout or (strong and numbers_near(at) < Feel.count("crowd", "busy_numbers_max", 1)):
		return false
	noise.quieted += 1
	return true


## How many damage numbers show round a field point (the busy spot's
## size).
func numbers_near(at: Vector2) -> int:
	var reach := Feel.num("crowd", "busy_cell_tiles", 1.5) * BattleSim.TILE * 1.5
	var n := 0
	for num in fx.numbers:
		var p := screen_to_field(num.at)
		if absf(p.x - at.x) < reach and absf(p.y - at.y) < reach:
			n += 1
	return n


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


## An ice blast on the ground at `ground` (screen pixels), `reach` pixels
## across: the Yeti's pound, or a smaller one round a frozen animal
## (fx_layer "ice_blast"; colors from feel.json "styles").
func _ice_blast(ground: Vector2, reach: float, seconds: float, shards: int, cracks: int) -> Dictionary:
	var looks: Dictionary = GameData.feel.get("styles", {})
	var blast := fx.effect("ice_blast", ground, reach, Color(String(looks.get("frost", "#9fe6ff"))), seconds)
	blast.dark = Color(String(looks.get("ice_dark", "#2f7fd6")))
	blast.core = Color(String(looks.get("ice_core", "#ffffff")))
	blast.shards = shards
	blast.cracks = cracks
	return blast


## A slow-motion close-up on one animal (its view key): zoom in, hold,
## zoom out (data/feel.json, "celebrations"). False if it isn't on the field.
func celebrate(key: Variant) -> bool:
	var v: UnitView = _views.get(key, null)
	if v == null:
		return false
	var c := "celebrations"
	_focus = {"view": v, "age": 0.0, "zoom": Feel.num(c, "star3_zoom", 1.45), "slow": Feel.num(c, "star3_slow_motion", 0.3),
		"in": Feel.num(c, "star3_zoom_in_seconds", 0.28), "hold": Feel.num(c, "star3_hold_seconds", 0.9),
		"out": Feel.num(c, "star3_zoom_out_seconds", 0.4)}
	return true


## The fight is over: the last knockout plays in slow motion with a small
## push-in on it (feel.json "choreography"), then the winners celebrate.
## Gives how long that takes, so the score can wait for it.
func finish_fight(winner: int) -> float:
	var c := "choreography"
	# The last one knocked out: still waiting for its blow, or already
	# going down.
	var last: UnitView = null
	var at := -1.0
	for v: UnitView in _views.values():
		var when := v.doom_at if v.doomed else -1.0
		if v.defeat >= 0.0 and v.defeat < 1.0 and v == _last_defeated:
			when = _last_defeat_at
		if when >= 0.0 and when > at:
			last = v
			at = when
	var wait := 0.0
	if last != null:
		var slow := Feel.num(c, "final_slow_motion", 0.35)
		var hold := maxf(0.0, at - _time) / slow + Feel.num(c, "final_hold_seconds", 0.5)
		_focus = {"view": last, "age": 0.0, "zoom": Feel.num(c, "final_zoom", 1.18), "slow": slow,
			"in": Feel.num(c, "final_zoom_in_seconds", 0.2), "hold": maxf(0.2, hold), "out": Feel.num(c, "final_zoom_out_seconds", 0.4)}
		wait = float(_focus.in) + float(_focus.hold)
	if winner >= 0:
		for v: UnitView in _views.values():
			if v.team == winner and v.defeat < 0.0 and not v.doomed:
				v.celebrate(_time + wait * Feel.num(c, "final_slow_motion", 0.35) + randf() * 0.3)
	return wait


## Both herds hop into place, one after another, as a fight begins.
func hop_in() -> void:
	var spread := Feel.num("choreography", "intro_hop_spread_seconds", 0.4)
	for v: UnitView in _views.values():
		if v.defeat < 0.0:
			v.hop_in(_time + randf() * spread)


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
	zoom_in = float(_focus.get("in", zoom_in))
	hold = float(_focus.get("hold", hold))
	zoom_out = float(_focus.get("out", zoom_out))
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
			_press_ms = Time.get_ticks_msec()
			_pressed = true
		elif _pressed:
			_pressed = false
			if event.position.distance_to(_press_at) < 24.0:
				# A quick tap (not a hold for info) with no tool being aimed:
				# picks the squad there (or lets go of it).
				var quick := Time.get_ticks_msec() - _press_ms < roundi(Feel.num("info", "hold_seconds", 0.35) * 1000.0)
				if quick and highlight == "":
					pick_squad_at(event.position)
				tapped.emit(to_field(event.position))


# --- Every frame -----------------------------------------------------------

func _process(delta: float) -> void:
	delta *= playback
	var dt := delta
	_freeze_ready = maxf(0.0, _freeze_ready - delta)
	if _freeze > 0.0:
		_freeze -= delta
		dt = 0.0
	# A celebration close-up slows everything down while it zooms in.
	var slow := float(_focus.get("slow", 1.0))
	var focus := _focus_amount(delta)
	dt *= lerpf(1.0, slow, focus)
	_time += dt
	_trauma = maxf(0.0, _trauma - delta / maxf(0.05, Feel.num("combat", "shake_seconds", 0.3)))
	var strength := Feel.num("combat", "shake_pixels", 8.0) * _trauma * _trauma
	var shake_offset := Vector2(randf_range(-strength, strength), randf_range(-strength, strength)) if strength > 0.1 else Vector2.ZERO
	var zoom := 1.0
	var pan := Vector2.ZERO
	if focus > 0.0 and is_instance_valid(_focus.get("view")):
		var v: UnitView = _focus.view
		var target := v.position + Vector2(0, -UnitSprites.top(v.id) * v.body.k * 0.4)
		zoom = lerpf(1.0, float(_focus.get("zoom", 1.3)), focus)
		# Bring the animal toward the middle as we zoom in on it.
		pan = target.lerp(size / 2.0, focus) - target * zoom
	_world.scale = Vector2(zoom, zoom)
	_world.position = pan + shake_offset
	_follow_field(delta)
	_frame_armies(delta)
	_keep_life()
	_stomp()
	_check_crowd()
	UnitView.refresh_tuning()
	if sim != null:
		_sync_views(dt)
		# Every other frame is plenty for the gentle nudges apart.
		_spread_dt += dt
		if Engine.get_process_frames() % 2 == 0:
			_spread_views(_spread_dt)
			_spread_dt = 0.0
	_land_due()
	fx._process_fx(dt)
	_ambient(delta)
	var glow := 0.0
	if picked_group >= 0:
		glow = 0.65 + 0.35 * sin(_time * Feel.num("readability", "squad_pulse_speed", 4.0))
	for v in _views.values():
		v.animate(dt, _time)
		v.position = to_screen(v.render_pos().x, v.render_pos().y)
		v.m_glow = glow if picked_group >= 0 and v.fighter != null and int(v.fighter.memory.get("group", -1)) == picked_group else 0.0
	if picked_group >= 0 and picked_views().is_empty():
		picked_group = -1  # the whole squad is down
	if _stage != null:
		_stage.sync(_views, _time, dt)
	_remove_finished()
	_decor.queue_redraw()
	_ground.queue_redraw()
	_banners.queue_redraw()
	fx.queue_redraw()


## A marching army stomps in step: one thump (and a tiny shake) for every
## step the whole army takes.
func _stomp() -> void:
	for team in 2:
		if not marching(team) or (frame_team >= 0 and team != frame_team):
			_last_steps[team] = -1
			continue
		var steps := floori(march_walk(team) * 2.0)
		if _last_steps[team] >= 0 and steps != _last_steps[team]:
			Sound.play("land", Feel.num("army", "stomp_volume_db", -16.0), 0.05)
			shake(Feel.num("army", "stomp_shake", 0.03))
		_last_steps[team] = steps


func _sync_views(dt: float) -> void:
	var seen := {}
	_by_uid.clear()
	for f: BattleSim.Fighter in sim.fighters:
		if not f.alive or not f.is_unit() or (frame_team >= 0 and f.team != frame_team):
			continue
		var key: Variant = f.memory.get("view_key", f.uid)
		var v: UnitView = _views.get(key, null)
		if v != null and (v.defeat >= 0.0 or v.id != f.card.id):
			_drop_view(key)
			v = null
		var at := Vector2(lerpf(f.prev_x, f.x, blend), lerpf(f.prev_y, f.y, blend))
		if v == null:
			# (Looked up only for a new view: a big fight syncs dozens a frame.)
			if not UnitSprites.has(f.card.id):
				continue
			v = UnitView.make(self, f, key)
			v.modeled = use_models and ModelStage.has_model(v.id)
			v.set_shaded(not _plain)
			_views[key] = v
			_units.add_child(v)
			v.position = to_screen(at.x, at.y)
			if walk_in and v.army:
				# A new squad marches in from behind its army.
				var back := 1.0 if f.team == 0 else -1.0
				v.walk_to(at + Vector2(0, back * Feel.num("army", "walk_in_tiles", 5.0) * 1000.0), _time)
			else:
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
	var settle := Feel.num(m, "spread_return_rate", 1.0) * 1000.0 * dt
	for v: UnitView in _views.values():
		if v.defeat >= 0.0 or v.doomed or v.fighter == null or v.fighter.memory.get("burrowing", false) or v.hop_t < 1.0:
			continue
		if v.army and (v.walking_in() or (v._placed and not v._in_reach)):
			# In its place in the formation: lines stay clean, no nudging.
			v.spread = v.spread.move_toward(Vector2.ZERO, settle)
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
			color = Color("#f4fbff")
			edge = Color("#8db8d6")
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
			"splash", "stun", "cleave", "pound", "reflect", "slam", "pack_bite", "venom", "triple", "spray", "pierce", \
					"dive_hit", "crack", "grab", "drop", "feast", "tentacles", "chain", "flip", \
					"frost", "freeze", "head_lit", "fire_breath", "beam_heal", "ink":
				# Shown when the hit they came with lands.
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
		"cleave", "pound", "reflect", "shell", "snack", "heal", "rhino_charge", "charge_end", \
				"slam", "pack_bite", "roar", "venom", "triple", "pounce", "spray", "pierce", "spit_charge", \
				"dive_hit", "crack", "grab", "drop", "feast", "fire_line", \
				"dig", "flip", "ball", "slide", "slide_end", "tentacles", "chain", "chest_beat", "shockwave", "stand_tall", \
				"frost", "freeze", "head_lit", "fire_breath", "beam_heal", "scared", "ink", "blind_miss":
			_show_style(e)
		"sleep":
			var at := to_screen(e.x, e.y) - Vector2(0, 18)
			fx.burst("sparkle", at, 5, 50.0, 1.0, 7.0, [EFFECT_COLORS.tranq_dart, Color.WHITE], -70.0, 2.0)
		"clash":
			# The walls meet: a big thump, dust thrown up all along the line.
			var a := "army"
			var at := to_screen(e.x, e.y)
			var dust := Color("#c9b08a")
			fx.effect("ring", at, 2600 * s, Color("#f3e3c0"), 0.55, "", true)
			fx.effect("dust", at, 2000 * s, dust, 0.7)
			for i in 7:
				var along := Vector2((i - 3) * 700.0 * s, 0)
				fx.burst("puff", at + along, 3, 130.0, 0.6, 10.0, [dust, Color("#e6d3b0")], -60.0, 2.5)
			fx.burst("spark", at, 12, 320.0, 0.35, 7.0, [Color("#fff6b0"), Color.WHITE], 0.0, 6.0)
			shake(Feel.num(a, "clash_shake", 0.55))
			hit_stop(Feel.num(a, "clash_hitstop_seconds", 0.12))
			Sound.play("boom", -2.0)
			_cheer(Vector2(e.x, e.y), 1.0)
		"alert":
			# The targeting rules' threat response: it turns on whoever's
			# biting it, with a cartoon "!" over its head.
			var v := view_for_uid(int(e.uid))
			if v != null and v.defeat < 0.0:
				var look := "readability"
				var pop := fx.effect("alert", v.position + v.head(), Feel.num(look, "alert_size", 30.0),
					Feel.color(look, "alert_color", Color("#ffd23f")), Feel.num(look, "alert_seconds", 0.85))
				pop.follow = v
				pop.pop = Feel.num(look, "alert_pop", 3.0)
				Sound.play("pop", -9.0, 0.3)
		"volley":
			# Every Ranged animal lets fly at once.
			Sound.play("whoosh", -3.0, 0.05)
		"charge":
			var at := to_screen(e.x, e.y)
			fx.burst("puff", at, 10, 160.0, 0.6, 9.0, [Color("#c9b08a"), Color("#e6d3b0")], -40.0, 2.5)
			Sound.play("alert", -4.0)
		"war_horn":
			# The whole army surges: a ring of its color sweeping out and
			# every animal springing forward.
			var color := team_color(int(e.team))
			var middle := Vector2.ZERO
			var count := 0
			for v: UnitView in _views.values():
				if v.team == int(e.team) and v.defeat < 0.0 and not v.doomed:
					v.hop_in(_time)
					middle += v.position
					count += 1
			if count > 0:
				fx.effect("ring", middle / count, 5200 * s, color.lightened(0.3), 0.8, "", true)
			shake(Feel.num("army", "war_horn_shake", 0.3))
			_cheer(Vector2(_field_size().x / 2.0, 0.0), 1.0)


## The moments of the animals' attack styles (BattleStyles): a swipe across
## two, a ground pound, a blow bouncing back off a thick hide, a shell, a
## snack, a charge.
func _show_style(e: Dictionary) -> void:
	var s := _scale()
	var looks: Dictionary = GameData.feel.get("styles", {})
	var v := view_for_uid(int(e.get("uid", -1)))
	var at := v.middle() if v != null else to_screen(e.x, e.y)
	match e.type:
		"cleave":
			var a := to_screen(e.ax, e.ay) + Vector2(0, -14)
			var b := to_screen(e.bx, e.by) + Vector2(0, -14)
			var sweep := fx.effect("sweep", at, maxf(at.distance_to(a), at.distance_to(b)) * 1.05, Color.WHITE, Feel.num("styles", "sweep_seconds", 0.3))
			sweep.a_ang = (a - at).angle()
			sweep.b_ang = (b - at).angle()
			_blast("wind", (a + b) / 2.0, 700 * s, false, (b - a).normalized(), false)
			Sound.play("whoosh", -8.0, 0.1)
		"pound":
			# The Yeti's ground pound: a layered ice blast (fx_layer "ice_blast":
			# core, glow, shockwave, shards, cracks), snow thrown up, a shake.
			var ground := to_screen(e.x, e.y)
			var frost := Color(String(looks.get("frost", "#9fe6ff")))
			var snow := Color(String(looks.get("snow", "#f4fbff")))
			_ice_blast(ground, e.radius * s * Feel.num("styles", "ice_blast_reach", 1.1), Feel.num("styles", "ice_blast_seconds", 0.9),
					Feel.count("styles", "ice_shards", 10), Feel.count("styles", "ice_cracks", 6))
			fx.burst("puff", ground, Feel.count("styles", "snow_puffs", 10), 230.0, 0.7, 11.0, [snow, frost.lightened(0.4)], -30.0, 2.5, 40.0)
			fx.burst("sparkle", ground, 14, 300.0, 0.7, 8.0, [frost, Color.WHITE], 260.0, 2.0, 220.0)
			shake(Feel.num("styles", "pound_shake", 0.18))
			Sound.play("boom", -6.0, 0.1)
		"reflect":
			var source := view_for_uid(int(e.to))
			var to := source.middle() if source != null else to_screen(e.x, e.y)
			var hide := Color(String(looks.get("hide", "#c9c3bd")))
			# A ripple across its thick hide, and the bite flung back as a spray
			# of sparks at the attacker.
			fx.effect("ring", at, 900 * s, hide.lightened(0.2), 0.35)
			fx.effect("ring", at, 600 * s, Color.WHITE, 0.25)
			_blast("light", at, 650 * s, false, Vector2.UP, false)
			var dir := (to - at).normalized()
			for i in 8:
				fx.particle("spark", at, dir.rotated(randf_range(-0.5, 0.5)) * randf_range(320.0, 520.0), 0.32, 8.0, Color.WHITE if i % 2 == 0 else hide.lightened(0.3), 0.0, 3.0)
			fx.effect("flash", to, 260 * s, Color(1, 1, 1, 0.7), 0.18)
			if source != null:
				source.hurt(dir, false)
				fx.number(to + Vector2(0, -10), int(e.amount), "hurt_own" if source.team == 0 else "hurt_enemy", false, source.key)
		"shell":
			if e.on:
				fx.burst("puff", at, 6, 140.0, 0.4, 8.0, [Color(String(looks.get("shell_light", "#7fb04a"))), Color("#d8e8c8")], -20.0, 2.5)
				_blast("nature", at, 520 * s, false, Vector2.UP, false)
				Sound.play("land", -4.0, 0.1)
			else:
				Sound.play("pop", -8.0, 0.2)
		"snack":
			if e.on:
				fx.burst("leaf", at, 6, 120.0, 0.7, 8.0, [Color(String(looks.get("bamboo_leaf", "#6fcf4a"))), Color(String(looks.get("bamboo", "#8fd14f")))], 120.0, 2.0, 80.0)
				Sound.play("heal", -6.0)
		"heal":
			if v != null and int(e.amount) > 0:
				fx.number(at + Vector2(0, -16), int(e.amount), "heal", false, v.key)
				fx.burst_heal(at)
		"rhino_charge":
			var dust := Color(String(looks.get("charge_dust", "#c9b08a")))
			fx.effect("dust", to_screen(e.x, e.y), 900 * s, dust, 0.5, "", true)
			_blast("earth", to_screen(e.x, e.y), 600 * s, false)
			fx.burst("sparkle", at - Vector2(0, 12), 3, 90.0, 0.4, 8.0, [Color.WHITE, Color("#fff6b0")], 0.0, 3.0)
			shake(0.1)
			Sound.play("alert", -6.0)
		"charge_end":
			fx.effect("dust", to_screen(e.x, e.y), 700 * s, Color(String(looks.get("charge_dust", "#c9b08a"))), 0.45, "", true)
			_blast("earth", to_screen(e.x, e.y), 900 * s, true)
		"slam":
			# A huge first hit: the Boar's head-on slam, the Tiger's pounce.
			var target := view_for_uid(int(e.to))
			var hit_at := target.middle() if target != null else to_screen(e.x, e.y)
			if String(e.kind) == "stalk":
				var claws := fx.effect("slash", hit_at, 900 * s, Color(String(looks.get("pounce", "#ff9a2e"))), 0.4)
				claws.dir = (hit_at - at).normalized()
			else:
				fx.effect("dust", to_screen(e.x, e.y), 1100 * s, Color(String(looks.get("charge_dust", "#c9b08a"))), 0.55, "", true)
			fx.effect("flash", hit_at, 380 * s, Color(1, 1, 1, 0.8), 0.18)
			_blast("fire" if String(e.kind) == "stalk" else "earth", hit_at, 900 * s, true, (hit_at - at).normalized())
			fx.burst("spark", hit_at, 10, 360.0, 0.3, 8.0, [Color("#fff6b0"), Color.WHITE], 0.0, 5.0)
			shake(Feel.num("styles", "slam_shake", 0.14))
			Sound.play("boom", -8.0, 0.1)
		"pack_bite":
			var target := view_for_uid(int(e.to))
			var hit_at := target.middle() if target != null else to_screen(e.x, e.y)
			var gold := Color(String(looks.get("pack", "#ffd84a")))
			var jaws := fx.effect("chomp", hit_at, 560 * s, gold, 0.3)
			jaws.dir = (hit_at - at).normalized()
			_blast("light", hit_at, 420 * s, false, jaws.dir, false)
			fx.burst("spark", hit_at, 5, 220.0, 0.25, 6.0, [gold, Color.WHITE], 0.0, 5.0)
		"roar":
			var gold := Color(String(looks.get("roar", "#ffc93c")))
			fx.effect("ring", to_screen(e.x, e.y), e.radius * s, gold, 0.6, "", true)
			fx.effect("ring", at, e.radius * s * 0.5, gold.lightened(0.4), 0.45)
			_blast("light", at, 700 * s, true, Vector2.UP, false)
			fx.burst("sparkle", at, 8, 220.0, 0.6, 8.0, [gold, Color.WHITE], -40.0, 2.5)
			Sound.play("alert", -6.0)
		"venom":
			var target := view_for_uid(int(e.to))
			var hit_at := target.middle() if target != null else to_screen(e.x, e.y)
			var green := Color(String(looks.get("venom", "#7ee04a")))
			fx.burst("puff", hit_at, 6, 120.0, 0.5, 7.0, [green, green.lightened(0.4)], 30.0, 2.5)
			_blast("venom", hit_at, 420 * s, false)
			Sound.play("pop", -10.0, 0.2)
		"triple":
			# Three heads: three snaps of fire, one after another.
			var fire := Color(String(looks.get("fire", "#ff6a2a")))
			var bitten: Array = e.get("bitten", [])
			for i in bitten.size():
				var victim := view_for_uid(int(bitten[i]))
				if victim == null:
					continue
				var jaws := fx.effect("chomp", victim.middle() + Vector2((i - 1) * 6.0, (i - 1) * 4.0), 480 * s, fire, 0.3)
				jaws.dir = (victim.middle() - at).normalized()
				jaws.age = -i * Feel.num("styles", "bite_stagger_seconds", 0.07)
				var snap := _blast("fire", victim.middle(), 460 * s, true, jaws.dir, false)
				if not snap.is_empty():
					snap.age = jaws.age
		"pounce":
			fx.burst("puff", to_screen(e.x, e.y), 5, 140.0, 0.4, 7.0, [Color(String(looks.get("pounce", "#ff9a2e"))), Color("#ffe0b0")], -20.0, 3.0)
			_blast("fire", to_screen(e.x, e.y), 450 * s, false)
			Sound.play("whoosh", -6.0, 0.1)
		"spray":
			var toward := to_screen(e.tx, e.ty) - Vector2(0, 10)
			var cone := fx.effect("cone", at, int(e.reach) * s, Color(String(looks.get("spray", "#d6e05a"))), 0.45)
			_blast("stink", toward, int(e.reach) * s * 0.45, false)
			cone.dir = (toward - at).normalized()
			cone.spread = float(e.cone)
			for i in 5:
				var u := (i + 1) / 6.0
				fx.particle("puff", at.lerp(toward, u), (toward - at).normalized() * 60.0, 0.6, 9.0, Color(String(looks.get("stink", "#c8d84a")), 0.7), -20.0, 2.0)
			Sound.play("pop", -9.0, 0.3)
		"pierce":
			var beam := fx.effect("rainbow", at, 22.0, Color.WHITE, 0.4)
			beam.end = to_screen(e.ex, e.ey) - Vector2(0, 12)
			_blast("light", beam.end, 650 * s, true, (beam.end - at).normalized(), false)
			Sound.play("zap", -8.0, 0.1)
		"spit_charge":
			Sound.play("tick", -10.0, 0.2)
		"dive_hit":
			# The Falcon's dive lands: a white flash, feathers and sparks.
			var target := view_for_uid(int(e.to))
			var hit_at := target.middle() if target != null else to_screen(e.x, e.y)
			var white := Color(String(looks.get("speed_lines", "#ffffff")))
			fx.effect("flash", hit_at, 420 * s, Color(white, 0.85), 0.2)
			fx.effect("ring", hit_at, 700 * s, white, 0.3)
			fx.effect("feathers", hit_at, 520 * s, Color("#d9c6a5"), 0.6)
			_blast("wind", hit_at, 650 * s, false, Vector2.DOWN, false)
			fx.burst("spark", hit_at, 8, 380.0, 0.3, 8.0, [white, Color("#fff6b0")], 0.0, 5.0)
			shake(Feel.num("styles", "slam_shake", 0.14) * 0.7)
			Sound.play("whoosh", -6.0, 0.1)
		"crack":
			# The Macaw cracks its target's armor: blue shards flying off.
			var target := view_for_uid(int(e.to))
			var hit_at := target.middle() if target != null else to_screen(e.x, e.y)
			var blue := Color(String(looks.get("crack", "#3d8bff")))
			fx.effect("ring", hit_at, 520 * s, blue, 0.3)
			_blast("lightning", hit_at, 450 * s, false, Vector2.UP, false)
			fx.burst("spark", hit_at, 7, 260.0, 0.35, 7.0, [blue, Color.WHITE], 200.0, 3.0)
			Sound.play("pop", -6.0, 0.3)
		"grab":
			# The Harpy Eagle's talons snatch it up.
			var target := view_for_uid(int(e.to))
			var hit_at := target.middle() if target != null else to_screen(e.x, e.y)
			var claws := fx.effect("slash", hit_at, 760 * s, Color("#f2c14e"), 0.4)
			claws.dir = Vector2.DOWN
			fx.effect("feathers", hit_at, 480 * s, Color("#8a8f99"), 0.6)
			_blast("wind", hit_at, 450 * s, false, Vector2.DOWN, false)
			fx.burst("puff", to_screen(e.x, e.y), 5, 140.0, 0.4, 8.0, [Color("#c9b08a"), Color("#e6d3b0")], -20.0, 2.5)
			Sound.play("whoosh", -4.0, 0.1)
		"drop":
			# ...and drops it far back: a thud and a cloud of dust.
			var ground := to_screen(e.x, e.y)
			fx.effect("dust", ground, 1000 * s, Color(String(looks.get("charge_dust", "#c9b08a"))), 0.5, "", true)
			fx.effect("ring", ground, 800 * s, Color("#f3e3c0"), 0.4, "", true)
			_blast("earth", ground, 850 * s, true)
			shake(Feel.num("styles", "slam_shake", 0.14))
			Sound.play("land", -2.0, 0.1)
		"feast":
			# A wisp flies from the fallen animal into the Condor, which grows.
			var wisp := fx.effect("wisp", to_screen(e.x, e.y) - Vector2(0, 14), 340 * s, Color(String(looks.get("feast", "#b48cff"))), Feel.num("styles", "feast_seconds", 0.45))
			wisp.end = at
			var swell := fx.effect("ring", at, 700 * s, Color(String(looks.get("feast", "#b48cff"))), 0.35)
			swell.age = -Feel.num("styles", "feast_seconds", 0.45)
			var gulp := _blast("dark", at, 520 * s, false, Vector2.UP, false)
			if not gulp.is_empty():
				gulp.age = swell.age
			Sound.play("heal", -10.0, 0.2)
		"fire_line":
			# The Dragon's fire-breath run: a line of fire along the ground,
			# its flames drawn over the animals standing in it.
			var line := fx.effect("fire_line", to_screen(e.x1, e.y1), maxf(8.0, int(e.width) * s), Color(String(looks.get("fire", "#ff6a2a"))), float(e.seconds))
			line.end = to_screen(e.x2, e.y2)
			line.reveal = Feel.num("styles", "fire_reveal_seconds", 0.35)
			line.flame = Color(String(looks.get("flame", "#ffc23a")))
			var scorch := _blast("fire", line.end, 750 * s, true)
			if not scorch.is_empty():
				scorch.age = -float(line.reveal)
			Sound.play("whoosh", -2.0, 0.05)
		"dig":
			# The Fox digs down again: a spray of earth.
			var ground := to_screen(e.x, e.y)
			fx.effect("dust", ground, 900 * s, Color("#b49a78"), 0.55, "", true)
			fx.burst("puff", ground, 6, 120.0, 0.45, 9.0, [Color("#c9b08a"), Color("#e6d3b0")], 200.0, 2.0, 120.0)
			Sound.play("land", -6.0, 0.15)
			_blast("earth", ground, 600 * s, false)
		"flip":
			# The Pangolin bursts up under a Tank and flips it.
			var target := view_for_uid(int(e.to))
			var hit_at := target.middle() if target != null else to_screen(e.x, e.y)
			fx.effect("dust", to_screen(e.x, e.y), 1300 * s, Color("#b49a78"), 0.6, "", true)
			fx.effect("flash", hit_at, 420 * s, Color(1, 1, 1, 0.8), 0.2)
			_blast("earth", to_screen(e.x, e.y), 1000 * s, true)
			fx.burst("puff", to_screen(e.x, e.y), 8, 200.0, 0.5, 10.0, [Color("#c9b08a"), Color("#e6d3b0")], 160.0, 2.0, 160.0)
			shake(Feel.num("styles", "slam_shake", 0.14))
			Sound.play("boom", -6.0, 0.1)
		"ball":
			if e.on:
				fx.burst("puff", at, 5, 120.0, 0.35, 7.0, [Color(String(looks.get("scales", "#a8794f"))), Color("#e6d3b0")], -20.0, 2.5)
				Sound.play("land", -6.0, 0.2)
			else:
				Sound.play("pop", -8.0, 0.2)
		"slide":
			# The Seal flops onto its belly and slides: a spray of water.
			var water := Color(String(looks.get("water", "#9fdcff")))
			fx.effect("ring", to_screen(e.x, e.y), 700 * s, water, 0.35, "", true)
			_blast("water", to_screen(e.x, e.y), 550 * s, false)
			fx.burst("puff", at, 6, 160.0, 0.45, 8.0, [water, Color.WHITE], 220.0, 2.0, 140.0)
			Sound.play("whoosh", -4.0, 0.1)
		"slide_end":
			fx.burst("puff", at, 4, 110.0, 0.4, 7.0, [Color(String(looks.get("water", "#9fdcff"))), Color.WHITE], 220.0, 2.0, 100.0)
		"tentacles":
			# Tentacles reach out and slam down, one after another.
			var color := Color(String(looks.get("tentacle", "#8e5bd6")))
			var spots: Array = e.get("spots", [])
			for i in spots.size():
				var spot := to_screen(spots[i][0], spots[i][1])
				var arm := fx.effect("tentacle", at, maxf(12.0, 380 * s), color, 0.5)
				arm.end = spot
				arm.age = -i * Feel.num("styles", "tentacle_stagger_seconds", 0.08)
				var slam := fx.effect("ring", spot, 900 * s, Color(String(looks.get("water", "#9fdcff"))), 0.4, "", true)
				slam.age = arm.age - 0.15
				var splash := _blast("water", spot, 750 * s, true)
				if not splash.is_empty():
					splash.age = slam.age
			shake(Feel.num("styles", "slam_shake", 0.14))
			Sound.play("boom", -8.0, 0.1)
		"chain":
			# Lightning jumping from one to the next.
			var points := PackedVector2Array()
			for i in e.get("points", []).size():
				var point: Array = e.points[i]
				var who := view_for_uid(int(e.uid)) if i == 0 else null
				points.append(who.middle() if who != null else to_screen(point[0], point[1]) - Vector2(0, 16))
			var bolt := fx.effect("lightning", at, maxf(6.0, 120 * s), Color(String(looks.get("lightning", "#fff27a"))), 0.35)
			bolt.points = points
			for i in range(1, points.size()):
				fx.effect("flash", points[i], 300 * s, Color(1, 1, 0.8, 0.8), 0.18)
				_blast("lightning", points[i], 360 * s, false, Vector2.UP, false)
			Sound.play("zap", -4.0, 0.1)
		"chest_beat":
			# Beating its chest: thumps rippling out.
			for i in 3:
				var thump := fx.effect("ring", at, 500 * s, Color(String(looks.get("shock", "#f3e3c0"))), 0.25)
				thump.age = -i * 0.15
			Sound.play("tick", -2.0, 0.1)
			_blast("earth", at, 420 * s, false, Vector2.UP, false)
		"shockwave":
			var ground := to_screen(e.x, e.y)
			var shock := Color(String(looks.get("shock", "#f3e3c0")))
			fx.effect("ring", ground, e.radius * s, shock, 0.55, "", true)
			fx.effect("ring", ground, e.radius * s * 0.7, Color.WHITE, 0.4, "", true)
			fx.effect("dust", ground, e.radius * s * 0.8, Color("#c9b08a"), 0.6, "", true)
			_blast("earth", ground, e.radius * s * 0.85, true)
			shake(Feel.num("styles", "shock_shake", 0.22))
			Sound.play("boom", -2.0, 0.1)
		"frost":
			# The Yeti's pound leaves a frost patch on the ground.
			var patch := fx.effect("frost_patch", to_screen(e.x, e.y), e.radius * s, Color(String(looks.get("frost_patch", "#c8f2ff"))), float(e.seconds), "", true)
			patch.edge = Color(String(looks.get("frost", "#9fe6ff")))
		"freeze":
			# Frozen solid: a smaller burst of ice round its feet, shards and all.
			var frost := Color(String(looks.get("frost", "#9fe6ff")))
			var feet := v.position if v != null else to_screen(e.x, e.y)
			_ice_blast(feet, 340 * s, 0.6, 6, 4)
			fx.burst("spark", at, 10, 260.0, 0.4, 8.0, [frost, Color.WHITE], 200.0, 3.0)
			Sound.play("pop", -4.0, 0.2)
		"head_lit":
			# A knockout lights one of Cerberus's heads.
			var fire := Color(String(looks.get("fire", "#ff6a2a")))
			fx.burst("spark", at - Vector2(0, 12), 8, 200.0, 0.45, 8.0, [fire, Color(String(looks.get("flame", "#ffc23a")))], -60.0, 3.0)
			_blast("fire", at - Vector2(0, 12), 420 * s, false, Vector2.UP, false)
			Sound.play("whoosh", -8.0, 0.2)
		"fire_breath":
			# A cone of fire from Cerberus's lit head.
			var toward := to_screen(e.tx, e.ty) - Vector2(0, 10)
			var fire := Color(String(looks.get("fire", "#ff6a2a")))
			var flame := Color(String(looks.get("flame", "#ffc23a")))
			var breath := Feel.num("styles", "fire_breath_seconds", 0.45)
			var cone := fx.effect("cone", at, int(e.reach) * s, fire, breath)
			cone.dir = (toward - at).normalized()
			cone.spread = float(e.cone)
			var inner := fx.effect("cone", at, int(e.reach) * s * 0.7, flame, breath * 0.8)
			inner.dir = cone.dir
			inner.spread = float(e.cone) * 0.6
			_blast("fire", toward, int(e.reach) * s * 0.4, true)
			for i in 8:
				var u := (i + 1) / 9.0
				fx.particle("spark", at.lerp(toward, u), cone.dir.rotated(randf_range(-0.4, 0.4)) * 160.0, 0.5, 9.0, flame if i % 2 == 0 else fire, -60.0, 2.0)
			shake(Feel.num("styles", "slam_shake", 0.14) * 0.6)
			Sound.play("boom", -8.0, 0.2)
		"beam_heal":
			# The rainbow heals a teammate it passes through.
			if v != null and int(e.amount) > 0:
				fx.number(at + Vector2(0, -16), int(e.amount), "heal", false, v.key)
				fx.burst("sparkle", at, 6, 140.0, 0.6, 7.0, [Color(String(looks.get("heal_sparkle", "#9dffb0"))), Color.WHITE, Color("#fff176")], -50.0, 2.5)
				_blast("light", at, 360 * s, false, Vector2.UP, false)
		"scared":
			# Panicked by the fire: a "!" and a hop out of it.
			if v != null:
				var pop := fx.effect("alert", v.position + v.head(), Feel.num("readability", "alert_size", 30.0) * 0.8, Color(String(looks.get("panic_color", "#ff9a2e"))), 0.8)
				pop.follow = v
			fx.burst("glow", at - Vector2(0, 14), 4, 120.0, 0.5, 5.0, [Color(String(looks.get("sweat", "#8fd8ff")))], 260.0, 2.0, 80.0)
		"ink":
			# A squirt of ink where the Kraken dragged them.
			var ink := Color(String(looks.get("ink", "#2a1840")))
			# Over the animals (the Kraken's big body would hide it on the ground).
			var cloud := fx.effect("ink_cloud", to_screen(e.x, e.y), e.radius * s, ink, float(e.seconds))
			cloud.puffs = int(looks.get("ink_puffs", 7))
			_blast("dark", to_screen(e.x, e.y), e.radius * s * 0.6, true, Vector2.UP, false)
			fx.burst("puff", to_screen(e.x, e.y), 8, 180.0, 0.5, 11.0, [ink, ink.lightened(0.2)], 0.0, 3.0)
			Sound.play("pop", -6.0, 0.3)
		"blind_miss":
			# A blinded shot fizzles.
			if v != null and randf() < 0.5:
				fx.burst("puff", at - Vector2(0, 10), 2, 60.0, 0.35, 6.0, [Color(String(looks.get("blind_puff", "#6b5585")))], -20.0, 2.0)
		"stand_tall":
			var orange := Color(String(looks.get("panda", "#ff8a3d")))
			fx.effect("ring", to_screen(e.x, e.y), e.radius * s, orange, 0.6, "", true)
			_blast("fire", at, 520 * s, false, Vector2.UP, false)
			fx.burst("sparkle", at - Vector2(0, 14), 6, 160.0, 0.5, 7.0, [orange, Color.WHITE], -30.0, 2.5)
			Sound.play("alert", -4.0, 0.1)


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
		# A charge knocks enemies aside as it runs into them: no wind-up.
		var delay := 0.0 if e.get("charge", false) else attacker.time_to_strike(_time, toward)
		# Cerberus's other heads bite a moment after the first.
		delay += float(e.get("head", 0)) * Feel.num("styles", "bite_stagger_seconds", 0.07)
		var strike_at := _time + delay
		hit.read = attacker.attacking(strike_at) and strike_at - attacker.attack_at >= attacker.windup_seconds() * 0.6
		if bool(e.get("ranged", false)):
			var c := "combat"
			var tiles := toward.length() / 1000.0
			var flight := clampf(tiles / maxf(0.1, Feel.num(c, "shot_tiles_per_second", 14.0)), Feel.num(c, "shot_min_seconds", 0.12), Feel.num(c, "shot_max_seconds", 0.32))
			var arc := 1.0
			if sim != null and sim.army != null:
				# In an army fight, shots go over the teammates in between.
				arc = Feel.num("army", "over_allies_arc", 1.4)
			if e.has("volley"):
				# A volley: higher, slower arcs, so the shots fly as a flock.
				var a := "army"
				flight = clampf(tiles / maxf(0.1, Feel.num(a, "volley_tiles_per_second", 9.0)), Feel.num(a, "volley_min_seconds", 0.45), Feel.num(a, "volley_max_seconds", 0.85))
				arc = Feel.num(a, "volley_arc", 1.8)
			# The shooter's attack style: how its shot flies.
			var st := "styles"
			var scale := 1.0
			var origin: UnitView = null
			match String(e.get("style", "")):
				"lob":
					arc *= Feel.num(st, "lob_arc", 2.2)
					flight *= Feel.num(st, "lob_flight", 1.35)
				"sniper":
					arc *= 0.25
					flight *= Feel.num(st, "sniper_flight", 0.55)
				"spit":
					scale = Feel.num(st, "spit_scale", 2.2)
				"burst":
					scale = Feel.num(st, "pellet_scale", 0.75)
					delay += float(e.get("pellet", 0)) * Feel.num(st, "pellet_stagger_seconds", 0.07)
				"bounce":
					# On from the last one hit, once the fruit lands there.
					origin = view_for_uid(int(e.get("bounce_from", -1)))
					delay = maxf(delay, float(_shot_land.get(int(e.from), _time)) - _time + Feel.num(st, "bounce_seconds", 0.05))
					if origin != null and target != null:
						flight = clampf(origin.pos.distance_to(target.pos) / 1000.0 / maxf(0.1, Feel.num(c, "shot_tiles_per_second", 14.0)), Feel.num(c, "shot_min_seconds", 0.12), Feel.num(c, "shot_max_seconds", 0.32))
			# Into a Sloth's slow-motion zone: the shot crawls.
			if target != null and target.fighter != null and attacker.fighter != null and sim != null \
					and BattleStyles.shot_crawl(sim, attacker.fighter.team, target.fighter) > 0:
				flight *= Feel.num(st, "crawl_flight", 2.0)
			flight = fx.shoot(attacker, target, Vector2(e.x, e.y), delay, flight, arc, scale, origin)
			delay += flight
			_shot_land[int(e.from)] = _time + delay
		elif String(e.get("style", "")) in ["spray", "pierce"]:
			# Hit by the same spray or beam: lands with it.
			delay = maxf(delay, float(_shot_land.get(int(e.from), _time)) - _time)
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
	_last_defeated = v
	_last_defeat_at = _time
	var winner := v.last_attacker
	if is_instance_valid(winner) and winner.defeat < 0.0 and not winner.doomed:
		winner.gloat(_time)
	Sound.play("death", -6.0, 0.15)
	if not v.swarm:
		_cheer((v.render_pos()), 0.75)
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
	if bool(e.get("guard", false)) and target != null:
		# The Elephant took a shot for a teammate: a shield flashes up.
		var shield := fx.effect("shield", target.middle(), UnitSprites.top(target.id) * target.body.k * 0.7,
			Color(String(GameData.feel.get("styles", {}).get("shield", "#7fc8ff"))), Feel.num("styles", "shield_seconds", 0.45))
		shield.dir = -dir
		Sound.play("tower_hit", -8.0, 0.1)
	if attacker != null and attacker.trait_name() == "splash":
		# A belly flop lands with a splash ring on the ground.
		fx.effect("ring", to_screen(e.x, e.y), 650 * s, EFFECT_COLORS.splash, 0.4, "", true)
	# In a busy spot a small hit keeps quiet (no sparks, no new number), so
	# who's fighting whom, the big hits and the knockouts stay clear.
	var knockout: bool = (target != null and target.doomed) or hit.after.any(func(a): return String(a.get("type", "")) == "death")
	var quiet := quiet_hit(Vector2(e.x, e.y), strong, big, knockout)
	# Busy fights keep the biggest hits' sparks and marks (fx.allow_sparks).
	if not quiet and (fx.allow_sparks(amount) or strong):
		if strong or not fx.crowded:
			_impact(style, at, dir, s, big)
		fx.burst_hit(at, strong, Vector2(dir.x, dir.y * 0.6))
	var kind := "hurt_enemy" if target == null or target.team == 1 else "hurt_own"
	fx.number(at + Vector2(0, -10), amount, kind, strong, target.key if target != null else null, quiet)
	Sound.play("hit", -7.0, 0.2)
	if big:
		hit_stop(Feel.num(c, "hitstop_seconds", 0.055))
		shake(Feel.num(c, "shake_strong_hit", 0.12))
	if strong and attacker != null:
		strong_hit.emit(attacker.team)
		_cheer(Vector2(e.x, e.y), 0.5)
	for after in hit.after:
		_show(after)
	if log_impacts:
		impact_log.append({"time": _time, "team": attacker.team if attacker != null else -1, "read": bool(hit.get("read", false)), "late": _time - float(hit.sim_at), "volley": int(e.get("volley", -1))})


## A hit effect that fits how the attacker fights.
## An impact in an element's look (feel.json "elements"; docs/ART_DIRECTION.md,
## effects): the layers of a hit. A "blast" over the animals (a white-hot
## core flash, the element's glow, a shockwave ring, the element's bits
## flying out, pushed along `dir`), a burst of its particles, and (`ground`)
## the fade it leaves on the ground, a "linger". `big` (a Mythic's, a slam):
## two rings, twice the bits, longer, and a shake.
func _blast(element: String, at: Vector2, radius: float, big: bool, dir := Vector2.UP, ground := true) -> Dictionary:
	var el: Dictionary = GameData.feel.get("elements", {}).get(element, {})
	if el.is_empty():
		return {}
	var glow := Color(String(el.get("glow", "#ffffff")))
	var core := Color(String(el.get("core", "#ffffff")))
	var life := Feel.num("elements", "blast_seconds_big" if big else "blast_seconds", 0.85 if big else 0.55)
	var blast := fx.effect("blast", at, radius, glow, life)
	blast.core = core
	blast.dark = Color(String(el.get("dark", "#333333")))
	blast.bits = String(el.get("bits", "spark"))
	blast.count = Feel.count("elements", "blast_bits_big" if big else "blast_bits", 14 if big else 7)
	if fx.crowded:
		blast.count = maxi(3, int(blast.count) / 2)
	blast.rings = Feel.count("elements", "blast_rings_big", 2) if big else 1
	blast.dir = dir
	var particle := String(el.get("particle", "spark"))
	var rises := particle in ["spark", "sparkle", "glow"]
	fx.burst(particle, at, 10 if big else 5, 240.0, 0.5, 8.0, [glow, core], -40.0 if rises else 120.0, 2.5)
	var linger_seconds := Feel.num("elements", "linger_seconds", 1.2)
	if ground and linger_seconds > 0.0:
		var linger := fx.effect("linger", at, radius * (0.9 if big else 0.7), glow, linger_seconds * (1.5 if big else 1.0), "", true)
		linger.dark = blast.dark
		linger.bits = blast.bits
		linger.age = -life * 0.5
	if big:
		shake(Feel.num("elements", "blast_shake", 0.08))
	return blast


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
	# And the layers every hit gets (feel.json "elements" impact): a small
	# core flash, glow, ring and sparks; a big hit's is bigger.
	_blast("impact", at, (520 if big else 340) * s, big, dir, false)
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
	draw_rect(Rect2(Vector2.ZERO, size), grass.darkened(0.12))


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
	canvas.draw_rect(Rect2(Vector2.ZERO, size).grow(20), grass.darkened(0.08))
	canvas.draw_rect(field, grass)
	var tile := BattleSim.TILE * s
	var tiles := Vector2i((_field_size() / BattleSim.TILE).ceil())
	for row in tiles.y:
		for col in tiles.x:
			if (row + col) % 2 == 0:
				canvas.draw_rect(Rect2(field.position + Vector2(col, row) * tile, Vector2(tile, tile)).intersection(field), Color(1, 1, 1, 0.035))
	var middle := to_screen(0, sim.middle if sim != null else BattleSim.MIDDLE).y
	# Painted lines: a solid lighter grass, not see-through white.
	var paint := grass.lightened(0.3)
	canvas.draw_line(Vector2(field.position.x, middle), Vector2(field.end.x, middle), paint, 3.0)
	canvas.draw_arc(field.get_center(), tile * 2.2, 0, TAU, 48, paint, 3.0)
	canvas.draw_rect(field, Color(0.25, 0.18, 0.1), false, 4.0)


## Shadows and rings first, then the class badges: their circles, then the
## icons a class at a time, so each kind of picture is drawn in one batch.
func _draw_unit_ground(canvas: CanvasItem) -> void:
	_draw_squad_glow(canvas)
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


## Each squad's banner, over its animals: a flag on a pole in its team's
## color with its class's icon. Elite Specialists and Mythic heroes get a
## gold one.
## A soft glow on the ground under each animal of the picked squad, in its
## team's color, gently pulsing.
func _draw_squad_glow(canvas: CanvasItem) -> void:
	if picked_group < 0:
		return
	var r := "readability"
	var color := team_color(picked_team).lightened(0.35)
	var strength := Feel.num(r, "squad_glow_alpha", 0.5)
	var tile := float(BattleSim.TILE) * _scale()
	for v: UnitView in picked_views():
		var size := maxf(14.0, float(v.fighter.radius) * _scale() * Feel.num(r, "squad_glow_scale", 2.4))
		var pulse := v.m_glow
		canvas.draw_set_transform(v.position, 0.0, Vector2(1.0, 0.55))
		for k in 5:
			var f := 1.0 - k / 5.0
			canvas.draw_circle(Vector2.ZERO, size * (0.45 + 0.55 * f) + tile * 0.04 * pulse, Color(color, strength * 0.22 * (1.0 - f * 0.6) * pulse))
		canvas.draw_arc(Vector2.ZERO, size * 0.9, 0.0, TAU, 32, Color(color, strength * pulse), 3.0, true)
		canvas.draw_set_transform(Vector2.ZERO)


## For a moment after a squad is picked: a dashed line from each of its
## animals to the enemy it's going for, and a target ring on that enemy,
## fading out at the end.
func _draw_squad_targets(canvas: CanvasItem) -> void:
	var pairs := picked_targets()
	if pairs.is_empty():
		return
	var r := "readability"
	var seconds := Feel.num(r, "squad_lines_seconds", 2.5)
	var age := _time - _picked_at
	var fade := clampf((seconds - age) / 0.5, 0.0, 1.0)
	var color := Color(team_color(picked_team).lightened(0.2), fade)
	var ink := Color(UIKit.INK, 0.55 * fade)
	var width := Feel.num(r, "squad_line_px", 3.0)
	var dash := Feel.num(r, "squad_dash_px", 10.0)
	var ring := Feel.num(r, "squad_marker_px", 15.0)
	var marked := {}
	for pair in pairs:
		var a: Vector2 = (pair[0] as UnitView).middle()
		var b: Vector2 = (pair[1] as UnitView).middle()
		var gap := ring + 2.0
		if a.distance_to(b) > gap * 2.0:
			var end := b - (b - a).normalized() * gap
			canvas.draw_dashed_line(a, end, ink, width + 2.0, dash, true, true)
			canvas.draw_dashed_line(a, end, color, width, dash, true, true)
		marked[pair[1]] = b
	for at: Vector2 in marked.values():
		var spin := _time * 2.0
		canvas.draw_arc(at, ring, 0.0, TAU, 28, ink, 5.0, true)
		canvas.draw_arc(at, ring, 0.0, TAU, 28, color, 3.0, true)
		for k in 4:
			var ang := spin + k * PI / 2.0
			var dir := Vector2(cos(ang), sin(ang))
			canvas.draw_line(at + dir * (ring - 5.0), at + dir * (ring + 6.0), color, 3.0, true)


## Every squad's banner: {"base": the pole's foot, "tip": its top, "flag":
## the flag's middle, team, cls, gold, group}, over the middle of the squad.
func banners() -> Array:
	if sim == null or sim.army == null:
		return []
	var a := "army"
	var squads := {}
	for v: UnitView in _views.values():
		if not v.army or v.defeat >= 0.0 or v.doomed or v.fighter == null or v.fighter.memory.get("burrowing", false):
			continue
		var g := int(v.fighter.memory.get("group", -1))
		var top := v.position + v.head()
		if not squads.has(g):
			squads[g] = {"x": 0.0, "n": 0, "top": top.y, "team": v.team, "cls": v.cls, "group": g,
				"gold": v.fighter.memory.get("hero", false) or v.fighter.memory.get("elite", false)}
		var sq: Dictionary = squads[g]
		sq.x += top.x
		sq.n += 1
		sq.top = minf(float(sq.top), top.y)
	var pole := Feel.num(a, "banner_pole_pixels", 22.0)
	var w := Feel.num(a, "banner_width_pixels", 22.0)
	var h := Feel.num(a, "banner_height_pixels", 17.0)
	for sq: Dictionary in squads.values():
		sq.base = Vector2(float(sq.x) / int(sq.n), float(sq.top) - 4.0)
		sq.tip = (sq.base as Vector2) - Vector2(0, pole + h)
		sq.flag = (sq.tip as Vector2) + Vector2(w * 0.5, h * 0.5)
	return squads.values()


## For checking sizes (the website opened with ?fight=...&sizes=1, dev
## tools on): each animal's standing height on screen, marked and labelled
## as a share of the screen's height.
var show_sizes := false


func _draw_sizes(canvas: CanvasItem) -> void:
	var font := ThemeDB.fallback_font
	for v: UnitView in _views.values():
		if v.fighter == null or v.defeat >= 0.0 or not v.modeled or _stage == null:
			continue
		var px := _stage.height_px(v.key)
		if px <= 0.0:
			continue
		var share := px / maxf(1.0, screen_height())
		var limits: Dictionary = GameData.bodies.get("limits", {})
		var limit := float(limits.get("hero_max_pct", 10.0)) if v.fighter.memory.get("hero", false) else float(limits.get("unit_max_pct", 9.0))
		var color := Color("#ff4d4d") if share * 100.0 > limit else Color("#2bff7a")
		var foot := v.position + Vector2(v.spread_r * 0.0, 0.0)
		var x := foot.x + 22.0
		canvas.draw_line(Vector2(x, foot.y), Vector2(x, foot.y - px), color, 2.0)
		canvas.draw_line(Vector2(x - 5, foot.y), Vector2(x + 5, foot.y), color, 2.0)
		canvas.draw_line(Vector2(x - 5, foot.y - px), Vector2(x + 5, foot.y - px), color, 2.0)
		var text := "%.1f%%" % (share * 100.0)
		var at := Vector2(x + 7.0, foot.y - px * 0.5 + 5.0)
		canvas.draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.9))
		canvas.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)


func _draw_banners(canvas: CanvasItem) -> void:
	_draw_squad_targets(canvas)
	if show_sizes:
		_draw_sizes(canvas)
	var a := "army"
	var w := Feel.num(a, "banner_width_pixels", 22.0)
	var h := Feel.num(a, "banner_height_pixels", 17.0)
	var alpha := Feel.num(a, "banner_alpha", 1.0)
	var ink := Color(UIKit.INK, alpha)
	for sq: Dictionary in banners():
		var base: Vector2 = sq.base
		var tip: Vector2 = sq.tip
		canvas.draw_line(base, tip, ink, 2.5)
		var color: Color = team_color(int(sq.team))
		if sq.gold:
			color = Color("#ffc53d")
		# The flag flies toward the enemy's side of the screen's top or
		# bottom... simply to the right, with a little wave.
		var wave := sin(_time * 5.0 + base.x * 0.05) * 2.0
		var flag := PackedVector2Array([tip, tip + Vector2(w, wave * 0.5), tip + Vector2(w * 0.86, h * 0.5 + wave), tip + Vector2(w, h + wave * 0.5), tip + Vector2(0, h)])
		canvas.draw_colored_polygon(flag, Color(color, alpha))
		canvas.draw_polyline(flag + PackedVector2Array([tip]), ink, 2.0)
		if int(sq.group) == picked_group:
			# The picked squad's flag: a glowing ring round it.
			canvas.draw_arc(tip + Vector2(w * 0.5, h * 0.5), maxf(w, h) * 0.95, 0.0, TAU, 24, Color(team_color(int(sq.team)).lightened(0.4), 0.85), 3.0, true)
		var icon := UIKit.icon(GameData.ui_icon(String(GameData.class_info(String(sq.cls)).get("icon", ""))))
		if icon != null:
			var side := h * 0.8
			canvas.draw_texture_rect(icon, Rect2(tip + Vector2(w * 0.42 - side / 2.0, h / 2.0 - side / 2.0 + wave * 0.4), Vector2(side, side)), false, Color(1, 1, 1, alpha))


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
	canvas.draw_rect(area.grow(-2), Color(1, 1, 0.6), false, 3.0)


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
