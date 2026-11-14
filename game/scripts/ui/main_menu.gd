extends Control
## The home screen, laid out like other mobile card battlers:
## top bar, five tabs and a bottom navigation bar
## (Shop - Animals - Battle - Clan - Events), opening on Battle. It wears
## the match's "Ranger Camp" look (docs/ART_DIRECTION.md): a sunny sky
## behind, wooden planks for the bars, a toy for every icon
## (tools/props; art.json "menu").

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
## Each tab in the bar: {"cell", "tile", "icon", "label"}.
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
	column.add_child(_inset(top_bar, 8, 6, 0))

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
	version.position += Vector2(-14, 4)
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
## with ?tab=shop to that tab of the menu, with ?result=win to a sample of
## the popup after a match (loss, draw, boss, arena),
## with ?arttest=1 to the art tests beside our animals (ArtTestScreen),
## with ?army=1 to the Big army test, and with ?fight=<seed> to a real
## Draft Duel the computer plays for you (&mine=, &theirs=, &sizes=1):
## for checking a new model on a phone, or for screenshots. On a computer
## the same come from the environment (DEV_FIGHT=3 DEV_SIZES=1), and
## DEV_SHOT_DIR saves screenshots as it runs (DevShots).
func _open_dev_shortcut() -> void:
	if not (OS.is_debug_build() or GameData.testing.get("show_dev_tools", false)):
		return
	DevShots.start_if_asked(self)
	# Art tests (art_tests.json): animals from an outside art pack, tried out
	# next to ours. They only exist when a shortcut asks for one.
	if _wants_art_tests():
		GameData.install_art_tests()
	if _query("arttest") == "1":
		# Their cards beside ours (tap for the 3D viewer), and a test fight.
		_open_art_tests.call_deferred()
		return
	if _query("army") == "1":
		# The Big army test (40 animals a side, an fps counter), as 3D models.
		ArmyTest.use_models = true
		Transition.go.call_deferred("res://scenes/army_test.tscn")
		return
	# &result=win (loss, draw, boss, arena) shows a sample of the popup that
	# follows a match.
	if _query("result") != "":
		_show_match_result.call_deferred(_sample_result(_query("result")))
	# &tab=shop (animals, battle, clan, events) opens on that tab.
	var tab := TABS.map(func(entry): return String(entry[0]).to_lower()).find(_query("tab").to_lower())
	if tab >= 0:
		select_tab(tab)
	var fight := _query("fight")
	if fight != "":
		# A real Draft Duel against the computer, played for you by the
		# computer too (?fight=<seed>; &mine=id,id and &theirs=id,id pick
		# the decks; &sizes=1 marks every animal's height on screen; &track=id,id
		# prints where those animals are drawn each frame, for frame scripts).
		# &slow=1 plays it in slow motion (styles showcase_slow_speed; or
		# &slow=0.1, that fraction of full speed), for frame-by-frame shots.
		# &herds=id*2,id|id,id*3 skips the picks: the first fight with those
		# herds ("id*2": two squads of it) at once.
		DraftScreen.dev_auto = {"seed": fight.to_int(), "mine": _query("mine"), "theirs": _query("theirs"), "sizes": _query("sizes") == "1", "track": _query("track"), "slow": _slow_of(_query("slow")), "herds": _query("herds")}
		Transition.go.call_deferred("res://scenes/draft.tscn")
		return
	var show := _query("showcase")
	if GameData.cards.has(show) and GameData.styles.has(show):
		StyleShowcase.start_id = show
		StyleShowcase.start_slow = _slow_of(_query("slow"))
		StyleShowcase.start_track = _query("track")
		Transition.go.call_deferred("res://scenes/style_showcase.tscn")
		return
	var id := _query("viewer")
	if id.is_empty() or not GameData.cards.has(id) or GameData.is_tool(id):
		return
	select_tab(1)
	_open_viewer_dev.call_deferred(id, _query("pose"))


## True if the website's address (or, on a computer, the environment) asks
## for an art test: ?arttest=1, or an art test's id in ?viewer=, ?showcase=,
## &herds=, &mine= or &theirs=.
func _wants_art_tests() -> bool:
	if _query("arttest") == "1":
		return true
	var ids: Dictionary = GameData.art_tests.get("animals", {})
	for key in ["viewer", "showcase", "herds", "mine", "theirs"]:
		var value := _query(key)
		if value == "":
			continue
		for id: String in ids:
			if value.contains(id):
				return true
	return false


## The speed a &slow= value asks for: 1 is the showcase's slow motion
## (styles showcase_slow_speed), a fraction under 1 that share of full
## speed, anything else full speed (0: not slowed).
static func _slow_of(value: String) -> float:
	if value == "1":
		return Feel.num("styles", "showcase_slow_speed", 0.3)
	var k := value.to_float()
	return k if k > 0.0 and k < 1.0 else 0.0


## One value from the website's address (?key=value), or, on a computer,
## from the environment (DEV_KEY=value: the same shortcuts for screenshots
## from a script), or "".
func _query(key: String) -> String:
	if not OS.has_feature("web"):
		return OS.get_environment("DEV_" + key.to_upper())
	var value: Variant = JavaScriptBridge.eval("(new URLSearchParams(window.location.search)).get('%s') || ''" % key, true)
	return String(value) if value is String else ""


## A made-up match result of `kind` ("win", "loss", "draw", "boss": a first
## boss win with its reward, "arena": a win into the next arena), for
## looking at the result popup without playing a match.
func _sample_result(kind: String) -> Dictionary:
	var arena := Profile.arena_index()
	var rivals: Array = GameData.rivals_in_arena(arena, kind == "boss")
	var outcome := kind if kind in ["win", "loss", "draw"] else "win"
	var result := {"won": outcome == "win", "outcome": outcome, "score": [4, 2] if outcome == "win" else ([2, 4] if outcome == "loss" else [3, 3]),
		"trophy_change": {"win": 30, "loss": -24, "draw": 0}[outcome], "trophies": Profile.get_trophies(),
		"rival": String(rivals[0].id) if not rivals.is_empty() else "", "new_arena": kind == "arena",
		"arena_index": mini(arena + 1, GameData.arenas.size() - 1) if kind == "arena" else arena,
		"cage_id": "twig" if outcome == "win" else "", "slots_full": false}
	if kind == "boss":
		result["boss_beaten"] = true
		result["boss_reward"] = {"gold": 500, "gems": 20, "cage_id": "golden"}
	return result


func _open_art_tests() -> void:
	ArtTestScreen.open()


func _open_viewer_dev(id: String, pose: String) -> void:
	var viewer := AnimalViewer.open(id)
	viewer.dev_pose = pose


func select_tab(index: int) -> void:
	if index == _current:
		return
	_current = index
	var c := "menu"
	var small := Feel.num(c, "tab_icon", 62.0)
	var big := Feel.num(c, "tab_icon_picked", 84.0)
	for i in _pages.size():
		_pages[i].visible = i == index
		if i == index:
			# Fade the new tab in.
			_pages[i].modulate.a = 0.0
			_pages[i].create_tween().tween_property(_pages[i], "modulate:a", 1.0, 0.15)
		var selected: bool = i == index
		var tab: Dictionary = _nav[i]
		var cell: Control = tab.cell
		var tile: Panel = tab.tile
		var icon: Control = tab.icon
		tile.visible = selected
		cell.size_flags_stretch_ratio = 1.5 if selected else 1.0
		icon.custom_minimum_size = Vector2(big, big) if selected else Vector2(small, small)
		tab.label.visible = selected
		if selected:
			# The chosen tab hops up.
			icon.pivot_offset = Vector2(big, big) / 2.0
			icon.scale = Vector2(0.7, 0.7)
			var hop := icon.create_tween()
			hop.tween_property(icon, "scale", Vector2.ONE, Feel.num(c, "tab_bounce_seconds", 0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			icon.scale = Vector2.ONE


## The tab bar at the bottom: a wooden plank with a toy for each tab; the
## chosen one stands on a raised tile, bigger, with its name.
func _build_nav() -> Control:
	var c := "menu"
	var bar := PanelContainer.new()
	var plank := SkinBox.make("sign", UIStyle.color("sign"))
	plank.content_margin_left = 14
	plank.content_margin_right = 14
	plank.content_margin_top = 4
	plank.content_margin_bottom = 10
	bar.add_theme_stylebox_override("panel", plank)
	var row := UIKit.hbox(4)
	bar.add_child(row)
	var props: Array = GameData.art.get("menu", {}).get("tabs", [])
	var small := Feel.num(c, "tab_icon", 62.0)
	for i in TABS.size():
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(0, Feel.num(c, "tab_height", 104.0))
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# The raised tile under the chosen tab: light wood, standing proud
		# of the bar.
		var tile := Panel.new()
		tile.add_theme_stylebox_override("panel", SkinBox.make("panel", UIKit.PANEL_LIGHT))
		tile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tile.offset_top = -Feel.num(c, "tab_lift", 14.0)
		tile.offset_bottom = -2.0
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.visible = false
		cell.add_child(tile)
		var stack := UIKit.vbox(-6)
		stack.alignment = BoxContainer.ALIGNMENT_CENTER
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.offset_top = -Feel.num(c, "tab_lift", 14.0)
		cell.add_child(stack)
		var prop := String(props[i]) if i < props.size() else ""
		var icon: TextureRect = MenuArt.rect(prop, small) if MenuArt.has(prop) else UIKit.icon_rect(GameData.ui_icon(TABS[i][2]), Color.WHITE, int(small))
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(icon)
		var label := UIKit.label(TABS[i][0], 22, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(label)
		UIKit.on_tap(cell, select_tab.bind(i))
		row.add_child(cell)
		_nav.append({"cell": cell, "tile": tile, "icon": icon, "label": label})

	# A little "!" on the Animals tab when something can be upgraded or is new.
	_animals_badge = UIKit.label("!", 22, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	var badge_style := UIKit.box(UIKit.RED, 15)
	badge_style.set_border_width_all(3)
	badge_style.border_color = UIKit.INK
	_animals_badge.add_theme_stylebox_override("normal", badge_style)
	_animals_badge.size = Vector2(32, 32)
	_animals_badge.position = Vector2(small - 22.0, -4)
	_animals_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# On the icon (not a container), so it keeps its own size and spot.
	_nav[1].icon.add_child(_animals_badge)
	return _inset(bar, 8, 0, 6)


## A bar with a little air between it and the screen's edges (`side`),
## above it (`top`) and under it (`bottom`).
func _inset(bar: Control, side: int, top: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", side)
	margin.add_theme_constant_override("margin_right", side)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_bottom", bottom)
	margin.add_child(bar)
	return margin


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
		# The cage you won, as it will stand on your shelf.
		var won := IconArt.new()
		won.shape = IconArt.Shape.CAGE
		won.color = Color(String(GameData.cages[result.cage_id].color))
		won.custom_minimum_size = Vector2(150, 150)
		won.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(won)
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
