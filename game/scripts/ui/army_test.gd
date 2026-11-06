class_name ArmyTest
extends Control
## For testing (Profile > Developer tools > Big army test, with the animals
## as 3D models (ModelStage), and Big army test (sprites)): the biggest
## armies there can be (40 animals a side: every class, elites, Mythic
## heroes, 3-star squads) fight over and over on the real battle field, with
## the frame rate on screen. After each fight a line sums it up: frames a
## second on average, the slowest 1% of frames, how many frames missed 60 a
## second, and how long the game's own code took each frame (the rest is
## drawing). Both sides blow their War Horn as the computer would.
##
## ARMY_TEST_LOG=file (an environment variable, on a computer) writes the
## summaries to that file and quits after ARMY_TEST_FIGHTS fights;
## ARMY_TEST_MODELS=1 (or 0) picks 3D models (or sprites).

const MENU_SCENE := "res://scenes/main.tscn"
## The next test shows the animals as 3D models (the game's way), or as the
## older sprites, for comparing (set by the Developer tools).
static var use_models := true
const ARMIES := [
	[["brown_bear", 3, 3], ["black_rhino", 1, 2], ["yeti", 1, 1], ["wild_boar", 3, 2], ["tiger", 2, 3],
		["gray_squirrel", 3, 3], ["wild_bactrian_camel", 1, 1], ["peregrine_falcon", 2, 2], ["california_condor", 1, 1],
		["red_fox", 1, 2], ["mountain_gorilla", 1, 1], ["electric_eel", 1, 1], ["harbor_seal", 1, 1],
		["dragon", 1, 1], ["unicorn", 1, 1], ["cerberus", 1, 1]],
	[["snapping_turtle", 3, 3], ["hippopotamus", 1, 2], ["asian_elephant", 1, 1], ["lion", 3, 2], ["komodo_dragon", 2, 3],
		["striped_skunk", 3, 3], ["raccoon", 1, 1], ["barn_owl", 2, 2], ["harpy_eagle", 1, 1],
		["red_panda", 1, 2], ["pygmy_three_toed_sloth", 1, 1], ["sunda_pangolin", 1, 1], ["kraken", 1, 1],
		["cerberus", 1, 1], ["yeti", 1, 1], ["dragon", 1, 1]],
]

var duel: DraftMatch
var bots: Array = []
var field: BattleField
var _stats: Label
var _history: Label
var _lines: Array = []
var _accumulator := 0.0
var _intro := 0.0
var _rest := 0.0
var _frames: PackedFloat32Array = PackedFloat32Array()
var _script_ms := 0.0
var _sim_ms := 0.0
var _sim_worst := 0.0
var _fight := 0
var _log := ""
var _fights_wanted := 3
## When this frame's game code started (a little node that goes first
## notes it; this screen goes last).
var _frame_start := 0
var _code: PackedFloat32Array = PackedFloat32Array()


class _FirstOfFrame:
	extends Node
	var test: Node

	func _process(_delta: float) -> void:
		test._frame_start = Time.get_ticks_usec()


func _ready() -> void:
	theme = UIStyle.theme()
	add_child(UIStyle.backdrop())
	process_priority = 1000
	var first := _FirstOfFrame.new()
	first.test = self
	first.process_priority = -1000
	add_child(first)
	_log = OS.get_environment("ARMY_TEST_LOG")
	if OS.get_environment("ARMY_TEST_FIGHTS") != "":
		_fights_wanted = int(OS.get_environment("ARMY_TEST_FIGHTS"))
	if OS.get_environment("ARMY_TEST_MODELS") != "":
		use_models = OS.get_environment("ARMY_TEST_MODELS") == "1"
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
	_stats = UIStyle.label("", "small")
	_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_stats)
	column.add_child(top)
	field = BattleField.new()
	field.use_models = use_models
	field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var arena := GameData.get_arena(Profile.arena_index())
	field.arena_id = arena.id
	field.grass = Color(arena.color)
	column.add_child(field)
	_history = UIStyle.label("Fights so far: none yet", "small")
	_history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_history.custom_minimum_size.y = 96
	column.add_child(_history)
	_start_fight()


func _start_fight() -> void:
	_fight += 1
	var levels := {}
	for id in GameData.card_order:
		levels[id] = GameData.start_level(GameData.cards[id].rarity)
	duel = DraftMatch.new(1000 + _fight, {"levels": [levels, levels]})
	for team in 2:
		var herd := []
		for spec in ARMIES[team]:
			herd.append({"id": spec[0], "stars": spec[2], "squads": spec[1]})
		duel.herds[team] = herd
		duel.picks_left[team] = 0
		duel.picks_made[team] = []
	duel._lay_out_herds()
	bots = [DraftBot.new(duel, 0, _fight * 7, 0.8), DraftBot.new(duel, 1, _fight * 13, 0.8)]
	duel.set_ready(0)
	duel.set_ready(1)
	duel.take_events()
	field.sim = duel.sim
	field.blend = 0.0
	field.snap_camera()
	_intro = Feel.num("army", "lineup_seconds", 1.2)
	_accumulator = 0.0
	_frames.clear()
	_code.clear()
	_script_ms = 0.0
	_sim_ms = 0.0
	_sim_worst = 0.0


func _process(delta: float) -> void:
	if duel == null:
		return
	if _rest > 0.0:
		_rest -= delta
		if _rest <= 0.0:
			_start_fight()
		return
	_frames.append(delta)
	if _intro > 0.0:
		_intro -= delta
	elif duel.phase == "fight" and not field.is_frozen():
		var tick := 1.0 / duel.sim.tps
		_accumulator += delta
		var steps := 0
		while _accumulator >= tick and steps < 4 and duel.phase == "fight":
			var t0 := Time.get_ticks_usec()
			for b in bots:
				b.update()
			duel.step()
			var used := (Time.get_ticks_usec() - t0) / 1000.0
			_sim_ms += used
			_sim_worst = maxf(_sim_worst, used)
			var events := duel.sim.take_events()
			field.add_events(events)
			BattleField.play_sounds(events)
			_accumulator -= tick
			steps += 1
		field.blend = clampf(_accumulator / tick, 0.0, 1.0)
	var on_field := duel.sim.units(0).size() + duel.sim.units(1).size()
	# How long the game's own code took this frame (the rest is drawing).
	var code := (Time.get_ticks_usec() - _frame_start) / 1000.0
	_code.append(code)
	_script_ms += code
	_stats.text = "%s%d fps   %d animals   fight %d   code %.1f ms" % ["3D  " if field.use_models else "", Engine.get_frames_per_second(), on_field, _fight, code]
	if duel.phase != "fight":
		_finish()


## Sums up the fight just played and starts another in a moment.
func _finish() -> void:
	var count := _frames.size()
	if count < 10:
		_rest = 1.0
		return
	var sorted := _frames.duplicate()
	sorted.sort()
	var total := 0.0
	var missed := 0
	for d in _frames:
		total += d
		if d > 1.0 / 55.0:
			missed += 1
	var worst := sorted[clampi(int(count * 0.99), 0, count - 1)]
	var codes := _code.duplicate()
	codes.sort()
	var code_worst: float = codes[clampi(int(codes.size() * 0.99), 0, codes.size() - 1)] if not codes.is_empty() else 0.0
	var line := ("3D models. " if field.use_models else "Sprites. ") + "Fight %d: %.0f fps on average, slowest 1%% of frames %.0f fps, %.1f%% of frames missed 60 fps; game code %.1f ms a frame (%.1f in the slowest 1%%), fight %.2f ms a step (%.1f at worst)" % [
		_fight, count / total, 1.0 / maxf(worst, 0.001), 100.0 * missed / count, _script_ms / maxf(1, _code.size()), code_worst,
		_sim_ms / maxf(1.0, duel.fight_tick), _sim_worst]
	_lines.append(line)
	_history.text = "\n".join(_lines.slice(-3))
	print(line)
	if _log != "":
		var f := FileAccess.open(_log, FileAccess.WRITE)
		f.store_string("\n".join(_lines) + "\n")
		f.close()
		if _lines.size() >= _fights_wanted:
			get_tree().quit()
	_rest = 1.5
