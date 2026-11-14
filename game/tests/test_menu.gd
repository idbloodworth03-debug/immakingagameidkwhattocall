extends TestCase
## The main menu in the animals' own toy look (docs/ART_DIRECTION.md "The
## menus"): painted wood on a sunny sky (scripts/ui/ui_kit.gd,
## style/kit_box.gd), a toy for every icon (art/menu/, tools/props;
## scripts/ui/menu_art.gd), and on the home tab your deck's animals
## standing together as live toys in your arena (scripts/ui/squad_stage.gd).

const TOP_BAR := preload("res://scripts/ui/top_bar.gd")

var _saved: Dictionary
var _autosave := true
var _switches := true
var _made: Array = []


func _init() -> void:
	_saved = Profile.data.duplicate(true)
	_autosave = Profile.autosave
	_switches = Profile.testing_switches
	Profile.autosave = false
	Profile.testing_switches = false


func cleanup() -> void:
	for node in _made:
		if is_instance_valid(node):
			node.free()
	_made.clear()
	Profile.data = _saved
	Profile.autosave = _autosave
	Profile.testing_switches = _switches
	Profile.pending_match_result = {}
	MatchPlan.clear()


func _host() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_child(tree.root.get_child_count() - 1)


func _animals() -> Array:
	return GameData.card_order.filter(func(id): return not GameData.is_tool(id))


## A squad of these animals on a stage, in the tree, lined up (`numbers`
## replace feel.json's for it).
func _squad(ids: Array, habitat := "forest", numbers := {}) -> SquadStage:
	var stage := SquadStage.make(ids, habitat)
	stage.overrides = numbers
	stage.size = Vector2(680, 720)
	_made.append(stage)
	_host().add_child(stage)
	stage.load_now()
	return stage


## The main menu, in the tree.
func _menu() -> Control:
	var menu: Control = load("res://scenes/main.tscn").instantiate()
	_made.append(menu)
	_host().add_child(menu)
	return menu


# --- The toy props ---------------------------------------------------------------

func test_every_prop_the_menu_names_is_there() -> void:
	var menu: Dictionary = GameData.art.get("menu", {})
	var props: Dictionary = menu.get("props", {})
	check(props.size() >= 4, "coins, gems, the trophy and the lock have a toy (%d)" % props.size())
	for icon_name: String in props:
		check(MenuArt.has(String(props[icon_name])), "the toy for the %s icon: %s" % [icon_name, props[icon_name]])
		check(ResourceLoader.exists("res://art/icons/%s.svg" % icon_name), "%s is one of the game's icons" % icon_name)
		check_eq(MenuArt.for_icon(icon_name), String(props[icon_name]), "the menus find it by the icon's name")
	check_eq((menu.get("tabs", []) as Array).size(), 5, "a toy for each of the five tabs")
	for prop: String in menu.get("tabs", []) + menu.get("gold_packs", []):
		check(MenuArt.has(prop), "the %s toy" % prop)
	check_eq((menu.get("gold_packs", []) as Array).size(), (GameData.progression.gold_packs as Array).size(), "a heap of coins for each gold pack")
	check_eq(MenuArt.for_icon("flat-paw-print"), "", "an icon without a toy stays an icon")


func test_every_cage_is_a_toy_of_its_own() -> void:
	var seen := {}
	for id: String in GameData.cages:
		var art := MenuArt.cage(id)
		check(MenuArt.has("cage_" + id), "the %s has its toy" % id)
		check(art != null and not seen.has(art), "and it is its own picture")
		seen[art] = true
		check_eq(MenuArt.cage_for_color(Color(String(GameData.cages[id].color))), id, "found by the %s's color" % id)
	check(MenuArt.has("cage_empty"), "an empty slot's cage")
	check_eq(MenuArt.cage(""), MenuArt.texture("cage_empty"), "which stands in an empty slot")
	check(not seen.has(MenuArt.cage("")), "and is none of the others")


# --- Painted wood ------------------------------------------------------------------

func test_menu_panels_are_painted_wood() -> void:
	var panel := UIKit.raised(UIKit.PANEL, 18, 14)
	check(panel is KitBox, "a raised panel is a painted piece")
	check_eq(panel._skin_for(Rect2(0, 0, 400, 300)).skin, "panel", "a tall box is a wooden panel")
	check_eq(panel._skin_for(Rect2(0, 0, 200, 48)).skin, "chip", "a short one a chip")
	var well := UIKit.inset()
	check_eq(well._skin_for(Rect2(0, 0, 400, 300)).skin, "inset", "a well is sunk into its panel")
	check(well.bg_color.v < UIKit.PANEL.v, "and darker than it")
	check(panel.content_margin_bottom > panel.content_margin_top, "a panel's lip takes room along its bottom")
	# The palette: warm wood, a dark outline that stands off the sky and the
	# wood alike, a lighter tile for what is picked.
	var wood := UIStyle.color("kit_panel")
	check(wood.h >= 0.04 and wood.h <= 0.14 and wood.s >= 0.55, "panels are warm wood (hue %.2f, saturation %.2f)" % [wood.h, wood.s])
	check(UIStyle.color("kit_panel_dark").v < wood.v and UIStyle.color("kit_deep").v < UIStyle.color("kit_panel_dark").v, "wells and tracks are darker wood")
	check(UIStyle.color("kit_panel_light").v > wood.v, "a picked tile is lighter wood")
	var buttons: Array = [UIKit.button("Buy", UIKit.GREEN), UIKit.price_button("500", "gems")]
	for b: Button in buttons:
		var skin := b.find_children("*", "ButtonSkin", false, false)
		check_eq(skin.size(), 1, "a button wears the painted button piece")
	check(buttons[1].icon == MenuArt.texture("gem"), "a gem price shows the toy gem")
	check(UIKit.price_button("200", "gold").icon == MenuArt.texture("coin"), "a gold price the toy coin")
	for b: Button in buttons:
		b.free()


func test_menu_text_is_outlined() -> void:
	# (Inside a screen that wears the menus' theme, as every menu does.)
	var screen := Control.new()
	screen.theme = UIKit.build_theme()
	_made.append(screen)
	_host().add_child(screen)
	for size in [20, 26, 44]:
		var words := UIKit.paragraph("Find more in cages.", size)
		screen.add_child(words)
		check(words.get_theme_constant("outline_size") >= 4, "body text of %d has an outline (%d)" % [size, words.get_theme_constant("outline_size")])
		check_eq(words.get_theme_color("font_outline_color"), UIKit.INK, "in the menus' dark brown")
	var title := UIKit.label("Cages", 30)
	screen.add_child(title)
	check(title.get_theme_constant("outline_size") >= 6, "titles have a thick one (%d)" % title.get_theme_constant("outline_size"))
	check_eq(title.get_theme_color("font_outline_color"), UIKit.INK, "the same brown")
	var heading := UIKit.heading("Cages")
	screen.add_child(heading)
	var plank := heading.get_child(0) as PanelContainer
	check(plank != null and (plank.get_theme_stylebox("panel") as SkinBox).skin == "sign", "a heading stands on a trail-sign plank")


func test_amounts_fit_the_top_bar() -> void:
	check_eq(TOP_BAR.short_amount(0), "0", "nothing")
	check_eq(TOP_BAR.short_amount(999999), "999,999", "in full up to 999,999")
	check_eq(TOP_BAR.short_amount(1000000), "1.00M", "then in millions")
	check_eq(TOP_BAR.short_amount(12345678), "12.3M", "with fewer decimals as it grows")
	check_eq(TOP_BAR.short_amount(250000000), "250M", "and none past a hundred million")
	for amount in [7, 4321, 999999, 1000966, 98765432, 2000000000]:
		check(TOP_BAR.short_amount(amount).length() <= 7, "%d fits its slot (%s)" % [amount, TOP_BAR.short_amount(amount)])


# --- The squad -----------------------------------------------------------------------

func test_each_arena_has_a_stage() -> void:
	var habitats: Dictionary = GameData.viewer.get("habitats", {})
	for arena: Dictionary in GameData.arenas:
		check(habitats.has(String(arena.get("stage", ""))), "%s stands on one of the viewer's stages (%s)" % [arena.id, arena.get("stage", "none")])


func test_every_animal_can_stand_in_a_squad() -> void:
	var count := 0
	for id: String in _animals():
		check(AnimalViewer.has_model(id), "%s has a model to stand" % id)
		var stage := _squad([id])
		check_eq(stage.standing(), 1, "%s stands" % id)
		var actor: Dictionary = stage._actors[0]
		var tall := float(actor.get("tall", 0.0))
		check(tall > 0.1 and tall <= float(actor.size) + 0.01, "%s stands %.2f tall, its longest side %.2f" % [id, tall, float(actor.size)])
		count += 1
		cleanup()
		_init()
	check(count >= 35, "every animal tried (%d)" % count)


func test_the_squad_lines_up_with_every_face_showing() -> void:
	var deck := ["brown_bear", "wolf_pack", "gray_squirrel", "peregrine_falcon", "red_fox", "wild_boar", "striped_skunk", "snapping_turtle"]
	var stage := _squad(deck)
	check_eq(stage.standing(), deck.size(), "the whole deck stands")
	var rows: Array = stage.rows()
	check_eq(rows[-1], ["peregrine_falcon"], "the flier hovers behind the others")
	var ground: Array = rows.slice(0, rows.size() - 1)
	var pattern: Array = ground.map(func(row: Array) -> int: return row.size())
	check_eq(pattern, (GameData.feel.menu.squad.rows as Dictionary)["7"].map(func(n): return int(n)), "seven on the ground stand as feel.json's rows say")
	for r in range(1, ground.size()):
		check_eq(absi(int(pattern[r]) - int(pattern[r - 1])), 1, "neighboring rows differ by one, so faces show between shoulders")
	# The tall ones behind, the low ones in front.
	var tall := {}
	var slot := {}
	for actor: Dictionary in stage._actors:
		tall[String(actor.id)] = float(actor.tall)
		slot[String(actor.id)] = actor.slot as Vector3
	for r in range(1, ground.size()):
		var behind: float = (ground[r - 1] as Array).map(func(id: String) -> float: return float(tall[id])).min()
		var front: float = (ground[r] as Array).map(func(id: String) -> float: return float(tall[id])).max()
		check(behind >= front - 0.001, "row %d stands no taller than the row behind it (%.2f, %.2f)" % [r, front, behind])
		check((slot[ground[r][0]] as Vector3).z > (slot[ground[r - 1][0]] as Vector3).z, "and nearer the camera")
	# Nobody stands straight in front of anybody in the next row.
	for r in range(1, ground.size()):
		for a: String in ground[r]:
			for b: String in ground[r - 1]:
				check(absf((slot[a] as Vector3).x - (slot[b] as Vector3).x) > 0.1, "%s isn't straight in front of %s" % [a, b])
	# Everyone on the stage, facing the camera, turned toward the middle.
	var radius := float(GameData.viewer.platform.radius)
	var turn := deg_to_rad(float(GameData.feel.menu.squad.turn_degrees))
	for actor: Dictionary in stage._actors:
		var at: Vector3 = (actor.slot as Vector3) * stage._fit
		check(Vector2(at.x, at.z).length() <= radius, "%s stands on the stage (%.2f of %.2f)" % [actor.id, Vector2(at.x, at.z).length(), radius])
		var off := wrapf(float(actor.yaw) - PI, -PI, PI)
		check(absf(off) <= turn + 0.001, "%s faces the camera" % actor.id)
		check(off * at.x <= 0.0001, "%s is turned toward the middle" % actor.id)


func test_squads_of_any_size_line_up() -> void:
	var pool := ["asian_elephant", "red_fox", "gray_squirrel", "lion", "giant_panda", "king_cobra", "wild_boar", "tiger", "raccoon"]
	for count in range(1, pool.size()):
		var stage := _squad(pool.slice(0, count))
		check_eq(stage.standing(), count, "%d stand" % count)
		var total := 0
		for row: Array in stage.rows():
			total += row.size()
		check_eq(total, count, "each in a row (%s)" % str(stage.rows()))
		check(stage._fit > 0.3 and stage._fit <= 1.0, "%d fit the stage (drawn at %.2f)" % [count, stage._fit])
		cleanup()
		_init()
	var none := _squad([])
	check_eq(none.standing(), 0, "an empty squad is an empty stage")
	check_eq(none.rows(), [], "with nobody on it")


func test_the_squad_can_stand_as_lighter_models() -> void:
	# feel.json "menu" "squad" light_models: the fights' lighter models, should
	# a phone need them (off: the viewer's finer ones).
	check(not bool(GameData.feel.menu.squad.light_models), "the squad stands as the viewer's finer models")
	var deck := ["brown_bear", "red_fox", "gray_squirrel", "peregrine_falcon"]
	var fine := _squad(deck)
	var light := _squad(deck, "forest", {"light_models": true})
	check_eq(light.standing(), deck.size(), "the light squad stands too")
	check_eq(light.rows(), fine.rows(), "in the same places")
	for i in deck.size():
		check(String(light._actors[i].path).begins_with(ModelStage.DIR), "%s as its fight model" % deck[i])
		check_eq(String(fine._actors[i].path), AnimalViewer.model_path(deck[i]), "%s as its viewer model" % deck[i])
		check(absf(float(light._actors[i].tall) - float(fine._actors[i].tall)) < 0.12, "%s stands as tall either way (%.2f, %.2f)" % [deck[i], float(light._actors[i].tall), float(fine._actors[i].tall)])


func test_a_tapped_animal_celebrates() -> void:
	var stage := _squad(["brown_bear", "red_fox", "gray_squirrel"])
	var tapped := []
	stage.animal_tapped.connect(func(id: String) -> void: tapped.append(id))
	var fox := -1
	for i in stage._actors.size():
		if String(stage._actors[i].id) == "red_fox":
			fox = i
	var spot := stage.screen_spot(fox)
	check(spot != Vector2.INF and Rect2(Vector2.ZERO, stage.size).has_point(spot), "the fox is drawn in the window (%s)" % str(spot))
	check_eq(stage.actor_at(spot), fox, "a tap on it finds it")
	check_eq(stage.actor_at(Vector2(-400, -400)), -1, "a tap far from everyone finds nobody")
	stage.react(fox)
	check_eq(tapped, ["red_fox"], "it says who was tapped")
	var m: ModelStage.Model = stage._actors[fox].model
	check_eq(String(m.player.current_animation), "victory", "and it celebrates")


# --- The menu ---------------------------------------------------------------------------

func test_the_menu_shows_your_squad_and_five_toy_tabs() -> void:
	var menu := _menu()
	check_eq(menu._pages.size(), 5, "five tabs")
	check_eq(menu._current, 2, "opening on Battle")
	var props: Array = GameData.art.menu.tabs
	for i in menu._nav.size():
		var tab: Dictionary = menu._nav[i]
		check_eq((tab.icon as TextureRect).texture, MenuArt.texture(String(props[i])), "tab %d wears its toy" % i)
		check_eq((tab.label as Label).visible, i == 2, "only the tab you're on shows its name")
		check_eq((tab.tile as Control).visible, i == 2, "and stands on the raised tile")
	menu.select_tab(0)
	check(menu._pages[0].visible and not menu._pages[2].visible, "picking a tab shows its page")
	check((menu._nav[0].label as Label).visible and not (menu._nav[2].label as Label).visible, "and its name")
	menu.select_tab(2)
	var squads: Array = menu.find_children("*", "SquadStage", true, false)
	check_eq(squads.size(), 1, "your squad stands on the home tab")
	var squad := squads[0] as SquadStage
	check_eq(squad.ids, Profile.get_deck(), "it is your deck")
	check_eq(squad.habitat, String(GameData.get_arena(Profile.arena_index()).stage), "in your arena's scene")
	squad.load_now()
	check_eq(squad.standing(), Profile.get_deck().size(), "all of it")
	check(menu.find_children("*", "Backdrop", true, false).size() == 1, "under a sunny sky")


func test_the_cage_shelf_shows_toy_cages() -> void:
	# A locked Golden Cage, a Crystal Cage ready to open, two empty slots.
	Profile.data.cage_slots = [{"cage_id": "golden", "arena": 0, "unlock_at": 0.0}, {"cage_id": "crystal", "arena": 0, "unlock_at": 1.0}, null, null]
	check_eq([Profile.cage_slot_state(0), Profile.cage_slot_state(1), Profile.cage_slot_state(2)], ["locked", "ready", "empty"], "a locked cage, a ready one, an empty slot")
	var menu := _menu()
	var cages: Array = (menu._pages[2] as Control).find_children("*", "IconArt", true, false).filter(func(art: IconArt) -> bool: return art.shape == IconArt.Shape.CAGE)
	check_eq(cages.size(), Profile.data.cage_slots.size(), "a cage on every slot")
	check_eq(MenuArt.cage_for_color((cages[0] as IconArt).color), "golden", "the Golden Cage in its slot")
	check_eq(MenuArt.cage_for_color((cages[1] as IconArt).color), "crystal", "the Crystal Cage in its")
	check((cages[2] as IconArt).dimmed and (cages[3] as IconArt).dimmed, "an empty slot: the gray cage")
	check(not (cages[0] as IconArt).dimmed, "a cage you have: in its colors")
	# The slot of the one that's ready glows.
	var shelves: Array = (menu._pages[2].get("_slots_row") as Control).get_children()
	var ready := (shelves[1] as PanelContainer).get_theme_stylebox("panel") as KitBox
	var locked := (shelves[0] as PanelContainer).get_theme_stylebox("panel") as KitBox
	var empty := (shelves[2] as PanelContainer).get_theme_stylebox("panel") as KitBox
	check(ready != null and ready.glow and ready.border_width >= 3, "the ready cage's shelf has a bright ring that glows")
	check(locked != null and not locked.glow and not locked.sunken, "a locked cage stands on a plain shelf")
	check(empty != null and empty.sunken, "an empty slot is a sunken one")


func test_the_game_loads_under_the_menus_sky() -> void:
	# The splash screen and the web page while the game loads are the color
	# of the menus' sky (project.godot boot_splash; export_presets.cfg), and
	# the splash, the icon and the logo are there (tools/make_logo.py).
	var sky := UIStyle.color("kit_bg_top")
	var splash: Color = ProjectSettings.get_setting("application/boot_splash/bg_color")
	check(absf(splash.r - sky.r) + absf(splash.g - sky.g) + absf(splash.b - sky.b) < 0.02, "the splash screen is the sky's color (%s, %s)" % [splash.to_html(false), sky.to_html(false)])
	check_eq(UIStyle.color("kit_bg_top"), UIStyle.color("sky"), "the menus' sky is the match's sky")
	check_eq(UIStyle.color("kit_bg_bottom"), UIStyle.color("sky_deep"), "down to the same sunshine")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	if presets != "":
		check(presets.count("#" + sky.to_html(false)) >= 2, "the web page's background and theme color too")
	for file_name in ["splash.png", "app_icon.png", "logo.png"]:
		check(ResourceLoader.exists("res://art/logo/" + file_name), "art/logo/%s" % file_name)


func test_the_result_popup_shows_for_every_outcome() -> void:
	var menu := _menu()
	var layer: Node = menu.get_tree().get_first_node_in_group("popup_layer")
	for kind in ["win", "loss", "draw", "boss", "arena"]:
		var before := layer.get_child_count()
		menu._show_match_result(menu._sample_result(kind))
		check_eq(layer.get_child_count(), before + 1, "a popup after a %s" % kind)
		var popup := layer.get_child(layer.get_child_count() - 1) as Modal
		check(popup != null, "the result of a %s" % kind)
		var cages: Array = popup.find_children("*", "IconArt", true, false).filter(func(art: IconArt) -> bool: return art.shape == IconArt.Shape.CAGE)
		check_eq(cages.size(), 1 if kind in ["win", "boss", "arena"] else 0, "a %s %s the cage you won" % [kind, "shows" if kind != "loss" and kind != "draw" else "has no"])
