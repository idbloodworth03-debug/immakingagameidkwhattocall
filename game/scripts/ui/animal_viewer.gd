class_name AnimalViewer
extends Control
## The 3D animal viewer (Animals tab: tap an animal). The animal stands in a
## little scene of its habitat (HabitatStage), as a real 3D model
## (tools/creatures/export_gltf.py): drag to spin it, pinch (or the mouse
## wheel) to zoom, tap it for a reaction. It idles, with a little fidget now
## and then. Below: the same info as the hold popup (InfoPop), its Ranger
## Journal entry (data/journal.json), and the Upgrade button.
##
## The 3D is drawn into its own SubViewport at the phone's real resolution
## (up to view.render_scale_max), with its own world, and only while the
## viewer is open: the model is loaded when it opens and freed when it
## closes. Values: data/viewer.json.

const SKIN_SHADER := preload("res://scripts/fx/model_skin.gdshader")
const OUTLINE_SHADER := preload("res://scripts/fx/model_outline.gdshader")
const SHADOW_SHADER := preload("res://scripts/fx/blob_shadow.gdshader")

var animal_id := ""
var render_scale := 1.0

var _view: Dictionary = {}
var _look: Dictionary = {}
var _view_rect := Rect2()
var _viewport: SubViewport
var _picture: TextureRect
var _placeholder: TextureRect
var _camera: Camera3D
var _stage: HabitatStage
var _turntable: Node3D
var _model: Node3D
var _player: AnimationPlayer
var _skin: ShaderMaterial
var _outline: ShaderMaterial
## The model has the movie look (hero art: no outline, its own shading).
var _movie := false
## The model comes from a flat-color art pack (its own shading; a face of
## blendshapes that blinks and reacts).
var _toon := false
var _face_meshes: Array = []
var _next_blink := 0.0
var _blink_until := 0.0
var _face := ""
## For testing: an animation to hold at a point in it once the model loads
## ("attack:0.6"), for screenshots of a pose. Empty: none.
var dev_pose := ""
var _shadow: MeshInstance3D
var _info_box: VBoxContainer
var _hint: Control

var _loading := ""
var _yaw := 0.0
var _yaw_speed := 0.0
var _pitch := 0.0
var _distance := 4.6
var _target_y := 0.5
var _bottom := 0.0
var _height := 1.0
var _touches := {}
var _press_at := Vector2.ZERO
var _press_time := 0.0
var _moved := false
var _pinch_from := 0.0
var _distance_from := 0.0
var _reaction := 0
var _next_fidget := 0.0
var _flash := 0.0
var _clock := 0.0


static func open(id: String) -> AnimalViewer:
	var viewer := AnimalViewer.new()
	viewer.animal_id = id
	var tree := Engine.get_main_loop() as SceneTree
	var layer := tree.get_first_node_in_group("popup_layer")
	(layer if layer else tree.current_scene).add_child(viewer)
	return viewer


static func model_path(id: String) -> String:
	return "res://art/models/%s.glb" % id


static func has_model(id: String) -> bool:
	return ResourceLoader.exists(model_path(id))


func _ready() -> void:
	_view = GameData.viewer.get("view", {})
	_look = GameData.viewer.get("look", {})
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group(HoldInfo.COVER_GROUP)
	Profile.mark_card_seen(animal_id)
	var screen := get_viewport_rect().size
	_view_rect = Rect2(Vector2.ZERO, Vector2(screen.x, roundf(screen.y * float(_view.get("height_share", 0.5)))))

	var back := ColorRect.new()
	back.color = UIKit.DEEP
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	_build_3d()
	_build_overlay()
	_build_info_area()
	UIKit.fade_in(self, 0.18)
	Sound.play("select", -4.0)


# --- The 3D scene -------------------------------------------------------------

func _build_3d() -> void:
	var stretch := get_viewport().get_final_transform().get_scale().x if get_viewport() != null else 1.0
	render_scale = clampf(stretch, 1.0, float(_view.get("render_scale_max", 2.0)))
	_viewport = SubViewport.new()
	_viewport.size = Vector2i((_view_rect.size * render_scale).round())
	_viewport.own_world_3d = true
	_viewport.transparent_bg = false
	_viewport.msaa_3d = Viewport.MSAA_4X if int(_view.get("msaa", 4)) >= 4 else Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	var card := GameData.get_card(animal_id)
	var habitat := String(card.get("habitat", "forest"))
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(String(GameData.viewer.get("habitats", {}).get(habitat, {}).get("sky", ["#7cc8ff", "#dff3ff"])[1]))
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var world := WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)

	_camera = Camera3D.new()
	_camera.fov = float(_view.get("fov", 30.0))
	_camera.near = 0.05
	_camera.far = 90.0
	_viewport.add_child(_camera)
	_stage = HabitatStage.make(habitat, render_scale)
	_viewport.add_child(_stage)
	_camera.add_child(_stage.make_sky(70.0, _camera.fov, _view_rect.size.x / maxf(1.0, _view_rect.size.y)))

	_turntable = Node3D.new()
	_turntable.name = "turntable"
	_viewport.add_child(_turntable)
	_yaw = deg_to_rad(float(_view.get("start_yaw", 150.0)))
	_pitch = deg_to_rad(float(_view.get("pitch", 13.0)))
	_distance = float(_view.get("distance", 4.6))

	_picture = TextureRect.new()
	_picture.texture = _viewport.get_texture()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.position = _view_rect.position
	_picture.size = _view_rect.size
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_picture)

	# The card picture stands in until the model is ready (or if there's none).
	_placeholder = TextureRect.new()
	_placeholder.texture = UnitSprites.portrait(animal_id)
	_placeholder.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_placeholder.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var side := minf(_view_rect.size.x, _view_rect.size.y) * 0.62
	_placeholder.position = _view_rect.get_center() - Vector2(side, side) / 2.0
	_placeholder.size = Vector2(side, side)
	_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not Profile.has_card(GameData.plays_as(animal_id)):
		_placeholder.modulate = Color(UIKit.DEEP, 1.0)
	add_child(_placeholder)

	_place_camera()
	if has_model(animal_id):
		_loading = model_path(animal_id)
		ResourceLoader.load_threaded_request(_loading)


## Loads the model right away (for tests: the viewer itself loads it in the
## background so the screen opens at once).
func load_model_now() -> void:
	if _model == null and has_model(animal_id):
		_loading = ""
		_model_ready(load(model_path(animal_id)) as PackedScene)


func _model_ready(scene: PackedScene) -> void:
	_model = scene.instantiate() as Node3D
	_turntable.add_child(_model)
	_movie = ModelStage.is_movie(_model)
	_toon = ModelStage.is_toon(_model)
	if _toon:
		_face_meshes = ModelStage.toon_faces(_model)
	_skin = ShaderMaterial.new()
	_skin.shader = SKIN_SHADER
	_outline = ShaderMaterial.new()
	_outline.shader = OUTLINE_SHADER
	_apply_look()
	var box := AABB()
	var first := true
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh as MeshInstance3D
		instance.material_override = _skin
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var local := _turntable.global_transform.affine_inverse() * instance.global_transform * instance.get_aabb()
		box = local if first else box.merge(local)
		first = false
	# Framed as it's drawn idling (its skinned points), not by its mesh's
	# box at rest: a flier's model rests up in the air but is drawn hovering
	# lower.
	var posed := _idle_box()
	if posed.size.y > 0.0:
		box = posed
	# The same size whatever the animal: its biggest side is model_size, its
	# feet on the stage, centered.
	var biggest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	var fit := float(_view.get("model_size", 1.35)) / maxf(biggest, 0.001)
	_model.scale = Vector3.ONE * fit
	var center := box.get_center() * fit
	_model.position = Vector3(-center.x, 0.0, -center.z)
	_bottom = box.position.y * fit
	_height = box.size.y * fit
	_shadow = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var footprint := maxf(box.size.x, box.size.z) * fit * 1.05
	plane.size = Vector2(footprint, footprint)
	_shadow.mesh = plane
	var shade := ShaderMaterial.new()
	shade.shader = SHADOW_SHADER
	shade.set_shader_parameter("color", Color(String(_look.get("shadow_color", "#1a2238"))))
	shade.set_shader_parameter("strength", float(_look.get("shadow", 0.38)))
	_shadow.material_override = shade
	_shadow.position = Vector3(0, 0.006, 0)
	_viewport.add_child(_shadow)

	var players := _model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_player = players[0]
		# Reactions blend in and back out to the idle smoothly.
		_player.playback_default_blend_time = 0.15
		if _player.has_animation("idle"):
			_player.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
			_player.play("idle")
	_schedule_fidget()
	_place_camera()
	var fade := create_tween()
	fade.tween_property(_placeholder, "modulate:a", 0.0, 0.2)
	fade.tween_callback(_placeholder.hide)
	if not dev_pose.is_empty():
		pose_at(dev_pose)


## For testing: holds one animation at a point in it ("attack:0.6", 0 to 1),
## so a pose can be screenshotted. The fidgets stop.
func pose_at(spec: String) -> void:
	if _player == null:
		return
	var anim := spec.get_slice(":", 0)
	var at := float(spec.get_slice(":", 1)) if spec.contains(":") else 0.0
	if not _player.has_animation(anim):
		return
	# No blend from the idle (it would hold the blend's first frame instead).
	_player.stop()
	_player.play(anim, 0.0)
	_player.seek(clampf(at, 0.0, 1.0) * _player.get_animation(anim).length, true)
	_player.pause()
	_next_fidget = INF


func _apply_look() -> void:
	var unknown := not Profile.has_card(GameData.plays_as(animal_id))
	var outline_px := float(_look.get("outline_px", 1.8))
	var outline_color := String(_look.get("outline_color", "#140c09"))
	if _toon:
		# Flat-color art: its two-tone shading and a clean dark outline.
		var toon_look: Dictionary = GameData.viewer.get("toon_look", {})
		ModelStage.dress_toon(_skin)
		_skin.set_shader_parameter("silhouette_color", Color(String(_look.get("silhouette_color", "#1d2f5e"))))
		_skin.next_pass = _outline
		outline_px *= float(toon_look.get("outline_scale", 1.0))
		outline_color = String(toon_look.get("outline_color", outline_color))
	elif _movie:
		# Hero art: the movie shading and no outline (the rim light separates
		# it from the background), except as an undiscovered silhouette.
		ModelStage.dress_movie(_skin, animal_id)
		_skin.set_shader_parameter("silhouette_color", Color(String(_look.get("silhouette_color", "#1d2f5e"))))
		_skin.next_pass = _outline if unknown else null
		_outline.set_shader_parameter("lock_push", ModelStage.lock_push())
	else:
		_skin.next_pass = _outline
		var key_dir: Array = _look.get("key_dir", [-0.45, 0.72, 0.55])
		_skin.set_shader_parameter("key_dir", Vector3(float(key_dir[0]), float(key_dir[1]), float(key_dir[2])))
		for key in ["key_color", "shade_color", "rim_color", "silhouette_color"]:
			if _look.has(key):
				_skin.set_shader_parameter(key, Color(String(_look[key])))
		for key in ["soft", "rim", "rim_width", "highlight", "vibrance"]:
			if _look.has(key):
				_skin.set_shader_parameter(key, float(_look[key]))
	_skin.set_shader_parameter("silhouette", 1.0 if unknown else 0.0)
	_outline.set_shader_parameter("width_px", outline_px * render_scale)
	_outline.set_shader_parameter("color", Color(outline_color))
	_outline.set_shader_parameter("silhouette", 1.0 if unknown else 0.0)
	_outline.set_shader_parameter("silhouette_color", Color(String(_look.get("silhouette_outline", "#0a1430"))))


## The box round the model as drawn in its idle's first pose, in the
## turntable's space: a sample of its mesh's points skinned by its skeleton
## (an empty box without a skeleton).
func _idle_box() -> AABB:
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	var skeletons := _model.find_children("*", "Skeleton3D", true, false)
	if players.is_empty() or skeletons.is_empty():
		return AABB()
	var player: AnimationPlayer = players[0]
	var skeleton: Skeleton3D = skeletons[0]
	if player.has_animation("idle"):
		player.play("idle")
		player.seek(0.0, true)
		player.advance(0.0)
	var to_turntable := _turntable.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.skin == null:
			continue
		var skin := mi.skin
		var mats: Array[Transform3D] = []
		for b in skin.get_bind_count():
			var bone := skin.get_bind_bone(b)
			if bone < 0:
				bone = skeleton.find_bone(skin.get_bind_name(b))
			var pose := skeleton.get_bone_global_pose(bone) if bone >= 0 else Transform3D.IDENTITY
			mats.append(to_turntable * skeleton.global_transform * pose * skin.get_bind_pose(b))
		for surface in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: Variant = arrays[Mesh.ARRAY_BONES]
			var weights: Variant = arrays[Mesh.ARRAY_WEIGHTS]
			if bones == null or weights == null or (bones as Array).is_empty():
				continue
			var per := 8 if (bones as Array).size() == verts.size() * 8 else 4
			for i in range(0, verts.size(), maxi(1, verts.size() / 600)):
				var at := Vector3.ZERO
				var total := 0.0
				for k in per:
					var w: float = weights[i * per + k]
					if w > 0.001:
						at += (mats[int(bones[i * per + k])] * verts[i]) * w
						total += w
				if total <= 0.0:
					continue
				at /= total
				box = AABB(at, Vector3.ZERO) if first else box.expand(at)
				first = false
	return box


func _place_camera() -> void:
	# Aimed at the middle of the animal, moving up toward its face as you
	# zoom in.
	var limits: Array = _view.get("distance_range", [2.7, 7.0])
	var closeness := clampf(inverse_lerp(float(_view.get("distance", 4.2)), float(limits[0]), _distance), 0.0, 1.0)
	var aim := lerpf(float(_view.get("target_height", 0.42)), float(_view.get("zoom_target_height", 0.68)), closeness)
	_target_y = _bottom + _height * aim
	var target := Vector3(0, _target_y, 0)
	_camera.position = target + Vector3(0, sin(_pitch), cos(_pitch)) * _distance
	_camera.look_at(target, Vector3.UP)
	_turntable.rotation.y = _yaw
	if _shadow != null:
		_shadow.rotation.y = _yaw


func _process(delta: float) -> void:
	_clock += delta
	if _loading != "":
		var status := ResourceLoader.load_threaded_get_status(_loading)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var scene := ResourceLoader.load_threaded_get(_loading) as PackedScene
			_loading = ""
			if scene != null:
				_model_ready(scene)
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_loading = ""
	if _touches.is_empty() and absf(_yaw_speed) > 0.001:
		_yaw += _yaw_speed * delta
		_yaw_speed *= exp(-float(_view.get("spin_friction", 5.0)) * delta)
	if _flash > 0.0 and _skin != null:
		_flash = maxf(0.0, _flash - delta / float(_look.get("flash_seconds", 0.25)))
		_skin.set_shader_parameter("flash", _flash * float(_look.get("flash", 0.35)))
	if _toon:
		_animate_face()
	if _player != null and _clock >= _next_fidget:
		if _player.current_animation == "idle" and _player.has_animation("fidget"):
			_play("fidget")
		_schedule_fidget()
	_place_camera()


## A flat-color model's face: the face of the reaction it's playing
## (viewer.json "toon_look" viewer_faces), a blink now and then otherwise.
func _animate_face() -> void:
	var toon_look: Dictionary = GameData.viewer.get("toon_look", {})
	var playing := String(_player.current_animation) if _player != null else ""
	var face := String(toon_look.get("viewer_faces", {}).get(playing, ""))
	if face == "":
		var blink: Dictionary = toon_look.get("viewer_blink", {})
		if _clock >= _next_blink:
			var every: Array = blink.get("every", [2.2, 5.0])
			_blink_until = _clock + float(blink.get("seconds", 0.13))
			_next_blink = _clock + randf_range(float(every[0]), float(every[1]))
		if _clock < _blink_until:
			face = "blink"
	if face != _face or face == "dizzy":
		_face = face
		ModelStage.set_toon_face(_face_meshes, face, _clock)


func _schedule_fidget() -> void:
	var every: Array = _view.get("fidget_every", [6.0, 10.0])
	_next_fidget = _clock + randf_range(float(every[0]), float(every[1]))


func _play(anim: String) -> void:
	if _player == null or not _player.has_animation(anim):
		return
	_player.play(anim, 0.12)
	_player.queue("idle")


## A tap on the animal: its next reaction (data "reactions"), a quick flash
## and a little bounce.
func react() -> String:
	if _player == null:
		return ""
	var names: Array = []
	for anim in GameData.viewer.get("reactions", ["fidget", "attack", "victory"]):
		if _player.has_animation(String(anim)):
			names.append(String(anim))
	if names.is_empty():
		return ""
	var anim: String = names[_reaction % names.size()]
	_reaction += 1
	_play(anim)
	_flash = 1.0
	var bounce := float(_look.get("bounce", 0.08))
	var pop := create_tween()
	pop.tween_property(_turntable, "scale", Vector3(1.0 - bounce * 0.5, 1.0 + bounce, 1.0 - bounce * 0.5), 0.08)
	pop.tween_property(_turntable, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sound.play("pop", -3.0, 0.08)
	_schedule_fidget()
	_hide_hint()
	return anim


# --- Touch -----------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _is_covered():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if not _view_rect.has_point(event.position):
				return
			_touches[event.index] = event.position
			if _touches.size() == 1:
				_press_at = event.position
				_press_time = _clock
				_moved = false
				_yaw_speed = 0.0
			elif _touches.size() == 2:
				_moved = true
				_pinch_from = _pinch_distance()
				_distance_from = _distance
			_hide_hint()
		elif _touches.has(event.index):
			_touches.erase(event.index)
			var tap_seconds := float(_view.get("tap_seconds", 0.35))
			if _touches.is_empty() and not _moved and _clock - _press_time <= tap_seconds:
				react()
	elif event is InputEventScreenDrag and _touches.has(event.index):
		_touches[event.index] = event.position
		if _press_at.distance_to(event.position) > float(_view.get("tap_pixels", 16.0)):
			_moved = true
		if _touches.size() == 1:
			spin(event.relative, event.velocity)
		elif _touches.size() >= 2 and _pinch_from > 1.0:
			_distance = _clamp_distance(_distance_from * _pinch_from / maxf(1.0, _pinch_distance()))
	elif event is InputEventMouseButton and event.pressed and _view_rect.has_point(event.position):
		var step := float(_view.get("zoom_per_wheel", 0.08))
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(1.0 - step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(1.0 + step)
	elif event is InputEventMagnifyGesture and _view_rect.has_point(event.position):
		zoom(1.0 / maxf(0.1, event.factor))


## Turns the animal by a finger's movement (and keeps it spinning a little
## after a flick).
func spin(relative: Vector2, velocity := Vector2.ZERO) -> void:
	var per_pixel := deg_to_rad(float(_view.get("spin_per_pixel", 0.55)))
	_yaw += relative.x * per_pixel
	_yaw_speed = velocity.x * per_pixel
	var limits: Array = _view.get("pitch_range", [3.0, 34.0])
	_pitch = clampf(_pitch + relative.y * deg_to_rad(float(_view.get("tilt_per_pixel", 0.12))),
		deg_to_rad(float(limits[0])), deg_to_rad(float(limits[1])))


## Moves the camera closer (factor < 1) or further.
func zoom(factor: float) -> void:
	_distance = _clamp_distance(_distance * factor)


func _clamp_distance(d: float) -> float:
	var limits: Array = _view.get("distance_range", [2.7, 7.0])
	return clampf(d, float(limits[0]), float(limits[1]))


func _pinch_distance() -> float:
	var points: Array = _touches.values()
	return (points[0] as Vector2).distance_to(points[1]) if points.size() >= 2 else 0.0


## True while a popup (an animal's legend link, a toast) sits over the viewer.
func _is_covered() -> bool:
	var parent := get_parent()
	return parent != null and get_index() < parent.get_child_count() - 1 and parent.get_child(-1) is Modal


func yaw() -> float:
	return _yaw


func distance() -> float:
	return _distance


func model() -> Node3D:
	return _model


func animation() -> String:
	return _player.current_animation if _player != null else ""


# --- Overlay and info --------------------------------------------------------------

func _build_overlay() -> void:
	var close := UIKit.icon_button("close", UIKit.RED, 64)
	close.position = Vector2(_view_rect.size.x - 64 - 18, 18)
	close.pressed.connect(close_viewer)
	add_child(close)

	var card := GameData.get_card(animal_id)
	var habitat: Dictionary = GameData.habitats.get(String(card.get("habitat", "")), {})
	if not habitat.is_empty():
		var chip := _chip(String(habitat.name), Color(String(habitat.color)), String(habitat.get("icon", "")))
		chip.position = Vector2(18, 24)
		add_child(chip)

	# How to play with it, until the first touch.
	_hint = UIKit.hud_pill(UIKit.label("Drag to spin  ·  Pinch to zoom  ·  Tap!", 21, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	add_child(_hint)
	_hint.reset_size()
	_hint.position = Vector2((_view_rect.size.x - _hint.size.x) / 2.0, _view_rect.end.y - _hint.size.y - 16)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().create_timer(float(_view.get("hint_seconds", 5.0))).timeout.connect(_hide_hint)


func _hide_hint() -> void:
	if _hint != null and is_instance_valid(_hint) and _hint.modulate.a >= 1.0:
		create_tween().tween_property(_hint, "modulate:a", 0.0, 0.3)


func _build_info_area() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, _view_rect.end.y)
	scroll.size = Vector2(_view_rect.size.x, get_viewport_rect().size.y - _view_rect.end.y)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)
	_info_box = UIKit.vbox(14)
	margin.add_child(_info_box)
	_build_info()


func _build_info() -> void:
	for child in _info_box.get_children():
		_info_box.remove_child(child)
		child.queue_free()
	var card := GameData.get_card(animal_id)
	# An art test (art_tests.json) shows the progress of the animal it plays
	# as, and can't be upgraded itself.
	var art_test := GameData.is_art_test(animal_id)
	var owned := Profile.has_card(animal_id)
	var width := _view_rect.size.x - 32.0

	# The hold popup's card, full width.
	var pop := InfoPop.make(animal_id, 0, Profile.card_level(GameData.plays_as(animal_id)))
	pop.size = Vector2(width, pop.size.y)
	pop.custom_minimum_size = pop.size
	_info_box.add_child(pop)

	# Level and Upgrade (or where to find it).
	var row := UIKit.hbox(16)
	_info_box.add_child(row)
	if art_test:
		var test: Dictionary = GameData.art_tests.animals[animal_id]
		var note := UIKit.paragraph("Art test. Plays exactly as the %s. Art: %s." % [
				String(GameData.get_card(GameData.plays_as(animal_id)).get("name", "")), String(test.get("pack", "an art pack"))], 22, UIKit.YELLOW)
		note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(note)
	elif owned:
		var level_box := UIKit.vbox(6)
		level_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(level_box)
		level_box.add_child(UIKit.label("Level %d" % Profile.card_level(animal_id), 28, UIKit.YELLOW))
		var cost := Profile.upgrade_cost(animal_id)
		if cost.is_empty():
			level_box.add_child(UIKit.label("Max level!", 24, UIKit.YELLOW))
		else:
			var copies := Profile.card_copies(animal_id)
			level_box.add_child(UIKit.progress(float(copies) / float(cost.copies), "%d / %d" % [copies, cost.copies],
					UIKit.GREEN if Profile.has_copies_for_upgrade(animal_id) else UIKit.BLUE))
			var upgrade := UIKit.button("Upgrade\n%s gold" % UIKit.format_number(cost.gold), UIKit.GREEN, 24, Vector2(230, 84))
			upgrade.disabled = not Profile.can_upgrade(animal_id)
			upgrade.pressed.connect(_on_upgrade)
			row.add_child(upgrade)
	else:
		var arena_index := int(card.get("unlock_arena_index", 0))
		var where := "Not found yet. Look in cages from Arena %d: %s" % [arena_index + 1, GameData.get_arena(arena_index).name]
		var text := UIKit.paragraph(where, 22, UIKit.YELLOW)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)

	# Ranger Journal.
	var entry: Dictionary = GameData.journal.get(animal_id, {})
	var journal := UIKit.well(16)
	_info_box.add_child(journal)
	var column := UIKit.vbox(10)
	journal.add_child(column)
	var heading := UIKit.hbox(10)
	heading.add_child(UIKit.icon_rect(GameData.ui_icon("journal"), UIKit.YELLOW, 38))
	heading.add_child(UIKit.label("Ranger Journal", 28, UIKit.YELLOW))
	column.add_child(heading)
	var status := "Mythical creature" if String(card.get("rarity", "")) == "mythic" \
		else "Real-world status: %s" % GameData.status_name(card.get("status", ""))
	column.add_child(UIKit.label(status, 21, UIStyle.color("journal_status")))
	if entry.has("home"):
		column.add_child(_journal_line("Home", String(entry.home), UIStyle.color("journal_home")))
	for fact in entry.get("facts", []):
		column.add_child(_journal_line("•", String(fact), UIKit.YELLOW))
	if entry.has("help"):
		column.add_child(_journal_line("Help", String(entry.help), UIStyle.color("journal_help")))
	if String(card.get("legend", "")) != "":
		column.add_child(_journal_line("Real clue", String(card.legend), UIStyle.color("journal_clue")))
		var link := String(card.get("legend_card", ""))
		if link != "" and GameData.cards.has(link):
			var meet := UIKit.button("Meet the " + String(GameData.get_card(link).name), UIKit.BLUE, 22, Vector2(0, 64))
			meet.icon = UIKit.icon(GameData.card_icon(link))
			meet.add_theme_constant_override("icon_max_width", 36)
			meet.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			meet.pressed.connect(func() -> void:
				close_viewer()
				AnimalViewer.open(link))
			column.add_child(meet)


## One journal line: a colored word, then the text.
func _journal_line(word: String, text: String, color: Color) -> Control:
	var line := RichTextLabel.new()
	line.bbcode_enabled = true
	line.fit_content = true
	line.scroll_active = false
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_font_override("normal_font", UIKit.body_font())
	line.add_theme_font_override("bold_font", UIKit.DISPLAY_FONT)
	line.add_theme_font_size_override("normal_font_size", 22)
	line.add_theme_font_size_override("bold_font_size", 22)
	line.add_theme_color_override("default_color", UIKit.TEXT)
	line.text = "[b][color=#%s]%s[/color][/b]  %s" % [color.to_html(false), word, text]
	return line


func _chip(text: String, color: Color, icon_key: String) -> Control:
	var chip := PanelContainer.new()
	var style := UIKit.box(color.darkened(0.3), 18, 6)
	style.content_margin_left = 12
	style.content_margin_right = 14
	style.set_border_width_all(3)
	style.border_color = UIKit.INK
	chip.add_theme_stylebox_override("panel", style)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UIKit.hbox(8)
	chip.add_child(row)
	if icon_key != "":
		row.add_child(UIKit.icon_rect(GameData.ui_icon(icon_key), Color.WHITE, 30))
	row.add_child(UIKit.label(text, 22))
	return chip


func _on_upgrade() -> void:
	if Profile.upgrade_card(animal_id):
		Sound.play("upgrade")
		UIKit.toast("%s is now Level %d!" % [GameData.get_card(animal_id).name, Profile.card_level(animal_id)], UIKit.GREEN.darkened(0.3))
		_build_info()
		react()
	else:
		UIKit.error_toast("Not enough gold or copies yet")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_viewer()
		get_viewport().set_input_as_handled()


func close_viewer() -> void:
	set_process(false)
	set_process_input(false)
	queue_free()
