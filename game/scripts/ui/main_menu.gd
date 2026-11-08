extends Control
## The home screen, laid out like other mobile card battlers:
## top bar, five tabs and a bottom navigation bar
## (Shop - Animals - Battle - Clan - Events), opening on Battle.

const TABS := [
	["Shop", preload("res://scripts/ui/tabs/shop_tab.gd"), "tab_shop"],
	["Animals", preload("res://scripts/ui/tabs/animals_tab.gd"), "tab_animals"],
	["Battle", preload("res://scripts/ui/tabs/battle_tab.gd"), "tab_battle"],
	["Clan", preload("res://scripts/ui/tabs/clan_tab.gd"), "tab_clan"],
	["Events", preload("res://scripts/ui/tabs/events_tab.gd"), "tab_events"],
]
const BATTLE_TAB := 2
const SHOP_TAB := 0

var _pages: Array = []
## Each tab in the bar: {"cell", "icon", "label"}.
var _nav: Array = []
var _animals_badge: Label
var _current := -1


func _ready() -> void:
	theme = UIKit.build_theme()

	var background := Backdrop.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var safe_area := MarginContainer.new()
	safe_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(safe_area)
	_apply_safe_area(safe_area)

	var column := UIKit.vbox(0)
	safe_area.add_child(column)
	var top_bar: Control = preload("res://scripts/ui/top_bar.gd").new()
	top_bar.shop_requested.connect(select_tab.bind(SHOP_TAB))
	column.add_child(top_bar)

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

	# Which build this is, small in the top corner under the bar (to check
	# the phone has the newest).
	var version := BuildInfo.label()
	version.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.position += Vector2(-12, 6)
	page_host.add_child(version)

	var popup_layer := Control.new()
	popup_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_layer.add_to_group("popup_layer")
	add_child(popup_layer)

	Profile.changed.connect(_update_badges)
	_update_badges()
	select_tab(BATTLE_TAB)
	Sound.play_music("menu")
	UIKit.fade_in(self)

	if OS.is_debug_build():
		for problem in GameData.validate():
			push_warning("Game data: " + problem)

	if not Profile.pending_match_result.is_empty():
		_show_match_result.call_deferred(Profile.pending_match_result)
		Profile.pending_match_result = {}
	_open_dev_shortcut()


## For testing only (debug builds, or show_dev_tools in testing.json): the
## website opened with ?viewer=<animal id> goes straight to that animal's
## 3D viewer (&pose=attack:0.6 holds that animation at that point), and
## with ?showcase=<animal id> to its attack showcase (&slow=1 slowed down),
## with ?army=1 to the Big army test, and with ?fight=<seed> to a real
## Draft Duel the computer plays for you (&mine=, &theirs=, &sizes=1):
## for checking a new model on a phone, or for screenshots. On a computer
## the same come from the environment (DEV_FIGHT=3 DEV_SIZES=1), and
## DEV_SHOT_DIR saves screenshots as it runs (DevShots).
func _open_dev_shortcut() -> void:
	if not (OS.is_debug_build() or GameData.testing.get("show_dev_tools", false)):
		return
	DevShots.start_if_asked(self)
	if _query("army") == "1":
		# The Big army test (40 animals a side, an fps counter), as 3D models.
		ArmyTest.use_models = true
		Transition.go.call_deferred("res://scenes/army_test.tscn")
		return
	var fight := _query("fight")
	if fight != "":
		# A real Draft Duel against the computer, played for you by the
		# computer too (?fight=<seed>; &mine=id,id and &theirs=id,id pick
		# the decks; &sizes=1 marks every animal's height on screen; &track=id,id
		# prints where those animals are drawn each frame, for frame scripts).
		DraftScreen.dev_auto = {"seed": fight.to_int(), "mine": _query("mine"), "theirs": _query("theirs"), "sizes": _query("sizes") == "1", "track": _query("track")}
		Transition.go.call_deferred("res://scenes/draft.tscn")
		return
	var show := _query("showcase")
	if GameData.cards.has(show) and GameData.styles.has(show):
		StyleShowcase.start_id = show
		StyleShowcase.start_slow = _query("slow") == "1"
		StyleShowcase.start_track = _query("track")
		Transition.go.call_deferred("res://scenes/style_showcase.tscn")
		return
	var id := _query("viewer")
	if id.is_empty() or not GameData.cards.has(id) or GameData.is_tool(id):
		return
	select_tab(1)
	_open_viewer_dev.call_deferred(id, _query("pose"))


## One value from the website's address (?key=value), or, on a computer,
## from the environment (DEV_KEY=value: the same shortcuts for screenshots
## from a script), or "".
func _query(key: String) -> String:
	if not OS.has_feature("web"):
		return OS.get_environment("DEV_" + key.to_upper())
	var value: Variant = JavaScriptBridge.eval("(new URLSearchParams(window.location.search)).get('%s') || ''" % key, true)
	return String(value) if value is String else ""


func _open_viewer_dev(id: String, pose: String) -> void:
	var viewer := AnimalViewer.open(id)
	viewer.dev_pose = pose


func select_tab(index: int) -> void:
	if index == _current:
		return
	_current = index
	for i in _pages.size():
		_pages[i].visible = i == index
		if i == index:
			# Fade the new tab in.
			_pages[i].modulate.a = 0.0
			_pages[i].create_tween().tween_property(_pages[i], "modulate:a", 1.0, 0.15)
		var selected: bool = i == index
		var tab: Dictionary = _nav[i]
		var cell: PanelContainer = tab.cell
		if selected:
			var style := UIKit.raised(UIKit.PANEL_LIGHT, 18, 4)
			style.border_color = UIKit.PANEL_LIGHT.lightened(0.35)
			style.shadow_offset = Vector2(0, 2)
			cell.add_theme_stylebox_override("panel", style)
		else:
			cell.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		cell.size_flags_stretch_ratio = 1.45 if selected else 1.0
		tab.icon.custom_minimum_size = Vector2(56, 56) if selected else Vector2(46, 46)
		tab.icon.modulate = Color.WHITE if selected else UIKit.TEXT_DIM
		tab.label.visible = selected
		if selected:
			# The chosen tab pops up a little.
			tab.icon.pivot_offset = Vector2(28, 28)
			tab.icon.scale = Vector2(0.8, 0.8)
			tab.icon.create_tween().tween_property(tab.icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The tab bar at the bottom: an icon for each tab; the chosen one is raised
## and shows its name.
func _build_nav() -> Control:
	var bar := PanelContainer.new()
	var bar_style := UIKit.box(UIKit.DEEP, 0, 8)
	bar_style.border_width_top = 2
	bar_style.border_color = UIKit.PANEL
	bar_style.shadow_color = Color(UIKit.INK, 0.4)
	bar_style.shadow_size = 10
	bar.add_theme_stylebox_override("panel", bar_style)
	var row := UIKit.hbox(6)
	bar.add_child(row)
	for i in TABS.size():
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(0, 96)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var stack := UIKit.vbox(0)
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(stack)
		var icon := UIKit.icon_rect(GameData.ui_icon(TABS[i][2]), Color.WHITE, 46)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(icon)
		var label := UIKit.label(TABS[i][0], 20, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		stack.add_child(label)
		UIKit.on_tap(cell, select_tab.bind(i))
		row.add_child(cell)
		_nav.append({"cell": cell, "icon": icon, "label": label})

	# A little "!" on the Animals tab when something can be upgraded or is new.
	_animals_badge = UIKit.label("!", 22, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	var badge_style := UIKit.box(UIKit.RED, 15)
	badge_style.set_border_width_all(2)
	badge_style.border_color = UIKit.INK
	_animals_badge.add_theme_stylebox_override("normal", badge_style)
	_animals_badge.size = Vector2(30, 30)
	_animals_badge.position = Vector2(30, -6)
	_animals_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# On the icon (not a container), so it keeps its own size and spot.
	_nav[1].icon.add_child(_animals_badge)
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
	if result.get("boss_beaten", false):
		titles.win = "Boss Defeated!"
	var colors := {"win": UIKit.YELLOW, "loss": UIKit.RED, "draw": UIKit.TEXT}
	box.add_child(UIKit.label(titles[outcome], 52, colors[outcome], HORIZONTAL_ALIGNMENT_CENTER))
	var rival := GameData.rival(result.get("rival", ""))
	if not rival.is_empty():
		var row := UIKit.hbox(10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var portrait := RangerPortrait.create(rival, 72)
		portrait.mood = {"win": "sad", "loss": "happy"}.get(outcome, "normal")
		row.add_child(portrait)
		row.add_child(UIKit.label(("vs %s" % rival.name) + ("  (Boss)" if rival.get("boss", false) else ""), 24, UIKit.TEXT))
		box.add_child(row)
	if result.has("score"):
		box.add_child(UIKit.label("%d - %d" % [result.score[0], result.score[1]], 34, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
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

	var boss_reward: Dictionary = result.get("boss_reward", {})
	if not boss_reward.is_empty():
		var reward_panel := UIKit.panel(UIStyle.color("boss_reward"), 14)
		box.add_child(reward_panel)
		var reward_box := UIKit.vbox(6)
		reward_panel.add_child(reward_box)
		reward_box.add_child(UIKit.label("First boss win!", 28, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		var reward_row := UIKit.hbox(10)
		reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
		reward_row.add_child(UIKit.pill(GameData.ui_icon("gold"), UIKit.GOLD, "+%s" % UIKit.format_number(int(boss_reward.gold))))
		reward_row.add_child(UIKit.pill(GameData.ui_icon("gems"), UIKit.GEMS, "+%d" % int(boss_reward.gems)))
		reward_box.add_child(reward_row)
		if boss_reward.get("cage_id", "") != "":
			reward_box.add_child(UIKit.label("and a %s!" % GameData.cages[boss_reward.cage_id].name, 22, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))

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
