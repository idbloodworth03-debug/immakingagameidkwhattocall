class_name DevShots
extends Node
## For testing on a computer: saves screenshots of the game as it runs, so a
## script can check a fight frame by frame. Started by the main menu with
## the dev shortcuts (main_menu.gd) when DEV_SHOT_DIR names a folder:
## DEV_SHOT_FROM seconds after the game starts (default 0), one every
## DEV_SHOT_EVERY seconds (default 1; 0: every frame), DEV_SHOT_COUNT of
## them (default 20), as shot_<number>_<seconds>_<engine ms>.png; then the game quits
## (DEV_SHOT_QUIT=0 keeps it running). DEV_TAPS taps the screen on the way
## ("2.0:360,300;3.5:120,900": at those seconds, at those game pixels; a
## third number holds the press that many seconds: "2.0:360,300:1.5"), to
## open a popup, change tab or hold a card for its info before a shot.

var dir := ""
var from := 0.0
var every := 1.0
var count := 20
var quit := true
var _age := 0.0
var _next := 0.0
var _taken := 0
## Taps still to make: [seconds, position, how long held] each, soonest first.
var _taps: Array = []


static func start_if_asked(on: Node) -> void:
	var where := OS.get_environment("DEV_SHOT_DIR")
	if where == "" or OS.has_feature("web"):
		return
	var shots := DevShots.new()
	shots.dir = where
	shots.from = float(OS.get_environment("DEV_SHOT_FROM")) if OS.get_environment("DEV_SHOT_FROM") != "" else 0.0
	shots.every = float(OS.get_environment("DEV_SHOT_EVERY")) if OS.get_environment("DEV_SHOT_EVERY") != "" else 1.0
	shots.count = int(OS.get_environment("DEV_SHOT_COUNT")) if OS.get_environment("DEV_SHOT_COUNT") != "" else 20
	shots.quit = OS.get_environment("DEV_SHOT_QUIT") != "0"
	shots._next = shots.from
	for tap in OS.get_environment("DEV_TAPS").split(";", false):
		var at := tap.get_slice(":", 1).split(",")
		if at.size() == 2:
			var held := float(tap.get_slice(":", 2)) if tap.get_slice_count(":") > 2 else 0.05
			shots._taps.append([float(tap.get_slice(":", 0)), Vector2(float(at[0]), float(at[1])), held])
	shots._taps.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	DirAccess.make_dir_recursive_absolute(where)
	# On the scene tree's root, so it outlives the screen that started it.
	on.get_tree().root.add_child.call_deferred(shots)


func _process(delta: float) -> void:
	_age += delta
	while not _taps.is_empty() and _age >= float(_taps[0][0]):
		var tap: Array = _taps.pop_front()
		_tap(tap[1], float(tap[2]))
	if _age < _next:
		return
	_next = _age + every
	_taken += 1
	var image := get_viewport().get_texture().get_image()
	# (The engine clock in the name too, to match a TRACK line of the field.)
	image.save_png("%s/shot_%03d_%06.2f_%d.png" % [dir, _taken, _age, Time.get_ticks_msec()])
	if _taken >= count and quit:
		get_tree().quit()


## A tap at `at` (game pixels): a press and, `held` seconds later, a release.
func _tap(at: Vector2, held := 0.05) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = get_viewport().get_final_transform() * at
		event.global_position = event.position
		Input.parse_input_event(event)
		if pressed:
			await get_tree().create_timer(held).timeout
