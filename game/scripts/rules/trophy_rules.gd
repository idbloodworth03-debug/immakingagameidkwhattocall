class_name TrophyRules
extends RefCounted
## Trophy math. These are plain functions with no saved state, so the game
## server can use exactly the same rules later.


## How many trophies a match is worth (negative for a loss).
## Beating someone with more trophies than you gives more; losing to someone
## with fewer trophies costs more.
static func change_for_match(my_trophies: int, opponent_trophies: int, won: bool, settings: Dictionary) -> int:
	var base := int(settings.get("base", 30))
	var lowest := int(settings.get("min_change", 20))
	var highest := int(settings.get("max_change", 40))
	var divisor := maxf(1.0, float(settings.get("difference_divisor", 25)))
	var swing := roundi((opponent_trophies - my_trophies) / divisor)
	if won:
		return clampi(base + swing, lowest, highest)
	return -clampi(base - swing, lowest, highest)


## Which arena (0 = first) a trophy count belongs to.
static func arena_index_for(trophies: int, arenas: Array) -> int:
	var index := 0
	for i in arenas.size():
		if trophies >= int(arenas[i].min_trophies):
			index = i
	return index


## Trophies after a match. You never drop below zero, and arenas with
## "trophy_floor" stop you from falling back into the arena before them.
static func trophies_after_match(trophies: int, opponent_trophies: int, won: bool, settings: Dictionary, arenas: Array) -> int:
	var result := maxi(0, trophies + change_for_match(trophies, opponent_trophies, won, settings))
	if not won:
		var arena: Dictionary = arenas[arena_index_for(trophies, arenas)]
		if arena.get("trophy_floor", false):
			result = maxi(result, int(arena.min_trophies))
	return result
