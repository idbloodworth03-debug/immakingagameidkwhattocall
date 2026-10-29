class_name ProfileView
extends VBoxContainer
## The player's profile: name, Ranger Level, stats, and pickers for the banner
## and icon. Debug builds also get developer tools here. Shown inside a Modal.


static func create() -> ProfileView:
	var view := ProfileView.new()
	view.add_theme_constant_override("separation", 16)
	view._build()
	return view


func _ready() -> void:
	Profile.changed.connect(_rebuild_later)


func _rebuild_later() -> void:
	# Wait a frame so a button press finishes before its button is replaced.
	_build.call_deferred()


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var badge := PlayerBadge.for_player()
	add_child(badge)

	# Name
	var name_row := UIKit.hbox(10)
	add_child(name_row)
	var name_edit := LineEdit.new()
	name_edit.text = Profile.get_player_name()
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(0, 64)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_edit)
	var save_name := UIKit.button("Save name", UIKit.GREEN, 22, Vector2(170, 64))
	save_name.pressed.connect(func() -> void:
		Profile.set_player_name(name_edit.text)
		UIKit.toast("Name saved")
	)
	name_row.add_child(save_name)

	# Ranger level
	var ranger := Profile.ranger_info()
	var level_box := UIKit.vbox(6)
	add_child(level_box)
	level_box.add_child(UIKit.label("Ranger Level %d" % ranger.level, 28, UIKit.YELLOW))
	if int(ranger.xp_needed) > 0:
		level_box.add_child(UIKit.progress(float(ranger.xp) / float(ranger.xp_needed), "%s / %s XP" % [UIKit.format_number(ranger.xp), UIKit.format_number(ranger.xp_needed)], UIKit.GREEN))
	else:
		level_box.add_child(UIKit.label("Max level!", 22))
	level_box.add_child(UIKit.paragraph("Earn XP by upgrading animals and playing battles. Higher levels unlock banners, icons and emotes.", 19))

	# Stats
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 30)
	add_child(stats)
	var arena := GameData.get_arena(Profile.arena_index())
	for pair in [
		["Trophies", UIKit.format_number(Profile.get_trophies())],
		["Best trophies", UIKit.format_number(int(Profile.data.best_trophies))],
		["Arena", "%d: %s" % [Profile.arena_index() + 1, arena.name]],
		["Wins / Losses / Draws", "%d / %d / %d" % [int(Profile.data.wins), int(Profile.data.losses), int(Profile.data.get("draws", 0))]],
		["Animals found", "%d / %d" % [Profile.found_count(), GameData.card_order.size()]],
	]:
		stats.add_child(UIKit.label(pair[0], 21, UIKit.TEXT_DIM))
		stats.add_child(UIKit.label(pair[1], 22))

	add_child(UIKit.heading("Banners"))
	add_child(_picker(GameData.banners, Profile.data.banner, _banner_swatch, Profile.set_banner))
	add_child(UIKit.heading("Icons"))
	add_child(_picker(GameData.player_icons, Profile.data.icon, _icon_swatch, Profile.set_icon))

	add_child(UIKit.heading("Settings"))
	var settings_row := UIKit.hbox(10)
	add_child(settings_row)
	var sound_button := UIKit.button("Sound: " + ("On" if Sound.sound_on() else "Off"), UIKit.BLUE if Sound.sound_on() else UIKit.GREY, 22, Vector2(0, 64))
	sound_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_button.pressed.connect(func() -> void:
		Sound.set_sound(not Sound.sound_on())
		_build.call_deferred()
	)
	settings_row.add_child(sound_button)
	var music_button := UIKit.button("Music: " + ("On" if Sound.music_on() else "Off"), UIKit.BLUE if Sound.music_on() else UIKit.GREY, 22, Vector2(0, 64))
	music_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_button.pressed.connect(func() -> void:
		Sound.set_music(not Sound.music_on())
		_build.call_deferred()
	)
	settings_row.add_child(music_button)
	var credits := UIKit.button("Credits", UIKit.GREY, 22, Vector2(0, 64))
	credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	credits.pressed.connect(_show_credits)
	settings_row.add_child(credits)

	if OS.is_debug_build():
		add_child(_dev_tools())


## A grid of cosmetics. Tapping an unlocked one equips it; tapping a shop
## one offers to buy it.
func _picker(items: Array, selected: String, make_swatch: Callable, equip: Callable) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for item in items:
		var unlocked := Profile.is_unlocked(item)
		var cell := UIKit.panel(UIKit.PANEL_DARK, 6, 12)
		if item.id == selected:
			var style := UIKit.box(UIKit.PANEL_DARK, 12, 6)
			style.set_border_width_all(4)
			style.border_color = UIKit.YELLOW
			cell.add_theme_stylebox_override("panel", style)
		cell.custom_minimum_size = Vector2(140, 0)
		var column := UIKit.vbox(4)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(column)
		var swatch: Control = make_swatch.call(item, unlocked)
		column.add_child(swatch)
		var caption := UIKit.label(item.name if unlocked else Profile.unlock_hint(item), 15, UIKit.TEXT if unlocked else UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.add_theme_constant_override("outline_size", 3)
		column.add_child(caption)
		UIKit.on_tap(cell, func() -> void: _on_cosmetic_tapped(item, equip))
		grid.add_child(cell)
	return grid


func _banner_swatch(item: Dictionary, unlocked: bool) -> Control:
	var swatch := Panel.new()
	var style := UIKit.box(Color(item.colors[0]) if unlocked else Color(item.colors[0]).darkened(0.6), 10)
	style.set_border_width_all(4)
	style.border_color = Color(item.colors[1]) if unlocked else Color(item.colors[1]).darkened(0.6)
	swatch.add_theme_stylebox_override("panel", style)
	swatch.custom_minimum_size = Vector2(0, 54)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return swatch


func _icon_swatch(item: Dictionary, unlocked: bool) -> Control:
	var art := IconArt.make(GameData.player_icon(item.id), Color(item.color))
	art.text = item.text
	art.dimmed = not unlocked
	art.custom_minimum_size = Vector2(70, 70)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return art


func _on_cosmetic_tapped(item: Dictionary, equip: Callable) -> void:
	if Profile.is_unlocked(item):
		equip.call(item.id)
	elif item.unlock.type == "shop":
		Modal.confirm("Buy %s for %d gems?" % [item.name, int(item.unlock.gems)], "Buy", func() -> void:
			if not Profile.buy_cosmetic(item):
				UIKit.error_toast("Not enough gems")
			else:
				Sound.play("coin")
		)
	else:
		UIKit.toast("Locked: " + Profile.unlock_hint(item))


func _dev_tools() -> Control:
	var box := UIKit.vbox(10)
	box.add_child(UIKit.heading("Developer tools"))
	box.add_child(UIKit.paragraph("Only in debug builds. Use these to test progression quickly.", 19))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	var actions := [
		["+1,000 gold", func() -> void: Profile.add_gold(1000)],
		["+500 gems", func() -> void: Profile.add_gems(500)],
		["+300 trophies", func() -> void: Profile.dev_add_trophies(300)],
		["-300 trophies", func() -> void: Profile.dev_add_trophies(-300)],
		["Skip 1 hour", func() -> void: Profile.dev_skip_time(3600)],
		["+500 XP", func() -> void: Profile.add_xp(500)],
		["Unlock all animals", func() -> void: Profile.dev_unlock_all_animals()],
		["Reset profile", _confirm_reset],
	]
	for action in actions:
		var b := UIKit.button(action[0], UIKit.GREY.darkened(0.1), 21, Vector2(0, 62))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(action[1])
		grid.add_child(b)
	return box


func _confirm_reset() -> void:
	Modal.confirm("Erase this profile and start over?", "Reset", Profile.reset, UIKit.RED)


func _show_credits() -> void:
	var box := UIKit.vbox(12)
	for line in [
		"Icons: game-icons.net by Lorc, Delapouite, Caro Asercion, Skoll, Cathelineau and Sbed, under Creative Commons BY 3.0.",
		"Fonts: Lilita One by Juan Montoreano, and Nunito by Vernon Adams, Cyreal and Jacques Le Bailly, under the SIL Open Font License.",
		"Sound effects and music: made for this game.",
		"Animal statuses: the IUCN Red List of Threatened Species.",
	]:
		box.add_child(UIKit.paragraph(line, 21, UIKit.TEXT))
	Modal.open(box, "Credits", 600)
