class_name HabitatStage
extends Node3D
## The little 3D scene an animal stands in, in the 3D animal viewer: a round
## stage in its habitat's colors, simple cartoon scenery behind and beside it
## (trees, rocks, ice, reeds...), a sky, water for Ocean and Wetlands, and
## little things drifting by (snow, pollen, leaves, bubbles, fireflies).
## Everything is built from a few primitive shapes, drawn unlit with the same
## soft shading as the animal (prop.gdshader), so it's cheap and smooth on a
## phone. All of it comes from data/viewer.json "habitats".

const PROP_SHADER := preload("res://scripts/fx/prop.gdshader")
const OUTLINE_SHADER := preload("res://scripts/fx/model_outline.gdshader")
const WATER_SHADER := preload("res://scripts/fx/water.gdshader")
const SKY_SHADER := preload("res://scripts/fx/sky.gdshader")
const DOT_SHADER := preload("res://scripts/fx/dot.gdshader")

## How much each kind of scenery sways in the breeze.
const SWAY := {"grass": 0.22, "reed": 0.1, "weed": 0.16, "frond": 0.1, "flower": 0.12, "palm": 0.04, "pine": 0.02,
	"round_tree": 0.02, "acacia": 0.015}

var habitat := ""
var spec: Dictionary = {}
var render_scale := 1.0
var _materials := {}
var _outline: ShaderMaterial
var _look: Dictionary = {}


static func make(habitat_id: String, scale_for_pixels := 1.0) -> HabitatStage:
	var stage := HabitatStage.new()
	var all: Dictionary = GameData.viewer.get("habitats", {})
	stage.habitat = habitat_id if all.has(habitat_id) else "forest"
	stage.spec = all.get(stage.habitat, {})
	stage.render_scale = scale_for_pixels
	stage._build()
	return stage


func _build() -> void:
	_look = GameData.viewer.get("look", {})
	_outline = ShaderMaterial.new()
	_outline.shader = OUTLINE_SHADER
	_outline.set_shader_parameter("width_px", float(_look.get("prop_outline_px", 1.3)) * render_scale)
	_outline.set_shader_parameter("color", Color(String(_look.get("outline_color", "#140c09"))))
	var platform: Dictionary = GameData.viewer.get("platform", {})
	var radius := float(platform.get("radius", 1.15))
	var height := float(platform.get("height", 0.2))
	var ground := Color(String(spec.get("ground", "#6cc04a")))

	# The stage: a round block with the habitat's ground on top.
	var block := CylinderMesh.new()
	block.top_radius = radius
	block.bottom_radius = radius * 0.94
	block.height = height
	block.radial_segments = 64
	_add(block, _material(Color(String(spec.get("side", "#8a5a32")))), Vector3(0, -height / 2.0 - 0.01, 0))
	var top := CylinderMesh.new()
	top.top_radius = radius + float(platform.get("lip", 0.035))
	top.bottom_radius = top.top_radius
	top.height = 0.04
	top.radial_segments = 64
	_add(top, _material(ground), Vector3(0, -0.02, 0))

	# The world round it: water, or the same ground a step down.
	var water: Dictionary = spec.get("water", {})
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2.ONE * float(water.get("radius", 14.0)) * 2.0 if not water.is_empty() else Vector2(60, 60)
	if water.is_empty():
		_add(floor_mesh, _material(ground.darkened(0.12), 0.0, false, false), Vector3(0, -height, 0))
	else:
		var sea := ShaderMaterial.new()
		sea.shader = WATER_SHADER
		sea.set_shader_parameter("deep", _color(String(water.get("color", "water"))))
		sea.set_shader_parameter("shine", _color(String(water.get("shine", "shine"))))
		var plane := MeshInstance3D.new()
		plane.mesh = floor_mesh
		plane.material_override = sea
		plane.position = Vector3(0, -height * 0.6, 0)
		add_child(plane)

	for prop in spec.get("props", []):
		_prop(prop)
	for prop in spec.get("far", []):
		_prop(prop, false)
	_drift(spec.get("drift", {}))


## The sky: a gradient card behind everything, held by the camera.
func make_sky(distance: float, fov: float, aspect: float) -> MeshInstance3D:
	var sky_colors: Array = spec.get("sky", ["#7cc8ff", "#dff3ff"])
	var card := QuadMesh.new()
	var half_height := distance * tan(deg_to_rad(fov) / 2.0) * 1.3
	card.size = Vector2(half_height * 2.0 * maxf(aspect, 1.0) * 1.3, half_height * 2.0)
	var sky := ShaderMaterial.new()
	sky.shader = SKY_SHADER
	sky.set_shader_parameter("top", Color(String(sky_colors[0])))
	sky.set_shader_parameter("bottom", Color(String(sky_colors[1])))
	var node := MeshInstance3D.new()
	node.mesh = card
	node.material_override = sky
	node.position = Vector3(0, 0, -distance)
	node.extra_cull_margin = 16384.0
	return node


func _color(key: String) -> Color:
	var colors: Dictionary = spec.get("colors", {})
	return Color(String(colors.get(key, key if key.begins_with("#") else "#888888")))


func _material(color: Color, sway := 0.0, flat := false, outline := true) -> ShaderMaterial:
	var key := "%s/%s/%s/%s" % [color.to_html(), sway, flat, outline]
	if _materials.has(key):
		return _materials[key]
	var mat := ShaderMaterial.new()
	mat.shader = PROP_SHADER
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("sway", sway)
	var key_dir: Array = _look.get("key_dir", [-0.45, 0.72, 0.55])
	mat.set_shader_parameter("key_dir", Vector3(float(key_dir[0]), float(key_dir[1]), float(key_dir[2])))
	mat.set_shader_parameter("key_color", Color(String(_look.get("key_color", "#fff6ea"))))
	mat.set_shader_parameter("shade_color", Color.WHITE if flat else Color(String(_look.get("shade_color", "#a097bd"))))
	mat.set_shader_parameter("soft", float(_look.get("soft", 0.5)))
	if outline:
		mat.next_pass = _outline
	_materials[key] = mat
	return mat


func _add(mesh: Mesh, mat: Material, at: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else self).add_child(node)
	return node


## One piece of scenery: [kind, x, z, size, color name, turn in degrees].
func _prop(entry: Array, near := true) -> void:
	var kind := String(entry[0])
	var s := float(entry[3])
	var color := _color(String(entry[4]))
	var root := Node3D.new()
	root.position = Vector3(float(entry[1]), 0.0, float(entry[2]))
	root.rotation.y = deg_to_rad(float(entry[5]) if entry.size() > 5 else 0.0)
	root.name = kind
	add_child(root)
	var sway := float(SWAY.get(kind, 0.0)) if near else 0.0
	var mat := _material(color, sway / maxf(s, 0.3), false, near)
	var trunk := _material(_color("trunk"), 0.0, false, near)
	match kind:
		"pine":
			_add(_cylinder(0.05 * s, 0.07 * s, 0.26 * s), trunk, Vector3(0, 0.13 * s, 0), root)
			for tier in [[0.42, 0.46, 0.42], [0.33, 0.4, 0.66], [0.22, 0.34, 0.88]]:
				_add(_cylinder(0.0, tier[0] * s, tier[1] * s, 20), mat, Vector3(0, tier[2] * s, 0), root)
		"round_tree":
			_add(_cylinder(0.06 * s, 0.08 * s, 0.5 * s), trunk, Vector3(0, 0.25 * s, 0), root)
			_add(_sphere(0.34 * s), mat, Vector3(0, 0.7 * s, 0), root)
			_add(_sphere(0.22 * s), mat, Vector3(0.24 * s, 0.6 * s, 0.05 * s), root)
			_add(_sphere(0.2 * s), mat, Vector3(-0.22 * s, 0.62 * s, -0.04 * s), root)
		"acacia":
			var stem := _add(_cylinder(0.035 * s, 0.06 * s, 0.66 * s), trunk, Vector3(0, 0.32 * s, 0), root)
			stem.rotation.z = 0.12
			var crown := _add(_sphere(0.5 * s), mat, Vector3(0.08 * s, 0.7 * s, 0), root)
			crown.scale = Vector3(1.0, 0.28, 0.8)
		"palm":
			var bend := Node3D.new()
			bend.rotation.z = -0.15
			root.add_child(bend)
			_add(_cylinder(0.035 * s, 0.055 * s, 0.82 * s), trunk, Vector3(0, 0.41 * s, 0), bend)
			for i in 6:
				var leaf := _add(_sphere(0.3 * s), mat, Vector3(0, 0.82 * s, 0), bend)
				leaf.scale = Vector3(1.0, 0.1, 0.32)
				leaf.rotation = Vector3(0, i * TAU / 6.0, -0.35)
				leaf.position += Vector3(cos(i * TAU / 6.0), 0, -sin(i * TAU / 6.0)) * 0.24 * s
		"frond":
			for i in 5:
				var leaf := _add(_sphere(0.36 * s), mat, Vector3.ZERO, root)
				leaf.scale = Vector3(0.32, 1.0, 0.08)
				var angle := (i - 2) * 0.45
				leaf.rotation = Vector3(0, 0, angle)
				leaf.position = Vector3(-sin(angle) * 0.3 * s, 0.3 * s * cos(angle), 0)
		"bush":
			_add(_sphere(0.3 * s), mat, Vector3(0, 0.22 * s, 0), root)
			_add(_sphere(0.22 * s), mat, Vector3(0.25 * s, 0.14 * s, 0.05 * s), root)
			_add(_sphere(0.2 * s), mat, Vector3(-0.24 * s, 0.13 * s, 0.02 * s), root)
		"rock", "boulder":
			var rock := _add(_sphere(0.5 * s, 9, 6), mat, Vector3(0, 0.12 * s, 0), root)
			rock.scale = Vector3(1.0, 0.62, 0.8)
		"mushroom":
			_add(_cylinder(0.1 * s, 0.13 * s, 0.4 * s), _material(Color("#fff4e0"), 0.0, false, near), Vector3(0, 0.2 * s, 0), root)
			var cap := _add(_sphere(0.32 * s, 20, 10, true), mat, Vector3(0, 0.36 * s, 0), root)
			cap.scale = Vector3(1, 0.8, 1)
			for spot in [Vector3(0.12, 0.6, 0.18), Vector3(-0.15, 0.58, 0.1), Vector3(0.0, 0.64, -0.12)]:
				_add(_sphere(0.05 * s), _material(Color("#fff4e0"), 0.0, false, false), spot * s, root)
		"grass":
			for i in 7:
				var blade := _add(_cylinder(0.0, 0.035 * s, (0.6 + 0.4 * fmod(i * 0.37, 1.0)) * s, 6), mat, Vector3.ZERO, root)
				var a := i * 2.4
				blade.position = Vector3(cos(a) * 0.12 * s, blade.mesh.height / 2.0, sin(a) * 0.1 * s)
				blade.rotation = Vector3(sin(a) * 0.25, 0, cos(a) * 0.3)
		"flower":
			_add(_cylinder(0.015 * s, 0.02 * s, 0.6 * s, 6), _material(Color("#3f9a3a"), sway, false, near), Vector3(0, 0.3 * s, 0), root)
			_add(_sphere(0.14 * s), mat, Vector3(0, 0.64 * s, 0), root)
			_add(_sphere(0.06 * s), _material(Color("#ffe14a"), 0.0, false, false), Vector3(0, 0.66 * s, 0.1 * s), root)
		"reed":
			for i in 4:
				var x := (i - 1.5) * 0.09 * s
				var tall := (0.8 + 0.2 * fmod(i * 0.61, 1.0)) * s
				_add(_cylinder(0.012 * s, 0.018 * s, tall, 6), mat, Vector3(x, tall / 2.0, sin(i * 1.7) * 0.06 * s), root)
				if i % 2 == 0:
					var tail := _add(_capsule(0.035 * s, 0.2 * s), _material(_color("cattail"), sway, false, near), Vector3(x, tall, sin(i * 1.7) * 0.06 * s), root)
					tail.name = "cattail"
		"lily":
			var pad := _add(_cylinder(0.4 * s, 0.4 * s, 0.02, 24), mat, Vector3(0, -0.1, 0), root)
			pad.name = "pad"
			_add(_sphere(0.1 * s), _material(Color("#ff8ac0"), 0.0, false, near), Vector3(0.1 * s, -0.05, 0), root)
		"ice":
			var block := _add(_box(Vector3(1.0, 0.8, 0.75) * s * 0.6), mat, Vector3(0, 0.22 * s, 0), root)
			block.rotation.x = 0.08
		"icicle":
			for i in 3:
				_add(_cylinder(0.0, 0.07 * s, (0.5 + i * 0.2) * s, 6), mat, Vector3((i - 1) * 0.1 * s, (0.25 + i * 0.1) * s, 0), root)
		"snow":
			var mound := _add(_sphere(0.5 * s), mat, Vector3(0, 0.0, 0), root)
			mound.scale = Vector3(1, 0.5, 0.9)
		"peak":
			_add(_cylinder(0.0, 0.6 * s, s, 7), mat, Vector3(0, 0.5 * s, 0), root)
			_add(_cylinder(0.0, 0.22 * s, 0.37 * s, 7), _material(Color.WHITE, 0.0, false, near), Vector3(0, 0.82 * s, 0), root)
		"hill":
			var hill := _add(_sphere(0.5 * s, 24, 12), mat, Vector3(0, -0.12 * s, 0), root)
			hill.scale = Vector3(1, 0.5, 0.7)
		"sun":
			_add(_sphere(0.5 * s), _material(color, 0.0, true, false), Vector3(0, 1.5 * s, 0), root)
		"shell":
			var shell := _add(_sphere(0.5 * s, 16, 8, true), mat, Vector3.ZERO, root)
			shell.scale = Vector3(1, 0.55, 0.8)
		"starfish":
			for i in 5:
				var arm := _add(_sphere(0.25 * s), mat, Vector3.ZERO, root)
				arm.scale = Vector3(1, 0.22, 0.32)
				arm.rotation.y = i * TAU / 5.0
				arm.position = Vector3(cos(i * TAU / 5.0), 0.04, -sin(i * TAU / 5.0)) * 0.22 * s + Vector3(0, 0.03 * s, 0)
		"weed":
			for i in 3:
				var tall := (0.7 + 0.25 * i) * s
				_add(_capsule(0.03 * s, tall), mat, Vector3((i - 1) * 0.08 * s, tall / 2.0, 0), root)
		"fence":
			for x in [-0.42, 0.42]:
				_add(_box(Vector3(0.08, 0.55, 0.08) * s), mat, Vector3(x * s, 0.27 * s, 0), root)
			for y in [0.22, 0.42]:
				_add(_box(Vector3(1.0, 0.07, 0.05) * s), mat, Vector3(0, y * s, 0), root)
		"hay":
			var bale := _add(_cylinder(0.3 * s, 0.3 * s, 0.5 * s, 20), mat, Vector3(0, 0.3 * s, 0), root)
			bale.rotation.z = PI / 2.0
		"lamp":
			_add(_cylinder(0.025 * s, 0.035 * s, s, 8), mat, Vector3(0, 0.5 * s, 0), root)
			_add(_box(Vector3(0.22, 0.03, 0.03) * s), mat, Vector3(0.1 * s, 0.97 * s, 0), root)
			_add(_sphere(0.08 * s), _material(_color("light"), 0.0, true, near), Vector3(0.2 * s, 0.92 * s, 0), root)
		"bin":
			_add(_cylinder(0.17 * s, 0.15 * s, 0.42 * s, 16), mat, Vector3(0, 0.21 * s, 0), root)
			_add(_cylinder(0.19 * s, 0.19 * s, 0.05 * s, 16), _material(color.darkened(0.2), 0.0, false, near), Vector3(0, 0.44 * s, 0), root)
		"box":
			_add(_box(Vector3.ONE * 0.4 * s), mat, Vector3(0, 0.2 * s, 0), root)
		"building":
			_add(_box(Vector3(0.8, 1.0, 0.6) * s), mat, Vector3(0, 0.5 * s, 0), root)
			var glow := _material(_color("window"), 0.0, true, false)
			for row in 3:
				for column in 2:
					_add(_box(Vector3(0.16, 0.14, 0.02) * s), glow, Vector3((column - 0.5) * 0.32 * s, (0.3 + row * 0.24) * s, 0.3 * s), root)
		_:
			_add(_sphere(0.3 * s), mat, Vector3(0, 0.3 * s, 0), root)


func _drift(drift: Dictionary) -> void:
	if drift.is_empty() or int(drift.get("amount", 0)) <= 0:
		return
	var kind := String(drift.get("kind", "pollen"))
	var particles := CPUParticles3D.new()
	particles.name = "drift"
	particles.amount = int(drift.get("amount", 12))
	particles.lifetime = 8.0
	particles.preprocess = 8.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(2.4, 0.8, 1.6)
	particles.position = Vector3(0, 1.0, -0.4)
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 180.0
	particles.initial_velocity_min = 0.02
	particles.initial_velocity_max = 0.08
	particles.gravity = Vector3.ZERO
	particles.scale_amount_min = 0.025
	particles.scale_amount_max = 0.05
	var ring := 0.0
	match kind:
		"snow":
			particles.position = Vector3(0, 2.4, -0.3)
			particles.emission_box_extents = Vector3(2.6, 0.1, 1.8)
			particles.gravity = Vector3(0.03, -0.22, 0)
			particles.lifetime = 11.0
			particles.preprocess = 11.0
		"leaves":
			particles.position = Vector3(0, 2.2, -0.4)
			particles.emission_box_extents = Vector3(2.4, 0.1, 1.4)
			particles.gravity = Vector3(0.08, -0.14, 0)
			particles.lifetime = 13.0
			particles.preprocess = 13.0
			particles.scale_amount_min = 0.035
			particles.scale_amount_max = 0.06
		"bubbles":
			particles.position = Vector3(0, -0.1, -0.2)
			particles.emission_box_extents = Vector3(2.4, 0.05, 1.6)
			particles.gravity = Vector3(0, 0.16, 0)
			particles.scale_amount_min = 0.03
			particles.scale_amount_max = 0.07
			ring = 1.0
		"fireflies":
			particles.scale_amount_min = 0.025
			particles.scale_amount_max = 0.04
	# Fade in, hold, fade out.
	var fade := Gradient.new()
	fade.set_offset(0, 0.0)
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_offset(1, 1.0)
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.15, Color.WHITE)
	fade.add_point(0.85, Color.WHITE)
	particles.color_ramp = fade
	var colors: Array = drift.get("colors", ["#ffffff"])
	var pick := Gradient.new()
	pick.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	pick.set_color(0, Color(String(colors[0])))
	pick.set_color(1, Color(String(colors[-1])))
	for i in range(1, colors.size()):
		pick.add_point(float(i) / colors.size(), Color(String(colors[i])))
	particles.color_initial_ramp = pick
	var dot := QuadMesh.new()
	dot.size = Vector2.ONE
	var mat := ShaderMaterial.new()
	mat.shader = DOT_SHADER
	mat.set_shader_parameter("ring", ring)
	dot.material = mat
	particles.mesh = dot
	add_child(particles)


func _cylinder(top: float, bottom: float, height: float, sides := 16) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh


func _sphere(radius: float, sides := 16, rings := 8, half := false) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * (1.0 if half else 2.0)
	mesh.radial_segments = sides
	mesh.rings = rings
	mesh.is_hemisphere = half
	return mesh


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = 8
	mesh.rings = 2
	return mesh


func _box(extent: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = extent
	return mesh
