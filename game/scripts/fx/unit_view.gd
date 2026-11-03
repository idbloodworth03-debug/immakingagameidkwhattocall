class_name UnitView
extends Node2D
## One animal on the battlefield. It plays the animal's rendered frames
## (idle, walk, attack) and adds smooth motion on top, every frame:
## breathing, walking hops with squash and stretch, a lean into the run, an
## anticipation squash before a strike and a lunge on it, a springy squash
## and knockback when hit, a white flash, a pop-in when it appears, a hop
## when it's moved, and a cartoon defeat (a hop, a spin and a poof).
##
## Only looks: it reads the fighter, never changes it. The node itself draws
## the ground shadow and team ring; its Body child draws the sprite with the
## unit shader (fake-3D highlight, rim light, colored outline, flash). The
## numbers live in data/feel.json.

const SHADER := preload("res://scripts/fx/unit.gdshader")
const TURN_SPEED := 600.0     # degrees per second

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
## Field position (thousandths of a tile), smoothed.
var pos := Vector2.ZERO
var facing := 0.0
var stars := 1

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
	v.body = Body.new()
	if Feel.on("characters", "shader_enabled"):
		var material := ShaderMaterial.new()
		material.shader = SHADER
		_apply_look(material)
		material.set_shader_parameter("gold_color", Color(1.0, 0.82, 0.25))
		v._material = material
		v.body.material = material
	v.add_child(v.body)
	v.z_index = 1 if v.flying else 0
	return v


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
	hp_ratio = float(f.hp) / maxf(1.0, float(f.max_hp))
	var new_stars := int(f.memory.get("stars", 1))
	if new_stars > stars:
		upgrade = 1.0
		field.fx.burst_upgrade(self)
	stars = new_stars
	var jump := at.distance_to(pos)
	if jump > 900.0 and hop_t >= 1.0:
		# Moved to a new spot all at once (placed, laid out again, knocked
		# back): hop there.
		hop_from = pos
		hop_t = 0.0
		hop_seconds = Feel.num("characters", "move_hop_seconds", 0.32) * clampf(jump / 4000.0, 0.5, 1.0)
	var moved := at - pos
	pos = at
	if hop_t < 1.0:
		moved = Vector2.ZERO
	if moved.length() > 1.0:
		moving = 0.12
		move_dir = moved.normalized()
		_turn(moved, dt)
		walk += moved.length() / 1000.0 / _walk_tiles
	else:
		moving = maxf(0.0, moving - dt)
		if f.target != null and f.target.alive:
			_turn(Vector2(f.target.x - f.x, f.target.y - f.y), dt)
	# Start the attack early enough that the bite lands on the hit.
	var sim := field.sim
	if f.target != null and f.target.alive and f.deploy_ticks <= 0 and sim.in_range(f, f.target) and not attacking(now):
		var windup := windup_seconds()
		var to_hit := (float(f.cooldown) / 100.0 - field.blend) / float(sim.tps)
		if to_hit >= 0.0 and to_hit <= windup:
			attack_at = now - (windup - to_hit)
			attack_dir = Vector2(f.target.x - f.x, f.target.y - f.y).normalized()
			if f.attack_range > 1500:
				field.fx.throw(f, to_hit)


func _turn(toward: Vector2, dt: float) -> void:
	if toward.length() < 1.0:
		return
	var goal := rad_to_deg(atan2(toward.x, -toward.y))
	var diff := wrapf(goal - facing, -180.0, 180.0)
	facing += clampf(diff, -TURN_SPEED * dt, TURN_SPEED * dt)


func windup_seconds() -> float:
	return _windup


func attacking(now: float) -> bool:
	return now - attack_at < UnitSprites.duration(id, "attack")


## Starts the strike now (a hit with no attack showing, often the first).
func strike(now: float, toward: Vector2) -> void:
	if not attacking(now):
		attack_at = now - windup_seconds()
	if toward.length() > 0.0:
		attack_dir = toward.normalized()


## Took a hit from the direction `from_dir` (field space, toward this view).
func hurt(from_dir: Vector2, strong: bool) -> void:
	flash = 1.0
	var c := "combat"
	squash += Feel.num(c, "hit_squash", 0.2) * (1.5 if strong else 1.0)
	var push := Feel.num(c, "hit_knockback_pixels", 7.0) * (1.6 if strong else 1.0)
	knock += Vector2(from_dir.x, from_dir.y * 0.6).normalized() * push
	trail_hold = Feel.num(c, "health_bar_trail_delay", 0.4)


func start_defeat() -> void:
	if defeat >= 0.0:
		return
	defeat = 0.0
	flash = 1.0
	defeat_spin = -1.0 if randf() < 0.5 else 1.0
	fighter = null


func is_done() -> bool:
	return defeat >= 1.0


# --- Every frame -------------------------------------------------------------

## The feel.json numbers every animal's animation uses, read once a frame.
static func _tuning() -> Dictionary:
	var now := Engine.get_process_frames()
	if now != _tuned_frame:
		_tuned_frame = now
		_tuned = {
			"bob_pixels": Feel.num("characters", "bob_pixels", 1.5),
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
	if hop_t < 1.0:
		hop_t = minf(1.0, hop_t + dt / maxf(0.05, hop_seconds))
	if defeat >= 0.0:
		defeat = minf(1.0, defeat + dt / maxf(0.05, float(t.defeat_seconds)))
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
	var anim := "idle"
	var frame := int((now + uid * 0.37) * _idle_fps)
	var since := now - attack_at
	var attack_len := _attack_len
	if defeat >= 0.0:
		anim = "attack"
		frame = 0
	elif since >= 0.0 and since < attack_len:
		anim = "attack"
		frame = int(since * _attack_fps)
	elif moving > 0.0 and hop_t >= 1.0:
		anim = "walk"
		frame = int(walk * _walk_frames)
	# Look the frame up only when it changes.
	var frame_key := "%s%d/%d" % [anim, frame, roundi(fposmod(facing, 360.0) / 45.0) % 8]
	if frame_key != _frame_key:
		_frame_key = frame_key
		body.frame = UnitSprites.frame(id, anim, facing, frame)

	# Build this frame's offset, stretch and lean.
	var offset := Vector2.ZERO
	var sx := 1.0
	var sy := 1.0
	var lean := 0.0
	var lift := 0.0
	if anim == "idle" and defeat < 0.0:
		# Breathing: a slow squash and stretch, and a gentle bob.
		var b := sin(now * float(t.breathe_speed) + idle_phase)
		var amount := float(t.breathe_amount)
		sy += b * amount
		sx -= b * amount * 0.6
		offset.y -= (b * 0.5 + 0.5) * float(t.bob_pixels)
	elif anim == "walk":
		# Little hops in step with the walk cycle: stretched in the air,
		# squashed on landing, leaning into the run.
		var step := absf(sin(walk * TAU))
		lift = step * float(t.walk_hop_pixels)
		var land := 1.0 - step
		var ws := float(t.walk_squash)
		sy += step * ws - land * ws * 0.8
		sx -= step * ws * 0.6 - land * ws * 0.6
		lean = move_dir.x * float(t.lean_degrees)
	elif anim == "attack" and defeat < 0.0:
		var windup := windup_seconds()
		var screen_dir := Vector2(attack_dir.x, attack_dir.y * 0.6).normalized()
		if since < windup:
			# Anticipation: squash down and pull back.
			var w := Ease.in_out_sine(since / maxf(windup, 0.01))
			var ws := float(t.windup_squash)
			sy -= w * ws
			sx += w * ws * 0.7
			offset -= screen_dir * w * float(t.windup_pull_pixels)
		else:
			# The strike: a fast stretch and lunge, then settle back.
			var after := (since - windup) / maxf(attack_len - windup, 0.05)
			var strike_t := 1.0 - Ease.out_cubic(after)
			var st := float(t.strike_stretch)
			sy += strike_t * st
			sx -= strike_t * st * 0.6
			offset += screen_dir * strike_t * float(t.lunge_pixels)
			lean = screen_dir.x * 10.0 * strike_t
	# Hit reaction.
	sx += squash
	sy -= squash
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
	var opacity := 1.0
	var rot := lean
	if defeat >= 0.0:
		# A cartoon knockout: hop up, spin, shrink and vanish in a poof.
		var d := defeat
		lift += Ease.arc(minf(1.0, d * 1.15)) * float(t.defeat_hop_pixels)
		rot += defeat_spin * float(t.defeat_spin_turns) * 360.0 * Ease.out_cubic(d)
		var shrink := 1.0 - Ease.in_cubic(d)
		sx *= shrink
		sy *= shrink
		opacity = 1.0 - Ease.in_cubic(d)
	offset.y -= lift

	var f := fighter
	if f != null:
		if f.stealthed and f.revealed <= 0:
			opacity *= 0.45 if team == 0 else 0.15
	body.position = offset
	body.scale = Vector2(maxf(sx, 0.01), maxf(sy, 0.01))
	body.rotation_degrees = rot
	body.visible = not (f != null and f.memory.get("burrowing", false))
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
		return pos
	return hop_from.lerp(pos, Ease.in_out_sine(hop_t))


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
