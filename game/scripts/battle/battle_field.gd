class_name BattleField
extends Control
## Draws a running battle (field, towers, animals, effects) and turns taps
## into field positions. It only reads the BattleSim; it never changes it.
## Team 0 (the player) is at the bottom.

signal tapped(at: Vector2i, zone: String)

const OWN_COLOR := Color("#3d7fd9")
const ENEMY_COLOR := Color("#d94a4a")
const EFFECT_COLORS := {
	"net": Color("#d8c08a"), "air_horn": Color("#ffffff"), "flare": Color("#ff8a3d"),
	"medkit": Color("#5ef08a"), "tranq_dart": Color("#b07cff"), "bait": Color("#c98b4a"),
	"heal": Color("#5ef08a"), "cloud": Color("#9bd36b"), "scare": Color("#ffd166"),
	"stun_pulse": Color("#ffe066"), "rage": Color("#ff9f43"), "tree": Color("#3fbf55"),
}

var sim: BattleSim
var grass := Color("#5f9e4f")
## How far we are between the last tick and the next (0-1), for smooth motion.
var blend := 0.0
var highlight_zones: Array = []
## The card being dragged, drawn where it would land:
## {"card": Dictionary, "at": Vector2i, "valid": bool}. Empty when none.
var preview: Dictionary = {}
var effects: Array = []

var _time := 0.0
var _shake := 0.0
var _lunges := {}          # attacker uid -> {"age", "dir"}
var _shake_offset := Vector2.ZERO

var _press_at := Vector2.ZERO
var _pressed := false

## How each animal looks right now, for the rendered sprites:
## uid -> {"id", "pos" (field position), "facing" (degrees clockwise from up),
## "walk" (cycles walked), "moving" (seconds left of walking pose),
## "attack_at" (when the attack animation started)}
var _views := {}
## Animals that just died, playing their death animation.
var _corpses: Array = []
## Things thrown by ranged animals (a squirrel's acorns), timed to land on the hit.
var _projectiles: Array = []

## Sprites are drawn this much bigger than true size, to read on a phone.
const SPRITE_SCALE := 1.6
const TURN_SPEED := 600.0     # degrees per second
## Pack and swarm animals are drawn a bit smaller so a group stays readable.
const SWARM_SCALE := 0.8
const HURT_TIME := 0.16
const THROW_FLIGHT := 0.28    # seconds an acorn is in the air
const CORPSE_REST := 0.6      # seconds a fallen animal lies still before fading
const CORPSE_FADE := 0.8
const DEN_ART := "res://art/towers/"
const HEADROOM := 2800.0      # field units above the far end, for the tall dens
const DEN_SCALE := 0.92

static var _den_meta := {}
static var _den_textures := {}
const DROP_PART := 0.35       # share of the deploy time spent dropping into place
const DROP_HEIGHT := 2500.0   # field units a new unit drops from


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


# --- Coordinates -----------------------------------------------------------

func _scale() -> float:
	return minf(size.x / BattleSim.WIDTH, size.y / (BattleSim.HEIGHT + HEADROOM))


## Room left above the field for the enemy's treehouses to stand up into.
func _origin() -> Vector2:
	var s := _scale()
	var room := size - Vector2(BattleSim.WIDTH, BattleSim.HEIGHT + HEADROOM) * s
	return Vector2(room.x / 2.0, room.y / 2.0 + HEADROOM * s)


func to_screen(x: float, y: float) -> Vector2:
	return _origin() + Vector2(x, y) * _scale()


func to_field(point: Vector2) -> Vector2i:
	var p := (point - _origin()) / _scale()
	return Vector2i(clampi(roundi(p.x), 0, BattleSim.WIDTH), clampi(roundi(p.y), 0, BattleSim.HEIGHT))


func tower_screen_position(team: int, kind: String) -> Vector2:
	for t in sim.towers(team):
		if t.tower_kind == kind:
			return to_screen(t.x, t.y)
	return size / 2.0


# --- Input -----------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_at = event.position
			_pressed = true
		elif _pressed:
			_pressed = false
			if event.position.distance_to(_press_at) < 24.0:
				var at := to_field(event.position)
				tapped.emit(at, sim.zone_for(0, at.x, at.y))


# --- Effects ---------------------------------------------------------------

## Turns battle events into short-lived visual effects.
func add_events(events: Array) -> void:
	for e in events:
		match e.type:
			"tool":
				_effect("ring", e.x, e.y, maxi(e.radius, 600), EFFECT_COLORS.get(e.effect, Color.WHITE), 0.6)
				_effect("icon", e.x, e.y, maxi(e.radius, 900), EFFECT_COLORS.get(e.effect, Color.WHITE), 0.7, GameData.card_icon(e.card))
			"release":
				_effect("ring", e.x, e.y, 900, OWN_COLOR if e.team == 0 else ENEMY_COLOR, 0.35)
			"hit":
				_effect("flash", e.x, e.y, 260, Color(1, 1, 1, 0.9), 0.12)
				if e.from_kind == "unit":
					_lunges[e.from] = {"age": 0.0, "dir": Vector2(e.x - e.fx, e.y - e.fy).normalized()}
					_on_unit_hit(e.from)
				if _views.has(e.to):
					_views[e.to].hurt = HURT_TIME
				if _views.has(e.from):
					_impact(UnitSprites.attack_style(_views[e.from].id), e)
				if e.to_kind == "tower":
					_effect("number", e.x + randi_range(-400, 400), e.y - 600, 0, Color("#ffd166"), 0.7, str(e.amount))
			"death":
				if _views.has(e.uid):
					_add_corpse(e.uid)
				else:
					_effect("ring", e.x, e.y, 1600 if e.kind == "tower" else 700, Color(0.2, 0.2, 0.2), 0.5 if e.kind == "tower" else 0.35)
				if e.kind == "tower":
					_shake = 0.45
			"heal", "cloud", "scare", "stun_pulse", "rage":
				_effect("ring", e.x, e.y, mini(e.radius, BattleSim.WIDTH), EFFECT_COLORS[e.type], 0.6)
			"tree":
				_effect("area", e.x, e.y, e.radius, EFFECT_COLORS.tree, e.seconds)
			"dodge", "play_dead", "revive", "roll_up", "sleep", "steal", "pounce", "emerge":
				_effect("text", e.x, e.y, 0, Color.WHITE, 0.8, _event_word(e.type))


func _event_word(kind: String) -> String:
	return {
		"dodge": "Dodge!", "play_dead": "Playing dead...", "revive": "Back up!", "roll_up": "Rolled up!",
		"sleep": "Zzz", "steal": "-1 energy", "pounce": "Pounce!", "emerge": "Surprise!",
	}.get(kind, "")


func _effect(kind: String, x: int, y: int, radius: int, color: Color, life: float, text := "") -> Dictionary:
	var fx := {"kind": kind, "x": x, "y": y, "radius": radius, "color": color, "life": life, "age": 0.0, "text": text,
		"dir": Vector2.UP, "seed": randi()}
	effects.append(fx)
	return fx


func _process(delta: float) -> void:
	_time += delta
	_shake = maxf(0.0, _shake - delta)
	for fx in effects:
		fx.age += delta
	effects = effects.filter(func(fx): return fx.age < fx.life)
	for uid in _lunges.keys():
		_lunges[uid].age += delta
		if _lunges[uid].age > 0.16:
			_lunges.erase(uid)
	if sim != null:
		_update_views(delta)
	_corpses = _corpses.filter(func(c): return _time - c.at < UnitSprites.duration(c.id, "death") + CORPSE_REST + CORPSE_FADE)
	_projectiles = _projectiles.filter(func(pr): return _time < pr.land)
	queue_redraw()


# --- Sprite animation state ---------------------------------------------------

func _update_views(delta: float) -> void:
	var seen := {}
	for f in sim.fighters:
		if not f.alive or not f.is_unit() or not UnitSprites.has(f.card.id):
			continue
		seen[f.uid] = true
		var pos := Vector2(lerpf(f.prev_x, f.x, blend), lerpf(f.prev_y, f.y, blend))
		var v: Dictionary = _views.get(f.uid, {})
		if v.is_empty():
			v = {"id": f.card.id, "pos": pos, "facing": 0.0 if f.team == 0 else 180.0, "hurt": 0.0,
				"walk": randf(), "moving": 0.0, "attack_at": -100.0, "team": f.team, "flying": f.is_flying(),
				"landed": f.deploy_ticks <= 0}
			_views[f.uid] = v
		if not v.landed and _drop(f) <= 0.0:
			v.landed = true
			if not v.flying:
				_effect("dust", int(f.x), int(f.y), 800 + f.radius * 2, Color("#b49a78"), 0.45)
		var moved: Vector2 = pos - v.pos
		v.pos = pos
		v.hurt = maxf(0.0, float(v.hurt) - delta)
		if moved.length() > 1.0:
			v.moving = 0.12
			_turn(v, moved, delta)
			v.walk += moved.length() / 1000.0 / UnitSprites.walk_cycle_tiles(v.id)
		else:
			v.moving = maxf(0.0, v.moving - delta)
			if f.target != null and f.target.alive:
				_turn(v, Vector2(f.target.x - f.x, f.target.y - f.y), delta)
		# Start the attack early enough that the bite lands on the hit.
		if f.target != null and f.target.alive and f.deploy_ticks <= 0 and sim.in_range(f, f.target) and not _attacking(v):
			var windup := _windup(v.id)
			var to_hit := (float(f.cooldown) / 100.0 - blend) / float(sim.tps)
			if to_hit >= 0.0 and to_hit <= windup:
				v.attack_at = _time - (windup - to_hit)
				if f.attack_range > 1500:
					_throw(f, to_hit)
	for uid in _views.keys():
		if not seen.has(uid):
			_views.erase(uid)


## How high a deploying unit still is, from 1 (just placed) down to 0 (landed).
func _drop(f: BattleSim.Fighter) -> float:
	if f.deploy_ticks <= 0:
		return 0.0
	var elapsed := float(sim.deploy_ticks - f.deploy_ticks) + blend
	var fall := clampf(elapsed / maxf(1.0, sim.deploy_ticks * DROP_PART), 0.0, 1.0)
	return 1.0 - fall * fall


func _turn(v: Dictionary, toward: Vector2, delta: float) -> void:
	if toward.length() < 1.0:
		return
	var goal := rad_to_deg(atan2(toward.x, -toward.y))
	var diff := wrapf(goal - float(v.facing), -180.0, 180.0)
	v.facing = float(v.facing) + clampf(diff, -TURN_SPEED * delta, TURN_SPEED * delta)


func _windup(id: String) -> float:
	return float(UnitSprites.animation(id, "attack").get("hit", 0.45)) * UnitSprites.duration(id, "attack")


func _attacking(v: Dictionary) -> bool:
	return _time - float(v.attack_at) < UnitSprites.duration(v.id, "attack")


func _on_unit_hit(uid: int) -> void:
	# A hit with no attack showing (the first one, often): jump to the strike.
	if _views.has(uid) and not _attacking(_views[uid]):
		_views[uid].attack_at = _time - _windup(_views[uid].id)


## A ranged animal's throw: leaves its paw before the hit and lands on it.
func _throw(f: BattleSim.Fighter, to_hit: float) -> void:
	var flight := minf(THROW_FLIGHT, to_hit + 0.15)
	_projectiles.append({"from": Vector2(f.x, f.y), "to_uid": f.target.uid, "to": Vector2(f.target.x, f.target.y),
		"launch": _time + to_hit - flight, "land": _time + to_hit})


## A hit effect that fits how the attacker fights.
func _impact(style: String, e: Dictionary) -> void:
	var dir := Vector2(e.x - e.fx, e.y - e.fy).normalized()
	var fx := {}
	match style:
		"swipe":
			fx = _effect("slash", e.x, e.y, 520, Color.WHITE, 0.28)
		"bite", "pounce_bite":
			fx = _effect("chomp", e.x, e.y, 420, Color.WHITE, 0.22)
		"charge":
			fx = _effect("dust", e.x, e.y, 700, Color("#b49a78"), 0.5)
		"stomp":
			_effect("ring", e.x, e.y, 1500, Color("#a88a62"), 0.45)
			fx = _effect("dust", e.x, e.y, 1000, Color("#b49a78"), 0.6)
			_shake = maxf(_shake, 0.18)
		"dive":
			fx = _effect("feathers", e.x, e.y, 500, Color("#f1ede4"), 0.5)
		_:
			return
	fx["dir"] = dir
	# Land on the target's body, not at its feet.
	if _views.has(e.to):
		var id: String = _views[e.to].id
		fx["lift"] = UnitSprites.top(id) * _scale() * 1000.0 / UnitSprites.pixels_per_tile(id) * SPRITE_SCALE * 0.45


func _add_corpse(uid: int) -> void:
	var v: Dictionary = _views[uid]
	_corpses.append({"id": v.id, "pos": v.pos, "facing": v.facing, "team": v.team, "at": _time})
	_views.erase(uid)


# --- Drawing ---------------------------------------------------------------

func _draw() -> void:
	if sim == null:
		return
	var s := _scale()
	var origin := _origin()
	var field := Rect2(origin, Vector2(BattleSim.WIDTH, BattleSim.HEIGHT) * s)
	var river_top := to_screen(0, BattleSim.RIVER_TOP).y
	var river_bottom := to_screen(0, BattleSim.RIVER_BOTTOM).y

	draw_rect(Rect2(Vector2.ZERO, size), Color("#13240f"))
	_shake_offset = Vector2.ZERO
	if _shake > 0.0:
		# A destroyed tower shakes the whole field for a moment.
		var strength := 10.0 * _shake / 0.45
		_shake_offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
	draw_set_transform(_shake_offset)
	# The meadow behind the enemy's dens, a shade darker than the field.
	draw_rect(Rect2(field.position - Vector2(0, HEADROOM * s), Vector2(field.size.x, HEADROOM * s)), grass.darkened(0.22))
	draw_rect(Rect2(field.position, Vector2(field.size.x, river_top - field.position.y)), grass.darkened(0.1))
	draw_rect(Rect2(Vector2(field.position.x, river_bottom), Vector2(field.size.x, field.end.y - river_bottom)), grass)
	var tile := BattleSim.TILE * s
	for row in 30:
		for col in 18:
			if (row + col) % 2 == 0:
				draw_rect(Rect2(origin + Vector2(col, row) * tile, Vector2(tile, tile)), Color(1, 1, 1, 0.035))

	draw_rect(Rect2(field.position.x, river_top, field.size.x, river_bottom - river_top), Color("#3a8fd6"))
	for i in 6:
		var wave_x := field.position.x + field.size.x * (i + 0.5) / 6.0
		var wave_y := (river_top + river_bottom) / 2.0
		draw_line(Vector2(wave_x - tile * 0.6, wave_y), Vector2(wave_x + tile * 0.6, wave_y), Color(1, 1, 1, 0.3), 2.0)
	for bridge_x in BattleSim.BRIDGE_XS:
		var left := to_screen(bridge_x - BattleSim.BRIDGE_HALF_WIDTH, BattleSim.RIVER_TOP - 300)
		var right := to_screen(bridge_x + BattleSim.BRIDGE_HALF_WIDTH, BattleSim.RIVER_BOTTOM + 300)
		var bridge := Rect2(left, right - left)
		draw_style_box(UIKit.box(Color("#9a6b3f"), 5), bridge)
		for plank in 4:
			var plank_y := bridge.position.y + bridge.size.y * (plank + 1) / 5.0
			draw_line(Vector2(bridge.position.x + 3, plank_y), Vector2(bridge.end.x - 3, plank_y), Color("#6e4a2a"), 2.0)

	_draw_highlight(field, river_top, river_bottom)

	for f in sim.fighters:
		if f.kind == "tower" and not f.alive:
			_draw_tower(f, s)
	for f in sim.fighters:
		if f.kind == "bait" and f.alive:
			_draw_bait(f, s)
	for corpse in _corpses:
		_draw_corpse(corpse, s)
	for flying in [false, true]:
		# Dens stand among the animals on the ground.
		var row: Array = sim.fighters.filter(func(f): return _drawn_in_row(f, flying))
		# Farther things first, so nearer ones overlap them.
		row.sort_custom(func(a, b): return a.y < b.y)
		for f in row:
			if f.kind == "tower":
				_draw_tower(f, s)
			else:
				_draw_unit(f, s)

	_draw_preview(s)
	for pr in _projectiles:
		_draw_projectile(pr, s)
	for fx in effects:
		_draw_effect(fx, s)


func _draw_highlight(field: Rect2, river_top: float, river_bottom: float) -> void:
	var glow := Color(1, 1, 0.6, 0.16)
	var edge := Color(1, 1, 0.6, 0.7)
	var areas := []
	if highlight_zones.has("enemy_side"):
		areas.append(Rect2(field.position, Vector2(field.size.x, river_top - field.position.y)))
	if highlight_zones.has("river"):
		areas.append(Rect2(field.position.x, river_top, field.size.x, river_bottom - river_top))
	if highlight_zones.has("own_side"):
		areas.append(Rect2(field.position.x, river_bottom, field.size.x, field.end.y - river_bottom))
		for pocket in sim.pocket_rects(0):
			var top_left := to_screen(pocket.position.x, pocket.position.y)
			areas.append(Rect2(top_left, to_screen(pocket.end.x, pocket.end.y) - top_left))
	for area in areas:
		draw_rect(area, glow)
		draw_rect(area.grow(-2), edge, false, 3.0)


## A see-through copy of the card where it would land: the tile, the
## animals in their group formation (or a tool's area), and the attack range.
## White when it can be released there, red when it can't.
func _draw_preview(s: float) -> void:
	if preview.is_empty():
		return
	var card: Dictionary = preview.card
	var at: Vector2i = preview.at
	var color := Color.WHITE if preview.valid else UIKit.RED.lightened(0.15)
	var pulse := 0.5 + 0.5 * sin(_time * 8.0)
	var tile := BattleSim.TILE * s
	var center := to_screen(at.x, at.y)
	var icon := UIKit.icon(GameData.card_icon(card.id))
	if card.kind == "tool":
		var radius := maxf(float(card.stats.get("radius", 1.0)), 0.6) * BattleSim.TILE * s
		draw_circle(center, radius, Color(color, 0.18 + 0.08 * pulse))
		draw_arc(center, radius, 0, TAU, 48, Color(color, 0.9), 4.0)
		if icon != null:
			var side := clampf(radius * 1.2, tile * 1.5, tile * 2.5)
			draw_texture_rect(icon, Rect2(center - Vector2(side, side) / 2.0, Vector2(side, side)), false, Color(color, 0.75))
		return
	# A glowing spot on the ground, bigger than the animals so it shows
	# around a fingertip.
	var spot := tile * 1.6
	draw_circle(center, spot, Color(color, 0.2 + 0.1 * pulse))
	draw_arc(center, spot, 0, TAU, 40, Color(color, 0.9), 3.0)
	var range_tiles := float(card.stats.get("range", 1))
	if range_tiles > 1.0:
		draw_arc(center, range_tiles * tile, 0, TAU, 48, Color(color, 0.4), 2.0)
	var count := int(card.get("count", 1))
	var r := maxf(10.0, BattleSim.unit_radius(card) * s * 1.6)
	var ring := OWN_COLOR if preview.valid else UIKit.RED
	var fill := UIKit.habitat_color(card) if preview.valid else UIKit.RED.darkened(0.3)
	for i in count:
		var offset := BattleSim.formation(i, count)
		var p := to_screen(at.x + offset.x, at.y + offset.y)
		draw_circle(p, r + 3, Color(ring, 0.8))
		draw_circle(p, r, Color(fill, 0.8))
		if icon != null:
			var side := r * 1.45
			draw_texture_rect(icon, Rect2(p - Vector2(side, side) / 2.0, Vector2(side, side)), false, Color(1, 1, 1, 0.9))


func _position(f: BattleSim.Fighter) -> Vector2:
	return to_screen(lerpf(f.prev_x, f.x, blend), lerpf(f.prev_y, f.y, blend))


func _drawn_in_row(f: BattleSim.Fighter, flying: bool) -> bool:
	if f.kind == "tower":
		return f.alive and not flying
	return f.is_unit() and f.alive and f.is_flying() == flying


## The rendered treehouse for a den, or {} if there is none.
static func _den_art(name: String) -> Dictionary:
	if _den_meta.is_empty():
		var text := FileAccess.get_file_as_string(DEN_ART + "towers.json")
		_den_meta = JSON.parse_string(text) if text != "" else {"none": true}
	if not _den_textures.has(name):
		var path := DEN_ART + name + ".webp"
		_den_textures[name] = load(path) if ResourceLoader.exists(path) else null
	if _den_textures[name] == null or not _den_meta.has(name):
		return {}
	return {"texture": _den_textures[name], "anchor": Vector2(_den_meta[name].anchor[0], _den_meta[name].anchor[1]),
		"top": float(_den_meta[name].top), "scale": 1000.0 / float(_den_meta.get("pixels_per_tile", 100))}


func _draw_tower(t: BattleSim.Fighter, s: float) -> void:
	var center := to_screen(t.x, t.y)
	var half := t.radius * s
	var team_name := "blue" if t.team == 0 else "red"
	var art := _den_art(("main_" if t.tower_kind == "main" else "side_") + (team_name if t.alive else "ruin"))
	if not art.is_empty():
		var k: float = art.scale * s * DEN_SCALE
		var texture: Texture2D = art.texture
		draw_texture_rect(texture, Rect2(center - art.anchor * k, texture.get_size() * k), false)
		if not t.alive:
			return
		var top: float = art.top * k
		if t.target != null and t.target.alive:
			var from := center - Vector2(0, top * 0.55)
			draw_line(from, from.lerp(_position(t.target), 0.25), Color(1, 1, 1, 0.35), 2.0)
		var color := OWN_COLOR if t.team == 0 else ENEMY_COLOR
		# The far main den stands right under the top bar, so its bar goes below it.
		var bar_y := center.y + half * 0.75 if t.team == 1 and t.tower_kind == "main" else center.y - top - 8
		_draw_bar(Vector2(center.x, bar_y), half * 2.0, 10.0, float(t.hp) / t.max_hp, color.lightened(0.2), str(t.hp))
		return
	var rect := Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0)
	if not t.alive:
		draw_style_box(UIKit.box(Color("#4a4a4a"), 8), rect.grow(-half * 0.25))
		draw_style_box(UIKit.box(Color("#2f2f2f"), 6), rect.grow(-half * 0.5))
		return
	var color := OWN_COLOR if t.team == 0 else ENEMY_COLOR
	var style := UIKit.box(color, int(half * 0.3))
	style.set_border_width_all(4)
	style.border_color = color.darkened(0.45)
	draw_style_box(style, rect)
	draw_style_box(UIKit.box(color.lightened(0.25), int(half * 0.2)), rect.grow(-half * 0.3))
	var tower_icon := UIKit.icon(GameData.ui_icon("main_tower" if t.tower_kind == "main" else "side_tower"))
	if tower_icon != null:
		var side := half * 1.3
		draw_texture_rect(tower_icon, Rect2(center - Vector2(side, side) / 2.0, Vector2(side, side)), false, Color(1, 1, 1, 0.92))
	if t.target != null and t.target.alive:
		var aim := _position(t.target)
		draw_line(center, center.lerp(aim, 0.25), Color(1, 1, 1, 0.35), 2.0)
	_draw_bar(center + Vector2(0, -half - 12), half * 2.0, 10.0, float(t.hp) / t.max_hp, color.lightened(0.2), str(t.hp))


func _draw_bait(f: BattleSim.Fighter, s: float) -> void:
	var p := to_screen(f.x, f.y)
	var r := f.radius * s
	draw_circle(p, r + 2, Color("#5a3a1a"))
	draw_circle(p, r, Color("#c98b4a"))
	var bait_icon := UIKit.icon(GameData.ui_icon("bait"))
	if bait_icon != null:
		draw_texture_rect(bait_icon, Rect2(p - Vector2(r, r) * 0.75, Vector2(r, r) * 1.5), false, Color.WHITE)
	_draw_bar(p + Vector2(0, -r - 8), r * 2.0, 6.0, float(f.hp) / f.max_hp, Color("#ffcf40"))


func _draw_unit(f: BattleSim.Fighter, s: float) -> void:
	if _views.has(f.uid):
		_draw_sprite_unit(f, s)
		return
	var p := _position(f)
	var r := maxf(7.0, f.radius * s * 1.25)
	# Little hops while walking, a pop-in while deploying, a lunge when attacking.
	if f.prev_x != f.x or f.prev_y != f.y:
		p.y -= absf(sin(_time * 11.0 + f.uid)) * r * 0.22
	if f.deploy_ticks > 0:
		r *= lerpf(1.0, 0.6, float(f.deploy_ticks) / maxf(1.0, sim.deploy_ticks))
	if _lunges.has(f.uid):
		var lunge: Dictionary = _lunges[f.uid]
		p += lunge.dir * r * 0.45 * sin(PI * clampf(lunge.age / 0.16, 0.0, 1.0))
	var team_color := OWN_COLOR if f.team == 0 else ENEMY_COLOR
	var alpha := 1.0
	if f.deploy_ticks > 0:
		alpha = 0.55
	if f.stealthed and f.revealed <= 0:
		alpha = 0.4 if f.team == 0 else 0.12
	if f.memory.get("burrowing", false):
		draw_circle(p, r * 0.8, Color(0.36, 0.24, 0.12, 0.85 if f.team == 0 else 0.5))
		draw_arc(p, r * 0.8, PI, TAU, 10, team_color, 2.0)
		return

	if f.is_flying():
		draw_circle(p + Vector2(0, r * 0.5), r * 0.8, Color(0, 0, 0, 0.25 * alpha))
		p.y -= r * 0.9
	var fill := UIKit.habitat_color(f.card)
	if int(f.memory.get("playing_dead", 0)) > 0:
		fill = Color("#777777")
	draw_circle(p, r + 3, Color(team_color, alpha))
	draw_circle(p, r, Color(fill, alpha))
	var icon := UIKit.icon(GameData.card_icon(f.card.id))
	if icon != null:
		var side := r * 1.45
		var icon_rect := Rect2(p - Vector2(side, side) / 2.0, Vector2(side, side))
		if GameData.card_icon_flipped(f.card.id):
			draw_set_transform(_shake_offset + Vector2(icon_rect.end.x, icon_rect.position.y), 0.0, Vector2(-1, 1))
			draw_texture_rect(icon, Rect2(Vector2.ZERO, icon_rect.size), false, Color(1, 1, 1, alpha))
			draw_set_transform(_shake_offset)
		else:
			draw_texture_rect(icon, icon_rect, false, Color(1, 1, 1, alpha))
	elif r >= 11:
		_draw_text(p, UIKit.initials(f.card.name), int(r * 0.85), Color(1, 1, 1, alpha))

	# Effect rings
	if f.stun > 0:
		draw_arc(p, r + 6, 0, TAU, 20, Color("#ffe066"), 3.0)
	if f.shield > 0:
		draw_arc(p, r + 5, 0, TAU, 20, Color("#7fd6ff"), 2.5)
	if f.rage > 0:
		draw_arc(p, r + 8, 0, TAU, 20, Color("#ff9f43", 0.8), 2.0)
	if f.poison > 0:
		draw_circle(p + Vector2(r * 0.7, -r * 0.7), maxf(3.0, r * 0.25), Color("#7bd34a"))
	if f.slow > 0:
		draw_arc(p, r + 4, 0, TAU, 20, Color("#9fd8ff", 0.8), 2.0)
	if f.invulnerable > 0:
		draw_arc(p, r + 6, 0, TAU, 20, Color("#ffffff"), 3.0)

	if f.hp < f.max_hp:
		_draw_bar(p + Vector2(0, -r - 8), maxf(r * 2.0, 26.0), 6.0, float(f.hp) / f.max_hp, team_color.lightened(0.3))


## An animal drawn from its rendered sprite sheet.
func _draw_sprite_unit(f: BattleSim.Fighter, s: float) -> void:
	var v: Dictionary = _views[f.uid]
	var id: String = v.id
	var p := to_screen(v.pos.x, v.pos.y)
	var k := s * 1000.0 / UnitSprites.pixels_per_tile(id) * SPRITE_SCALE
	if int(f.card.get("count", 1)) > 1:
		k *= SWARM_SCALE
	var team_color := OWN_COLOR if f.team == 0 else ENEMY_COLOR
	# Dropping into place: the ring marks where it will land.
	var drop := _drop(f)
	var alpha := clampf((1.0 - drop) * 4.0, 0.0, 1.0)
	var ring_alpha := 1.0 - drop
	if f.stealthed and f.revealed <= 0:
		alpha = 0.4 if f.team == 0 else 0.12
	var ring := f.radius * s * 1.45
	if f.memory.get("burrowing", false):
		draw_circle(p, ring * 0.7, Color(0.36, 0.24, 0.12, 0.85 if f.team == 0 else 0.5))
		return
	_draw_team_ring(p, ring, team_color, minf(alpha, ring_alpha))

	var anim := "idle"
	var frame := int((_time + f.uid * 0.37) * float(UnitSprites.animation(id, "idle").get("fps", 6)))
	var since := _time - float(v.attack_at)
	if since >= 0.0 and since < UnitSprites.duration(id, "attack"):
		anim = "attack"
		frame = int(since * float(UnitSprites.animation(id, "attack").fps))
	elif float(v.moving) > 0.0:
		anim = "walk"
		frame = int(float(v.walk) * float(UnitSprites.animation(id, "walk").frames))
	var info := UnitSprites.frame(id, anim, v.facing, frame)
	var tint := Color(1, 1, 1, alpha)
	if int(f.memory.get("playing_dead", 0)) > 0:
		tint = Color(0.6, 0.6, 0.6, alpha)
	elif f.stun > 0:
		tint = Color(1.0, 1.0, 0.7, alpha)
	if float(v.hurt) > 0.0:
		# Flash bright when hit.
		var h := float(v.hurt) / HURT_TIME
		tint = Color(tint.r + 0.35 * h, tint.g + 0.12 * h, tint.b + 0.1 * h, alpha)
	_blit(info, p - Vector2(0, drop * DROP_HEIGHT * s), k, tint)

	# Status rings around its feet.
	if f.stun > 0:
		_draw_team_ring(p, ring + 5, Color("#ffe066"), 1.0, 3.0)
	if f.shield > 0:
		_draw_team_ring(p, ring + 4, Color("#7fd6ff"), 1.0, 2.5)
	if f.rage > 0:
		_draw_team_ring(p, ring + 7, Color("#ff9f43", 0.8), 1.0, 2.0)
	if f.slow > 0:
		_draw_team_ring(p, ring + 3, Color("#9fd8ff", 0.8), 1.0, 2.0)
	if f.invulnerable > 0:
		_draw_team_ring(p, ring + 6, Color.WHITE, 1.0, 3.0)
	if f.poison > 0:
		draw_circle(p + Vector2(ring * 0.8, -ring * 1.6), maxf(3.0, ring * 0.2), Color("#7bd34a"))
	if f.hp < f.max_hp:
		_draw_bar(Vector2(p.x, p.y - UnitSprites.top(id) * k - 7.0), maxf(ring * 1.6, 26.0), 6.0, float(f.hp) / f.max_hp, team_color.lightened(0.3))


func _draw_corpse(corpse: Dictionary, s: float) -> void:
	var id: String = corpse.id
	var age := _time - float(corpse.at)
	var info_anim := UnitSprites.animation(id, "death")
	var frame := int(age * float(info_anim.get("fps", 10)))
	var fade := clampf(1.0 - (age - UnitSprites.duration(id, "death") - CORPSE_REST) / CORPSE_FADE, 0.0, 1.0)
	var p := to_screen(corpse.pos.x, corpse.pos.y)
	var k := s * 1000.0 / UnitSprites.pixels_per_tile(id) * SPRITE_SCALE
	if int(GameData.get_card(id).get("count", 1)) > 1:
		k *= SWARM_SCALE
	_blit(UnitSprites.frame(id, "death", corpse.facing, frame), p, k, Color(1, 1, 1, fade))


func _draw_team_ring(p: Vector2, radius: float, color: Color, alpha: float, width := 2.5) -> void:
	# Flattened to sit on the ground in the sprites' tilted view.
	draw_set_transform(_shake_offset + p, 0.0, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, radius, Color(color, 0.18 * alpha))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(color, 0.85 * alpha), width / 0.55 * 0.6)
	draw_set_transform(_shake_offset)


func _blit(info: Dictionary, p: Vector2, k: float, tint: Color) -> void:
	var region: Rect2 = info.region
	var anchor: Vector2 = info.anchor * k
	var size := region.size * k
	if info.flip:
		draw_set_transform(_shake_offset + p, 0.0, Vector2(-1, 1))
		draw_texture_rect_region(info.texture, Rect2(-anchor, size), region, tint)
		draw_set_transform(_shake_offset)
	else:
		draw_texture_rect_region(info.texture, Rect2(p - anchor, size), region, tint)


func _draw_projectile(pr: Dictionary, s: float) -> void:
	if _time < pr.launch:
		return
	var t := clampf((_time - float(pr.launch)) / maxf(float(pr.land) - float(pr.launch), 0.01), 0.0, 1.0)
	var goal: Vector2 = pr.to
	if _views.has(pr.to_uid):
		goal = _views[pr.to_uid].pos
	var from := to_screen(pr.from.x, pr.from.y)
	var to := to_screen(goal.x, goal.y)
	# An arc: up and over, a little higher for longer throws.
	var lift := from.distance_to(to) * 0.35 + 10.0
	var p := from.lerp(to, t) + Vector2(0, -lift * 4.0 * t * (1.0 - t) - 10.0)
	var r := maxf(3.0, 220.0 * s)
	draw_circle(p + Vector2(0, 10.0 + lift * 4.0 * t * (1.0 - t)) * 0.4, r * 0.8, Color(0, 0, 0, 0.25))
	draw_circle(p, r, Color("#7a4a22"))
	draw_circle(p + Vector2(0, -r * 0.45), r * 0.75, Color("#4b2e15"))
	draw_circle(p + Vector2(-r * 0.3, r * 0.15), r * 0.3, Color(1, 1, 1, 0.35))


func _draw_effect(fx: Dictionary, s: float) -> void:
	var p := to_screen(fx.x, fx.y) - Vector2(0, float(fx.get("lift", 0.0)))
	var t: float = fx.age / fx.life
	var color: Color = fx.color
	match fx.kind:
		"ring":
			var r: float = fx.radius * s * (0.6 + 0.4 * t)
			draw_circle(p, r, Color(color, 0.25 * (1.0 - t)))
			draw_arc(p, r, 0, TAU, 32, Color(color, 0.9 * (1.0 - t)), 3.0)
		"area":
			var r: float = fx.radius * s
			draw_circle(p, r, Color(color, 0.12))
			draw_arc(p, r, 0, TAU, 32, Color(color, 0.5), 2.0)
		"flash":
			draw_circle(p, fx.radius * s * (1.0 - t), Color(color, 0.8 * (1.0 - t)))
		"text":
			_draw_text(p + Vector2(0, -30 - 30 * t), fx.text, 20, Color(1, 1, 1, 1.0 - t))
		"number":
			_draw_text(p + Vector2(0, -24 * t), fx.text, 18, Color(color, 1.0 - t * t))
		"slash":
			# Three claw marks raking across the target.
			var r: float = fx.radius * s
			var d: Vector2 = fx.dir
			var across := Vector2(-d.y, d.x)
			var reach := clampf(t * 2.2, 0.0, 1.0)
			for i in 3:
				var offset := across * (float(i) - 1.0) * r * 0.32
				var a := p + offset - d * r * 0.6 + across * r * 0.25
				var b := p + offset + d * r * 0.6 - across * r * 0.25
				var tip := a.lerp(b, reach)
				draw_line(a, tip, Color(0, 0, 0, 0.4 * (1.0 - t)), 5.0)
				draw_line(a, tip, Color(color, 1.0 - t), 2.5)
		"chomp":
			# Two jaws snapping shut on the target.
			var r: float = fx.radius * s
			var gap := (1.0 - clampf(t * 2.5, 0.0, 1.0)) * r * 0.5
			var ang: float = fx.dir.angle()
			var col := Color(color, 1.0 - t * t)
			draw_arc(p - Vector2.from_angle(ang + PI / 2) * gap, r, ang + PI * 0.15, ang + PI * 0.85, 10, col, 3.0)
			draw_arc(p + Vector2.from_angle(ang + PI / 2) * gap, r, ang - PI * 0.85, ang - PI * 0.15, 10, col, 3.0)
		"dust":
			# Puffs of dust bursting out from the impact.
			var rng := RandomNumberGenerator.new()
			rng.seed = int(fx.seed)
			for i in 7:
				var ang := rng.randf() * TAU
				var dist: float = fx.radius * s * (0.3 + 0.7 * t) * (0.5 + rng.randf() * 0.5)
				var puff: float = fx.radius * s * (0.12 + 0.2 * t) * (0.7 + rng.randf() * 0.6)
				var at := p + Vector2(cos(ang), sin(ang) * 0.55) * dist
				draw_circle(at, puff, Color(color, 0.55 * (1.0 - t)))
		"feathers":
			var rng := RandomNumberGenerator.new()
			rng.seed = int(fx.seed)
			for i in 6:
				var ang := rng.randf() * TAU
				var dist: float = fx.radius * s * (0.2 + 0.8 * t) * (0.5 + rng.randf() * 0.5)
				var at := p + Vector2(cos(ang), sin(ang)) * dist + Vector2(0, 14.0 * t)
				draw_set_transform(_shake_offset + at, ang + t * 3.0, Vector2(1.0, 0.35))
				draw_circle(Vector2.ZERO, 5.0, Color(color, 1.0 - t))
				draw_set_transform(_shake_offset)
		"icon":
			var texture := UIKit.icon(fx.text)
			if texture != null:
				var side: float = fx.radius * s * (0.7 + 0.3 * t)
				draw_texture_rect(texture, Rect2(p - Vector2(side, side) / 2.0, Vector2(side, side)), false, Color(color, 0.85 * (1.0 - t)))


func _draw_bar(center: Vector2, width: float, height: float, ratio: float, color: Color, label := "") -> void:
	var rect := Rect2(center - Vector2(width / 2.0, height / 2.0), Vector2(width, height))
	draw_rect(rect.grow(1.5), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(rect.position, Vector2(width * clampf(ratio, 0.0, 1.0), height)), color)
	if label != "":
		_draw_text(center + Vector2(0, -height - 2), label, 15, Color.WHITE)


func _draw_text(center: Vector2, text: String, font_size: int, color: Color) -> void:
	if font_size < 6:
		return
	var font := get_theme_default_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := center + Vector2(-width / 2.0, font_size * 0.36)
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(2, font_size / 5), Color(0, 0, 0, color.a * 0.8))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
