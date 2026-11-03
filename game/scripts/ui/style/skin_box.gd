class_name SkinBox
extends StyleBox
## A chunky "Ranger Camp" piece (painted wood, brass...) drawn from a
## nine-slice texture made by tools/make_ui_art.py: the grayscale shape
## tinted with `tint`, then its white shine drawn over it. The corners keep
## their shape at any size; the middle stretches. The drop shadow hangs
## below the box's rect.
##
## Every piece of one skin is a region of the same texture, so a box is a
## single draw call, and boxes of the same skin drawn one after another
## batch together.

const META_PATH := "res://art/ui/skins.json"

var skin := ""
var tint := Color.WHITE
var shine_alpha := 1.0
var _base: Texture2D
var _shine: Texture2D
var _margins := [0.0, 0.0, 0.0, 0.0]
var _size := Vector2.ONE
var _scale := 0.5
var _shadow := 0.0

static var _meta: Dictionary = {}
static var _textures: Dictionary = {}


static func make(skin_name: String, color := Color.WHITE) -> SkinBox:
	var box := SkinBox.new()
	box.set_skin(skin_name)
	box.tint = color
	return box


func set_skin(skin_name: String) -> void:
	skin = skin_name
	var info: Dictionary = meta().get("skins", {}).get(skin_name, {})
	if info.is_empty():
		push_warning("No UI skin '%s' (run tools/make_ui_art.py)" % skin_name)
		return
	_base = texture(String(info.file))
	_shine = texture(String(info.shine)) if String(info.shine) != "" else null
	_margins = info.margins
	_size = Vector2(info.size[0], info.size[1])
	_scale = float(info.scale)
	_shadow = float(info.shadow)


## How far the shadow hangs below the box, in game pixels.
func shadow_height() -> float:
	return _shadow * _scale


func _draw(item: RID, rect: Rect2) -> void:
	if _base == null:
		return
	var full := Rect2(rect.position, rect.size + Vector2(0, _shadow * _scale))
	_nine(item, _base, full, tint)
	if _shine != null and shine_alpha > 0.0:
		_nine(item, _shine, full, Color(1, 1, 1, shine_alpha * tint.a))


func _get_draw_rect(rect: Rect2) -> Rect2:
	return Rect2(rect.position, rect.size + Vector2(0, _shadow * _scale))


## The texture cut into 3 x 3: corners at their size, edges and middle
## stretched. On a box smaller than its corners, the corners shrink to fit.
func _nine(item: RID, tex: Texture2D, rect: Rect2, color: Color) -> void:
	var l := float(_margins[0])
	var t := float(_margins[1])
	var r := float(_margins[2])
	var b := float(_margins[3])
	var kx := minf(1.0, rect.size.x / maxf(1.0, (l + r) * _scale))
	var ky := minf(1.0, rect.size.y / maxf(1.0, (t + b) * _scale))
	var src_x := [0.0, l, _size.x - r, _size.x]
	var src_y := [0.0, t, _size.y - b, _size.y]
	var dst_x := [rect.position.x, rect.position.x + l * _scale * kx, rect.end.x - r * _scale * kx, rect.end.x]
	var dst_y := [rect.position.y, rect.position.y + t * _scale * ky, rect.end.y - b * _scale * ky, rect.end.y]
	var rid := tex.get_rid()
	for row in 3:
		var dh: float = dst_y[row + 1] - dst_y[row]
		if dh <= 0.0:
			continue
		for col in 3:
			var dw: float = dst_x[col + 1] - dst_x[col]
			if dw <= 0.0:
				continue
			var src := Rect2(src_x[col], src_y[row], src_x[col + 1] - src_x[col], src_y[row + 1] - src_y[row])
			RenderingServer.canvas_item_add_texture_rect_region(item, Rect2(dst_x[col], dst_y[row], dw, dh), rid, src, color)


static func meta() -> Dictionary:
	if _meta.is_empty():
		var text := FileAccess.get_file_as_string(META_PATH)
		var parsed: Variant = JSON.parse_string(text)
		_meta = parsed if parsed is Dictionary else {}
	return _meta


static func texture(file_name: String) -> Texture2D:
	if not _textures.has(file_name):
		var path := "res://art/ui/" + file_name
		_textures[file_name] = load(path) if ResourceLoader.exists(path) else null
	return _textures[file_name]
