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
