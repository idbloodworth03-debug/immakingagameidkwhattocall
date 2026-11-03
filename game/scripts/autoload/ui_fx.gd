extends CanvasLayer
## UI effects over every screen: little sparkles when you tap, dust puffs,
## and a layer for things flying across the screen (a bought card flying
## into your herd). Above the screens, under the color grade.

var particles: ParticleLayer
## Things flying across the screen go here (screen coordinates).
var air: Control


func _ready() -> void:
	layer = 60
	air = Control.new()
	air.mouse_filter = Control.MOUSE_FILTER_IGNORE
	air.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(air)
	particles = ParticleLayer.new()
	add_child(particles)


## A tiny sparkle where a button was tapped (feel.json "ui": tap_sparkles).
func tap(at: Vector2) -> void:
	var count := Feel.count("ui", "tap_sparkles", 4)
	if count > 0:
		particles.burst("sparkle", at, count, 150.0, 0.4, 6.0, [Color.WHITE, Color("#fff3a8")], -40.0, 4.0)


## A puff of dust, like something landing (feel.json "ui": land_puffs).
func dust(at: Vector2, width: float) -> void:
	var count := Feel.count("ui", "land_puffs", 7)
	for i in count:
		var x := randf_range(-width / 2.0, width / 2.0)
		var v := Vector2(x * 2.2, randf_range(-60.0, -20.0))
		particles.particle("dust", at + Vector2(x, 0), v, randf_range(0.35, 0.55), randf_range(7.0, 11.0), Color("#f3e2c4", 0.9), -20.0, 4.0)


## A star burst and sparkles (a star added, a reward).
func stars(at: Vector2, count := 8) -> void:
	particles.burst("star", at, count, 230.0, 0.7, 9.0, [Color("#ffe14d"), Color("#ffb03b"), Color.WHITE], 520.0, 1.2, 160.0)
	particles.burst("sparkle", at, count, 170.0, 0.6, 8.0, [Color.WHITE, Color("#fff3a8")], -60.0, 2.5)
