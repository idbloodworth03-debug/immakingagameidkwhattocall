class_name ModelStage
extends Node2D
## The animals of a fight as real 3D models (art/models/battle/, from
## tools/creatures/export_gltf.py --lod battle) instead of sprites. Only the
## animals' bodies are 3D: the arena, shadows and team rings, banners,
## effects and health bars stay the battle field's own 2D layers, and this
## sits among them where the sprites were.
##
## One transparent 3D viewport the size of the field holds every model. Its
## orthographic camera looks down at the same 50 degrees the sprites were
## rendered from, and follows the field's own 2D camera each frame, so a
## model stands exactly where its sprite would (one field tile is one unit
## across, and 1 / sin 50 units deep, as the arena pictures stretch it).
## Each UnitView still runs all the choreography (which animation, how far
## through it, squash, lean, hops, flashes, knockouts) and says what to show
## (UnitView.m_*); this only poses the model to match.
## Settings: feel.json "models"; shading: viewer.json "look".

const SKIN_SHADER := preload("res://scripts/fx/model_skin.gdshader")
const OUTLINE_SHADER := preload("res://scripts/fx/model_outline.gdshader")
const DIR := "res://art/models/battle/"
const ATTACKS := ["attack", "attack2", "special"]
## Each cartoon face as the eye shader's [blink, lid, pupil size, happy, dizzy].
const FACES := {
	"": [0.0, 0.0, 1.0, 0.0, 0.0], "blink": [1.0, 0.0, 1.0, 0.0, 0.0], "squint": [0.0, 0.48, 1.0, 0.0, 0.0],
	"drowsy": [0.0, 0.62, 1.0, 0.0, 0.0], "smug": [0.0, 0.5, 1.0, 0.0, 0.0], "wide": [0.0, 0.0, 0.68, 0.0, 0.0],
	"happy": [0.0, 0.0, 1.0, 1.0, 0.0], "dizzy": [0.0, 0.0, 1.0, 0.0, 1.0],
}
## The camera's 50-degree look down (as the sprites and arenas were rendered).
const SIN := 0.76604444
const COS := 0.64278761

static var _scenes := {}
static var _index := {}

var field: BattleField
var viewport: SubViewport
var camera: Camera3D
var render_scale := 1.0
var _models := {}
## Models of animals that left the field, kept to reuse (building one is the
## slow part), by animal id.
var _pool := {}
var _settings: Dictionary = {}
var _drawn_size := Vector2.ZERO


## One animal's model: a pivot at its feet (the sprite's squash, stretch
## and lean, in the camera's plane), turned to face its way, holding the
## model scaled to its size on the field.
class Model:
	var pivot: Node3D
	var turn: Node3D
	var body: Node3D
	var player: AnimationPlayer
	var skin: ShaderMaterial
	var outline: ShaderMaterial
	var anim := ""
	var lengths := {}
	var size := 1.0
	var face := "-"
	var shown := {}
	var id := ""


static func make(on: BattleField) -> ModelStage:
	var stage := ModelStage.new()
	stage.field = on
	stage.name = "models"
	return stage


## True if this animal has a battle model.
static func has_model(id: String) -> bool:
	return ResourceLoader.exists(DIR + id + ".glb")


static func _scene(id: String) -> PackedScene:
	if not _scenes.has(id):
		_scenes[id] = load(DIR + id + ".glb") if has_model(id) else null
	return _scenes[id]


## Its size in field tiles per model unit (its longest side is its
## tiles_long, as the sprites have it).
static func tile_scale(id: String) -> float:
	if _index.is_empty():
		var file := FileAccess.open(DIR + "models.json", FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				_index = parsed
	return float(_index.get(id, {}).get("tile_scale", 1.0))


func _ready() -> void:
	_settings = GameData.feel.get("models", {})
	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X if int(_settings.get("msaa", 2)) >= 4 else (Viewport.MSAA_2X if int(_settings.get("msaa", 2)) >= 2 else Viewport.MSAA_DISABLED)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.5
	camera.far = 400.0
	viewport.add_child(camera)


func _draw() -> void:
	if viewport != null:
		draw_texture_rect(viewport.get_texture(), Rect2(Vector2.ZERO, _drawn_size), false)


## Poses every model to match its animal this frame (after the views have
## animated). New animals get a model, gone ones lose theirs.
func sync(views: Dictionary, now: float) -> void:
	if viewport == null or field.size.x <= 0.0:
		return
	var stretch := get_viewport().get_final_transform().get_scale().x if get_viewport() != null else 1.0
	render_scale = clampf(stretch, 1.0, float(_settings.get("render_scale_max", 2.0)))
	var pixels := Vector2i((field.size * render_scale).round())
	if viewport.size != pixels:
		viewport.size = pixels
	if _drawn_size != field.size:
		_drawn_size = field.size
		queue_redraw()
	var ppu := field.field_scale() * 1000.0
	if ppu <= 0.0:
		return
	# The camera: the screen's middle over the field point under it.
	aim(camera, field.screen_to_field(field.size / 2.0), ppu, field.size.y)
	var forward := Vector3(0.0, -SIN, -COS)

	var right := Vector3(1, 0, 0)
	var up := Vector3(0, COS, -SIN)
	var seen := {}
	for key in views:
		var v: UnitView = views[key]
		if not v.modeled:
			continue
		var m: Model = _models.get(key)
		if m != null and m.id != v.id:
			# Another animal under the same key now (a new fight's): its own
			# model, and the old one back in the pool.
			_retire(m)
			_models.erase(key)
			m = null
		if m == null:
			m = _make_model(v)
			if m == null:
				v.modeled = false
				continue
			_models[key] = m
		seen[key] = true
		_pose(m, v, now, ppu, right, up, forward)
	for key in _models.keys():
		if not seen.has(key):
			_retire(_models[key])
			_models.erase(key)


## A model no animal needs any more: hidden, and kept for the next of its
## kind.
func _retire(m: Model) -> void:
	m.pivot.visible = false
	(_pool.get_or_add(m.id, []) as Array).append(m)


func _make_model(v: UnitView) -> Model:
	var spare: Array = _pool.get(v.id, [])
	if not spare.is_empty():
		var reused: Model = spare.pop_back()
		_fit(reused, v)
		reused.outline.set_shader_parameter("width_px", outline_px(render_scale))
		reused.anim = ""
		reused.face = "-"
		reused.pivot.visible = true
		return reused
	var m := new_model(v.id, outline_px(render_scale), true)
	if m == null:
		return null
	_fit(m, v)
	viewport.add_child(m.pivot)
	return m


## Its size on the field (as the sprite's: its squad's, an elite's or a
## hero's size, a swarm smaller).
func _fit(m: Model, v: UnitView) -> void:
	var c := "characters"
	m.size = tile_scale(v.id) * Feel.num(c, "sprite_scale", 1.6) * v.size_k * (Feel.num(c, "swarm_scale", 0.8) if v.swarm else 1.0)
	m.body.scale = Vector3.ONE * m.size


## The outline's width in the viewport's real pixels.
static func outline_px(scale: float) -> float:
	return Feel.num("models", "outline_px", 1.5) * scale


## A new model of an animal in the cartoon shading (viewer.json "look"), for
## any 3D layer: a pivot (at its feet), turned to face its way, holding the
## model. `manual`: its animation is posed by hand (seek), not played.
static func new_model(id: String, outline_width: float, manual := false) -> Model:
	var scene := _scene(id)
	if scene == null:
		return null
	var m := Model.new()
	m.id = id
	m.pivot = Node3D.new()
	m.turn = Node3D.new()
	m.pivot.add_child(m.turn)
	m.body = scene.instantiate() as Node3D
	m.turn.add_child(m.body)
	m.skin = ShaderMaterial.new()
	m.skin.shader = SKIN_SHADER
	m.outline = ShaderMaterial.new()
	m.outline.shader = OUTLINE_SHADER
	var look: Dictionary = GameData.viewer.get("look", {})
	var key_dir: Array = look.get("key_dir", [-0.45, 0.72, 0.55])
	m.skin.set_shader_parameter("key_dir", Vector3(float(key_dir[0]), float(key_dir[1]), float(key_dir[2])))
	for key in ["key_color", "shade_color", "rim_color"]:
		if look.has(key):
			m.skin.set_shader_parameter(key, Color(String(look[key])))
	for key in ["soft", "rim", "rim_width", "highlight", "vibrance"]:
		if look.has(key):
			m.skin.set_shader_parameter(key, float(look[key]))
	m.skin.set_shader_parameter("lid_color", UnitSprites.lid_color(id))
	m.outline.set_shader_parameter("width_px", outline_width)
	m.outline.set_shader_parameter("color", Color(String(look.get("outline_color", "#140c09"))))
	m.skin.next_pass = m.outline
	for mesh in m.body.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh as MeshInstance3D
		instance.material_override = m.skin
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var players := m.body.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		m.player = players[0]
		if manual:
			m.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for anim in m.player.get_animation_list():
			m.lengths[String(anim)] = m.player.get_animation(anim).length
	return m


## Points an orthographic camera down at the sprites' 50 degrees so that
## field point `middle` (field units) is the view's middle, at `ppu` screen
## pixels a tile, `view_height` pixels tall.
static func aim(cam: Camera3D, middle: Vector2, ppu: float, view_height: float) -> void:
	var forward := Vector3(0.0, -SIN, -COS)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = view_height / ppu
	cam.basis = Basis.looking_at(forward, Vector3.UP)
	cam.position = Vector3(middle.x / 1000.0, 0.0, middle.y / 1000.0 / SIN) - forward * 80.0


## A field point (field units) in the 3D layer, on the ground.
static func ground(at: Vector2) -> Vector3:
	return Vector3(at.x / 1000.0, 0.0, at.y / 1000.0 / SIN)


## Turns the model to face `degrees` (clockwise from up on screen), on the
## stretched ground.
static func face_toward(m: Model, degrees: float) -> void:
	var f := deg_to_rad(degrees)
	var dir := Vector2(sin(f), -cos(f) / SIN)
	m.turn.rotation.y = atan2(-dir.x, -dir.y)


func _pose(m: Model, v: UnitView, now: float, ppu: float, right: Vector3, up: Vector3, forward: Vector3) -> void:
	var showing := v.m_visible and v.m_opacity > 0.02
	m.pivot.visible = showing
	if not showing:
		return
	# Where: its feet on the field, then the sprite's offset in the camera's plane.
	var at := ground(v.render_pos())
	at += right * (v.m_offset.x / ppu) + up * (-v.m_offset.y / ppu)
	m.pivot.position = at
	# Squash, stretch and lean, as the sprite has them on screen.
	var camera_frame := Basis(right, up, -forward)
	var squash := camera_frame * Basis.from_scale(Vector3(v.m_scale.x, v.m_scale.y, v.m_scale.x)) * camera_frame.inverse()
	m.pivot.basis = Basis(forward, deg_to_rad(v.m_rot)) * squash
	# Which way it faces (on the stretched ground).
	face_toward(m, v.m_facing)
	# Its animation, at the view's point in it.
	if m.player != null:
		var anim := v.m_anim
		if not m.lengths.has(anim):
			anim = "attack" if anim in ATTACKS and m.lengths.has("attack") else "idle"
		if m.lengths.has(anim):
			if anim != m.anim:
				m.anim = anim
				m.player.current_animation = anim
			m.player.seek(v.m_phase * float(m.lengths[anim]), true)
	# Its cartoon face (UnitView chooses it, as for the sprite).
	if v.m_face != m.face:
		m.face = v.m_face
		var face: Array = FACES.get(m.face, FACES[""])
		_param(m, m.skin, "blink", float(face[0]))
		_param(m, m.skin, "lid", float(face[1]))
		_param(m, m.skin, "pupil_size", float(face[2]))
		_param(m, m.skin, "happy", float(face[3]))
		_param(m, m.skin, "dizzy", float(face[4]))
	if m.face == "dizzy":
		_param(m, m.skin, "spin", snappedf(fposmod(now * 7.0, TAU), 0.05))
	_param(m, m.skin, "flash", snappedf(v.m_flash, 0.02))
	_param(m, m.skin, "gold", snappedf(v.m_gold, 0.02))
	_param(m, m.outline, "gold", snappedf(v.m_gold, 0.02))
	_param(m, m.skin, "opacity", snappedf(v.m_opacity, 0.02))
	_param(m, m.outline, "opacity", snappedf(v.m_opacity, 0.02))
	_param(m, m.skin, "tint", v.m_tint)


## Sets a shader value only when it changes (dozens of animals, every frame).
func _param(m: Model, material: ShaderMaterial, param: String, value: Variant) -> void:
	var key := "%d%s" % [material.get_instance_id(), param]
	if m.shown.get(key) != value:
		m.shown[key] = value
		material.set_shader_parameter(param, value)


func model_count() -> int:
	return _models.size()
