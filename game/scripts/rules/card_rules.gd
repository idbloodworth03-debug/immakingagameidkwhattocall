class_name CardRules
extends RefCounted
## Card (animal) leveling: how many copies and how much gold an upgrade costs,
## and how stats grow with level.
##
## Every rarity starts at a different level (Common 1, Rare 3, Epic 6,
## Legendary 9) and all cards share the same max level. Tables in
## progression.json are indexed by the level you upgrade TO.


static func is_max_level(level: int, progression: Dictionary) -> bool:
	return level >= int(progression.card_max_level)


## Copies needed to go from `level` to `level + 1` (0 if already maxed).
static func copies_to_upgrade(rarity: String, level: int, progression: Dictionary) -> int:
	if is_max_level(level, progression):
		return 0
	var table: Array = progression.copies_to_level.get(rarity, [])
	return int(table[level + 1]) if level + 1 < table.size() else 0


static func gold_to_upgrade(level: int, progression: Dictionary) -> int:
	if is_max_level(level, progression):
		return 0
	var table: Array = progression.gold_to_level
	return int(table[level + 1]) if level + 1 < table.size() else 0


## Ranger XP earned for upgrading from `level` to `level + 1`.
static func xp_for_upgrade(level: int, progression: Dictionary) -> int:
	if is_max_level(level, progression):
		return 0
	var table: Array = progression.xp_for_upgrade
	return int(table[level + 1]) if level + 1 < table.size() else 0


static func can_upgrade(rarity: String, level: int, copies: int, gold: int, progression: Dictionary) -> bool:
	if is_max_level(level, progression):
		return false
	return copies >= copies_to_upgrade(rarity, level, progression) and gold >= gold_to_upgrade(level, progression)


## Has enough copies to upgrade (gold not checked). Used for the green
## "ready to upgrade" bar on cards.
static func has_copies_for_upgrade(rarity: String, level: int, copies: int, progression: Dictionary) -> bool:
	return not is_max_level(level, progression) and copies >= copies_to_upgrade(rarity, level, progression)


## Stats in animals.json are for the rarity's starting level; each level
## above that adds `growth` (10%) on top.
static func stat_at_level(base_value: float, level: int, start_level: int, growth: float) -> int:
	return roundi(base_value * pow(1.0 + growth, level - start_level))
