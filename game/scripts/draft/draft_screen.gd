extends Control
## Draft Duel against a Rival Ranger (the rules are in DraftMatch): best of
## 7, first to 4 round wins.
##
## Each round has two views under the score bar:
## - Pick: "Pick 3" with three slots, the options as big cards (in round 1,
##   your whole collection), your herd in a scrolling row (tap one with an
##   arrow to add a star), and the Fight! button, lit once all three picks
##   are made. Hold any card for a short line about it; tap your last pick
##   to take it back.
## - Fight: the field, with the Rally button and your tools under it. Then
##   a quick result, and back to picking.
##
## Almost no words anywhere: icons, numbers and stars do the talking. Sizes
## and timings: feel.json ("pick").

const MENU_SCENE := "res://scenes/main.tscn"
## Draws popups above the field (flying animals sit a step higher).
const OVER_FIELD := 10
## The debug slow-motion speeds (0 = paused, with a Step button).
const DEBUG_SPEEDS := [1.0, 0.5, 0.25, 0.1, 0.0]

var duel: DraftMatch
var bot: DraftBot
var opponent: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _accumulator := 0.0
var _bot_wait := 0.0
var _fast := false
## A fight's opening beat (the armies stand in formation a moment, then
## "FIGHT!"), and how fast it's playing: a dragging ending speeds up
## (feel.json "choreography").
var _intro_left := 0.0
var _speed := 1.0
var _quiet := 0.0
var _result: Dictionary = {}
var _selected_tool := -1
var _view := ""

# The score bar.
var _score_bar: Control
var _score_label: Label
var _my_pips: _Pips
var _their_pips: _Pips
var _rival_portrait: RangerPortrait
var _rival_check: Control
var _shown_wins := [0, 0]
var _most_behind := 0

# The pick view.
var _pick_view: VBoxContainer
var _pick_title: Label
var _slots: Array = []
var _options_holder: Control
var _option_cards: Array = []
var _herd_scroll: ScrollContainer
var _herd_row: HBoxContainer
## Your army in formation while you pick (new squads march into place; tap
## an animal to upgrade it).
var _army_view: BattleField
var _fight_button: ChunkyButton
var _flying := {}
var _details: Control
var _tip: Control
var _pick_key := ""

# The fight view.
var _fight_view: VBoxContainer
var _field: BattleField
var _actions: HBoxContainer
var _actions_key := ""

var _emote_free_at := 0.0
var _big_hit_round := -1
var _banner_free_at := 0.0


func _ready() -> void:
	theme = UIStyle.theme()
	_rng.randomize()
	# Your opponent is a Rival Ranger from your arena (or its boss, when a
	# win would take you up), with their own way of playing (see Opponents).
	# You pick from your deck and your tools; the rival brings a deck of its
	# own that suits it, at about your card levels.
	opponent = Opponents.next_for_player(_rng)
	var mine: Array = DraftMatch.with_enough(Profile.get_deck() + Profile.owned_tools())
	var theirs := _rival_pool(opponent, mine)
	duel = DraftMatch.new(_rng.randi(), {"levels": [Profile.card_levels(), _opponent_levels(theirs, Opponents.level_drop(opponent), mine)], "pools": [mine, theirs]})
	bot = DraftBot.new(duel, 1, _rng.randi(), float(opponent.difficulty), opponent.get("style", {}))
	_build()
	Sound.play_music("battle")
	var intro := VersusIntro.create(opponent)
	# While the VS screen covers everything, the screen under it isn't drawn.
	_score_bar.visible = false
	_pick_view.visible = false
	intro.leaving.connect(func() -> void:
		_score_bar.visible = true
		_show_view("pick"))
	intro.z_index = OVER_FIELD
	add_child(intro)


## The rival's cards: a deck of 8 that suits it (DraftBot.rival_deck) and
## as many tools as the player has, from the tools unlocked in its arena.
func _rival_pool(rival: Dictionary, player_pool: Array) -> Array:
	var arena := int(rival.get("arena_index", 0))
	var size := int(GameData.draft_rules.get("deck_size", 8))
	var deck := DraftBot.rival_deck(arena, rival.get("style", {}), _rng, float(rival.get("difficulty", 0.5)), size)
	var tools: Array = GameData.card_order.filter(func(id): return GameData.is_tool(id) and int(GameData.cards[id].unlock_arena_index) <= arena)
	var want := maxi(int(GameData.draft_rules.offer_tools), player_pool.filter(func(id): return GameData.is_tool(id)).size())
	while tools.size() > want:
		tools.remove_at(_rng.randi_range(0, tools.size() - 1))
	return deck + tools


## Levels for the opponent's cards: each rarity's starting level, plus as
## many levels as the player's cards (`reference`) have on average, minus
## `drop`.
static func _opponent_levels(pool: Array, drop := 0, reference: Array = []) -> Dictionary:
	var above := 0.0
	var against: Array = reference if not reference.is_empty() else pool
	for id in against:
		above += Profile.card_level(id) - GameData.start_level(GameData.cards[id].rarity)
	var offset := roundi(above / maxf(1.0, against.size()))
	var levels := {}
	for id in pool:
		levels[id] = clampi(GameData.start_level(GameData.cards[id].rarity) + offset - drop, 1, int(GameData.progression.card_max_level))
	return levels


func _process(delta: float) -> void:
	if not _result.is_empty():
		return
	_opponent_moves(delta)
	if duel.phase == "fight":
		_run_fight(delta)
	else:
		_accumulator = 0.0
	_handle_events(duel.take_events())
	if _view == "pick":
		var key := _pick_signature()
		if key != _pick_key:
			_pick_key = key
			_refresh_pick()
	elif _view == "fight":
		_refresh_actions()
	_update_score()
	if duel.is_over():
		_end_match()


# --- Building the screen ---------------------------------------------------

func _build() -> void:
	add_child(UIStyle.backdrop())
	var safe := UIStyle.safe_margins(get_viewport())
	var margin := UIStyle.num("screen", "margin", 16)
	var column := UIStyle.vbox("s")
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = margin
	column.offset_right = -margin
	column.offset_top = margin * 0.5 + float(safe.top)
	column.offset_bottom = -margin * 0.5 - float(safe.bottom)
	add_child(column)

	_score_bar = _build_score_bar()
	column.add_child(_score_bar)

	var views := Control.new()
	views.size_flags_vertical = Control.SIZE_EXPAND_FILL
	views.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(views)
	_pick_view = _build_pick_view()
	views.add_child(_pick_view)
	_fight_view = _build_fight_view()
	views.add_child(_fight_view)
	_fight_view.visible = false


## The score, big: your pips, "2 - 1", their pips, and the rival's face
## (with a check once they've made their picks).
func _build_score_bar() -> Control:
	var row := UIStyle.hbox("s")
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var mine := GameData.find_by_id(GameData.player_icons, Profile.data.icon)
	var me := IconArt.make(GameData.player_icon(Profile.data.icon), Color(mine.get("color", "#888888")))
	me.custom_minimum_size = Vector2(64, 64)
	me.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(me)
	var wins := int(duel.rules.wins_needed)
	_my_pips = _Pips.new(wins, UIStyle.color("player"))
	row.add_child(_my_pips)
	_score_label = UIStyle.label("0 - 0", "title", Color(0, 0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER)
	_score_label.custom_minimum_size.x = 170
	row.add_child(_score_label)
	_their_pips = _Pips.new(wins, UIStyle.color("enemy"))
	row.add_child(_their_pips)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(64, 64)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rival_portrait = RangerPortrait.create(opponent, 64)
	holder.add_child(_rival_portrait)
	_rival_check = _CheckBadge.new()
	_rival_check.size = Vector2(30, 30)
	_rival_check.position = Vector2(40, 38)
	_rival_check.visible = false
	holder.add_child(_rival_check)
	row.add_child(holder)
	return UIStyle.chip(row)


func _build_pick_view() -> VBoxContainer:
	var view := UIStyle.vbox("m")
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# "Pick 3" and the three slots the picks land in.
	var header := UIStyle.hbox("s")
	_pick_title = UIStyle.label("Pick 3", "title")
	_pick_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_pick_title)
	_slots.clear()
	var side := Feel.num("pick", "slot_size", 108.0)
	for i in int(duel.rules.picks_per_round):
		var slot := PanelContainer.new()
		slot.theme_type_variation = "InsetPanel"
		slot.custom_minimum_size = Vector2(side, side)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		var index := i
		slot.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_tap_slot(index))
		header.add_child(slot)
		_slots.append(slot)
	view.add_child(header)

	# The options (filled each round).
	_options_holder = Control.new()
	_options_holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_options_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(_options_holder)

	# Your army, standing in formation.
	_army_view = BattleField.new()
	_army_view.sim = duel.sim
	_army_view.frame_team = 0
	_army_view.walk_in = true
	_army_view.camera_max_zoom = Feel.num("pick", "army_max_zoom", 10.0)
	_army_view.camera_min_tiles = Feel.num("pick", "army_min_tiles", 7.0)
	_army_view.grass = Color(GameData.get_arena(Profile.arena_index()).color)
	_army_view.arena_id = GameData.get_arena(Profile.arena_index()).id
	_army_view.custom_minimum_size.y = Feel.num("pick", "army_height", 200.0)
	_army_view.camera_margin = Feel.num("pick", "army_margin_tiles", 0.8)
	_army_view.tapped.connect(_on_army_tapped)
	var army_box := UIStyle.inset(_army_view)
	# It takes whatever room the options leave.
	army_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.add_child(army_box)

	# Your herd, in a row that scrolls, then your tools.
	_herd_scroll = ScrollContainer.new()
	_herd_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_herd_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var herd_size: Vector2 = _size("herd_card", Vector2(104, 120))
	_herd_scroll.custom_minimum_size.y = herd_size.y + 24.0
	_herd_row = UIStyle.hbox("xs")
	_herd_scroll.add_child(_herd_row)
	view.add_child(UIStyle.inset(_herd_scroll))

	# Leave, and Fight!
	var bottom := UIStyle.hbox("s")
	var leave := UIStyle.icon_button("exit", "danger")
	leave.pressed.connect(_on_leave)
	bottom.add_child(leave)
	_fight_button = UIStyle.button("Fight!", "primary", "tab_battle")
	_fight_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fight_button.pressed.connect(func() -> void:
		_hide_tip()
		duel.set_ready(0))
	bottom.add_child(_fight_button)
	view.add_child(bottom)
	return view


func _build_fight_view() -> VBoxContainer:
	var view := UIStyle.vbox("s")
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_field = BattleField.new()
	_field.sim = duel.sim
	_field.grass = Color(GameData.get_arena(Profile.arena_index()).color)
	_field.arena_id = GameData.get_arena(Profile.arena_index()).id
	_field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field.tapped.connect(_on_field_tapped)
	_field.strong_hit.connect(_on_strong_hit)
	view.add_child(_field)
	if OS.is_debug_build() or GameData.testing.get("show_dev_tools", false):
		_field.add_child(_debug_speed_buttons())
	_actions = UIStyle.hbox("s")
	_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	view.add_child(_actions)
	return view


## For testing only (debug builds, or show_dev_tools in testing.json): a
## small button over the field's corner that slows the whole game down
## (1x, 0.5x, 0.25x, 0.1x) or pauses it, with Step to go on a frame at a
## time, for looking at a fight closely.
func _debug_speed_buttons() -> Control:
	var row := HBoxContainer.new()
	row.position = Vector2(8, 8)
	row.z_index = 5  # over the arena and animals the field adds after it
	row.add_theme_constant_override("separation", 6)
	var speed := UIStyle.button("1x", "secondary", "", -1, "small")
	var step := UIStyle.button("Step", "secondary", "", -1, "small")
	step.visible = false
	var index := [0]
	speed.pressed.connect(func() -> void:
		index[0] = (index[0] + 1) % DEBUG_SPEEDS.size()
		var rate: float = DEBUG_SPEEDS[index[0]]
		Engine.time_scale = rate
		speed.text_label.text = "Paused" if rate == 0.0 else "%sx" % str(rate)
		step.visible = rate == 0.0)
	step.pressed.connect(func() -> void:
		Engine.time_scale = 1.0
		await get_tree().process_frame
		await get_tree().process_frame
		if index[0] == DEBUG_SPEEDS.size() - 1:
			Engine.time_scale = 0.0)
	row.add_child(speed)
	row.add_child(step)
	return row


func _exit_tree() -> void:
	Engine.time_scale = 1.0


## Shows the pick view or the fight view, with a quick slide and fade.
func _show_view(which: String) -> void:
	var view: Control = _pick_view if which == "pick" else _fight_view
	var other: Control = _fight_view if which == "pick" else _pick_view
	if _view == which and view.visible:
		return
	_view = which
	_hide_details()
	_hide_tip()
	other.visible = false
	view.visible = true
	view.modulate.a = 0.0
	view.position.y = 40.0
	var tween := view.create_tween().set_parallel()
	tween.tween_property(view, "modulate:a", 1.0, Feel.num("ui", "panel_seconds", 0.32))
	tween.tween_property(view, "position:y", 0.0, Feel.num("ui", "panel_seconds", 0.32)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_rival_check.visible = false
	if which == "pick":
		_pick_key = ""
		_build_options()
		_refresh_pick()
		_first_match_tip()
	else:
		_actions_key = ""
		_refresh_actions()


func _size(key: String, fallback: Vector2) -> Vector2:
	var value: Variant = GameData.feel.get("pick", {}).get(key, null)
	if value is Array and (value as Array).size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback


# --- The score -----------------------------------------------------------------

func _update_score() -> void:
	if duel.wins == _shown_wins:
		return
	for team in 2:
		if duel.wins[team] != _shown_wins[team]:
			(_my_pips if team == 0 else _their_pips).set_filled(duel.wins[team])
	_shown_wins = duel.wins.duplicate()
	_most_behind = maxi(_most_behind, duel.wins[1] - duel.wins[0])
	_score_label.text = "%d - %d" % [duel.wins[0], duel.wins[1]]
	_score_label.pivot_offset = _score_label.size / 2.0
	_score_label.scale = Vector2(1.35, 1.35)
	_score_label.create_tween().tween_property(_score_label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A row of pips, one per round needed to win, filling as rounds are won.
class _Pips:
	extends Control
	var count := 4
	var filled := 0
	var color := Color.WHITE
	var _pop := {}

	func _init(pip_count: int, pip_color: Color) -> void:
		count = pip_count
		color = pip_color
		custom_minimum_size = Vector2(pip_count * 30.0 + 4.0, 40)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_filled(value: int) -> void:
		for i in range(filled, value):
			_pop[i] = 0.0
		filled = value
		set_process(true)
		queue_redraw()

	func _process(delta: float) -> void:
		var busy := false
		for i in _pop.keys():
			_pop[i] = float(_pop[i]) + delta * 3.0
			busy = busy or float(_pop[i]) < 1.0
		if not busy:
			_pop.clear()
			set_process(false)
		queue_redraw()

	func _draw() -> void:
		var ink := UIStyle.color("outline")
		for i in count:
			var c := Vector2(17.0 + i * 30.0, size.y / 2.0)
			draw_circle(c, 12.0, ink)
			if i < filled:
				var t: float = clampf(float(_pop.get(i, 1.0)), 0.0, 1.0)
				var k := 1.0 + 0.5 * sin(t * PI) if _pop.has(i) else 1.0
				UIStyle.draw_particle(self, "badge", c, 10.0 * k, color)
			else:
				draw_circle(c, 9.0, Color(ink, 0.55).lightened(0.15))


# --- Picking ---------------------------------------------------------------------

## Changes whenever the pick view needs updating.
func _pick_signature() -> String:
	return str([duel.round_number, duel.picks_left[0], duel.picks_made[0].size(), duel.herds[0], duel.tools[0],
		duel.offers[0].map(func(o): return o.taken), duel.ready, _flying.keys()])


## The options as big cards: the whole deck in round 1 (a grid), after
## that two groups, each on its own tray: the animals in a row, and the
## tools in a row under them.
func _build_options() -> void:
	for child in _options_holder.get_children():
		_options_holder.remove_child(child)
		child.queue_free()
	_option_cards.clear()
	var step := Feel.num("ui", "stagger_seconds", 0.05)
	# Just the room the cards need: your army below gets the rest.
	var gap := float(UIStyle.space("s"))
	if duel.is_first_round():
		var card := _size("start_card", Vector2(156, 176))
		_options_holder.custom_minimum_size.y = ceilf(duel.offers[0].size() / 4.0) * (card.y + gap)
	else:
		var pad := Feel.num("pick", "tray_padding", 8.0)
		_options_holder.custom_minimum_size.y = 2.0 * (_size("offer_card", Vector2(156, 184)).y + 2.0 * pad) + gap
	if duel.is_first_round():
		var scroll := ScrollContainer.new()
		scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", UIStyle.space("s"))
		grid.add_theme_constant_override("v_separation", UIStyle.space("s"))
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(grid)
		_options_holder.add_child(scroll)
		for slot in duel.offers[0].size():
			var card := _option_card(slot, _size("start_card", Vector2(156, 176)))
			grid.add_child(card)
			_pop_after(card, step * slot)
		return
	var rows := UIStyle.vbox("s")
	rows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	_options_holder.add_child(rows)
	# The offers come animals first, then tools (DraftMatch._roll_offers),
	# so the cards are made in slot order.
	var pick: Dictionary = GameData.feel.get("pick", {})
	for tools in [false, true]:
		var slots: Array = range(duel.offers[0].size()).filter(func(s): return GameData.is_tool(duel.offers[0][s].id) == tools)
		if slots.is_empty():
			continue
		var tray := UIKit.panel(Color(String(pick.get("tool_tray" if tools else "animal_tray", "#00000040"))), int(Feel.num("pick", "tray_padding", 8.0)), 18)
		tray.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var row := UIStyle.hbox("xs")
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		tray.add_child(row)
		rows.add_child(tray)
		for slot in slots:
			var card := _option_card(slot, _size("offer_card", Vector2(156, 184)))
			row.add_child(card)
			_pop_after(card, step * slot)


func _option_card(slot: int, card_size: Vector2) -> GameCard:
	var id: String = duel.offers[0][slot].id
	var card := GameCard.make(id, card_size)
	card.show_name = false
	_bind_card(card, func() -> void: _tap_option(slot), id)
	_option_cards.append(card)
	return card


## Brings the pick view up to date: the title, every card's state, the
## slots, your herd row and the Fight! button.
func _refresh_pick() -> void:
	var left: int = duel.picks_left[0]
	_pick_title.text = "Pick %d" % left if left > 0 and duel.has_any_pick(0) else "Ready!"
	_pick_title.add_theme_color_override("font_color", UIStyle.color("text") if left > 0 else UIStyle.color("gold"))
	for slot in _option_cards.size():
		var card: GameCard = _option_cards[slot]
		var item: Dictionary = duel.offers[0][slot]
		var index := duel.herd_index(0, item.id)
		var can := duel.can_pick(0, slot) == ""
		# An animal already in your army: picking it adds another squad
		# ("+3" on a Ranged card), its stars stay as they are.
		var owned := index >= 0 and can and not duel.is_first_round()
		var tag := "+%d" % DraftMatch.squad_units(String(item.id)) if owned else ""
		var stars := int(duel.herds[0][index].stars) if owned else 0
		if stars != card.stars or tag != card.squad_tag:
			card.stars = stars
			card.star_preview = false
			card.squad_tag = tag
			card.animate(owned)
			card.queue_redraw()
		var done := 1.0 if item.taken else 0.0
		if card.done != done:
			card.create_tween().tween_property(card, "done", done, 0.2)
		card.modulate.a = 1.0 if can or item.taken or not duel.has_any_pick(0) else 0.55
	_refresh_slots()
	_refresh_herd_row()
	var done_picking: bool = not duel.has_any_pick(0)
	_fight_button.disabled = duel.ready[0] or not done_picking
	_fight_button.kind = "primary" if done_picking and not duel.ready[0] else "disabled"
	_fight_button.set_label("Fight!")
	_fight_button.breathe = done_picking and not duel.ready[0]
	_rival_check.visible = duel.phase == "pick" and duel.ready[1]


## Each slot shows its pick (a card, a star for a herd animal, a tool), the
## latest with a back arrow to take it back. Empty slots wait.
func _refresh_slots() -> void:
	var picks: Array = duel.picks_made[0]
	for i in _slots.size():
		var slot: PanelContainer = _slots[i]
		var want := ""
		if i < picks.size() and not _flying.has(i):
			want = "%s:%s" % [picks[i].kind, picks[i].id]
		var have := String(slot.get_meta("pick", ""))
		var last: bool = i == picks.size() - 1 and not duel.ready[0]
		if want != have:
			slot.set_meta("pick", want)
			for child in slot.get_children():
				slot.remove_child(child)
				child.queue_free()
			if want != "":
				var card := GameCard.make(picks[i].id, Vector2.ONE * (slot.custom_minimum_size.x - 12.0))
				card.mouse_filter = Control.MOUSE_FILTER_IGNORE
				if picks[i].kind != "tool":
					card.stars = int(duel.herds[0][picks[i].index].stars) if picks[i].index < duel.herds[0].size() else 1
				slot.add_child(card)
				UIKit.pop_in(slot, 0.6, 0.3)
				Sound.play("pop")
		slot.modulate = Color(1, 1, 1, 1) if want != "" else Color(1, 1, 1, 0.75)
		# The latest pick can be taken back: a little back arrow in its corner.
		# (On the card: the slot is a container and would stretch it.)
		var card_now: Control = slot.get_child(0) if slot.get_child_count() > 0 else null
		var undo: Control = card_now.get_node_or_null("Undo") if card_now != null else null
		if card_now != null and last and undo == null:
			var badge := _UndoBadge.new()
			badge.name = "Undo"
			var side := Feel.num("pick", "undo_badge", 38.0)
			badge.size = Vector2(side, side)
			badge.position = Vector2(card_now.custom_minimum_size.x - side * 0.7, -side * 0.3)
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card_now.add_child(badge)
			UIKit.pop_in(badge, 0.4, 0.25)
		elif undo != null and not last:
			card_now.remove_child(undo)
			undo.queue_free()


## Your army in a scrolling row (an arrow on each one a pick can upgrade or
## add a squad of), then your tools.
func _refresh_herd_row() -> void:
	var herd: Array = duel.herds[0]
	var card_size := _size("herd_card", Vector2(104, 120))
	_herd_scroll.get_parent().visible = not duel.is_first_round() and (not herd.is_empty() or not duel.tools[0].is_empty())
	var children := _herd_row.get_children()
	var wanted := []
	for entry in herd:
		wanted.append("a:" + String(entry.id))
	for id in duel.tools[0]:
		wanted.append("t:" + String(id))
	var have := children.map(func(c): return String(c.get_meta("key", "")))
	if have != wanted:
		for child in children:
			_herd_row.remove_child(child)
			child.queue_free()
		for i in wanted.size():
			var key: String = wanted[i]
			var id := key.substr(2)
			var card := GameCard.make(id, card_size)
			card.set_meta("key", key)
			if key.begins_with("a:"):
				var index := i
				_bind_card(card, func() -> void: _tap_herd(index), id)
			else:
				_bind_card(card, func() -> void: pass, id)
			_herd_row.add_child(card)
			if not have.has(key):
				UIKit.pop_in(card, 0.4, 0.35)
	for i in herd.size():
		var card: GameCard = _herd_row.get_child(i)
		var stars := int(herd[i].stars)
		var arrow: bool = duel.can_star(0, i) == "" or duel.can_reinforce(0, i) == ""
		if card.stars != stars or card.upgrade_arrow != arrow:
			card.stars = stars
			card.upgrade_arrow = arrow
			card.animate(arrow)
			card.queue_redraw()


func _tap_option(slot: int) -> void:
	var problem := duel.can_pick(0, slot)
	if problem != "":
		_nope(_option_cards[slot])
		return
	if duel.needs_tool_swap(0, slot):
		_ask_tool_swap(slot)
		return
	_pick(slot, -1)


func _pick(slot: int, replace: int) -> void:
	var card: Control = _option_cards[slot]
	var from := card.get_global_rect()
	var into: int = duel.picks_made[0].size()
	var id: String = duel.offers[0][slot].id
	if not duel.pick(0, slot, replace):
		_nope(card)
		return
	Sound.play("coin", -4.0)
	_fly_to_slot(id, from, into)


## Tapping an animal in your army: two big buttons, Upgrade (a star for
## every squad of it) and +Squad (another full squad of it: "+3 Squad" for
## Ranged), each one of your 3 picks. Nothing else.
func _tap_herd(index: int) -> void:
	if index >= duel.herds[0].size():
		return
	var card: GameCard = _herd_row.get_child(index)
	var can_up: bool = duel.can_star(0, index) == ""
	var can_more: bool = duel.can_reinforce(0, index) == ""
	if not can_up and not can_more:
		_nope(card)
		return
	var id: String = duel.herds[0][index].id
	var row := UIStyle.hbox("m")
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var up := UIStyle.button("Upgrade", "gold" if can_up else "disabled", "star")
	var more := UIStyle.button("+%d Squad" % DraftMatch.squad_units(id), "primary" if can_more else "disabled", "class_" + GameData.class_of(id))
	var big := _size("choice_button", Vector2(236, 128))
	for b: ChunkyButton in [up, more]:
		b.min_width = big.x
		b.min_height = big.y
		row.add_child(b)
	up.disabled = not can_up
	more.disabled = not can_more
	var layer := _overlay(row, true)
	layer.name = "ArmyChoice"
	up.pressed.connect(func() -> void:
		layer.queue_free()
		_upgrade(index))
	more.pressed.connect(func() -> void:
		layer.queue_free()
		_reinforce(index))


## Upgrade: a star for every squad of herd animal `index` (one pick).
func _upgrade(index: int) -> void:
	var card: GameCard = _herd_row.get_child(index)
	var from := card.get_global_rect()
	var into: int = duel.picks_made[0].size()
	if duel.star(0, index):
		card.flash = 1.0
		card.create_tween().tween_property(card, "flash", 0.0, 0.5)
		UIFx.stars(from.get_center(), 6)
		Sound.play("upgrade")
		_fly_to_slot(String(duel.herds[0][index].id), from, into)


## Reinforce: another full squad of herd animal `index` (one pick); it
## marches into the formation.
func _reinforce(index: int) -> void:
	var card: GameCard = _herd_row.get_child(index)
	var from := card.get_global_rect()
	var into: int = duel.picks_made[0].size()
	if duel.reinforce(0, index):
		card.flash = 1.0
		card.create_tween().tween_property(card, "flash", 0.0, 0.5)
		Sound.play("coin", -4.0)
		_fly_to_slot(String(duel.herds[0][index].id), from, into)


## A tap on your army: the animal nearest it offers Upgrade or +Squad (like
## tapping its card in the row below).
func _on_army_tapped(at: Vector2i) -> void:
	var best := -1
	var best_d := 1 << 40
	for f: BattleSim.Fighter in duel.sim.units(0):
		var d := (f.x - at.x) * (f.x - at.x) + (f.y - at.y) * (f.y - at.y)
		if d < best_d and f.memory.has("view_key"):
			best_d = d
			best = int(String(f.memory.view_key).split("/")[1])
	if best >= 0 and best_d <= 1500 * 1500:
		_tap_herd(best)


## Tapping your latest pick takes it back.
func _tap_slot(index: int) -> void:
	if index != duel.picks_made[0].size() - 1 or duel.ready[0]:
		return
	if duel.undo(0):
		Sound.play("whoosh", -6.0)
		var slot: Control = _slots[index]
		slot.pivot_offset = slot.size / 2.0
		var tween := slot.create_tween()
		tween.tween_property(slot, "scale", Vector2(0.85, 0.85), 0.08)
		tween.tween_property(slot, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A picked card flies along an arc into its slot and lands with a pop.
func _fly_to_slot(id: String, from: Rect2, into: int) -> void:
	_hide_tip()
	if into < 0 or into >= _slots.size():
		return
	_flying[into] = true
	var slot: Control = _slots[into]
	var to := slot.get_global_rect()
	var flyer := GameCard.make(id, from.size)
	flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flyer.position = from.position
	flyer.pivot_offset = from.size / 2.0
	UIFx.air.add_child(flyer)
	var start := from.get_center()
	var end := to.get_center()
	var peak := (start + end) / 2.0 + Vector2(0, -Feel.num("ui", "fly_arc_pixels", 140.0))
	var end_scale := Vector2(to.size.x / from.size.x, to.size.y / from.size.y)
	var size := from.size
	Sound.play("whoosh", -8.0)
	var tween := flyer.create_tween()
	tween.tween_method(func(t: float) -> void:
		flyer.position = start.lerp(peak, t).lerp(peak.lerp(end, t), t) - size / 2.0
		flyer.scale = Vector2.ONE.lerp(end_scale, t) * (1.0 + 0.12 * sin(t * PI))
		flyer.rotation = -0.22 * sin(t * PI)
	, 0.0, 1.0, Feel.num("ui", "fly_seconds", 0.5)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void:
		flyer.queue_free()
		_flying.erase(into)
		UIFx.dust(Vector2(to.get_center().x, to.end.y - 4.0), to.size.x * 0.8)
		Sound.play("land")
		_celebrate_if_three_stars(id, to))


## A third tool: tap one of yours to swap it out (or tap outside to keep them).
func _ask_tool_swap(slot: int) -> void:
	var box := UIStyle.vbox("s")
	box.add_child(UIStyle.label("Swap", "large", Color(0, 0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER))
	var row := UIStyle.hbox("s")
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var layer := _overlay(box, true)
	for i in duel.tools[0].size():
		var card := GameCard.make(duel.tools[0][i], _size("herd_card", Vector2(104, 120)) * 1.3)
		var index: int = i
		UIKit.on_tap(card, func() -> void:
			layer.queue_free()
			_pick(slot, index))
		row.add_child(card)


## A card that can't be picked gives a little shake.
func _nope(card: Control) -> void:
	Sound.play("error", -4.0)
	var x := card.position.x
	var tween := card.create_tween()
	for k in [8.0, -7.0, 5.0, -3.0, 0.0]:
		tween.tween_property(card, "position:x", x + k, 0.04)


## Taps, and holding to see a card's details (a name and one line).
func _bind_card(card: Control, on_tap: Callable, id: String) -> void:
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var press := {"down": false, "held": false, "at": Vector2.ZERO, "serial": 0}
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				press.down = true
				press.held = false
				press.at = event.global_position
				press.serial = int(press.serial) + 1
				var serial: int = press.serial
				UIKit.press_squash(card)
				get_tree().create_timer(Feel.num("pick", "hold_seconds", 0.35)).timeout.connect(func() -> void:
					if bool(press.down) and int(press.serial) == serial and is_instance_valid(card):
						press.held = true
						_show_details(id, card))
			elif press.down:
				press.down = false
				UIKit.release_bounce(card)
				if press.held:
					_hide_details()
				elif event.global_position.distance_to(press.at) < 24.0:
					Sound.play("select")
					UIFx.tap(event.global_position)
					on_tap.call()
		elif event is InputEventMouseMotion and bool(press.down) and event.global_position.distance_to(press.at) > 24.0:
			# A drag: scrolling, not a tap.
			press.down = false
			UIKit.release_bounce(card)
			if press.held:
				_hide_details()
	)


## A short popup over a held card: its name, and one line.
func _show_details(id: String, card: Control) -> void:
	_hide_details()
	var card_info := GameData.get_card(id)
	var row := UIStyle.hbox("s")
	var icon_key := "toolbox" if GameData.is_tool(id) else String(GameData.class_info(GameData.class_of(id)).get("icon", ""))
	var tint := UIStyle.color("tool") if GameData.is_tool(id) else Color(String(GameData.class_info(GameData.class_of(id)).get("color", "#ffffff")))
	row.add_child(UIStyle.icon(icon_key, tint.lightened(0.3), 52))
	var words := UIStyle.vbox("xs")
	words.add_theme_constant_override("separation", 0)
	words.add_child(UIStyle.label(String(card_info.name), "body"))
	var line := UIStyle.label(GameData.card_line(id), "small", UIStyle.color("text_soft"))
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = 380
	words.add_child(line)
	row.add_child(words)
	var popup := UIStyle.chip(row, UIStyle.color("toast"))
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.z_index = OVER_FIELD
	add_child(popup)
	popup.reset_size()
	var rect := card.get_global_rect()
	var screen := get_viewport_rect().size
	popup.position = Vector2(clampf(rect.get_center().x - popup.size.x / 2.0, 8.0, screen.x - popup.size.x - 8.0),
		maxf(8.0, rect.position.y - popup.size.y - 10.0))
	UIKit.pop_in(popup, 0.7, 0.2)
	_details = popup


func _hide_details() -> void:
	if _details != null and is_instance_valid(_details):
		_details.queue_free()
	_details = null


## A one-time hint in your very first match: what to tap.
func _first_match_tip() -> void:
	if not Profile.data.has("tips_seen"):
		return
	var seen: Array = Profile.data.tips_seen
	var key := "pick" if duel.is_first_round() else ("star" if duel.round_number == 2 else "")
	if key == "" or seen.has(key):
		return
	seen.append(key)
	Profile.save()
	var text := "Tap 3 animals" if key == "pick" else "Tap your animals: Upgrade or +Squad"
	var anchor: Control = _options_holder if key == "pick" else _herd_scroll
	_hide_tip()
	var tip := UIStyle.chip(UIStyle.label(text, "body"), UIStyle.color("primary"))
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.z_index = OVER_FIELD
	add_child(tip)
	_tip = tip
	(func() -> void:
		if not is_instance_valid(tip):
			return
		tip.reset_size()
		var rect := anchor.get_global_rect()
		# Just above what to tap, in the gap; it stays until you pick.
		tip.position = Vector2((get_viewport_rect().size.x - tip.size.x) / 2.0, rect.position.y - tip.size.y - UIStyle.space("xs"))
		if key == "pick":
			tip.position.y = rect.position.y - tip.size.y * 0.5
		UIKit.pop_in(tip, 0.6, 0.3)
		var bob := tip.create_tween().set_loops()
		bob.tween_property(tip, "position:y", tip.position.y - 6.0, 0.4).set_trans(Tween.TRANS_SINE)
		bob.tween_property(tip, "position:y", tip.position.y, 0.4).set_trans(Tween.TRANS_SINE)).call_deferred()


func _hide_tip() -> void:
	if _tip != null and is_instance_valid(_tip):
		var tip := _tip
		tip.create_tween().tween_property(tip, "modulate:a", 0.0, 0.2).finished.connect(tip.queue_free)
	_tip = null


## A small round back arrow: "tap to take this back".
class _UndoBadge:
	extends Control

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0
		UIStyle.draw_particle(self, "badge", c, r, UIStyle.color("danger"))
		var arrow := UIKit.icon(GameData.ui_icon("reroll"))
		if arrow != null:
			draw_texture_rect(arrow, Rect2(c - Vector2(r, r) * 0.6, Vector2(r, r) * 1.2), false)


## A green check mark in a circle.
class _CheckBadge:
	extends Control

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0
		UIStyle.draw_particle(self, "badge", c, r, UIStyle.color("primary"))
		var check := UIKit.icon(GameData.ui_icon("check"))
		if check != null:
			draw_texture_rect(check, Rect2(c - Vector2(r, r) * 0.62, Vector2(r, r) * 1.24), false)


# --- The opponent ----------------------------------------------------------------

## The opponent takes a moment over each pick, like a person would.
func _opponent_moves(delta: float) -> void:
	_bot_wait -= delta
	if duel.phase == "pick" and not duel.ready[bot.team] and _bot_wait <= 0.0:
		bot.pick()
		var gap := _size("bot_pick_seconds", Vector2(0.4, 0.8))
		_bot_wait = _rng.randf_range(gap.x, gap.y)


func _run_fight(delta: float) -> void:
	if _intro_left > 0.0:
		_intro_left -= delta
		return  # the opening beat: the herds hop in, then it starts
	if _field.is_frozen():
		return  # hit-stop: the fight holds still for a moment
	_speed_up_ending(delta)
	var tick_length := 1.0 / duel.sim.tps
	_accumulator += delta * _speed * (2.0 if _fast else 1.0)
	var steps := 0
	while _accumulator >= tick_length and steps < 10 and duel.phase == "fight":
		bot.update()
		duel.step()
		var events := duel.sim.take_events()
		_field.add_events(events)
		BattleField.play_sounds(events)
		for e in events:
			if e.type == "death":
				_quiet = 0.0
		_accumulator -= tick_length
		steps += 1
	if duel.phase == "fight":
		_field.blend = clampf(_accumulator / tick_length, 0.0, 1.0)


## With only a few animals left and nobody knocked out for a while, the
## fight (and the field with it) gradually plays faster, so the end never
## drags. Only how fast it plays changes, never what happens.
func _speed_up_ending(delta: float) -> void:
	var c := "choreography"
	var alive := 0
	for f in duel.sim.fighters:
		if f.alive and f.is_unit():
			alive += 1
	if alive <= Feel.count(c, "stall_animals", 4):
		_quiet += delta
	else:
		_quiet = 0.0
	var ramp := clampf((_quiet - Feel.num(c, "stall_after_seconds", 3.0)) / maxf(0.1, Feel.num(c, "stall_ramp_seconds", 3.0)), 0.0, 1.0)
	_speed = move_toward(_speed, 1.0 + ramp * (Feel.num(c, "stall_max_speed", 2.2) - 1.0), delta)
	_field.playback = _speed


func _reset_speed() -> void:
	_speed = 1.0
	_quiet = 0.0
	_field.playback = 1.0


# --- What happened -----------------------------------------------------------------

func _handle_events(events: Array) -> void:
	for e in events:
		match e.type:
			"round":
				_selected_tool = -1
				if _score_bar.visible:
					_show_view("pick")
			"fight":
				_field.end_celebrations()
				_reset_speed()
				_show_view("fight")
				# The opening beat: both armies stand in formation a moment,
				# then FIGHT! and they march.
				var lineup := Feel.num("army", "lineup_seconds", 1.2)
				_intro_left = lineup + Feel.num("choreography", "intro_seconds", 0.4)
				_field.snap_camera()
				get_tree().create_timer(lineup).timeout.connect(func() -> void:
					if duel.phase == "fight":
						Sound.play("horn")
						_banner("FIGHT!", UIStyle.color("gold"), Feel.count("choreography", "fight_banner_size", 96)))
				get_tree().create_timer(lineup + 0.6).timeout.connect(func() -> void: _rival_says("start"))
			"tool":
				Sound.play("horn" if e.id == "air_horn" else "tool")
			"rally":
				# The War Horn: the whole army surges.
				Sound.play("horn", 2.0)
				Sound.play("boom", -6.0)
				if int(e.team) == 0:
					_banner("WAR HORN!", UIStyle.color("gold"), Feel.count("choreography", "war_horn_banner_size", 72))
			"round_over":
				_selected_tool = -1
				_field.highlight = ""
				_reset_speed()
				# The last knockout in slow motion, then the winners celebrate
				# and the score pops up.
				var wait := _field.finish_fight(int(e.winner))
				if wait > 0.0:
					get_tree().create_timer(wait).timeout.connect(_round_result.bind(int(e.winner)))
				else:
					_round_result(int(e.winner))


## The quick result: the new score, big, then on to the next round.
func _round_result(winner: int) -> void:
	var c := "celebrations"
	var size := Feel.count(c, "banner_size", 54)
	var at := _field.get_global_rect().get_center()
	_score_pop(winner)
	if winner == 0:
		Sound.play("upgrade")
		var half := Feel.count("effects", "win_confetti", 60) / 2
		var rect := _field.get_global_rect()
		UIFx.particles.burst_confetti(rect.position + Vector2(rect.size.x * 0.25, rect.size.y * 0.35), half)
		UIFx.particles.burst_confetti(rect.position + Vector2(rect.size.x * 0.75, rect.size.y * 0.35), half)
		if bool(duel.last_round.get("flawless", false)):
			_banner("FLAWLESS!", Color("#7fe0ff"), size)
			UIFx.particles.burst("sparkle", at, Feel.count(c, "flawless_sparkles", 18), 260.0, 0.8, 10.0, [Color.WHITE, Color("#bff0ff"), Color("#ffe14d")], -40.0, 2.0)
			Sound.play("fanfare", 2.0)
	elif winner == 1:
		Sound.play("pop")
	if not duel.is_over():
		_rival_says("losing" if winner == 0 else ("winning" if winner == 1 else "start"))
		get_tree().create_timer(Feel.num("pick", "result_seconds", 1.8)).timeout.connect(func() -> void:
			if duel.phase == "round_over":
				duel.next_round())


## The new score pops up big over the field (the round winner's number
## glowing), then flies up into the score bar.
func _score_pop(winner: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.z_index = OVER_FIELD
	var big := Feel.count("celebrations", "score_pop_size", 120)
	var parts := [str(duel.wins[0]), "-", str(duel.wins[1])]
	var colors := [Color.WHITE, Color.WHITE, Color.WHITE]
	if winner == 0:
		colors[0] = UIStyle.color("gold")
	elif winner == 1:
		colors[2] = Color("#ff8a7a")
	for i in 3:
		var part := UIStyle.label(parts[i], "title", colors[i], HORIZONTAL_ALIGNMENT_CENTER)
		part.add_theme_font_size_override("font_size", big if i != 1 else big * 2 / 3)
		part.add_theme_constant_override("outline_size", UIStyle.outline_for(big))
		row.add_child(part)
	add_child(row)
	row.reset_size()
	var field := _field.get_global_rect()
	row.position = field.get_center() - row.size / 2.0 - get_global_rect().position
	row.pivot_offset = row.size / 2.0
	row.scale = Vector2(0.2, 0.2)
	var goal := _score_label.get_global_rect().get_center() - get_global_rect().position - row.size / 2.0
	var shrink := clampf(_score_label.size.y / maxf(1.0, row.size.y), 0.2, 1.0)
	var hold := Feel.num("pick", "result_seconds", 1.8)
	var tween := row.create_tween()
	tween.tween_property(row, "scale", Vector2(1.15, 1.15), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(row, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(maxf(0.2, hold - 0.9))
	tween.set_parallel()
	tween.tween_property(row, "position", goal, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(row, "scale", Vector2(shrink, shrink), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(row, "modulate:a", 0.0, 0.2).set_delay(0.25)
	tween.chain().tween_callback(row.queue_free)


func _celebrate_if_three_stars(id: String, rect: Rect2) -> void:
	var index := duel.herd_index(0, id)
	if index < 0 or int(duel.herds[0][index].stars) < int(duel.rules.star_max):
		return
	var c := "celebrations"
	Sound.play("star3")
	UIFx.particles.burst("star", rect.get_center(), Feel.count(c, "star3_stars", 22), 260.0, 0.9, 9.0, [Color("#ffe14d"), Color("#ffb03b"), Color.WHITE], 380.0, 1.2, 180.0)
	UIFx.particles.burst_confetti(rect.get_center(), Feel.count(c, "star3_confetti", 36))
	_banner("3 STARS!", Color("#ffe14d"), Feel.count(c, "star3_text_size", 64))


## Big bouncy words in the middle of the screen.
func _banner(text: String, color: Color, font_size: int) -> void:
	# One banner at a time: a second one waits its turn.
	var now := Time.get_ticks_msec() / 1000.0
	var wait := _banner_free_at - now
	_banner_free_at = maxf(now, _banner_free_at) + Feel.num("celebrations", "banner_seconds", 1.4) * 0.8
	if wait > 0.0:
		get_tree().create_timer(wait).timeout.connect(_show_banner.bind(text, color, font_size))
	else:
		_show_banner(text, color, font_size)


func _show_banner(text: String, color: Color, font_size: int) -> void:
	var title := UIStyle.label(text, "title", color, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_font_size_override("font_size", font_size)
	title.add_theme_constant_override("outline_size", UIStyle.outline_for(font_size))
	title.z_index = OVER_FIELD
	add_child(title)
	var screen := get_viewport_rect().size
	title.size = Vector2(screen.x, 0)
	title.reset_size()
	title.size.x = screen.x
	title.position = Vector2(0, screen.y * 0.36)
	title.pivot_offset = title.size / 2.0
	title.scale = Vector2(0.2, 0.2)
	var seconds := Feel.num("celebrations", "banner_seconds", 1.4)
	var tween := title.create_tween()
	tween.tween_property(title, "scale", Vector2(1.15, 1.15), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(title, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(maxf(0.1, seconds - 0.7))
	tween.set_parallel()
	tween.tween_property(title, "modulate:a", 0.0, 0.3)
	tween.tween_property(title, "position:y", title.position.y - 40.0, 0.3)
	tween.chain().tween_callback(title.queue_free)


# --- The fight: Rally and tools -------------------------------------------------------

## The buttons under the field: Rally, then one per tool (each works once a
## fight). Tap one, then the field.
func _refresh_actions() -> void:
	var key := str([duel.phase, duel.rally_ready[0], duel.tools[0], duel.tools_ready[0], _selected_tool, _intro_left > 0.0])
	if key == _actions_key:
		return
	_actions_key = key
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	var rally := UIStyle.button("War Horn", "gold" if duel.rally_ready[0] and duel.phase == "fight" else "secondary", "war_horn")
	rally.disabled = not duel.rally_ready[0] or duel.phase != "fight" or _intro_left > 0.0
	rally.pressed.connect(_blow_war_horn)
	_actions.add_child(rally)
	for i in duel.tools[0].size():
		var id: String = duel.tools[0][i]
		var button := ChunkyButton.make("", "gold" if i == _selected_tool else "tool")
		button.square = true
		var art := TextureRect.new()
		art.texture = UIKit.icon(GameData.card_icon(id))
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2(54, 54)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.content.add_child(art)
		button.disabled = i >= duel.tools_ready[0].size() or not bool(duel.tools_ready[0][i]) or duel.phase != "fight"
		var index: int = i
		button.pressed.connect(func() -> void:
			_selected_tool = -1 if _selected_tool == index else index
			_field.highlight = "field" if _selected_tool >= 0 else "")
		_actions.add_child(button)


## The War Horn, once a fight: your whole army surges at once.
func _blow_war_horn() -> void:
	var army: BattleArmy = duel.sim.army
	var x := duel.sim.width / 2
	var y: int = army.front[0] if army != null else duel.sim.middle
	_selected_tool = -1
	_field.highlight = ""
	if duel.rally(0, x, y):
		_field.add_events(duel.sim.take_events())


func _on_field_tapped(at: Vector2i) -> void:
	if duel.phase != "fight":
		return
	if _selected_tool >= 0 and duel.use_tool(0, _selected_tool, at.x, at.y):
		_field.add_events(duel.sim.take_events())
		_selected_tool = -1
		_field.highlight = ""


# --- The rival's reactions -------------------------------------------------

## The rival reacts with one of their emotes (rivals.json): a picture in a
## bubble by their face (no words), and their face changes for a moment.
func _rival_says(moment: String) -> bool:
	var emote := GameData.find_by_id(GameData.emotes, opponent.get("emotes", {}).get(moment, ""))
	var now := Time.get_ticks_msec() / 1000.0
	if emote.is_empty() or now < _emote_free_at or not _result.is_empty():
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
	bubble.position = Vector2(anchor.get_center().x - bubble.size.x + 12.0, anchor.end.y + 2.0)
	bubble.pivot_offset = Vector2(bubble.size.x - 12.0, 0)
	bubble.scale = Vector2(0.2, 0.2)
	var tween := bubble.create_tween()
	tween.tween_property(bubble, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(maxf(0.2, seconds - 0.55))
	tween.tween_property(bubble, "modulate:a", 0.0, 0.25)
	tween.tween_callback(bubble.queue_free)
	return true


## A speech bubble with an emote's picture (no words).
func _emote_bubble(emote: Dictionary) -> Control:
	var style := UIKit.box(Color.WHITE, 18, 6)
	style.corner_radius_top_right = 4
	style.set_border_width_all(3)
	style.border_color = UIStyle.color("outline")
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", style)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := IconArt.make(GameData.emote_icon(emote.id), Color(emote.get("color", "#888888")))
	art.custom_minimum_size = Vector2(56, 56)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(art)
	return bubble


## The rival cheers their own big hits (once a round).
func _on_strong_hit(team: int) -> void:
	if team == bot.team and _big_hit_round != duel.round_number and _rival_says("big_hit"):
		_big_hit_round = duel.round_number


# --- Popups ------------------------------------------------------------------------

## A dimmed full-screen layer with a panel in the middle holding `content`.
## With `tap_outside_closes`, tapping the dim closes it.
func _overlay(content: Control, tap_outside_closes := false) -> Control:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.z_index = OVER_FIELD  # above flying animals
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	if tap_outside_closes:
		dim.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed:
				layer.queue_free())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var panel := UIStyle.panel(content)
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)
	dim.modulate.a = 0.0
	dim.create_tween().tween_property(dim, "modulate:a", 1.0, 0.2)
	(func() -> void: UIKit.pop_in(panel, 0.8, Feel.num("ui", "panel_seconds", 0.32))).call_deferred()
	return layer


# --- End of the match ------------------------------------------------------

func _end_match() -> void:
	if not _result.is_empty():
		return
	var winner := duel.match_winner()
	var outcome := "draw" if winner == DraftMatch.NO_WINNER else ("win" if winner == 0 else "loss")
	_record(outcome)
	Sound.stop_music()
	Sound.play({"win": "victory", "loss": "defeat", "draw": "reveal"}[outcome])
	var box := UIStyle.vbox("m")
	var titles := {"win": "Victory!", "loss": "Defeat", "draw": "Draw"}
	if outcome == "win" and _most_behind >= 2:
		titles.win = "Comeback Victory!"
	var boss_beaten: bool = _result.get("boss_beaten", false)
	if boss_beaten:
		titles.win = "Boss Defeated!"
	var colors := {"win": UIStyle.color("gold"), "loss": UIStyle.color("danger").lightened(0.3), "draw": UIStyle.color("text")}
	box.add_child(UIStyle.label(titles[outcome], "title", colors[outcome], HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_rival_reaction(outcome))
	box.add_child(UIStyle.label("%d - %d" % [duel.wins[0], duel.wins[1]], "title", Color(0, 0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER))
	if opponent.boss:
		box.add_child(_boss_lines(boss_beaten))
	var ok := UIStyle.button("OK", "primary")
	ok.min_width = 240.0
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(_back_to_menu)
	box.add_child(ok)
	# A beaten boss gets its own moment first.
	var show_result := func() -> void:
		_overlay(box)
		if outcome == "win":
			var screen_size := get_viewport_rect().size
			for i in 3:
				UIFx.particles.burst_confetti(Vector2(screen_size.x * (0.2 + 0.3 * i), screen_size.y * 0.3), Feel.count("effects", "win_confetti", 60) / 2)
			UIFx.particles.burst_coins(screen_size / 2.0 + Vector2(0, -120), Feel.count("effects", "coin_burst", 8) * 2)
	if boss_beaten:
		_celebrate_boss()
		get_tree().create_timer(Feel.num("rivals", "boss_celebration_seconds", 1.8)).timeout.connect(show_result)
	else:
		show_result.call()


## The rival's face and their emote at the end: happy if they won, sad if
## you did.
func _rival_reaction(outcome: String) -> Control:
	var row := UIStyle.hbox("s")
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var portrait := RangerPortrait.create(opponent, 104)
	portrait.mood = {"win": "sad", "loss": "happy"}.get(outcome, "normal")
	row.add_child(portrait)
	var moment: String = {"win": "losing", "loss": "winning"}.get(outcome, "start")
	var emote := GameData.find_by_id(GameData.emotes, opponent.get("emotes", {}).get(moment, ""))
	if not emote.is_empty():
		row.add_child(_emote_bubble(emote))
	return row


## Under a boss match's result: where you've got to, and the first-win reward.
func _boss_lines(beaten: bool) -> Control:
	var box := UIStyle.vbox("xs")
	var next := int(opponent.arena_index) + 1
	if beaten and next < GameData.arenas.size():
		box.add_child(UIStyle.label("On to %s!" % GameData.get_arena(next).name, "body", UIStyle.color("gold"), HORIZONTAL_ALIGNMENT_CENTER))
	var reward: Dictionary = _result.get("boss_reward", {})
	if not reward.is_empty():
		var row := UIStyle.hbox("s")
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		var gold := UIStyle.pill("gold", UIStyle.color("gold"), int(reward.gold), true)
		row.add_child(gold)
		row.add_child(UIStyle.pill("gems", UIStyle.color("gem"), int(reward.gems)))
		box.add_child(row)
	return box


## Beating a boss: a gold banner, bursts of stars, and coins.
func _celebrate_boss() -> void:
	var screen_size := get_viewport_rect().size
	_banner("BOSS DEFEATED!", UIStyle.color("gold"), Feel.count("celebrations", "banner_size", 54))
	Sound.play("fanfare")
	for i in 4:
		var at := Vector2(screen_size.x * (0.15 + 0.233 * i), screen_size.y * (0.22 + 0.08 * (i % 2)))
		get_tree().create_timer(0.25 * i).timeout.connect(func() -> void:
			UIFx.stars(at, Feel.count("celebrations", "star3_stars", 22) / 2)
			Sound.play("pop"))
	get_tree().create_timer(1.1).timeout.connect(func() -> void:
		Sound.play("star3")
		UIFx.particles.burst_coins(screen_size / 2.0, Feel.count("effects", "coin_burst", 8) * 3))


func _record(outcome: String) -> void:
	_result = Profile.record_match(outcome, int(opponent.trophies), bool(opponent.boss))
	_result["score"] = duel.wins.duplicate()
	_result["rival"] = opponent.id


func _back_to_menu() -> void:
	Profile.pending_match_result = _result
	Transition.go(MENU_SCENE)


func _on_leave() -> void:
	Modal.confirm("Leave the match? It counts as a loss.", "Leave", _leave_now, UIKit.RED)


func _leave_now() -> void:
	if _result.is_empty():
		_record("loss")
	_back_to_menu()


## Pops a control in after `delay` seconds.
func _pop_after(control: Control, delay: float) -> void:
	control.modulate.a = 0.0
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if is_instance_valid(control):
			UIKit.pop_in(control, 0.6, Feel.num("ui", "panel_seconds", 0.32)))
