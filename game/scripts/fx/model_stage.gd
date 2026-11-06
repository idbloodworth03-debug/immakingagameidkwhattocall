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
var _look: Dictionary = {}
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
	var blink_at := -10.0
	var blink_next := 0.0
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
	_look = GameData.viewer.get("look", {})
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
	var middle := field.screen_to_field(field.size / 2.0)
	var forward := Vector3(0.0, -SIN, -COS)
	camera.size = field.size.y / ppu
	camera.basis = Basis.looking_at(forward, Vector3.UP)
	camera.position = Vector3(middle.x / 1000.0, 0.0, middle.y / 1000.0 / SIN) - forward * 80.0

	var right := Vector3(1, 0, 0)
	var up := Vector3(0, COS, -SIN)
	var seen := {}
	for key in views:
		var v: UnitView = views[key]
		if not v.modeled:
			continue
		var m: Model = _models.get(key)
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
			var gone: Model = _models[key]
			gone.pivot.visible = false
			(_pool.get_or_add(gone.id, []) as Array).append(gone)
			_models.erase(key)


func _make_model(v: UnitView) -> Model:
	var spare: Array = _pool.get(v.id, [])
	if not spare.is_empty():
		var reused: Model = spare.pop_back()
		_fit(reused, v)
		_apply_look(reused, v)
		reused.anim = ""
		reused.pivot.visible = true
		return reused
	var scene := _scene(v.id)
	if scene == null:
		return null
	var m := Model.new()
	m.id = v.id
	m.pivot = Node3D.new()
	m.turn = Node3D.new()
	m.pivot.add_child(m.turn)
	m.body = scene.instantiate() as Node3D
	m.turn.add_child(m.body)
	_fit(m, v)
	m.skin = ShaderMaterial.new()
	m.skin.shader = SKIN_SHADER
	m.outline = ShaderMaterial.new()
	m.outline.shader = OUTLINE_SHADER
	_apply_look(m, v)
	m.skin.next_pass = m.outline
	for mesh in m.body.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh as MeshInstance3D
		instance.material_override = m.skin
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var players := m.body.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		m.player = players[0]
		# Posed by hand every frame, to the view's timing.
		m.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for anim in m.player.get_animation_list():
			m.lengths[String(anim)] = m.player.get_animation(anim).length
	m.blink_next = randf_range(0.5, 4.0)
	viewport.add_child(m.pivot)
	return m


## Its size on the field (as the sprite's: its squad's, an elite's or a
## hero's size, a swarm smaller).
func _fit(m: Model, v: UnitView) -> void:
	var c := "characters"
	m.size = tile_scale(v.id) * Feel.num(c, "sprite_scale", 1.6) * v.size_k * (Feel.num(c, "swarm_scale", 0.8) if v.swarm else 1.0)
	m.body.scale = Vector3.ONE * m.size


func _apply_look(m: Model, v: UnitView) -> void:
	var key_dir: Array = _look.get("key_dir", [-0.45, 0.72, 0.55])
	m.skin.set_shader_parameter("key_dir", Vector3(float(key_dir[0]), float(key_dir[1]), float(key_dir[2])))
	for key in ["key_color", "shade_color", "rim_color"]:
		if _look.has(key):
			m.skin.set_shader_parameter(key, Color(String(_look[key])))
	for key in ["soft", "rim", "rim_width", "highlight", "vibrance"]:
		if _look.has(key):
			m.skin.set_shader_parameter(key, float(_look[key]))
	m.skin.set_shader_parameter("lid_color", UnitSprites.lid_color(v.id))
	m.outline.set_shader_parameter("width_px", float(_settings.get("outline_px", 1.5)) * render_scale)
	m.outline.set_shader_parameter("color", Color(String(_look.get("outline_color", "#140c09"))))


func _pose(m: Model, v: UnitView, now: float, ppu: float, right: Vector3, up: Vector3, forward: Vector3) -> void:
	var showing := v.m_visible and v.m_opacity > 0.02
	m.pivot.visible = showing
	if not showing:
		return
	# Where: its feet on the field, then the sprite's offset in the camera's plane.
	var feet := v.render_pos()
	var at := Vector3(feet.x / 1000.0, 0.0, feet.y / 1000.0 / SIN)
	at += right * (v.m_offset.x / ppu) + up * (-v.m_offset.y / ppu)
	m.pivot.position = at
	# Squash, stretch and lean, as the sprite has them on screen.
	var camera_frame := Basis(right, up, -forward)
	var squash := camera_frame * Basis.from_scale(Vector3(v.m_scale.x, v.m_scale.y, v.m_scale.x)) * camera_frame.inverse()
	m.pivot.basis = Basis(forward, deg_to_rad(v.m_rot)) * squash
	# Which way it faces (on the stretched ground).
	var f := deg_to_rad(v.m_facing)
	var dir := Vector2(sin(f), -cos(f) / SIN)
	m.turn.rotation.y = atan2(-dir.x, -dir.y)
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
	# Blinks now and then.
	if now >= m.blink_next:
		m.blink_at = now
		m.blink_next = now + randf_range(2.0, 5.0)
	var blink := clampf(1.0 - absf((now - m.blink_at) / 0.07 - 1.0), 0.0, 1.0)
	_param(m, m.skin, "blink", snappedf(blink, 0.05))
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
