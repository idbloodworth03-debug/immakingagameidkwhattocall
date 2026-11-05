extends TestCase
## The ban phase before a Draft Duel match (scripts/draft/ban_phase.gd):
## turns from the coin flip, a deck can always be filled afterwards, the
## rival bans by its personality, and in whole matches a banned animal never
## turns up in either player's deck, options or army.


func _animals() -> Array:
	return GameData.card_order.filter(func(id): return not GameData.is_tool(id))


## A shuffled copy of `ids`.
func _shuffled(ids: Array, rng: RandomNumberGenerator) -> Array:
	var out := ids.duplicate()
	for i in out.size():
		var j := rng.randi_range(i, out.size() - 1)
		var swap: Variant = out[i]
		out[i] = out[j]
		out[j] = swap
	return out


func test_bans_unlock_at_eleven_animals() -> void:
	var need := int(GameData.draft_rules.bans.unlock_owned)
	check_eq(need, 11, "eleven animals")
	check(not BanPhase.unlocked(need - 1), "not with ten")
	check(BanPhase.unlocked(need), "with eleven")
	check(need >= int(GameData.draft_rules.deck_size) + int(GameData.draft_rules.bans.per_player), "a deck plus the rival's bans")


func test_turns_alternate_from_the_coin_flip() -> void:
	var owned := _animals().slice(0, 20)
	for first in 2:
		var phase := BanPhase.new(_animals(), owned, first)
		var turns := []
		var spare := _animals().slice(20)
		while not phase.is_done():
			var team := phase.turn()
			turns.append(team)
			check(phase.can_ban(1 - team, spare[0]) != "", "the other side waits")
			check(phase.ban(team, spare.pop_front()), "a ban")
		check_eq(turns, [first, 1 - first, first, 1 - first, first, 1 - first], "P, O, P, O, P, O from whoever won the flip")
		check_eq(phase.bans[0].size(), 3, "you ban 3")
		check_eq(phase.bans[1].size(), 3, "the rival bans 3")
		check_eq(phase.turn(), -1, "then it's done")


func test_you_can_always_fill_a_deck() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var deck_size := int(GameData.draft_rules.deck_size)
	for trial in 200:
		var all := _shuffled(_animals(), rng)
		var owned := all.slice(0, rng.randi_range(11, 16))
		var phase := BanPhase.new(BanPhase.choices_for(owned, rng.randi_range(0, 5)), owned, rng.randi_range(0, 1))
		while not phase.is_done():
			var team := phase.turn()
			# Both sides go after your animals as hard as they can.
			var tries: Array = owned.filter(func(id): return phase.can_ban(team, id) == "")
			if tries.is_empty():
				tries = phase.choices.filter(func(id): return phase.can_ban(team, id) == "")
			check(not tries.is_empty(), "trial %d: always something to ban" % trial)
			if tries.is_empty():
				break
			phase.ban(team, tries[rng.randi_range(0, tries.size() - 1)])
		check(phase.usable().size() >= deck_size, "trial %d: %d of your animals left for a deck of %d" % [trial, phase.usable().size(), deck_size])
	# Exactly eleven: none of your own can go (the rival's three would leave
	# you short), but ones you don't have can.
	var owned := _animals().slice(0, 11)
	var phase := BanPhase.new(_animals(), owned, 0)
	check(phase.can_ban(0, owned[0]) != "", "with eleven, not one of your own")
	check_eq(phase.can_ban(0, _animals()[20]), "", "one you don't have is fine")


func test_the_rival_bans_what_beats_its_favorite() -> void:
	# A rival that loves Tanks bans your Tank Destroyers first.
	var owned := _animals()
	var rng := RandomNumberGenerator.new()
	for seed_value in 10:
		rng.seed = seed_value
		var phase := BanPhase.new(_animals(), owned, 1)
		var id := phase.bot_choice({"favorite": "tank"}, {}, rng, 1.0)
		check_eq(GameData.class_of(id), "tank_destroyer", "seed %d: a Tank lover bans %s" % [seed_value, id])
		phase = BanPhase.new(_animals(), owned, 1)
		id = phase.bot_choice({"favorite": "air"}, {}, rng, 1.0)
		check_eq(GameData.class_of(id), "ranged", "seed %d: an Air lover bans %s" % [seed_value, id])
	# It goes after yours, not ones you don't have.
	var mine := _animals().filter(func(id): return GameData.class_of(id) == "tank_destroyer").slice(0, 2) + _animals().filter(func(id): return GameData.class_of(id) in ["tank", "ranged"])
	check(mine.size() >= 12, "enough of yours to spare one (%d)" % mine.size())
	rng.seed = 3
	var phase := BanPhase.new(_animals(), mine, 1)
	check(mine.has(phase.bot_choice({"favorite": "tank"}, {}, rng, 1.0)), "one of yours")


## Whole matches with a ban phase first: you ban, the rival bans by its
## personality, you fill the gaps in your deck, the rival builds its deck
## without the banned ones, and two computer players play it out. A banned
## animal is never in a deck, never offered, never in an army or on the
## field.
func test_banned_animals_never_appear() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var deck_size := int(GameData.draft_rules.deck_size)
	for match_index in 10:
		var owned := _shuffled(_animals(), rng).slice(0, rng.randi_range(11, 18))
		var arena := rng.randi_range(0, GameData.arenas.size() - 1)
		var style := {"favorite": GameData.class_order[rng.randi_range(0, GameData.class_order.size() - 1)]}
		var phase := BanPhase.new(BanPhase.choices_for(owned, arena), owned, rng.randi_range(0, 1))
		while not phase.is_done():
			if phase.turn() == 0:
				var can: Array = phase.choices.filter(func(id): return phase.can_ban(0, id) == "")
				phase.ban(0, can[rng.randi_range(0, can.size() - 1)])
			else:
				check(phase.ban(1, phase.bot_choice(style, {}, rng, rng.randf())), "the rival bans")
		var banned := phase.banned()
		check_eq(banned.size(), 6, "match %d: six bans" % match_index)
		# Your saved deck with the banned ones taken out, the gaps filled.
		var deck: Array = owned.slice(0, deck_size).filter(func(id): return not banned.has(id))
		for id in owned:
			if deck.size() >= deck_size:
				break
			if not deck.has(id) and not banned.has(id):
				deck.append(id)
		check_eq(deck.size(), deck_size, "match %d: your deck is full" % match_index)
		var theirs := DraftBot.rival_deck(arena, style, rng, 0.6, deck_size, banned)
		check_eq(theirs.size(), deck_size, "match %d: the rival's deck is full" % match_index)
		for team in 2:
			for id in [deck, theirs][team]:
				check(not banned.has(id), "match %d: team %d's deck has banned %s" % [match_index, team, id])
		var m := DraftMatch.new(1300 + match_index, {"pools": [deck + ["net", "air_horn"], theirs + ["net", "medkit"]], "banned": banned})
		var bots := [DraftBot.new(m, 0, match_index * 7 + 1, 0.6), DraftBot.new(m, 1, match_index * 7 + 2, 0.6)]
		var guard := 0
		var bad := []
		while not m.is_over() and guard < 200000:
			guard += 1
			for team in 2:
				for o in m.offers[team]:
					if banned.has(o.id):
						bad.append("offered %s" % o.id)
				for entry in m.herds[team]:
					if banned.has(entry.id):
						bad.append("army %s" % entry.id)
			match m.phase:
				"pick":
					for b in bots:
						b.pick_all()
				"fight":
					if m.fight_tick == 0:
						for f in m.sim.fighters:
							if f.is_unit() and banned.has(f.card.id):
								bad.append("field %s" % f.card.id)
					for b in bots:
						b.update()
					m.step()
				"round_over":
					m.next_round()
		check(m.is_over(), "match %d finished" % match_index)
		check(bad.is_empty(), "match %d: banned %s never seen (saw %s)" % [match_index, banned, bad.slice(0, 3)])
