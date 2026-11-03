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
	for id in ["polar_bear", "cheetah", "raccoon"]:
		m.pick(1, _slot(m, 1, id))
	m.set_ready(1)
	check_eq(m.phase, "fight", "both ready: fight")


func test_later_rounds_offer_five_animals_and_tools() -> void:
	var m := _after_starters(2, ["brown_bear", "lion", "gray_squirrel"], ["polar_bear", "cheetah", "raccoon"])
	var offers: Array = m.offers[0]
	var tools := offers.filter(func(o): return GameData.is_tool(o.id)).size()
	check_eq(offers.size(), int(GameData.draft_rules.offer_count), "five options")
	check(tools >= int(GameData.draft_rules.offer_tools_min) and tools <= int(GameData.draft_rules.offer_tools_max), "a few tools among them (%d)" % tools)
	var ids := offers.map(func(o): return o.id)
	for id in ids:
		check(ids.count(id) == 1, "%s offered once" % id)


func test_picking_an_owned_animal_adds_a_star() -> void:
	var pool := ["brown_bear", "lion", "gray_squirrel", "net"]
	var m := _after_starters(3, ["brown_bear", "lion", "gray_squirrel"], ["brown_bear", "lion", "gray_squirrel"], pool)
	var slot := _slot(m, 0, "brown_bear")
	check(slot >= 0, "the bear is offered again")
	check(m.pick(0, slot), "picked")
	check_eq(m.herds[0].size(), 3, "no copy added")
	check_eq(int(m.herds[0][m.herd_index(0, "brown_bear")].stars), 2, "a star instead")


func test_stars_from_the_herd_and_the_cap() -> void:
	var m := _after_starters(4, ["brown_bear", "lion", "gray_squirrel"], ["polar_bear", "cheetah", "raccoon"])
	check(m.star(0, 0), "a star for a herd animal")
	check(m.star(0, 0), "and another")
	check_eq(int(m.herds[0][0].stars), int(GameData.draft_rules.star_max), "up to the cap")
	check_eq(m.can_star(0, 0), "Fully trained", "no further")
	check_eq(m.picks_left[0], 1, "each star used a pick")


func test_undo_takes_a_pick_back() -> void:
	var m := _after_starters(5, ["brown_bear", "lion", "gray_squirrel"], ["polar_bear", "cheetah", "raccoon"])
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


func test_no_limit_on_the_herd() -> void:
	var m := DraftMatch.new(7)
	m.herds[0] = []
	for id in ["brown_bear", "lion", "gray_squirrel", "polar_bear", "cheetah", "raccoon", "wolf_pack", "tiger", "hippopotamus", "black_rhino", "asian_elephant", "american_bison"]:
		m.herds[0].append({"id": id, "stars": 1})
	m._lay_out_herds()
	check_eq(m.groups[0].size(), 12, "twelve animals on the field")
	for f in m.sim.units(0):
		check(f.y > BattleSim.MIDDLE and f.y < BattleSim.HEIGHT, "%s stays on its own half" % f.card.id)


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
		check(f.y < BattleSim.MIDDLE, "the other herd lines up on its own half")


func test_tools_work_once_a_fight_and_stay() -> void:
	var m := _after_starters(9, ["brown_bear", "lion", "gray_squirrel"], ["polar_bear", "cheetah", "raccoon"])
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
