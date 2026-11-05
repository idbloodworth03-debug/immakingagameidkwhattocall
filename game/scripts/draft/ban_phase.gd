class_name BanPhase
extends RefCounted
## The ban phase before a Draft Duel match (once you own enough animals):
## you (team 0) and the rival (team 1) take turns banning animals, starting
## with whoever won the coin flip, until each has banned per_player. Nobody
## can use a banned animal that match: not in a deck, not offered, not in
## an army. Numbers: draft_rules.json "bans".
##
## You can always fill a deck afterwards: the phase only starts once you own
## unlock_owned animals (a deck plus the rival's bans), and a ban of one of
## your own animals is refused if it could leave you short once the rival's
## remaining bans are in.

var per_player := 3
var deck_size := 8
## Who bans first (the coin flip): 0 you, 1 the rival.
var first := 0
## Each side's bans, in order.
var bans := [[], []]
## The animals that can be banned (the cards on the screen).
var choices: Array = []
## Your animals (your deck comes from these).
var owned: Array = []


func _init(choice_ids: Array, player_owned: Array, first_team: int) -> void:
	var r: Dictionary = GameData.draft_rules.get("bans", {})
	per_player = int(r.get("per_player", 3))
	deck_size = int(GameData.draft_rules.get("deck_size", 8))
	choices = choice_ids.duplicate()
	owned = player_owned.filter(func(id): return not GameData.is_tool(id))
	first = first_team


## Whether a player with `owned_animals` animals gets a ban phase.
static func unlocked(owned_animals: int) -> bool:
	return owned_animals >= int(GameData.draft_rules.get("bans", {}).get("unlock_owned", 11))


## The cards on the ban screen: your animals and every animal the rival
## could bring (unlocked up to its arena, or a starting card), in the order
## they line up in battle (by class), rarest first.
static func choices_for(player_owned: Array, rival_arena: int) -> Array:
	var ids := {}
	for id in player_owned:
		if not GameData.is_tool(id):
			ids[id] = true
	for id in GameData.card_order:
		if not GameData.is_tool(id) and int(GameData.cards[id].unlock_arena_index) <= rival_arena:
			ids[id] = true
	for id in GameData.progression.get("starting_cards", []):
		if not GameData.is_tool(id):
			ids[id] = true
	var out: Array = GameData.card_order.filter(func(id): return ids.has(id))
	out.sort_custom(func(a: String, b: String) -> bool:
		var ca := GameData.class_order.find(GameData.class_of(a))
		var cb := GameData.class_order.find(GameData.class_of(b))
		if ca != cb:
			return ca < cb
		var ra := GameData.rarity_order.find(GameData.cards[a].rarity)
		var rb := GameData.rarity_order.find(GameData.cards[b].rarity)
		if ra != rb:
			return ra > rb
		return String(GameData.cards[a].name) < String(GameData.cards[b].name))
	return out


func banned() -> Array:
	return bans[0] + bans[1]


func is_done() -> bool:
	return bans[0].size() + bans[1].size() >= 2 * per_player


## Whose turn it is (0 you, 1 the rival), or -1 once the bans are done.
func turn() -> int:
	if is_done():
		return -1
	return (first + bans[0].size() + bans[1].size()) % 2


## How many bans `team` has left.
func remaining(team: int) -> int:
	return per_player - bans[team].size()


## Your animals nobody has banned.
func usable() -> Array:
	var gone := banned()
	return owned.filter(func(id): return not gone.has(id))


## Why `team` can't ban `id` now ("" if it can).
func can_ban(team: int, id: String) -> String:
	if is_done():
		return "Bans are done"
	if team != turn():
		return "Not your turn"
	if not choices.has(id):
		return "Not in the match"
	if banned().has(id):
		return "Already banned"
	if owned.has(id):
		# Your animals left must still make a deck once every ban still to
		# come (the rival's, and this one) is in.
		var rival_left := remaining(1) - (1 if team == 1 else 0)
		if usable().size() - 1 < deck_size + rival_left:
			return "You need %d for your deck" % deck_size
	return ""


func ban(team: int, id: String) -> bool:
	if can_ban(team, id) != "":
		return false
	bans[team].append(id)
	return true


## The rival's ban: one of your animals that beats its favorite class
## (draft_rules.json "bans" "threats"), your best-leveled and strongest
## first, never gladly one of its favorite class, with some luck (more for
## a weaker rival). `levels`: your card levels.
func bot_choice(style: Dictionary, levels: Dictionary, rng: RandomNumberGenerator, difficulty := 0.5) -> String:
	var r: Dictionary = GameData.draft_rules.get("bans", {})
	var favorite := String(style.get("favorite", ""))
	var threats: Array = r.get("threats", {}).get(favorite, [])
	var luck := lerpf(float(r.get("luck_easy", 4.0)), float(r.get("luck_hard", 1.0)), clampf(difficulty, 0.0, 1.0))
	var best := ""
	var best_score := -INF
	for id in choices:
		if can_ban(1, id) != "":
			continue
		var card := GameData.get_card(id)
		var cls := GameData.class_of(id)
		var score := float(card.get("cost", 4)) * float(r.get("power", 0.4))
		if threats.has(cls):
			score += float(r.get("threat", 5.0))
		if owned.has(id):
			var above := int(levels.get(id, GameData.start_level(card.rarity))) - GameData.start_level(card.rarity)
			score += float(r.get("owned", 3.0)) + maxf(0.0, above) * float(r.get("level", 0.5))
		if cls == favorite:
			score += float(r.get("favorite", -6.0))
		score += rng.randf() * luck
		if score > best_score:
			best_score = score
			best = id
	return best
