extends TestCase
## Hold for info (scripts/autoload/hold_info.gd, scripts/ui/info_pop.gd):
## holding any card, or an animal on the battlefield, shows its info; the
## release that ends a hold isn't a tap.

var _made: Array = []


## Somewhere in the scene tree to put test nodes: the test runner itself (the
## tree's root is still setting up while the tests run).
func _host() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_child(tree.root.get_child_count() - 1)


func cleanup() -> void:
	HoldInfo.hide_pop()
	for node in _made:
		if is_instance_valid(node):
			node.free()
	_made.clear()


func test_the_bars_read_the_card() -> void:
	var bear := InfoPop.bars("brown_bear", 1)
	var squirrel := InfoPop.bars("gray_squirrel", 1)
	var cobra := InfoPop.bars("king_cobra", 3)
	for key in ["health", "damage", "speed", "range"]:
		check(float(bear[key]) > 0.0 and float(bear[key]) <= 1.0, "%s bar between 0 and 1" % key)
	check(float(bear.health) > float(squirrel.health), "a Tank is tougher than a squad of squirrels")
	check(float(squirrel.range) > float(bear.range), "Ranged reach further than a Tank")
	check(float(cobra.range) > float(squirrel.range), "the sniping Cobra reaches furthest")
	check(float(InfoPop.bars("peregrine_falcon", 1).speed) > float(bear.speed), "a Falcon is faster than a Bear")
	check(float(InfoPop.bars("brown_bear", 5).health) > float(bear.health), "a higher level is tougher")


func test_holding_a_card_finds_it() -> void:
	var card := AnimalCard.create("red_fox")
	_made.append(card)
	_host().add_child(card)
	card.position = Vector2(100, 200)
	card.size = AnimalCard.SIZE_NORMAL
	var target := HoldInfo.target_at(card.get_global_rect().get_center())
	check_eq(String(target.get("id", "")), "red_fox", "the card under the finger")
	check(HoldInfo.target_at(Vector2(4, 4)).is_empty(), "nothing where there's no card")


func test_a_hold_shows_the_popup_and_its_release_is_no_tap() -> void:
	var card := AnimalCard.create("brown_bear")
	_made.append(card)
	_host().add_child(card)
	card.position = Vector2(200, 600)
	card.size = AnimalCard.SIZE_NORMAL
	HoldInfo._show_at(card.get_global_rect().get_center())
	var pop := HoldInfo.showing()
	check(pop != null, "a popup shows")
	if pop != null:
		check_eq(pop.card_id, "brown_bear", "for the card held")
		check(pop.position.y + pop.size.y <= card.get_global_rect().get_center().y, "above the finger")
		check(pop.mouse_filter == Control.MOUSE_FILTER_IGNORE, "it doesn't block anything")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	HoldInfo._input(release)
	check(HoldInfo.showing() == null, "letting go hides it")
	check(HoldInfo.just_held(), "and that release isn't a tap")


func test_holding_an_animal_on_the_battlefield() -> void:
	var field := BattleField.new()
	_made.append(field)
	_host().add_child(field)
	field.size = Vector2(720, 1080)
	var sim := BattleSim.new([{}, {}], 1)
	field.sim = sim
	field.blend = 1.0
	var bear: BattleSim.Fighter = sim.spawn(0, "brown_bear", 8 * BattleSim.TILE, 11 * BattleSim.TILE)[0]
	field._process(1.0 / 60.0)
	field._process(1.0 / 60.0)
	var view := field.view_for_uid(bear.uid)
	check(view != null, "the bear is drawn")
	if view != null:
		var middle: Vector2 = view.get_global_transform_with_canvas() * (view.body.position - Vector2(0, UnitSprites.top(view.id) * view.body.k * 0.5))
		var found := field.view_at(middle)
		check(found == view, "holding the bear finds it")
		var target := HoldInfo.target_at(middle)
		check_eq(String(target.get("id", "")), "brown_bear", "and the info is the bear's")
