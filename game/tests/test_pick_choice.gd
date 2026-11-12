extends TestCase
## The choice you get by picking an animal already in your army (scripts/
## draft/draft_screen.gd _army_choice): its name, "Upgrade it, or add
## more?", and the two buttons, Upgrade and "+N More" (N: a full group of
## it). Its panel fits a phone's width whatever the animal is called.

const SCREEN_WIDTH := 720.0
const MARGIN := 16.0

var _made: Array = []


func _host() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_child(tree.root.get_child_count() - 1)


func cleanup() -> void:
	for node in _made:
		if is_instance_valid(node):
			node.free()
	_made.clear()


## The choice for `id` in its panel, in the tree with the game's theme.
func _choice(id: String, can_up := true, can_more := true) -> Dictionary:
	var screen: Control = load("res://scripts/draft/draft_screen.gd").new()
	_made.append(screen)
	var frame := Control.new()
	frame.theme = UIStyle.theme()
	_made.push_front(frame)
	_host().add_child(frame)
	var choice: Dictionary = screen._army_choice(id, can_up, can_more)
	var panel := UIStyle.panel(choice.box)
	frame.add_child(panel)
	choice["panel"] = panel
	return choice


func _texts(choice: Dictionary) -> Array:
	var out := []
	for label: Label in (choice.box as Control).find_children("*", "Label", true, false):
		out.append(label.text)
	return out


func test_the_choice_fits_the_screen_whatever_the_animal_is_called() -> void:
	var widest := 0.0
	var who := ""
	var count := 0
	for id in GameData.card_order:
		if GameData.is_tool(id):
			continue
		count += 1
		var choice := _choice(id)
		var wide: float = (choice.panel as Control).get_combined_minimum_size().x
		if wide > widest:
			widest = wide
			who = id
		cleanup()
	check(count >= 35, "every animal tried (%d)" % count)
	check(widest > 0.0 and widest <= SCREEN_WIDTH - 2.0 * MARGIN, "the widest choice (%s) fits a phone's width with a margin (%d of %d pixels)" % [who, widest, SCREEN_WIDTH])


func test_the_choice_names_the_animal_and_both_ways() -> void:
	var squirrels := _choice("gray_squirrel")
	var texts := _texts(squirrels)
	check(texts.has("Gray Squirrel"), "the animal's name")
	check(texts.has("Upgrade it, or add more?"), "the question")
	check(texts.has("Upgrade"), "an Upgrade button")
	check(texts.has("+6 More"), "and more of it: a full group of Squirrels (%s)" % str(texts))
	check(_texts(_choice("asian_elephant")).has("+2 More"), "two more Elephants")
	check(not squirrels.up.disabled and not squirrels.more.disabled, "both can be pressed")


func test_a_way_that_is_not_open_is_switched_off() -> void:
	var trained := _choice("brown_bear", false, true)
	check(trained.up.disabled and not trained.more.disabled, "fully trained: only more of it")
	var full := _choice("brown_bear", true, false)
	check(not full.up.disabled and full.more.disabled, "army full: only the upgrade")
