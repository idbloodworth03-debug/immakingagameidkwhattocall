class_name SquadStage
extends Control
## The home screen's hero: your deck's animals as live 3D toys, standing
## together on a little scene of your arena (a HabitatStage, as in the 3D
## viewer), facing you: the big ones behind, the small ones in front, the
## fliers hovering over them. They breathe, blink, fidget now and then, and
## hop and celebrate when tapped.
##
## Drawn into its own SubViewport with its own world, at the phone's real
## resolution (up to render_scale_max), and only while it shows. The
## animals' models (the viewer's finer ones) load in the background, one
## asked for a frame (a web build loads on the main thread: the menu shows
## at once and stays smooth), and the squad lines up and pops in when all
## are in. The last squad's models are kept, so coming back from a match
## shows it straight away. Numbers: feel.json "menu" "squad".

signal animal_tapped(id: String)

const SHADOW_SHADER := preload("res://scripts/fx/blob_shadow.gdshader")

## The animals to show (card ids), and the habitat scene they stand in.
var ids: Array = []
var habitat := "forest"
## Only the animals, on a see-through background, with no scene round them
## (for pictures of a squad: the logo, tests/squad_shot.gd).
var bare := false
## Numbers that replace feel.json's for this stage (a picture's own camera).
var overrides: Dictionary = {}

var _cfg: Dictionary = {}
var _viewport: SubViewport
var _camera: Camera3D
var _stage: HabitatStage
var _squad: Node3D
var _render_scale := 1.0
## One per animal: {"id", "size", "flier", "path"}; once its model is
## loaded and measured: "model" (ModelStage.Model, or null without one),
## "holder", "tall", "across"; once the squad has lined up: "slot", "lift",
## "yaw", and its idle life ("next_fidget", "next_blink", "blink_until",
## "face").
var _actors: Array = []
## The squad has lined up (every model is in, or failed).
var _lined_up := false
## How many of the animals' models have been asked for.
var _asked := 0

## The models of the squad shown last (by path), kept between visits to the
## menu.
static var _kept := {}
var _fit := 1.0
var _height := 1.0
var _clock := 0.0
var _press_at := Vector2.ZERO
var _pressed := false


static func make(animal_ids: Array, habitat_id: String) -> SquadStage:
	var stage := SquadStage.new()
	stage.ids = animal_ids.filter(func(id): return AnimalViewer.has_model(String(id)))
	stage.habitat = habitat_id
	return stage


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true


func _ready() -> void:
	_cfg = (GameData.feel.get("menu", {}).get("squad", {}) as Dictionary).duplicate()
	_cfg.merge(overrides, true)
	_build()
	resized.connect(_fit_viewport)
	visibility_changed.connect(_on_visibility)
	_fit_viewport()
	_on_visibility()


func _num(key: String, fallback: float) -> float:
	return float(_cfg.get(key, fallback))


# --- The scene ---------------------------------------------------------------------

func _build() -> void:
	var stretch := get_viewport().get_final_transform().get_scale().x if get_viewport() != null else 1.0
	_render_scale = clampf(stretch, 1.0, _num("render_scale_max", 2.0))
	if _cfg.has("render_scale"):
		_render_scale = _num("render_scale", 1.0)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = bare
	_viewport.msaa_3d = Viewport.MSAA_4X if int(_num("msaa", 4)) >= 4 else Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	var spec: Dictionary = GameData.viewer.get("habitats", {}).get(habitat, {})
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR if bare else Environment.BG_COLOR
	environment.background_color = Color(String(spec.get("sky", ["#7cc8ff", "#dff3ff"])[1]))
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	var world := WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)

	_camera = Camera3D.new()
	_camera.fov = _num("fov", 30.0)
	_camera.near = 0.05
	_camera.far = 90.0
	_viewport.add_child(_camera)
	if not bare:
		_stage = HabitatStage.make(habitat, _render_scale)
		_viewport.add_child(_stage)
	_squad = Node3D.new()
	_squad.name = "squad"
	_viewport.add_child(_squad)
	_cast()
	# Only this squad's models are kept.
	var paths := _actors.map(func(actor: Dictionary) -> String: return String(actor.path))
	for path: String in _kept.keys():
		if not paths.has(path):
			_kept.erase(path)


## Who is in the squad and how big each stands: by its build (classes.json
## "groups"), a Mythic at least hero_size.
func _cast() -> void:
	var sizes: Dictionary = _cfg.get("sizes", {})
	var builds: Dictionary = GameData.class_rules.get("groups", {})
	var light := bool(_cfg.get("light_models", false))
	for id: String in ids:
		var real := GameData.plays_as(id)
		var build := String(builds.get("builds", {}).get(real, builds.get("default", "medium")))
		var size := float(sizes.get(build, 1.0))
		if GameData.get_card(id).get("rarity", "") == "mythic":
			size = maxf(size, _num("hero_size", 1.3))
		# The viewer's finer model; the fights' lighter one (a third of the
		# triangles) with light_models, should a phone need it.
		var path := ModelStage.DIR + id + ".glb" if light and ModelStage.has_model(id) else AnimalViewer.model_path(id)
		_actors.append({"id": id, "size": size, "flier": GameData.class_of(id) == "air", "path": path})


## Lines the squad up, once every model is in and measured: the tallest at
## the back, the lowest in front (so a turtle isn't hidden behind a bear),
## the fliers hovering behind them all; each row centered, everyone turned
## a little toward the middle. Then the whole squad is shrunk to fit the
## stage, and each animal pops in.
func _line_up(pop := true) -> void:
	_lined_up = true
	var here := range(_actors.size()).filter(func(i: int) -> bool: return _actors[i].get("model") != null)
	# Tall ones first; a stable order for equal heights.
	here.sort_custom(func(a: int, b: int) -> bool:
		var ta := float(_actors[a].tall)
		var tb := float(_actors[b].tall)
		return ta > tb if absf(ta - tb) > 0.001 else a < b)
	var ground := here.filter(func(i: int) -> bool: return not bool(_actors[i].flier))
	var air := here.filter(func(i: int) -> bool: return bool(_actors[i].flier))
	# The rows, back to front, for this many animals (feel.json "rows":
	# neighboring rows differ by one, so a face in front stands between
	# two behind it, like bowling pins); past the table, rows of row_most.
	var pattern: Array = _cfg.get("rows", {}).get(str(ground.size()), [])
	if pattern.is_empty():
		var most := maxi(1, int(_num("row_most", 3)))
		for r in ceili(ground.size() / float(most)):
			pattern.append(mini(most, ground.size() - r * most))
	var rows := []
	var taken := 0
	for count in pattern:
		rows.append(ground.slice(taken, taken + int(count)))
		taken += int(count)
	if rows.is_empty():
		rows.append([])
	# One spacing for every row (the widest any row needs), so a row of two
	# stands in front of the gaps of a row of three.
	var gap := _num("gap", 0.05)
	var pitch := 0.1
	var most := 1
	for row: Array in rows + [air]:
		most = maxi(most, row.size())
		var total := 0.0
		for i: int in row:
			total += float(_actors[i].across)
		if not row.is_empty():
			pitch = maxf(pitch, total / row.size() + gap)
	var row_gap := _num("row_gap", 0.56)
	for r in rows.size():
		_lay_row(rows[r], (r - (rows.size() - 1) / 2.0) * row_gap, 0.0, pitch)
	# The fliers over the back row.
	var tallest_back := 0.0
	for i: int in rows[0]:
		tallest_back = maxf(tallest_back, float(_actors[i].tall))
	var back_z := -(rows.size() - 1) / 2.0 * row_gap
	_lay_row(air, back_z - 0.1, tallest_back * _num("hover", 0.9) if not rows[0].is_empty() else 0.25, pitch)
	var widest := pitch * most
	_fit = minf(_num("fit_most", 1.0), _num("width", 2.2) / maxf(0.1, widest))
	_squad.scale = Vector3.ONE * _fit
	_height = 0.0
	var index := 0
	for i: int in here:
		var actor: Dictionary = _actors[i]
		_height = maxf(_height, (float(actor.lift) + float(actor.tall)) * _fit)
		_stand(actor, index, pop)
		index += 1
	_place_camera()


## Lays `row` (indices into the actors) left to right round the middle at
## depth `z`, `lift` up, `pitch` apart. The tallest stands in the middle,
## the next ones either side in turn.
func _lay_row(row: Array, z: float, lift: float, pitch: float) -> void:
	var arranged := []
	for k in row.size():
		if k % 2 == 0:
			arranged.append(row[k])
		else:
			arranged.push_front(row[k])
	var turn := deg_to_rad(_num("turn_degrees", 26.0))
	var half := maxf(pitch, pitch * (arranged.size() - 1) / 2.0)
	for k in arranged.size():
		var actor: Dictionary = _actors[arranged[k]]
		var at := (k - (arranged.size() - 1) / 2.0) * pitch
		actor["slot"] = Vector3(at, 0.0, z)
		actor["lift"] = lift
		# Facing the camera, turned toward the middle (more, the further out).
		actor["yaw"] = PI + clampf(-at / half, -1.0, 1.0) * turn


func _fit_viewport() -> void:
	if _viewport == null or size.x < 4.0 or size.y < 4.0:
		return
	_viewport.size = Vector2i((size * _render_scale).round())
	if _stage != null and _camera.get_child_count() == 0:
		_camera.add_child(_stage.make_sky(70.0, _camera.fov, size.x / maxf(1.0, size.y)))
	_place_camera()
	queue_redraw()


func _place_camera() -> void:
	var pitch := deg_to_rad(_num("pitch", 12.0))
	var target := Vector3(0, _height * _num("target", 0.4), _num("target_z", 0.0))
	# As far back as shows the stage's width (`distance` at a square
	# window; a narrower one stands further back).
	var aspect := size.x / maxf(1.0, size.y)
	var distance := _num("distance", 4.9) / clampf(aspect, 0.6, 1.0)
	if _cfg.has("camera_distance"):
		distance = _num("camera_distance", distance)
	_camera.position = target + Vector3(0, sin(pitch), cos(pitch)) * distance
	_camera.look_at(target, Vector3.UP)


func _on_visibility() -> void:
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	set_process(is_visible_in_tree())


func _draw() -> void:
	if _viewport != null:
		draw_texture_rect(_viewport.get_texture(), Rect2(Vector2.ZERO, size), false)


# --- The animals ---------------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	if _lined_up:
		for actor: Dictionary in _actors:
			_animate(actor)
		queue_redraw()
		return
	# One more model asked for each frame (kept ones are here already).
	if _asked < _actors.size():
		var next: Dictionary = _actors[_asked]
		_asked += 1
		if _kept.has(String(next.path)):
			_measure(next, _kept[String(next.path)])
		else:
			ResourceLoader.load_threaded_request(String(next.path))
	var waiting := _actors.size() - _asked
	for i in _asked:
		var actor: Dictionary = _actors[i]
		if actor.has("model"):
			continue
		var path := String(actor.path)
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var scene := ResourceLoader.load_threaded_get(path) as PackedScene
			_kept[path] = scene
			_measure(actor, scene)
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			actor["model"] = null
		else:
			waiting += 1
	if waiting == 0:
		_line_up()
	queue_redraw()


## Loads every model right away and lines the squad up (for tests and
## screenshots).
func load_now() -> void:
	for actor: Dictionary in _actors:
		if not actor.has("model"):
			_measure(actor, load(String(actor.path)) as PackedScene)
	_asked = _actors.size()
	if not _lined_up:
		_line_up(false)


## An animal's model is ready: dressed as a toy, scaled so its longest side
## is its size, and measured as it stands idling (how tall, how much of a
## row it takes turned a little).
func _measure(actor: Dictionary, scene: PackedScene) -> void:
	var m: ModelStage.Model = ModelStage.new_model(String(actor.id), ModelStage.outline_px(_render_scale), false, scene) if scene != null else null
	actor["model"] = m
	if m == null:
		return
	var holder := Node3D.new()
	holder.visible = false
	_squad.add_child(holder)
	holder.add_child(m.pivot)
	var box := _idle_box(m)
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	var k := float(actor.size) / maxf(0.01, longest)
	m.body.scale = Vector3.ONE * k
	# Its feet on the ground (a flier: hovering at its lift), centered on its slot.
	var center := box.get_center() * k
	m.body.position = Vector3(-center.x, -box.position.y * k, -center.z)
	actor["holder"] = holder
	actor["tall"] = box.size.y * k
	actor["footprint"] = maxf(box.size.x, box.size.z) * k
	var turn := deg_to_rad(_num("turn_degrees", 26.0)) * 0.6
	actor["across"] = (box.size.x * cos(turn) + box.size.z * sin(turn)) * k * _num("across", 0.9)


## An animal takes its place in the line-up and pops in.
func _stand(actor: Dictionary, index: int, pop: bool) -> void:
	var m: ModelStage.Model = actor.model
	var holder: Node3D = actor.holder
	holder.position = actor.slot
	holder.visible = true
	m.turn.rotation.y = float(actor.yaw)
	m.pivot.position.y = float(actor.lift)
	# A soft round shadow under it.
	var shadow := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var footprint := float(actor.footprint) * (0.8 if actor.flier else 1.05)
	plane.size = Vector2(footprint, footprint)
	shadow.mesh = plane
	var shade := ShaderMaterial.new()
	shade.shader = SHADOW_SHADER
	var look: Dictionary = GameData.viewer.get("look", {})
	shade.set_shader_parameter("color", Color(String(look.get("shadow_color", "#1a2238"))))
	shade.set_shader_parameter("strength", float(look.get("shadow", 0.38)) * (0.6 if actor.flier else 1.0))
	shadow.material_override = shade
	shadow.position = Vector3(0, 0.008 + 0.002 * index, 0)
	holder.add_child(shadow)
	if m.player != null:
		m.player.playback_default_blend_time = 0.15
		if m.player.has_animation("idle"):
			m.player.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
			m.player.play("idle")
			# Each in its own time.
			m.player.seek(randf() * float(m.lengths.get("idle", 1.0)), true)
	var every: Array = _cfg.get("fidget_every", [5.0, 12.0])
	actor["next_fidget"] = _clock + randf_range(float(every[0]), float(every[1])) * randf_range(0.4, 1.0)
	actor["next_blink"] = _clock + randf_range(0.5, 4.0)
	actor["blink_until"] = 0.0
	actor["face"] = "-"
	if pop and is_inside_tree():
		holder.scale = Vector3.ONE * 0.01
		var tween := create_tween()
		tween.tween_interval(_num("stagger", 0.07) * index)
		tween.tween_callback(func() -> void: Sound.play("pop", -10.0))
		tween.tween_property(holder, "scale", Vector3.ONE, _num("pop_seconds", 0.4)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The box round a model as it stands idling, in its body's own space (a
## sample of its mesh's points skinned by its skeleton; its meshes' boxes at
## rest without one).
func _idle_box(m: ModelStage.Model) -> AABB:
	var box := AABB()
	var first := true
	if m.player != null and m.skeleton != null and m.player.has_animation("idle"):
		m.player.play("idle")
		m.player.seek(0.0, true)
		m.player.advance(0.0)
		var to_body := m.body.global_transform.affine_inverse()
		for mi: MeshInstance3D in m.meshes:
			if mi.mesh == null or mi.skin == null:
				continue
			var mats: Array[Transform3D] = []
			for b in mi.skin.get_bind_count():
				var bone := mi.skin.get_bind_bone(b)
				if bone < 0:
					bone = m.skeleton.find_bone(mi.skin.get_bind_name(b))
				var pose := m.skeleton.get_bone_global_pose(bone) if bone >= 0 else Transform3D.IDENTITY
				mats.append(to_body * m.skeleton.global_transform * pose * mi.skin.get_bind_pose(b))
			for surface in mi.mesh.get_surface_count():
				var arrays := mi.mesh.surface_get_arrays(surface)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var bones: Variant = arrays[Mesh.ARRAY_BONES]
				var weights: Variant = arrays[Mesh.ARRAY_WEIGHTS]
				if bones == null or weights == null or (bones as Array).is_empty():
					continue
				var per := 8 if (bones as Array).size() == verts.size() * 8 else 4
				for i in range(0, verts.size(), maxi(1, verts.size() / 500)):
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
	if first:
		for mi: MeshInstance3D in m.meshes:
			var b: AABB = m.body.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
	return box


## Its idle life: a fidget now and then, a blink, the face of what it's doing.
func _animate(actor: Dictionary) -> void:
	var m: ModelStage.Model = actor.get("model")
	if m == null or m.player == null:
		return
	if _clock >= float(actor.next_fidget):
		if String(m.player.current_animation) == "idle" and m.player.has_animation("fidget"):
			m.player.play("fidget", 0.12)
			m.player.queue("idle")
		var every: Array = _cfg.get("fidget_every", [5.0, 12.0])
		actor.next_fidget = _clock + randf_range(float(every[0]), float(every[1]))
	if not m.toon:
		return
	var toon_look: Dictionary = GameData.viewer.get("toon_look", {})
	var face := String(toon_look.get("viewer_faces", {}).get(String(m.player.current_animation), ""))
	if face == "":
		var blink: Dictionary = toon_look.get("viewer_blink", {})
		if _clock >= float(actor.next_blink):
			var gap: Array = blink.get("every", [2.2, 5.0])
			actor.blink_until = _clock + float(blink.get("seconds", 0.13))
			actor.next_blink = _clock + randf_range(float(gap[0]), float(gap[1]))
		if _clock < float(actor.blink_until):
			face = "blink"
	if face != String(actor.face) or face == "dizzy":
		actor.face = face
		ModelStage.set_toon_face(m.face_meshes, face, _clock)


# --- Taps ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_at = event.position
			_pressed = true
		elif _pressed:
			_pressed = false
			if event.position.distance_to(_press_at) < 24.0 and not HoldInfo.just_held():
				var index := actor_at(event.position)
				if index >= 0:
					accept_event()
					react(index)


## Where an animal's middle is drawn in this control, or Vector2.INF.
func screen_spot(index: int) -> Vector2:
	var actor: Dictionary = _actors[index]
	if actor.get("model") == null or _camera == null or not _lined_up:
		return Vector2.INF
	var holder: Node3D = actor.holder
	var at := holder.global_position + Vector3(0, (float(actor.lift) + float(actor.tall) * 0.5) * _fit, 0)
	if _camera.is_position_behind(at):
		return Vector2.INF
	return _camera.unproject_position(at) / _render_scale


## The animal drawn nearest `at` (within its reach on screen), or -1.
func actor_at(at: Vector2) -> int:
	var best := -1
	var best_d := _num("tap_pixels", 110.0)
	for i in _actors.size():
		var spot := screen_spot(i)
		if spot == Vector2.INF:
			continue
		# (The ones in front win a tie: they're drawn over the others.)
		var d := spot.distance_to(at) - float(_actors[i].slot.z) * 6.0
		if d < best_d:
			best_d = d
			best = i
	return best


## A tap on an animal: it hops and celebrates.
func react(index: int) -> void:
	var actor: Dictionary = _actors[index]
	var m: ModelStage.Model = actor.get("model")
	if m == null or not _lined_up:
		return
	if m.player != null:
		var anim := "victory" if m.player.has_animation("victory") else "fidget"
		if m.player.has_animation(anim):
			m.player.play(anim, 0.1)
			m.player.queue("idle")
	var holder: Node3D = actor.holder
	var hop := create_tween()
	var seconds := _num("tap_seconds", 0.36)
	var up := float(actor.size) * _num("tap_hop", 0.22)
	hop.tween_property(holder, "position:y", up, seconds * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_property(holder, "position:y", 0.0, seconds * 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	Sound.play("pop")
	var spot := screen_spot(index)
	if spot != Vector2.INF:
		UIFx.stars(global_position + spot, 5)
	animal_tapped.emit(String(actor.id))


## How many animals are standing (their models loaded).
func standing() -> int:
	return _actors.filter(func(actor: Dictionary) -> bool: return actor.get("model") != null).size() if _lined_up else 0


## Who stands where, back row first ([[ids of the back row], ...], fliers
## last), once the squad has lined up.
func rows() -> Array:
	var by_depth := {}
	for actor: Dictionary in _actors:
		if actor.get("model") == null or not actor.has("slot"):
			continue
		var key := "air" if actor.flier else "%+.3f" % float(actor.slot.z)
		if not by_depth.has(key):
			by_depth[key] = []
		by_depth[key].append(actor)
	var keys := by_depth.keys().filter(func(k: String) -> bool: return k != "air")
	keys.sort_custom(func(a: String, b: String) -> bool: return a.to_float() < b.to_float())
	if by_depth.has("air"):
		keys.append("air")
	var out := []
	for key: String in keys:
		var row: Array = by_depth[key]
		row.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.slot.x) < float(b.slot.x))
		out.append(row.map(func(actor: Dictionary) -> String: return String(actor.id)))
	return out
