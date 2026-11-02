extends Control
## Draft Duel against the computer opponent (the rules are in DraftMatch).
## The field in the middle shows both herds for the whole match. The panel
## under it changes with each part of a round: the Watering Hole, placing
## your herd, the Bookie's odds, your tools in the fight, the halftime bet
## and the round's results.

const MENU_SCENE := "res://scenes/main.tscn"
const ACORN := Color("#c98b4a")
## How long the Bookie may think each frame (nothing else moves while it
## thinks), and in all before it settles on the tries it has finished (for
## slow phones).
const BOOKIE_USEC_PER_FRAME := 12000
const BOOKIE_PATIENCE := 3.0
## Moods this strong or more show over the animals when a fight starts.
const MOOD_SHOWN := 12

var duel: DraftMatch
var bot: DraftBot
var opponent: Dictionary = {}
## The match stake from draft_rules.json, chosen before the match.
var stake: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _selected_market := -1
var _selected_herd := -1
var _selected_tool := -1
var _rally_selected := false
var _fast := false
var _accumulator := 0.0
var _bot_wait := 0.0
var _bookie: Bookie
var _bookie_time := 0.0
## The Bookie's halftime chance for the player (-1 while it's thinking).
var _halftime_line := -1.0
var _panel_key := ""
var _result: Dictionary = {}

var _field: BattleField
var _round_label: Label
var _phase_label: Label
var _pot_pill: PanelContainer
var _their_acorns: PanelContainer
var _their_tools: Label
var _my_acorns: PanelContainer
var _status: Label
var _panel: VBoxContainer


func _ready() -> void:
	theme = UIKit.build_theme()
	_rng.randomize()
	duel = DraftMatch.new(_rng.randi())
	# The opponent gets sharper the higher the arena.
	var difficulty := float(Profile.arena_index()) / maxf(1.0, GameData.arenas.size() - 1)
	bot = DraftBot.new(duel, 1, _rng.randi(), difficulty)
	opponent = Opponents.random(_rng)
	_build()
	Sound.play_music("battle")
	_choose_stake()
	UIKit.fade_in(self)


func _process(delta: float) -> void:
	if stake.is_empty() or not _result.is_empty():
		return
	_think_bookie(delta)
	_opponent_moves(delta)
	if duel.phase == "fight":
		_run_fight(delta)
	else:
		_accumulator = 0.0
	_handle_events(duel.take_events())
	_update_hud()
	var key := _panel_signature()
	if key != _panel_key:
		_panel_key = key
		_rebuild_panel()
	if duel.is_over():
		_end_match()


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
	_round_label = UIKit.label("", 24, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	middle.add_child(_round_label)
	_phase_label = UIKit.label("", 17, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	middle.add_child(_phase_label)
	var round_pill := UIKit.hud_pill(middle)
	round_pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(round_pill)
	var pot_box := UIKit.vbox(0)
	top.add_child(pot_box)
	pot_box.add_child(UIKit.label("Pot", 16, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	_pot_pill = UIKit.pill(GameData.ui_icon("pot"), UIKit.GOLD, "0")
	pot_box.add_child(_pot_pill)

	var theirs := UIKit.hbox(10)
	column.add_child(theirs)
	_their_acorns = UIKit.pill(GameData.ui_icon("acorn"), ACORN, "0")
	theirs.add_child(_their_acorns)
	_their_tools = UIKit.label("", 18, UIKit.TEXT_DIM)
	_their_tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	theirs.add_child(_their_tools)

	_field = BattleField.new()
	_field.sim = duel.sim
	_field.grass = Color(GameData.get_arena(Profile.arena_index()).color)
	_field.arena_id = GameData.get_arena(Profile.arena_index()).id
	_field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field.tapped.connect(_on_field_tapped)
	column.add_child(_field)

	_status = UIKit.paragraph("", 19, UIKit.TEXT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size.y = 30
	column.add_child(_status)

	# Only as tall as each part of the round needs, so the fight gets room.
	var panel := UIKit.panel(UIKit.PANEL_DARK, 10, 18)
	column.add_child(panel)
	_panel = UIKit.vbox(8)
	panel.add_child(_panel)

	var bottom := UIKit.hbox(10)
	column.add_child(bottom)
	_my_acorns = UIKit.pill(GameData.ui_icon("acorn"), ACORN, "0")
	bottom.add_child(_my_acorns)
	bottom.add_child(UIKit.label("Your Acorns", 18, UIKit.TEXT_DIM))
	bottom.add_child(UIKit.spacer())
	var leave := UIKit.button("Leave", UIKit.GREY.darkened(0.25), 20, Vector2(110, 56))
	leave.pressed.connect(_on_leave)
	bottom.add_child(leave)
	_update_hud()


## Before the first draft: how many trophies to play for.
func _choose_stake() -> void:
	var box := UIKit.vbox(12)
	box.add_child(UIKit.label("Draft Duel", 44, UIKit.YELLOW, HORIZONTAL_ALIGNMENT_CENTER))
	var intro := UIKit.paragraph("Take turns drafting animals at the Watering Hole, place your herd, and bet Acorns on the fight. Your dens are your lives: lose your main den and you're out. Choose your stake:", 20, UIKit.TEXT)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(intro)
	var overlay := _overlay(box)
	var colors := [UIKit.GREEN, UIKit.BLUE, UIKit.RED]
	var stakes: Array = duel.rules.stakes
	for i in stakes.size():
		var s: Dictionary = stakes[i]
		var b := UIKit.button("%s\n%s" % [s.name, s.text], colors[i % colors.size()], 22, Vector2(0, 92))
		b.pressed.connect(func() -> void:
			stake = s
			overlay.queue_free()
			Sound.play("select")
		)
		box.add_child(b)


## A dimmed full-screen layer with a panel in the middle holding `content`.
func _overlay(content: Control) -> Control:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := UIKit.panel(UIKit.PANEL, 24, 24)
	panel.custom_minimum_size = Vector2(560, 0)
	panel.add_child(content)
	center.add_child(panel)
	return layer


# --- Every frame -----------------------------------------------------------

func _update_hud() -> void:
	_round_label.text = "Round %d of %d" % [duel.round_number, duel.rounds()]
	var phase_names := {
		"draft": "Draft", "place": "Place your herd", "wager": "The Bookie's odds",
		"halftime": "Halftime!", "round_over": "Round over", "over": "Match over",
	}
	if duel.phase == "fight":
		var left := float(duel.fight_ticks - duel.fight_tick) / duel.sim.tps
		_phase_label.text = "Fight  %d:%02d" % [floori(left / 60.0), int(left) % 60]
	else:
		_phase_label.text = phase_names.get(duel.phase, "")
	_set_amount(_pot_pill, duel.pot)
	_set_amount(_their_acorns, duel.acorns[1])
	_set_amount(_my_acorns, duel.acorns[0])
	var their_tools: int = duel.tools[1].size()
	_their_tools.text = "%s's Acorns  ·  %d tool%s hidden" % [opponent.name, their_tools, "" if their_tools == 1 else "s"]


func _set_amount(pill: PanelContainer, amount: int) -> void:
	(pill.find_child("Amount", true, false) as Label).text = str(amount)


## Changes whenever the panel under the field needs redrawing.
func _panel_signature() -> String:
	var taken := []
	for item in duel.market:
		taken.append(item.taken)
	return str([duel.phase, duel.round_number, duel.turn, duel.passed, taken, duel.acorns, duel.tools[0],
		duel.herds[0].size(), duel.wagers, duel.line >= 0.0, duel.halftime, _halftime_line >= 0.0,
		_selected_market, _selected_herd, _selected_tool, _rally_selected, duel.rally_ready[0], _fast, duel.ready,
		duel.fight_tick > duel.halftime_ticks])


## The Bookie works out odds a little each frame when they're wanted.
func _think_bookie(delta: float) -> void:
	var wanted := (duel.phase == "wager" and duel.line < 0.0) or (duel.phase == "halftime" and _halftime_line < 0.0)
	if not wanted:
		_bookie = null
		return
	if _bookie == null:
		_bookie = Bookie.study(duel, _rng.randi())
		_bookie_time = 0.0
	_bookie_time += delta
	if _bookie.advance(BOOKIE_USEC_PER_FRAME) or (_bookie_time > BOOKIE_PATIENCE and _bookie.settle()):
		var chance := _bookie.chance(0)
		_bookie = null
		if duel.phase == "wager":
			duel.post_line(chance)
		else:
			_halftime_line = chance
		_bot_wait = _rng.randf_range(0.6, 1.2)


## The opponent takes a moment over each decision, like a person would.
func _opponent_moves(delta: float) -> void:
	_bot_wait -= delta
	match duel.phase:
		"draft":
			if duel.turn == bot.team and not duel.passed[bot.team] and _bot_wait <= 0.0:
				bot.pick()
				_bot_wait = _rng.randf_range(0.7, 1.3)
		"place":
			if not duel.ready[bot.team]:
				bot.place()
		"wager":
			if duel.line >= 0.0 and duel.wagers[bot.team] < 0 and _bot_wait <= 0.0:
				bot.back_herd(1.0 - duel.line)
		"halftime":
			if _halftime_line >= 0.0 and int(duel.halftime.get("turn", -1)) == bot.team and _bot_wait <= 0.0:
				bot.bet(1.0 - _halftime_line)
				_bot_wait = _rng.randf_range(0.6, 1.0)


func _run_fight(delta: float) -> void:
	var tick_length := 1.0 / duel.sim.tps
	_accumulator += delta * (2.0 if _fast else 1.0)
	var steps := 0
	while _accumulator >= tick_length and steps < 10 and duel.phase == "fight":
		bot.update()
		duel.step()
		var events := duel.sim.take_events()
		_field.add_events(events)
		BattleField.play_sounds(events)
		_accumulator -= tick_length
		steps += 1
	if duel.phase == "fight":
		_field.blend = clampf(_accumulator / tick_length, 0.0, 1.0)


func _handle_events(events: Array) -> void:
	for e in events:
		var theirs: bool = e.get("team", 0) == bot.team
		match e.type:
			"round":
				_selected_market = -1
				_announce_round(int(e.first))
				_bot_wait = 1.6  # let the player read who picks first
			"buy":
				Sound.play("reveal" if e.mystery else "coin")
				var card := GameData.get_card(e.id)
				if e.mystery:
					UIKit.toast("%s Mystery Crate: %s!" % ["Their" if theirs else "Your", card.name], ACORN.darkened(0.4))
				if theirs:
					_set_status("%s took the %s." % [opponent.name, card.name])
				else:
					_selected_market = -1
			"pass":
				if theirs and not e.get("auto", false):
					_set_status("%s is done picking." % opponent.name)
			"place":
				Sound.play("pop")
				_set_status("Place your herd: tap an animal, then where it should start. No rush.")
			"wager":
				_set_status("The Bookie plays the fight out a few times to set the odds...")
			"bet":
				if theirs:
					Sound.play("coin")
					_set_status("%s bets %d on its herd." % [opponent.name, e.amount] if e.amount > 0 else "%s doesn't bet." % opponent.name)
			"fight":
				Sound.play("horn")
				_set_status("Fight! Rally your herd once, at just the right moment.")
				_show_moods()
			"rally":
				Sound.play("alert", -4.0)
				if theirs:
					_set_status("%s rallies its herd!" % opponent.name, UIKit.YELLOW)
			"tool":
				Sound.play("horn" if e.id == "air_horn" else "tool")
				if theirs:
					_set_status("%s used a %s!" % [opponent.name, GameData.get_card(e.id).name], UIKit.YELLOW)
			"halftime":
				Sound.play("alert")
				_halftime_line = -1.0
				_selected_tool = -1
				_rally_selected = false
				_field.highlight_zones = []
				_set_status("Halftime! The fight pauses for a bet.")
			"raise":
				Sound.play("coin")
				if theirs:
					_set_status("%s raises %d!" % [opponent.name, e.amount], UIKit.YELLOW)
			"check":
				if theirs:
					_set_status("%s checks." % opponent.name)
			"call":
				Sound.play("coin")
				if theirs:
					_set_status("%s calls." % opponent.name)
			"fold":
				if theirs:
					_set_status("%s folds and pulls its herd back!" % opponent.name, UIKit.YELLOW)
			"round_over":
				_selected_tool = -1
				_rally_selected = false
				_field.highlight_zones = []
				Sound.play("upgrade" if e.winner == 0 else "pop")


func _announce_round(first_picker: int) -> void:
	var first := "You pick first." if first_picker == 0 else "%s picks first." % opponent.name
	UIKit.toast("Round %d! %s" % [duel.round_number, first])
	_set_status("The Watering Hole: tap a card to see it, tap again to buy it.")


## Shows which animals came to this fight fired up, and which are sleepy.
func _show_moods() -> void:
	for f in duel.sim.fighters:
		if not f.is_unit():
			continue
		var mood := int(f.memory.get("mood", 0))
		if mood >= MOOD_SHOWN:
			_field.say(f.x, f.y, "Fired up!", Color("#ffb347"))
		elif mood <= -MOOD_SHOWN:
			_field.say(f.x, f.y, "Sleepy", Color("#9fd3ff"))


# --- The panel under the field ---------------------------------------------

func _rebuild_panel() -> void:
	for child in _panel.get_children():
		_panel.remove_child(child)
		child.queue_free()
	match duel.phase:
		"draft":
			_draft_panel()
		"place":
			_place_panel()
		"wager":
			_wager_panel()
		"fight":
			_fight_panel()
		"halftime":
			_halftime_panel()
		"round_over":
			_round_panel()


func _heading(title: String, subtitle: String, icon_key := "") -> void:
	var row := UIKit.hbox(10)
	if icon_key != "":
		row.add_child(UIKit.icon_rect(GameData.ui_icon(icon_key), UIKit.YELLOW, 40))
	var titles := UIKit.vbox(0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_child(UIKit.label(title, 26, UIKit.TEXT))
	if subtitle != "":
		titles.add_child(UIKit.label(subtitle, 18, UIKit.TEXT_DIM))
	row.add_child(titles)
	_panel.add_child(row)


func _buttons(row_items: Array) -> HBoxContainer:
	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for b in row_items:
		row.add_child(b)
	_panel.add_child(row)
	return row


# Draft: the Watering Hole.

func _draft_panel() -> void:
	var mine: bool = duel.turn == 0 and not duel.passed[0]
	var who := "Your pick!" if mine else ("%s is picking..." % opponent.name if not duel.passed[1] else "")
	if duel.passed[0]:
		who = "You're done picking. %s" % ("%s is still picking..." % opponent.name if not duel.passed[1] else "")
	_heading("The Watering Hole", "%s  Herd %d/%d · Tools %d/%d" % [who, duel.herds[0].size(), int(duel.rules.herd_max),
		duel.tools[0].size(), int(duel.rules.tools_max)])
	var row := UIKit.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in duel.market.size():
		row.add_child(_market_card(i))
	_panel.add_child(row)

	if _selected_market >= 0 and int(duel.market[_selected_market].taken) < 0:
		_panel.add_child(_market_details(duel.market[_selected_market]))
	var actions := []
	if _selected_market >= 0 and int(duel.market[_selected_market].taken) < 0:
		var problem := duel.can_buy(0, _selected_market)
		var buy := UIKit.button("Buy for %d" % int(duel.market[_selected_market].cost) if problem == "" else problem, UIKit.GREEN, 22, Vector2(280, 64))
		buy.disabled = problem != ""
		buy.pressed.connect(func() -> void: _buy(_selected_market))
		actions.append(buy)
	var done := UIKit.button("Done picking", UIKit.GREY, 22, Vector2(240, 64))
	done.disabled = not mine
	done.pressed.connect(func() -> void:
		_selected_market = -1
		duel.pass_turn(0)
		_bot_wait = _rng.randf_range(0.6, 1.0)
	)
	actions.append(done)
	_buttons(actions)


func _market_card(slot: int) -> Control:
	var item: Dictionary = duel.market[slot]
	var taken := int(item.taken)
	var card := AnimalCard.create(item.id, true)
	card.custom_minimum_size = Vector2(108, 144)
	card.info = AnimalCard.Info.NONE
	card.mystery = item.mystery and taken < 0
	card.price = int(item.cost)
	card.price_color = ACORN if duel.acorns[0] >= int(item.cost) or taken >= 0 else UIKit.RED
	card.highlighted = slot == _selected_market
	if taken >= 0:
		card.stamp = "YOURS" if taken == 0 else "THEIRS"
		card.stamp_color = UIKit.GREEN if taken == 0 else UIKit.RED
		card.modulate = Color(1, 1, 1, 0.75)
	UIKit.on_tap(card, func() -> void: _on_market_tapped(slot))
	return card


## What the picked card does: its stats and ability, or the crate's odds.
func _market_details(item: Dictionary) -> Control:
	var text := ""
	if item.mystery:
		text = "A random animal for %d Acorns. Could be a Legendary... or a single rat." % int(item.cost)
	else:
		var card := GameData.get_card(item.id)
		if card.kind == "tool":
			text = "%s (tool): %s" % [card.name, card.ability.text]
		else:
			var stats: Dictionary = card.stats
			var pack := " x%d" % int(card.count) if int(card.count) > 1 else ""
			text = "%s%s  ·  %s  ·  Health %d, Bite %d%s\n%s: %s" % [card.name, pack, GameData.rarity_name(card.rarity),
				int(stats.hp), int(stats.damage), ", hits dens only" if stats.targets == "buildings" else "",
				card.ability.name, card.ability.text]
	var l := UIKit.paragraph(text, 18, UIKit.TEXT)
	return l


func _on_market_tapped(slot: int) -> void:
	if int(duel.market[slot].taken) >= 0:
		return
	if _selected_market == slot and duel.can_buy(0, slot) == "":
		_buy(slot)
		return
	Sound.play("select")
	_selected_market = slot


func _buy(slot: int) -> void:
	var problem := duel.can_buy(0, slot)
	if problem != "":
		Sound.play("error")
		_set_status(problem, UIKit.RED.lightened(0.3))
		return
	duel.buy(0, slot)
	_bot_wait = _rng.randf_range(0.7, 1.3)


# Placing.

func _place_panel() -> void:
	var waiting: bool = duel.ready[0]
	_heading("Place your herd", "Tap an animal, then where it should start." if not waiting else "Waiting for %s..." % opponent.name)
	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in duel.herds[0].size():
		row.add_child(_herd_chip(i))
	if duel.herds[0].is_empty():
		row.add_child(UIKit.label("No animals this round!", 20, UIKit.TEXT_DIM))
	_panel.add_child(row)
	if not duel.tools[0].is_empty():
		var names := []
		for id in duel.tools[0]:
			names.append(GameData.get_card(id).name)
		_panel.add_child(UIKit.label("Tools for the fight: " + ", ".join(names), 18, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var go := UIKit.button("Ready!", UIKit.GREEN, 28, Vector2(260, 72))
	go.disabled = waiting
	go.pressed.connect(func() -> void:
		_selected_herd = -1
		_field.highlight_zones = []
		Sound.play("select")
		duel.set_ready(0)
	)
	_buttons([go])


func _herd_chip(index: int) -> Control:
	var card := AnimalCard.create(duel.herds[0][index].id, true)
	card.custom_minimum_size = Vector2(96, 128)
	card.info = AnimalCard.Info.NONE
	card.highlighted = index == _selected_herd
	UIKit.on_tap(card, func() -> void: _select_herd(index))
	return card


func _select_herd(index: int) -> void:
	if duel.phase != "place" or duel.ready[0]:
		return
	Sound.play("select")
	_selected_herd = -1 if _selected_herd == index else index
	if _selected_herd >= 0:
		var card := GameData.get_card(duel.herds[0][_selected_herd].id)
		var zones := PlacementRules.allowed_zones(card)
		_field.highlight_zones = zones
		_set_status("%s: tap where it should start." % card.name)
	else:
		_field.highlight_zones = []


# The Bookie's odds before the fight.

func _wager_panel() -> void:
	if duel.line < 0.0:
		_heading("The Bookie", "Studying the herds... (tools in hand don't count)", "bookie")
		return
	var chance := duel.line
	_heading("The Bookie", "Your herd won %d%% of my tries." % roundi(chance * 100.0), "bookie")
	if duel.wagers[0] >= 0:
		var bet: int = duel.wagers[0]
		_panel.add_child(UIKit.label(("You bet %d. " % bet if bet > 0 else "No bet. ") + "Waiting for %s..." % opponent.name, 20, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		return
	var most := duel.max_wager(0)
	if most == 0:
		var why := "A sure thing: no bets on this one!" if chance > float(duel.rules.no_bets_above) else "You need your Acorns for the ante."
		_panel.add_child(UIKit.label(why, 20, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		var fight := UIKit.button("Fight!", UIKit.GREEN, 26, Vector2(240, 68))
		fight.pressed.connect(func() -> void: duel.wager(0, 0))
		_buttons([fight])
		return
	var pays := float(duel.payout(0)) / 100.0
	var hint := UIKit.paragraph("Back your herd? If it wins, every Acorn you bet comes back x%.1f." % pays, 20, UIKit.TEXT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(hint)
	var choices := []
	var no_bet := UIKit.button("No bet", UIKit.GREY, 22, Vector2(130, 64))
	no_bet.pressed.connect(func() -> void: duel.wager(0, 0))
	choices.append(no_bet)
	for amount in [1, 2, 3, 5]:
		if amount > most and amount != 5:
			continue
		var bet := mini(amount, most)
		var b := UIKit.button("Bet %d" % bet, UIKit.YELLOW.darkened(0.15), 22, Vector2(110, 64))
		b.pressed.connect(func() -> void:
			Sound.play("coin")
			duel.wager(0, bet)
		)
		choices.append(b)
		if bet == most:
			break
	_buttons(choices)


# The fight.

func _fight_panel() -> void:
	var to_halftime := duel.halftime_ticks - duel.fight_tick
	_heading("Fight!", "Halftime bet soon" if to_halftime > 0 else "Tap Rally or a tool, then the field", "dice")
	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_rally_chip())
	for i in duel.tools[0].size():
		row.add_child(_tool_chip(i))
	_panel.add_child(row)
	var speed := UIKit.button("Speed x2" if not _fast else "Normal speed", UIKit.BLUE, 20, Vector2(200, 56))
	speed.pressed.connect(func() -> void: _fast = not _fast)
	_buttons([speed])


## Rally, once a fight: the animals around the spot you tap get fired up.
func _rally_chip() -> Control:
	var ready: bool = duel.rally_ready[0]
	var box := PanelContainer.new()
	var frame := UIKit.box(UIKit.PANEL, 12, 6)
	frame.set_border_width_all(4 if _rally_selected else 2)
	frame.border_color = UIKit.YELLOW if _rally_selected else Color("#ff9f43")
	box.add_theme_stylebox_override("panel", frame)
	var row := UIKit.hbox(6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var art := IconArt.make(GameData.ui_icon("whistle"), Color("#ff9f43"), IconArt.Shape.ROUNDED)
	art.custom_minimum_size = Vector2(72, 72)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art)
	row.add_child(UIKit.label("Rally!" if ready else "Rallied", 20, UIKit.TEXT))
	if not ready:
		box.modulate = Color(1, 1, 1, 0.45)
		return box
	UIKit.on_tap(box, func() -> void:
		Sound.play("select")
		_rally_selected = not _rally_selected
		_selected_tool = -1
		_field.highlight_zones = ["own_side", "river", "enemy_side"] if _rally_selected else []
		if _rally_selected:
			_set_status("Rally: tap where your animals are fighting.")
	)
	return box


func _tool_chip(index: int) -> Control:
	var id: String = duel.tools[0][index]
	var box := PanelContainer.new()
	var frame := UIKit.box(UIKit.PANEL, 12, 6)
	frame.set_border_width_all(4 if index == _selected_tool else 2)
	frame.border_color = UIKit.YELLOW if index == _selected_tool else UIKit.GREY
	box.add_theme_stylebox_override("panel", frame)
	var row := UIKit.hbox(6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var art := UIKit.card_art(id)
	art.custom_minimum_size = Vector2(72, 72)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art)
	row.add_child(UIKit.label(GameData.get_card(id).name, 20, UIKit.TEXT))
	UIKit.on_tap(box, func() -> void:
		Sound.play("select")
		_selected_tool = -1 if _selected_tool == index else index
		_rally_selected = false
		_field.highlight_zones = ["own_side", "river", "enemy_side"] if _selected_tool >= 0 else []
		if _selected_tool >= 0:
			_set_status("%s: tap the field to use it." % GameData.get_card(id).name)
	)
	return box


# Halftime betting.

func _halftime_panel() -> void:
	var h := duel.halftime
	var line_text := "The Bookie is watching..." if _halftime_line < 0.0 else "The Bookie gives your herd %d%%." % roundi(_halftime_line * 100.0)
	_heading("Halftime!  Pot: %d" % duel.pot, line_text, "whistle")
	if _halftime_line < 0.0 or h.is_empty():
		return
	if int(h.turn) != 0:
		_panel.add_child(UIKit.label("%s is deciding..." % opponent.name, 20, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		return
	if int(h.raise) > 0:
		var ask := UIKit.paragraph("%s raises %d! Call to keep fighting for the Pot, or fold to give it up and save your dens." % [opponent.name, int(h.raise)], 20, UIKit.TEXT)
		ask.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_panel.add_child(ask)
		var call_button := UIKit.button("Call %d" % mini(int(h.raise), duel.acorns[0]), UIKit.GREEN, 24, Vector2(200, 68))
		call_button.pressed.connect(func() -> void:
			Sound.play("coin")
			duel.call_raise(0)
		)
		var fold_button := UIKit.button("Fold", UIKit.RED, 24, Vector2(200, 68))
		fold_button.pressed.connect(func() -> void: duel.fold(0))
		_buttons([call_button, fold_button])
		return
	var tip := UIKit.paragraph("Raise to win more Acorns: %s must match it or fold. Or check and play on." % opponent.name, 19, UIKit.TEXT)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(tip)
	var choices := []
	var check_button := UIKit.button("Check", UIKit.GREY, 22, Vector2(150, 64))
	check_button.pressed.connect(func() -> void:
		duel.check(0)
		_bot_wait = _rng.randf_range(0.6, 1.0)
	)
	choices.append(check_button)
	for amount in range(1, duel.max_raise(0) + 1):
		var b := UIKit.button("Raise %d" % amount, UIKit.YELLOW.darkened(0.15), 22, Vector2(130, 64))
		b.pressed.connect(func() -> void:
			duel.raise_pot(0, amount)
			_bot_wait = _rng.randf_range(0.6, 1.0)
		)
		choices.append(b)
	_buttons(choices)


# The round's results.

func _round_panel() -> void:
	var r := duel.last_round
	var winner := int(r.winner)
	var title := "You won round %d!" % int(r.round) if winner == 0 else ("%s won round %d" % [opponent.name, int(r.round)] if winner == 1 else "Round %d: a tie" % int(r.round))
	_heading(title, "", "trophy" if winner == 0 else "")
	var lines := []
	if int(r.folded) == 0:
		lines.append("You folded and saved your dens.")
	elif int(r.folded) == 1:
		lines.append("%s folded!" % opponent.name)
	if winner == 0:
		lines.append("You won the Pot: +%d Acorns." % int(r.pot))
	elif winner == 1:
		lines.append("%s won the Pot (%d)." % [opponent.name, int(r.pot)])
	else:
		lines.append("The Pot carries over: %d." % duel.pot)
	var bet := int(r.wagers[0])
	if bet > 0:
		lines.append("The Bookie paid you %d!" % int(r.paid[0]) if int(r.paid[0]) > bet else ("The Bookie gave back your %d." % bet if int(r.paid[0]) == bet else "The Bookie kept your %d." % bet))
	lines.append("Den damage: you dealt %d, took %d." % [int(r.dealt[0]), int(r.dealt[1])])
	for line in lines:
		_panel.add_child(UIKit.label(line, 20, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var next := UIKit.button("Next round", UIKit.GREEN, 26, Vector2(260, 68))
	next.pressed.connect(func() -> void:
		Sound.play("select")
		duel.next_round()
	)
	_buttons([next])


# --- The field -------------------------------------------------------------

func _on_field_tapped(at: Vector2i, _zone: String) -> void:
	match duel.phase:
		"place":
			if duel.ready[0]:
				return
			var hit := duel.herd_index_at(0, at.x, at.y)
			if hit >= 0 and hit != _selected_herd:
				_select_herd(hit)
				return
			if _selected_herd < 0:
				_set_status("Tap one of your animals first.")
				return
			var spot := BattleSim.tile_center(at.x, at.y)
			var entry: Dictionary = duel.herds[0][_selected_herd]
			if duel.move(0, _selected_herd, spot.x, spot.y):
				Sound.play("release", -2.0, 0.08)
				_selected_herd = -1
				_field.highlight_zones = []
				_set_status("Moved. Tap another animal, or press Ready.")
			else:
				Sound.play("error")
				_set_status(duel.placement_problem(0, entry.id, spot.x, spot.y), UIKit.RED.lightened(0.3))
		"fight":
			if _rally_selected:
				if duel.rally(0, at.x, at.y):
					_field.add_events(duel.sim.take_events())
				_rally_selected = false
				_field.highlight_zones = []
				return
			if _selected_tool < 0:
				_set_status("Tap Rally or a tool first.")
				return
			if duel.use_tool(0, _selected_tool, at.x, at.y):
				_field.add_events(duel.sim.take_events())
				_selected_tool = -1
				_field.highlight_zones = []


func _set_status(text: String, color := UIKit.TEXT) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)


# --- End of the match ------------------------------------------------------

func _end_match() -> void:
	if not _result.is_empty():
		return
	var winner := duel.match_winner()
	var outcome := "draw" if winner == DraftMatch.NO_WINNER else ("win" if winner == 0 else "loss")
	_record(outcome)
	Sound.stop_music()
	Sound.play({"win": "victory", "loss": "defeat", "draw": "reveal"}[outcome])
	var box := UIKit.vbox(14)
	var titles := {"win": "Victory!", "loss": "Defeat", "draw": "Draw"}
	var colors := {"win": UIKit.YELLOW, "loss": UIKit.RED, "draw": UIKit.TEXT}
	box.add_child(UIKit.label(titles[outcome], 52, colors[outcome], HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UIKit.label("Dens destroyed  %d - %d" % [duel.sim.teams[0].towers_destroyed, duel.sim.teams[1].towers_destroyed], 26, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UIKit.label("Stake: %s" % stake.name, 22, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var ok := UIKit.button("OK", UIKit.GREEN, 28, Vector2(220, 84))
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(_back_to_menu)
	box.add_child(ok)
	_overlay(box)


func _record(outcome: String) -> void:
	_result = Profile.record_match(outcome, int(opponent.trophies), float(stake.get("multiplier", 1.0)))
	_result["towers"] = [duel.sim.teams[0].towers_destroyed, duel.sim.teams[1].towers_destroyed]


func _back_to_menu() -> void:
	Profile.pending_match_result = _result
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_leave() -> void:
	Modal.confirm("Leave the match? It counts as a loss.", "Leave", _leave_now, UIKit.RED)


func _leave_now() -> void:
	if _result.is_empty():
		if stake.is_empty():
			stake = duel.rules.stakes[0]
		_record("loss")
	_back_to_menu()
