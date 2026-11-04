class_name UnitView
extends Node2D
## One animal on the battlefield. It plays the animal's rendered frames
## (idle, walk, attack) and adds smooth motion on top, every frame:
## breathing, walking hops with squash and stretch, a lean into the run, an
## anticipation squash before a strike and a lunge on it, a springy squash
## and knockback when hit, a white flash, a pop-in when it appears, a hop
## when it's moved, and a cartoon defeat (a hop, a spin and a poof).
##
## Only looks: it reads the fighter, never changes it. Where it's drawn
## follows the fighter smoothly (easing into and out of a run, nudged apart
## from animals it would cover, a little loose in a marching row), so the
## fight's steps never show. It faces where it's going or what it's fighting,
## turning at a cartoon pace, and a push never turns it. The node itself
## draws the ground shadow and team ring; its Body child draws the sprite
## with the unit shader (fake-3D highlight, rim light, colored outline,
## flash). The numbers live in data/feel.json ("movement", "combat",
## "characters").

const SHADER := preload("res://scripts/fx/unit.gdshader")
const ATTACK_ANIMS := ["attack", "attack2", "special"]

## What identifies this animal across re-layouts (herd slot), so it isn't
## popped in again when the herd is laid out anew.
var key: Variant
var uid := 0
var id := ""
var team := 0
var field: BattleField
var fighter: BattleSim.Fighter
var flying := false
var swarm := false
## Field position (thousandths of a tile): where the fight has it now.
var pos := Vector2.ZERO
## Where it's drawn (field units) and how fast that's moving: it follows
## `pos` (plus its nudge apart from others) like a spring, so it eases into
## and out of a run instead of starting and stopping dead.
var shown := Vector2.ZERO
var shown_v := Vector2.ZERO
## A nudge on screen away from animals it would cover (the field works it
## out each frame); `push` is this frame's, `spread_r` how far its picture
## reaches, in field units.
var spread := Vector2.ZERO
var push := Vector2.ZERO
var spread_r := 500.0
var facing := 0.0
var stars := 1
## Damage already dealt in the fight whose hit hasn't landed on screen yet
## (the strike or shot is still on its way), and how many such hits.
var pending_damage := 0
var incoming := 0
## Beaten in the fight; the defeat shows at doom_at, once the hits on their
## way have landed.
var doomed := false
var doom_at := 0.0

# Motion state
var walk := 0.0
var moving := 0.0
var move_dir := Vector2.ZERO
var attack_at := -100.0
var attack_dir := Vector2.UP
var flash := 0.0
var squash := 0.0
var squash_v := 0.0
var knock := Vector2.ZERO
var knock_v := Vector2.ZERO
var pop := 0.0                # 0 to 1 while popping in
var hop_from := Vector2.ZERO  # where a hop to a new spot started
var hop_t := 1.0
var hop_seconds := 0.3
var upgrade := 0.0            # counts down after a star is added
var defeat := -1.0            # 0 to 1 while being defeated; -1 while fine
var defeat_spin := 1.0
var idle_phase := 0.0
var _sparkle_in := 0.0        # a 3-star animal's next sparkle
## The direction drawn (0-7, eighths of a turn), which changes only once
## `facing` is well past the halfway mark (no flicker between two).
var _dir8 := 0
var _turn_pinch := 0.0        # a quick squash as it turns to a new direction
var _follow_k := 1.0          # its own follow speed (a row isn't a rigid block)
var _intent := 0.0            # walking on its own (not pushed) for this long yet
var _last_run := 0
var _march := 0.0             # 0-1: how much it's marching (its wobble in the row)

## Acting (feel.json "acting"): its class's way of moving and attacking,
## faces, fidgets, blinks, a celebration and a few comic touches.
var _style := ""              # tank, tank_destroyer, ranged, air or specialist
## Its attacks ("attack", and "attack2" if it has a second to alternate
## with): {anim: {"windup", "length", "hit_frame", "fps"}}, and which plays.
var _attacks := {}
var _attack_anim := "attack"
var _attack_count := 0
var _anim_speed := 1.0        # its own idle and walk pace (no two in step)
var _fidget_len := 0.0
var _fidget_fps := 10.0
var _victory_fps := 10.0
var _blink_at := -100.0
var _blink_next := 0.0
var _fidget_at := -100.0
var _fidget_next := 0.0
var _hurt_at := -100.0
var _hurt_power := 1.0
var _flinch := 0.0
var _flinch_v := 0.0
var _smug_until := -100.0
var _victory_at := -1.0       # celebrating since (field time); -1 when not
var _trip_at := -100.0
var _trip_ready := 0.0
var _sweat_in := 0.0
var _zzz_in := 0.0
var _bank := 0.0
var _last_facing := 0.0
var _prev_anim := ""
var _last_step := 0
var _defeat_kind := "poof"
var _defeat_side := 1.0
var _face_key := ""
## Its Specialist trait ("burrow", "splash", "stun", "slow" or "") and body
## plan (UnitSprites.body), for their own ways of moving.
var _trait := ""
var _body := ""
## The attack playing: its wind-up stretched by this much (a lazy Slow
## swing, a Stun stare), and whether it's the big Stun blow.
var _attack_k := 1.0
var _dramatic := false
var _force_next := ""
var _dig_at := -100.0
var _emerge_at := -100.0
var _was_burrowing := false
var _shown_dir := 0
var _hop_in_at := -100.0
## Who hit it last (for a smug look when it's knocked out).
var last_attacker: UnitView
var face: UnitFace
## Its sprite sheet's speeds and sizes (see make()), and the frame it's on.
var _idle_fps := 6.0
var _attack_fps := 12.0
var _walk_frames := 8.0
var _attack_len := 0.5
var _per_tile := 64.0
var _walk_tiles := 1.0
var _windup := 0.2
var _frame_key := ""
## Tuning from feel.json, read once a frame for every animal (see _tuning()).
static var _tuned := {}
static var _tuned_frame := -1
## What the shader was last given (gold, flash, opacity; the frame).
var _shader_values := [-1.0, -1.0, -1.0]
var _shaded_frame: Dictionary = {}
var _material: ShaderMaterial


## The full look (its shader) or the plain one, which draws faster: a crowded
## fight uses the plain look, so many animals of a kind batch together.
func set_shaded(on: bool) -> void:
	var want: Material = _material if on else null
	if body.material != want:
		body.material = want
		_shader_values = [-1.0, -1.0, -1.0]
		_shaded_frame = {}
## Its class: a small icon shows under it.
var cls := ""

# Health bar
var hp_ratio := 1.0
var bar_shown := 1.0
var bar_trail := 1.0
var trail_hold := 0.0

var body: Body


## Draws the sprite; positioned and scaled by the view for squash and hops.
class Body:
	extends Node2D
	var frame: Dictionary = {}
	var k := 1.0

	func _draw() -> void:
		if frame.is_empty():
			return
		var region: Rect2 = frame.region
		var anchor: Vector2 = frame.anchor * k
		if frame.flip:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
		draw_texture_rect_region(frame.texture, Rect2(-anchor, region.size * k), region)


static func make(owner_field: BattleField, f: BattleSim.Fighter, view_key: Variant) -> UnitView:
	var v := UnitView.new()
	v.field = owner_field
	v.key = view_key
	v.id = f.card.id
	v.team = f.team
	v.flying = f.is_flying()
	v.swarm = int(f.card.get("count", 1)) > 1
	v.facing = 0.0 if f.team == 0 else 180.0
	v.pos = Vector2(f.x, f.y)
	v.shown = v.pos
	v._dir8 = posmod(roundi(v.facing / 45.0), 8)
	v.walk = randf()
	v.idle_phase = randf() * TAU
	v.stars = int(f.memory.get("stars", 1))
	v.cls = GameData.class_of(v.id)
	# Facts about its sprite sheet, looked up once (a big fight animates
	# dozens of these every frame).
	v._idle_fps = float(UnitSprites.animation(v.id, "idle").get("fps", 6))
	v._attack_fps = float(UnitSprites.animation(v.id, "attack").get("fps", 12))
	v._walk_frames = float(UnitSprites.animation(v.id, "walk").get("frames", 8))
	v._attack_len = UnitSprites.duration(v.id, "attack")
	v._per_tile = UnitSprites.pixels_per_tile(v.id)
	v._walk_tiles = maxf(0.05, UnitSprites.walk_cycle_tiles(v.id))
	v._windup = float(UnitSprites.animation(v.id, "attack").get("hit", 0.45)) * v._attack_len
	v._style = "air" if v.flying else v.cls
	v._trait = f.trait_id
	v._body = UnitSprites.body(v.id)
	v._was_burrowing = bool(f.memory.get("burrowing", false))
	var a := "acting"
	var slower: float = GameData.feel.get(a, {}).get("windup_scale", {}).get(v._style, 1.0)
	for anim in ["attack", "attack2", "special"]:
		var info := UnitSprites.animation(v.id, anim)
		if info.is_empty():
			continue
		var fps := float(info.get("fps", 16))
		var length := float(info.frames) / fps
		var hit := float(info.get("hit", 0.45))
		v._attacks[anim] = {"windup": hit * length * slower, "length": hit * length * slower + (1.0 - hit) * length,
			"hit_frame": hit * float(info.frames), "frames": float(info.frames), "fps": fps}
	if UnitSprites.has_animation(v.id, "fidget"):
		v._fidget_len = UnitSprites.duration(v.id, "fidget")
		v._fidget_fps = float(UnitSprites.animation(v.id, "fidget").get("fps", 10))
	v._victory_fps = float(UnitSprites.animation(v.id, "victory").get("fps", 10))
	v._anim_speed = 1.0 + randf_range(-1.0, 1.0) * Feel.num(a, "pace_variety", 0.08)
	var now := owner_field.now()
	v._blink_next = now + randf_range(0.5, 4.0)
	var first := _range(a, "fidget_first", Vector2(2.0, 9.0))
	v._fidget_next = now + randf_range(first.x, first.y)
	# How far its picture reaches (field units), for keeping animals from
	# covering each other on screen.
	var c := "characters"
	var drawn := Feel.num(c, "sprite_scale", 1.6) * (Feel.num(c, "swarm_scale", 0.8) if v.swarm else 1.0)
	v.spread_r = UnitSprites.top(v.id) / v._per_tile * 1000.0 * drawn * Feel.num("movement", "spread_body_share", 0.45)
	v._follow_k = 1.0 + randf_range(-1.0, 1.0) * Feel.num("movement", "follow_variety", 0.25)
	v._last_run = int(f.memory.get("run", 0))
	v.body = Body.new()
	if Feel.on("characters", "shader_enabled"):
		var material := ShaderMaterial.new()
		material.shader = SHADER
		_apply_look(material)
		material.set_shader_parameter("gold_color", Color(1.0, 0.82, 0.25))
		v._material = material
		v.body.material = material
	v.add_child(v.body)
	v.face = UnitFace.new()
	v.face.radius = UnitSprites.eye_radius(v.id)
	v.face.lid = UnitSprites.lid_color(v.id)
	v.face.visible = false
	v.body.add_child(v.face)
	v.z_index = 1 if v.flying else 0
	return v


## A [low, high] pair from feel.json.
static func _range(section: String, key: String, fallback: Vector2) -> Vector2:
	var value: Variant = GameData.feel.get(section, {}).get(key, null)
	if value is Array and (value as Array).size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback


## The shader's look settings from feel.json.
static func _apply_look(material: ShaderMaterial) -> void:
	var c := "characters"
	material.set_shader_parameter("vibrance", Feel.num(c, "shader_vibrance", 0.3))
	material.set_shader_parameter("contrast", Feel.num(c, "shader_contrast", 0.1))
	material.set_shader_parameter("brightness", Feel.num(c, "shader_brightness", 0.03))
	material.set_shader_parameter("highlight", Feel.num(c, "shader_highlight", 0.45))
	material.set_shader_parameter("highlight_color", Feel.color(c, "shader_highlight_color", Color("#fff3d1")))
	material.set_shader_parameter("rim", Feel.num(c, "shader_rim", 0.6))
	material.set_shader_parameter("rim_color", Feel.color(c, "shader_rim_color", Color("#b9e2ff")))
	material.set_shader_parameter("edge_width", Feel.num(c, "shader_edge_width", 2.0))
	material.set_shader_parameter("outline_darkness", Feel.num(c, "shader_outline_darkness", 0.42))
	material.set_shader_parameter("outline_thicken", Feel.num(c, "shader_outline_thicken", 1.0))
	material.set_shader_parameter("gradient", Feel.num(c, "shader_gradient", 0.12))


# --- Following the fighter ---------------------------------------------------

## Called every frame with the fighter this view shows. `at` is its
## position (blended between ticks); `dt` is 0 during hit-stop.
func sync(f: BattleSim.Fighter, at: Vector2, dt: float, now: float) -> void:
	fighter = f
	uid = f.uid
	update_hp()
	var new_stars := int(f.memory.get("stars", 1))
	if new_stars > stars:
		upgrade = 1.0
		field.fx.burst_upgrade(self)
	stars = new_stars
	var t := _tuning()
	var jump := at.distance_to(pos)
	if jump > 900.0 and hop_t >= 1.0:
		# Moved to a new spot all at once (placed, laid out again, knocked
		# back): hop there.
		hop_from = render_pos()
		hop_t = 0.0
		hop_seconds = float(t.move_hop_seconds) * clampf(jump / 4000.0, 0.5, 1.0)
	var goal_v := (at - pos) / dt if dt > 0.0 else Vector2.ZERO
	pos = at
	# Walking on its own (the fight moved it toward something), not shoved
	# by its neighbors.
	# Burrowing: dive into the ground; popping up: boing.
	var burrowing := bool(f.memory.get("burrowing", false))
	if burrowing != _was_burrowing:
		_was_burrowing = burrowing
		if burrowing:
			_dig_at = now
			field.fx.burst("puff", position, 6, 110.0, 0.45, 8.0, [Color("#c9b08a"), Color("#e6d3b0")], 200.0, 2.0, 110.0)
		else:
			_emerge_at = now
	var run := int(f.memory.get("run", 0))
	if run > _last_run:
		_intent = float(t.walk_hold_seconds)
	_last_run = run
	_intent -= dt
	if hop_t < 1.0:
		shown = pos + spread
		shown_v = Vector2.ZERO
		goal_v = Vector2.ZERO
	elif dt > 0.0:
		var march := _march_offset(now, t)
		follow(pos + spread + march, goal_v, dt)
	var speed := shown_v.length()
	if hop_t >= 1.0 and _intent > 0.0 and speed > float(t.walk_min_speed):
		if moving <= 0.0 and now >= _trip_ready and randf() < float(t.trip_chance):
			# Now and then, setting off, it trips over its own feet.
			_trip_at = now
			_trip_ready = now + float(t.trip_cooldown)
			field.fx.burst("puff", position, 3, 50.0, 0.4, 5.0, [Color("#c9b08a", 0.8)], -30.0, 3.0)
		moving = float(t.walk_hold_seconds)
		move_dir = shown_v / speed
		# The legs keep pace with the ground they cover (within limits, so a
		# slow giant doesn't play its walk one frame a second).
		var cycle := _walk_tiles * 1000.0 * float(t.walk_stride) * (float(t.swarm_scale) if swarm else 1.0)
		var fps := clampf(speed / maxf(cycle, 1.0) * _walk_frames, float(t.walk_min_fps), float(t.walk_max_fps))
		walk += fps / _walk_frames * dt
	elif moving > 0.0:
		moving = maxf(0.0, moving - dt)
		if moving <= 0.0:
			# Arriving: a small settling bounce instead of a slide.
			squash_v += float(t.arrive_squash) * sqrt(float(t.spring_stiffness)) * 1.6
	_march = move_toward(_march, 1.0 if moving > 0.0 else 0.0, dt * 2.5)
	# Facing: where it's walking, else what it's fighting. A push never turns it.
	var sim := field.sim
	var has_target := f.target != null and f.target.alive
	if attacking(now) and now >= attack_at:
		_turn(attack_dir, dt)
	elif moving > 0.0:
		_turn(move_dir, dt)
	elif has_target:
		_turn(Vector2(f.target.x - f.x, f.target.y - f.y), dt)
	# Start the attack early enough that the strike lands on the hit (a
	# little later for some, so a herd doesn't swing in step).
	if has_target and f.deploy_ticks <= 0 and f.stun <= 0 and sim.in_range(f, f.target) and not attacking(now):
		var next := _upcoming()
		var windup := _windup_of(String(next[0])) * float(next[1])
		var to_hit := (float(f.cooldown) / 100.0 - field.blend) / float(sim.tps)
		if to_hit >= 0.0 and to_hit <= windup:
			_start_attack(next, now - (windup - to_hit) + randf() * float(t.impact_jitter_seconds), Vector2(f.target.x - f.x, f.target.y - f.y))


## The health it shows: the fight's, plus the damage from hits still on their way.
func update_hp() -> void:
	if fighter != null:
		hp_ratio = clampf(float(fighter.hp + pending_damage) / maxf(1.0, float(fighter.max_hp)), 0.0, 1.0)


## Eases where it's drawn toward `goal` (moving at `goal_v`): a critically
## damped spring that keeps up with a steady walk and eases in and out of
## it, the same at any frame rate.
func follow(goal: Vector2, goal_v: Vector2, dt: float) -> void:
	var w := float(_tuning().follow_rate) * _follow_k
	var e := shown - goal
	var ev := shown_v - goal_v
	var decay := exp(-w * dt)
	var lead := ev + w * e
	shown = goal + (e + lead * dt) * decay
	shown_v = goal_v + (ev - w * lead * dt) * decay


## A slow wander while marching, so a row moves as a loose crowd rather
## than one block (none while standing).
func _march_offset(now: float, t: Dictionary) -> Vector2:
	var amount := float(t.march_wobble) * 1000.0 * _march
	if amount <= 0.0:
		return Vector2.ZERO
	var p := now / maxf(0.2, float(t.march_wobble_seconds)) * TAU
	return Vector2(sin(p * 0.83 + idle_phase), sin(p * 1.17 + idle_phase * 1.7) * 0.8) * amount


func _turn(toward: Vector2, dt: float) -> void:
	if toward.length() < 1e-3:
		return
	var t := _tuning()
	var goal := rad_to_deg(atan2(toward.x, -toward.y))
	var diff := wrapf(goal - facing, -180.0, 180.0)
	var rate := float(t.turn_speed) * dt
	facing = wrapf(facing + clampf(diff, -rate, rate), 0.0, 360.0)
	# The drawn direction moves on only once well past halfway to the next.
	var off := wrapf(facing - _dir8 * 45.0, -180.0, 180.0)
	if absf(off) > 22.5 + float(t.turn_hysteresis):
		_dir8 = posmod(roundi(facing / 45.0), 8)
		_turn_pinch = 1.0


func windup_seconds() -> float:
	return _windup_of(_attack_anim) * _attack_k


## How long the attack playing lasts, wind-up and all.
func _attack_length() -> float:
	var info: Dictionary = _attacks.get(_attack_anim, {})
	if info.is_empty():
		return _attack_len
	return windup_seconds() + float(info.length) - float(info.windup)


func attacking(now: float) -> bool:
	return now - attack_at < _attack_length()


## The attack it plays next, as [animation, wind-up stretch, the big Stun
## blow?]: common animals alternate two; a Stun animal's stunning blow gets
## its rendered wind-up (or a long stare); a Slow animal winds up lazily.
func _upcoming() -> Array:
	var a := "acting"
	if _force_next != "":
		var forced := _force_next
		_force_next = ""
		if forced == "special" and not _attacks.has("special"):
			return ["attack", Feel.num(a, "stun_windup_scale", 1.8), true]
		return [forced, 1.0, forced == "special"]
	var f := fighter
	if f != null and _trait == "stun":
		var every := maxi(1, int(f.param("every", 3)))
		if (int(f.memory.get("hits", 0)) + 1) % every == 0:
			if _attacks.has("special"):
				return ["special", 1.0, true]
			return ["attack", Feel.num(a, "stun_windup_scale", 1.8), true]
	var anim := "attack2" if _attacks.has("attack2") and _attack_count % 2 == 1 else "attack"
	return [anim, Feel.num(a, "slow_windup_scale", 1.5) if _trait == "slow" else 1.0, false]


func _windup_of(anim: String) -> float:
	return float(_attacks.get(anim, {}).get("windup", _windup))


func _start_attack(next: Array, at: float, toward: Vector2) -> void:
	_attack_anim = String(next[0])
	_attack_k = float(next[1])
	_dramatic = bool(next[2])
	if _attack_anim != "special":
		_attack_count += 1
	attack_at = at
	if toward.length() > 0.0:
		attack_dir = toward.normalized()


## The frame of an attack `since` seconds in: the wind-up plays at its
## class's pace (a Tank's big slow swing, a Tank Destroyer's quick one), the
## rest at the sheet's.
func _attack_frame(since: float) -> int:
	var info: Dictionary = _attacks.get(_attack_anim, {})
	if info.is_empty():
		return int(since * _attack_fps)
	var windup := windup_seconds()
	if since < windup:
		return int(since / maxf(windup, 0.01) * float(info.hit_frame))
	return mini(int(float(info.hit_frame) + (since - windup) * float(info.fps)), int(info.frames) - 1)


## Seconds until this animal's strike lands, for a hit the fight just dealt.
## If no wind-up is showing it starts one now, so every hit is seen coming.
func time_to_strike(now: float, toward: Vector2) -> float:
	var since := now - attack_at
	var windup := windup_seconds()
	if since < windup and attacking(now):
		return windup - since
	if since < windup + float(_tuning().strike_grace_seconds):
		return 0.0
	var next := _upcoming()
	_start_attack(next, now, toward)
	return windup_seconds()


## Took a hit from the direction `from_dir` (field space, toward this view).
func hurt(from_dir: Vector2, strong: bool) -> void:
	flash = 1.0
	var c := "combat"
	squash += Feel.num(c, "hit_squash", 0.2) * (1.5 if strong else 1.0)
	var push_px := Feel.num(c, "hit_knockback_pixels", 7.0) * (1.6 if strong else 1.0)
	knock += Vector2(from_dir.x, from_dir.y * 0.6).normalized() * push_px
	trail_hold = Feel.num(c, "health_bar_trail_delay", 0.4)
	# A flinch: a quick tilt away from the blow and a little bounce, eyes wide.
	_hurt_at = field.now()
	_hurt_power = 1.5 if strong else 1.0
	var away := signf(from_dir.x) if absf(from_dir.x) > 0.1 else (1.0 if randf() < 0.5 else -1.0)
	_flinch_v += away * Feel.num("acting", "flinch_degrees", 9.0) * 30.0 * _hurt_power


## The winning herd celebrates (from `at`, a moment apart so they aren't in
## step) for feel.json "acting" victory_seconds.
func celebrate(at: float) -> void:
	_victory_at = at
	_fidget_at = -100.0


func stop_celebrating() -> void:
	_victory_at = -1.0


func is_celebrating(now: float) -> bool:
	return _victory_at >= 0.0 and now >= _victory_at and now - _victory_at < Feel.num("acting", "victory_seconds", 2.6)


## A hop into place as the fight begins (at `at`, field time).
func hop_in(at: float) -> void:
	_hop_in_at = at


## When it was last hit (field time), for fading its health bar.
func hurt_time() -> float:
	return _hurt_at


## Its Specialist trait ("burrow", "splash", "stun", "slow" or "").
func trait_name() -> String:
	return _trait


## Fidgets now (the animation preview).
func fidget_now(now: float) -> void:
	if _fidget_len > 0.0:
		_fidget_at = now


## Makes its next attack this one ("attack" or "attack2"; the animation
## preview).
func prefer_attack(anim: String) -> void:
	_force_next = anim if anim != "attack2" or _attacks.has("attack2") else "attack"


## Knocked someone out: a smug look for a moment and a little chin-up.
func gloat(now: float) -> void:
	_smug_until = now + Feel.num("acting", "smug_seconds", 1.0)
	squash_v -= 2.5


func start_defeat() -> void:
	if defeat >= 0.0:
		return
	defeat = 0.0
	flash = 1.0
	defeat_spin = -1.0 if randf() < 0.5 else 1.0
	# Most poof into a cloud; some bounce off the screen with a comic spin.
	_defeat_kind = "fling" if randf() < Feel.num("acting", "defeat_fling_chance", 0.3) else "poof"
	_defeat_side = signf(knock.x) if absf(knock.x) > 0.5 else defeat_spin
	fighter = null


func is_done() -> bool:
	return defeat >= 1.0


# --- Every frame -------------------------------------------------------------

## The feel.json numbers every animal's animation uses, read once a frame.
static func _tuning() -> Dictionary:
	var now := Engine.get_process_frames()
	if now != _tuned_frame:
		_tuned_frame = now
		var m := "movement"
		_tuned = {
			"arrive_squash": Feel.num(m, "arrive_squash", 0.1),
			"follow_rate": Feel.num(m, "follow_rate", 12.0),
			"march_wobble": Feel.num(m, "march_wobble_tiles", 0.1),
			"march_wobble_seconds": Feel.num(m, "march_wobble_seconds", 2.6),
			"turn_speed": Feel.num(m, "turn_degrees_per_second", 720.0),
			"turn_hysteresis": Feel.num(m, "turn_hysteresis_degrees", 12.0),
			"turn_squash": Feel.num(m, "turn_squash", 0.1),
			"turn_squash_seconds": Feel.num(m, "turn_squash_seconds", 0.12),
			"walk_hold_seconds": Feel.num(m, "walk_hold_seconds", 0.15),
			"walk_min_speed": Feel.num(m, "walk_min_speed_tiles", 0.15) * 1000.0,
			"walk_stride": Feel.num("characters", "sprite_scale", 1.6) * Feel.num(m, "walk_stride_match", 1.0),
			"walk_min_fps": Feel.num(m, "walk_min_fps", 5.0),
			"walk_max_fps": Feel.num(m, "walk_max_fps", 16.0),
			"swarm_scale": Feel.num("characters", "swarm_scale", 0.8),
			"move_hop_seconds": Feel.num("characters", "move_hop_seconds", 0.32),
			"impact_jitter_seconds": Feel.num("combat", "impact_jitter_seconds", 0.06),
			"strike_grace_seconds": Feel.num("combat", "strike_grace_seconds", 0.1),
			"bob_pixels": Feel.num("characters", "bob_pixels", 1.5),
			"trip_chance": Feel.num("acting", "trip_chance", 0.03),
			"trip_cooldown": Feel.num("acting", "trip_cooldown", 25.0),
			"trip_seconds": Feel.num("acting", "trip_seconds", 0.45),
			"blink_seconds": Feel.num("acting", "blink_seconds", 0.13),
			"blink_every": _range("acting", "blink_every", Vector2(2.2, 5.0)),
			"fidget_every": _range("acting", "fidget_every", Vector2(7.0, 14.0)),
			"wide_seconds": Feel.num("acting", "wide_seconds", 0.35),
			"hurt_seconds": Feel.num("acting", "hurt_seconds", 0.32),
			"hurt_bounce_pixels": Feel.num("acting", "hurt_bounce_pixels", 5.0),
			"transition_squash": Feel.num("acting", "transition_squash", 0.05),
			"tank_hop": Feel.num("acting", "tank_hop", 0.45),
			"tank_step_squash": Feel.num("acting", "tank_step_squash", 0.06),
			"td_lean": Feel.num("acting", "td_lean", 1.7),
			"td_lunge": Feel.num("acting", "td_lunge", 1.9),
			"td_pounce_pixels": Feel.num("acting", "td_pounce_pixels", 9.0),
			"ranged_recoil_pixels": Feel.num("acting", "ranged_recoil_pixels", 5.0),
			"air_bob_pixels": Feel.num("acting", "air_bob_pixels", 4.0),
			"air_bob_speed": Feel.num("acting", "air_bob_speed", 2.6),
			"air_swoop_pixels": Feel.num("acting", "air_swoop_pixels", 5.0),
			"air_bank_degrees": Feel.num("acting", "air_bank_degrees", 16.0),
			"air_dive_rise_pixels": Feel.num("acting", "air_dive_rise_pixels", 8.0),
			"air_dive_drop_pixels": Feel.num("acting", "air_dive_drop_pixels", 10.0),
			"victory_hop_pixels": Feel.num("acting", "victory_hop_pixels", 9.0),
			"victory_seconds": Feel.num("acting", "victory_seconds", 2.6),
			"fling_seconds": Feel.num("acting", "defeat_fling_seconds", 0.9),
			"stun_wobble_degrees": Feel.num("acting", "stun_wobble_degrees", 7.0),
			"slow_pace": Feel.num("acting", "slow_pace", 0.5),
			"zzz_every": Feel.num("acting", "zzz_every", 0.9),
			"sweat_below": Feel.num("acting", "sweat_below", 0.25),
			"sweat_every": Feel.num("acting", "sweat_every", 1.3),
			"splash_hop_pixels": Feel.num("acting", "splash_hop_pixels", 16.0),
			"splash_squash": Feel.num("acting", "splash_squash", 0.25),
			"dig_seconds": Feel.num("acting", "dig_seconds", 0.35),
			"emerge_seconds": Feel.num("acting", "emerge_seconds", 0.5),
			"emerge_hop_pixels": Feel.num("acting", "emerge_hop_pixels", 18.0),
			"fish_wiggle_degrees": Feel.num("acting", "fish_wiggle_degrees", 8.0),
			"waddle_degrees": Feel.num("acting", "waddle_degrees", 5.0),
			"intro_hop_pixels": Feel.num("choreography", "intro_hop_pixels", 16.0),
			"breathe_amount": Feel.num("characters", "breathe_amount", 0.035),
			"breathe_speed": Feel.num("characters", "breathe_speed", 2.4),
			"defeat_hop_pixels": Feel.num("combat", "defeat_hop_pixels", 46.0),
			"defeat_seconds": Feel.num("combat", "defeat_seconds", 0.6),
			"defeat_spin_turns": Feel.num("combat", "defeat_spin_turns", 1.25),
			"gold_glow": Feel.num("celebrations", "gold_glow", 0.85),
			"gold_sparkle_seconds": Feel.num("celebrations", "gold_sparkle_seconds", 0.7),
			"health_bar_drain_speed": Feel.num("combat", "health_bar_drain_speed", 3.0),
			"health_bar_trail_speed": Feel.num("combat", "health_bar_trail_speed", 0.9),
			"hit_flash_seconds": Feel.num("combat", "hit_flash_seconds", 0.11),
			"lean_degrees": Feel.num("characters", "lean_degrees", 7.0),
			"lunge_pixels": Feel.num("combat", "lunge_pixels", 12.0),
			"move_hop_pixels": Feel.num("characters", "move_hop_pixels", 22.0),
			"spawn_drop_pixels": Feel.num("characters", "spawn_drop_pixels", 26.0),
			"spawn_pop_seconds": Feel.num("characters", "spawn_pop_seconds", 0.5),
			"spring_damping": Feel.num("combat", "spring_damping", 16.0),
			"spring_stiffness": Feel.num("combat", "spring_stiffness", 320.0),
			"strike_stretch": Feel.num("combat", "strike_stretch", 0.16),
			"upgrade_pop": Feel.num("characters", "upgrade_pop", 0.3),
			"walk_hop_pixels": Feel.num("characters", "walk_hop_pixels", 5.0),
			"walk_squash": Feel.num("characters", "walk_squash", 0.07),
			"windup_pull_pixels": Feel.num("combat", "windup_pull_pixels", 4.0),
			"windup_squash": Feel.num("combat", "windup_squash", 0.12),
		}
	return _tuned



## Moves the springs and timers along and lays out the body for this frame.
func animate(dt: float, now: float) -> void:
	var t := _tuning()
	var stiff := float(t.spring_stiffness)
	var damp := float(t.spring_damping)
	# Springs: squash and knockback settle back with a wobble.
	squash_v += (-stiff * squash - damp * squash_v) * dt
	squash += squash_v * dt
	knock_v += (-stiff * knock - damp * knock_v) * dt
	knock += knock_v * dt
	flash = maxf(0.0, flash - dt / maxf(0.01, float(t.hit_flash_seconds)))
	pop = minf(1.0, pop + dt / maxf(0.01, float(t.spawn_pop_seconds)))
	upgrade = maxf(0.0, upgrade - dt / 0.6)
	_turn_pinch = maxf(0.0, _turn_pinch - dt / maxf(0.01, float(t.turn_squash_seconds)))
	if hop_t < 1.0:
		hop_t = minf(1.0, hop_t + dt / maxf(0.05, hop_seconds))
	if defeat >= 0.0:
		var lasts := float(t.fling_seconds) if _defeat_kind == "fling" else float(t.defeat_seconds)
		defeat = minf(1.0, defeat + dt / maxf(0.05, lasts))
	_flinch_v += (-stiff * _flinch - damp * _flinch_v) * dt
	_flinch += _flinch_v * dt
	# The health bar drains smoothly; the "damage taken" part waits, then follows.
	bar_shown = move_toward(bar_shown, hp_ratio, dt * float(t.health_bar_drain_speed))
	if hp_ratio > bar_trail:
		bar_trail = hp_ratio
	if trail_hold > 0.0:
		trail_hold -= dt
	else:
		bar_trail = move_toward(bar_trail, bar_shown, dt * float(t.health_bar_trail_speed))

	var k := field.sprite_k_per_tile(_per_tile, swarm)
	body.k = k
	var f := fighter
	var stunned := f != null and f.stun > 0
	var slowed := f != null and f.slow > 0
	var pace := _anim_speed * (float(t.slow_pace) if slowed else 1.0)
	var anim := "idle"
	var frame := int((now * pace + uid * 0.37) * _idle_fps)
	var since := now - attack_at
	var attack_len := _attack_length()
	var windup := windup_seconds()
	var celebrating := is_celebrating(now)
	var tripping := now - _trip_at < float(t.trip_seconds)
	if defeat >= 0.0 or stunned:
		frame = 0
	elif since >= 0.0 and since < attack_len:
		anim = _attack_anim
		frame = _attack_frame(since)
	elif celebrating and UnitSprites.has_animation(id, "victory"):
		anim = "victory"
		frame = int((now - _victory_at) * _victory_fps * pace)
	elif moving > 0.0 and hop_t >= 1.0:
		anim = "walk"
		frame = int(walk * _walk_frames)
	elif now - _fidget_at < _fidget_len and not celebrating:
		anim = "fidget"
		frame = int((now - _fidget_at) * _fidget_fps)
	# A fidget now and then, while standing about with nothing in reach.
	if dt > 0.0 and _fidget_len > 0.0 and now >= _fidget_next:
		var every: Vector2 = t.fidget_every
		if anim == "idle" and defeat < 0.0 and not stunned and not celebrating and not _in_a_scrap():
			_fidget_at = now
			_fidget_next = now + randf_range(every.x, every.y)
			anim = "fidget"
			frame = 0
		else:
			_fidget_next = now + randf_range(1.0, 3.0)
	# Changing animation: a little squash eases the cut between pictures.
	if anim != _prev_anim:
		if _prev_anim != "" and not anim in ATTACK_ANIMS:
			squash_v += float(t.transition_squash) * 18.0
		_prev_anim = anim
	# Celebrating without a rendered victory: hop, hop, then spin round
	# through its drawn directions.
	_shown_dir = _dir8
	if celebrating and anim != "victory":
		var cycle := fmod(now - _victory_at, 1.3)
		if cycle > 0.85:
			_shown_dir = (_dir8 + int((cycle - 0.85) / 0.45 * 8.0)) % 8
	# Look the frame up only when it changes.
	var frame_key := "%s%d/%d" % [anim, frame, _shown_dir]
	if frame_key != _frame_key:
		_frame_key = frame_key
		body.frame = UnitSprites.frame(id, anim, _shown_dir * 45.0, frame)

	# Build this frame's offset, stretch and lean.
	var offset := Vector2.ZERO
	var sx := 1.0
	var sy := 1.0
	var lean := 0.0
	var lift := 0.0
	var air := _style == "air"
	if anim in ["idle", "fidget", "victory"] and defeat < 0.0:
		# Breathing: a slow squash and stretch, and a gentle bob.
		var b := sin(now * float(t.breathe_speed) * pace + idle_phase)
		var amount := float(t.breathe_amount)
		sy += b * amount
		sx -= b * amount * 0.6
		offset.y -= (b * 0.5 + 0.5) * float(t.bob_pixels)
	if air and defeat < 0.0:
		# Fliers bob as they hover and swoop gently as they fly.
		lift += (sin(now * float(t.air_bob_speed) * pace + idle_phase) * 0.5 + 0.5) * float(t.air_bob_pixels)
		if anim == "walk":
			lift += (sin(now * 1.7 + idle_phase) * 0.5 + 0.5) * float(t.air_swoop_pixels)
	elif anim == "walk":
		# Little hops in step with the walk cycle: stretched in the air,
		# squashed on landing, leaning into the run. Tanks plod low and
		# heavy; Tank Destroyers lean right into it.
		var step := absf(sin(walk * TAU))
		var hop := float(t.walk_hop_pixels)
		var ws := float(t.walk_squash)
		var lean_k := 1.0
		match _style:
			"tank":
				hop *= float(t.tank_hop)
				ws *= 1.5
				lean_k = 0.6
			"tank_destroyer":
				lean_k = float(t.td_lean)
		lift = step * hop
		var land := 1.0 - step
		sy += step * ws - land * ws * 0.8
		sx -= step * ws * 0.6 - land * ws * 0.6
		lean = move_dir.x * float(t.lean_degrees) * lean_k
		# Each body plan's own gait on top: fish flop and wiggle, upright
		# animals waddle, snakes ripple, frogs bound, seals and whales slide,
		# shrimp scuttle.
		match _body:
			"fish":
				lean += sin(walk * TAU * 2.0) * float(t.fish_wiggle_degrees)
			"biped":
				lean += sin(walk * TAU) * float(t.waddle_degrees)
				offset.x += sin(walk * TAU) * 1.5
			"serpent":
				sx += sin(walk * TAU * 2.0) * 0.05
				sy -= sin(walk * TAU * 2.0) * 0.03
				lift *= 0.2
			"frog":
				lift *= 2.2
			"pinniped", "cetacean":
				lift *= 0.3
				sx += step * 0.06
			"crustacean":
				lift = absf(sin(walk * TAU * 3.0)) * 1.5
		var steps := floori(walk * 2.0)
		if steps != _last_step:
			_last_step = steps
			_footfall(t)
	if anim in ATTACK_ANIMS and defeat < 0.0:
		var screen_dir := Vector2(attack_dir.x, attack_dir.y * 0.6).normalized()
		var lunge := float(t.lunge_pixels)
		if since < windup:
			# Anticipation: squash down and pull back (a Tank rears back
			# further; a Tank Destroyer crouches, then springs; a flier rises).
			var w := Ease.in_out_sine(since / maxf(windup, 0.01))
			var ws := float(t.windup_squash)
			var pull := float(t.windup_pull_pixels)
			match _style:
				"tank":
					pull *= 1.6
					ws *= 1.3
					lift += w * 3.0
				"tank_destroyer":
					ws *= 1.4
					var leap := clampf((since / maxf(windup, 0.01) - 0.7) / 0.3, 0.0, 1.0)
					lift += sin(leap * PI * 0.5) * float(t.td_pounce_pixels)
					offset += screen_dir * leap * lunge * float(t.td_lunge) * 0.6
				"ranged":
					pull *= 1.3
				"air":
					lift += w * float(t.air_dive_rise_pixels)
			# Traits: a Splash animal rises for a belly flop, a Slow one
			# stretches in a lazy yawn, the big Stun blow comes with a
			# trembling stare (when there's no rendered wind-up).
			match _trait:
				"splash":
					lift += sin(w * PI * 0.5) * float(t.splash_hop_pixels)
				"slow":
					sy += sin(w * PI) * 0.08
			if _dramatic and anim == "attack":
				lean += sin(now * 45.0) * 3.0 * w
				lift += w * 4.0
			sy -= w * ws
			sx += w * ws * 0.7
			offset -= screen_dir * w * pull
		else:
			# The strike: a fast stretch and lunge, then settle back. A shot
			# kicks the shooter back instead; a flier dives in and pulls up.
			var after := (since - windup) / maxf(attack_len - windup, 0.05)
			var strike_t := 1.0 - Ease.out_cubic(after)
			var st := float(t.strike_stretch)
			sy += strike_t * st
			sx -= strike_t * st * 0.6
			match _style:
				"ranged":
					offset -= screen_dir * strike_t * float(t.ranged_recoil_pixels)
				"tank_destroyer":
					offset += screen_dir * strike_t * lunge * float(t.td_lunge)
				"tank":
					offset += screen_dir * strike_t * lunge * 1.2
				"air":
					offset += screen_dir * strike_t * lunge * 1.5
					lift -= strike_t * float(t.air_dive_drop_pixels)
				_:
					offset += screen_dir * strike_t * lunge
			lean = screen_dir.x * 10.0 * strike_t
			if _trait == "splash":
				# Splat: flattened by the belly flop.
				sx += strike_t * float(t.splash_squash)
				sy -= strike_t * float(t.splash_squash)
	if celebrating and defeat < 0.0:
		# Celebrating: happy bounces (a moment apart, so not in step).
		var hop_t2 := (now - _victory_at) * 6.0
		lift += absf(sin(hop_t2)) * float(t.victory_hop_pixels)
		sy += absf(cos(hop_t2)) * 0.04
	# Hit reaction: a squash, a little bounce and a flinch away from the blow.
	sx += squash
	sy -= squash
	var hurt_t := (now - _hurt_at) / maxf(0.05, float(t.hurt_seconds))
	if hurt_t < 1.0:
		lift += Ease.arc(hurt_t) * float(t.hurt_bounce_pixels) * _hurt_power
	if tripping:
		# Tripping over its own feet: pitch forward, squash, recover.
		var trip := Ease.arc((now - _trip_at) / float(t.trip_seconds))
		lean += (move_dir.x if absf(move_dir.x) > 0.2 else 1.0) * 28.0 * trip
		sy -= 0.12 * trip
		sx += 0.08 * trip
	# Turning to a new direction: a quick pinch hides the swap of pictures.
	if _turn_pinch > 0.0:
		var pinch := Ease.arc(1.0 - _turn_pinch) * float(t.turn_squash)
		sx -= pinch
		sy += pinch * 0.4
	offset += knock
	# Popping in: drop in and bounce up to full size.
	if pop < 1.0:
		var p := Ease.out_elastic(pop)
		sx *= p
		sy *= lerpf(0.4, 1.0, Ease.out_back(pop)) * p
		offset.y -= (1.0 - Ease.out_cubic(pop * 1.6)) * float(t.spawn_drop_pixels)
	if upgrade > 0.0:
		var u := Ease.arc(1.0 - upgrade) * float(t.upgrade_pop)
		sx += u
		sy += u
	if hop_t < 1.0:
		lift += Ease.arc(hop_t) * float(t.move_hop_pixels) * clampf(hop_seconds / 0.3, 0.4, 1.0)
		var h := Ease.arc(hop_t)
		sy += h * 0.12
		sx -= h * 0.08
	# Burrowing: sinking into the ground; popping out: a springy boing.
	var burrowed := false
	if _was_burrowing:
		var dig := (now - _dig_at) / maxf(0.05, float(t.dig_seconds))
		if dig < 1.0:
			var sink := Ease.in_cubic(dig)
			sy *= 1.0 - sink * 0.85
			sx *= 1.0 + sink * 0.25
			lift -= sink * 6.0
		else:
			burrowed = true
	var hop_in_t := (now - _hop_in_at) / 0.4
	if hop_in_t >= 0.0 and hop_in_t < 1.0:
		lift += Ease.arc(hop_in_t) * float(t.intro_hop_pixels)
		sy += Ease.arc(hop_in_t) * 0.1
		sx -= Ease.arc(hop_in_t) * 0.06
		if hop_in_t + dt / 0.4 >= 1.0:
			squash_v += 3.0
	var emerge := (now - _emerge_at) / maxf(0.05, float(t.emerge_seconds))
	if emerge < 1.0:
		var boing := Ease.out_elastic(emerge)
		sy *= lerpf(0.2, 1.0, boing)
		sx *= lerpf(1.3, 1.0, boing)
		lift += Ease.arc(emerge) * float(t.emerge_hop_pixels)
	var opacity := 1.0
	var rot := lean + _flinch
	if air and dt > 0.0:
		# Banking into turns.
		var turning := wrapf(facing - _last_facing, -180.0, 180.0) / dt
		var bank := clampf(turning * 0.05, -float(t.air_bank_degrees), float(t.air_bank_degrees))
		_bank = lerpf(_bank, bank, 1.0 - exp(-dt * 6.0))
	_last_facing = facing
	rot += _bank
	if stunned and defeat < 0.0:
		rot += sin(now * 9.0 + idle_phase) * float(t.stun_wobble_degrees)
	if defeat >= 0.0:
		var d := defeat
		if _defeat_kind == "fling":
			# Bounced off the screen with a comic spin, fading as it goes.
			lift += 520.0 * d - 120.0 * d * d
			offset.x += _defeat_side * 260.0 * d
			rot += defeat_spin * 2.5 * 360.0 * d
			opacity = 1.0 - clampf((d - 0.65) / 0.35, 0.0, 1.0)
		else:
			# A cartoon knockout: hop up, spin, shrink and vanish in a poof.
			lift += Ease.arc(minf(1.0, d * 1.15)) * float(t.defeat_hop_pixels)
			rot += defeat_spin * float(t.defeat_spin_turns) * 360.0 * Ease.out_cubic(d)
			var shrink := 1.0 - Ease.in_cubic(d)
			sx *= shrink
			sy *= shrink
			opacity = 1.0 - Ease.in_cubic(d)
	offset.y -= lift
	_update_face(t, anim, frame, now, since, windup, celebrating, stunned, slowed, k)
	_comic_touches(t, dt, slowed, k)

	if f != null:
		if f.stealthed and f.revealed <= 0:
			opacity *= 0.45 if team == 0 else 0.15
	body.position = offset
	body.scale = Vector2(maxf(sx, 0.01), maxf(sy, 0.01))
	body.rotation_degrees = rot
	body.visible = not burrowed
	var tint := Color.WHITE
	if f != null and f.stun > 0:
		tint = Color(1.0, 1.0, 0.8)
	# Three stars: a gentle golden glow, and a sparkle now and then.
	var golden := stars >= int(GameData.draft_rules.get("star_max", 3)) and defeat < 0.0
	if golden and dt > 0.0:
		_sparkle_in -= dt
		if _sparkle_in <= 0.0:
			_sparkle_in = float(t.gold_sparkle_seconds) * randf_range(0.7, 1.3)
			var spot := position + body.position + Vector2(randf_range(-0.5, 0.5) * UnitSprites.top(id) * k, -randf() * UnitSprites.top(id) * k)
			field.fx.particle("sparkle", spot, Vector2(0, -24), 0.6, 6.0, Color("#ffe58a"), 0.0, 1.0)
	var m := body.material as ShaderMaterial
	if m != null:
		# Only what changed goes to the shader (a big fight has dozens of
		# animals, every frame).
		var shine := float(t.gold_glow) * (0.8 + 0.2 * sin(now * 3.0 + idle_phase)) if golden else 0.0
		_set_param(m, 0, "gold", snappedf(shine, 0.01))
		_set_param(m, 1, "flash", snappedf(flash, 0.01))
		_set_param(m, 2, "opacity", snappedf(opacity, 0.01))
		if body.frame != _shaded_frame:
			_shaded_frame = body.frame
			m.set_shader_parameter("flip", 1.0 if body.frame.get("flip", false) else 0.0)
			m.set_shader_parameter("region", region_uv(body.frame))
	else:
		# No shader (the lighter option): flash and fade with a plain tint.
		tint = tint.lerp(Color(2.0, 2.0, 2.0), flash * 0.6)
		tint.a = opacity
	body.self_modulate = tint
	body.queue_redraw()


## In reach of what it's fighting (no fidgeting then).
func _in_a_scrap() -> bool:
	var f := fighter
	return f != null and f.target != null and f.target.alive and field.sim != null and field.sim.in_range(f, f.target)


## A foot coming down: a Tank's heavy step thumps with a puff of dust; a
## Tank Destroyer kicks up dust behind it now and then.
func _footfall(t: Dictionary) -> void:
	if field.fx.crowded and randf() < 0.6:
		return
	var dust := Color("#c9b08a", 0.75)
	match _style:
		"tank":
			squash_v += float(t.tank_step_squash) * 20.0
			var heavy := fighter != null and fighter.radius >= 700
			field.fx.burst("puff", position + Vector2(randf_range(-6.0, 6.0), 0), 2 if heavy else 1, 40.0, 0.45, 6.0 if heavy else 4.5, [dust], -15.0, 3.0)
		"tank_destroyer":
			if randf() < 0.4:
				var back := -Vector2(move_dir.x, move_dir.y * 0.6)
				field.fx.particle("puff", position + back * 6.0, back * 60.0, 0.35, 3.5, dust, 0.0, 3.0)


## Which face to draw over its eyes this frame, if any.
func _update_face(t: Dictionary, anim: String, frame: int, now: float, since: float, windup: float, celebrating: bool, stunned: bool, slowed: bool, k: float) -> void:
	if face.radius <= 0.0:
		return
	if now >= _blink_next:
		var every: Vector2 = t.blink_every
		_blink_at = now
		_blink_next = now + randf_range(every.x, every.y)
	var mode := ""
	if defeat >= 0.0 or stunned:
		mode = "dizzy"
	elif celebrating:
		mode = "happy"
	elif now - _hurt_at < float(t.wide_seconds):
		mode = "wide"
	elif anim in ATTACK_ANIMS and since >= 0.0 and since < windup:
		mode = "drowsy" if _trait == "slow" else "squint"
	elif now < _smug_until:
		mode = "smug"
	elif slowed:
		mode = "drowsy"
	elif now - _blink_at < float(t.blink_seconds):
		mode = "blink"
	if mode == "":
		face.visible = false
		_face_key = ""
		return
	var key := "%s/%s" % [mode, _frame_key]
	if key != _face_key or mode == "dizzy":
		_face_key = key
		face.mode = mode
		face.eyes = UnitSprites.eyes(id, anim, _shown_dir * 45.0, frame)
		face.k = k
		face.flip = bool(body.frame.get("flip", false))
		face.spin = now * 7.0
		face.visible = not face.eyes.is_empty()
		face.queue_redraw()


## Sweat drops when it's nearly beaten, and Zzz while slowed.
func _comic_touches(t: Dictionary, dt: float, slowed: bool, k: float) -> void:
	if dt <= 0.0 or defeat >= 0.0 or fighter == null:
		return
	var top := position + body.position + Vector2(0, -UnitSprites.top(id) * k)
	if hp_ratio < float(t.sweat_below):
		_sweat_in -= dt
		if _sweat_in <= 0.0:
			_sweat_in = float(t.sweat_every) * randf_range(0.8, 1.3)
			var side := 1.0 if randf() < 0.5 else -1.0
			field.fx.effect("drop", top + Vector2(side * UnitSprites.top(id) * k * 0.3, 6.0), 5.0, Color("#8fd3ff"), 0.7)
	if slowed:
		_zzz_in -= dt
		if _zzz_in <= 0.0:
			_zzz_in = float(t.zzz_every)
			field.fx.effect("zzz", top + Vector2(8.0, -2.0), 9.0, Color("#e9f2ff"), 1.3)


func _set_param(m: ShaderMaterial, slot: int, param: String, value: float) -> void:
	if _shader_values[slot] != value:
		_shader_values[slot] = value
		m.set_shader_parameter(param, value)


## A frame's rectangle in its sheet, in UV (for the shader's shading).
static func region_uv(frame: Dictionary) -> Vector4:
	if frame.is_empty():
		return Vector4(0, 0, 1, 1)
	var size: Vector2 = frame.texture.get_size()
	var r: Rect2 = frame.region
	return Vector4(r.position.x / size.x, r.position.y / size.y, r.size.x / size.x, r.size.y / size.y)


## Where it's drawn on the field: mid-hop, between the old spot and the new.
func render_pos() -> Vector2:
	if hop_t >= 1.0:
		return shown
	return hop_from.lerp(shown, Ease.in_out_sine(hop_t))


## A pack's stars show over one of its animals only, not all of them.
func shows_stars() -> bool:
	return not swarm or not (key is String) or String(key).ends_with("/0")


## Where the top of its head is now, relative to its feet, for bars and stars.
func head() -> Vector2:
	return body.position + Vector2(0, -UnitSprites.top(id) * body.k * body.scale.y)


## Where the middle of its body is, for hit sparks.
func middle() -> Vector2:
	return position + body.position + Vector2(0, -UnitSprites.top(id) * body.k * 0.45)


# --- Drawing the shadow and ring ---------------------------------------------

## Its shadow, team ring and status rings on the ground, drawn by the field
## for every animal in one go (so they batch); its class badge is added to
## `badges` for the field to draw after all the rings.
func draw_ground(canvas: CanvasItem, badges: Array) -> void:
	var c := "characters"
	var s := field.field_scale()
	var f := fighter
	var radius := (f.radius if f != null else 450) * s
	var lift := -body.position.y
	var fade := 1.0
	if defeat >= 0.0:
		fade = 1.0 - defeat
	if pop < 1.0:
		fade *= pop
	var at := position
	if f != null and f.memory.get("burrowing", false):
		# Underground: a little mound of dirt wobbling along.
		var w := radius * 1.1
		GroundArt.draw(canvas, GroundArt.Cell.DISC, at, w, 0.55, Color("#5a3d22"))
		GroundArt.draw(canvas, GroundArt.Cell.DISC, at + Vector2(0, -w * 0.11), w * 0.75, 0.55, Color("#7a5532"))
		return
	# The shadow shrinks and fades as the animal leaves the ground.
	var air := clampf(lift / 40.0, 0.0, 0.7)
	var shadow_w := radius * Feel.num(c, "shadow_width", 1.25) * (1.0 - air * 0.5)
	GroundArt.draw(canvas, GroundArt.Cell.SHADOW, at, shadow_w * 1.1, 0.42, Color(0.05, 0.1, 0.05, Feel.num(c, "shadow_alpha", 0.34) * 1.3 * (1.0 - air) * fade))
	# Team ring, flattened to sit on the ground.
	var team_color := BattleField.OWN_COLOR if team == 0 else BattleField.ENEMY_COLOR
	var ring := radius * 1.45
	var ring_alpha := Feel.num(c, "team_ring_alpha", 0.9) * fade
	if f != null and f.stealthed and f.revealed <= 0:
		ring_alpha *= 0.4 if team == 0 else 0.1
	GroundArt.draw(canvas, GroundArt.Cell.DISC, at, ring, 0.42, Color(team_color, 0.16 * ring_alpha))
	GroundArt.draw_ring(canvas, GroundArt.Cell.RING, at, ring, 0.42, Color(team_color.darkened(0.45), ring_alpha))
	GroundArt.draw_ring(canvas, GroundArt.Cell.LINE, at, ring, 0.42, Color(team_color.lightened(0.15), ring_alpha))
	if f != null:
		# Status rings around its feet.
		if f.shield > 0:
			GroundArt.draw_ring(canvas, GroundArt.Cell.RING, at, ring + 4, 0.42, Color("#7fd6ff"))
		if f.rage > 0:
			GroundArt.draw_ring(canvas, GroundArt.Cell.RING, at, ring + 7, 0.42, Color("#ff9f43", 0.85))
		if f.slow > 0:
			GroundArt.draw_ring(canvas, GroundArt.Cell.RING, at, ring + 3, 0.42, Color("#9fd8ff", 0.8))
		if f.invulnerable > 0:
			GroundArt.draw_ring(canvas, GroundArt.Cell.RING, at, ring + 6, 0.42, Color.WHITE)
		if cls != "":
			# Its class, as a small badge just under its feet.
			var badge := Feel.num(c, "class_badge_radius", 9.0)
			badges.append([cls, at + Vector2(0, ring * 0.42 + badge * 0.9), badge, minf(fade, 0.95)])
