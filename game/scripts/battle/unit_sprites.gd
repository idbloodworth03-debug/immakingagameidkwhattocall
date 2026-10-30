class_name UnitSprites
extends RefCounted
## Rendered animal sprites, made by tools/creatures (Blender).
##
## Each animal has art/units/<id>/sheet.webp, holding every frame of its
## idle, walk, attack and death animations from five directions, and
## sheet.json saying where each frame is. Left-facing frames are the
## right-facing ones mirrored. art/units/<id>/portrait.webp is its card art.

const ROOT := "res://art/units/"

static var _sheets := {}      # id -> Dictionary (the json, plus "texture"), or {} if none
static var _portraits := {}   # id -> Texture2D or null


static func has(id: String) -> bool:
	return not _sheet(id).is_empty()


static func portrait(id: String) -> Texture2D:
	if not _portraits.has(id):
		var path := ROOT + id + "/portrait.webp"
		_portraits[id] = load(path) if ResourceLoader.exists(path) else null
	return _portraits[id]


static func animation(id: String, anim: String) -> Dictionary:
	return _sheet(id).get("animations", {}).get(anim, {})


## Seconds an animation lasts (once through).
static func duration(id: String, anim: String) -> float:
	var info := animation(id, anim)
	if info.is_empty():
		return 0.0
	return float(info.frames) / float(info.fps)


static func walk_cycle_tiles(id: String) -> float:
	return float(_sheet(id).get("walk_cycle_tiles", 1.0))


## How far the animal's head rises above its feet, in sheet pixels.
static func top(id: String) -> float:
	return float(_sheet(id).get("top", 40.0))


static func pixels_per_tile(id: String) -> float:
	return float(_sheet(id).get("pixels_per_tile", 64))


## The frame to draw: {"texture", "region" (Rect2 in the sheet), "flip",
## "anchor" (pixel under the animal's middle, in the frame)}.
## `facing` is degrees clockwise from "up the screen"; `frame` wraps for
## looping animations and stops at the last frame otherwise.
static func frame(id: String, anim: String, facing: float, frame_index: int) -> Dictionary:
	var sheet := _sheet(id)
	var info: Dictionary = sheet.animations.get(anim, sheet.animations.idle)
	var count := int(info.frames)
	var f := posmod(frame_index, count) if info.loop else clampi(frame_index, 0, count - 1)
	var step := roundi(fposmod(facing, 360.0) / 45.0) % 8
	var angle := step * 45
	var flip := angle > 180
	if flip:
		angle = 360 - angle
	var row := int(info.rows[str(angle)])
	var cell: Vector2 = sheet.cell_size
	var pad := float(sheet.padding)
	var region := Rect2(f * (cell.x + pad * 2) + pad, row * (cell.y + pad * 2) + pad, cell.x, cell.y)
	return {"texture": sheet.texture, "region": region, "flip": flip, "anchor": sheet.anchor_point}


static func _sheet(id: String) -> Dictionary:
	if _sheets.has(id):
		return _sheets[id]
	var sheet := {}
	var json_path := ROOT + id + "/sheet.json"
	var texture_path := ROOT + id + "/sheet.webp"
	if FileAccess.file_exists(json_path) and ResourceLoader.exists(texture_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
		if parsed is Dictionary:
			sheet = parsed
			sheet["texture"] = load(texture_path)
			sheet["cell_size"] = Vector2(float(sheet.cell[0]), float(sheet.cell[1]))
			sheet["anchor_point"] = Vector2(float(sheet.anchor[0]), float(sheet.anchor[1]))
	_sheets[id] = sheet
	return sheet
