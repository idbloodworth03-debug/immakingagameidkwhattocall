class_name PlayerBadge
extends PanelContainer
## The player's banner with their icon, name and Ranger Level.
## Used in the top bar, the profile and the battle screen. A Rival Ranger's
## badge shows their portrait instead of an icon, and a BOSS tag for a boss.

var banner_id := ""
var icon_id := ""
var player_name := ""
var level := 1
var compact := false
var rival: Dictionary = {}
var portrait: RangerPortrait


static func create(banner: String, icon: String, name_text: String, ranger_level: int, compact_mode := false) -> PlayerBadge:
	var badge := PlayerBadge.new()
	badge.banner_id = banner
	badge.icon_id = icon
	badge.player_name = name_text
	badge.level = ranger_level
	badge.compact = compact_mode
	badge._build()
	return badge


static func for_rival(rival_info: Dictionary, compact_mode := false) -> PlayerBadge:
	var badge := PlayerBadge.new()
	badge.rival = rival_info
	badge.banner_id = rival_info.get("banner", "")
	badge.player_name = rival_info.get("name", "")
	badge.level = int(rival_info.get("level", 1))
	badge.compact = compact_mode
	badge._build()
	return badge


static func for_player(compact_mode := false) -> PlayerBadge:
	return create(Profile.data.banner, Profile.data.icon, Profile.get_player_name(), Profile.ranger_info().level, compact_mode)


func _build() -> void:
	var banner := GameData.find_by_id(GameData.banners, banner_id)
	var colors: Array = banner.get("colors", ["#1e4f96", "#3277c9"])
	var style := UIKit.raised(Color(colors[0]), 18, 8 if compact else 12)
	style.content_margin_right = 16 if compact else 20
	style.set_border_width_all(4)
	style.border_color = Color(colors[1])
	add_theme_stylebox_override("panel", style)

	var row := UIKit.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	var art_size := 58 if compact else 84
	if not rival.is_empty():
		portrait = RangerPortrait.create(rival, art_size)
		row.add_child(portrait)
	else:
		var icon := GameData.find_by_id(GameData.player_icons, icon_id)
		var art := IconArt.make(GameData.player_icon(icon_id), Color(icon.get("color", "#888888")))
		art.text = icon.get("text", "?")
		art.custom_minimum_size = Vector2(art_size, art_size)
		row.add_child(art)

	var column := UIKit.vbox(0)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var name_label := UIKit.label(player_name, 24 if compact else 30)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size.x = 132 if compact else 260
	column.add_child(name_label)
	var level_row := UIKit.hbox(6)
	level_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(level_row)
	var level_style := UIKit.box(UIKit.DEEP, 10, 2)
	level_style.content_margin_left = 8
	level_style.content_margin_right = 8
	var level_chip := PanelContainer.new()
	level_chip.add_theme_stylebox_override("panel", level_style)
	level_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_chip.add_child(UIKit.label("Ranger Lv %d" % level, 16 if compact else 20, Color(colors[1]).lightened(0.55)))
	level_row.add_child(level_chip)
	if rival.get("boss", false):
		var boss_style := UIKit.box(UIKit.GOLD, 10, 2)
		boss_style.content_margin_left = 8
		boss_style.content_margin_right = 8
		var boss_chip := PanelContainer.new()
		boss_chip.add_theme_stylebox_override("panel", boss_style)
		boss_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var boss_label := UIKit.label("BOSS", 16 if compact else 20, UIKit.INK)
		boss_label.add_theme_constant_override("outline_size", 0)
		boss_chip.add_child(boss_label)
		level_row.add_child(boss_chip)
