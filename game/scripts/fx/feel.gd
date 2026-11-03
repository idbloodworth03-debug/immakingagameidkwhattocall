class_name Feel
extends RefCounted
## Reads the look-and-feel settings in data/feel.json (animation, hit
## effects, particles, UI motion, backgrounds). Missing values fall back to
## the default given, so an older or trimmed file still works.


## (These run many times a frame in a big fight, so they don't build a
## fallback dictionary on every call.)
static func _value(section: String, key: String) -> Variant:
	var part: Variant = GameData.feel.get(section)
	return (part as Dictionary).get(key) if part is Dictionary else null


static func num(section: String, key: String, fallback := 0.0) -> float:
	var value: Variant = _value(section, key)
	return fallback if value == null else float(value)


static func count(section: String, key: String, fallback := 0) -> int:
	var value: Variant = _value(section, key)
	return fallback if value == null else int(value)


static func on(section: String, key: String, fallback := true) -> bool:
	var value: Variant = _value(section, key)
	return fallback if value == null else bool(value)


static func color(section: String, key: String, fallback := Color.WHITE) -> Color:
	var value: Variant = _value(section, key)
	return Color(String(value)) if value is String else fallback
