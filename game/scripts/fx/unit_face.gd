class_name UnitFace
extends Node2D
## Cartoon faces drawn over an animal's rendered eyes: a blink, a squint on
## the wind-up, wide eyes when hit, swirly dizzy eyes when stunned or
## knocked out, drowsy lids when slowed, happy ^ ^ eyes when celebrating
## and a smug look after a knockout. Where the eyes are in each frame comes
## from the animal's sprite sheet (UnitSprites.eyes). It lives inside the
## view's Body, so it squashes, leans and flips with the picture, and it is
## only drawn while a face is showing.

const INK := Color("#1a0f08")

## "", "blink", "squint", "wide", "dizzy", "drowsy", "happy" or "smug".
var mode := ""
## Each eye in sheet pixels from the anchor, or null when turned away.
var eyes: Array = []
## An eye's radius in sheet pixels, and screen pixels per sheet pixel.
var radius := 4.0
var k := 1.0
var flip := false
## The skin around the eyes, for eyelids.
var lid := Color("#7a5a3a")
## The dizzy swirl's turn, in radians.
var spin := 0.0


func _draw() -> void:
	if mode == "" or eyes.is_empty():
		return
	if flip:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	var r := radius * k
	var line := maxf(1.3, r * 0.34)
	var shown: Array[Vector2] = []
	for e: Variant in eyes:
		if e is Vector2:
			shown.append(e * k)
	var mid := Vector2.ZERO
	for p in shown:
		mid += p
	if not shown.is_empty():
		mid /= shown.size()
	for p in shown:
		# Which way the nose is, for slanting a brow toward it.
		var inward := signf(mid.x - p.x) if shown.size() > 1 and absf(mid.x - p.x) > 0.5 else 1.0
		match mode:
			"blink":
				draw_circle(p, r * 1.12, lid)
				draw_arc(p + Vector2(0, -r * 0.15), r * 0.8, PI * 0.15, PI * 0.85, 10, INK, line, true)
			"happy":
				draw_circle(p, r * 1.12, lid)
				draw_arc(p + Vector2(0, r * 0.35), r * 0.8, PI * 1.15, PI * 1.85, 10, INK, line, true)
			"squint":
				_lid(p, r, 0.48, line)
				# A determined brow, low toward the nose.
				draw_line(p + Vector2(-inward * r * 1.1, -r * 0.55), p + Vector2(inward * r * 1.0, -r * 0.05), INK, line, true)
			"drowsy":
				_lid(p, r, 0.62, line)
			"smug":
				_lid(p, r, 0.5, line)
			"wide":
				draw_circle(p, r * 1.32, INK)
				draw_circle(p, r * 1.18, Color.WHITE)
				draw_circle(p, r * 0.34, INK)
			"dizzy":
				draw_circle(p, r * 1.2, INK)
				draw_circle(p, r * 1.06, Color.WHITE)
				var swirl := PackedVector2Array()
				for i in 14:
					var u := float(i) / 13.0
					var ang := spin * inward + u * TAU * 1.6
					swirl.append(p + Vector2(cos(ang), sin(ang)) * r * 0.9 * u)
				draw_polyline(swirl, INK, maxf(1.1, line * 0.7), true)


## An eyelid over the top `amount` of the eye (0-1), with its dark edge.
func _lid(p: Vector2, r: float, amount: float, line: float) -> void:
	var rr := r * 1.12
	var cut := -rr + 2.0 * rr * amount
	var half := sqrt(maxf(0.0, rr * rr - cut * cut))
	# From the left end of the edge, over the top, to the right end.
	var a0 := atan2(cut, -half)
	var a1 := atan2(cut, half)
	if a1 < a0:
		a1 += TAU
	var points := PackedVector2Array()
	for i in 13:
		var ang := lerpf(a0, a1, float(i) / 12.0)
		points.append(p + Vector2(cos(ang), sin(ang)) * rr)
	draw_colored_polygon(points, lid)
	draw_line(p + Vector2(-half, cut), p + Vector2(half, cut), INK, line, true)
