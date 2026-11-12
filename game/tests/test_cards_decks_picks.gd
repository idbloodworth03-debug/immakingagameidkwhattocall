extends TestCase
## The three rules that make Draft Duel an army game, checked the way a
## match plays them:
##   Groups: one card puts a whole group of its animal on the field, sized
##     by the animal's build: a bunch of small ones (6), fewer middling
##     ones (4), a few big ones (3), a pair of the biggest (2). Written out
##     here on purpose (not read from classes.json), so a wrong data file
##     fails too.
##   Deck of 8: round 1 offers exactly your 8; later offers come only from
##     your 8 (and your tools, when Ranger tools are on), for you and for
##     the computer.
##   Upgrade or more: from round 2, an animal in your army can get a star
##     (more stars, same animals) or another full group (more animals).

const GROUP := {
	"gray_squirrel": 6, "striped_skunk": 6, "raccoon": 6, "king_cobra": 6, "peregrine_falcon": 6, "barn_owl": 6,
	"hyacinth_macaw": 6, "honey_badger": 6, "red_fox": 6, "red_panda": 6, "sunda_pangolin": 6, "electric_eel": 6,
	"wolf_pack": 4, "wild_boar": 4, "komodo_dragon": 4, "snapping_turtle": 4, "harpy_eagle": 4, "california_condor": 4,
	"harbor_seal": 4, "pygmy_three_toed_sloth": 4,
	"lion": 3, "tiger": 3, "cerberus": 3, "brown_bear": 3, "giant_panda": 3, "sumatran_orangutan": 3,
	"wild_bactrian_camel": 3, "unicorn": 3, "mountain_gorilla": 3,
	"asian_elephant": 2, "black_rhino": 2, "hippopotamus": 2, "yeti": 2, "dragon": 2, "kraken": 2,
}


func _expected(id: String) -> int:
	return int(GROUP.get(id, -1))


func _animals() -> Array:
	return GameData.card_order.filter(func(id): return not GameData.is_tool(id))


func _on_field(m: DraftMatch, team: int, id: String) -> int:
	return m.sim.units(team).filter(func(f): return f.card.id == id).size()


func _slot(m: DraftMatch, team: int, id: String) -> int:
	for i in m.offers[team].size():
		if m.offers[team][i].id == id:
			return i
	return -1


func _finish_fight(m: DraftMatch) -> void:
	var guard := 0
	while m.phase == "fight" and guard < 100000:
		m.step()
		guard += 1


# --- Squads ------------------------------------------------------------------

## Every animal in the game, for the player and for the computer: one card,
## and the field has exactly its group.
func test_every_card_brings_its_whole_group() -> void:
	check_eq(_animals().size(), GROUP.size(), "every animal has a group written out here")
	for id in _animals():
		var m := DraftMatch.new(3)
		m.herds = [[{"id": id, "stars": 1, "squads": 1}], [{"id": id, "stars": 1, "squads": 1}]]
		m._lay_out_herds()
		for team in 2:
			check_eq(_on_field(m, team, id), _expected(id), "%s (%s) for %s" % [id, GameData.class_of(id), ["you", "the computer"][team]])
		# Each one is its own animal, with its own health.
		var squad: Array = m.sim.units(0)
		var uids := {}
		for f in squad:
			uids[f.uid] = true
			check(f.hp > 0 and f.hp == f.max_hp, "%s: each animal has its own full health" % id)
		check_eq(uids.size(), squad.size(), "%s: separate animals" % id)
		# The plain fight (no army) brings the same group.
		var sim := BattleSim.new([{}, {}], 1)
		check_eq(sim.spawn(0, id, 8000, 15000).size(), _expected(id), "%s spawned on its own" % id)


## One card of each class, picked the way a player picks them: each puts
## its whole group on the field.
func test_one_card_of_each_class_through_the_picks() -> void:
	var deck := ["brown_bear", "wild_boar", "gray_squirrel", "peregrine_falcon", "red_fox", "yeti", "lion", "barn_owl"]
	var m := DraftMatch.new(21, {"pools": [deck, deck]})
	for id in ["brown_bear", "wild_boar", "gray_squirrel"]:
		check(m.pick(0, _slot(m, 0, id)), "round 1: %s" % id)
	for id in ["lion", "barn_owl", "red_fox"]:
		m.pick(1, _slot(m, 1, id))
	m.set_ready(0)
	m.set_ready(1)
	check_eq(m.phase, "fight", "fighting")
	check_eq(_on_field(m, 0, "brown_bear"), 3, "a card of Bears: 3")
	check_eq(_on_field(m, 0, "wild_boar"), 4, "a card of Boars: 4")
	check_eq(_on_field(m, 0, "gray_squirrel"), 6, "a card of Squirrels: 6")
	_finish_fight(m)
	m.next_round()
	# Round 2: the other three classes on offer.
	m.offers[0] = [{"id": "peregrine_falcon", "taken": false}, {"id": "red_fox", "taken": false}, {"id": "yeti", "taken": false}]
	for id in ["peregrine_falcon", "red_fox", "yeti"]:
		check(m.pick(0, _slot(m, 0, id)), "round 2: %s" % id)
	m.picks_left[1] = 0
	m.set_ready(0)
	m.set_ready(1)
	check_eq(m.phase, "fight", "fighting again")
	check_eq(_on_field(m, 0, "peregrine_falcon"), 6, "a card of Falcons: 6")
	check_eq(_on_field(m, 0, "red_fox"), 6, "a card of Foxes: 6")
	check_eq(_on_field(m, 0, "yeti"), 2, "a Mythic card of Yetis: 2")
	check_eq(_on_field(m, 0, "gray_squirrel"), 6, "the Squirrels from round 1 still 6")


# --- Deck of 8 ---------------------------------------------------------------

## Whole matches between computer players, each with its own deck of 8:
## nothing outside a deck is ever offered or put on the field.
func test_no_animal_outside_the_deck_ever_appears() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var animals := _animals()
	for match_index in 6:
		var decks := [[], []]
		for team in 2:
			var shuffled := animals.duplicate()
			for i in shuffled.size():
				var j := rng.randi_range(i, shuffled.size() - 1)
				var swap: Variant = shuffled[i]
				shuffled[i] = shuffled[j]
				shuffled[j] = swap
			decks[team] = shuffled.slice(0, 8)
		# (Ranger tools are off for now: a deck is all there is to pick from.)
		var tools := [[], []]
		var m := DraftMatch.new(500 + match_index, {"pools": [decks[0] + tools[0], decks[1] + tools[1]]})
		var bots := [DraftBot.new(m, 0, match_index * 3 + 1, 0.7), DraftBot.new(m, 1, match_index * 3 + 2, 0.4)]
		var guard := 0
		var checked_round := 0
		while not m.is_over() and guard < 200000:
			guard += 1
			if m.phase == "pick" and checked_round != m.round_number:
				checked_round = m.round_number
				for team in 2:
					var offered: Array = m.offers[team].map(func(o): return String(o.id))
					if m.is_first_round():
						check_eq(offered, decks[team], "round 1 offers exactly team %d's 8" % team)
					for id in offered:
						check(decks[team].has(id) or tools[team].has(id), "round %d: %s offered to team %d is in its deck or tools" % [m.round_number, id, team])
			match m.phase:
				"pick":
					for b in bots:
						b.pick_all()
				"fight":
					if m.fight_tick == 0:
						for team in 2:
							for f in m.sim.units(team):
								check(decks[team].has(f.card.id), "%s on the field for team %d is in its deck" % [f.card.id, team])
					for b in bots:
						b.update()
					m.step()
				"round_over":
					m.next_round()
		check(m.is_over(), "match %d finished" % match_index)
		for team in 2:
			for entry in m.herds[team]:
				check(decks[team].has(entry.id), "team %d's army: %s from its deck" % [team, entry.id])


## Whole matches between computer players: from round 2 on, every player is
## offered exactly 4 different animals from their deck (and, with Ranger
## tools on, 2 different tools: they're on for this test), makes 3 picks
## every round, and can still upgrade and add groups.
func test_later_rounds_offer_four_animals_and_two_tools() -> void:
	borrow_tools()
	var rules: Dictionary = GameData.draft_rules.duplicate(true)
	rules.offer_tools = 2
	var animals := _animals()
	var want_animals := int(rules.offer_animals)
	var want_tools := int(rules.offer_tools)
	var kinds := {}
	for match_index in 6:
		var decks := [animals.slice(match_index * 3, match_index * 3 + 8), animals.slice(match_index * 4 + 1, match_index * 4 + 9)]
		var tools := [["net", "air_horn", "medkit"], ["net", "food_bait"]]
		var m := DraftMatch.new(700 + match_index, {"pools": [decks[0] + tools[0], decks[1] + tools[1]]}, rules)
		var bots := [DraftBot.new(m, 0, match_index * 5 + 1, 0.7), DraftBot.new(m, 1, match_index * 5 + 2, 0.4)]
		var guard := 0
		var checked_round := 0
		while not m.is_over() and guard < 200000:
			guard += 1
			if m.phase == "pick" and checked_round != m.round_number:
				checked_round = m.round_number
				for team in 2:
					if m.is_first_round():
						continue
					var offered: Array = m.offers[team].map(func(o): return String(o.id))
					var offered_animals := offered.filter(func(id): return not GameData.is_tool(id))
					var offered_tools := offered.filter(func(id): return GameData.is_tool(id))
					check_eq(offered_animals.size(), want_animals, "round %d, team %d: 4 animals" % [m.round_number, team])
					check_eq(offered_tools.size(), want_tools, "round %d, team %d: 2 tools" % [m.round_number, team])
					check(offered_animals.all(func(id): return decks[team].has(id) and offered.count(id) == 1), "round %d, team %d: different animals from the deck" % [m.round_number, team])
					check(offered_tools.all(func(id): return tools[team].has(id) and offered.count(id) == 1), "round %d, team %d: different tools of its own" % [m.round_number, team])
					check(offered.slice(0, want_animals) == offered_animals, "animals first, then tools (two groups)")
					check_eq(int(m.picks_left[team]), int(rules.picks_per_round), "3 picks")
			match m.phase:
				"pick":
					for b in bots:
						b.pick_all()
					for team in 2:
						for made in m.picks_made[team]:
							kinds[made.kind] = int(kinds.get(made.kind, 0)) + 1
				"fight":
					for b in bots:
						b.update()
					m.step()
				"round_over":
					m.next_round()
		check(m.is_over(), "match %d finished" % match_index)
	for kind in ["animal", "tool", "star", "squad"]:
		check(int(kinds.get(kind, 0)) > 0, "picks include %s (%s)" % [kind, kinds])


## The computer always brings a deck of 8, even in the first arena where
## fewer than 8 animals are unlocked.
func test_rival_decks_have_eight() -> void:
	for arena in GameData.arenas.size():
		var rng := RandomNumberGenerator.new()
		rng.seed = arena
		var deck := DraftBot.rival_deck(arena, {"favorite": "air"}, rng, 0.5, 8)
		check_eq(deck.size(), 8, "arena %d: 8 animals" % (arena + 1))
		var unique := {}
		for id in deck:
			unique[id] = true
			check(not GameData.is_tool(id), "arena %d: animals only" % (arena + 1))
		check_eq(unique.size(), 8, "arena %d: all different" % (arena + 1))


## Your deck is kept and filled in next time (one tap to start).
func test_the_last_deck_is_kept() -> void:
	var profile: Node = load("res://scripts/autoload/profile.gd").new()
	profile.autosave = false
	profile.testing_switches = false
	profile.reset()
	for id in ["lion", "tiger", "king_cobra"]:
		profile.data.collection[id] = {"level": 1, "copies": 0, "new": false}
	var deck: Array = (profile.get_deck() as Array).slice(0, 5) + ["lion", "tiger", "king_cobra"]
	profile.set_deck(deck)
	check_eq(profile.get_deck(), deck, "the same 8 next time")
	profile.free()


# --- Upgrade or Reinforce ----------------------------------------------------

func _second_round(seed_value: int) -> DraftMatch:
	var deck := ["brown_bear", "wild_boar", "gray_squirrel", "peregrine_falcon", "red_fox", "lion", "barn_owl", "raccoon"]
	var m := DraftMatch.new(seed_value, {"pools": [deck, deck]})
	for id in ["brown_bear", "wild_boar", "gray_squirrel"]:
		m.pick(0, _slot(m, 0, id))
	for id in ["lion", "barn_owl", "raccoon"]:
		m.pick(1, _slot(m, 1, id))
	m.set_ready(0)
	m.set_ready(1)
	_finish_fight(m)
	m.next_round()
	return m


## More of an animal you have: another full group of it (12 Squirrels) on
## the field in the next fight.
func test_reinforce_adds_a_full_group() -> void:
	var m := _second_round(31)
	var index := m.herd_index(0, "gray_squirrel")
	check_eq(m.can_reinforce(0, index), "", "a pick can add a group")
	check(m.reinforce(0, index), "reinforced")
	check_eq(int(m.herds[0][index].squads), 2, "two groups")
	check_eq(int(m.herds[0][index].stars), 1, "no star")
	check_eq(m.picks_left[0], int(GameData.draft_rules.picks_per_round) - 1, "it used one pick")
	check_eq(m.picks_made[0][-1].kind, "squad", "the pick slot shows it")
	m.picks_left = [0, 0]
	m.set_ready(0)
	m.set_ready(1)
	check_eq(m.phase, "fight", "fighting")
	check_eq(_on_field(m, 0, "gray_squirrel"), 12, "12 Gray Squirrels on the field")


## Upgrade one: its stars go up and its animals don't.
func test_upgrade_adds_a_star_not_animals() -> void:
	var m := _second_round(32)
	var index := m.herd_index(0, "gray_squirrel")
	check(m.star(0, index), "upgraded")
	check_eq(int(m.herds[0][index].stars), 2, "a star")
	check_eq(int(m.herds[0][index].squads), 1, "still one group")
	m.picks_left = [0, 0]
	m.set_ready(0)
	m.set_ready(1)
	var squirrels: Array = m.sim.units(0).filter(func(f): return f.card.id == "gray_squirrel")
	check_eq(squirrels.size(), 6, "still 6 Gray Squirrels")
	for f in squirrels:
		check_eq(int(f.memory.stars), 2, "each with the star")


## The rules around it: not in round 1, undo takes it back, and a full army
## can't take another group (it can still upgrade).
func test_reinforce_rules() -> void:
	var deck := ["brown_bear", "wild_boar", "gray_squirrel", "peregrine_falcon", "red_fox", "lion", "barn_owl", "raccoon"]
	var first := DraftMatch.new(33, {"pools": [deck, deck]})
	first.pick(0, _slot(first, 0, "gray_squirrel"))
	check(first.can_reinforce(0, 0) != "", "not in round 1 (starters only)")
	var m := _second_round(34)
	var index := m.herd_index(0, "gray_squirrel")
	m.reinforce(0, index)
	check(m.undo(0), "taken back")
	check_eq(int(m.herds[0][index].squads), 1, "one group again")
	m.herds[0][index].squads = 6
	check(m.army_units(0) + 6 > int(GameData.draft_rules.army_max_units), "the army is full (%d animals)" % m.army_units(0))
	check_eq(m.can_reinforce(0, index), "Army full", "no room for 6 more")
	check_eq(m.can_star(0, index), "", "an upgrade still fits")


## The computer chooses between the two as well.
func test_the_computer_upgrades_and_reinforces() -> void:
	var kinds := {}
	for match_index in 4:
		var m := DraftMatch.new(900 + match_index)
		var bots := [DraftBot.new(m, 0, match_index + 1, 0.6), DraftBot.new(m, 1, match_index + 7, 0.6)]
		var guard := 0
		while not m.is_over() and guard < 200000:
			guard += 1
			match m.phase:
				"pick":
					for b in bots:
						b.pick_all()
				"fight":
					for b in bots:
						b.update()
					m.step()
				"round_over":
					m.next_round()
			for e in m.take_events():
				if e.type == "pick":
					kinds[e.kind] = int(kinds.get(e.kind, 0)) + 1
	check(int(kinds.get("star", 0)) > 0, "it upgrades (%d)" % int(kinds.get("star", 0)))
	check(int(kinds.get("squad", 0)) > 0, "it reinforces (%d)" % int(kinds.get("squad", 0)))
