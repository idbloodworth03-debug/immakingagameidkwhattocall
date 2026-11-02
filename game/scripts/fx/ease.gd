class_name Ease
extends RefCounted
## Easing curves for hand-made animation: each takes t from 0 to 1 and
## returns the eased value (out_back and out_elastic overshoot past 1).


static func out_cubic(t: float) -> float:
	var u := 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - u * u * u


static func in_cubic(t: float) -> float:
	var u := clampf(t, 0.0, 1.0)
	return u * u * u


static func in_out_sine(t: float) -> float:
	return 0.5 - 0.5 * cos(PI * clampf(t, 0.0, 1.0))


## Overshoots a little, then settles.
static func out_back(t: float, overshoot := 1.70158) -> float:
	var u := clampf(t, 0.0, 1.0) - 1.0
	return 1.0 + (overshoot + 1.0) * u * u * u + overshoot * u * u


## A springy wobble that settles at 1.
static func out_elastic(t: float) -> float:
	var u := clampf(t, 0.0, 1.0)
	if u <= 0.0 or u >= 1.0:
		return u
	return pow(2.0, -10.0 * u) * sin((u * 10.0 - 0.75) * TAU / 3.0) + 1.0


## Up and back down: 0 at the ends, 1 in the middle.
static func arc(t: float) -> float:
	var u := clampf(t, 0.0, 1.0)
	return 4.0 * u * (1.0 - u)
