extends CanvasLayer
## Changing screens: a leafy circle closes over the screen with a swirl of
## leaves, the next screen loads behind it, and it opens again. Timings and
## the number of leaves: feel.json ("transition").

const IRIS := preload("res://scripts/fx/iris.gdshader")

var _cover: ColorRect
var _leaves_layer: ParticleLayer
var _busy := false


func _ready() -> void:
	layer = 90
	_cover = ColorRect.new()
	_cover.color = Color("#7cb84a")
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = IRIS
	material.set_shader_parameter("rim_color", Color("#3f6e1f"))
	_cover.material = material
	_cover.visible = false
	add_child(_cover)
	# The leaves swirl over the cover.
	_leaves_layer = ParticleLayer.new()
	add_child(_leaves_layer)


## Goes to the scene at `path` with the leafy wipe.
func go(path: String) -> void:
	if _busy:
		return
	_busy = true
	var c := "transition"
	_cover.visible = true
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	var size := get_viewport().get_visible_rect().size
	(_cover.material as ShaderMaterial).set_shader_parameter("aspect", size.x / maxf(1.0, size.y))
	_set_progress(0.0)
	Sound.play("whoosh")
	_leaves(size)
	var close := create_tween()
	close.tween_method(_set_progress, 0.0, 1.0, Feel.num(c, "cover_seconds", 0.38)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await close.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var open := create_tween()
	open.tween_method(_set_progress, 1.0, 0.0, Feel.num(c, "reveal_seconds", 0.45)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await open.finished
	_cover.visible = false
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _set_progress(value: float) -> void:
	(_cover.material as ShaderMaterial).set_shader_parameter("progress", value)


## Leaves swirl in from the edges toward the middle.
func _leaves(size: Vector2) -> void:
	var count := Feel.count("transition", "leaves", 22)
	var greens := [Color("#7cc84a"), Color("#a6d85a"), Color("#e8b44a"), Color("#d9783a")]
	for i in count:
		var angle := randf() * TAU
		var from := size / 2.0 + Vector2(cos(angle), sin(angle)) * size.length() * 0.55
		var v := (size / 2.0 - from) * randf_range(0.9, 1.4) + Vector2(cos(angle + PI / 2), sin(angle + PI / 2)) * 260.0
		_leaves_layer.particle("leaf", from, v, randf_range(0.7, 1.0), randf_range(12.0, 18.0), greens[i % greens.size()], 0.0, 1.6, randf_range(-7.0, 7.0))
