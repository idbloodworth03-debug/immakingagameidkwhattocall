extends Control
## Battle sandbox: practice releasing animals before the real battle rules
## exist. It has energy, the 4-card hand that cycles through your deck,
## release requirements, emotes and quick chat. Animals don't move or fight
## yet; that's what we design next. The Win and Lose buttons end the match
## so trophies and cages can be tested.

const MENU_SCENE := "res://scenes/main.tscn"
const OPPONENT_NAMES := ["MossyFox", "RiverOtter42", "SilentOwl", "BadgerBoss", "TundraTom", "ZebraZoe", "CanopyKid", "DuneRunner"]
const OPPONENT_CHATS := ["good_luck", "well_played", "wow", "good_game", "oops"]

var rules: Dictionary
var energy := 0.0
var elapsed := 0.0
var hand: Array = []         # the 4 cards you can play
var waiting: Array = []      # the rest of the deck; waiting[0] comes next
var selected := -1           # index in `hand`, -1 when nothing is selected
var allies_on_field: Array = []   # [{ "animal": Dictionary, "token": Control }]
var deployed_count := 0
var allies_defeated := 0
var opponent: Dictionary = {}
var opponent_muted := false
var emote_cooldown := 0.0

var _field: BattleField
var _timer_label: Label
var _status: Label
var _hand_row: HBoxContainer
var _energy_bar: ProgressBar
var _emote_panel: PanelContainer
var _bubbles := {}


func _ready() -> void:
	theme = UIKit.build_theme()
	rules = GameData.battle_rules
	energy = float(rules.energy_start)

	var deck := Profile.get_deck()
	deck.shuffle()
	hand = deck.slice(0, int(rules.hand_size))
	waiting = deck.slice(int(rules.hand_size))
	_make_opponent()
	_build()
	_refresh_hand()
	_set_status("Tap a card, then tap your side of the field to release it.")
	if randf() < 0.5:
		get_tree().create_timer(1.5).timeout.connect(func() -> void: _opponent_says("good_luck"))


func _process(delta: float) -> void:
	var match_seconds := float(rules.match_seconds)
	var was_running := elapsed < match_seconds
	elapsed += delta
	emote_cooldown = maxf(0.0, emote_cooldown - delta)
	var before := floori(energy)
	energy = minf(float(rules.energy_max), energy + delta / float(rules.energy_regen_seconds))
	_energy_bar.value = energy
	_energy_bar.get_child(0).text = "Energy %d" % floori(energy)
	if floori(energy) != before:
		_refresh_hand()
	var left := maxf(0.0, match_seconds - elapsed)
	_timer_label.text = "%d:%02d" % [floori(left / 60.0), int(left) % 60]
	if was_running and elapsed >= match_seconds:
		_set_status("Time! Real win conditions come with the battle rules. Use Win or Lose to finish.", UIKit.YELLOW)


# --- Building the screen ---------------------------------------------------

func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("#1a2a1a")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var column := UIKit.vbox(8)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 8
	column.offset_right = -8
	column.offset_top = 8
	column.offset_bottom = -8
	add_child(column)

	# Opponent and clock
	var top := UIKit.hbox(10)
	column.add_child(top)
	top.add_child(PlayerBadge.create(opponent.banner, opponent.icon, opponent.name, opponent.level, true))
	top.add_child(UIKit.pill("T", UIKit.TROPHY, UIKit.format_number(opponent.trophies)))
	top.add_child(UIKit.spacer())
	var clock := UIKit.vbox(0)
	top.add_child(clock)
	clock.add_child(UIKit.label("Time left", 18, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT))
	_timer_label = UIKit.label("3:00", 34, UIKit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	clock.add_child(_timer_label)

	_field = BattleField.new()
	_field.grass = Color(GameData.get_arena(Profile.arena_index()).color)
	_field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field.tapped.connect(_on_field_tapped)
	column.add_child(_field)

	_status = UIKit.paragraph("", 20, UIKit.TEXT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size.y = 52
	column.add_child(_status)

	_hand_row = UIKit.hbox(8)
	_hand_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_hand_row)

	_energy_bar = UIKit.progress(0.0, "Energy", UIKit.ENERGY, 34)
	_energy_bar.max_value = float(rules.energy_max)
	column.add_child(_energy_bar)

	var buttons := UIKit.hbox(8)
	column.add_child(buttons)
	var actions := [
		["Emote", UIKit.BLUE, _toggle_emotes],
		["Hit my\ntower", UIKit.GREY, _dev_hit_tower],
		["Dev:\nWin", UIKit.GREEN, _finish.bind(true)],
		["Dev:\nLose", UIKit.RED, _finish.bind(false)],
		["Leave", UIKit.GREY.darkened(0.2), _leave],
	]
	for action in actions:
		var b := UIKit.button(action[0], action[1], 19, Vector2(0, 74))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(action[2])
		buttons.add_child(b)

	_emote_panel = _build_emote_panel()
	_emote_panel.visible = false
	add_child(_emote_panel)


func _build_emote_panel() -> PanelContainer:
	var panel := UIKit.panel(UIKit.PANEL_DARK, 14, 20)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.custom_minimum_size = Vector2(680, 0)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_bottom = -100
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


func _make_opponent() -> void:
	var defaults_b := GameData.banners.filter(func(b): return b.unlock.type == "default")
	var defaults_i := GameData.player_icons.filter(func(i): return i.unlock.type == "default")
	opponent = {
		"name": OPPONENT_NAMES.pick_random(),
		"trophies": maxi(0, Profile.get_trophies() + randi_range(-80, 80)),
		"banner": defaults_b.pick_random().id,
		"icon": defaults_i.pick_random().id,
		"level": maxi(1, int(Profile.ranger_info().level) + randi_range(-1, 1)),
	}


# --- Hand and releasing animals --------------------------------------------

func _state(zone: String) -> Dictionary:
	return {
		"energy": energy,
		"elapsed": elapsed,
		"zone": zone,
		"allies": allies_on_field.map(func(entry): return entry.animal),
		"deployed_count": deployed_count,
		"allies_defeated": allies_defeated,
		"own_tower_damaged": _field.own_tower_damaged,
	}


## Reasons a hand card can't be released anywhere right now (ignores where
## you tap; that's checked when you tap the field).
func _card_reasons(index: int) -> Array:
	var animal := GameData.get_animal(hand[index])
	return PlacementRules.blocking_reasons(animal, _state(PlacementRules.allowed_zones(animal)[0]))


func _refresh_hand() -> void:
	for child in _hand_row.get_children():
		_hand_row.remove_child(child)
		child.queue_free()
	for i in hand.size():
		var card := AnimalCard.create(hand[i], true)
		card.highlighted = i == selected
		if not _card_reasons(i).is_empty():
			card.modulate = Color(0.55, 0.55, 0.6)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_select(i)
		)
		_hand_row.add_child(card)
	if not waiting.is_empty():
		var next_box := UIKit.vbox(2)
		next_box.add_child(UIKit.label("Next", 16, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
		var next_card := AnimalCard.create(waiting[0], true)
		next_card.modulate = Color(0.8, 0.8, 0.85)
		next_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		next_box.add_child(next_card)
		_hand_row.add_child(next_box)


func _select(index: int) -> void:
	selected = -1 if selected == index else index
	if selected == -1:
		_field.highlight_zones = []
		_set_status("")
	else:
		var animal := GameData.get_animal(hand[selected])
		_field.highlight_zones = PlacementRules.allowed_zones(animal)
		var reasons := _card_reasons(selected)
		if reasons.is_empty():
			_set_status("%s: tap the highlighted area to release." % animal.name)
		else:
			_set_status("%s: %s" % [animal.name, ". ".join(reasons)], UIKit.YELLOW)
	_refresh_hand()


func _on_field_tapped(at: Vector2, zone: String) -> void:
	if selected == -1:
		_set_status("Pick a card first.")
		return
	var animal := GameData.get_animal(hand[selected])
	var reasons := PlacementRules.blocking_reasons(animal, _state(zone))
	if not reasons.is_empty():
		_set_status("Can't release %s: %s" % [animal.name, ". ".join(reasons)], UIKit.RED.lightened(0.3))
		return

	energy -= float(animal.cost)
	deployed_count += 1
	_spawn_token(animal, at)
	# The played card goes to the back of the deck and the next one comes in.
	waiting.push_back(hand[selected])
	hand[selected] = waiting.pop_front()
	selected = -1
	_field.highlight_zones = []
	_set_status("Released %s! (Tap one of your animals to mark it defeated.)" % animal.name, UIKit.GREEN.lightened(0.3))
	_refresh_hand()


func _spawn_token(animal: Dictionary, at: Vector2) -> void:
	var token := ArtPlaceholder.new()
	token.text = UIKit.initials(animal.name) + ("x%d" % int(animal.count) if int(animal.count) > 1 else "")
	token.color = UIKit.habitat_color(animal)
	var token_size := _field.token_size()
	token.size = Vector2(token_size, token_size)
	token.position = at - token.size / 2.0
	_field.add_child(token)
	var entry := {"animal": animal, "token": token}
	allies_on_field.append(entry)
	UIKit.on_tap(token, func() -> void: _defeat(entry))
	token.mouse_filter = Control.MOUSE_FILTER_STOP
	token.pivot_offset = token.size / 2.0
	token.scale = Vector2(0.2, 0.2)
	token.create_tween().tween_property(token, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _defeat(entry: Dictionary) -> void:
	allies_on_field.erase(entry)
	allies_defeated += 1
	entry.token.queue_free()
	_set_status("%s was defeated." % entry.animal.name)
	_refresh_hand()


func _set_status(text: String, color := UIKit.TEXT) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)


# --- Emotes and quick chat -------------------------------------------------

func _toggle_emotes() -> void:
	_emote_panel.visible = not _emote_panel.visible


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

	var anchor := _field.king_position(own)
	var place := func() -> void:
		var offset_y := -bubble.size.y - _field.size.x * 0.12 if own else _field.size.x * 0.12
		bubble.position = Vector2(clampf(anchor.x - bubble.size.x / 2.0, 4.0, _field.size.x - bubble.size.x - 4.0), anchor.y + offset_y)
	bubble.resized.connect(place)
	place.call()
	var tween := bubble.create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(bubble, "modulate:a", 0.0, 0.3)
	tween.tween_callback(bubble.queue_free)


# --- Dev buttons -----------------------------------------------------------

func _dev_hit_tower() -> void:
	_field.own_tower_damaged = true
	_set_status("One of your towers took damage (sandbox).", UIKit.YELLOW)
	_refresh_hand()


func _finish(won: bool) -> void:
	Profile.pending_match_result = Profile.record_match(won, int(opponent.trophies))
	get_tree().change_scene_to_file(MENU_SCENE)


func _leave() -> void:
	Modal.confirm("Leave the sandbox? Trophies won't change.", "Leave", func() -> void: get_tree().change_scene_to_file(MENU_SCENE), UIKit.RED)
