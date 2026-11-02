class_name Feel
extends RefCounted
## Reads the look-and-feel settings in data/feel.json (animation, hit
## effects, particles, UI motion, backgrounds). Missing values fall back to
## the default given, so an older or trimmed file still works.


static func num(section: String, key: String, fallback := 0.0) -> float:
	return float(GameData.feel.get(section, {}).get(key, fallback))


static func count(section: String, key: String, fallback := 0) -> int:
	return int(GameData.feel.get(section, {}).get(key, fallback))


static func on(section: String, key: String, fallback := true) -> bool:
	return bool(GameData.feel.get(section, {}).get(key, fallback))


static func color(section: String, key: String, fallback := Color.WHITE) -> Color:
	var value: Variant = GameData.feel.get(section, {}).get(key, null)
	return Color(String(value)) if value is String else fallback
