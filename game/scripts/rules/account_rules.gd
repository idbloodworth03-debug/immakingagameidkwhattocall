class_name AccountRules
extends RefCounted
## Ranger Level (the account level). XP comes from upgrading animals and from
## battles. The XP total never resets; the level is worked out from it.


## Returns { level, xp, xp_needed } where `xp` is progress inside the current
## level and `xp_needed` is how much that level takes (0 at max level).
static func level_info(total_xp: int, xp_table: Array, max_level: int) -> Dictionary:
	var level := 1
	var remaining := total_xp
	while level < max_level and level < xp_table.size():
		var needed := int(xp_table[level])
		if remaining < needed:
			return {"level": level, "xp": remaining, "xp_needed": needed}
		remaining -= needed
		level += 1
	return {"level": level, "xp": remaining, "xp_needed": 0}
