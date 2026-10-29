extends Control
## The home screen, laid out like other mobile card battlers:
## top bar, five tabs and a bottom navigation bar
## (Shop - Animals - Battle - Clan - Events), opening on Battle.

const TABS := [
	["Shop", preload("res://scripts/ui/tabs/shop_tab.gd")],
	["Animals", preload("res://scripts/ui/tabs/animals_tab.gd")],
	["Battle", preload("res://scripts/ui/tabs/battle_tab.gd")],
	["Clan", preload("res://scripts/ui/tabs/clan_tab.gd")],
	["Events", preload("res://scripts/ui/tabs/events_tab.gd")],
]
const BATTLE_TAB := 2

var _pages: Array = []
var _nav_buttons: Array = []
var _animals_badge: Label
var _current := -1


func _ready() -> void:
	theme = UIKit.build_theme()

	var gradient := Gradient.new()
	gradient.set_color(0, UIKit.BG_TOP)
	gradient.set_color(1, UIKit.BG_BOTTOM)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_to = Vector2(0, 1)
	var background := TextureRect.new()
	background.texture = texture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var safe_area := MarginContainer.new()
	safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(safe_area)
	_apply_safe_area(safe_area)

	var column := UIKit.vbox(0)
	safe_area.add_child(column)
	column.add_child(preload("res://scripts/ui/top_bar.gd").new())

	var page_host := Control.new()
	page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_host.clip_contents = true
	column.add_child(page_host)
	for tab in TABS:
		var page: Control = tab[1].new()
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page.visible = false
		page_host.add_child(page)
		_pages.append(page)

	column.add_child(_build_nav())

	var popup_layer := Control.new()
	popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_layer.add_to_group("popup_layer")
	add_child(popup_layer)

	Profile.changed.connect(_update_badges)
	_update_badges()
	select_tab(BATTLE_TAB)

	if OS.is_debug_build():
		for problem in GameData.validate():
			push_warning("Game data: " + problem)

	if not Profile.pending_match_result.is_empty():
		_show_match_result.call_deferred(Profile.pending_match_result)
		Profile.pending_match_result = {}


func select_tab(index: int) -> void:
	if index == _current:
		return
	_current = index
	for i in _pages.size():
		_pages[i].visible = i == index
		var selected: bool = i == index
		var button: Button = _nav_buttons[i]
		UIKit.color_button(button, UIKit.PANEL_LIGHT.lightened(0.15) if selected else UIKit.PANEL_DARK)
		button.size_flags_stretch_ratio = 1.5 if selected else 1.0
		button.add_theme_font_size_override("font_size", 26 if selected else 21)


func _build_nav() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.35), 0, 8))
	var row := UIKit.hbox(6)
	bar.add_child(row)
	for i in TABS.size():
		var button := UIKit.button(TABS[i][0], UIKit.PANEL_DARK, 21, Vector2(0, 96))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(select_tab.bind(i))
		row.add_child(button)
		_nav_buttons.append(button)

	# A little "!" on the Animals tab when something can be upgraded or is new.
	_animals_badge = UIKit.label("!", 22, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	var badge_style := UIKit.box(UIKit.RED, 14)
	_animals_badge.add_theme_stylebox_override("normal", badge_style)
	_animals_badge.custom_minimum_size = Vector2(28, 28)
	_animals_badge.position = Vector2(4, 2)
	_nav_buttons[1].add_child(_animals_badge)
	return bar


func _update_badges() -> void:
	var attention := false
	for id in Profile.data.collection:
		if Profile.is_card_new(id) or Profile.has_copies_for_upgrade(id):
			attention = true
			break
	_animals_badge.visible = attention


## Keeps the UI clear of notches and rounded corners on phones.
func _apply_safe_area(margin: MarginContainer) -> void:
	if not OS.has_feature("mobile"):
		return
	var screen := DisplayServer.screen_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if screen.y <= 0:
		return
	var scale_factor := get_viewport_rect().size.y / float(screen.y)
	margin.add_theme_constant_override("margin_top", int(safe.position.y * scale_factor))
	margin.add_theme_constant_override("margin_bottom", int((screen.y - safe.end.y) * scale_factor))
	margin.add_theme_constant_override("margin_left", int(safe.position.x * scale_factor))
	margin.add_theme_constant_override("margin_right", int((screen.x - safe.end.x) * scale_factor))


func _show_match_result(result: Dictionary) -> void:
	var box := UIKit.vbox(14)
	var outcome: String = result.get("outcome", "win" if result.won else "loss")
	var titles := {"win": "Victory!", "loss": "Defeat", "draw": "Draw"}
	var colors := {"win": UIKit.YELLOW, "loss": UIKit.RED, "draw": UIKit.TEXT}
	box.add_child(UIKit.label(titles[outcome], 52, colors[outcome], HORIZONTAL_ALIGNMENT_CENTER))
	if result.has("towers"):
		box.add_child(UIKit.label("Towers destroyed  %d - %d" % [result.towers[0], result.towers[1]], 24, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var change := int(result.trophy_change)
	box.add_child(UIKit.label("%+d trophies" % change, 34, UIKit.TROPHY, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UIKit.label("Total: %s" % UIKit.format_number(int(result.trophies)), 24, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))

	if result.new_arena:
		var arena := GameData.get_arena(int(result.arena_index))
		var arena_panel := UIKit.panel(Color(arena.color).darkened(0.3), 14)
		box.add_child(arena_panel)
		var arena_box := UIKit.vbox(6)
		arena_panel.add_child(arena_box)
		arena_box.add_child(UIKit.label("New arena: %s!" % arena.name, 28, UIKit.YELLOW, HORIZONTAL_ALIGNMENT_CENTER))
		var names := []
		for id in GameData.cards_in_arena(int(result.arena_index)):
			names.append(GameData.get_card(id).name)
		var unlocked := UIKit.paragraph("New animals can now be found: " + ", ".join(names), 21, UIKit.TEXT)
		unlocked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		arena_box.add_child(unlocked)

	if result.cage_id != "":
		box.add_child(UIKit.label("You won a %s!" % GameData.cages[result.cage_id].name, 26, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	elif result.slots_full:
		var full := UIKit.paragraph("Your cage slots are full, so no cage this time. Open some cages to make room!", 21, UIKit.TEXT)
		full.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(full)

	var modal := Modal.open(box, "", 560)
	var ok := UIKit.button("OK", UIKit.GREEN, 28, Vector2(200, 80))
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(modal.close)
	box.add_child(ok)
