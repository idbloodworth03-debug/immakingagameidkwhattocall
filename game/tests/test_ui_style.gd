extends TestCase
## The design system (data/ui_style.json, scripts/ui/style/): its rules hold
## and every screen-facing piece builds.


func test_sizes_follow_the_rules() -> void:
	var sizes: Array = UIStyle.SIZES.map(func(key): return UIStyle.text_size(key))
	check_eq(sizes.size(), 4, "four text sizes")
	for i in range(1, sizes.size()):
		check(int(sizes[i]) > int(sizes[i - 1]), "text sizes grow: %s" % str(sizes))
	# The layout is 720 wide: about 0.54 pt per pixel on an iPhone.
	check(UIStyle.text_size("small") * 0.54 >= 14.0, "the smallest text is at least about 14 pt")
	check(UIStyle.num("button", "min_height", 0) * 0.54 >= 47.5, "buttons are at least a 48 pt touch target")
	for key in ["xs", "s", "m", "l"]:
		check(UIStyle.space(key) % 8 == 0, "spacing %s is on the 8-pixel scale" % key)


func test_every_color_is_defined() -> void:
	var needed := ["sky", "sky_deep", "panel", "panel_inset", "outline", "text", "text_soft", "chip", "heart", "acorn",
		"gem", "trophy", "flame", "selected", "player", "enemy"] + UIStyle.KINDS
	for key in needed:
		check(GameData.ui_style.colors.has(key), "ui_style.json defines '%s'" % key)
	for rarity in GameData.rarity_order:
		check(GameData.ui_style.colors.has("rarity_" + rarity), "a card frame color for %s" % rarity)


func test_components_build() -> void:
	var theme := UIStyle.theme()
	for kind in UIStyle.KINDS:
		check(theme.has_stylebox("normal", kind.capitalize() + "Button"), "%s button style" % kind)
	var b := UIStyle.button("Reroll", "secondary", "reroll", 1)
	check(b.cost_label != null and b.cost_label.text == "1", "a button can show an Acorn price")
	var pill := UIStyle.pill("heart", Color.RED, 30)
	check_eq(pill.amount.text, "30", "a pill shows its number")
	var card := GameCard.make("red_fox", Vector2(200, 150))
	check_eq(card.custom_minimum_size, Vector2(200, 150), "a card takes its size")
	for node in [b, pill, card]:
		node.free()


# --- Bright, bold, solid colors ---------------------------------------------------

## WCAG contrast between two colors (1 to 21).
func _contrast(a: Color, b: Color) -> float:
	var la := a.srgb_to_linear().get_luminance() + 0.05
	var lb := b.srgb_to_linear().get_luminance() + 0.05
	return maxf(la, lb) / minf(la, lb)


func test_every_color_lives_in_ui_style() -> void:
	var colors: Dictionary = GameData.ui_style.colors
	for id in GameData.rarity_order:
		check(colors.has("rarity_" + id), "rarity %s's color in ui_style.json" % id)
		check_eq(GameData.rarity_color(id), UIStyle.color("rarity_" + id), "%s: one color everywhere" % id)
	for id in GameData.class_order:
		check(colors.has("class_" + id), "class %s's color in ui_style.json" % id)
		check_eq(Color(String(GameData.class_info(id).color)), UIStyle.class_color(id), "%s: one color everywhere" % id)
	for id in GameData.habitat_order:
		check(colors.has("habitat_" + id), "habitat %s's color in ui_style.json" % id)
		check_eq(Color(String(GameData.habitats[id].color)), UIStyle.habitat_color(id), "%s: one color everywhere" % id)
	# No other data file keeps its own copy.
	for file_name in ["rarities.json", "classes.json", "habitats.json", "sorting.json"]:
		var text := FileAccess.get_file_as_string("res://data/" + file_name)
		check(not text.contains("\"color\""), "%s has no colors of its own" % file_name)
	# The home screen's palette reads from it too.
	check_eq(UIKit.PANEL, UIStyle.color("kit_panel"), "UIKit's panels come from ui_style.json")
	check_eq(UIKit.BG_TOP, UIStyle.color("kit_bg_top"), "and its backdrop")
	check_eq(UIKit.GREY, UIStyle.color("kit_grey"), "and its gray")


func test_colors_are_solid() -> void:
	# Every color is fully solid: nothing see-through, nothing to fade out.
	for key in GameData.ui_style.colors:
		if String(key).begins_with("_"):
			continue
		var text := String(GameData.ui_style.colors[key])
		check(text.length() == 7, "%s is a solid #rrggbb color (%s)" % [key, text])
		check_eq(Color(text).a, 1.0, "%s is solid" % key)


func test_colors_are_bold_and_text_reads() -> void:
	# Bold: the color pieces are saturated, and the home screen's panels
	# stand out from its backdrop. Disabled stays a muted gray, but solid.
	for key in ["primary", "secondary", "danger", "tool", "gold", "player", "enemy", "kit_panel", "kit_blue", "kit_green", "kit_red",
			"rarity_rare", "rarity_epic", "rarity_legendary", "rarity_mythic"]:
		check(UIStyle.color(key).s >= 0.55, "%s is saturated (%.2f)" % [key, UIStyle.color(key).s])
	for id in GameData.class_order:
		check(UIStyle.class_color(id).s >= 0.55, "class %s is saturated" % id)
	check(UIStyle.color("disabled").s < 0.3, "disabled is muted")
	check(UIStyle.color("kit_grey").s < 0.3, "the home screen's gray is muted")
	var top := UIStyle.color("kit_bg_top")
	var bottom := UIStyle.color("kit_bg_bottom")
	var panel := UIStyle.color("kit_panel")
	check(panel.v < bottom.v and panel.v < top.v - 0.1, "panels sit darker than the backdrop, so they stand out")
	check(panel.lightened(float(GameData.ui_style.kit.rim_light)).v - panel.v >= 0.1, "and a bright rim round each")
	# Text: plain text reads on the panels and bars it sits on; outlined
	# text has a dark outline far from its fill.
	for back in ["kit_panel", "kit_panel_dark", "kit_deep", "toast"]:
		for fore in ["kit_text", "kit_text_dim"]:
			var ratio := _contrast(UIStyle.color(fore), UIStyle.color(back))
			check(ratio >= 4.5, "%s text reads on %s (%.1f:1)" % [fore, back, ratio])
	check(_contrast(UIStyle.color("text"), UIStyle.color("outline")) >= 12.0, "outlined text: white on a dark outline")
	check(_contrast(UIKit.TEXT, UIKit.INK) >= 12.0, "home screen text: white on a dark outline")


func test_a_still_card_draws_once() -> void:
	# Only Epic, Legendary and Mythic cards move; the rest never freeze
	# mid-sweep with a pale stripe across the picture.
	var tree := Engine.get_main_loop() as SceneTree
	var host: Node = tree.root.get_child(tree.root.get_child_count() - 1)
	var saved: Dictionary = Profile.data.duplicate(true)
	var auto := Profile.autosave
	Profile.autosave = false
	for id in ["brown_bear", "lion", "tiger", "black_rhino", "dragon"]:
		Profile.data.collection[id] = {"level": 5, "copies": 0, "new": false}
	for id in ["brown_bear", "lion", "tiger", "black_rhino", "dragon"]:
		var card := AnimalCard.create(id)
		host.add_child(card)
		var moves: bool = GameData.cards[id].rarity in ["epic", "legendary", "mythic"]
		check_eq(card.is_processing(), moves, "%s (%s) %s" % [id, GameData.cards[id].rarity, "moves" if moves else "is drawn once"])
		card.free()
	Profile.data = saved
	Profile.autosave = auto


func test_locked_arenas_are_solid_and_muted() -> void:
	var road := TrophyRoad.create()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.get_child(tree.root.get_child_count() - 1).add_child(road)
	var tinted := 0
	for node in road.find_children("*", "ArenaPreview", true, false):
		var preview := node as CanvasItem
		check_eq(preview.modulate.a, 1.0, "an arena picture is never see-through")
		if preview.modulate != Color.WHITE:
			tinted += 1
			check_eq(preview.modulate, UIStyle.color("locked_tint"), "an arena ahead: solid, muted tones")
	check_eq(tinted, GameData.arenas.size() - 1 - Profile.highest_arena(), "every arena not reached yet, and only those")
	road.free()
