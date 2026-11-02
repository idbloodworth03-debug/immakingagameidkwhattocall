extends Control
## Draft Duel against the computer opponent (the rules are in DraftMatch).
## Before the match: the stake, then your starters. The field in the middle
## shows both herds for the whole match. The panel under it changes with
## each part of a round: your shop (buy, reroll, train), placing your herd,
## the Bookie's odds, your tools in the fight, the halftime bet and the
## round's results.

const MENU_SCENE := "res://scenes/main.tscn"
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
## A herd animal picked: to train while shopping, to move while placing.
var _selected_herd := -1
## The starters being picked, before the match.
var _starter_ids: Array = []
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
var _their_hearts: PanelContainer
var _their_tools: Label
var _my_acorns: PanelContainer
var _my_hearts: PanelContainer
var _hearts_shown := [-1, -1]
var _status: Label
var _panel: VBoxContainer


func _ready() -> void:
	theme = UIKit.build_theme()
	_rng.randomize()
	# You draft from the cards you own, and they fight at your levels. The
	# opponent's cards are about as leveled as yours.
	var pool := DraftMatch.pool_from_collection(Profile.has_card)
	duel = DraftMatch.new(_rng.randi(), {"levels": [Profile.card_levels(), _opponent_levels(pool)], "pool": pool})
	# The opponent gets sharper the higher the arena.
	var difficulty := float(Profile.arena_index()) / maxf(1.0, GameData.arenas.size() - 1)
	bot = DraftBot.new(duel, 1, _rng.randi(), difficulty)
	opponent = Opponents.random(_rng)
	_build()
	Sound.play_music("battle")
	_choose_stake()
	UIKit.fade_in(self)


## Levels for the opponent's cards: each rarity's starting level, plus as
## many levels as the player's cards have on average.
static func _opponent_levels(pool: Array) -> Dictionary:
	var above := 0.0
	for id in pool:
		above += Profile.card_level(id) - GameData.start_level(GameData.cards[id].rarity)
	var offset := roundi(above / maxf(1.0, pool.size()))
	var levels := {}
	for id in pool:
		levels[id] = mini(int(GameData.progression.card_max_level), GameData.start_level(GameData.cards[id].rarity) + offset)
	return levels


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
	_their_hearts = UIKit.pill(GameData.ui_icon("heart"), UIKit.HEART, "0")
	theirs.add_child(_their_hearts)
	_their_acorns = UIKit.pill(GameData.ui_icon("acorn"), UIKit.ACORN, "0")
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
	_my_hearts = UIKit.pill(GameData.ui_icon("heart"), UIKit.HEART, "0")
	bottom.add_child(_my_hearts)
	_my_acorns = UIKit.pill(GameData.ui_icon("acorn"), UIKit.ACORN, "0")
	bottom.add_child(_my_acorns)
	bottom.add_child(UIKit.label("You", 18, UIKit.TEXT_DIM))
	bottom.add_child(UIKit.spacer())
	var leave := UIKit.button("Leave", UIKit.GREY.darkened(0.25), 20, Vector2(110, 56))
	leave.pressed.connect(_on_leave)
	bottom.add_child(leave)
	_update_hud()


## Before the first draft: how many trophies to play for.
func _choose_stake() -> void:
	var box := UIKit.vbox(12)
	box.add_child(UIKit.label("Draft Duel", 44, UIKit.YELLOW, HORIZONTAL_ALIGNMENT_CENTER))
	var intro := UIKit.paragraph("Pick your starters, then each round shop for more animals, train them up to 3 stars, place your herd and bet Acorns on the fight. You both start with %d hearts. Lose a fight and you lose hearts: more for every enemy animal still standing. Run out and you're out. Choose your stake:" % int(duel.rules.hearts), 20, UIKit.TEXT)
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
			_choose_starters()
		)
		box.add_child(b)


## Before the first round: up to 3 of your animals to start with, within
## the Acorn budget.
func _choose_starters() -> void:
	var box := UIKit.vbox(10)
	var overlay := _overlay(box)
	var rebuild := func(again: Callable) -> void:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
		box.add_child(UIKit.label("Pick your starters", 38, UIKit.YELLOW, HORIZONTAL_ALIGNMENT_CENTER))
		var total := 0
		for id in _starter_ids:
			total += int(GameData.get_card(id).cost)
		var budget := int(duel.rules.starter_budget)
		var note := UIKit.paragraph("Up to %d animals, worth up to %d Acorns. You'll buy more in the shop each round." % [int(duel.rules.starters), budget], 19, UIKit.TEXT)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(note)
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var animal_ids: Array = duel.pool.filter(func(id): return not GameData.is_tool(id))
		# As tall as the cards need, up to 3 rows; more scroll.
		var rows := ceili(animal_ids.size() / 5.0)
		scroll.custom_minimum_size = Vector2(530, mini(rows, 3) * 140)
		scroll.add_child(grid)
		box.add_child(scroll)
		for id in animal_ids:
			var card := AnimalCard.create(id, true)
			card.custom_minimum_size = Vector2(100, 134)
			card.info = AnimalCard.Info.LEVEL
			var picked := _starter_ids.has(id)
			card.highlighted = picked
			if picked:
				card.stamp = "PICKED"
			elif duel.starter_problem(_starter_ids + [id]) != "":
				card.modulate = Color(1, 1, 1, 0.45)
			UIKit.on_tap(card, func() -> void:
				if _starter_ids.has(id):
					_starter_ids.erase(id)
				elif duel.starter_problem(_starter_ids + [id]) == "":
					_starter_ids.append(id)
				else:
					Sound.play("error")
					UIKit.toast(duel.starter_problem(_starter_ids + [id]))
					return
				Sound.play("select")
				again.call(again)
			)
			grid.add_child(card)
		var count_text := "%d of %d picked  ·  %d of %d Acorns" % [_starter_ids.size(), int(duel.rules.starters), total, budget]
		box.add_child(UIKit.label(count_text, 22, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		var go := UIKit.button("Start!", UIKit.GREEN, 28, Vector2(260, 76))
		go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		go.disabled = _starter_ids.is_empty()
		go.pressed.connect(func() -> void:
			if duel.pick_starters(0, _starter_ids):
				Sound.play("horn")
				overlay.queue_free()
		)
		box.add_child(go)
	rebuild.call(rebuild)


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
	_round_label.text = "Round %d" % duel.round_number if duel.round_number > 0 else "Draft Duel"
	var phase_names := {
		"starters": "Pick your starters", "draft": "Shopping", "place": "Place your herd", "wager": "The Bookie's odds",
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
	for team in 2:
		if duel.hearts[team] != _hearts_shown[team]:
			var pill := _my_hearts if team == 0 else _their_hearts
			_set_amount(pill, duel.hearts[team])
			if _hearts_shown[team] >= 0:
				_bump(pill)
			_hearts_shown[team] = duel.hearts[team]
	var their_tools: int = duel.tools[1].size()
	_their_tools.text = "%s  ·  %d tool%s hidden" % [opponent.name, their_tools, "" if their_tools == 1 else "s"]


func _set_amount(pill: PanelContainer, amount: int) -> void:
	(pill.find_child("Amount", true, false) as Label).text = str(amount)


## A quick throb, red, when a pill's number drops.
func _bump(pill: Control) -> void:
	pill.pivot_offset = pill.size / 2.0
	var tween := pill.create_tween()
	tween.tween_property(pill, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(pill, "modulate", Color(1.0, 0.55, 0.55), 0.12)
	tween.tween_property(pill, "scale", Vector2.ONE, 0.25)
	tween.parallel().tween_property(pill, "modulate", Color.WHITE, 0.25)


## Changes whenever the panel under the field needs redrawing.
func _panel_signature() -> String:
	var taken := []
	for item in duel.shops[0]:
		taken.append([item.id, item.taken])
	var stars := []
	for entry in duel.herds[0]:
		stars.append(entry.stars)
	return str([duel.phase, duel.round_number, duel.done_shopping, taken, stars, duel.acorns, duel.tools[0],
		duel.wagers, duel.line >= 0.0, duel.halftime, _halftime_line >= 0.0,
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
		"starters":
			if not duel.starters_picked[bot.team]:
				bot.pick_starters()
		"draft":
			if not duel.done_shopping[bot.team] and _bot_wait <= 0.0:
				bot.shop()
				_bot_wait = _rng.randf_range(0.5, 1.0)
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
				_selected_herd = -1
				_announce_round(int(e.bonus_team), int(e.bonus))
				_bot_wait = 1.2
			"buy":
				Sound.play("reveal" if e.mystery else ("upgrade" if e.merged else "coin"))
				var card := GameData.get_card(e.id)
				if e.mystery:
					UIKit.toast("%s Mystery Crate: %s!" % ["Their" if theirs else "Your", card.name], UIKit.ACORN.darkened(0.4))
				if theirs:
					_set_status("%s's %s is now %s" % [opponent.name, card.name, _stars_text(e.stars)] if e.merged else "%s bought a %s." % [opponent.name, card.name])
				else:
					_selected_market = -1
					if e.merged:
						_set_status("A second %s! Yours is now %s" % [card.name, _stars_text(e.stars)], UIKit.YELLOW)
			"train":
				Sound.play("upgrade")
				var trained: String = GameData.get_card(e.id).name
				if theirs:
					_set_status("%s trained its %s to %s" % [opponent.name, trained, _stars_text(e.stars)])
				else:
					_set_status("Your %s is now %s" % [trained, _stars_text(e.stars)], UIKit.YELLOW)
			"reroll":
				Sound.play("pop", -4.0)
				if theirs:
					_set_status("%s rerolls its shop." % opponent.name)
				else:
					_selected_market = -1
			"done":
				if theirs:
					_set_status("%s is done shopping." % opponent.name)
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
			"steal":
				Sound.play("coin")
				var thief: String = GameData.get_card(e.id).name
				if theirs:
					_set_status("%s's %s steals %d of your Acorns!" % [opponent.name, thief, e.amount], UIKit.YELLOW)
				else:
					_set_status("Your %s steals %d Acorns!" % [thief, e.amount], UIKit.YELLOW)
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
				_field.highlight = ""
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
				_field.highlight = ""
				Sound.play("upgrade" if e.winner == 0 else "pop")
				var lost: Array = e.hearts_lost
				if int(lost[0]) > 0:
					_set_status("You lose %d heart%s." % [lost[0], "" if int(lost[0]) == 1 else "s"], UIKit.HEART)
				elif int(lost[1]) > 0:
					_set_status("%s loses %d heart%s!" % [opponent.name, lost[1], "" if int(lost[1]) == 1 else "s"], UIKit.YELLOW)


func _announce_round(bonus_team: int, bonus: int) -> void:
	var extra := ""
	if bonus_team == 0:
		extra = " +%d bonus Acorns." % bonus
	elif bonus_team == 1:
		extra = " %s gets %d bonus Acorns." % [opponent.name, bonus]
	UIKit.toast("Round %d!%s" % [duel.round_number, extra])
	_set_status("Your shop: tap a card to see it, tap again to buy. Tap a herd animal to train it.")


## "★★" for 2 stars.
static func _stars_text(stars: int) -> String:
	return "★".repeat(stars)


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


# Shopping: your own Watering Hole, and training your herd.

func _draft_panel() -> void:
	var done: bool = duel.done_shopping[0]
	var who := "Waiting for %s to finish shopping..." % opponent.name if done else ("%s is shopping too." % opponent.name if not duel.done_shopping[1] else "%s is done shopping." % opponent.name)
	_heading("Your Watering Hole", "Herd %d/%d · Tools %d/%d · %s" % [duel.herds[0].size(), int(duel.rules.herd_max),
		duel.tools[0].size(), int(duel.rules.tools_max), who])
	var row := UIKit.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in duel.shops[0].size():
		row.add_child(_market_card(i))
	_panel.add_child(row)

	var herd_row := UIKit.hbox(6)
	herd_row.alignment = BoxContainer.ALIGNMENT_CENTER
	herd_row.add_child(UIKit.label("Herd", 18, UIKit.TEXT_DIM))
	for i in duel.herds[0].size():
		herd_row.add_child(_herd_chip(i, Vector2(70, 94)))
	_panel.add_child(herd_row)

	var actions := []
	if _selected_market >= 0 and int(duel.shops[0][_selected_market].taken) < 0:
		var item: Dictionary = duel.shops[0][_selected_market]
		_panel.add_child(_market_details(item))
		var problem := duel.can_buy(0, _selected_market)
		var label := "Buy for %d" % int(item.cost)
		if not item.mystery and not GameData.is_tool(item.id):
			var target := duel.merge_target(0, item.id)
			if target >= 0:
				label = "Make it %s for %d" % [_stars_text(int(duel.herds[0][target].stars) + 1), int(item.cost)]
		var buy := UIKit.button(label if problem == "" else problem, UIKit.GREEN, 22, Vector2(230, 64))
		buy.disabled = problem != ""
		buy.pressed.connect(func() -> void: _buy(_selected_market))
		actions.append(buy)
	elif _selected_herd >= 0 and _selected_herd < duel.herds[0].size():
		var entry: Dictionary = duel.herds[0][_selected_herd]
		var card := GameData.get_card(entry.id)
		var stars := int(entry.stars)
		var price := duel.train_cost(0, _selected_herd)
		var info := "%s %s" % [card.name, _stars_text(stars)]
		if price >= 0:
			info += "  ·  Train to %s: +%d%% health and bite" % [_stars_text(stars + 1), int(duel.rules.star_bonus_pct)]
		_panel.add_child(UIKit.label(info, 18, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		var problem := duel.can_train(0, _selected_herd)
		var train := UIKit.button("Train for %d" % price if problem == "" else problem, UIKit.YELLOW.darkened(0.15), 22, Vector2(230, 64))
		train.disabled = problem != ""
		train.pressed.connect(func() -> void:
			duel.train(0, _selected_herd)
		)
		actions.append(train)
	var reroll := UIKit.button("Reroll (%d)" % int(duel.rules.reroll_cost), UIKit.BLUE, 22, Vector2(150, 64))
	reroll.disabled = done or duel.acorns[0] < int(duel.rules.reroll_cost)
	reroll.pressed.connect(func() -> void: duel.reroll(0))
	actions.append(reroll)
	var finish := UIKit.button("Done", UIKit.GREY, 22, Vector2(130, 64))
	finish.disabled = done
	finish.pressed.connect(func() -> void:
		_selected_market = -1
		_selected_herd = -1
		duel.finish_shopping(0)
	)
	actions.append(finish)
	_buttons(actions)


func _market_card(slot: int) -> Control:
	var item: Dictionary = duel.shops[0][slot]
	var taken := int(item.taken)
	var card := AnimalCard.create(item.id, true)
	card.custom_minimum_size = Vector2(104, 138)
	card.info = AnimalCard.Info.NONE
	card.mystery = item.mystery and taken < 0
	card.price = int(item.cost)
	card.price_color = UIKit.ACORN if duel.acorns[0] >= int(item.cost) or taken >= 0 else UIKit.RED
	card.highlighted = slot == _selected_market
	if taken >= 0:
		card.stamp = "BOUGHT"
		card.stamp_color = UIKit.GREEN
		card.modulate = Color(1, 1, 1, 0.6)
	elif not item.mystery and duel.merge_target(0, item.id) >= 0:
		# A copy of one you have: buying it adds a star.
		card.stars = int(duel.herds[0][duel.merge_target(0, item.id)].stars) + 1
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
			var level := duel.sim.level_of(0, item.id)
			text = "%s%s  ·  %s, level %d  ·  Health %d, Bite %d\n%s: %s" % [card.name, pack, GameData.rarity_name(card.rarity), level,
				int(stats.hp), int(stats.damage), card.ability.name, card.ability.text]
			if duel.merge_target(0, item.id) >= 0:
				text += "\nYou have one: buying this gives it a star instead."
	var l := UIKit.paragraph(text, 18, UIKit.TEXT)
	return l


func _on_market_tapped(slot: int) -> void:
	if duel.phase != "draft" or int(duel.shops[0][slot].taken) >= 0:
		return
	if _selected_market == slot and duel.can_buy(0, slot) == "":
		_buy(slot)
		return
	Sound.play("select")
	_selected_market = slot
	_selected_herd = -1


func _buy(slot: int) -> void:
	var problem := duel.can_buy(0, slot)
	if problem != "":
		Sound.play("error")
		_set_status(problem, UIKit.RED.lightened(0.3))
		return
	duel.buy(0, slot)


# Placing.

func _place_panel() -> void:
	var waiting: bool = duel.ready[0]
	_heading("Place your herd", "Tap an animal, then where it should start." if not waiting else "Waiting for %s..." % opponent.name)
	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in duel.herds[0].size():
		row.add_child(_herd_chip(i, Vector2(92, 122)))
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
		_field.highlight = ""
		Sound.play("select")
		duel.set_ready(0)
	)
	_buttons([go])


func _herd_chip(index: int, chip_size: Vector2) -> Control:
	var card := AnimalCard.create(duel.herds[0][index].id, true)
	card.custom_minimum_size = chip_size
	card.info = AnimalCard.Info.NONE
	card.stars = int(duel.herds[0][index].stars)
	card.highlighted = index == _selected_herd
	UIKit.on_tap(card, func() -> void: _select_herd(index))
	return card


func _select_herd(index: int) -> void:
	if duel.phase == "draft" and not duel.done_shopping[0]:
		# While shopping, a herd animal is picked to train.
		Sound.play("select")
		_selected_herd = -1 if _selected_herd == index else index
		_selected_market = -1
		return
	if duel.phase != "place" or duel.ready[0]:
		return
	Sound.play("select")
	_selected_herd = -1 if _selected_herd == index else index
	if _selected_herd >= 0:
		var card := GameData.get_card(duel.herds[0][_selected_herd].id)
		_field.highlight = "own_half"
		_set_status("%s: tap where it should start, on your half." % card.name)
	else:
		_field.highlight = ""


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
		_field.highlight = "field" if _rally_selected else ""
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
		_field.highlight = "field" if _selected_tool >= 0 else ""
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
		var ask := UIKit.paragraph("%s raises %d! Call to keep fighting for the Pot, or fold: you give up the round and the Pot, but lose only %d hearts, nothing extra for their animals still standing." % [opponent.name, int(h.raise), duel.heart_loss(0, true)], 20, UIKit.TEXT)
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
		lines.append("You folded.")
	elif int(r.folded) == 1:
		lines.append("%s folded!" % opponent.name)
	var lost: Array = r.hearts_lost
	var standing: Array = r.standing
	if winner == 0:
		lines.append("%s loses %d heart%s (%d of your animals still standing)." % [opponent.name, lost[1], "" if int(lost[1]) == 1 else "s", standing[0]] if int(r.folded) < 0 else "%s loses %d heart%s." % [opponent.name, lost[1], "" if int(lost[1]) == 1 else "s"])
	elif winner == 1:
		lines.append("You lose %d heart%s (%d of theirs still standing)." % [lost[0], "" if int(lost[0]) == 1 else "s", standing[1]] if int(r.folded) < 0 else "You lose %d heart%s." % [lost[0], "" if int(lost[0]) == 1 else "s"])
	else:
		lines.append("Nobody loses hearts.")
	if winner == 0:
		lines.append("You won the Pot: +%d Acorns." % int(r.pot))
	elif winner == 1:
		lines.append("%s won the Pot (%d)." % [opponent.name, int(r.pot)])
	else:
		lines.append("The Pot carries over: %d." % duel.pot)
	var bet := int(r.wagers[0])
	if bet > 0:
		lines.append("The Bookie paid you %d!" % int(r.paid[0]) if int(r.paid[0]) > bet else ("The Bookie gave back your %d." % bet if int(r.paid[0]) == bet else "The Bookie kept your %d." % bet))
	if int(r.stolen[1]) > 0:
		lines.append("%s's Raccoon stole %d of your Acorns." % [opponent.name, int(r.stolen[1])])
	if duel.round_number + 1 == duel.max_rounds():
		lines.append("Last round next! Then whoever has more hearts wins.")
	for line in lines:
		_panel.add_child(UIKit.label(line, 20, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var next := UIKit.button("Next round", UIKit.GREEN, 26, Vector2(260, 68))
	next.pressed.connect(func() -> void:
		Sound.play("select")
		duel.next_round()
	)
	_buttons([next])


# --- The field -------------------------------------------------------------

func _on_field_tapped(at: Vector2i) -> void:
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
			if not DraftMatch.can_start_at(0, spot.y):
				Sound.play("error")
				_set_status("Animals start on your half of the field.", UIKit.RED.lightened(0.3))
				return
			if duel.move(0, _selected_herd, spot.x, spot.y):
				Sound.play("release", -2.0, 0.08)
				_selected_herd = -1
				_field.highlight = ""
				_set_status("Moved. Tap another animal, or press Ready.")
		"fight":
			if _rally_selected:
				if duel.rally(0, at.x, at.y):
					_field.add_events(duel.sim.take_events())
				_rally_selected = false
				_field.highlight = ""
				return
			if _selected_tool < 0:
				_set_status("Tap Rally or a tool first.")
				return
			if duel.use_tool(0, _selected_tool, at.x, at.y):
				_field.add_events(duel.sim.take_events())
				_selected_tool = -1
				_field.highlight = ""


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
	box.add_child(UIKit.label("Hearts left  %d - %d" % [duel.hearts[0], duel.hearts[1]], 26, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UIKit.label("%d rounds" % duel.round_number, 22, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UIKit.label("Stake: %s" % stake.name, 22, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var ok := UIKit.button("OK", UIKit.GREEN, 28, Vector2(220, 84))
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(_back_to_menu)
	box.add_child(ok)
	_overlay(box)


func _record(outcome: String) -> void:
	_result = Profile.record_match(outcome, int(opponent.trophies), float(stake.get("multiplier", 1.0)))
	_result["hearts"] = duel.hearts.duplicate()


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
