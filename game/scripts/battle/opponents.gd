class_name Opponents
extends RefCounted
## Rival Rangers (data/rivals.json): who you face in Draft Duel.
##
## Each arena has a few regular rivals and one boss. When a win could take
## you to the next arena, you face that arena's boss: the final challenge
## before promotion. In the top arena the boss turns up once you are
## `top_arena_boss_after` trophies in, and after you beat it, it joins the
## regulars for rematches.
##
## A rival's difficulty (0 to 1, see DraftBot) comes from the arena, its own
## skill, and boss_skill for a boss. After `ease_after_losses` losses in a
## row, the next rival is quietly a little easier: lower difficulty and
## slightly lower card levels. The game never mentions it.


## Whether a match at `trophies` is a boss match.
static func is_boss_match(trophies: int, beaten: Array) -> bool:
	var rules := GameData.rival_rules
	var index := GameData.arena_index_for_trophies(trophies)
	if index + 1 < GameData.arenas.size():
		var next_at := int(GameData.arenas[index + 1].min_trophies)
		return trophies + int(rules.get("boss_within_trophies", 40)) >= next_at
	var arena: Dictionary = GameData.arenas[index]
	return not beaten.has(arena.id) and trophies >= int(arena.min_trophies) + int(rules.get("top_arena_boss_after", 300))


## Whether the next opponent should be eased, after a run of losses.
static func is_eased(loss_streak: int) -> bool:
	var after := int(GameData.rival_rules.get("ease_after_losses", 3))
	return after > 0 and loss_streak >= after


## The rival's difficulty for DraftBot: 0 (easiest) to 1.
static func difficulty_for(rival: Dictionary, arena_index: int, eased: bool) -> float:
	var rules := GameData.rival_rules
	var value := float(arena_index) / maxf(1.0, GameData.arenas.size() - 1)
	value += float(rival.get("skill", 0.0))
	if rival.get("boss", false):
		value += float(rules.get("boss_skill", 0.15))
	if eased:
		value -= float(rules.get("ease_amount", 0.15))
	return clampf(value, 0.0, 1.0)


## Picks the next rival for a player with `trophies`, `loss_streak` losses
## in a row and bosses `beaten` (arena ids). Returns everything the match
## needs: the rival's data (id, name, line, banner, look, style, emotes,
## boss...) plus "arena_index", "difficulty", "eased", "trophies" and "level".
static func pick(rng: RandomNumberGenerator, trophies: int, loss_streak: int, beaten: Array, ranger_level: int) -> Dictionary:
	var index := GameData.arena_index_for_trophies(trophies)
	var boss := is_boss_match(trophies, beaten)
	var choices: Array = GameData.rivals_in_arena(index, boss)
	var top := index == GameData.arenas.size() - 1
	if not boss and top and beaten.has(GameData.arenas[index].id):
		choices += GameData.rivals_in_arena(index, true)  # rematches
	var rival: Dictionary = choices[rng.randi_range(0, choices.size() - 1)].duplicate(true)
	var eased := is_eased(loss_streak)
	rival["boss"] = bool(rival.get("boss", false))
	rival["arena_index"] = index
	rival["eased"] = eased
	rival["difficulty"] = difficulty_for(rival, index, eased)
	# A boss holds the gate: it has the next arena's trophies, so beating it
	# is worth a little more.
	var their_trophies := maxi(0, trophies + rng.randi_range(-40, 40))
	if rival.boss and index + 1 < GameData.arenas.size():
		their_trophies = maxi(trophies, int(GameData.arenas[index + 1].min_trophies))
	rival["trophies"] = their_trophies
	rival["level"] = maxi(1, ranger_level + (1 if rival.boss else rng.randi_range(-1, 1)))
	return rival


## The next rival for the player, from their profile.
static func next_for_player(rng: RandomNumberGenerator) -> Dictionary:
	return pick(rng, Profile.get_trophies(), Profile.loss_streak(), Profile.bosses_beaten(), int(Profile.ranger_info().level))


## How many card levels an eased rival's cards drop.
static func level_drop(rival: Dictionary) -> int:
	return int(GameData.rival_rules.get("ease_card_levels", 1)) if rival.get("eased", false) else 0
