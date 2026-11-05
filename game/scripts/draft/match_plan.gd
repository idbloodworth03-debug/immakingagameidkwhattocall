class_name MatchPlan
extends RefCounted
## What's settled before a Draft Duel match starts, carried from screen to
## screen: the rival (chosen on the ban screen) and the animals banned for
## this match. The ban screen fills it in, the deck screen leaves banned
## animals out, and the match reads it as it starts (then it's cleared).

## The rival you'll face ({} : the match picks one itself).
static var opponent: Dictionary = {}
## Animals nobody can use this match.
static var banned: Array = []


static func clear() -> void:
	opponent = {}
	banned = []
