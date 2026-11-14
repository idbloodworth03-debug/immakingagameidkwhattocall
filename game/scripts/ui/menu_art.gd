class_name MenuArt
extends RefCounted
## The menu's toy props (art/menu/, built and rendered by tools/props in the
## animals' own flat toy style): the cages, coins, gems, the trophy, the
## tab icons. data/art.json "menu" says which prop stands in for which of
## the old line icons, so the menus show a toy coin wherever they showed
## the coin icon.

const DIR := "res://art/menu/"

static var _textures := {}


## A prop's picture by name ("coin", "cage_twig", "tab_shop"), or null.
static func texture(prop: String) -> Texture2D:
	if prop == "":
		return null
	if not _textures.has(prop):
		var path := DIR + prop + ".webp"
		_textures[prop] = load(path) if ResourceLoader.exists(path) else null
	return _textures[prop]


static func has(prop: String) -> bool:
	return texture(prop) != null


## The prop that stands in for a line icon (its file name in art/icons/),
## or "".
static func for_icon(icon_name: String) -> String:
	return String(GameData.art.get("menu", {}).get("props", {}).get(icon_name, ""))


## A cage's picture (cages.json id); an empty slot's with "".
static func cage(cage_id: String) -> Texture2D:
	var art := texture("cage_" + cage_id) if cage_id != "" else null
	return art if art != null else texture("cage_empty")


## The cage (cages.json id) painted `color`, or "" (each cage has its own).
static func cage_for_color(color: Color) -> String:
	for id: String in GameData.cages:
		if Color(String(GameData.cages[id].get("color", "#000000"))).is_equal_approx(color):
			return id
	return ""


## A prop as a control `side` pixels square (drawn whole, smoothly shrunk).
static func rect(prop: String, side: float) -> TextureRect:
	var view := TextureRect.new()
	view.texture = texture(prop)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	view.custom_minimum_size = Vector2(side, side)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view


## The prop that stands in for `icon_name`, `side` pixels square; without
## one, the line icon itself in `tint` (UIKit.icon_rect).
static func icon_or(icon_name: String, tint: Color, side: int) -> TextureRect:
	var prop := for_icon(icon_name)
	if has(prop):
		return rect(prop, side)
	return UIKit.icon_rect(icon_name, tint, side)


## The same choice as a plain texture (a button's icon): the prop, or the
## line icon.
static func icon_texture(icon_name: String) -> Texture2D:
	var prop := for_icon(icon_name)
	return texture(prop) if has(prop) else UIKit.icon(icon_name)
