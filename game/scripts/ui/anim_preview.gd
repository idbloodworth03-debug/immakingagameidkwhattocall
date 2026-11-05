extends Control
## For testing (Profile > Developer tools > Animation preview): three
## animals on a small field, each with a sparring partner, and buttons that
## make them act out every animation and reaction on demand: standing, a
## fidget, walking, both attacks, getting hit, a big hit, stunned, slowed,
## nearly beaten, celebrating, knocked out, a Stun animal's big blow and
## burrowing. Starts with the combat polish samples (a Tank, a Tank
## Destroyer and a flier); Next shows three more.
##
## The little fight is never stepped: the buttons move the animals and
## hand the field the same events a fight would.

const MENU_SCENE := "res://scenes/main.tscn"
const SAMPLES := ["brown_bear", "lion", "peregrine_falcon"]
const PARTNER := "wild_boar"
const T := BattleSim.TILE
const ACTIONS := [
	["Stand", "idle"], ["Fidget", "fidget"], ["Walk", "walk"], ["Attack", "attack"],
	["Attack 2", "attack2"], ["Get hit", "hit"], ["Big hit", "big_hit"], ["Stunned", "stun"],
	["Slowed", "slow"], ["Nearly beaten", "low"], ["Celebrate", "victory"], ["Knockout", "knockout"],
	["Stun blow", "special"], ["Burrow", "burrow"],
]

var field: BattleField
var sim: BattleSim
var ids: Array = SAMPLES.duplicate()
var actors: Array = []
var partners: Array = []
var _roster: Array = []
var _page := -1
var _ticks := 0.0
var _walk_left := 0.0
var _walk_from: Array = []
var _respawn_in := -1.0
var _unburrow_in := -1.0
var _names: Label
## What's being acted out, over the field for a moment.
var _caption: Label
var _caption_left := 0.0


func _ready() -> void:
	theme = UIStyle.theme()
	add_child(UIStyle.backdrop())
	var safe := UIStyle.safe_margins(get_viewport())
	var column := UIStyle.vbox("s")
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 12
	column.offset_right = -12
	column.offset_top = 8 + float(safe.top)
	column.offset_bottom = -8 - float(safe.bottom)
	add_child(column)
	var top := UIStyle.hbox("s")
	var back := UIStyle.button("Back", "secondary", "", -1, "small")
	back.pressed.connect(func() -> void: Transition.go(MENU_SCENE))
	top.add_child(back)
	_names = UIStyle.label("", "small")
	_names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_names.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(_names)
	var next := UIStyle.button("Next", "secondary", "", -1, "small")
	next.pressed.connect(_next_page)
	top.add_child(next)
	column.add_child(top)
	field = BattleField.new()
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var arena := GameData.get_arena(Profile.arena_index())
	field.arena_id = arena.id
	field.grass = Color(arena.color)
	column.add_child(field)
	_caption = UIStyle.label("", "large", Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_caption.offset_top = 10
	_caption.z_index = 5
	_caption.add_theme_constant_override("outline_size", 10)
	_caption.add_theme_color_override("font_outline_color", UIKit.INK)
	field.add_child(_caption)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for action in ACTIONS:
		var b := UIStyle.button(String(action[0]), "secondary", "", -1, "small")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var what := String(action[1])
		b.pressed.connect(func() -> void: act(what))
		grid.add_child(b)
	column.add_child(grid)
	for id in GameData.card_order:
		if not GameData.is_tool(id) and UnitSprites.has(id) and not SAMPLES.has(id):
			_roster.append(id)
	_roster.sort_custom(func(a, b): return GameData.class_of(a) < GameData.class_of(b))
	_reset()


## Shows the next three animals (by class), after the samples.
func _next_page() -> void:
	_page += 1
	if _page * 3 >= _roster.size():
		_page = -1
	ids = SAMPLES.duplicate() if _page < 0 else _roster.slice(_page * 3, _page * 3 + 3)
	_reset()


func _reset() -> void:
	sim = BattleSim.new([{}, {}], 1)
	# A small field, so the camera shows the animals big.
	sim.width = 9 * T
	sim.height = 11 * T
	sim.middle = sim.height / 2
	actors.clear()
	partners.clear()
	for i in ids.size():
		var x := roundi((1.6 + i * 2.9) * T)
		var a: BattleSim.Fighter = sim.spawn(0, String(ids[i]), x, 4 * T)[0]
		var p: BattleSim.Fighter = sim.spawn(1, PARTNER, x + roundi(1.1 * T), roundi(7.6 * T))[0]
		for f: BattleSim.Fighter in [a, p]:
			f.deploy_ticks = 0
			f.cooldown = 0
		a.target = p
		p.target = a
		actors.append(a)
		partners.append(p)
	field.sim = sim
	field.blend = 1.0
	field.snap_camera()
	var names := []
	for id in ids:
		names.append("%s (%s)" % [GameData.cards[id].name, GameData.class_info(GameData.class_of(id)).get("name", "")])
	_names.text = ", ".join(names)
	_walk_left = 0.0
	_respawn_in = -1.0


func _process(delta: float) -> void:
	if sim == null:
		return
	# The fight's clock for stuns and slows (it isn't stepped). The field
	# reads the animals' changes once a tick, so the tick moves on every
	# frame here.
	sim.tick += 1
	_ticks += delta * sim.tps
	while _ticks >= 1.0:
		_ticks -= 1.0
		for f: BattleSim.Fighter in actors + partners:
			f.stun = maxi(0, f.stun - 1)
			f.slow = maxi(0, f.slow - 1)
	if _walk_left > 0.0:
		# Out to the right and back.
		_walk_left = maxf(0.0, _walk_left - delta)
		var u := 1.0 - _walk_left / 3.0
		for i in actors.size():
			var f: BattleSim.Fighter = actors[i]
			var x := roundi(float(_walk_from[i]) + sin(u * PI) * 1.4 * T)
			f.memory.run = int(f.memory.get("run", 0)) + absi(x - f.x)
			f.x = x
			f.prev_x = x
	_caption_left -= delta
	_caption.modulate.a = clampf(_caption_left / 0.3, 0.0, 1.0)
	if _unburrow_in >= 0.0:
		_unburrow_in -= delta
		if _unburrow_in < 0.0:
			for f: BattleSim.Fighter in actors:
				f.memory.burrowing = false
				field.add_events([{"type": "emerge", "uid": f.uid, "x": f.x, "y": f.y}])
	if _respawn_in >= 0.0:
		_respawn_in -= delta
		if _respawn_in < 0.0:
			_reset()


## Acts out one thing (the names in ACTIONS).
func act(what: String) -> void:
	var now := field.now()
	for action in ACTIONS:
		if action[1] == what:
			_caption.text = String(action[0])
			_caption_left = 1.6
	match what:
		"idle":
			field.end_celebrations()
			for f: BattleSim.Fighter in actors:
				f.stun = 0
				f.slow = 0
				f.hp = f.max_hp
		"fidget":
			for f: BattleSim.Fighter in actors:
				var v := field.view_for_uid(f.uid)
				if v != null:
					v.fidget_now(now)
		"walk":
			_walk_left = 3.0
			_walk_from = actors.map(func(f): return f.x)
		"burrow":
			# Down into the ground, then up again a moment later.
			for f: BattleSim.Fighter in actors:
				f.memory.burrowing = true
			_unburrow_in = 1.4
		"attack", "attack2", "special":
			for i in actors.size():
				var v := field.view_for_uid(actors[i].uid)
				if v != null:
					v.prefer_attack(what)
				field.add_events([_hit(actors[i], partners[i], 120)])
		"hit", "big_hit":
			for i in actors.size():
				var a: BattleSim.Fighter = actors[i]
				field.add_events([_hit(partners[i], a, a.max_hp / 2 if what == "big_hit" else 60)])
		"stun":
			for f: BattleSim.Fighter in actors:
				f.stun = 3 * sim.tps
				field.add_events([{"type": "stun", "uid": f.uid, "x": f.x, "y": f.y}])
		"slow":
			for f: BattleSim.Fighter in actors:
				f.slow = 4 * sim.tps
				f.slow_pct = 40
		"low":
			for f: BattleSim.Fighter in actors:
				f.hp = f.max_hp / 5 if f.hp == f.max_hp else f.max_hp
		"victory":
			field.celebrate_team(0)
		"knockout":
			for f: BattleSim.Fighter in actors:
				f.alive = false
				field.add_events([{"type": "death", "uid": f.uid, "kind": "unit", "team": 0, "x": f.x, "y": f.y}])
			_respawn_in = 1.8


## A hit as the fight would report it (it takes no health here).
func _hit(from: BattleSim.Fighter, to: BattleSim.Fighter, amount: int) -> Dictionary:
	return {"type": "hit", "from": from.uid, "from_kind": "unit", "to": to.uid, "to_kind": "unit",
		"x": to.x, "y": to.y, "fx": from.x, "fy": from.y, "amount": amount, "dealt": 0,
		"ranged": from.attack_range > 1500}
