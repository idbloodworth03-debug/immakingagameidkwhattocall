extends Control
## For testing (Profile > Developer tools > Attack styles): each animal's
## attack style (styles.json) on its own, in a little fight set up so the
## style shows straight away: the animal (yours, at the bottom) against a
## few enemies placed to bring it out. Its name and its card's line on top;
## Back and Next go through every animal with a style; the fight starts over
## every showcase_seconds; the enemies bite at showcase_enemy_bite_pct so the
## animal lasts long enough to show its style; Slow plays it at
## showcase_slow_speed (feel.json "styles").

const MENU_SCENE := "res://scenes/main.tscn"
const T := BattleSim.TILE

## How each style is set up: who's on the field ([team, id, x tiles, y
## tiles], "self" for the animal shown), and what's arranged first:
## "hurt": the animal starts at this share of its health; "aim": every enemy
## goes for the teammate at this index first.
const STAGES := {
	"cleave": {"units": [[0, "self", 8, 11.5], [1, "wild_boar", 6.8, 9.6], [1, "wild_boar", 9.2, 9.6]]},
	"shell": {"units": [[0, "self", 8, 11.5], [1, "wild_boar", 6.8, 9.6], [1, "wild_boar", 9.2, 9.6]], "hurt": 0.45},
	"snack": {"units": [[0, "self", 8, 11.5], [1, "wild_boar", 6.8, 9.6], [1, "wild_boar", 9.2, 9.6]], "hurt": 0.55},
	"reflect": {"units": [[0, "self", 8, 11.5], [1, "wild_boar", 6.6, 9.8], [1, "wild_boar", 9.4, 9.8], [1, "honey_badger", 8, 9.2]]},
	"guard": {"units": [[0, "self", 8, 11], [0, "gray_squirrel", 8, 12.4], [1, "gray_squirrel", 7, 6.5], [1, "gray_squirrel", 9, 6.5]], "aim": 1},
	"rhino_charge": {"units": [[0, "self", 8, 16], [1, "raccoon", 6.4, 10.5], [1, "raccoon", 7.5, 10.5], [1, "raccoon", 8.6, 10.5], [1, "raccoon", 9.7, 10.5]]},
	"pound": {"units": [[0, "self", 8, 11.5], [1, "wild_boar", 6.6, 10.0], [1, "wild_boar", 9.4, 10.0], [1, "wolf_pack", 6.6, 13.0], [1, "wolf_pack", 9.4, 13.0]]},
	"rush": {"units": [[0, "self", 8, 15], [1, "raccoon", 6.5, 11], [1, "brown_bear", 8.6, 9]]},
	"pack": {"units": [[0, "self", 7.2, 12], [0, "self", 8.8, 12], [1, "brown_bear", 8, 9.6]]},
	"roar": {"units": [[0, "self", 8, 12], [0, "wild_boar", 6.6, 12.4], [0, "wolf_pack", 9.4, 12.4], [1, "brown_bear", 6.8, 9.8], [1, "snapping_turtle", 9.2, 9.8]]},
	"fearless": {"units": [[0, "self", 8, 12.5], [1, "gray_squirrel", 7.2, 11], [1, "asian_elephant", 9.6, 9]]},
	"stalk": {"units": [[0, "self", 8, 15], [1, "brown_bear", 8, 9.5]]},
	"venom": {"units": [[0, "self", 8, 12.5], [1, "brown_bear", 6.6, 10], [1, "snapping_turtle", 8, 9.6], [1, "giant_panda", 9.4, 10]]},
	"triple": {"units": [[0, "self", 8, 12], [1, "wild_boar", 6.9, 10.4], [1, "honey_badger", 8, 10], [1, "wolf_pack", 9.1, 10.4]]},
	"burst": {"units": [[0, "self", 8, 15], [1, "brown_bear", 7.4, 9.5], [1, "peregrine_falcon", 9.4, 9.8]]},
	"spray": {"units": [[0, "self", 8, 13.5], [1, "wild_boar", 6.9, 10.6], [1, "wild_boar", 8, 10.2], [1, "wild_boar", 9.1, 10.6]]},
	"lob": {"units": [[0, "self", 8, 16], [1, "brown_bear", 8, 11], [1, "gray_squirrel", 7.4, 8], [1, "gray_squirrel", 8.6, 8]]},
	"sniper": {"units": [[0, "self", 8, 17.5], [1, "brown_bear", 8, 8.5]]},
	"spit": {"units": [[0, "self", 8, 15], [1, "brown_bear", 8, 9.5]]},
	"bounce": {"units": [[0, "self", 8, 15.5], [1, "wild_boar", 6.6, 9.8], [1, "wild_boar", 8, 9.2], [1, "wild_boar", 9.4, 9.8]]},
	"pierce": {"units": [[0, "self", 8, 16.5], [1, "wild_boar", 8, 11.5], [1, "wild_boar", 8.1, 10], [1, "wild_boar", 7.9, 8.5]]},
}

var field: BattleField
var sim: BattleSim
var _ids: Array = []
var _index := 0
var _title: Label
var _line: Label
var _accumulator := 0.0
var _age := 0.0
var _over := 0.0


func _ready() -> void:
	theme = UIStyle.theme()
	add_child(UIStyle.backdrop())
	for id in GameData.card_order:
		if GameData.styles.has(id) and STAGES.has(String(GameData.styles[id].kind)):
			_ids.append(id)
	# By class (as they line up in battle), then in the cards' own order.
	_ids.sort_custom(func(a: String, b: String) -> bool:
		var ca := GameData.class_order.find(GameData.class_of(a))
		var cb := GameData.class_order.find(GameData.class_of(b))
		return ca < cb if ca != cb else GameData.card_order.find(a) < GameData.card_order.find(b))
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
	_title = UIStyle.label("", "title", Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	column.add_child(top)
	_line = UIStyle.label("", "large", UIStyle.color("gold"), HORIZONTAL_ALIGNMENT_CENTER)
	# A long line wraps instead of pushing the screen wider.
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size.x = 1.0
	_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_line)
	field = BattleField.new()
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var arena := GameData.get_arena(Profile.arena_index())
	field.arena_id = arena.id
	field.grass = Color(arena.color)
	field.camera_min_tiles = 9.0
	field.camera_max_zoom = 2.2
	field.camera_margin = 1.6
	column.add_child(field)
	var bottom := UIStyle.hbox("s")
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	var prev := UIStyle.button("Prev", "secondary")
	prev.pressed.connect(func() -> void: _show(_index - 1))
	bottom.add_child(prev)
	var again := UIStyle.button("Again", "secondary")
	again.pressed.connect(func() -> void: _show(_index))
	bottom.add_child(again)
	var slow := UIStyle.button("Slow", "secondary")
	slow.pressed.connect(func() -> void:
		var slowed := Engine.time_scale < 1.0
		Engine.time_scale = 1.0 if slowed else Feel.num("styles", "showcase_slow_speed", 0.3)
		slow.set_label("Slow" if slowed else "Normal"))
	bottom.add_child(slow)
	var next := UIStyle.button("Next", "primary")
	next.pressed.connect(func() -> void: _show(_index + 1))
	bottom.add_child(next)
	column.add_child(bottom)
	_show(0)


## Sets up the little fight for animal number `index` (wrapping round).
func _show(index: int) -> void:
	if _ids.is_empty():
		return
	_index = posmod(index, _ids.size())
	var id: String = _ids[_index]
	_title.text = String(GameData.cards[id].name)
	_line.text = GameData.style_line(id)
	var stage: Dictionary = STAGES[String(GameData.styles[id].kind)]
	sim = BattleSim.new([{}, {}], 7 + _index)
	# An army with nobody in it: the camera frames the fight like a battle.
	sim.army = BattleArmy.new(sim.rules, sim.tps)
	var made := []
	for u in stage.units:
		var who := id if String(u[1]) == "self" else String(u[1])
		var f: BattleSim.Fighter = sim.spawn_units(int(u[0]), who, 1, roundi(float(u[2]) * T), roundi(float(u[3]) * T))[0]
		f.deploy_ticks = 0
		made.append(f)
	var bite := int(Feel.num("styles", "showcase_enemy_bite_pct", 40.0))
	for f in made:
		if f.team == 1:
			f.damage = maxi(1, f.damage * bite / 100)
	if stage.has("hurt"):
		made[0].hp = maxi(1, roundi(made[0].max_hp * float(stage.hurt)))
	if stage.has("aim"):
		for f in made:
			if f.team == 1:
				f.target = made[int(stage.aim)]
	field.sim = sim
	field.snap_camera()
	_accumulator = 0.0
	_age = 0.0
	_over = 0.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	if sim == null:
		return
	_age += delta
	# Over a moment after one side is gone (so the knockout shows), or after
	# showcase_seconds anyway.
	_over = _over + delta if sim.units(0).is_empty() or sim.units(1).is_empty() else 0.0
	if _age > Feel.num("styles", "showcase_seconds", 7.0) or _over > 1.5:
		_show(_index)
		return
	if field.is_frozen():
		return
	var tick := 1.0 / sim.tps
	_accumulator += delta
	var steps := 0
	while _accumulator >= tick and steps < 4:
		sim.step()
		var events := sim.take_events()
		field.add_events(events)
		BattleField.play_sounds(events)
		_accumulator -= tick
		steps += 1
	field.blend = clampf(_accumulator / tick, 0.0, 1.0)
