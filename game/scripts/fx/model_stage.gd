class_name ModelStage
extends Node2D
## The animals of a fight as real 3D models (art/models/battle/, from
## tools/creatures/export_gltf.py --lod battle) instead of sprites. Only the
## animals' bodies are 3D: the arena, shadows and team rings, banners,
## effects and health bars stay the battle field's own 2D layers, and this
## sits among them where the sprites were.
##
## One transparent 3D viewport the size of the field holds every model. Its
## orthographic camera is tilted as feel.json "camera" tilt_degrees says (the
## angle the arena pictures and sprites are rendered from), and follows the
## field's own 2D camera each frame, so a model stands exactly where its
## sprite would (one field tile is one unit across, and 1 / sin(look down)
## units deep, as the arena pictures stretch it).
## Each UnitView still runs all the choreography (which animation, how far
## through it, squash, lean, hops, flashes, knockouts) and says what to show
## (UnitView.m_*); this only poses the model to match.
## Settings: feel.json "models"; shading: viewer.json "look".

const SKIN_SHADER := preload("res://scripts/fx/model_skin.gdshader")
const OUTLINE_SHADER := preload("res://scripts/fx/model_outline.gdshader")
## Animals with the movie look (docs/ART_DIRECTION.md): their own shading.
const MOVIE_SHADER := preload("res://scripts/fx/model_movie.gdshader")
## Animals from a flat-color art pack (tools/packs): their own shading too.
const TOON_SHADER := preload("res://scripts/fx/model_toon.gdshader")
const DIR := "res://art/models/battle/"
const ATTACKS := ["attack", "attack2", "special"]
## Each cartoon face as the eye shader's [blink, lid, pupil size, happy, dizzy].
const FACES := {
	"": [0.0, 0.0, 1.0, 0.0, 0.0], "blink": [1.0, 0.0, 1.0, 0.0, 0.0], "squint": [0.0, 0.48, 1.0, 0.0, 0.0],
	"drowsy": [0.0, 0.62, 1.0, 0.0, 0.0], "smug": [0.0, 0.5, 1.0, 0.0, 0.0], "wide": [0.0, 0.0, 0.68, 0.0, 0.0],
	"happy": [0.0, 0.0, 1.0, 1.0, 0.0], "dizzy": [0.0, 0.0, 1.0, 0.0, 1.0],
}
## The camera's look down at the field (feel.json "camera" tilt_degrees:
## how far it leans from straight down; the arenas are rendered from the
## same angle): SIN and COS of its angle below level, read once.
static var SIN := 0.0
static var COS := 0.0


## Reads the camera's angle from the data the first time it's needed.
static func angle() -> void:
	if SIN > 0.0:
		return
	var down := deg_to_rad(90.0 - Feel.num("camera", "tilt_degrees", 40.0))
	SIN = sin(down)
	COS = cos(down)


## The cosine of the camera's look down (how much of a height shows on the
## screen), for the 2D layers that lift things off the ground.
static func cos_down() -> float:
	angle()
	return COS

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
## For the feel report: animation changes that cross-faded (feel.json
## "acting" blend_seconds) and ones that cut (a model's first, a missing
## animation).
var blends := 0
var cuts := 0


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
	## The team's colored band outside the dark outline (battle only).
	var team_line: ShaderMaterial
	var team := -1
	## It has the movie look (its own shading; its locks' outline pushed back).
	var movie := false
	## It comes from a flat-color art pack (its own shading; its face is
	## real geometry moved by blendshapes on face_meshes, not drawn by the
	## shader; its outline outline_k times the usual width).
	var toon := false
	var face_meshes: Array = []
	var outline_k := 1.0
	var anim := ""
	var lengths := {}
	var size := 1.0
	var face := "-"
	var shown := {}
	var id := ""
	## Its mesh instances (for measuring it on screen).
	var meshes: Array = []
	## Its skeleton (for measuring its real outline as posed).
	var skeleton: Skeleton3D


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
## animated; `dt` is the frame's time, 0 during hit-stop, which the
## cross-fades between animations run on). New animals get a model, gone
## ones lose theirs.
func sync(views: Dictionary, now: float, dt := 0.0) -> void:
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
	angle()
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
		_pose(m, v, now, dt, ppu, right, up, forward)
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
		reused.outline.set_shader_parameter("width_px", outline_px(render_scale) * reused.outline_k)
		_set_team(reused, v.team)
		reused.anim = ""
		reused.face = "-"
		reused.pivot.visible = true
		return reused
	var m := new_model(v.id, outline_px(render_scale), true)
	if m == null:
		return null
	_fit(m, v)
	_set_team(m, v.team)
	viewport.add_child(m.pivot)
	return m


## The bold band in `team`'s color (blue yours, red the enemy's) round the
## dark outline, so sides read at a glance even packed close (feel.json
## "models" team_outline_px; drawn by a second, wider hull pushed back
## team_outline_depth so the dark line stays on top).
func _set_team(m: Model, team: int) -> void:
	var px := Feel.num("models", "team_outline_px", 2.0)
	if px <= 0.0 or team < 0:
		return
	if m.team_line == null:
		m.team_line = ShaderMaterial.new()
		m.team_line.shader = OUTLINE_SHADER
		m.team_line.set_shader_parameter("depth_push", Feel.num("models", "team_outline_depth", 0.06))
		if m.movie:
			m.team_line.set_shader_parameter("lock_push", lock_push())
		m.outline.next_pass = m.team_line
	m.team = team
	m.team_line.set_shader_parameter("color", BattleField.team_color(team))
	m.team_line.set_shader_parameter("width_px", outline_px(render_scale) * m.outline_k + px * render_scale)


## Its size on the field: its natural size (tile_scale) times the view's
## draw factor (bodies.json "size" over its natural longest side).
func _fit(m: Model, v: UnitView) -> void:
	m.size = tile_scale(v.id) * v.size_k
	m.body.scale = Vector3.ONE * m.size


static var _boxes := {}


## A battle model's box at its natural size (tile_scale), in field tiles:
## {"longest": its longest side, "up": how tall it stands along the
## camera's up (its real outline in its idle pose, facing whichever way
## makes it tallest: its height and its length, foreshortened), "tallest":
## the most it rises in a fight's poses}. Measured once from the mesh.
static func natural_box(id: String) -> Dictionary:
	if _boxes.has(id):
		return _boxes[id]
	var info := {"longest": 1.0, "up": 1.0, "tallest": 1.0}
	var scene := _scene(id)
	if scene != null:
		var root := scene.instantiate() as Node3D
		var box := AABB()
		var first := true
		for mesh in root.find_children("*", "MeshInstance3D", true, false):
			var mi := mesh as MeshInstance3D
			var xf := mi.transform
			var p := mi.get_parent()
			while p != null and p != root:
				if p is Node3D:
					xf = (p as Node3D).transform * xf
				p = p.get_parent()
			var b: AABB = xf * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		var ts := tile_scale(id)
		if not first:
			info.longest = maxf(box.size.x, maxf(box.size.y, box.size.z)) * ts
			angle()
			# Its real outline as it stands (its bounding box at rest would
			# add a fifth or so; that's the fallback without a skeleton).
			var stand := _idle_up(root)
			info.up = (stand if stand > 0.0 else box.size.y * COS + box.size.z * SIN) * ts
			# The tallest it stands on the screen in a fight, its real outline
			# in its tallest pose (bodies.json pose_up, measured from its
			# animations: tests/test_sizes.gd keeps it true).
			info.tallest = float(info.up) * float(GameData.bodies.get("animals", {}).get(id, {}).get("pose_up", 1.0))
		root.free()
	_boxes[id] = info
	return info


## How tall a model (a fresh copy, not in the scene tree) stands along the
## camera's up in its idle pose (the first moment of its "idle"), in model
## units: a sample of its mesh's points, skinned to that pose, facing up,
## down or across the field, whichever is tallest. 0 without a skeleton.
static func _idle_up(root: Node3D) -> float:
	var skeletons := root.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return 0.0
	var skeleton: Skeleton3D = skeletons[0]
	var players := root.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty() and (players[0] as AnimationPlayer).has_animation("idle"):
		var idle := (players[0] as AnimationPlayer).get_animation("idle")
		for i in idle.get_track_count():
			var bone := skeleton.find_bone(idle.track_get_path(i).get_concatenated_subnames())
			if bone < 0:
				continue
			match idle.track_get_type(i):
				Animation.TYPE_POSITION_3D:
					skeleton.set_bone_pose_position(bone, idle.position_track_interpolate(i, 0.0))
				Animation.TYPE_ROTATION_3D:
					skeleton.set_bone_pose_rotation(bone, idle.rotation_track_interpolate(i, 0.0))
				Animation.TYPE_SCALE_3D:
					skeleton.set_bone_pose_scale(bone, idle.scale_track_interpolate(i, 0.0))
	var to_root := skeleton.transform
	var parent := skeleton.get_parent()
	while parent != null and parent != root:
		if parent is Node3D:
			to_root = (parent as Node3D).transform * to_root
		parent = parent.get_parent()
	var points := PackedVector3Array()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.skin == null:
			continue
		var mats: Array[Transform3D] = []
		for b in mi.skin.get_bind_count():
			var bone := mi.skin.get_bind_bone(b)
			if bone < 0:
				bone = skeleton.find_bone(mi.skin.get_bind_name(b))
			mats.append(to_root * (skeleton.get_bone_global_pose(bone) if bone >= 0 else Transform3D.IDENTITY) * mi.skin.get_bind_pose(b))
		for surface in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: Variant = arrays[Mesh.ARRAY_BONES]
			var weights: Variant = arrays[Mesh.ARRAY_WEIGHTS]
			if bones == null or weights == null or (bones as Array).is_empty():
				continue
			var per := 8 if (bones as Array).size() == verts.size() * 8 else 4
			for i in range(0, verts.size(), maxi(1, verts.size() / OUTLINE_POINTS)):
				var at := Vector3.ZERO
				var total := 0.0
				for k in per:
					var w: float = weights[i * per + k]
					if w > 0.001:
						at += (mats[int(bones[i * per + k])] * verts[i]) * w
						total += w
				if total > 0.0:
					points.append(at / total)
	if points.is_empty():
		return 0.0
	var tallest := 0.0
	for turn in 4:
		# The camera's up as the model sees it, turned a quarter at a time.
		var a := turn * PI / 2.0
		var dir := Vector3(SIN * sin(a), COS, -SIN * cos(a))
		var lo := INF
		var hi := -INF
		for p in points:
			var d := p.dot(dir)
			lo = minf(lo, d)
			hi = maxf(hi, d)
		tallest = maxf(tallest, hi - lo)
	return tallest


## True if this model has the movie look: its mesh is named <id>_movie
## (tools/creatures/export_gltf.py).
static func is_movie(root: Node) -> bool:
	return not root.find_children("*_movie", "MeshInstance3D", true, false).is_empty()


## How far a movie-look model's fur locks' outline is pushed back, so the
## line only shows round its edge (viewer.json "movie_look").
static func lock_push() -> float:
	return float(GameData.viewer.get("movie_look", {}).get("lock_outline_push", 0.25))


## A skin material in the movie look's shading (viewer.json "movie_look"):
## studio lighting, fur locks with strands, eyes with an iris and catchlight.
static func dress_movie(skin: ShaderMaterial, id: String) -> void:
	skin.shader = MOVIE_SHADER
	var look: Dictionary = GameData.viewer.get("movie_look", {})
	for key in look:
		var value: Variant = look[key]
		if key == "lid_colors" or key == "lock_outline_push":
			continue
		if value is Array and (value as Array).size() == 3:
			skin.set_shader_parameter(key, Vector3(float(value[0]), float(value[1]), float(value[2])))
		elif value is Array and (value as Array).size() == 2:
			skin.set_shader_parameter(key, Vector2(float(value[0]), float(value[1])))
		elif value is String:
			skin.set_shader_parameter(key, Color(String(value)))
		elif value is float or value is int:
			skin.set_shader_parameter(key, float(value))
	var lids: Dictionary = look.get("lid_colors", {})
	skin.set_shader_parameter("lid_color", Color(String(lids[id])) if lids.has(id) else UnitSprites.lid_color(id))


## True if this model comes from a flat-color art pack: its meshes are named
## <id>_toon (tools/packs/convert.py).
static func is_toon(root: Node) -> bool:
	return not root.find_children("*_toon*", "MeshInstance3D", true, false).is_empty()


## A skin material in the flat-color look's shading (viewer.json "toon_look").
static func dress_toon(skin: ShaderMaterial) -> void:
	skin.shader = TOON_SHADER
	var look: Dictionary = GameData.viewer.get("toon_look", {})
	var key_dir: Array = look.get("key_dir", [-0.45, 0.72, 0.55])
	skin.set_shader_parameter("key_dir", Vector3(float(key_dir[0]), float(key_dir[1]), float(key_dir[2])))
	for key in ["key_color", "shade_color", "rim_color"]:
		if look.has(key):
			skin.set_shader_parameter(key, Color(String(look[key])))
	for key in ["band", "soft", "under", "rim", "rim_width", "saturation", "brightness"]:
		if look.has(key):
			skin.set_shader_parameter(key, float(look[key]))


## The meshes of a flat-color model that carry its facial blendshapes.
static func toon_faces(root: Node) -> Array:
	var out := []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh != null and mi.get_blend_shape_count() > 0:
			out.append(mi)
	return out


## Shows one of the game's cartoon faces ("", blink, squint, drowsy, smug,
## wide, happy, dizzy) on a flat-color model by setting its blendshapes
## (viewer.json "toon_look" faces). A face that cycles (dizzy: spinning
## eyes) wants calling every frame with the time.
static func set_toon_face(meshes: Array, face: String, now := 0.0) -> void:
	var faces: Dictionary = GameData.viewer.get("toon_look", {}).get("faces", {})
	var want: Dictionary = faces.get(face, {})
	var amounts := {}
	if want.has("cycle"):
		var names: Array = want.cycle
		if not names.is_empty():
			amounts[String(names[int(now * float(want.get("per_second", 9.0))) % names.size()])] = 1.0
	else:
		amounts = want
	for mi: MeshInstance3D in meshes:
		for i in mi.get_blend_shape_count():
			mi.set_blend_shape_value(i, float(amounts.get(String(mi.mesh.get_blend_shape_name(i)), 0.0)))


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
	m.outline = ShaderMaterial.new()
	m.outline.shader = OUTLINE_SHADER
	var look: Dictionary = GameData.viewer.get("look", {})
	m.movie = is_movie(m.body)
	m.toon = is_toon(m.body)
	var outline_color := String(look.get("outline_color", "#140c09"))
	if m.toon:
		var toon_look: Dictionary = GameData.viewer.get("toon_look", {})
		dress_toon(m.skin)
		m.face_meshes = toon_faces(m.body)
		m.outline_k = float(toon_look.get("outline_scale", 1.0))
		outline_color = String(toon_look.get("outline_color", outline_color))
	elif m.movie:
		dress_movie(m.skin, id)
		m.outline.set_shader_parameter("lock_push", lock_push())
	else:
		m.skin.shader = SKIN_SHADER
		var key_dir: Array = look.get("key_dir", [-0.45, 0.72, 0.55])
		m.skin.set_shader_parameter("key_dir", Vector3(float(key_dir[0]), float(key_dir[1]), float(key_dir[2])))
		for key in ["key_color", "shade_color", "rim_color"]:
			if look.has(key):
				m.skin.set_shader_parameter(key, Color(String(look[key])))
		for key in ["soft", "rim", "rim_width", "highlight", "vibrance"]:
			if look.has(key):
				m.skin.set_shader_parameter(key, float(look[key]))
		m.skin.set_shader_parameter("lid_color", UnitSprites.lid_color(id))
	m.outline.set_shader_parameter("width_px", outline_width * m.outline_k)
	m.outline.set_shader_parameter("color", Color(outline_color))
	m.skin.next_pass = m.outline
	for mesh in m.body.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh as MeshInstance3D
		instance.material_override = m.skin
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.meshes.append(instance)
	var skeletons := m.body.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		m.skeleton = skeletons[0]
	var players := m.body.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		m.player = players[0]
		if manual:
			m.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for anim in m.player.get_animation_list():
			m.lengths[String(anim)] = m.player.get_animation(anim).length
	return m


## Points an orthographic camera down at the camera's tilt (angle()) so that
## field point `middle` (field units) is the view's middle, at `ppu` screen
## pixels a tile, `view_height` pixels tall.
static func aim(cam: Camera3D, middle: Vector2, ppu: float, view_height: float) -> void:
	angle()
	var forward := Vector3(0.0, -SIN, -COS)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = view_height / ppu
	cam.basis = Basis.looking_at(forward, Vector3.UP)
	cam.position = Vector3(middle.x / 1000.0, 0.0, middle.y / 1000.0 / SIN) - forward * 80.0


## A field point (field units) in the 3D layer, on the ground.
static func ground(at: Vector2) -> Vector3:
	angle()
	return Vector3(at.x / 1000.0, 0.0, at.y / 1000.0 / SIN)


## Turns the model to face `degrees` (clockwise from up on screen), on the
## stretched ground.
static func face_toward(m: Model, degrees: float) -> void:
	angle()
	var f := deg_to_rad(degrees)
	var dir := Vector2(sin(f), -cos(f) / SIN)
	m.turn.rotation.y = atan2(-dir.x, -dir.y)


func _pose(m: Model, v: UnitView, now: float, dt: float, ppu: float, right: Vector3, up: Vector3, forward: Vector3) -> void:
	var showing := v.m_visible and v.m_opacity > 0.02
	m.pivot.visible = showing
	if not showing:
		return
	# Where: its feet on the field, then the sprite's offset in the camera's plane.
	var at := ground(v.render_pos())
	at += right * (v.m_offset.x / ppu) + up * (-v.m_offset.y / ppu)
	# A flier: a real height above the ground (it sorts with the others
	# in depth, never cuts through one it passes over).
	at += Vector3.UP * v.m_altitude
	m.pivot.position = at
	# Squash, stretch and lean, as the sprite has them on screen.
	var camera_frame := Basis(right, up, -forward)
	var squash := camera_frame * Basis.from_scale(Vector3(v.m_scale.x, v.m_scale.y, v.m_scale.x)) * camera_frame.inverse()
	m.pivot.basis = Basis(forward, deg_to_rad(v.m_rot)) * squash
	# Which way it faces (on the stretched ground).
	face_toward(m, v.m_facing)
	# Its animation, at the view's point in it. A change of animation
	# cross-fades over blend_seconds (no hard cuts): the player blends from
	# the pose it was in while we hold its playhead where the view wants it
	# (seek back a frame, then advance the frame, which also runs the fade).
	if m.player != null:
		var anim := v.m_anim
		if not m.lengths.has(anim):
			anim = "attack" if anim in ATTACKS and m.lengths.has("attack") else "idle"
		if m.lengths.has(anim):
			var length := float(m.lengths[anim])
			var target := v.m_phase * length
			if anim != m.anim:
				var blend := Feel.num("acting", "blend_seconds", 0.12) if m.anim != "" else 0.0
				m.anim = anim
				m.player.play(anim, blend)
				if blend > 0.0:
					blends += 1
				else:
					cuts += 1
				m.player.seek(target, true)
			elif dt > 0.0:
				var back := target - dt
				if back < 0.0:
					back = fposmod(back, length) if m.player.get_animation(anim).loop_mode != Animation.LOOP_NONE else 0.0
				m.player.seek(back, false)
				m.player.advance(dt)
				if m.player.current_animation != anim:
					# It ran off the end of a one-shot animation: hold its last pose.
					m.player.play(anim)
					m.player.seek(target, true)
			else:
				m.player.seek(target, true)
	# Its cartoon face (UnitView chooses it, as for the sprite).
	if m.toon:
		# A flat-color model's face is blendshapes (its spinning dizzy eyes
		# a cycle of them, so those are set every frame).
		if v.m_face != m.face or m.face == "dizzy":
			m.face = v.m_face
			set_toon_face(m.face_meshes, m.face, now)
	elif v.m_face != m.face:
		m.face = v.m_face
		var face: Array = FACES.get(m.face, FACES[""])
		_param(m, m.skin, "blink", float(face[0]))
		_param(m, m.skin, "lid", float(face[1]))
		_param(m, m.skin, "pupil_size", float(face[2]))
		_param(m, m.skin, "happy", float(face[3]))
		_param(m, m.skin, "dizzy", float(face[4]))
	if m.face == "dizzy" and not m.toon:
		_param(m, m.skin, "spin", snappedf(fposmod(now * 7.0, TAU), 0.05))
	_param(m, m.skin, "flash", snappedf(v.m_flash, 0.02))
	_param(m, m.skin, "gold", snappedf(v.m_gold, 0.02))
	_param(m, m.outline, "gold", snappedf(v.m_gold, 0.02))
	_param(m, m.skin, "opacity", snappedf(v.m_opacity, 0.02))
	_param(m, m.outline, "opacity", snappedf(v.m_opacity, 0.02))
	if m.team_line != null:
		_param(m, m.team_line, "opacity", snappedf(v.m_opacity, 0.02))
		# The squad picked with a tap: its band thicker and brighter.
		var glow := snappedf(v.m_glow, 0.05)
		var color := BattleField.team_color(m.team)
		_param(m, m.team_line, "color", color.lerp(Color.WHITE, 0.4 * glow) if glow > 0.0 else color)
		_param(m, m.team_line, "width_px", outline_px(render_scale) * m.outline_k + (Feel.num("models", "team_outline_px", 3.0) + Feel.num("readability", "squad_band_boost_px", 2.5) * glow) * render_scale)
	_param(m, m.skin, "tint", v.m_tint)


## Sets a shader value only when it changes (dozens of animals, every frame).
func _param(m: Model, material: ShaderMaterial, param: String, value: Variant) -> void:
	var key := "%d%s" % [material.get_instance_id(), param]
	if m.shown.get(key) != value:
		m.shown[key] = value
		material.set_shader_parameter(param, value)


func model_count() -> int:
	return _models.size()


## How tall the animal under `key` stands on screen right now, in the
## field's pixels (0 if it has no model): its model's box, as posed, turned
## and scaled this frame, measured along the camera's up. The box is the
## mesh's standing one (a rear or a crouch isn't followed), so it's the
## animal's size as the player sees it, head to feet, back included (the
## camera looks down at it).
func height_px(key: Variant) -> float:
	var m: Model = _models.get(key)
	if m == null or camera == null or camera.size <= 0.0:
		return 0.0
	return model_height_units(m) * field.size.y / camera.size


## How tall a model stands on the screen right now, along the camera's
## up, in field tiles: its real outline as posed (a sample of its mesh's
## points, skinned to its skeleton's pose; the bounding box would add a
## fifth or so), with its turn, lean and squash and stretch.
static func model_height_units(m: Model) -> float:
	if m.skeleton == null:
		return _box_height_units(m)
	var points: Dictionary = _outline_points(m)
	if (points.verts as PackedVector3Array).is_empty():
		return _box_height_units(m)
	angle()
	var up := Vector3(0, COS, -SIN)
	var g := m.skeleton.global_transform
	# Each bind's whole transform for this pose, once: then each point is
	# its weighted mix.
	var mats: Array[Transform3D] = []
	for bind: Array in points.binds:
		var bone := int(bind[0])
		mats.append(g * (m.skeleton.get_bone_global_pose(bone) if bone >= 0 else Transform3D.IDENTITY) * (bind[1] as Transform3D))
	var verts: PackedVector3Array = points.verts
	var weights: Array = points.weights
	var lo := INF
	var hi := -INF
	for i in verts.size():
		var v := verts[i]
		var at := Vector3.ZERO
		var total := 0.0
		for w: Vector2 in weights[i]:
			at += (mats[int(w.x)] * v) * w.y
			total += w.y
		var d := (at / total if total > 0.0 else g * v).dot(up)
		lo = minf(lo, d)
		hi = maxf(hi, d)
	return maxf(0.0, hi - lo) if lo < hi else 0.0


## The bounding box's height along the camera's up (for a model with no
## skeleton).
static func _box_height_units(m: Model) -> float:
	angle()
	var up := Vector3(0, COS, -SIN)
	var lo := INF
	var hi := -INF
	for mesh: MeshInstance3D in m.meshes:
		var box := mesh.get_aabb()
		var xf := mesh.global_transform
		for i in 8:
			var d := (xf * box.get_endpoint(i)).dot(up)
			lo = minf(lo, d)
			hi = maxf(hi, d)
	return maxf(0.0, hi - lo) if lo < hi else 0.0


## How many of a mesh's points measure its outline (spread over the mesh).
const OUTLINE_POINTS := 360
static var _outlines := {}


## A model's outline sample, the same for every model of its animal: its
## points (mesh space), each one's binds and weights (Vector2(bind, weight)),
## and the binds (skeleton bone, bind pose).
static func _outline_points(m: Model) -> Dictionary:
	if _outlines.has(m.id):
		return _outlines[m.id]
	var verts := PackedVector3Array()
	var weights: Array = []
	var binds: Array = []
	for mi: MeshInstance3D in m.meshes:
		var mesh := mi.mesh
		var skin := mi.skin
		if mesh == null:
			continue
		var first_bind := binds.size()
		if skin != null:
			for b in skin.get_bind_count():
				var bone := skin.get_bind_bone(b)
				if bone < 0 and m.skeleton != null:
					bone = m.skeleton.find_bone(skin.get_bind_name(b))
				binds.append([bone, skin.get_bind_pose(b)])
		var total := 0
		for s in mesh.get_surface_count():
			total += mesh.surface_get_array_len(s)
		var step := maxi(1, total / OUTLINE_POINTS)
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: Variant = arrays[Mesh.ARRAY_BONES]
			var ws: Variant = arrays[Mesh.ARRAY_WEIGHTS]
			var skinned: bool = skin != null and bones != null and ws != null and (bones as Array).size() > 0
			var per := 8 if skinned and (bones as Array).size() == vs.size() * 8 else 4
			for i in range(0, vs.size(), step):
				verts.append(vs[i])
				var mine: Array[Vector2] = []
				if skinned:
					for k in per:
						var w: float = ws[i * per + k]
						if w > 0.001:
							mine.append(Vector2(first_bind + int(bones[i * per + k]), w))
				weights.append(mine)
	var points := {"verts": verts, "weights": weights, "binds": binds}
	_outlines[m.id] = points
	return points


## How much taller than its bounding box at rest (natural_box "up") an
## animal stands on the screen at most in a fight's animations (idle, walk,
## its attacks, fidget, its victory): its real outline, posed, at the poses of each
## animation every twelfth of the way through. Measured from a model
## (manual, in the scene tree) for bodies.json "pose_up".
static func tallest_share(m: Model) -> float:
	var box := float(natural_box(m.id).up) / maxf(0.0001, tile_scale(m.id))
	if m.player == null or box <= 0.0:
		return 1.0
	var tallest := model_height_units(m) / maxf(0.0001, m.body.scale.y)
	for anim in ["idle", "walk", "attack", "attack2", "special", "fidget", "victory"]:
		if not m.player.has_animation(anim):
			continue
		var length := m.player.get_animation(anim).length
		for k in 13:
			m.player.play(anim)
			m.player.seek(length * k / 12.0, true)
			tallest = maxf(tallest, model_height_units(m) / maxf(0.0001, m.body.scale.y))
	return tallest / box
