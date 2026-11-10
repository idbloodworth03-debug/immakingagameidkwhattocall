extends Control
## Before a Draft Duel match, once you own enough animals (BanPhase): a coin
## flip, then you and the rival take turns banning animals nobody can use
## this match, 3 each. A grid of big cards; a banner says whose turn it is;
## on yours, tap a card and BAN; the rival thinks a moment (dots by its
## face) and bans one of yours. Every ban stamps a big red X on its card.
## Then on to your deck (deck_screen.gd), with the bans in MatchPlan.
## The cards sort by Level, Rarity, Class or Biome (SortBar), in groups
## with a header each; re-sorting moves the cards, stamps and all.
## Timings and sizes: feel.json "bans".

const MENU_SCENE := "res://scenes/main.tscn"
const DECK_SCENE := "res://scenes/deck.tscn"

var phase: BanPhase
var rival: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _cards := {}
var _selected := ""
var _banner: PanelContainer
var _banner_label: Label
var _thinking: _Dots
var _scroll: ScrollContainer
## The cards' groups: a header and a grid for each.
var _groups: VBoxContainer
var _sort: SortBar
var _coin: _Coin
var _ban_button: ChunkyButton
var _slots := [[], []]
var _busy := true
## Tests turn this off: no coin flip, no turns (they drive the phase).
var auto_start := true


func _ready() -> void:
	theme = UIStyle.theme()
	add_child(UIStyle.backdrop())
	_rng.randomize()
	rival = Opponents.next_for_player(_rng)
	MatchPlan.clear()
	MatchPlan.opponent = rival
	var owned: Array = GameData.card_order.filter(func(id): return Profile.has_card(id) and not GameData.is_tool(id))
	phase = BanPhase.new(BanPhase.choices_for(owned, int(rival.get("arena_index", 0))), owned, _rng.randi_range(0, 1))
	_build()
	if auto_start:
		_flip_coin()


func _num(key: String, fallback: float) -> float:
	return Feel.num("bans", key, fallback)


func _color(key: String, fallback: String) -> Color:
	return Color(String(GameData.feel.get("bans", {}).get(key, fallback)))


func _build() -> void:
	var safe := UIStyle.safe_margins(get_viewport())
	var margin := UIStyle.num("screen", "margin", 16)
	var column := UIStyle.vbox("s")
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = margin
	column.offset_right = -margin
	column.offset_top = 12 + float(safe.top)
	column.offset_bottom = -12 - float(safe.bottom)
	add_child(column)

	# Back, the title, and who you're up against.
	var top := UIStyle.hbox("s")
	var back := UIStyle.button("Back", "secondary", "", -1, "small")
	back.pressed.connect(func() -> void:
		MatchPlan.clear()
		Transition.go(MENU_SCENE))
	top.add_child(back)
	var title := UIStyle.label("BANS", "title", Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(RangerPortrait.create(rival, 76.0))
	column.add_child(top)

	# Whose turn: a big colored banner (the coin spins in it first).
	_banner = PanelContainer.new()
	_banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := UIStyle.hbox("s")
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_coin = _Coin.new()
	row.add_child(_coin)
	_banner_label = UIStyle.label("", "title", Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	row.add_child(_banner_label)
	_thinking = _Dots.new()
	_thinking.visible = false
	row.add_child(_thinking)
	_banner.add_child(row)
	column.add_child(_banner)
	_set_banner("", Color(0.2, 0.2, 0.25))

	# Each side's three bans: yours on the left, the rival's on the right.
	var tracks := UIStyle.hbox("xs")
	tracks.alignment = BoxContainer.ALIGNMENT_CENTER
	for team in 2:
		if team == 1:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(28, 0)
			tracks.add_child(gap)
		for i in phase.per_player:
			var slot := _Slot.new()
			slot.tint = _color("you_color" if team == 0 else "rival_color", "#888888")
			tracks.add_child(slot)
			_slots[team].append(slot)
	column.add_child(tracks)

	# The first time: one short line.
	var seen: Array = Profile.data.get("tips_seen", [])
	if not seen.has("ban"):
		seen.append("ban")
		Profile.data["tips_seen"] = seen
		Profile.save()
		var tip := UIStyle.chip(UIStyle.label("Banned animals sit out this match, for both sides", "body"), UIStyle.color("primary"))
		tip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(tip)

	# Sort them: Level, Rarity, Class, Biome.
	_sort = SortBar.make("bans")
	_sort.sort_changed.connect(func(_key: String, _desc: bool) -> void: _lay_out())
	column.add_child(_sort)

	# The animals.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_groups = UIStyle.vbox("s")
	_groups.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_groups)
	var size_value: Variant = GameData.feel.get("bans", {}).get("card", [158, 214])
	var card_size := Vector2(float(size_value[0]), float(size_value[1]))
	for id in phase.choices:
		var card := AnimalCard.create(id)
		card.info = AnimalCard.Info.LEVEL if phase.owned.has(id) else AnimalCard.Info.NONE
		card.custom_minimum_size = card_size
		card.pivot_offset = card_size / 2.0
		UIKit.on_tap(card, func() -> void: _tap(id))
		_cards[id] = card
	_lay_out()

	_ban_button = UIStyle.button("BAN", "danger", "close")
	_ban_button.min_width = 400.0
	_ban_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ban_button.pressed.connect(_ban_selected)
	column.add_child(_ban_button)
	_refresh_button()


## Puts the cards in their groups for the chosen sort. The cards are the
## same ones, moved (a ban's X and the selection go with them).
func _lay_out() -> void:
	for card: AnimalCard in _cards.values():
		if card.get_parent() != null:
			card.get_parent().remove_child(card)
	for child in _groups.get_children():
		_groups.remove_child(child)
		child.queue_free()
	var levels := {}
	for id: String in phase.owned:
		levels[id] = Profile.card_level(id)
	for group in AnimalSort.grouped(phase.choices, _sort.key, _sort.desc, levels):
		_groups.add_child(AnimalSort.header(group))
		var center := CenterContainer.new()
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var grid := GridContainer.new()
		grid.columns = int(_num("columns", 4))
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		# Always a full row wide, so a short group lines up on the left.
		var size_value: Variant = GameData.feel.get("bans", {}).get("card", [158, 214])
		grid.custom_minimum_size.x = grid.columns * float(size_value[0]) + (grid.columns - 1) * 10
		center.add_child(grid)
		_groups.add_child(center)
		for id: String in group.ids:
			_cards[id].show_class = not AnimalSort.names_class(_sort.key)
			grid.add_child(_cards[id])


## The cards' ids in the order shown.
func shown_order() -> Array:
	var out := []
	for center in _groups.get_children():
		if center is CenterContainer:
			for card: AnimalCard in center.get_child(0).get_children():
				out.append(card.animal_id)
	return out


func _set_banner(text: String, color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(40)
	box.content_margin_left = 34
	box.content_margin_right = 34
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	box.border_color = color.darkened(0.45)
	box.set_border_width_all(4)
	_banner.add_theme_stylebox_override("panel", box)
	_banner_label.text = text
	_banner_label.visible = text != ""


func _refresh_button() -> void:
	var can := not _busy and phase.turn() == 0 and _selected != ""
	_ban_button.disabled = not can
	_ban_button.kind = "danger" if can else "disabled"
	_ban_button.breathe = can


# --- The coin flip -------------------------------------------------------------

func _flip_coin() -> void:
	_busy = true
	_set_banner("", Color(0.25, 0.22, 0.3))
	_coin.visible = true
	_coin.result = phase.first
	_coin.spin(_num("coin_seconds", 1.2))
	Sound.play("whoosh", -4.0)
	await get_tree().create_timer(_num("coin_seconds", 1.2)).timeout
	Sound.play("coin", -2.0)
	var you := phase.first == 0
	_set_banner("You ban first!" if you else "Rival bans first!", _color("you_color" if you else "rival_color", "#888888"))
	UIKit.pop_in(_banner, 0.7, 0.3)
	await get_tree().create_timer(0.9).timeout
	_coin.visible = false
	_next_turn()


# --- Turns ---------------------------------------------------------------------

func _next_turn() -> void:
	if phase.is_done():
		_finish()
		return
	if phase.turn() == 0:
		_busy = false
		_thinking.visible = false
		_set_banner("Your turn", _color("you_color", "#3b8ff0"))
		UIKit.pop_in(_banner, 0.8, 0.25)
		_refresh_button()
		return
	_busy = true
	_select("")
	_set_banner("Rival's turn", _color("rival_color", "#e0523b"))
	UIKit.pop_in(_banner, 0.8, 0.25)
	_thinking.visible = true
	var span: Variant = GameData.feel.get("bans", {}).get("think_seconds", [0.8, 1.2])
	await get_tree().create_timer(_rng.randf_range(float(span[0]), float(span[1]))).timeout
	_thinking.visible = false
	var id := phase.bot_choice(rival.get("style", {}), Profile.card_levels(), _rng, float(rival.get("difficulty", 0.5)))
	if id != "" and phase.ban(1, id):
		_stamp(id, 1)
	else:
		# Nothing the rival may ban (can't happen with the unlock rule):
		# its turn passes.
		phase.bans[1].append("")
	await get_tree().create_timer(_num("stamp_seconds", 0.28) + 0.35).timeout
	_next_turn()


func _tap(id: String) -> void:
	if _busy or phase.turn() != 0:
		return
	var why := phase.can_ban(0, id)
	if why != "":
		Sound.play("error", -4.0)
		_wiggle(_cards[id])
		_flash(why)
		return
	Sound.play("select", -4.0)
	_select("" if _selected == id else id)


func _select(id: String) -> void:
	if _selected != "" and _cards.has(_selected):
		_cards[_selected].highlighted = false
		_cards[_selected].create_tween().tween_property(_cards[_selected], "scale", Vector2.ONE, 0.12)
	_selected = id
	if id != "":
		_cards[id].highlighted = true
		_cards[id].create_tween().tween_property(_cards[id], "scale", Vector2.ONE * 1.06, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_refresh_button()


func _ban_selected() -> void:
	if _busy or _selected == "" or not phase.ban(0, _selected):
		return
	var id := _selected
	_select("")
	_busy = true
	_refresh_button()
	_stamp(id, 0)
	await get_tree().create_timer(_num("stamp_seconds", 0.28) + 0.3).timeout
	_next_turn()


## A short message in the banner (why a card can't be banned), then back.
func _flash(text: String) -> void:
	var before := _banner_label.text
	_banner_label.text = text
	await get_tree().create_timer(1.1).timeout
	if _banner_label.text == text:
		_banner_label.text = before


# --- The stamp -----------------------------------------------------------------

## Stamps a big red X on `id`'s card (and its side's next slot): it drops in
## big and lands with a thump and a shake; the card goes dark.
func _stamp(id: String, team: int) -> void:
	var card: AnimalCard = _cards[id]
	card.highlighted = false
	# The rival's ban may be further down the grid: bring it into view.
	_scroll.ensure_control_visible(card)
	var x := BanX.new()
	x.color = _color("stamp_color", "#e0302a")
	x.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(x)
	var seconds := _num("stamp_seconds", 0.28)
	x.pivot_offset = card.size / 2.0
	x.scale = Vector2.ONE * _num("stamp_scale", 2.6)
	x.rotation = deg_to_rad(-14.0)
	x.modulate.a = 0.0
	var tween := x.create_tween().set_parallel()
	tween.tween_property(x, "scale", Vector2.ONE, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(x, "rotation", 0.0, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(x, "modulate:a", 1.0, seconds * 0.4)
	var land := card.create_tween()
	land.tween_interval(seconds * 0.8)
	land.tween_callback(func() -> void:
		Sound.play("land", 0.0)
		Sound.play("hit", -6.0))
	land.tween_property(card, "scale", Vector2.ONE * 0.92, 0.06)
	land.tween_property(card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_shake(_num("stamp_shake", 10.0))
	var slot: _Slot = _slots[team][phase.bans[team].size() - 1]
	slot.fill(id)


func _wiggle(card: Control) -> void:
	var tween := card.create_tween()
	for angle in [-4.0, 4.0, -2.0, 0.0]:
		tween.tween_property(card, "rotation", deg_to_rad(angle), 0.05)


func _shake(pixels: float) -> void:
	var tween := create_tween()
	tween.tween_interval(_num("stamp_seconds", 0.28) * 0.8)
	for i in 4:
		var offset := Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * pixels * (1.0 - i / 4.0)
		tween.tween_property(self, "position", offset, 0.035)
	tween.tween_property(self, "position", Vector2.ZERO, 0.04)


func _finish() -> void:
	_busy = true
	_refresh_button()
	_set_banner("Bans done!", UIStyle.color("primary"))
	UIKit.pop_in(_banner, 0.8, 0.25)
	Sound.play("upgrade", -4.0)
	MatchPlan.banned = phase.banned().filter(func(id): return id != "")
	await get_tree().create_timer(_num("done_seconds", 1.0)).timeout
	Transition.go(DECK_SCENE)


# --- Pieces ----------------------------------------------------------------------

## One of a side's ban slots: an empty dashed box in the side's color, then
## the banned animal's small card with an X.
class _Slot:
	extends Control
	var tint := Color.WHITE
	var _card: AnimalCard

	func _init() -> void:
		custom_minimum_size = Vector2(62, 82)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func fill(id: String) -> void:
		_card = AnimalCard.create(id, true)
		_card.info = AnimalCard.Info.NONE
		_card.scale = Vector2.ONE * (custom_minimum_size.x / AnimalCard.SIZE_SMALL.x)
		add_child(_card)
		var x := BanX.new()
		x.size = AnimalCard.SIZE_SMALL
		_card.add_child(x)
		UIKit.pop_in(self, 0.5, 0.25)
		queue_redraw()

	func _draw() -> void:
		if _card != null:
			return
		var rect := Rect2(Vector2(3, 3), size - Vector2(6, 6))
		draw_style_box(UIKit.box(tint.darkened(0.55), 10), rect)
		draw_rect(rect, tint, false, 3.0)


## The rival thinking: three dots bouncing one after another.
class _Dots:
	extends Control
	var _time := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(54, 40)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		for i in 3:
			var hop := maxf(0.0, sin(_time * 9.0 - i * 0.9)) * 9.0
			var at := Vector2(9.0 + i * 18.0, size.y * 0.62 - hop)
			draw_circle(at, 7.0, Color(0.1, 0.05, 0.05, 0.45))
			draw_circle(at, 5.5, Color.WHITE)


## The coin: spins (its face flipping between your paw and the rival's
## whistle) and lands on whoever bans first.
class _Coin:
	extends Control
	var result := 0
	var _left := 0.0
	var _total := 1.0

	func _init() -> void:
		custom_minimum_size = Vector2(64, 64)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func spin(seconds: float) -> void:
		_total = maxf(0.1, seconds)
		_left = _total
		set_process(true)

	func _process(delta: float) -> void:
		_left = maxf(0.0, _left - delta)
		queue_redraw()
		if _left <= 0.0:
			set_process(false)

	func _draw() -> void:
		var t := 1.0 - _left / _total
		# Fast at first, slowing to land: the number of half-turns so far.
		var turns := (1.0 - pow(1.0 - t, 2.0)) * 9.0 + (1.0 if result == 1 else 0.0)
		var face := int(floor(turns)) % 2 if _left > 0.0 else result
		var squeeze := absf(cos(turns * PI)) if _left > 0.0 else 1.0
		var center := size / 2.0
		var r := minf(size.x, size.y) / 2.0 - 2.0
		draw_set_transform(center, 0.0, Vector2(maxf(0.08, squeeze), 1.0))
		draw_circle(Vector2.ZERO, r, UIStyle.color("coin_rim"))
		draw_circle(Vector2.ZERO, r - 4.0, UIStyle.color("coin_face"))
		draw_circle(Vector2.ZERO, r - 10.0, UIStyle.color("player") if face == 0 else UIStyle.color("enemy"))
		var icon := UIKit.icon(GameData.ui_icon("paw" if face == 0 else "whistle"))
		if icon != null:
			var side := (r - 12.0) * 1.4
			draw_texture_rect(icon, Rect2(Vector2(-side, -side) / 2.0, Vector2(side, side)), false)
		draw_set_transform(Vector2.ZERO)
