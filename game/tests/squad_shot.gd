extends Control
## Saves a picture of a squad of animals drawn as the home screen draws them
## (scripts/ui/squad_stage.gd: the 3D toys, lined up, facing the camera), on
## a see-through background: what the logo, the app icon and the splash
## screen are made from (tools/make_logo.py).
##
##   godot --path game res://tests/squad_shot.tscn -- out.png 2048 1536 brown_bear,red_fox,gray_squirrel [key=value ...]
##
## (A real screen or xvfb is needed: it draws.) The picture is width x
## height pixels, drawn `scale` times as sharp as in the game (scale=3: its
## outlines as thick, by the animals' size, as on a phone). Other
## key=value pairs replace the squad's numbers (feel.json "menu" "squad":
## pitch, target, camera_distance, width, turn_degrees, hover...).


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 4:
		push_error("squad_shot: out.png width height id,id,... [key=value ...]")
		get_tree().quit(1)
		return
	var out := String(args[0])
	var wide := int(args[1])
	var high := int(args[2])
	var ids: Array = Array(String(args[3]).split(",", false))
	var numbers := {"render_scale": 3.0}
	for i in range(4, args.size()):
		var pair := String(args[i]).split("=")
		if pair.size() == 2:
			numbers[pair[0]] = float(pair[1])
	var stage := SquadStage.make(ids, "forest")
	stage.bare = true
	stage.overrides = numbers
	stage.size = Vector2(wide, high) / float(numbers.render_scale)
	add_child(stage)
	stage.load_now()
	# Each in the same moment of its idle (a picture, not a film), eyes open.
	for actor: Dictionary in stage._actors:
		var m: ModelStage.Model = actor.get("model")
		if m != null and m.player != null and m.player.has_animation("idle"):
			m.player.play("idle")
			m.player.seek(0.0, true)
			m.player.pause()
	stage.set_process(false)
	for frame in 4:
		await RenderingServer.frame_post_draw
	var image := stage._viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var error := image.save_png(out)
	print("squad_shot: %s %dx%d (%d standing)%s" % [out, image.get_width(), image.get_height(), stage.standing(), "" if error == OK else " FAILED"])
	get_tree().quit(0 if error == OK else 1)
