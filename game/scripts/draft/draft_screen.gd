extends Control
## Draft Duel against the computer opponent (the rules are in DraftMatch).
## Before the match: your starters. The field in the middle
## shows both herds for the whole match. The panel under it changes with
## each part of a round: your shop (buy, reroll, train), placing your herd,
## your Rally and tools in the fight, and the round's results.

const MENU_SCENE := "res://scenes/main.tscn"
## Moods this strong or more show over the animals when a fight starts.
const MOOD_SHOWN := 12

var duel: DraftMatch
var bot: DraftBot
var opponent: Dictionary = {}

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
var _panel_key := ""
var _result: Dictionary = {}

var _field: BattleField
## Particles over the whole screen: coins, sparkles, confetti.
var _ui_fx: ParticleLayer
var _panel_box: PanelContainer
## The part of the round the panel last showed, to animate a change.
var _panel_phase := ""
## Habitat synergies: the tracker on the left of the field (Shop and Place),
## the opponent's active habitats, and the tiers already celebrated.
var _tracker: VBoxContainer
var _tracker_key := ""
var _their_synergies: HBoxContainer
var _announced := {}
var _banner_free_at := 0.0


## A habitat badge as a control, with dots for its active tier.
class HabitatBadge:
	extends Control
	var habitat := ""
	var tier := 0

	func _init(habitat_id: String, active_tier: int, side: float) -> void:
		habitat = habitat_id
		tier = active_tier
		custom_minimum_size = Vector2(side, side)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := minf(size.x, size.y) / 2.0 - 2.0
		UIKit.draw_habitat_badge(self, size / 2.0, r, habitat, 1.0 if tier > 0 else 0.55)
		for i in tier:
			var at := Vector2(size.x / 2.0 + (i - (tier - 1) / 2.0) * r * 0.55, size.y - 2.0)
			draw_circle(at, r * 0.2 + 1.0, UIKit.INK)
			draw_circle(at, r * 0.2, UIKit.YELLOW)
var _market_cards: Array = []
var _herd_chips: Array = []
var _round_label: Label
var _phase_label: Label
var _their_acorns: PanelContainer
var _their_hearts: PanelContainer
var _their_tools: Label
var _my_acorns: PanelContainer
var _my_hearts: PanelContainer
## "+2 interest" next to your Acorns while shopping, and the win streak flames.
var _interest_label: Label
var _my_streak: Control
var _their_streak: Control
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
	_choose_starters()
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
	if not _result.is_empty():
		return
	if GameData.testing.get("infinite_acorns", false):
		# Testing switch (data/testing.json): your Acorns never run low.
		duel.acorns[0] = maxi(duel.acorns[0], int(GameData.testing.get("acorns_amount", 99)))
	_opponent_moves(delta)
	if duel.phase == "fight":
		_run_fight(delta)
	else:
		_accumulator = 0.0
	_handle_events(duel.take_events())
	_update_hud()
	_update_synergies()
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

	var theirs := UIKit.hbox(10)
	column.add_child(theirs)
	_their_hearts = UIKit.pill(GameData.ui_icon("heart"), UIKit.HEART, "0")
	theirs.add_child(_their_hearts)
	_their_acorns = UIKit.pill(GameData.ui_icon("acorn"), UIKit.ACORN, "0")
	theirs.add_child(_their_acorns)
	_their_streak = _streak_chip()
	theirs.add_child(_their_streak)
	_their_synergies = UIKit.hbox(2)
	theirs.add_child(_their_synergies)
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
	# The synergy tracker sits on the left of the field.
	_tracker = UIKit.vbox(4)
	_tracker.position = Vector2(6, 44)
	_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.add_child(_tracker)

	_status = UIKit.paragraph("", 19, UIKit.TEXT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size.y = 30
	column.add_child(_status)

	# Only as tall as each part of the round needs, so the fight gets room.
	var panel := UIKit.panel(UIKit.PANEL_DARK, 10, 18)
	column.add_child(panel)
	_panel_box = panel
	_panel = UIKit.vbox(8)
	panel.add_child(_panel)

	var bottom := UIKit.hbox(10)
	column.add_child(bottom)
	_my_hearts = UIKit.pill(GameData.ui_icon("heart"), UIKit.HEART, "0")
	bottom.add_child(_my_hearts)
	_my_acorns = UIKit.pill(GameData.ui_icon("acorn"), UIKit.ACORN, "0")
	bottom.add_child(_my_acorns)
	_interest_label = UIKit.label("", 18, Color("#ffe08a"))
	_interest_label.add_theme_constant_override("outline_size", 5)
	bottom.add_child(_interest_label)
	_my_streak = _streak_chip()
	bottom.add_child(_my_streak)
	bottom.add_child(UIKit.spacer())
	var leave := UIKit.button("Leave", UIKit.GREY.darkened(0.25), 20, Vector2(110, 56))
	leave.pressed.connect(_on_leave)
	bottom.add_child(leave)
	_update_hud()
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 10
	add_child(fx_layer)
	_ui_fx = ParticleLayer.new()
	fx_layer.add_child(_ui_fx)


## Before the first round: up to 3 of your animals to start with, within
## the Acorn budget.
func _choose_starters() -> void:
	var box := UIKit.vbox(10)
	var overlay := _overlay(box)
	var rebuild := func(again: Callable) -> void:
		for child in box.get_children():
			box.remove_child(child)
			child.queue_free()
		box.add_child(UIKit.label("Draft Duel", 40, UIKit.YELLOW, HORIZONTAL_ALIGNMENT_CENTER))
		var intro := UIKit.paragraph("Each round: shop for animals, train them up to 3 stars, place your herd and watch it fight. Save Acorns to earn interest, and win rounds in a row for a streak bonus. You both start with %d hearts; lose a fight and you lose hearts, more for every enemy animal still standing. Run out and you're out." % int(duel.rules.hearts), 19, UIKit.TEXT)
		intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(intro)
		box.add_child(UIKit.label("Pick your starters", 30, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
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
	# Dim fades in, the panel pops in.
	dim.modulate.a = 0.0
	dim.create_tween().tween_property(dim, "modulate:a", 1.0, 0.2)
	(func() -> void: UIKit.pop_in(panel, 0.8, Feel.num("ui", "panel_seconds", 0.32))).call_deferred()
	return layer


# --- Every frame -----------------------------------------------------------

func _update_hud() -> void:
	_round_label.text = "Round %d" % duel.round_number if duel.round_number > 0 else "Draft Duel"
	var phase_names := {
		"starters": "Pick your starters", "draft": "Shopping", "place": "Place your herd",
		"round_over": "Round over", "over": "Match over",
	}
	if duel.phase == "fight":
		var left := float(duel.fight_ticks - duel.fight_tick) / duel.sim.tps
		_phase_label.text = "Fight  %d:%02d" % [floori(left / 60.0), int(left) % 60]
	else:
		_phase_label.text = phase_names.get(duel.phase, "")
	_set_amount(_their_acorns, duel.acorns[1])
	_set_amount(_my_acorns, duel.acorns[0])
	for team in 2:
		if duel.hearts[team] != _hearts_shown[team]:
			var pill := _my_hearts if team == 0 else _their_hearts
			_set_amount(pill, duel.hearts[team])
			if _hearts_shown[team] >= 0 and duel.hearts[team] < _hearts_shown[team]:
				_bump(pill)
				var at := pill.get_global_rect().get_center()
				_ui_fx.burst("spark", at, 10, 260.0, 0.35, 8.0, [UIKit.HEART, Color("#ffd0d8")], 0.0, 5.0)
				_ui_fx.burst("star", at, 3, 160.0, 0.5, 7.0, [UIKit.HEART], 400.0, 1.5, 120.0)
			_hearts_shown[team] = duel.hearts[team]
	var their_tools: int = duel.tools[1].size()
	_their_tools.text = "%s  ·  %d tool%s hidden" % [opponent.name, their_tools, "" if their_tools == 1 else "s"]
	# Interest: what you'd earn if you stopped spending now.
	var shopping: bool = duel.phase in ["draft", "place"]
	var interest := duel.interest_on(0)
	_interest_label.text = "+%d interest" % interest if shopping and interest > 0 else ""
	_set_streak(_my_streak, duel.streak[0])
	_set_streak(_their_streak, duel.streak[1])


## A little flame with the number of rounds won in a row (hidden until 2).
func _streak_chip() -> Control:
	var chip := UIKit.hbox(2)
	chip.add_child(UIKit.icon_rect(GameData.ui_icon("flame"), Color("#ff8a2b"), 26))
	var count := UIKit.label("", 20, Color("#ffb347"))
	count.name = "Count"
	count.add_theme_constant_override("outline_size", 5)
	chip.add_child(count)
	chip.visible = false
	chip.tooltip_text = "Win streak"
	return chip


func _set_streak(chip: Control, wins: int) -> void:
	var active := wins >= int(duel.rules.win_streak_from)
	if active and not chip.visible:
		chip.visible = true
		(func() -> void: UIKit.pop_in(chip, 0.4, 0.35)).call_deferred()
	chip.visible = active
	(chip.find_child("Count", true, false) as Label).text = str(wins)


# --- Habitat synergies ---------------------------------------------------------

## Keeps the tracker, the opponent's badges and the tier celebrations up to
## date. Rebuilds only when something it shows has changed.
func _update_synergies() -> void:
	var shopping: bool = duel.phase in ["draft", "place"]
	var preview := ""
	if duel.phase == "draft" and _selected_market >= 0 and _selected_market < duel.shops[0].size():
		var item: Dictionary = duel.shops[0][_selected_market]
		if int(item.taken) < 0 and not GameData.is_tool(item.id) and duel.merge_target(0, item.id) < 0:
			var owned: bool = duel.herds[0].any(func(e): return e.id == item.id)
			if not owned:
				preview = Synergies.habitat_of(item.id)
	var counts := Synergies.counts(duel.herds[0])
	var theirs := Synergies.active(duel.herds[1])
	var key := str([shopping, counts, preview, theirs])
	if key != _tracker_key:
		_tracker_key = key
		_build_tracker(counts, preview, shopping)
		for child in _their_synergies.get_children():
			child.queue_free()
		for habitat in GameData.habitat_order:
			if theirs.has(habitat):
				_their_synergies.add_child(HabitatBadge.new(habitat, int(theirs[habitat]), 30))
	# Celebrate each tier the first time it turns on this match.
	if duel.phase in ["draft", "place", "starters"]:
		var mine := Synergies.active(duel.herds[0])
		for habitat in mine:
			if int(mine[habitat]) > int(_announced.get(habitat, 0)):
				_announced[habitat] = int(mine[habitat])
				_celebrate_synergy(habitat, int(mine[habitat]))


func _build_tracker(counts: Dictionary, preview: String, shopping: bool) -> void:
	for child in _tracker.get_children():
		_tracker.remove_child(child)
		child.queue_free()
	_tracker.visible = shopping
	if not shopping:
		return
	var habitats := GameData.habitat_order.filter(func(h): return counts.has(h) or h == preview)
	# Active tiers first, then the closest to their next tier.
	habitats.sort_custom(func(a, b):
		var ta := Synergies.tier_for(int(counts.get(a, 0)))
		var tb := Synergies.tier_for(int(counts.get(b, 0)))
		if ta != tb:
			return ta > tb
		return int(counts.get(a, 0)) > int(counts.get(b, 0))
	)
	for habitat in habitats:
		_tracker.add_child(_tracker_chip(habitat, int(counts.get(habitat, 0)), habitat == preview))


## One line of the tracker: badge, name and progress, e.g. "Savanna 3/4".
func _tracker_chip(habitat: String, count: int, preview: bool) -> Control:
	var info := Synergies.info(habitat)
	var color := Color(String(info.color))
	var tier := Synergies.tier_for(count)
	var chip := PanelContainer.new()
	var style := UIKit.box(Color(color.darkened(0.45), 0.92) if tier > 0 else Color(UIKit.INK, 0.72), 14, 3)
	style.content_margin_left = 4
	style.content_margin_right = 10
	style.set_border_width_all(2)
	style.border_color = color if tier > 0 else Color(color, 0.45)
	chip.add_theme_stylebox_override("panel", style)
	var row := UIKit.hbox(4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	row.add_child(HabitatBadge.new(habitat, tier, 30))
	var text := "%s %d/%d" % [info.name, count, Synergies.next_needed(count)]
	if preview:
		text = "%s %d+1/%d" % [info.name, count, Synergies.next_needed(count + 1)]
	var label := UIKit.label(text, 16, UIKit.YELLOW if preview else (Color.WHITE if tier > 0 else UIKit.TEXT_DIM))
	label.add_theme_constant_override("outline_size", 4)
	row.add_child(label)
	UIKit.on_tap(chip, func() -> void: _show_synergy(habitat, count))
	return chip


## The tapped habitat's bonus at each tier, with yours highlighted.
func _show_synergy(habitat: String, count: int) -> void:
	var info := Synergies.info(habitat)
	var box := UIKit.vbox(8)
	box.add_child(UIKit.paragraph("You have %d different %s animal%s in your herd. Copies of the same animal count once." % [count, info.name, "" if count == 1 else "s"], 20, UIKit.TEXT))
	var tier := Synergies.tier_for(count)
	var tiers: Array = GameData.synergy_tiers
	for i in tiers.size():
		var on := tier == i + 1
		var line := UIKit.paragraph("%d animals: %s" % [int(tiers[i]), Synergies.describe(habitat, i + 1)], 21, UIKit.YELLOW if on else (UIKit.TEXT if tier > i else UIKit.TEXT_DIM))
		box.add_child(line)
	Modal.open(box, "%s synergy" % info.name)


## A tier just turned on: a bouncy pop-up, a sting, and a glow on the
## animals that are part of it.
func _celebrate_synergy(habitat: String, tier: int) -> void:
	var info := Synergies.info(habitat)
	var color := Color(String(info.color))
	Sound.play("synergy")
	_banner("%s x%d!" % [String(info.name).to_upper(), int(GameData.synergy_tiers[tier - 1])], color.lightened(0.25),
		Feel.count("celebrations", "synergy_text_size", 44), Synergies.describe(habitat, tier))
	for view in _field.views():
		if view.team == 0 and view.habitat == habitat:
			view.glow(color.lightened(0.2), Feel.num("celebrations", "synergy_glow_seconds", 1.4))


# --- Big moments --------------------------------------------------------------

## Herd animal `index` just reached 3 stars: a slow-motion close-up, stars
## and confetti, a sound sting and a bouncy 3 STARS!
func _celebrate_three_stars(index: int, animal_name: String) -> void:
	var c := "celebrations"
	var key := "0/%d/0" % index
	if _field.celebrate(key):
		Sound.play("whoosh", -4.0)
	Sound.play("star3")
	var view := _field.view_for_key(key)
	if view != null:
		var at := view.position + Vector2(0, -UnitSprites.top(view.id) * view.body.k * 0.5)
		_field.fx.burst("star", at, Feel.count(c, "star3_stars", 22), 260.0, 0.9, 9.0, [Color("#ffe14d"), Color("#ffb03b"), Color.WHITE], 380.0, 1.2, 180.0)
		_field.fx.burst_confetti(at, Feel.count(c, "star3_confetti", 36))
	_banner("3 STARS!", Color("#ffe14d"), Feel.count(c, "star3_text_size", 64), animal_name)


## Smaller celebrations after a round you won: a comeback (at few hearts)
## and a flawless round (no animals lost).
func _celebrate_round() -> void:
	var c := "celebrations"
	var r := duel.last_round
	var lost: Array = r.get("animals_lost", [1, 1])
	var at := _field.get_global_rect().get_center()
	var delay := 0.0
	if duel.hearts[0] <= Feel.count(c, "comeback_hearts", 5):
		_banner("COMEBACK!", Color("#ff9f43"), Feel.count(c, "banner_size", 54), "Still in it!")
		_ui_fx.burst_confetti(at, Feel.count(c, "comeback_confetti", 30))
		Sound.play("fanfare")
		delay = 1.0
	if int(lost[0]) == 0 and not duel.herds[0].is_empty():
		var show_flawless := func() -> void:
			_banner("FLAWLESS!", Color("#7fe0ff"), Feel.count(c, "banner_size", 54), "Not a single animal lost")
			_ui_fx.burst("sparkle", at, Feel.count(c, "flawless_sparkles", 18), 260.0, 0.8, 10.0, [Color.WHITE, Color("#bff0ff"), Color("#ffe14d")], -40.0, 2.0)
			Sound.play("fanfare", 2.0)
		if delay > 0.0:
			get_tree().create_timer(delay).timeout.connect(show_flawless)
		else:
			show_flawless.call()


## Big bouncy words over the field, with a small line under them.
func _banner(text: String, color: Color, font_size: int, subtitle := "") -> void:
	# One banner at a time: a second one waits its turn.
	var now := Time.get_ticks_msec() / 1000.0
	var wait := _banner_free_at - now
	_banner_free_at = maxf(now, _banner_free_at) + Feel.num("celebrations", "banner_seconds", 1.4) * 0.8
	if wait > 0.0:
		get_tree().create_timer(wait).timeout.connect(_show_banner.bind(text, color, font_size, subtitle))
	else:
		_show_banner(text, color, font_size, subtitle)


func _show_banner(text: String, color: Color, font_size: int, subtitle := "") -> void:
	var holder := VBoxContainer.new()
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := UIKit.label(text, font_size, color, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_constant_override("outline_size", maxi(8, font_size / 5))
	title.add_theme_color_override("font_outline_color", UIKit.INK)
	title.add_theme_constant_override("shadow_offset_y", 5)
	holder.add_child(title)
	if subtitle != "":
		var sub := UIKit.paragraph(subtitle, 22, Color.WHITE)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_constant_override("outline_size", 6)
		holder.add_child(sub)
	_ui_fx.get_parent().add_child(holder)
	var field_rect := _field.get_global_rect()
	holder.size = Vector2(field_rect.size.x, 0)
	holder.reset_size()
	holder.position = Vector2(field_rect.position.x, field_rect.position.y + field_rect.size.y * 0.3)
	holder.size.x = field_rect.size.x
	holder.pivot_offset = holder.size / 2.0
	holder.scale = Vector2(0.2, 0.2)
	var seconds := Feel.num("celebrations", "banner_seconds", 1.4)
	var tween := holder.create_tween()
	tween.tween_property(holder, "scale", Vector2(1.15, 1.15), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(holder, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(maxf(0.1, seconds - 0.7))
	tween.set_parallel()
	tween.tween_property(holder, "modulate:a", 0.0, 0.3)
	tween.tween_property(holder, "position:y", holder.position.y - 40.0, 0.3)
	tween.chain().tween_callback(holder.queue_free)


## The middle of one of the panel's cards on screen (or the screen's middle).
func _chip_center(chips: Array, index: int) -> Vector2:
	if index >= 0 and index < chips.size() and is_instance_valid(chips[index]):
		return (chips[index] as Control).get_global_rect().get_center()
	return get_viewport_rect().size / 2.0


func _set_amount(pill: PanelContainer, amount: int) -> void:
	(pill.find_child("Amount", true, false) as Label).text = str(amount)


## A quick throb, red, when a pill's number drops.
func _bump(pill: Control) -> void:
	pill.pivot_offset = pill.size / 2.0
	var tween := pill.create_tween()
	var bump := Feel.num("ui", "pill_bump", 1.22)
	tween.tween_property(pill, "scale", Vector2(bump, bump), 0.12).set_trans(Tween.TRANS_BACK)
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
		_selected_market, _selected_herd, _selected_tool, _rally_selected, duel.rally_ready[0], _fast, duel.ready,
		])


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
				_bot_wait = _rng.randf_range(0.6, 1.0)


func _run_fight(delta: float) -> void:
	if _field.is_frozen():
		return  # hit-stop: the fight holds still for a moment
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
				_announce_round(int(e.bonus_team), int(e.bonus), int(e.streak_bonus[0]))
				_bot_wait = 1.2
			"buy":
				Sound.play("upgrade" if e.merged else "coin")
				var card := GameData.get_card(e.id)
				if theirs:
					_set_status("%s's %s is now %s" % [opponent.name, card.name, _stars_text(e.stars)] if e.merged else "%s bought %s %s." % [opponent.name, "an" if String(card.name)[0] in "AEIOU" else "a", card.name])
				else:
					_selected_market = -1
					if e.merged:
						_set_status("A second %s! Yours is now %s" % [card.name, _stars_text(e.stars)], UIKit.YELLOW)
						if int(e.stars) >= int(duel.rules.star_max):
							_celebrate_three_stars(int(e.index), card.name)
			"train":
				Sound.play("upgrade")
				var trained: String = GameData.get_card(e.id).name
				if theirs:
					_set_status("%s trained its %s to %s" % [opponent.name, trained, _stars_text(e.stars)])
				else:
					_set_status("Your %s is now %s" % [trained, _stars_text(e.stars)], UIKit.YELLOW)
					if int(e.stars) >= int(duel.rules.star_max):
						_celebrate_three_stars(int(e.index), trained)
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
			"round_over":
				_selected_tool = -1
				_rally_selected = false
				_field.highlight = ""
				Sound.play("upgrade" if e.winner == 0 else "pop")
				if e.winner == 0:
					var field_rect := _field.get_global_rect()
					var half := Feel.count("effects", "win_confetti", 60) / 2
					_ui_fx.burst_confetti(field_rect.position + Vector2(field_rect.size.x * 0.25, field_rect.size.y * 0.35), half)
					_ui_fx.burst_confetti(field_rect.position + Vector2(field_rect.size.x * 0.75, field_rect.size.y * 0.35), half)
				if e.winner == 0:
					_celebrate_round()
				var lost: Array = e.hearts_lost
				if int(lost[0]) > 0:
					_set_status("You lose %d heart%s." % [lost[0], "" if int(lost[0]) == 1 else "s"], UIKit.HEART)
				elif int(lost[1]) > 0:
					_set_status("%s loses %d heart%s!" % [opponent.name, lost[1], "" if int(lost[1]) == 1 else "s"], UIKit.YELLOW)


func _announce_round(bonus_team: int, bonus: int, streak_paid: int) -> void:
	var extra := ""
	if bonus_team == 0:
		extra = " +%d bonus Acorns." % bonus
	elif bonus_team == 1:
		extra = " %s gets %d bonus Acorns." % [opponent.name, bonus]
	if streak_paid > 0:
		extra += " Win streak: +%d Acorns!" % streak_paid
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
	if duel.phase != _panel_phase:
		# A new part of the round: the panel springs in.
		_panel_phase = duel.phase
		(func() -> void: UIKit.pop_in(_panel_box, 0.92, Feel.num("ui", "panel_seconds", 0.32))).call_deferred()
	match duel.phase:
		"draft":
			_draft_panel()
		"place":
			_place_panel()
		"fight":
			_fight_panel()
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
	_market_cards.clear()
	for i in duel.shops[0].size():
		var card := _market_card(i)
		_market_cards.append(card)
		row.add_child(card)
	_panel.add_child(row)

	var herd_row := UIKit.hbox(6)
	herd_row.alignment = BoxContainer.ALIGNMENT_CENTER
	herd_row.add_child(UIKit.label("Herd", 18, UIKit.TEXT_DIM))
	_herd_chips.clear()
	for i in duel.herds[0].size():
		var chip := _herd_chip(i, Vector2(70, 94))
		_herd_chips.append(chip)
		herd_row.add_child(chip)
	_panel.add_child(herd_row)

	var actions := []
	if _selected_market >= 0 and int(duel.shops[0][_selected_market].taken) < 0:
		var item: Dictionary = duel.shops[0][_selected_market]
		_panel.add_child(_market_details(item))
		var problem := duel.can_buy(0, _selected_market)
		var label := "Buy for %d" % int(item.cost)
		if not GameData.is_tool(item.id):
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
			var at := _chip_center(_herd_chips, _selected_herd)
			if duel.train(0, _selected_herd):
				_ui_fx.burst("sparkle", at, Feel.count("effects", "upgrade_sparkles", 14), 220.0, 0.7, 10.0, [Color("#ffe14d"), Color.WHITE], -80.0, 2.5)
				_ui_fx.burst("star", at, 4, 200.0, 0.7, 9.0, [Color("#ffe14d")], 500.0, 1.2, 160.0)
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
	card.price = int(item.cost)
	card.price_color = UIKit.ACORN if duel.acorns[0] >= int(item.cost) or taken >= 0 else UIKit.RED
	card.highlighted = slot == _selected_market
	if taken >= 0:
		card.stamp = "BOUGHT"
		card.stamp_color = UIKit.GREEN
		card.modulate = Color(1, 1, 1, 0.6)
	elif duel.merge_target(0, item.id) >= 0:
		# A copy of one you have: buying it adds a star.
		card.stars = int(duel.herds[0][duel.merge_target(0, item.id)].stars) + 1
	UIKit.on_tap(card, func() -> void: _on_market_tapped(slot))
	return card


## What the picked card does: its stats and ability.
func _market_details(item: Dictionary) -> Control:
	var text := ""
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
	return UIKit.paragraph(text, 18, UIKit.TEXT)


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
	var at := _chip_center(_market_cards, slot)
	duel.buy(0, slot)
	_ui_fx.burst_coins(at, Feel.count("effects", "coin_burst", 8))
	_ui_fx.burst("sparkle", at, 6, 160.0, 0.5, 8.0, [Color.WHITE, Color("#fff3a8")], -40.0, 3.0)


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


# The fight.

func _fight_panel() -> void:
	_heading("Fight!", "Tap Rally or a tool, then the field", "tab_battle")
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


# The round's results.

func _round_panel() -> void:
	var r := duel.last_round
	var winner := int(r.winner)
	var title := "You won round %d!" % int(r.round) if winner == 0 else ("%s won round %d" % [opponent.name, int(r.round)] if winner == 1 else "Round %d: a tie" % int(r.round))
	_heading(title, "", "trophy" if winner == 0 else "")
	var lines := []
	var lost: Array = r.hearts_lost
	var standing: Array = r.standing
	if winner == 0:
		lines.append("%s loses %d heart%s (%d of your animals still standing)." % [opponent.name, lost[1], "" if int(lost[1]) == 1 else "s", standing[0]])
		lines.append("%s gets %d bonus Acorns next round." % [opponent.name, int(duel.rules.loser_bonus)])
	elif winner == 1:
		lines.append("You lose %d heart%s (%d of theirs still standing)." % [lost[0], "" if int(lost[0]) == 1 else "s", standing[1]])
		lines.append("You get %d bonus Acorns next round." % int(duel.rules.loser_bonus))
	else:
		lines.append("Nobody loses hearts.")
	if int(r.stolen[1]) > 0:
		lines.append("%s's Raccoon stole %d of your Acorns." % [opponent.name, int(r.stolen[1])])
	var interest: Array = r.get("interest", [0, 0])
	if int(interest[0]) > 0:
		lines.append("Interest on your savings: +%d Acorns." % int(interest[0]))
	var wins := int(duel.streak[0])
	if duel.streak_bonus(wins) > 0:
		lines.append("Win streak %d: +%d Acorns next round!" % [wins, duel.streak_bonus(wins)])
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
	if outcome == "win" and duel.hearts[0] <= Feel.count("celebrations", "comeback_hearts", 5):
		titles.win = "Comeback Victory!"
	var colors := {"win": UIKit.YELLOW, "loss": UIKit.RED, "draw": UIKit.TEXT}
	box.add_child(UIKit.label(titles[outcome], 52, colors[outcome], HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UIKit.label("Hearts left  %d - %d" % [duel.hearts[0], duel.hearts[1]], 26, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UIKit.label("%d rounds" % duel.round_number, 22, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var ok := UIKit.button("OK", UIKit.GREEN, 28, Vector2(220, 84))
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(_back_to_menu)
	box.add_child(ok)
	_overlay(box)
	if outcome == "win":
		# A shower of confetti and coins for the winner.
		var screen_size := get_viewport_rect().size
		for i in 3:
			_ui_fx.burst_confetti(Vector2(screen_size.x * (0.2 + 0.3 * i), screen_size.y * 0.3), Feel.count("effects", "win_confetti", 60) / 2)
		_ui_fx.burst_coins(screen_size / 2.0 + Vector2(0, -120), Feel.count("effects", "coin_burst", 8) * 2)


func _record(outcome: String) -> void:
	_result = Profile.record_match(outcome, int(opponent.trophies))
	_result["hearts"] = duel.hearts.duplicate()


func _back_to_menu() -> void:
	Profile.pending_match_result = _result
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_leave() -> void:
	Modal.confirm("Leave the match? It counts as a loss.", "Leave", _leave_now, UIKit.RED)


func _leave_now() -> void:
	if _result.is_empty():
		_record("loss")
	_back_to_menu()
