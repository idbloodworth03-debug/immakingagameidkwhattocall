class_name ParticleLayer
extends Node2D
## Bright cartoon particles: sparks, puffs, stars, sparkles, confetti, coins,
## petals, leaves, dust, hearts and acorns, with a cap on how many there can
## be at once (data/feel.json, "effects"). On its own it moves itself along
## every frame; the battlefield's effects layer (FxLayer) builds on it and is
## moved along by the field instead, so hit-stop freezes it too.
##
## All of them are drawn in a single draw call: one MultiMesh of quads, each
## showing a cell of the particle sheet (art/ui/particles.png, made by
## tools/make_ui_art.py). Drawing each particle as shapes cost two or three
## draw calls apiece, which a phone's browser feels in a big celebration.

const SHEET := "res://art/ui/particles.png"
const SHADER := preload("res://scripts/fx/particle.gdshader")

var particles: Array = []
var time := 0.0
## False when something else calls step_particles() (the battlefield).
var self_driven := true

var _mesh: MultiMeshInstance2D
static var _cells: Dictionary = {}
static var _quad: ArrayMesh


func _process(delta: float) -> void:
	if self_driven:
		step_particles(delta)

func step_particles(dt: float) -> void:
	time += dt
	for p in particles:
		p.age += dt
		p.vel *= maxf(0.0, 1.0 - float(p.drag) * dt)
		p.vel.y += float(p.gravity) * dt
		p.pos += p.vel * dt
		p.rot += float(p.spin) * dt
	particles = particles.filter(func(p): return p.age < p.life)
	_update_mesh()


## The sheet's cell number for each kind.
static func cell_of(kind: String) -> int:
	if _cells.is_empty():
		var kinds: Array = SkinBox.meta().get("particles", {}).get("kinds", [])
		for i in kinds.size():
			_cells[kinds[i]] = i
	return int(_cells.get(kind, 0))


func _ensure_mesh() -> void:
	if _mesh != null:
		return
	if _quad == null:
		# A unit quad centered on the origin (2D, y down).
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)])
		_quad = ArrayMesh.new()
		_quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = _quad
	multimesh.instance_count = Feel.count("effects", "max_particles", 320)
	multimesh.visible_instance_count = 0
	_mesh = MultiMeshInstance2D.new()
	_mesh.multimesh = multimesh
	_mesh.texture = load(SHEET)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	var info: Dictionary = SkinBox.meta().get("particles", {})
	var kinds: Array = info.get("kinds", [])
	var columns := int(info.get("columns", 4))
	material.set_shader_parameter("grid", Vector2(columns, ceili(kinds.size() / float(columns))))
	_mesh.material = material
	add_child(_mesh)


## Fills the MultiMesh with this frame's particles.
func _update_mesh() -> void:
	if _mesh == null:
		if particles.is_empty():
			return
		_ensure_mesh()
	var multimesh := _mesh.multimesh
	var count := mini(particles.size(), multimesh.instance_count)
	for i in count:
		var look := _look(particles[i])
		multimesh.set_instance_transform_2d(i, look.xform)
		multimesh.set_instance_color(i, look.color)
		multimesh.set_instance_custom_data(i, Color(float(look.cell), 0, 0, 0))
	multimesh.visible_instance_count = count

# --- Particles ---------------------------------------------------------------

## Adds one particle. `kind`: "spark", "puff", "star", "sparkle", "confetti",
## "coin", "petal", "leaf", "dust", "glow", "heart" or "acorn". Positions are
## in this layer's pixels.
func particle(kind: String, at: Vector2, vel: Vector2, life: float, size: float, color: Color,
		gravity := 0.0, drag := 2.0, spin := 0.0) -> void:
	if particles.size() >= Feel.count("effects", "max_particles", 320):
		return
	particles.append({"kind": kind, "pos": at, "vel": vel, "life": life, "age": 0.0, "size": size,
		"color": color, "gravity": gravity, "drag": drag, "rot": randf() * TAU, "spin": spin})
	_ensure_mesh()


## A ring of particles flying out from `at`.
func burst(kind: String, at: Vector2, count: int, speed: float, life: float, size: float, colors: Array,
		gravity := 0.0, drag := 3.0, upward := 0.0) -> void:
	for i in count:
		var ang := randf() * TAU
		var v := Vector2(cos(ang), sin(ang) * 0.75) * speed * randf_range(0.55, 1.1) + Vector2(0, -upward)
		particle(kind, at, v, life * randf_range(0.75, 1.15), size * randf_range(0.7, 1.2),
			colors[i % colors.size()], gravity, drag, randf_range(-8.0, 8.0))


func burst_hit(at: Vector2, strong: bool, dir: Vector2) -> void:
	var e := "effects"
	var count := Feel.count(e, "strong_hit_sparks" if strong else "hit_sparks", 8 if strong else 5)
	for i in count:
		var ang := dir.angle() + randf_range(-1.1, 1.1)
		var speed := randf_range(140.0, 300.0) * (1.3 if strong else 1.0)
		particle("spark", at, Vector2.from_angle(ang) * speed, randf_range(0.14, 0.24), randf_range(5.0, 9.0),
			Color("#fff6b0") if i % 2 == 0 else Color.WHITE, 0.0, 6.0)
	particle("puff", at, Vector2.ZERO, 0.12, 8.0 if strong else 5.0, Color(1, 1, 1, 0.8), 0.0, 0.0)
	if strong:
		burst("star", at, 3, 160.0, 0.45, 7.0, [Color("#ffe14d"), Color.WHITE], 380.0, 1.5, 90.0)


func burst_defeat(at: Vector2) -> void:
	var e := "effects"
	burst("puff", at, Feel.count(e, "defeat_puffs", 7), 95.0, 0.45, Feel.num(e, "defeat_puff_size", 8.0), [Color(1, 1, 1, 0.9), Color("#e8eef7", 0.85)], -40.0, 3.5)
	burst("star", at, Feel.count(e, "defeat_stars", 6), 230.0, 0.7, 8.0, [Color("#ffe14d"), Color("#ffb03b"), Color.WHITE], 520.0, 1.2, 160.0)


func burst_spawn(at: Vector2) -> void:
	burst("sparkle", at, Feel.count("effects", "spawn_sparkles", 9), 110.0, 0.55, 7.0, [Color.WHITE, Color("#fff3a8"), Color("#bff0ff")], -30.0, 3.0)
	burst("puff", at + Vector2(0, 2), 5, 70.0, 0.4, 9.0, [Color(0.85, 0.78, 0.62, 0.7)], 0.0, 4.0)


func burst_upgrade(view: UnitView) -> void:
	var at := view.position + Vector2(0, -UnitSprites.top(view.id) * view.body.k * 0.5)
	burst("sparkle", at, Feel.count("effects", "upgrade_sparkles", 14), 170.0, 0.7, 9.0, [Color("#ffe14d"), Color.WHITE, Color("#ffd27a")], -60.0, 2.5)
	burst("star", at, 4, 140.0, 0.6, 8.0, [Color("#ffe14d")], 300.0, 1.2, 120.0)


func burst_confetti(at: Vector2, count: int) -> void:
	var colors := [Color("#ff5d73"), Color("#ffd23f"), Color("#4be38b"), Color("#3b8ff0"), Color("#c86bff"), Color("#ff9f43")]
	for i in count:
		var v := Vector2(randf_range(-220.0, 220.0), randf_range(-420.0, -160.0))
		particle("confetti", at, v, randf_range(0.9, 1.5), randf_range(6.0, 10.0), colors[i % colors.size()], 520.0, 1.6, randf_range(-12.0, 12.0))


func burst_coins(at: Vector2, count: int) -> void:
	for i in count:
		var v := Vector2(randf_range(-150.0, 150.0), randf_range(-380.0, -200.0))
		particle("coin", at, v, randf_range(0.7, 1.0), randf_range(8.0, 11.0), Color("#ffd23f"), 900.0, 0.8, randf_range(6.0, 12.0))


func burst_heal(at: Vector2) -> void:
	burst("sparkle", at, Feel.count("effects", "heal_sparkles", 6), 70.0, 0.7, 7.0, [Color("#7dffb0"), Color.WHITE], -90.0, 2.0)


## Where a particle is, how big, which way it's turned, its cell and color.
## The sheet's shapes fill about 80% of their cell, so a particle of
## radius r needs a quad about 2.5 r across.
func _look(p: Dictionary) -> Dictionary:
	var t: float = p.age / p.life
	var col: Color = p.color
	var size: float = p.size
	var kind: String = p.kind
	var pos: Vector2 = p.pos
	var rot := 0.0
	var scale := Vector2.ONE * size * 2.5
	var alpha := 1.0
	match kind:
		"spark":
			var v: Vector2 = p.vel
			var length := clampf(v.length() * 0.05, 3.0, 22.0) * (1.0 - t)
			rot = v.angle()
			scale = Vector2(length * 1.6 + 4.0, (size * 0.5 * (1.0 - t) + 1.0) * 6.0)
			alpha = 1.0 - t
		"puff", "dust":
			var r := size * (0.6 + 1.1 * Ease.out_cubic(t))
			scale = Vector2.ONE * r * 2.4
			alpha = col.a * (1.0 - t * t)
		"star":
			scale = Vector2.ONE * size * (1.0 - 0.3 * t) * 2.6
			rot = p.rot
			alpha = 1.0 - t * t
		"sparkle":
			scale = Vector2.ONE * size * Ease.arc(t) * 1.3 * 2.5
			alpha = 1.0 - t * 0.5
		"confetti":
			rot = p.rot
			scale = Vector2(size * 1.25, size * 1.25 * maxf(0.12, absf(cos(float(p.rot) * 1.7))))
			alpha = 1.0 - Ease.in_cubic(t)
		"coin":
			scale = Vector2(size * 2.5 * maxf(0.15, absf(cos(float(p.rot)))), size * 2.5)
			alpha = 1.0 - Ease.in_cubic(t)
		"petal", "leaf":
			rot = p.rot
			scale = Vector2(size * 2.5, size * 2.5)
			alpha = col.a * minf(1.0, (1.0 - t) * 3.0) * minf(1.0, t * 5.0)
		"glow":
			scale = Vector2.ONE * size * 2.5 * (0.8 + 0.4 * Ease.out_cubic(t))
			alpha = col.a * (1.0 - t)
		_:
			rot = p.rot
			alpha = 1.0 - Ease.in_cubic(t)
	return {"xform": Transform2D(rot, scale, 0.0, pos), "color": Color(col.r, col.g, col.b, alpha), "cell": cell_of(kind)}





