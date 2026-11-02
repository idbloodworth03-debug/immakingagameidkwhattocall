extends Control
## Draft Duel against the computer opponent (the rules are in DraftMatch).
## Before the match: your starters. The field in the middle
## shows both herds for the whole match. The panel under it changes with
## each part of a round: your shop (buy, reroll, train), placing your herd,
## your Rally and tools in the fight, and the round's results.

const MENU_SCENE := "res://scenes/main.tscn"
## Card sizes in the shop panel (three to a row) and herd slots (six), and
## a little shorter on short screens (like an iPhone SE) so the field keeps
## some room.
const SHOP_CARD := Vector2(204, 150)
const HERD_SLOT := Vector2(100, 96)
const SHORT_SCREEN := 1400.0
const SHOP_CARD_SHORT := Vector2(204, 124)
const HERD_SLOT_SHORT := Vector2(100, 80)
## Draws popups above the field (flying animals sit a step higher).
const OVER_FIELD := 10
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
var _their_hearts: ValuePill
var _my_acorns: ValuePill
var _my_hearts: ValuePill
## The win streak flames: yours by your pills, theirs on their badge.
var _my_streak: Control
var _their_streak: Control
var _hearts_shown := [-1, -1]
## Short messages pop up over the bottom of the field, then fade.
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
## The rival's badge (portrait, name, level, a check once they're done),
## and when their next emote bubble may show.
var _their_badge: PanelContainer
var _rival_portrait: RangerPortrait
var _rival_check: Control
## Which shop the cards show: they pop in one by one when it changes.
var _shop_key := ""
var _lifted := -1
var _emote_free_at := 0.0
var _big_hit_round := -1
var _panel: VBoxContainer


func _ready() -> void:
	theme = UIStyle.theme()
	_rng.randomize()
	# You draft from the cards you own, and they fight at your levels. The
	# opponent's cards are about as leveled as yours.
	# Your opponent is a Rival Ranger from your arena (or its boss, when a
	# win would take you up), with their own way of playing (see Opponents).
	opponent = Opponents.next_for_player(_rng)
	var pool := DraftMatch.pool_from_collection(Profile.has_card)
	duel = DraftMatch.new(_rng.randi(), {"levels": [Profile.card_levels(), _opponent_levels(pool, Opponents.level_drop(opponent))], "pool": pool})
	bot = DraftBot.new(duel, 1, _rng.randi(), float(opponent.difficulty), opponent.get("style", {}))
	_build()
	Sound.play_music("battle")
	var intro := VersusIntro.create(opponent)
	intro.finished.connect(_choose_starters)
	intro.z_index = OVER_FIELD
	add_child(intro)


## Levels for the opponent's cards: each rarity's starting level, plus as
## many levels as the player's cards have on average, minus `drop`.
static func _opponent_levels(pool: Array, drop := 0) -> Dictionary:
	var above := 0.0
	for id in pool:
		above += Profile.card_level(id) - GameData.start_level(GameData.cards[id].rarity)
	var offset := roundi(above / maxf(1.0, pool.size()))
	var levels := {}
	for id in pool:
		levels[id] = clampi(GameData.start_level(GameData.cards[id].rarity) + offset - drop, 1, int(GameData.progression.card_max_level))
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
	add_child(UIStyle.backdrop())
	var safe := UIStyle.safe_margins(get_viewport())
	var margin := UIStyle.num("screen", "margin", 16)
	var column := UIStyle.vbox("xs")
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = margin
	column.offset_right = -margin
	column.offset_top = margin * 0.5 + float(safe.top)
	column.offset_bottom = -margin * 0.5 - float(safe.bottom)
	add_child(column)

	# Top: the rival, the round, and the rival's hearts.
	var top := UIStyle.hbox("xs")
	column.add_child(top)
	_their_badge = _rival_badge()
	top.add_child(_their_badge)
	_round_label = UIStyle.label("", "body", Color(0, 0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER)
	var round_chip := UIStyle.chip(_round_label)
	round_chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	round_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(round_chip)
	_their_hearts = UIStyle.pill("heart", UIStyle.color("heart"), duel.hearts[1])
	_their_hearts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_their_hearts)

	_field = BattleField.new()
	_field.sim = duel.sim
	_field.grass = Color(GameData.get_arena(Profile.arena_index()).color)
	_field.arena_id = GameData.get_arena(Profile.arena_index()).id
	_field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field.tapped.connect(_on_field_tapped)
	_field.strong_hit.connect(_on_strong_hit)
	column.add_child(_field)
	# The synergy tracker sits on the left of the field.
	_tracker = UIStyle.vbox("xs")
	_tracker.position = Vector2(UIStyle.space("xs"), UIStyle.space("s"))
	_field.add_child(_tracker)
	_toast_label = UIStyle.label("", "small", Color(0, 0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER)
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast = UIStyle.chip(_toast_label, Color(UIStyle.color("outline"), 0.0))
	_toast.add_theme_stylebox_override("panel", UIStyle.chip_box(UIStyle.color("outline").lightened(0.12)))
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.add_child(_toast)

	# Only as tall as each part of the round needs, so the fight gets room.
	var panel := UIStyle.panel()
	column.add_child(panel)
	_panel_box = panel
	_panel = UIStyle.vbox("s")
	panel.add_child(_panel)

	# Bottom: your hearts and Acorns (with the interest they'd earn), your
	# streak, and a way out.
	var bottom := UIStyle.hbox("xs")
	column.add_child(bottom)
	_my_hearts = UIStyle.pill("heart", UIStyle.color("heart"), duel.hearts[0])
	_my_hearts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(_my_hearts)
	_my_acorns = UIStyle.pill("acorn", UIStyle.color("acorn").lightened(0.15), duel.acorns[0])
	_my_acorns.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(_my_acorns)
	_my_streak = _streak_chip()
	bottom.add_child(_my_streak)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(gap)
	var leave := UIStyle.icon_button("exit", "danger")
	leave.pressed.connect(_on_leave)
	bottom.add_child(leave)
	_hearts_shown = [duel.hearts[0], duel.hearts[1]]
	_update_hud()
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 10
	add_child(fx_layer)
	_ui_fx = ParticleLayer.new()
	fx_layer.add_child(_ui_fx)


## The rival's badge: portrait, name and level (or BOSS), with their win
## streak and active habitats tucked beside the level, and a check over the
## portrait once they're done shopping or placing.
func _rival_badge() -> PanelContainer:
	var row := UIStyle.hbox("xs")
	var side := 76.0
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(side, side)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rival_portrait = RangerPortrait.create(opponent, side)
	holder.add_child(_rival_portrait)
	_rival_check = _CheckBadge.new()
	_rival_check.custom_minimum_size = Vector2(34, 34)
	_rival_check.size = Vector2(34, 34)
	_rival_check.position = Vector2(side - 28, side - 30)
	_rival_check.visible = false
	holder.add_child(_rival_check)
	row.add_child(holder)
	var words := UIStyle.vbox("xs")
	words.add_theme_constant_override("separation", 0)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_label := UIStyle.label(opponent.name, "body")
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size.x = 196
	words.add_child(name_label)
	var tags := UIStyle.hbox("xs")
	var boss: bool = opponent.get("boss", false)
	var tag := UIStyle.chip(UIStyle.label("BOSS" if boss else "Lv %d" % int(opponent.level), "small"), UIStyle.color("gold") if boss else UIStyle.color("chip").darkened(0.15))
	tags.add_child(tag)
	_their_streak = _streak_chip()
	tags.add_child(_their_streak)
	_their_synergies = UIStyle.hbox("xs")
	_their_synergies.add_theme_constant_override("separation", 2)
	tags.add_child(_their_synergies)
	words.add_child(tags)
	row.add_child(words)
	var badge := UIStyle.chip(row)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return badge


## A green check mark in a circle.
class _CheckBadge:
	extends Control

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0
		var ink := UIStyle.color("outline")
		draw_circle(c + Vector2(0, 2), r, Color(ink, 0.4))
		draw_circle(c, r, ink)
		draw_circle(c, r - 3.0, UIStyle.color("primary"))
		var check := UIKit.icon(GameData.ui_icon("check"))
		if check != null:
			draw_texture_rect(check, Rect2(c - Vector2(r, r) * 0.62, Vector2(r, r) * 1.24), false)


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
				get_tree().create_timer(0.7).timeout.connect(func() -> void: _rival_says("start"))
		)
		box.add_child(go)
	rebuild.call(rebuild)


## A dimmed full-screen layer with a panel in the middle holding `content`.
func _overlay(content: Control) -> Control:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.z_index = OVER_FIELD  # above flying animals
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
	var phase_names := {"starters": "Starters", "draft": "Shop", "place": "Place", "round_over": "Results", "over": "Done"}
	var phase: String = phase_names.get(duel.phase, "")
	if duel.phase == "fight":
		var left := float(duel.fight_ticks - duel.fight_tick) / duel.sim.tps
		phase = "%d:%02d" % [floori(left / 60.0), int(left) % 60]
	_round_label.text = "Round %d · %s" % [duel.round_number, phase] if duel.round_number > 0 else "Draft Duel"
	_my_acorns.set_value(duel.acorns[0])
	for team in 2:
		if duel.hearts[team] != _hearts_shown[team]:
			var pill := _my_hearts if team == 0 else _their_hearts
			var lost: bool = duel.hearts[team] < _hearts_shown[team]
			pill.set_value(duel.hearts[team])
			if lost:
				var at := pill.get_global_rect().get_center()
				_ui_fx.burst("spark", at, 10, 260.0, 0.35, 8.0, [UIStyle.color("heart"), Color("#ffd0d8")], 0.0, 5.0)
				_ui_fx.burst("star", at, 3, 160.0, 0.5, 7.0, [UIStyle.color("heart")], 400.0, 1.5, 120.0)
			_hearts_shown[team] = duel.hearts[team]
	# Interest: what you'd earn if you stopped spending now.
	var shopping: bool = duel.phase in ["draft", "place"]
	var interest := duel.interest_on(0)
	_my_acorns.set_extra("+%d" % interest if shopping and interest > 0 else "")
	var their_turn_done: bool = (duel.phase == "draft" and duel.done_shopping[1]) or (duel.phase == "place" and duel.ready[1])
	if their_turn_done != _rival_check.visible:
		_rival_check.visible = their_turn_done
		if their_turn_done:
			(func() -> void: UIKit.pop_in(_rival_check, 0.3, 0.3)).call_deferred()
	_set_streak(_my_streak, duel.streak[0])
	_set_streak(_their_streak, duel.streak[1])


## A little flame with the number of rounds won in a row (hidden until 2).
func _streak_chip() -> Control:
	var chip := UIStyle.hbox("xs")
	chip.add_theme_constant_override("separation", 0)
	chip.add_child(UIStyle.icon("flame", UIStyle.color("flame"), 36))
	var count := UIStyle.label("", "small", UIStyle.color("gold"))
	count.name = "Count"
	chip.add_child(count)
	chip.visible = false
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
				_their_synergies.add_child(HabitatBadge.new(habitat, int(theirs[habitat]), 36))
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


## One pill of the tracker: the habitat's badge and progress, e.g. "Savanna
## 3/4". Lit in the habitat's color once a tier is on.
func _tracker_chip(habitat: String, count: int, preview: bool) -> Control:
	var info := Synergies.info(habitat)
	var tier := Synergies.tier_for(count)
	var row := UIStyle.hbox("xs")
	row.add_child(HabitatBadge.new(habitat, tier, 40))
	var text := "%s %d/%d" % [info.name, count, Synergies.next_needed(count)]
	if preview:
		text = "%s %d+1/%d" % [info.name, count, Synergies.next_needed(count + 1)]
	row.add_child(UIStyle.label(text, "small", UIStyle.color("gold") if preview else Color(0, 0, 0, 0)))
	var base := Color(String(info.color)).darkened(0.1) if tier > 0 else UIStyle.color("chip")
	var chip := UIStyle.chip(row, base)
	chip.modulate.a = 1.0 if tier > 0 or preview else 0.88
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


# --- The rival's reactions -------------------------------------------------

## The rival reacts with one of their emotes (rivals.json) in a bubble by
## their badge, and their face changes for a moment: at the start, on a big
## hit, and when a round goes their way or not. One at a time, and not too
## often (feel.json "rivals").
func _rival_says(moment: String) -> bool:
	var emote := GameData.find_by_id(GameData.emotes, opponent.get("emotes", {}).get(moment, ""))
	var now := Time.get_ticks_msec() / 1000.0
	if emote.is_empty() or now < _emote_free_at or _their_badge == null or not _result.is_empty():
		return false
	var seconds := Feel.num("rivals", "emote_seconds", 2.4)
	_emote_free_at = now + maxf(seconds, Feel.num("rivals", "emote_gap_seconds", 5.0))
	Sound.play("emote", -2.0)
	var portrait := _rival_portrait
	portrait.mood = {"winning": "happy", "big_hit": "happy", "losing": "sad"}.get(moment, "normal")
	portrait.pivot_offset = portrait.size / 2.0
	var bounce := portrait.create_tween()
	bounce.tween_property(portrait, "scale", Vector2(1.18, 0.88), 0.08)
	bounce.tween_property(portrait, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	bounce.tween_interval(maxf(0.0, seconds - 0.5))
	bounce.tween_callback(func() -> void: portrait.mood = "normal")

	var bubble := _emote_bubble(emote)
	bubble.z_index = OVER_FIELD
	add_child(bubble)
	bubble.reset_size()
	var anchor := portrait.get_global_rect()
	bubble.position = Vector2(anchor.position.x + anchor.size.x * 0.55, anchor.end.y - 4.0)
	bubble.position.x = minf(bubble.position.x, get_viewport_rect().size.x - bubble.size.x - 6.0)
	bubble.pivot_offset = Vector2(12, 0)
	bubble.scale = Vector2(0.2, 0.2)
	var tween := bubble.create_tween()
	tween.tween_property(bubble, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(maxf(0.2, seconds - 0.55))
	tween.tween_property(bubble, "modulate:a", 0.0, 0.25)
	tween.tween_callback(bubble.queue_free)
	return true


## A speech bubble with an emote's picture and caption.
func _emote_bubble(emote: Dictionary) -> Control:
	var style := UIKit.box(Color.WHITE, 18, 6)
	style.corner_radius_top_left = 4
	style.content_margin_left = 8
	style.content_margin_right = 14
	style.set_border_width_all(3)
	style.border_color = UIKit.INK
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", style)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UIKit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(row)
	var art := IconArt.make(GameData.emote_icon(emote.id), Color(emote.get("color", "#888888")))
	art.custom_minimum_size = Vector2(46, 46)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art)
	var caption := UIKit.label(emote.get("caption", ""), 24, UIKit.INK)
	caption.add_theme_constant_override("outline_size", 0)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(caption)
	return bubble


## The rival cheers their own big hits (once a round).
func _on_strong_hit(team: int) -> void:
	if team == bot.team and _big_hit_round != duel.round_number and _rival_says("big_hit"):
		_big_hit_round = duel.round_number


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
				var card := GameData.get_card(e.id)
				if not theirs:
					Sound.play("upgrade" if e.merged else "coin")
					_selected_market = -1
					if e.merged:
						_set_status("%s is now %s" % [card.name, _stars_text(e.stars)], UIStyle.color("gold"))
						if int(e.stars) >= int(duel.rules.star_max):
							_celebrate_three_stars(int(e.index), card.name)
			"train":
				var trained: String = GameData.get_card(e.id).name
				if not theirs:
					Sound.play("upgrade")
					_set_status("%s is now %s" % [trained, _stars_text(e.stars)], UIStyle.color("gold"))
					if int(e.stars) >= int(duel.rules.star_max):
						_celebrate_three_stars(int(e.index), trained)
			"reroll":
				if not theirs:
					Sound.play("pop", -4.0)
					_selected_market = -1
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
				if not duel.is_over() and e.winner != DraftMatch.NO_WINNER:
					_rival_says("losing" if e.winner == 0 else "winning")
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
	_set_status("Round %d!%s" % [duel.round_number, extra] if extra != "" else ("Tap a card, then Buy" if duel.round_number == 1 else "Round %d!" % duel.round_number))


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
	# Nothing to show (picking starters, match over): no empty panel.
	_panel_box.visible = _panel.get_child_count() > 0


## The strip across the top of the panel: a title (and a short hint under
## it, if any) on the left, `right` (chips or a button) on the right.
## Tapping the title calls `on_title`, if given.
func _heading(title: String, subtitle := "", icon_key := "", right: Control = null, on_title := Callable()) -> void:
	var row := UIStyle.hbox("s")
	row.custom_minimum_size.y = UIStyle.num("button", "min_height", 88)
	if icon_key != "":
		row.add_child(UIStyle.icon(icon_key, UIStyle.color("gold"), 52))
	var titles := UIStyle.vbox("xs")
	titles.add_theme_constant_override("separation", 0)
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_row := UIStyle.hbox("xs")
	if on_title.is_valid():
		title_row.add_child(UIStyle.icon("info", UIStyle.color("text_soft"), 36))
	var title_label := UIStyle.label(title, "large")
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_label)
	titles.add_child(title_row)
	if subtitle != "":
		var sub := UIStyle.label(subtitle, "small", UIStyle.color("text_soft"))
		sub.clip_text = true
		sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		titles.add_child(sub)
	row.add_child(titles)
	if on_title.is_valid():
		titles.mouse_filter = Control.MOUSE_FILTER_PASS
		UIKit.on_tap(titles, on_title)
	if right != null:
		right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(right)
	_panel.add_child(row)


## A row of big buttons sharing the panel's width.
func _buttons(row_items: Array) -> HBoxContainer:
	var row := UIStyle.hbox("s")
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for b in row_items:
		(b as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	_panel.add_child(row)
	return row


# Shopping: your own Watering Hole, and training your herd.

func _draft_panel() -> void:
	var done: bool = duel.done_shopping[0]
	var market_picked: bool = _selected_market >= 0 and int(duel.shops[0][_selected_market].taken) < 0
	var herd_picked: bool = not market_picked and _selected_herd >= 0 and _selected_herd < duel.herds[0].size()
	if done:
		_heading("Ready!", "Waiting for %s" % opponent.name)
	elif market_picked:
		var item: Dictionary = duel.shops[0][_selected_market]
		var card := GameData.get_card(item.id)
		var problem := duel.can_buy(0, _selected_market)
		var buy := UIStyle.button("Buy", "primary" if problem == "" else "disabled", "", int(item.cost))
		buy.pressed.connect(func() -> void: _buy(_selected_market))
		var id: String = item.id
		_heading(card.name, _card_line(item.id), "", buy, func() -> void: _show_card(id))
	elif herd_picked:
		var entry: Dictionary = duel.herds[0][_selected_herd]
		var card := GameData.get_card(entry.id)
		var price := duel.train_cost(0, _selected_herd)
		var problem := duel.can_train(0, _selected_herd)
		var right: Control = null
		if price >= 0:
			var train := UIStyle.button("Train", "gold" if problem == "" else "disabled", "upgrade", price)
			train.pressed.connect(_train_selected)
			right = train
		var line := "+%d%% health and bite" % int(duel.rules.star_bonus_pct) if price >= 0 else "Fully trained!"
		var id: String = entry.id
		_heading(card.name, line, "", right, func() -> void: _show_card(id))
	else:
		var counts := UIStyle.hbox("xs")
		counts.add_child(_count_chip("paw", "%d/%d" % [duel.herds[0].size(), int(duel.rules.herd_max)]))
		counts.add_child(_count_chip("toolbox", "%d/%d" % [duel.tools[0].size(), int(duel.rules.tools_max)]))
		_heading("Watering Hole", "", "", counts)

	# The shop: two rows of three big cards.
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", UIStyle.space("s"))
	grid.add_theme_constant_override("v_separation", UIStyle.space("s"))
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_market_cards.clear()
	for i in duel.shops[0].size():
		var card := _market_card(i)
		_market_cards.append(card)
		grid.add_child(card)
	_panel.add_child(grid)

	# Your herd: a slot for each animal it can hold.
	var herd_row := UIStyle.hbox("xs")
	herd_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_herd_chips.clear()
	for i in int(duel.rules.herd_max):
		if i < duel.herds[0].size():
			var chip := _herd_chip(i, _herd_slot_size())
			_herd_chips.append(chip)
			herd_row.add_child(chip)
		else:
			herd_row.add_child(GameCard.make("", _herd_slot_size()))
	_panel.add_child(herd_row)

	var reroll := UIStyle.button("Reroll", "secondary" if not done and duel.acorns[0] >= int(duel.rules.reroll_cost) else "disabled", "reroll", int(duel.rules.reroll_cost))
	reroll.disabled = done
	reroll.pressed.connect(func() -> void:
		if duel.acorns[0] < int(duel.rules.reroll_cost):
			Sound.play("error")
			_set_status("Not enough Acorns", UIStyle.color("danger").lightened(0.4))
			return
		duel.reroll(0)
	)
	var finish := UIStyle.button("Done" if not done else "Ready", "primary", "check" if done else "")
	finish.disabled = done
	finish.pressed.connect(func() -> void:
		_selected_market = -1
		_selected_herd = -1
		duel.finish_shopping(0)
	)
	_buttons([reroll, finish])
	_animate_shop()


func _market_card(slot: int) -> Control:
	var item: Dictionary = duel.shops[0][slot]
	var taken := int(item.taken)
	var card := GameCard.make(item.id, _shop_card_size())
	card.cost = int(item.cost)
	card.affordable = duel.acorns[0] >= int(item.cost) or taken >= 0
	card.selected = slot == _selected_market
	card.done = taken >= 0
	var target := duel.merge_target(0, item.id) if taken < 0 and not GameData.is_tool(item.id) else -1
	if target >= 0:
		# A copy of one you have: buying it adds a star.
		card.stars = int(duel.herds[0][target].stars) + 1
		card.star_preview = true
		card.animate(true)
	UIKit.on_tap(card, func() -> void: _on_market_tapped(slot))
	return card


func _shop_card_size() -> Vector2:
	return SHOP_CARD_SHORT if get_viewport_rect().size.y < SHORT_SCREEN else SHOP_CARD


func _herd_slot_size() -> Vector2:
	return HERD_SLOT_SHORT if get_viewport_rect().size.y < SHORT_SCREEN else HERD_SLOT


## One short line about a card for the strip: its ability, or what a copy
## does.
func _card_line(id: String) -> String:
	var card := GameData.get_card(id)
	if not GameData.is_tool(id) and duel.merge_target(0, id) >= 0:
		return "A copy: +1 star"
	var pack := " ×%d" % int(card.count) if int(card.get("count", 1)) > 1 else ""
	return String(card.ability.name) + pack


## The card's full details (stats and ability), in a popup.
func _show_card(id: String) -> void:
	Modal.open(AnimalDetail.create(id), GameData.get_card(id).name)


## A small chip with an icon and a count, like the herd's "3/6".
func _count_chip(icon_key: String, text: String) -> Control:
	var row := UIStyle.hbox("xs")
	row.add_theme_constant_override("separation", 4)
	row.add_child(UIStyle.icon(icon_key, Color.WHITE, 36))
	row.add_child(UIStyle.label(text, "small"))
	return UIStyle.chip(row)


## Cards pop in one by one when the shop changes (a new round or a reroll),
## and a newly picked card lifts.
func _animate_shop() -> void:
	var key := str([duel.round_number, duel.shops[0].map(func(item): return item.id)])
	var fresh := key != _shop_key
	_shop_key = key
	var lift := UIStyle.num("card", "selected_lift", 1.06)
	for i in _market_cards.size():
		var card: GameCard = _market_cards[i]
		if fresh:
			card.scale = Vector2(0.4, 0.4)
			card.modulate.a = 0.0
			var tween := card.create_tween()
			tween.tween_interval(0.05 * i)
			tween.tween_property(card, "modulate:a", 1.0, 0.1)
			tween.parallel().tween_property(card, "scale", Vector2.ONE, Feel.num("ui", "panel_seconds", 0.32)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		elif card.selected:
			if _lifted != i:
				card.scale = Vector2.ONE
				card.create_tween().tween_property(card, "scale", Vector2(lift, lift), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			else:
				card.scale = Vector2(lift, lift)
	_lifted = _selected_market





func _train_selected() -> void:
	var problem := duel.can_train(0, _selected_herd)
	if problem != "":
		Sound.play("error")
		_set_status(problem, UIStyle.color("danger").lightened(0.4))
		return
	var at := _chip_center(_herd_chips, _selected_herd)
	if duel.train(0, _selected_herd):
		_ui_fx.burst("sparkle", at, Feel.count("effects", "upgrade_sparkles", 14), 220.0, 0.7, 10.0, [Color("#ffe14d"), Color.WHITE], -80.0, 2.5)
		_ui_fx.burst("star", at, 4, 200.0, 0.7, 9.0, [Color("#ffe14d")], 500.0, 1.2, 160.0)


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
		_set_status(problem, UIStyle.color("danger").lightened(0.4))
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
	var card := GameCard.make(duel.herds[0][index].id, chip_size)
	card.stars = int(duel.herds[0][index].stars)
	card.show_habitat = chip_size.x >= SHOP_CARD.x * 0.6
	card.selected = index == _selected_herd
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


## A short message over the bottom of the field that fades after a moment.
func _set_status(text: String, color := Color.WHITE) -> void:
	if _toast == null or text == "":
		return
	_toast_label.text = text
	_toast_label.add_theme_color_override("font_color", color)
	var width := minf(_field.size.x - UIStyle.space("l"), 600.0)
	_toast_label.custom_minimum_size.x = 0.0
	_toast.reset_size()
	if _toast.size.x > width:
		_toast_label.custom_minimum_size.x = width - 40.0
		_toast.size = Vector2.ZERO
		_toast.reset_size()
	_toast.position = Vector2((_field.size.x - _toast.size.x) / 2.0, _field.size.y - _toast.size.y - UIStyle.space("s"))
	_toast.pivot_offset = _toast.size / 2.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.scale = Vector2(0.85, 0.85)
	_toast_tween = _toast.create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.12)
	_toast_tween.parallel().tween_property(_toast, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_interval(Feel.num("ui", "toast_seconds", 2.2))
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.3)


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
	var boss_beaten: bool = _result.get("boss_beaten", false)
	if boss_beaten:
		titles.win = "Boss Defeated!"
	var colors := {"win": UIKit.YELLOW, "loss": UIKit.RED, "draw": UIKit.TEXT}
	box.add_child(UIKit.label(titles[outcome], 52, colors[outcome], HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_rival_reaction(outcome))
	box.add_child(UIKit.label("Hearts left  %d - %d" % [duel.hearts[0], duel.hearts[1]], 26, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UIKit.label("%d round%s" % [duel.round_number, "" if duel.round_number == 1 else "s"], 22, UIKit.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	if opponent.boss:
		box.add_child(_boss_lines(boss_beaten))
	var ok := UIKit.button("OK", UIKit.GREEN, 28, Vector2(220, 84))
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(_back_to_menu)
	box.add_child(ok)
	# A beaten boss gets its own moment over the field first.
	var show_result := func() -> void:
		_overlay(box)
		if outcome == "win":
			# A shower of confetti and coins for the winner.
			var screen_size := get_viewport_rect().size
			for i in 3:
				_ui_fx.burst_confetti(Vector2(screen_size.x * (0.2 + 0.3 * i), screen_size.y * 0.3), Feel.count("effects", "win_confetti", 60) / 2)
			_ui_fx.burst_coins(screen_size / 2.0 + Vector2(0, -120), Feel.count("effects", "coin_burst", 8) * 2)
	if boss_beaten:
		_celebrate_boss()
		get_tree().create_timer(Feel.num("rivals", "boss_celebration_seconds", 1.8)).timeout.connect(show_result)
	else:
		show_result.call()


## The rival's face and last word at the end: their winning emote if they
## won, their losing one if you did.
func _rival_reaction(outcome: String) -> Control:
	var row := UIKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var portrait := RangerPortrait.create(opponent, 104)
	portrait.mood = {"win": "sad", "loss": "happy"}.get(outcome, "normal")
	row.add_child(portrait)
	var moment: String = {"win": "losing", "loss": "winning"}.get(outcome, "start")
	var emote := GameData.find_by_id(GameData.emotes, opponent.get("emotes", {}).get(moment, ""))
	var words := UIKit.vbox(0)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(UIKit.label(opponent.name, 26, UIKit.TEXT))
	if not emote.is_empty():
		words.add_child(_emote_bubble(emote))
	row.add_child(words)
	return row


## Under a boss match's result: the promotion and first-win reward, or what
## it would have meant.
func _boss_lines(beaten: bool) -> Control:
	var box := UIKit.vbox(6)
	var next := int(opponent.arena_index) + 1
	var text := ""
	if beaten:
		text = "You've earned your place in %s!" % GameData.get_arena(next).name if next < GameData.arenas.size() else "You're the champion of %s!" % GameData.get_arena(next - 1).name
	else:
		text = "%s still guards the way. Beat them to reach %s." % [opponent.name, GameData.get_arena(next).name] if next < GameData.arenas.size() else "%s is still the champion here." % opponent.name
	var line := UIKit.paragraph(text, 21, UIKit.YELLOW if beaten else UIKit.TEXT)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(line)
	var reward: Dictionary = _result.get("boss_reward", {})
	if not reward.is_empty():
		box.add_child(UIKit.label("First boss win reward", 22, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		var row := UIKit.hbox(10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(UIKit.pill(GameData.ui_icon("gold"), UIKit.GOLD, "+%s" % UIKit.format_number(int(reward.gold))))
		row.add_child(UIKit.pill(GameData.ui_icon("gems"), UIKit.GEMS, "+%d" % int(reward.gems)))
		box.add_child(row)
		if reward.cage_id != "":
			box.add_child(UIKit.label("and a %s!" % GameData.cages[reward.cage_id].name, 22, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	return box


## Beating a boss: a gold banner, fireworks of stars and confetti, and coins.
func _celebrate_boss() -> void:
	var screen_size := get_viewport_rect().size
	_banner("BOSS DEFEATED!", UIKit.GOLD, Feel.count("celebrations", "banner_size", 54), opponent.name)
	Sound.play("fanfare")
	for i in 4:
		var at := Vector2(screen_size.x * (0.15 + 0.233 * i), screen_size.y * (0.22 + 0.08 * (i % 2)))
		get_tree().create_timer(0.25 * i).timeout.connect(func() -> void:
			_ui_fx.burst("star", at, Feel.count("celebrations", "star3_stars", 22), 300.0, 0.9, 9.0, [UIKit.GOLD, Color("#ffb03b"), Color.WHITE], 380.0, 1.2, 180.0)
			Sound.play("pop")
		)
	get_tree().create_timer(1.1).timeout.connect(func() -> void:
		Sound.play("star3")
		_ui_fx.burst_coins(screen_size / 2.0, Feel.count("effects", "coin_burst", 8) * 3)
	)


func _record(outcome: String) -> void:
	_result = Profile.record_match(outcome, int(opponent.trophies), bool(opponent.boss))
	_result["hearts"] = duel.hearts.duplicate()
	_result["rival"] = opponent.id


func _back_to_menu() -> void:
	Profile.pending_match_result = _result
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_leave() -> void:
	Modal.confirm("Leave the match? It counts as a loss.", "Leave", _leave_now, UIKit.RED)


func _leave_now() -> void:
	if _result.is_empty():
		_record("loss")
	_back_to_menu()
