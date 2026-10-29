extends Control
## Battle tab (the home screen): current arena, the Battle button and the
## four cage slots.

const BATTLE_SCENE := "res://scenes/battle.tscn"

var _arena_holder: PanelContainer
var _slots_row: HBoxContainer
var _slot_keys: Array = []          # what each slot showed last time
var _slot_status_labels: Array = []


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)

	var column := UIKit.vbox(18)
	margin.add_child(column)

	var logo := TextureRect.new()
	logo.texture = load("res://art/logo/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, 150)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(logo)

	_arena_holder = PanelContainer.new()
	_arena_holder.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_arena_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_arena_holder)
	UIKit.on_tap(_arena_holder, func() -> void: Modal.open(TrophyRoad.create(), "Trophy Road"))

	var battle := UIKit.button("BATTLE", UIKit.YELLOW, 52, Vector2(440, 130))
	battle.add_theme_color_override("font_color", Color.WHITE)
	battle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	battle.pressed.connect(func() -> void: get_tree().change_scene_to_file(BATTLE_SCENE))
	column.add_child(battle)
	# A gentle pulse so the Battle button invites a tap.
	var pulse := battle.create_tween().set_loops()
	pulse.tween_property(battle, "scale", Vector2(1.04, 1.04), 0.8).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(battle, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)
	column.add_child(UIKit.label("Practice against a computer opponent. Online matches come later.", 18, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))

	_slots_row = UIKit.hbox(10)
	column.add_child(_slots_row)

	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_refresh_slots)
	add_child(timer)

	Profile.changed.connect(refresh)
	refresh()


func refresh() -> void:
	_build_arena()
	_refresh_slots(true)


func _build_arena() -> void:
	for child in _arena_holder.get_children():
		_arena_holder.remove_child(child)
		child.queue_free()
	var index := Profile.arena_index()
	var arena := GameData.get_arena(index)
	var trophies := Profile.get_trophies()

	var column := UIKit.vbox(8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena_holder.add_child(column)
	column.add_child(UIKit.label("Arena %d" % (index + 1), 24, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(UIKit.label(arena.name, 44, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))

	var art := ArenaArt.new()
	art.arena_id = arena.id
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.custom_minimum_size = Vector2(0, 200)
	column.add_child(art)

	var trophy_row := UIKit.hbox(12)
	trophy_row.alignment = BoxContainer.ALIGNMENT_CENTER
	trophy_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(trophy_row)
	trophy_row.add_child(UIKit.pill(GameData.ui_icon("trophy"), UIKit.TROPHY, UIKit.format_number(trophies)))
	if index + 1 < GameData.arenas.size():
		var next_at := int(GameData.arenas[index + 1].min_trophies)
		var start_at := int(arena.min_trophies)
		var bar := UIKit.progress(float(trophies - start_at) / float(next_at - start_at),
				"Next arena at %s" % UIKit.format_number(next_at), UIKit.TROPHY.darkened(0.25), 34)
		bar.custom_minimum_size.x = 380
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trophy_row.add_child(bar)
	column.add_child(UIKit.label("Tap the arena to see the Trophy Road", 18, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))


## Rebuilds the slots when a cage arrives, starts or finishes unlocking.
## Otherwise (every second) it just updates the countdown text, so a tap in
## progress isn't lost to a rebuild.
func _refresh_slots(force := false) -> void:
	var keys := []
	for i in Profile.data.cage_slots.size():
		var entry: Variant = Profile.cage_slot(i)
		keys.append(Profile.cage_slot_state(i) + ":" + (String(entry.cage_id) if entry != null else ""))
	if not force and keys == _slot_keys:
		for i in keys.size():
			if Profile.cage_slot_state(i) == "unlocking":
				_slot_status_labels[i].text = UIKit.format_duration(Profile.cage_seconds_left(i))
		return
	_slot_keys = keys
	_slot_status_labels.clear()
	for child in _slots_row.get_children():
		_slots_row.remove_child(child)
		child.queue_free()
	for i in keys.size():
		_slots_row.add_child(_slot_view(i))


func _slot_view(slot: int) -> Control:
	var state := Profile.cage_slot_state(slot)
	var entry: Variant = Profile.cage_slot(slot)
	var cage: Dictionary = GameData.cages.get(entry.cage_id, {}) if entry != null else {}

	var view := UIKit.panel(UIKit.PANEL_DARK, 8, 14)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size = Vector2(0, 170)
	if state == "ready":
		var style := UIKit.box(UIKit.PANEL_DARK, 14, 8)
		style.set_border_width_all(4)
		style.border_color = UIKit.YELLOW
		view.add_theme_stylebox_override("panel", style)

	var column := UIKit.vbox(4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(column)
	var art := IconArt.new()
	art.shape = IconArt.Shape.CAGE
	art.custom_minimum_size = Vector2(0, 80)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(art)

	var title := UIKit.label("", 16, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	title.clip_text = true
	title.add_theme_constant_override("outline_size", 4)
	column.add_child(title)
	var status := UIKit.label("", 17, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	status.add_theme_constant_override("outline_size", 4)
	column.add_child(status)
	_slot_status_labels.append(status)

	match state:
		"empty":
			art.color = UIKit.GREY
			art.dimmed = true
			title.text = "Empty"
			status.text = "Win to fill"
		"locked":
			art.color = Color(cage.color)
			title.text = cage.name
			status.text = UIKit.format_duration(float(cage.unlock_seconds))
		"unlocking":
			art.color = Color(cage.color)
			title.text = cage.name
			status.text = UIKit.format_duration(Profile.cage_seconds_left(slot))
			status.add_theme_color_override("font_color", UIKit.YELLOW)
		"ready":
			art.color = Color(cage.color)
			title.text = cage.name
			status.text = "OPEN!"
			status.add_theme_color_override("font_color", UIKit.YELLOW)

	UIKit.on_tap(view, func() -> void: _on_slot_tapped(slot))
	return view


func _on_slot_tapped(slot: int) -> void:
	var state := Profile.cage_slot_state(slot)
	if state == "empty":
		UIKit.toast("Win battles to earn cages")
		return
	if state == "ready":
		CageOpening.play(Profile.open_cage_slot(slot))
		return

	var entry: Dictionary = Profile.cage_slot(slot)
	var content := CageInfo.details(entry.cage_id, int(entry.arena))
	var modal := Modal.open(content, GameData.cages[entry.cage_id].name)
	var row := UIKit.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(row)

	if state == "locked":
		var start := UIKit.button("Start unlock", UIKit.GREEN, 24, Vector2(240, 80))
		if Profile.is_any_cage_unlocking():
			start.disabled = true
			start.text = "Another cage\nis unlocking"
		start.pressed.connect(func() -> void:
			Profile.start_cage_unlock(slot)
			modal.close()
		)
		row.add_child(start)

	var skip_cost := Profile.cage_skip_cost(slot)
	var skip := UIKit.button("Open now\n%d gems" % skip_cost, UIKit.GEMS.darkened(0.35), 24, Vector2(240, 80))
	skip.pressed.connect(func() -> void:
		if Profile.skip_cage_unlock(slot):
			modal.close()
			CageOpening.play(Profile.open_cage_slot(slot))
		else:
			UIKit.error_toast("Not enough gems")
	)
	row.add_child(skip)
