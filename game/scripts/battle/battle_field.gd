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
var effects: Array = []

var _press_at := Vector2.ZERO
var _pressed := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


# --- Coordinates -----------------------------------------------------------

func _scale() -> float:
	return minf(size.x / BattleSim.WIDTH, size.y / BattleSim.HEIGHT)


func _origin() -> Vector2:
	var s := _scale()
	return (size - Vector2(BattleSim.WIDTH, BattleSim.HEIGHT) * s) / 2.0


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
				tapped.emit(at, sim.zone_for(0, at.y))


# --- Effects ---------------------------------------------------------------

## Turns battle events into short-lived visual effects.
func add_events(events: Array) -> void:
	for e in events:
		match e.type:
			"tool":
				_effect("ring", e.x, e.y, maxi(e.radius, 600), EFFECT_COLORS.get(e.effect, Color.WHITE), 0.6)
			"release":
				_effect("ring", e.x, e.y, 900, OWN_COLOR if e.team == 0 else ENEMY_COLOR, 0.35)
			"hit":
				_effect("flash", e.x, e.y, 260, Color(1, 1, 1, 0.9), 0.12)
			"death":
				_effect("ring", e.x, e.y, 1600 if e.kind == "tower" else 700, Color(0.2, 0.2, 0.2), 0.5 if e.kind == "tower" else 0.35)
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


func _effect(kind: String, x: int, y: int, radius: int, color: Color, life: float, text := "") -> void:
	effects.append({"kind": kind, "x": x, "y": y, "radius": radius, "color": color, "life": life, "age": 0.0, "text": text})


func _process(delta: float) -> void:
	for fx in effects:
		fx.age += delta
	effects = effects.filter(func(fx): return fx.age < fx.life)
	queue_redraw()


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
		if f.kind == "tower":
			_draw_tower(f, s)
	for f in sim.fighters:
		if f.kind == "bait" and f.alive:
			_draw_bait(f, s)
	for flying in [false, true]:
		for f in sim.fighters:
			if f.is_unit() and f.alive and f.is_flying() == flying:
				_draw_unit(f, s)

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
	for area in areas:
		draw_rect(area, glow)
		draw_rect(area.grow(-2), edge, false, 3.0)


func _position(f: BattleSim.Fighter) -> Vector2:
	return to_screen(lerpf(f.prev_x, f.x, blend), lerpf(f.prev_y, f.y, blend))


func _draw_tower(t: BattleSim.Fighter, s: float) -> void:
	var center := to_screen(t.x, t.y)
	var half := t.radius * s
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
	if t.tower_kind == "main":
		_draw_text(center, "MAIN", int(half * 0.45), Color.WHITE)
	if t.target != null and t.target.alive:
		var aim := _position(t.target)
		draw_line(center, center.lerp(aim, 0.25), Color(1, 1, 1, 0.35), 2.0)
	_draw_bar(center + Vector2(0, -half - 12), half * 2.0, 10.0, float(t.hp) / t.max_hp, color.lightened(0.2), str(t.hp))


func _draw_bait(f: BattleSim.Fighter, s: float) -> void:
	var p := to_screen(f.x, f.y)
	var r := f.radius * s
	draw_circle(p, r + 2, Color("#5a3a1a"))
	draw_circle(p, r, Color("#c98b4a"))
	_draw_text(p, "BAIT", int(r * 0.7), Color.WHITE)
	_draw_bar(p + Vector2(0, -r - 8), r * 2.0, 6.0, float(f.hp) / f.max_hp, Color("#ffcf40"))


func _draw_unit(f: BattleSim.Fighter, s: float) -> void:
	var p := _position(f)
	var r := maxf(7.0, f.radius * s * 1.25)
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
	if r >= 11:
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


func _draw_effect(fx: Dictionary, s: float) -> void:
	var p := to_screen(fx.x, fx.y)
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
