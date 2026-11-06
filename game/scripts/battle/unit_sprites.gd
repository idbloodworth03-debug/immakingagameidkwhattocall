class_name UnitSprites
extends RefCounted
## Rendered animal sprites, made by tools/creatures (Blender).
##
## Each animal has art/units/<id>/sheet.webp, holding every frame of its
## idle, walk, attack and death animations from five directions (and, for
## animals rendered with them, a fidget, a victory and a second attack; a big
## animal's frames go on more pages, sheet_1.webp...), and sheet.json saying
## where each frame is and where the eyes are in it. Left-facing frames are
## the right-facing ones mirrored. art/units/<id>/portrait.webp is its card
## art.
##
## The sheets' pictures are big, so only the ones in use are kept: a match
## frees every animal's that isn't in it (keep_only: both decks, without the
## bans), and an animal's sheet loads when it's first drawn (so a match only
## ever holds the animals that actually came up, at most its own).

const ROOT := "res://art/units/"

static var _sheets := {}      # id -> Dictionary (the json), or {} if none
static var _textures := {}    # id -> Array of Texture2D (one per page), while in use
static var _portraits := {}   # id -> Texture2D or null


## Lets go of every animal's sheet pictures (and card portrait) except
## these animals'; theirs load when first drawn.
static func keep_only(ids: Array) -> void:
	for id in _textures.keys():
		if not ids.has(id):
			_textures.erase(id)
	for id in _portraits.keys():
		if not ids.has(id):
			_portraits.erase(id)


## The animals whose sheet pictures are in memory now.
static func loaded_ids() -> Array:
	return _textures.keys()


## How much graphics memory the loaded sheets take (4 bytes a pixel).
static func loaded_bytes() -> int:
	var total := 0
	for pages: Array in _textures.values():
		for page: Texture2D in pages:
			if page != null:
				total += page.get_width() * page.get_height() * 4
	return total


## The sheet's pictures (one per page), loaded when first needed.
static func _pages(id: String) -> Array:
	if not _textures.has(id):
		var pages := []
		var count := int(_sheet(id).get("pages", 1))
		for i in count:
			var path := ROOT + id + ("/sheet.webp" if i == 0 else "/sheet_%d.webp" % i)
			pages.append(load(path) if ResourceLoader.exists(path) else null)
		_textures[id] = pages
	return _textures[id]


static func has(id: String) -> bool:
	return not _sheet(id).is_empty()


## True if its sheet's pictures are in this build (the web build leaves
## them out: the animals are 3D models there, and the sheets' data is
## enough).
static func has_pictures(id: String) -> bool:
	return ResourceLoader.exists(ROOT + id + "/sheet.webp")


static func portrait(id: String) -> Texture2D:
	if not _portraits.has(id):
		var path := ROOT + id + "/portrait.webp"
		_portraits[id] = load(path) if ResourceLoader.exists(path) else null
	return _portraits[id]


static func animation(id: String, anim: String) -> Dictionary:
	return _sheet(id).get("animations", {}).get(anim, {})


static func has_animation(id: String, anim: String) -> bool:
	return not animation(id, anim).is_empty()


## Where the eyes are in a frame, in sheet pixels from the anchor (null for
## an eye turned away), for drawing blinks and faces over them. Empty when
## the sheet has no eye data. Takes the same `facing` and `frame_index` as
## frame(); mirrored frames need the x flipped, as the frame is.
static func eyes(id: String, anim: String, facing: float, frame_index: int) -> Array:
	var sheet := _sheet(id)
	var all: Dictionary = sheet.get("eyes", {})
	if not all.has(anim):
		return []
	var info: Dictionary = sheet.animations[anim]
	var count := int(info.frames)
	var f := posmod(frame_index, count) if info.loop else clampi(frame_index, 0, count - 1)
	var angle := (roundi(fposmod(facing, 360.0) / 45.0) % 8) * 45
	if angle > 180:
		angle = 360 - angle
	var frames: Array = all[anim].get(str(angle), [])
	if f >= frames.size():
		return []
	var out := []
	for e: Variant in frames[f]:
		out.append(Vector2(float(e[0]), float(e[1])) if e is Array else null)
	return out


## How big an eye is (radius in sheet pixels), 0 without eye data.
static func eye_radius(id: String) -> float:
	return float(_sheet(id).get("eye_radius", 0.0))


## The color of the skin around the eyes, for eyelids.
static func lid_color(id: String) -> Color:
	return Color(String(_sheet(id).get("lid_color", "#7a5a3a")))


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


## How the animal attacks (pounce_bite, bite, swipe, charge, stomp, throw,
## dive...), for matching hit effects; "attack2" for its second attack.
static func attack_style(id: String, anim := "attack") -> String:
	if anim == "attack2":
		return String(_sheet(id).get("attack2_style", _sheet(id).get("attack_style", "bite")))
	return String(_sheet(id).get("attack_style", "bite"))


## Its body plan (quadruped, biped, bird, winged, insect, fish, cetacean,
## crustacean, serpent, frog or pinniped), for how the game moves it.
static func body(id: String) -> String:
	return String(_sheet(id).get("body", "bird" if attack_style(id) == "dive" else "quadruped"))


## Which attack style its Stun wind-up ("special") has, "" if none.
static func has_special(id: String) -> bool:
	return has_animation(id, "special")


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
	if info.has("at"):
		# Version 3: each animation has its own frame size and anchor, and
		# every frame says where it is.
		var at: Array = info.at[str(angle)][f]
		var size: Vector2 = info.cell_size
		var page := int(at[2]) if at.size() > 2 else 0
		return {"texture": _pages(id)[page], "region": Rect2(float(at[0]), float(at[1]), size.x, size.y), "flip": flip, "anchor": info.anchor_point}
	var cell: Vector2 = sheet.cell_size
	var pad := float(sheet.padding)
	var col := f
	var row := 0
	if sheet.has("columns"):
		# Packed layout: frames run left to right, row after row.
		var index := int(info.start[str(angle)]) + f
		col = index % int(sheet.columns)
		row = index / int(sheet.columns)
	else:
		row = int(info.rows[str(angle)])
	var region := Rect2(col * (cell.x + pad * 2) + pad, row * (cell.y + pad * 2) + pad, cell.x, cell.y)
	return {"texture": _pages(id)[0], "region": region, "flip": flip, "anchor": sheet.anchor_point}


static func _sheet(id: String) -> Dictionary:
	if _sheets.has(id):
		return _sheets[id]
	var sheet := {}
	# The data alone: the pictures may not be in this build (the web build
	# shows 3D models, has_pictures).
	var json_path := ROOT + id + "/sheet.json"
	if FileAccess.file_exists(json_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
		if parsed is Dictionary:
			sheet = parsed
			if sheet.has("cell"):
				sheet["cell_size"] = Vector2(float(sheet.cell[0]), float(sheet.cell[1]))
				sheet["anchor_point"] = Vector2(float(sheet.anchor[0]), float(sheet.anchor[1]))
			for info: Dictionary in sheet.animations.values():
				if info.has("cell"):
					info["cell_size"] = Vector2(float(info.cell[0]), float(info.cell[1]))
					info["anchor_point"] = Vector2(float(info.anchor[0]), float(info.anchor[1]))
	_sheets[id] = sheet
	return sheet
