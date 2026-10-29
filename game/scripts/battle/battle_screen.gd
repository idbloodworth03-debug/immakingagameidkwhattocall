extends Control
## A battle against the computer opponent: the field, your hand of 4 cards,
## energy, emotes and quick chat. BattleSim runs the rules, BattleBot plays
## the other side and BattleField draws it all.

const MENU_SCENE := "res://scenes/main.tscn"
const OPPONENT_NAMES := ["MossyFox", "RiverOtter42", "SilentOwl", "BadgerBoss", "TundraTom", "ZebraZoe", "CanopyKid", "DuneRunner"]
const OPPONENT_CHATS := ["good_luck", "well_played", "wow", "good_game", "oops"]

var sim: BattleSim
var bot: BattleBot
var opponent: Dictionary = {}
var selected := -1
var opponent_muted := false
var emote_cooldown := 0.0

var _accumulator := 0.0
var _hand_signature := ""
var _result: Dictionary = {}
var _field: BattleField
var _timer_label: Label
var _mode_label: Label
var _towers_label: Label
var _status: Label
var _hand_row: HBoxContainer
var _energy_bar: ProgressBar
var _swap_button: Button
var _emote_panel: PanelContainer
var _bubbles := {}


func _ready() -> void:
	theme = UIKit.build_theme()
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var deck := Profile.get_deck()
	var levels := {}
	var offset_total := 0
	for id in deck:
		levels[id] = Profile.card_level(id)
		offset_total += Profile.card_level(id) - GameData.start_level(GameData.get_card(id).rarity)
	var bot_deck := BattleBot.make_deck(Profile.arena_index(), roundi(float(offset_total) / deck.size()), rng)
	sim = BattleSim.new([deck, bot_deck.deck], [levels, bot_deck.levels], rng.randi())
	bot = BattleBot.new(sim, 1, rng.randi())
	_make_opponent(rng)
	_build()
	_set_status("Tap a card, then tap the glowing area to play it.")
	if rng.randf() < 0.5:
		get_tree().create_timer(1.5).timeout.connect(func() -> void: _opponent_says("good_luck"))


func _process(delta: float) -> void:
	emote_cooldown = maxf(0.0, emote_cooldown - delta)
	if sim.is_over():
		if _result.is_empty():
			_end_battle()
		return
	var tick_length := 1.0 / sim.tps
	_accumulator += delta
	var steps := 0
	while _accumulator >= tick_length and steps < 5 and not sim.is_over():
		bot.update()
		sim.step()
		_handle_events(sim.take_events())
		_accumulator -= tick_length
		steps += 1
	_field.blend = clampf(_accumulator / tick_length, 0.0, 1.0)
	_update_hud()


# --- Building the screen ---------------------------------------------------

func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("#13240f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var column := UIKit.vbox(6)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 8
	column.offset_right = -8
	column.offset_top = 6
	column.offset_bottom = -8
	add_child(column)

	var top := UIKit.hbox(10)
	column.add_child(top)
	top.add_child(PlayerBadge.create(opponent.banner, opponent.icon, opponent.name, opponent.level, true))
	var middle := UIKit.vbox(0)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(middle)
	middle.add_child(UIKit.label("Towers destroyed", 16, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_towers_label = UIKit.label("0 - 0", 30, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	middle.add_child(_towers_label)
	var clock := UIKit.vbox(0)
	top.add_child(clock)
	_mode_label = UIKit.label("Time left", 16, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	clock.add_child(_mode_label)
	_timer_label = UIKit.label("3:00", 32, UIKit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	clock.add_child(_timer_label)

	_field = BattleField.new()
	_field.sim = sim
	_field.grass = Color(GameData.get_arena(Profile.arena_index()).color)
	_field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field.tapped.connect(_on_field_tapped)
	column.add_child(_field)

	_status = UIKit.paragraph("", 19, UIKit.TEXT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size.y = 48
	column.add_child(_status)

	_hand_row = UIKit.hbox(8)
	_hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_hand_row)

	var bottom := UIKit.hbox(8)
	column.add_child(bottom)
	var emote := UIKit.button("Emote", UIKit.BLUE, 20, Vector2(110, 64))
	emote.pressed.connect(func() -> void: _emote_panel.visible = not _emote_panel.visible)
	bottom.add_child(emote)
	_energy_bar = UIKit.progress(0.0, "Energy", UIKit.ENERGY, 40)
	_energy_bar.max_value = float(sim.rules.energy_max)
	_energy_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_energy_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(_energy_bar)
	_swap_button = UIKit.button("Swap", UIKit.GREY, 20, Vector2(100, 64))
	_swap_button.pressed.connect(_on_swap)
	bottom.add_child(_swap_button)
	var leave := UIKit.button("Leave", UIKit.GREY.darkened(0.25), 20, Vector2(100, 64))
	leave.pressed.connect(_on_leave)
	bottom.add_child(leave)

	_emote_panel = _build_emote_panel()
	_emote_panel.visible = false
	add_child(_emote_panel)
	_update_hud()


func _make_opponent(rng: RandomNumberGenerator) -> void:
	var banners := GameData.banners.filter(func(b): return b.unlock.type == "default")
	var icons := GameData.player_icons.filter(func(i): return i.unlock.type == "default")
	opponent = {
		"name": OPPONENT_NAMES[rng.randi_range(0, OPPONENT_NAMES.size() - 1)],
		"trophies": maxi(0, Profile.get_trophies() + rng.randi_range(-80, 80)),
		"banner": banners[rng.randi_range(0, banners.size() - 1)].id,
		"icon": icons[rng.randi_range(0, icons.size() - 1)].id,
		"level": maxi(1, int(Profile.ranger_info().level) + rng.randi_range(-1, 1)),
	}


# --- Every frame -----------------------------------------------------------

func _update_hud() -> void:
	var left := sim.seconds_left()
	_timer_label.text = "%d:%02d" % [floori(left / 60.0), int(left) % 60]
	if sim.in_overtime():
		_mode_label.text = "OVERTIME"
		_mode_label.add_theme_color_override("font_color", UIKit.RED.lightened(0.3))
	elif sim.is_double_energy():
		_mode_label.text = "2x Energy!"
		_mode_label.add_theme_color_override("font_color", UIKit.ENERGY.lightened(0.3))
	_towers_label.text = "%d - %d" % [sim.teams[0].towers_destroyed, sim.teams[1].towers_destroyed]
	_energy_bar.value = sim.energy(0)
	_energy_bar.get_child(0).text = "Energy %d" % floori(sim.energy(0))
	_swap_button.disabled = not sim.can_swap(0)
	if _hand_signature != _make_hand_signature():
		_refresh_hand()


## Changes whenever the hand or which cards are playable changes.
func _make_hand_signature() -> String:
	var parts := [str(selected)]
	for i in sim.hand(0).size():
		var playable := sim.requirement_problems(0, i).is_empty() and sim.energy(0) >= float(GameData.get_card(sim.hand(0)[i]).cost)
		parts.append("%s:%s" % [sim.hand(0)[i], playable])
	parts.append(sim.next_card(0))
	return ",".join(parts)


func _refresh_hand() -> void:
	_hand_signature = _make_hand_signature()
	for child in _hand_row.get_children():
		_hand_row.remove_child(child)
		child.queue_free()
	var hand := sim.hand(0)
	for i in hand.size():
		var card := AnimalCard.create(hand[i], true)
		card.highlighted = i == selected
		var card_info := GameData.get_card(hand[i])
		if not sim.requirement_problems(0, i).is_empty() or sim.energy(0) < float(card_info.cost):
			card.modulate = Color(0.55, 0.55, 0.6)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_select(i)
		)
		_hand_row.add_child(card)
	var next_box := UIKit.vbox(2)
	next_box.add_child(UIKit.label("Next", 16, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var next_card := AnimalCard.create(sim.next_card(0), true)
	next_card.modulate = Color(0.8, 0.8, 0.85)
	next_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_box.add_child(next_card)
	_hand_row.add_child(next_box)


func _handle_events(events: Array) -> void:
	_field.add_events(events)
	for e in events:
		if e.type == "death" and e.kind == "tower":
			if e.team == 0 and randf() < 0.5:
				_opponent_emote("laughing_hyena", 0.6)
			elif e.team == 1 and randf() < 0.35:
				_opponent_emote("crocodile_tears", 0.8)


# --- Playing cards ---------------------------------------------------------

func _select(index: int) -> void:
	selected = -1 if selected == index else index
	if selected == -1:
		_field.highlight_zones = []
		_set_status("")
	else:
		var card := GameData.get_card(sim.hand(0)[selected])
		_field.highlight_zones = PlacementRules.allowed_zones(card)
		var problems := sim.requirement_problems(0, selected)
		if problems.is_empty():
			var verb := "use" if card.kind == "tool" else "release"
			_set_status("%s: tap the glowing area to %s it." % [card.name, verb])
		else:
			_set_status("%s: %s" % [card.name, ". ".join(problems)], UIKit.YELLOW)
	_refresh_hand()


func _on_field_tapped(at: Vector2i, _zone: String) -> void:
	_emote_panel.visible = false
	if selected == -1:
		_set_status("Pick a card first.")
		return
	var card := GameData.get_card(sim.hand(0)[selected])
	var problems := sim.release_problems(0, selected, at.x, at.y)
	if not problems.is_empty():
		_set_status("Can't play %s: %s" % [card.name, ". ".join(problems)], UIKit.RED.lightened(0.3))
		return
	sim.release(0, selected, at.x, at.y)
	_field.add_events(sim.take_events())
	selected = -1
	_field.highlight_zones = []
	_set_status("")
	_refresh_hand()


func _on_swap() -> void:
	var index := selected if selected >= 0 else 0
	if sim.swap(0, index):
		selected = -1
		_field.highlight_zones = []
		_set_status("Swapped a card to the back of your deck.")
		sim.take_events()
		_refresh_hand()


func _set_status(text: String, color := UIKit.TEXT) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)


# --- End of battle ---------------------------------------------------------

func _end_battle() -> void:
	var outcome := "draw"
	if sim.outcome == 0:
		outcome = "win"
	elif sim.outcome == 1:
		outcome = "loss"
	_result = _record(outcome)
	_field.highlight_zones = []
	if not opponent_muted and randf() < 0.6:
		_opponent_says("good_game")

	var box := UIKit.vbox(14)
	var titles := {"win": "Victory!", "loss": "Defeat", "draw": "Draw"}
	var colors := {"win": UIKit.YELLOW, "loss": UIKit.RED, "draw": UIKit.TEXT}
	box.add_child(UIKit.label(titles[outcome], 52, colors[outcome], HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UIKit.label("Towers destroyed  %d - %d" % [sim.teams[0].towers_destroyed, sim.teams[1].towers_destroyed], 26, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var ok := UIKit.button("OK", UIKit.GREEN, 28, Vector2(220, 84))
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(_back_to_menu)
	box.add_child(ok)
	var panel := UIKit.panel(UIKit.PANEL, 24, 24)
	panel.add_child(box)
	panel.custom_minimum_size = Vector2(520, 0)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	add_child(center)
	center.add_child(panel)


func _record(outcome: String) -> Dictionary:
	var result := Profile.record_match(outcome, int(opponent.trophies))
	result["towers"] = [sim.teams[0].towers_destroyed, sim.teams[1].towers_destroyed]
	return result


func _back_to_menu() -> void:
	Profile.pending_match_result = _result
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_leave() -> void:
	Modal.confirm("Leave the battle? It counts as a loss.", "Leave", _leave_now, UIKit.RED)


func _leave_now() -> void:
	if _result.is_empty():
		_result = _record("loss")
	_back_to_menu()


# --- Emotes and quick chat -------------------------------------------------

func _build_emote_panel() -> PanelContainer:
	var panel := UIKit.panel(UIKit.PANEL_DARK, 14, 20)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.custom_minimum_size = Vector2(680, 0)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_bottom = -90
	var column := UIKit.vbox(10)
	panel.add_child(column)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)
	for emote in Profile.unlocked_emotes():
		var cell := UIKit.panel(UIKit.PANEL, 6, 12)
		cell.custom_minimum_size = Vector2(150, 0)
		var cell_box := UIKit.vbox(2)
		cell_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(cell_box)
		var art := ArtPlaceholder.new()
		art.text = UIKit.initials(emote.name)
		art.color = Color(emote.color)
		art.custom_minimum_size = Vector2(64, 64)
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell_box.add_child(art)
		var caption := UIKit.label(emote.caption, 16, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		caption.clip_text = true
		cell_box.add_child(caption)
		UIKit.on_tap(cell, func() -> void: _send({"emote": emote}))
		grid.add_child(cell)

	var chats := GridContainer.new()
	chats.columns = 2
	chats.add_theme_constant_override("h_separation", 8)
	chats.add_theme_constant_override("v_separation", 8)
	column.add_child(chats)
	for chat in GameData.quick_chats:
		var b := UIKit.button(chat.text, UIKit.PANEL_LIGHT, 20, Vector2(320, 56))
		b.pressed.connect(func() -> void: _send({"text": chat.text}))
		chats.add_child(b)

	var mute := UIKit.button("Mute opponent", UIKit.GREY, 20, Vector2(0, 56))
	mute.pressed.connect(func() -> void:
		opponent_muted = not opponent_muted
		mute.text = "Unmute opponent" if opponent_muted else "Mute opponent"
	)
	column.add_child(mute)
	return panel


## `message` is {"emote": Dictionary} or {"text": String}.
func _send(message: Dictionary) -> void:
	_emote_panel.visible = false
	if emote_cooldown > 0.0:
		return
	emote_cooldown = 2.0
	_show_bubble(true, message)
	if randf() < 0.4:
		var reply_id: String = OPPONENT_CHATS.pick_random()
		get_tree().create_timer(randf_range(1.0, 2.0)).timeout.connect(func() -> void: _opponent_says(reply_id))


func _opponent_says(chat_id: String) -> void:
	if opponent_muted or not is_inside_tree():
		return
	if randf() < 0.5:
		var defaults := GameData.emotes.filter(func(e): return e.unlock.type == "default")
		_show_bubble(false, {"emote": defaults.pick_random()})
	else:
		_show_bubble(false, {"text": GameData.find_by_id(GameData.quick_chats, chat_id).get("text", "Hi!")})


func _opponent_emote(emote_id: String, delay: float) -> void:
	var emote := GameData.find_by_id(GameData.emotes, emote_id)
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if not opponent_muted and is_inside_tree():
			_show_bubble(false, {"emote": emote})
	)


func _show_bubble(own: bool, message: Dictionary) -> void:
	if _bubbles.has(own) and is_instance_valid(_bubbles[own]):
		_bubbles[own].queue_free()
	var bubble := UIKit.panel(Color(1, 1, 1, 0.95), 10, 18)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UIKit.hbox(8)
	bubble.add_child(row)
	var text: String = message.get("text", "")
	if message.has("emote"):
		var art := ArtPlaceholder.new()
		art.text = UIKit.initials(message.emote.name)
		art.color = Color(message.emote.color)
		art.custom_minimum_size = Vector2(56, 56)
		row.add_child(art)
		text = message.emote.caption
	var l := UIKit.label(text, 24, Color("#1a2340"))
	l.add_theme_constant_override("outline_size", 0)
	row.add_child(l)
	_field.add_child(bubble)
	_bubbles[own] = bubble

	var anchor := _field.tower_screen_position(0 if own else 1, "main")
	var place := func() -> void:
		var offset_y := -bubble.size.y - 70.0 if own else 60.0
		bubble.position = Vector2(clampf(anchor.x - bubble.size.x / 2.0, 4.0, _field.size.x - bubble.size.x - 4.0), anchor.y + offset_y)
	bubble.resized.connect(place)
	place.call()
	var tween := bubble.create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.3)
	tween.tween_callback(bubble.queue_free)
