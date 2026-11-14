extends Control
## Battle tab (the home screen): the game's sign, your squad standing in
## your arena (SquadStage: your deck's animals as live toys; tap one and it
## celebrates), your trophies toward the next arena (tap for the Trophy
## Road), the Draft Duel button (it opens the bans first once you own enough
## animals, then your deck) and the four cage slots. Sizes: feel.json "menu".

const DECK_SCENE := "res://scenes/deck.tscn"
const BAN_SCENE := "res://scenes/ban.tscn"
const C := "menu"

var _arena_holder: PanelContainer
var _slots_row: HBoxContainer
var _slot_keys: Array = []          # what each slot showed last time
var _slot_status_labels: Array = []
## What the arena panel shows now (the arena, the deck, the trophies): it
## is only rebuilt when one of them changes, so the squad isn't loaded anew
## for a change of gold.
var _arena_key := ""
var squad: SquadStage


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	margin.add_theme_constant_override("margin_top", 10)
	add_child(margin)

	var column := UIKit.vbox(12)
	margin.add_child(column)
	column.add_child(_logo())

	_arena_holder = PanelContainer.new()
	_arena_holder.add_theme_stylebox_override("panel", UIKit.raised(UIKit.PANEL, 24, 8))
	_arena_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_arena_holder)

	var battle := UIKit.button("DRAFT DUEL", UIKit.YELLOW, 54, Vector2(500, 124))
	battle.icon = MenuArt.texture("tab_battle") if MenuArt.has("tab_battle") else UIKit.icon(GameData.ui_icon("tab_battle"))
	battle.expand_icon = true
	battle.add_theme_constant_override("icon_max_width", 92)
	battle.add_theme_constant_override("h_separation", 10)
	battle.add_theme_constant_override("outline_size", 12)
	# Every match starts with the bans (once you own enough animals), then
	# your deck of 8 (filled with your last one).
	battle.pressed.connect(func() -> void:
		MatchPlan.clear()
		var owned := GameData.card_order.filter(func(id): return Profile.has_card(id) and not GameData.is_tool(id)).size()
		Transition.go(BAN_SCENE if BanPhase.unlocked(owned) else DECK_SCENE))
	battle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(battle)
	# A gentle pulse so the main button invites a tap.
	battle.resized.connect(func() -> void: battle.pivot_offset = battle.size / 2.0)
	var pulse := battle.create_tween().set_loops()
	var breathe := 1.0 + Feel.num("ui", "breathe_amount", 0.03)
	var seconds := Feel.num("ui", "breathe_seconds", 1.8) / 2.0
	pulse.tween_property(battle, "scale", Vector2(breathe, breathe), seconds).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(battle, "scale", Vector2.ONE, seconds).set_trans(Tween.TRANS_SINE)
	column.add_child(UIKit.label("Pick 3 a round from your deck. First to 4 wins.", 22, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))

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


## The game's name on a trail sign, swinging a little on its nails.
func _logo() -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(0, Feel.num(C, "logo_height", 92.0))
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plank := PanelContainer.new()
	var skin := SkinBox.make("sign", UIStyle.color("sign").lightened(0.12))
	skin.content_margin_left = 44
	skin.content_margin_right = 44
	skin.content_margin_top = 0
	skin.content_margin_bottom = 10
	plank.add_theme_stylebox_override("panel", skin)
	plank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := UIKit.label("DEN DUEL", int(Feel.num(C, "logo_size", 64.0)), UIKit.YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_constant_override("shadow_offset_y", 5)
	plank.add_child(title)
	holder.add_child(plank)
	# It swings a touch, like a sign in a breeze.
	plank.resized.connect(func() -> void: plank.pivot_offset = Vector2(plank.size.x / 2.0, 0.0))
	var swing := Feel.num(C, "logo_swing_degrees", 1.4)
	if swing > 0.0:
		plank.rotation_degrees = -swing
		var sway := plank.create_tween().set_loops()
		var seconds := Feel.num(C, "logo_swing_seconds", 3.2) / 2.0
		sway.tween_property(plank, "rotation_degrees", swing, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sway.tween_property(plank, "rotation_degrees", -swing, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return holder


## The current arena: your squad standing in it, its name, and your
## trophies toward the next one.
func _build_arena() -> void:
	var index := Profile.arena_index()
	var arena := GameData.get_arena(index)
	var trophies := Profile.get_trophies()
	var deck: Array = Profile.get_deck()
	var key := "%s|%s|%d|%s" % [arena.id, ",".join(deck), trophies, str(Profile.bosses_beaten())]
	if key == _arena_key:
		return
	_arena_key = key
	for child in _arena_holder.get_children():
		_arena_holder.remove_child(child)
		child.queue_free()

	var column := UIKit.vbox(8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena_holder.add_child(column)

	var window := PanelContainer.new()
	var frame := UIKit.box(UIKit.INK, 20, 0)
	window.add_theme_stylebox_override("panel", frame)
	window.size_flags_vertical = Control.SIZE_EXPAND_FILL
	window.custom_minimum_size = Vector2(0, 230)
	window.mouse_filter = Control.MOUSE_FILTER_PASS
	window.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	column.add_child(window)
	squad = SquadStage.make(deck, String(arena.get("stage", "forest")))
	window.add_child(squad)

	# Over the scene: which arena this is, on a sign you can tap for the
	# Trophy Road.
	var overlay := MarginContainer.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		overlay.add_theme_constant_override("margin_" + side, 10)
	window.add_child(overlay)
	var stack := UIKit.vbox(0)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(stack)
	var sign_holder := PanelContainer.new()
	sign_holder.add_theme_stylebox_override("panel", UIStyle.sign_box())
	sign_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sign_row := UIKit.hbox(10)
	sign_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign_holder.add_child(sign_row)
	var number := PanelContainer.new()
	var number_style := UIKit.box(UIKit.DEEP, 12, 2)
	number_style.content_margin_left = 10
	number_style.content_margin_right = 10
	number.add_theme_stylebox_override("panel", number_style)
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number.add_child(UIKit.label("Arena %d" % (index + 1), 20, UIKit.TEXT_DIM))
	sign_row.add_child(number)
	var name_label := UIKit.label(arena.name, 34, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.add_theme_constant_override("outline_size", 9)
	sign_row.add_child(name_label)
	# (Along the bottom, on the grass in front of the squad: the fliers
	# hover at the top.)
	stack.add_child(UIKit.spacer())
	stack.add_child(sign_holder)
	UIKit.on_tap(sign_holder, _open_trophy_road)

	var trophy_row := UIKit.hbox(12)
	column.add_child(trophy_row)
	UIKit.on_tap(trophy_row, _open_trophy_road)
	var pill := UIKit.pill(GameData.ui_icon("trophy"), UIKit.TROPHY, UIKit.format_number(trophies))
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trophy_row.add_child(pill)
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
				bar_text, UIKit.GOLD if boss_next else UIKit.TROPHY, 38)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trophy_row.add_child(bar)
	elif boss_next:
		trophy_row.add_child(UIKit.label("Boss next: %s" % boss.name, 22, UIKit.GOLD))


func _open_trophy_road() -> void:
	Modal.open(TrophyRoad.create(), "Trophy Road")


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
	if keys == _slot_keys and not _slot_status_labels.is_empty():
		return
	_slot_keys = keys
	_slot_status_labels.clear()
	for child in _slots_row.get_children():
		_slots_row.remove_child(child)
		child.queue_free()
	for i in keys.size():
		_slots_row.add_child(_slot_view(i))


## A cage slot: a shelf of wood with its toy cage on it (an empty slot: a
## sunken one with a gray cage), the cage's name and what it's doing.
func _slot_view(slot: int) -> Control:
	var state := Profile.cage_slot_state(slot)
	var entry: Variant = Profile.cage_slot(slot)
	var cage: Dictionary = GameData.cages.get(entry.cage_id, {}) if entry != null else {}

	var view := PanelContainer.new()
	var style := UIKit.inset(UIKit.PANEL_DARK, 18, 6) if state == "empty" else UIKit.raised(UIKit.PANEL, 18, 6)
	if state == "ready":
		style.set_border_width_all(5)
		style.border_color = UIStyle.color("selected")
		style.glow = true
	view.add_theme_stylebox_override("panel", style)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size = Vector2(0, Feel.num(C, "slot_height", 178.0))

	var column := UIKit.vbox(0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(column)
	var art := IconArt.new()
	art.shape = IconArt.Shape.CAGE
	art.custom_minimum_size = Vector2(0, 96)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(art)

	var title := UIKit.label("", 18, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	title.clip_text = true
	title.add_theme_constant_override("outline_size", 5)
	column.add_child(title)
	var status := UIKit.label("", 20, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	status.add_theme_constant_override("outline_size", 5)
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

	if state == "ready" or state == "unlocking":
		# A cage that's ready hops now and then to say "open me"; one being
		# unlocked rattles a little (someone wants out).
		art.resized.connect(func() -> void: art.pivot_offset = Vector2(art.size.x / 2.0, art.size.y))
		var hop := art.create_tween().set_loops()
		if state == "ready":
			hop.tween_interval(1.2)
			hop.tween_property(art, "scale", Vector2(1.1, 0.9), 0.1)
			hop.tween_property(art, "scale", Vector2(0.95, 1.08), 0.12)
			hop.tween_property(art, "scale", Vector2.ONE, 0.15)
		else:
			hop.tween_interval(2.6)
			for turn in [-3.0, 3.0, -2.0, 2.0, 0.0]:
				hop.tween_property(art, "rotation_degrees", turn, 0.06)
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
	var skip := UIKit.button("Open now\n%d gems" % skip_cost, UIKit.GEMS.darkened(0.12), 24, Vector2(240, 80))
	skip.pressed.connect(func() -> void:
		if Profile.skip_cage_unlock(slot):
			modal.close()
			CageOpening.play(Profile.open_cage_slot(slot))
		else:
			UIKit.error_toast("Not enough gems")
	)
	row.add_child(skip)
