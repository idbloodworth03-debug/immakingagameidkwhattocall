extends Control
## Battle tab (the home screen): a window onto your arena, the Draft Duel
## button (it opens your deck first) and the four cage slots.

const DECK_SCENE := "res://scenes/deck.tscn"

var _arena_holder: PanelContainer
var _slots_row: HBoxContainer
var _slot_keys: Array = []          # what each slot showed last time
var _slot_status_labels: Array = []


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)

	var column := UIKit.vbox(14)
	margin.add_child(column)

	var logo := TextureRect.new()
	logo.texture = load("res://art/logo/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, 118)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(logo)

	_arena_holder = PanelContainer.new()
	_arena_holder.add_theme_stylebox_override("panel", UIKit.raised(UIKit.PANEL, 24, 8))
	_arena_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_arena_holder)
	UIKit.on_tap(_arena_holder, func() -> void: Modal.open(TrophyRoad.create(), "Trophy Road"))

	var battle := UIKit.button("DRAFT DUEL", UIKit.YELLOW, 50, Vector2(460, 118))
	battle.icon = UIKit.icon(GameData.ui_icon("tab_battle"))
	battle.add_theme_constant_override("icon_max_width", 58)
	battle.add_theme_constant_override("h_separation", 14)
	# Every match starts with your deck of 8 (filled with your last one).
	battle.pressed.connect(func() -> void: Transition.go(DECK_SCENE))
	battle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(battle)
	# A gentle pulse so the main button invites a tap.
	battle.resized.connect(func() -> void: battle.pivot_offset = battle.size / 2.0)
	var pulse := battle.create_tween().set_loops()
	pulse.tween_property(battle, "scale", Vector2(1.03, 1.03), 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(battle, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)
	column.add_child(UIKit.label("Pick 3 a round from your deck. First to 4 wins.", 20, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))

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


## The current arena: a window onto it, its name, and your trophies toward
## the next one.
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

	var window := PanelContainer.new()
	var frame := UIKit.box(Color(arena.color).darkened(0.5), 18, 0)
	window.add_theme_stylebox_override("panel", frame)
	window.size_flags_vertical = Control.SIZE_EXPAND_FILL
	window.custom_minimum_size = Vector2(0, 230)
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	column.add_child(window)
	if BattleField.arena_art(arena.id).is_empty():
		var art := ArenaArt.new()
		art.arena_id = arena.id
		window.add_child(art)
	else:
		var preview := ArenaPreview.new()
		preview.animate = true
		preview.arena_id = arena.id
		window.add_child(preview)
	var overlay := MarginContainer.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		overlay.add_theme_constant_override("margin_" + side, 12)
	window.add_child(overlay)
	var stack := UIKit.vbox(0)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(stack)
	var chip := PanelContainer.new()
	var chip_style := UIKit.box(Color(UIKit.INK, 0.65), 14, 4)
	chip_style.content_margin_left = 12
	chip_style.content_margin_right = 12
	chip.add_theme_stylebox_override("panel", chip_style)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(UIKit.label("Arena %d" % (index + 1), 20, UIKit.TEXT_DIM))
	stack.add_child(chip)
	stack.add_child(UIKit.spacer())
	var name_label := UIKit.label(arena.name, 46, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.add_theme_constant_override("outline_size", 10)
	stack.add_child(name_label)
	stack.add_child(UIKit.label("Tap for the Trophy Road", 17, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))

	var trophy_row := UIKit.hbox(12)
	trophy_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(trophy_row)
	trophy_row.add_child(UIKit.pill(GameData.ui_icon("trophy"), UIKit.TROPHY, UIKit.format_number(trophies)))
	# The arena's boss guards the way up: show who's next.
	var boss_next := Opponents.is_boss_match(trophies, Profile.bosses_beaten())
	var boss: Dictionary = GameData.rivals_in_arena(index, true)[0] if boss_next else {}
	if boss_next:
		trophy_row.add_child(RangerPortrait.create(boss, 52))
	if index + 1 < GameData.arenas.size():
		var next_at := int(GameData.arenas[index + 1].min_trophies)
		var start_at := int(arena.min_trophies)
		var bar_text := "Boss next: %s" % boss.name if boss_next else "Next arena at %s" % UIKit.format_number(next_at)
		var bar := UIKit.progress(float(trophies - start_at) / float(next_at - start_at),
				bar_text, UIKit.GOLD.darkened(0.25) if boss_next else UIKit.TROPHY.darkened(0.2), 34)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trophy_row.add_child(bar)
	elif boss_next:
		trophy_row.add_child(UIKit.label("Boss next: %s" % boss.name, 22, UIKit.GOLD))


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

	var view := PanelContainer.new()
	var style := UIKit.inset(UIKit.PANEL_DARK, 18, 8) if state == "empty" else UIKit.raised(UIKit.PANEL_DARK, 18, 8)
	if state == "ready":
		style.set_border_width_all(4)
		style.border_color = UIKit.YELLOW
		style.shadow_color = Color(UIKit.YELLOW, 0.45)
		style.shadow_size = 10
		style.shadow_offset = Vector2.ZERO
	view.add_theme_stylebox_override("panel", style)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size = Vector2(0, 168)

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

	if state == "ready":
		# A ready cage hops now and then to say "open me".
		art.resized.connect(func() -> void: art.pivot_offset = Vector2(art.size.x / 2.0, art.size.y))
		var hop := art.create_tween().set_loops()
		hop.tween_interval(1.2)
		hop.tween_property(art, "scale", Vector2(1.1, 0.9), 0.1)
		hop.tween_property(art, "scale", Vector2(0.95, 1.08), 0.12)
		hop.tween_property(art, "scale", Vector2.ONE, 0.15)
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
