extends TestCase
## Draft Duel rules (scripts/draft/draft_match.gd): best of 7, three picks a
## round, classes taking their rows.

const T := BattleSim.TILE


func _slot(m: DraftMatch, team: int, id: String) -> int:
	for i in m.offers[team].size():
		if m.offers[team][i].id == id:
			return i
	return -1


## A match past round 1, each team starting with these animals.
func _after_starters(seed_value: int, starters_0: Array, starters_1: Array, pool: Array = []) -> DraftMatch:
	var setup := {} if pool.is_empty() else {"pool": pool}
	var m := DraftMatch.new(seed_value, setup)
	for team in 2:
		for id in [starters_0, starters_1][team]:
			m.pick(team, _slot(m, team, id))
		m.set_ready(team)
	_finish_fight(m)
	m.next_round()
	return m


func _finish_fight(m: DraftMatch) -> void:
	var guard := 0
	while m.phase == "fight" and guard < 100000:
		m.step()
		guard += 1


func test_round_one_is_three_starting_animals() -> void:
	var m := DraftMatch.new(1)
	check_eq(m.phase, "pick", "starts with picking")
	check_eq(m.round_number, 1, "round 1")
	check_eq(m.picks_left[0], int(GameData.draft_rules.picks_per_round), "three picks")
	check(m.offers[0].all(func(o): return not GameData.is_tool(o.id)), "round 1 offers animals only")
	check(m.pick(0, _slot(m, 0, "brown_bear")), "pick a bear")
	check_eq(m.can_pick(0, _slot(m, 0, "brown_bear")), "Already picked", "not the same one twice")
	check(m.can_star(0, 0) != "", "no stars in round 1")
	check(not m.set_ready(0), "not ready with picks left")
	m.pick(0, _slot(m, 0, "lion"))
	m.pick(0, _slot(m, 0, "gray_squirrel"))
	check_eq(m.herds[0].size(), 3, "three animals in the herd")
	check(m.set_ready(0), "ready once all three are picked")
	check_eq(m.phase, "pick", "still waiting for the other player")
	for id in ["giant_panda", "wild_boar", "raccoon"]:
		m.pick(1, _slot(m, 1, id))
	m.set_ready(1)
	check_eq(m.phase, "fight", "both ready: fight")


func test_a_deck_is_what_you_pick_from() -> void:
	var deck := ["brown_bear", "snapping_turtle", "wolf_pack", "wild_boar", "gray_squirrel", "striped_skunk", "peregrine_falcon", "red_fox"]
	var theirs := ["giant_panda", "lion", "raccoon", "barn_owl", "harbor_seal", "hippopotamus", "tiger", "king_cobra", "air_horn"]
	var m := DraftMatch.new(12, {"pools": [deck + ["net"], theirs]})
	check_eq(m.offers[0].map(func(o): return o.id), deck, "round 1: your 8 to start with")
	for id in ["brown_bear", "wild_boar", "gray_squirrel"]:
		m.pick(0, _slot(m, 0, id))
	for id in ["giant_panda", "lion", "raccoon"]:
		m.pick(1, _slot(m, 1, id))
	for round_number in 3:
		m.set_ready(0)
		m.set_ready(1)
		_finish_fight(m)
		if m.is_over():
			break
		m.next_round()
		for o in m.offers[0]:
			check(deck.has(o.id) or o.id == "net", "round %d offers %s, from your deck or tools" % [m.round_number, o.id])
		for o in m.offers[1]:
			check(theirs.has(o.id), "theirs from their deck: %s" % o.id)
		m.picks_left = [0, 0]


func test_later_rounds_offer_four_animals_and_two_tools() -> void:
	var m := _after_starters(2, ["brown_bear", "lion", "gray_squirrel"], ["giant_panda", "wild_boar", "raccoon"])
	var offers: Array = m.offers[0]
	var tools := offers.filter(func(o): return GameData.is_tool(o.id)).size()
	check_eq(offers.size() - tools, int(GameData.draft_rules.offer_animals), "four animals")
	check_eq(tools, int(GameData.draft_rules.offer_tools), "two tools")
	var ids := offers.map(func(o): return o.id)
	for id in ids:
		check(ids.count(id) == 1, "%s offered once" % id)


func test_picking_an_owned_animal_adds_a_squad() -> void:
	var pool := ["brown_bear", "lion", "gray_squirrel", "net"]
	var m := _after_starters(3, ["brown_bear", "lion", "gray_squirrel"], ["brown_bear", "lion", "gray_squirrel"], pool)
	var slot := _slot(m, 0, "lion")
	check(slot >= 0, "the lion is offered again")
	check(m.pick(0, slot), "picked")
	var entry: Dictionary = m.herds[0][m.herd_index(0, "lion")]
	check_eq(m.herds[0].size(), 3, "still three kinds of animal")
	check_eq(int(entry.squads), 2, "another squad of lions")
	check_eq(int(entry.stars), 1, "no star")
	var lions: Array = m.sim.units(0).filter(func(f): return f.card.id == "lion")
	check_eq(lions.size(), 2 * DraftMatch.squad_units("lion"), "two squads on the field")
	check_eq(m.picks_made[0][-1].kind, "squad", "the pick says so")


func test_an_upgrade_stars_every_squad() -> void:
	var m := _after_starters(13, ["brown_bear", "lion", "gray_squirrel"], ["giant_panda", "wild_boar", "raccoon"])
	m.herds[0][1].squads = 2
	check(m.star(0, 1), "upgraded")
	m._lay_out_herds()
	var lions: Array = m.sim.units(0).filter(func(f): return f.card.id == "lion")
	check_eq(lions.size(), 2 * DraftMatch.squad_units("lion"), "both squads")
	for f in lions:
		check_eq(int(f.memory.stars), 2, "every lion has the star")


func test_the_army_has_a_size_limit() -> void:
	var m := _after_starters(14, ["brown_bear", "lion", "gray_squirrel"], ["giant_panda", "wild_boar", "raccoon"])
	var cap := int(GameData.draft_rules.army_max_units)
	m.herds[0][2].squads = (cap - m.army_units(0) + DraftMatch.squad_units("gray_squirrel")) / DraftMatch.squad_units("gray_squirrel")
	check(m.army_units(0) <= cap, "at the limit (%d)" % m.army_units(0))
	m.offers[0] = [{"id": "gray_squirrel", "taken": false}, {"id": "net", "taken": false}]
	check_eq(m.can_pick(0, 0), "Army full", "no room for another squad")
	check_eq(m.can_pick(0, 1), "", "a tool still fits")
	check_eq(m.can_star(0, 0), "", "and upgrades too")


func test_stars_from_the_herd_and_the_cap() -> void:
	var m := _after_starters(4, ["brown_bear", "lion", "gray_squirrel"], ["giant_panda", "wild_boar", "raccoon"])
	check(m.star(0, 0), "a star for a herd animal")
	check(m.star(0, 0), "and another")
	check_eq(int(m.herds[0][0].stars), int(GameData.draft_rules.star_max), "up to the cap")
	check_eq(m.can_star(0, 0), "Fully trained", "no further")
	check_eq(m.picks_left[0], 1, "each star used a pick")


func test_undo_takes_a_pick_back() -> void:
	var m := _after_starters(5, ["brown_bear", "lion", "gray_squirrel"], ["giant_panda", "wild_boar", "raccoon"])
	m.star(0, 1)
	check_eq(int(m.herds[0][1].stars), 2, "starred")
	check(m.undo(0), "taken back")
	check_eq(int(m.herds[0][1].stars), 1, "the star is gone")
	check_eq(m.picks_left[0], int(GameData.draft_rules.picks_per_round), "the pick is back")
	check(not m.undo(0), "nothing more to take back")


func test_two_tools_at_most() -> void:
	var pool := ["brown_bear", "lion", "gray_squirrel", "net", "air_horn", "medkit"]
	var m := _after_starters(6, ["brown_bear", "lion", "gray_squirrel"], ["brown_bear", "lion", "gray_squirrel"], pool)
	m.tools[0] = ["net", "air_horn"]
	m.offers[0] = [{"id": "medkit", "taken": false}]
	check(m.needs_tool_swap(0, 0), "a third tool needs a swap")
	check(not m.pick(0, 0), "can't just add it")
	check(m.pick(0, 0, 1), "swap the Air Horn for it")
	check_eq(m.tools[0], ["net", "medkit"], "two tools, the new one in its place")


func test_every_kind_lines_up() -> void:
	var m := DraftMatch.new(7)
	m.herds[0] = []
	for id in ["brown_bear", "lion", "gray_squirrel", "giant_panda", "wild_boar", "raccoon", "wolf_pack", "tiger", "hippopotamus", "black_rhino", "asian_elephant", "snapping_turtle"]:
		m.herds[0].append({"id": id, "stars": 1, "squads": 1})
	m._lay_out_herds()
	check_eq(m.groups[0].size(), 12, "twelve kinds of animal")
	check_eq(m.sim.units(0).size(), m.army_units(0), "every squad on the field")
	for f in m.sim.units(0):
		check(f.y > m.sim.middle and f.y < m.sim.height, "%s stays on its own half" % f.card.id)


func test_classes_take_their_rows() -> void:
	var m := DraftMatch.new(8)
	m.herds[0] = [{"id": "gray_squirrel", "stars": 1}, {"id": "lion", "stars": 1}, {"id": "brown_bear", "stars": 1}]
	m.herds[1] = [{"id": "gray_squirrel", "stars": 1}, {"id": "lion", "stars": 1}, {"id": "brown_bear", "stars": 1}]
	m._lay_out_herds()
	var y := {}
	for f in m.sim.units(0):
		y[f.card.id] = f.y
	check(y.brown_bear < y.lion and y.lion < y.gray_squirrel, "Tank in front, Tank Destroyer in the middle, Ranged at the back")
	for f in m.sim.units(1):
		check(f.y < m.sim.middle, "the other herd lines up on its own half")


## A herd of `count` squads of these ids, in turn.
func _big_herd(count: int, ids: Array) -> Array:
	var herd := []
	for i in count:
		var id: String = ids[i % ids.size()]
		var at := -1
		for j in herd.size():
			if herd[j].id == id:
				at = j
		if at >= 0:
			herd[at].squads += 1
		else:
			herd.append({"id": id, "stars": 1, "squads": 1})
	return herd


func test_small_herds_use_the_smallest_field() -> void:
	# A first round's herds (three squads a side).
	var m := DraftMatch.new(31)
	m.herds = [_big_herd(3, ["brown_bear", "lion", "gray_squirrel"]), _big_herd(3, ["giant_panda", "wild_boar", "raccoon"])]
	m._lay_out_herds()
	check_eq(m.field_scale, 1.0, "no need to grow")
	var smallest := BattleArmy.base_size(GameData.draft_rules.field)
	check_eq(Vector2i(m.sim.width, m.sim.height), smallest, "the smallest field (draft_rules.json \"field\")")
	check_eq(smallest, Vector2i(12, 16) * BattleSim.TILE, "12 tiles wide and 16 long")


func test_big_herds_grow_the_field_up_to_a_limit() -> void:
	var ids := ["brown_bear", "lion", "gray_squirrel", "peregrine_falcon", "electric_eel", "wolf_pack", "hippopotamus", "red_panda", "raccoon", "wild_boar"]
	var top := float(GameData.draft_rules.field.max_scale)
	var last := 1.0
	for count in [10, 20, 30, 60]:
		var m := DraftMatch.new(32)
		m.herds = [_big_herd(count, ids), _big_herd(count, ids)]
		m._lay_out_herds()
		check(m.field_scale >= last, "%d animals: the field doesn't shrink as herds grow (%.2f)" % [count, m.field_scale])
		check(m.field_scale <= top, "%d animals: no bigger than the limit" % count)
		last = m.field_scale
	check(last > 1.0, "the biggest herds get a bigger field")
	check_eq(last, top, "and the biggest of all reach the limit")


func test_big_herds_line_up_without_overlapping() -> void:
	var ids := ["brown_bear", "lion", "gray_squirrel", "peregrine_falcon", "electric_eel", "hippopotamus", "red_panda", "raccoon", "wild_boar", "tiger", "asian_elephant", "snapping_turtle"]
	var m := DraftMatch.new(33)
	m.herds = [_big_herd(24, ids), _big_herd(24, ids)]
	m._lay_out_herds()
	for team in 2:
		var units := m.sim.units(team)
		check_eq(units.size(), m.army_units(team), "team %d: everyone on the field" % team)
		var squeezed := 0
		for i in units.size():
			for j in range(i + 1, units.size()):
				var a: BattleSim.Fighter = units[i]
				var b: BattleSim.Fighter = units[j]
				if a.is_flying() == b.is_flying() and BattleSim.dist(a, b) < a.radius + b.radius:
					squeezed += 1
		check_eq(squeezed, 0, "team %d: nobody stands on top of another" % team)
		for f in units:
			check(m.sim.on_own_half(team, f.y), "team %d: %s on its own half" % [team, f.card.id])
			check(f.x >= 0 and f.x <= m.sim.width, "%s inside the fence" % f.card.id)


func test_rows_stay_in_order_in_big_herds() -> void:
	var m := DraftMatch.new(34)
	var herd := _big_herd(12, ["brown_bear"]) + _big_herd(12, ["lion"]) + _big_herd(6, ["peregrine_falcon"]) + _big_herd(6, ["gray_squirrel"])
	m.herds = [herd, herd.duplicate(true)]
	m._lay_out_herds()
	var deepest := {}
	var nearest := {}
	for f in m.sim.units(0):
		var back: int = f.y - m.sim.middle
		var rank: String = f.memory.rank
		deepest[rank] = maxi(int(deepest.get(rank, -1)), back)
		nearest[rank] = mini(int(nearest.get(rank, 1 << 30)), back)
	check(deepest.wall < nearest.td, "every Tank in front of every Tank Destroyer")
	check(nearest.air > nearest.td, "Air over the Tank Destroyers, behind their first line")
	check(deepest.td < nearest.ranged and deepest.air < nearest.ranged, "Ranged at the back")


func test_tools_work_once_a_fight_and_stay() -> void:
	var m := _after_starters(9, ["brown_bear", "lion", "gray_squirrel"], ["giant_panda", "wild_boar", "raccoon"])
	m.tools[0] = ["net"]
	m.picks_left = [0, 0]
	m.set_ready(0)
	m.set_ready(1)
	check_eq(m.phase, "fight", "fighting")
	check(m.use_tool(0, 0, 8 * T, 5 * T), "used")
	check(not m.use_tool(0, 0, 8 * T, 5 * T), "once a fight")
	check_eq(m.tools[0], ["net"], "still in the belt for next time")


func test_best_of_seven() -> void:
	var m := DraftMatch.new(10)
	check_eq(int(GameData.draft_rules.wins_needed), 4, "first to four")
	m.wins = [3, 2]
	m.herds[0] = [{"id": "black_rhino", "stars": 3}]
	m.herds[1] = []
	m.picks_left = [0, 0]
	m.set_ready(0)
	m.set_ready(1)
	check_eq(m.wins, [4, 2], "an empty herd loses the round at once")
	check(m.is_over(), "four wins: the match is over")
	check_eq(m.match_winner(), 0, "and won")


func test_a_draw_after_seven_rounds() -> void:
	var m := DraftMatch.new(11)
	m.round_number = 7
	m.wins = [3, 3]
	m.herds = [[], []]
	m.picks_left = [0, 0]
	m.set_ready(0)
	m.set_ready(1)
	check(m.is_over(), "seven rounds at most")
	check_eq(m.match_winner(), DraftMatch.NO_WINNER, "level: a draw")


func _bot_match(seed_value: int) -> DraftMatch:
	var m := DraftMatch.new(seed_value)
	var bots := [DraftBot.new(m, 0, seed_value + 1, 0.5), DraftBot.new(m, 1, seed_value + 2, 0.8)]
	var guard := 0
	while not m.is_over() and guard < 400000:
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
	return m


func test_bots_play_whole_matches() -> void:
	for seed_value in [11, 12]:
		var m := _bot_match(seed_value)
		check(m.is_over(), "seed %d: the match finishes" % seed_value)
		check(m.round_number >= int(GameData.draft_rules.wins_needed) and m.round_number <= int(GameData.draft_rules.max_rounds), "seed %d: 4 to 7 rounds (%d)" % [seed_value, m.round_number])
		check(m.herds[0].size() >= 3 and m.herds[1].size() >= 3, "seed %d: both built herds" % seed_value)


func test_same_seed_same_match() -> void:
	var a := _bot_match(21)
	var b := _bot_match(21)
	check_eq(a.sim.checksum(), b.sim.checksum(), "deterministic")
	check_eq(a.wins, b.wins, "same score")
