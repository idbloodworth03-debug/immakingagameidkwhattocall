class_name PlayerBadge
extends PanelContainer
## The player's banner with their icon, name and Ranger Level.
## Used in the top bar, the profile and the battle screen.

var banner_id := ""
var icon_id := ""
var player_name := ""
var level := 1
var compact := false


static func create(banner: String, icon: String, name_text: String, ranger_level: int, compact_mode := false) -> PlayerBadge:
	var badge := PlayerBadge.new()
	badge.banner_id = banner
	badge.icon_id = icon
	badge.player_name = name_text
	badge.level = ranger_level
	badge.compact = compact_mode
	badge._build()
	return badge


static func for_player(compact_mode := false) -> PlayerBadge:
	return create(Profile.data.banner, Profile.data.icon, Profile.get_player_name(), Profile.ranger_info().level, compact_mode)


func _build() -> void:
	var banner := GameData.find_by_id(GameData.banners, banner_id)
	var colors: Array = banner.get("colors", ["#1e4f96", "#3277c9"])
	var style := UIKit.box(Color(colors[0]), 16, 8 if compact else 12)
	style.set_border_width_all(4)
	style.border_color = Color(colors[1])
	add_theme_stylebox_override("panel", style)

	var row := UIKit.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	var icon := GameData.find_by_id(GameData.player_icons, icon_id)
	var art := IconArt.make(GameData.player_icon(icon_id), Color(icon.get("color", "#888888")))
	art.text = icon.get("text", "?")
	var art_size := 56 if compact else 84
	art.custom_minimum_size = Vector2(art_size, art_size)
	row.add_child(art)

	var column := UIKit.vbox(0)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var name_label := UIKit.label(player_name, 24 if compact else 30)
	name_label.clip_text = true
	name_label.custom_minimum_size.x = 150 if compact else 260
	column.add_child(name_label)
	column.add_child(UIKit.label("Ranger Lv %d" % level, 18 if compact else 22, Color(colors[1]).lightened(0.4)))
