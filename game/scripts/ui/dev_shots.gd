class_name DevShots
extends Node
## For testing on a computer: saves screenshots of the game as it runs, so a
## script can check a fight frame by frame. Started by the main menu with
## the dev shortcuts (main_menu.gd) when DEV_SHOT_DIR names a folder:
## DEV_SHOT_FROM seconds after the game starts (default 0), one every
## DEV_SHOT_EVERY seconds (default 1; 0: every frame), DEV_SHOT_COUNT of
## them (default 20), as shot_<number>_<seconds>.png; then the game quits
## (DEV_SHOT_QUIT=0 keeps it running).

var dir := ""
var from := 0.0
var every := 1.0
var count := 20
var quit := true
var _age := 0.0
var _next := 0.0
var _taken := 0


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
	DirAccess.make_dir_recursive_absolute(where)
	# On the scene tree's root, so it outlives the screen that started it.
	on.get_tree().root.add_child.call_deferred(shots)


func _process(delta: float) -> void:
	_age += delta
	if _age < _next:
		return
	_next = _age + every
	_taken += 1
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/shot_%03d_%06.2f.png" % [dir, _taken, _age])
	if _taken >= count and quit:
		get_tree().quit()
