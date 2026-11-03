extends CanvasLayer
## A warm, sunny grade over the whole game: everything is multiplied by a
## soft cream that darkens a little toward the screen's edges (a gentle
## vignette), like an afternoon photo. One full-screen quad, so it's cheap.
## Colors: ui_style.json (grade_center, grade_edge); strength and on/off:
## feel.json ("grade").

var _shade: TextureRect


func _ready() -> void:
	layer = 100
	_shade = TextureRect.new()
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shade.stretch_mode = TextureRect.STRETCH_SCALE
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_shade.material = material
	add_child(_shade)
	refresh()


## Rebuilds the grade from the data files.
func refresh() -> void:
	visible = Feel.on("grade", "enabled", true)
	var strength := Feel.num("grade", "strength", 1.0)
	var center := Color.WHITE.lerp(UIStyle.color("grade_center"), strength)
	var edge := Color.WHITE.lerp(UIStyle.color("grade_edge"), strength)
	var gradient := Gradient.new()
	gradient.set_color(0, center)
	gradient.set_color(1, edge)
	gradient.add_point(Feel.num("grade", "vignette_start", 0.55), center)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.45)
	texture.fill_to = Vector2(1.05, 1.0)
	texture.width = 128
	texture.height = 256
	_shade.texture = texture
