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
	v.body = Body.new()
	if Feel.on("characters", "shader_enabled"):
		var material := ShaderMaterial.new()
		material.shader = SHADER
		_apply_look(material)
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
		walk += moved.length() / 1000.0 / UnitSprites.walk_cycle_tiles(id)
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
	return float(UnitSprites.animation(id, "attack").get("hit", 0.45)) * UnitSprites.duration(id, "attack")


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

## Moves the springs and timers along and lays out the body for this frame.
func animate(dt: float, now: float) -> void:
	var c := "characters"
	var cb := "combat"
	var stiff := Feel.num(cb, "spring_stiffness", 320.0)
	var damp := Feel.num(cb, "spring_damping", 16.0)
	# Springs: squash and knockback settle back with a wobble.
	squash_v += (-stiff * squash - damp * squash_v) * dt
	squash += squash_v * dt
	knock_v += (-stiff * knock - damp * knock_v) * dt
	knock += knock_v * dt
	flash = maxf(0.0, flash - dt / maxf(0.01, Feel.num(cb, "hit_flash_seconds", 0.11)))
	pop = minf(1.0, pop + dt / maxf(0.01, Feel.num(c, "spawn_pop_seconds", 0.5)))
	upgrade = maxf(0.0, upgrade - dt / 0.6)
	if hop_t < 1.0:
		hop_t = minf(1.0, hop_t + dt / maxf(0.05, hop_seconds))
	if defeat >= 0.0:
		defeat = minf(1.0, defeat + dt / maxf(0.05, Feel.num(cb, "defeat_seconds", 0.6)))
	# The health bar drains smoothly; the "damage taken" part waits, then follows.
	bar_shown = move_toward(bar_shown, hp_ratio, dt * Feel.num(cb, "health_bar_drain_speed", 3.0))
	if hp_ratio > bar_trail:
		bar_trail = hp_ratio
	if trail_hold > 0.0:
		trail_hold -= dt
	else:
		bar_trail = move_toward(bar_trail, bar_shown, dt * Feel.num(cb, "health_bar_trail_speed", 0.9))

	var k := field.sprite_k(id, swarm)
	body.k = k
	var anim := "idle"
	var frame := int((now + uid * 0.37) * float(UnitSprites.animation(id, "idle").get("fps", 6)))
	var since := now - attack_at
	var attack_len := UnitSprites.duration(id, "attack")
	if defeat >= 0.0:
		anim = "attack"
		frame = 0
	elif since >= 0.0 and since < attack_len:
		anim = "attack"
		frame = int(since * float(UnitSprites.animation(id, "attack").fps))
	elif moving > 0.0 and hop_t >= 1.0:
		anim = "walk"
		frame = int(walk * float(UnitSprites.animation(id, "walk").frames))
	body.frame = UnitSprites.frame(id, anim, facing, frame)

	# Build this frame's offset, stretch and lean.
	var offset := Vector2.ZERO
	var sx := 1.0
	var sy := 1.0
	var lean := 0.0
	var lift := 0.0
	if anim == "idle" and defeat < 0.0:
		# Breathing: a slow squash and stretch, and a gentle bob.
		var b := sin(now * Feel.num(c, "breathe_speed", 2.4) + idle_phase)
		var amount := Feel.num(c, "breathe_amount", 0.035)
		sy += b * amount
		sx -= b * amount * 0.6
		offset.y -= (b * 0.5 + 0.5) * Feel.num(c, "bob_pixels", 1.5)
	elif anim == "walk":
		# Little hops in step with the walk cycle: stretched in the air,
		# squashed on landing, leaning into the run.
		var step := absf(sin(walk * TAU))
		lift = step * Feel.num(c, "walk_hop_pixels", 5.0)
		var land := 1.0 - step
		var ws := Feel.num(c, "walk_squash", 0.07)
		sy += step * ws - land * ws * 0.8
		sx -= step * ws * 0.6 - land * ws * 0.6
		lean = move_dir.x * Feel.num(c, "lean_degrees", 7.0)
	elif anim == "attack" and defeat < 0.0:
		var windup := windup_seconds()
		var screen_dir := Vector2(attack_dir.x, attack_dir.y * 0.6).normalized()
		if since < windup:
			# Anticipation: squash down and pull back.
			var w := Ease.in_out_sine(since / maxf(windup, 0.01))
			var ws := Feel.num(cb, "windup_squash", 0.12)
			sy -= w * ws
			sx += w * ws * 0.7
			offset -= screen_dir * w * Feel.num(cb, "windup_pull_pixels", 4.0)
		else:
			# The strike: a fast stretch and lunge, then settle back.
			var after := (since - windup) / maxf(attack_len - windup, 0.05)
			var strike_t := 1.0 - Ease.out_cubic(after)
			var st := Feel.num(cb, "strike_stretch", 0.16)
			sy += strike_t * st
			sx -= strike_t * st * 0.6
			offset += screen_dir * strike_t * Feel.num(cb, "lunge_pixels", 12.0)
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
		offset.y -= (1.0 - Ease.out_cubic(pop * 1.6)) * Feel.num(c, "spawn_drop_pixels", 26.0)
	if upgrade > 0.0:
		var u := Ease.arc(1.0 - upgrade) * Feel.num(c, "upgrade_pop", 0.3)
		sx += u
		sy += u
	if hop_t < 1.0:
		lift += Ease.arc(hop_t) * Feel.num(c, "move_hop_pixels", 22.0) * clampf(hop_seconds / 0.3, 0.4, 1.0)
		var h := Ease.arc(hop_t)
		sy += h * 0.12
		sx -= h * 0.08
	var opacity := 1.0
	var rot := lean
	if defeat >= 0.0:
		# A cartoon knockout: hop up, spin, shrink and vanish in a poof.
		var d := defeat
		lift += Ease.arc(minf(1.0, d * 1.15)) * Feel.num(cb, "defeat_hop_pixels", 46.0)
		rot += defeat_spin * Feel.num(cb, "defeat_spin_turns", 1.25) * 360.0 * Ease.out_cubic(d)
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
	if f != null and int(f.memory.get("playing_dead", 0)) > 0:
		tint = Color(0.6, 0.6, 0.6)
	elif f != null and f.stun > 0:
		tint = Color(1.0, 1.0, 0.8)
	# Three stars: a gentle golden glow, and a sparkle now and then.
	var golden := stars >= int(GameData.draft_rules.get("star_max", 3)) and defeat < 0.0
	if golden and dt > 0.0:
		_sparkle_in -= dt
		if _sparkle_in <= 0.0:
			_sparkle_in = Feel.num("celebrations", "gold_sparkle_seconds", 0.7) * randf_range(0.7, 1.3)
			var spot := position + body.position + Vector2(randf_range(-0.5, 0.5) * UnitSprites.top(id) * k, -randf() * UnitSprites.top(id) * k)
			field.fx.particle("sparkle", spot, Vector2(0, -24), 0.6, 6.0, Color("#ffe58a"), 0.0, 1.0)
	var m := body.material as ShaderMaterial
	if m != null:
		var glow := Feel.num("celebrations", "gold_glow", 0.85) * (0.8 + 0.2 * sin(now * 3.0 + idle_phase)) if golden else 0.0
		m.set_shader_parameter("gold", glow)
		m.set_shader_parameter("flash", flash)
		m.set_shader_parameter("flip", 1.0 if body.frame.get("flip", false) else 0.0)
		m.set_shader_parameter("region", region_uv(body.frame))
		m.set_shader_parameter("opacity", opacity)
	else:
		# No shader (the lighter option): flash and fade with a plain tint.
		tint = tint.lerp(Color(2.0, 2.0, 2.0), flash * 0.6)
		tint.a = opacity
	body.self_modulate = tint
	body.queue_redraw()
	queue_redraw()


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

func _draw() -> void:
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
	if f != null and f.memory.get("burrowing", false):
		# Underground: a little mound of dirt wobbling along.
		var w := radius * 1.1
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
		draw_circle(Vector2.ZERO, w, Color("#5a3d22"))
		draw_circle(Vector2(0, -w * 0.2), w * 0.75, Color("#7a5532"))
		draw_set_transform(Vector2.ZERO)
		return
	# The shadow shrinks and fades as the animal leaves the ground.
	var air := clampf(lift / 40.0, 0.0, 0.7)
	var shadow_w := radius * Feel.num(c, "shadow_width", 1.25) * (1.0 - air * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, shadow_w, Color(0.05, 0.1, 0.05, Feel.num(c, "shadow_alpha", 0.34) * (1.0 - air) * fade))
	draw_circle(Vector2.ZERO, shadow_w * 0.65, Color(0.05, 0.1, 0.05, Feel.num(c, "shadow_alpha", 0.34) * 0.6 * (1.0 - air) * fade))
	# Team ring, flattened to sit on the ground.
	var team_color := BattleField.OWN_COLOR if team == 0 else BattleField.ENEMY_COLOR
	var ring := radius * 1.45
	var ring_alpha := Feel.num(c, "team_ring_alpha", 0.9) * fade
	if f != null and f.stealthed and f.revealed <= 0:
		ring_alpha *= 0.4 if team == 0 else 0.1
	var width := Feel.num(c, "team_ring_width", 3.0)
	draw_circle(Vector2.ZERO, ring, Color(team_color, 0.16 * ring_alpha))
	draw_arc(Vector2.ZERO, ring, 0, TAU, 40, Color(team_color.darkened(0.45), ring_alpha), (width + 2.0) / 0.42)
	draw_arc(Vector2.ZERO, ring, 0, TAU, 40, Color(team_color.lightened(0.15), ring_alpha), width / 0.42)
	if f != null:
		# Status rings around its feet.
		if f.shield > 0:
			draw_arc(Vector2.ZERO, ring + 4, 0, TAU, 32, Color("#7fd6ff"), 6.0)
		if f.rage > 0:
			draw_arc(Vector2.ZERO, ring + 7, 0, TAU, 32, Color("#ff9f43", 0.85), 5.0)
		if f.slow > 0:
			draw_arc(Vector2.ZERO, ring + 3, 0, TAU, 32, Color("#9fd8ff", 0.8), 5.0)
		if f.invulnerable > 0:
			draw_arc(Vector2.ZERO, ring + 6, 0, TAU, 32, Color.WHITE, 7.0)
	draw_set_transform(Vector2.ZERO)
