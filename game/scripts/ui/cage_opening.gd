class_name CageOpening
extends Control
## Full-screen "free the animals" sequence after opening a cage.
## Tap to reveal the rewards one at a time, then see a summary.

signal finished

var rewards: Dictionary = {}
var _steps: Array = []   # what to reveal, in order
var _step := -1
var _stage: VBoxContainer
var _counter: Label


static func play(cage_rewards: Dictionary) -> CageOpening:
	var opening := CageOpening.new()
	opening.rewards = cage_rewards
	var tree := Engine.get_main_loop() as SceneTree
	var layer := tree.get_first_node_in_group("popup_layer")
	(layer if layer else tree.current_scene).add_child(opening)
	return opening


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var background := ColorRect.new()
	background.color = Color(0.04, 0.08, 0.16)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var column := UIKit.vbox(24)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_top = 120
	column.offset_bottom = -80
	column.offset_left = 30
	column.offset_right = -30
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	var cage: Dictionary = GameData.cages.get(rewards.get("cage_id", ""), {})
	column.add_child(UIKit.label(cage.get("name", "Cage"), 44, UIKit.YELLOW, HORIZONTAL_ALIGNMENT_CENTER))
	_counter = UIKit.label("", 26, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(_counter)

	_stage = UIKit.vbox(18)
	_stage.alignment = BoxContainer.ALIGNMENT_CENTER
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_stage)

	if int(rewards.get("gold", 0)) > 0:
		_steps.append({"kind": "gold"})
	if int(rewards.get("gems", 0)) > 0:
		_steps.append({"kind": "gems"})
	for stack in rewards.get("cards", []):
		_steps.append({"kind": "card", "stack": stack})

	_show_closed_cage(cage)
	UIKit.on_tap(self, _next)
	Sound.play("rattle")


func _show_closed_cage(cage: Dictionary) -> void:
	var art := IconArt.new()
	art.shape = IconArt.Shape.CAGE
	art.color = Color(cage.get("color", "#a27447"))
	art.custom_minimum_size = Vector2(320, 300)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stage.add_child(art)
	_stage.add_child(UIKit.label("Tap to free the animals!", 30, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	_counter.text = "%d animals inside" % _total_cards()
	var tween := art.create_tween().set_loops()
	tween.tween_property(art, "rotation", 0.04, 0.12)
	tween.tween_property(art, "rotation", -0.04, 0.12)
	tween.tween_property(art, "rotation", 0.0, 0.12)
	tween.tween_interval(0.8)
	art.resized.connect(func() -> void: art.pivot_offset = art.size / 2.0)


func _next() -> void:
	_step += 1
	_clear_stage()
	if _step < _steps.size():
		_show_step(_steps[_step])
	elif _step == _steps.size():
		_show_summary()
	else:
		finished.emit()
		queue_free()


func _clear_stage() -> void:
	for child in _stage.get_children():
		_stage.remove_child(child)
		child.queue_free()


func _show_step(step: Dictionary) -> void:
	var item: Control
	match step.kind:
		"gold":
			item = _big_reward(GameData.ui_icon("gold"), UIKit.GOLD, "+%s Gold" % UIKit.format_number(int(rewards.gold)), UIKit.GOLD)
			Sound.play("coin")
		"gems":
			item = _big_reward(GameData.ui_icon("gems"), UIKit.GEMS, "+%d Gems" % int(rewards.gems), UIKit.GEMS)
			Sound.play("coin")
		"card":
			item = _card_reward(step.stack)
			Sound.play("new_card" if step.stack.get("is_new", false) else "reveal")
	_stage.add_child(item)
	_counter.text = "%d left" % (_steps.size() - _step - 1)
	_pop_in(item)


func _big_reward(icon_name: String, color: Color, text: String, text_color: Color) -> Control:
	var box := UIKit.vbox(16)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := UIKit.icon_rect(icon_name, color, 200)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	box.add_child(UIKit.label(text, 44, text_color, HORIZONTAL_ALIGNMENT_CENTER))
	return box


func _card_reward(stack: Dictionary) -> Control:
	var animal := GameData.get_card(stack.animal)
	var box := UIKit.vbox(14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if stack.get("is_new", false):
		box.add_child(UIKit.label("NEW ANIMAL FREED!", 34, UIKit.YELLOW, HORIZONTAL_ALIGNMENT_CENTER))
	# The card glows in its rarity color.
	var glow := PanelContainer.new()
	var glow_style := UIKit.box(Color(0, 0, 0, 0), 30)
	glow_style.shadow_color = Color(GameData.rarity_color(stack.rarity), 0.7)
	glow_style.shadow_size = 40
	glow.add_theme_stylebox_override("panel", glow_style)
	glow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(glow)
	var art := UIKit.card_art(stack.animal)
	art.custom_minimum_size = Vector2(260, 300)
	glow.add_child(art)
	box.add_child(UIKit.label(animal.name, 40, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UIKit.label(GameData.rarity_name(stack.rarity), 30, GameData.rarity_color(stack.rarity), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UIKit.label("x%d" % int(stack.count), 48, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	return box


func _show_summary() -> void:
	_counter.text = "All animals freed!"
	var summary := UIKit.vbox(18)
	summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(summary)
	var totals := UIKit.hbox(30)
	totals.alignment = BoxContainer.ALIGNMENT_CENTER
	summary.add_child(totals)
	if int(rewards.get("gold", 0)) > 0:
		totals.add_child(UIKit.pill(GameData.ui_icon("gold"), UIKit.GOLD, UIKit.format_number(int(rewards.gold))))
	if int(rewards.get("gems", 0)) > 0:
		totals.add_child(UIKit.pill(GameData.ui_icon("gems"), UIKit.GEMS, str(int(rewards.gems))))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	summary.add_child(grid)
	for stack in rewards.get("cards", []):
		var cell := UIKit.vbox(2)
		var card := AnimalCard.create(stack.animal, true)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(card)
		cell.add_child(UIKit.label("x%d" % int(stack.count), 24, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		grid.add_child(cell)
	summary.add_child(UIKit.label("Tap to continue", 26, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))


func _pop_in(control: Control) -> void:
	control.modulate.a = 0.0
	control.scale = Vector2(0.6, 0.6)
	control.resized.connect(func() -> void: control.pivot_offset = control.size / 2.0)
	var tween := control.create_tween().set_parallel()
	tween.tween_property(control, "modulate:a", 1.0, 0.15)
	tween.tween_property(control, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _total_cards() -> int:
	var total := 0
	for stack in rewards.get("cards", []):
		total += int(stack.count)
	return total
