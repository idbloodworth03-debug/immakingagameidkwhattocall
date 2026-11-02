extends TestCase
## Draft Duel tests: starters, shopping and stars, placing, the Pot and
## halftime betting, rounds and hearts, the Bookie's odds and the computer
## opponent.

const T := BattleSim.TILE


## A match past the starters (none unless given), shopping in round 1.
func _new_match(seed_value: int, starters_0: Array = [], starters_1: Array = []) -> DraftMatch:
	var m := DraftMatch.new(seed_value)
	m.pick_starters(0, starters_0)
	m.pick_starters(1, starters_1)
	return m


## Ends the shopping with nobody buying anything.
func _skip_draft(m: DraftMatch) -> void:
	m.finish_shopping(0)
	m.finish_shopping(1)


## Skips to placing and gives each team the herd listed, at its default spots.
func _with_herds(herd_0: Array, herd_1: Array, seed_value := 3) -> DraftMatch:
	var m := _new_match(seed_value)
	_skip_draft(m)
	for team in 2:
		for id in [herd_0, herd_1][team]:
			var spot := m.default_spot(team)
			m.herds[team].append({"id": id, "x": spot.x, "y": spot.y, "stars": 1})
	m._lay_out_herds()
	return m


## Both players ready, even odds, no bets: the fight starts.
func _start(m: DraftMatch) -> void:
	m.set_ready(0)
	m.set_ready(1)
	m.post_line(0.5)
	m.wager(0, 0)
	m.wager(1, 0)


## Runs the fight to the end of the round, checking at halftime.
func _fight(m: DraftMatch) -> void:
	_start(m)
	while m.phase == "fight" or m.phase == "halftime":
		if m.phase == "halftime":
			m.check(int(m.halftime.turn))
		else:
			m.step()


func test_a_match_starts_with_starters() -> void:
	var m := DraftMatch.new(1)
	var rules := GameData.draft_rules
	check_eq(m.phase, "starters", "starters first")
	check_eq(m.round_number, 0, "before round 1")
	check_eq(m.acorns, [int(rules.acorns_start), int(rules.acorns_start)], "same Acorns for both")
	check_eq(m.hearts, [int(rules.hearts), int(rules.hearts)], "same hearts for both")
	check(m.pick_starters(0, ["red_fox", "raccoon"]), "the player picks")
	check_eq(m.phase, "starters", "waiting for the opponent")
	check(not m.pick_starters(0, ["cheetah"]), "only once")
	check(m.pick_starters(1, ["sewer_rats", "cheetah", "gray_squirrel"]), "the opponent picks")
	check_eq(m.phase, "draft", "then round 1's shopping")
	check_eq(m.round_number, 1, "round 1")
	check_eq(m.herds[0].map(func(e): return e.id), ["red_fox", "raccoon"], "starters are in the herd")
	check(m.herds[1].all(func(e): return int(e.stars) == 1), "with one star each")
	check_eq(m.sim.units(1).size(), 1 + 1 + int(GameData.get_card("sewer_rats").count), "and on the field")
	for team in 2:
		var shop: Array = m.shops[team]
		check_eq(shop.size(), int(rules.market_animals) + int(rules.market_tools) + int(rules.mystery_crates), "a full shop")
		check_eq(shop.filter(func(item): return item.mystery).size(), int(rules.mystery_crates), "a Mystery Crate")
		check_eq(shop.filter(func(item): return GameData.is_tool(item.id) and not item.mystery).size(), int(rules.market_tools), "a tool")


func test_starter_rules() -> void:
	var m := DraftMatch.new(1, {"pool": ["red_fox", "raccoon", "cheetah", "brown_bear", "lion", "sewer_rats", "net"]})
	var budget := int(GameData.draft_rules.starter_budget)
	check_eq(m.starter_problem(["red_fox", "raccoon", "cheetah"]), "", "three within the budget")
	check(m.starter_problem(["red_fox", "raccoon", "cheetah", "sewer_rats"]) != "", "no more than three")
	check(m.starter_problem(["red_fox", "red_fox"]) != "", "no doubles")
	check(m.starter_problem(["tiger"]) != "", "only animals you own")
	check(m.starter_problem(["net"]) != "", "no tools")
	check(int(GameData.get_card("brown_bear").cost) + int(GameData.get_card("lion").cost) + int(GameData.get_card("cheetah").cost) > budget, "(these three are over budget)")
	check(m.starter_problem(["brown_bear", "lion", "cheetah"]).begins_with("Over budget"), "the budget counts")


func test_each_player_has_their_own_shop() -> void:
	var m := _new_match(2)
	var slot := -1
	for i in m.shops[0].size():
		if m.can_buy(0, i) == "":
			slot = i
			break
	check(slot >= 0, "something affordable")
	check(m.can_buy(1, 0) == "" or m.can_buy(1, 0) == "Not enough Acorns", "the opponent can shop at the same time")
	var before: int = m.acorns[0]
	check(m.buy(0, slot), "buy")
	check_eq(m.acorns[0], before - int(m.shops[0][slot].cost), "pays the price")
	check_eq(m.herds[0].size() + m.tools[0].size(), 1, "the card joins the herd or tool belt")
	check(m.can_buy(0, slot) != "", "a bought card can't be bought again")
	check_eq(m.phase, "draft", "still shopping")
	var other: Array = m.shops[1].duplicate(true)
	before = m.acorns[0]
	check(m.reroll(0), "reroll")
	check_eq(m.acorns[0], before - int(GameData.draft_rules.reroll_cost), "a reroll costs an Acorn")
	check(m.shops[0].all(func(item): return int(item.taken) < 0), "a fresh shop")
	check_eq(m.shops[1], other, "the other player's shop doesn't change")
	check(m.finish_shopping(0), "done")
	check(m.can_buy(0, 0) != "" and not m.reroll(0), "no more shopping once done")
	check_eq(m.phase, "draft", "waiting for the other player")
	check(m.finish_shopping(1), "they're done too")
	check_eq(m.phase, "place", "on to placing")


func test_shops_are_independent_of_the_other_players_rerolls() -> void:
	var a := _new_match(7)
	var b := _new_match(7)
	a.acorns[1] = 9
	a.reroll(1)
	a.reroll(1)
	_skip_draft(a)
	_skip_draft(b)
	for m in [a, b]:
		_fight(m)
		m.next_round()
	check_eq(a.shops[0], b.shops[0], "team 0's next shop is the same either way")


func test_acorns_herd_and_tool_belt_limits() -> void:
	var m := _new_match(4)
	var team := 0
	m.shops[team] = [
		{"id": "asian_elephant", "cost": 8, "mystery": false, "taken": -1},
		{"id": "red_fox", "cost": 3, "mystery": false, "taken": -1},
		{"id": "net", "cost": 2, "mystery": false, "taken": -1},
		{"id": "wild_boar", "cost": 4, "mystery": true, "taken": -1},
	]
	m.acorns[team] = 5
	check_eq(m.can_buy(team, 0), "Not enough Acorns", "too pricey")
	for i in int(GameData.draft_rules.herd_max):
		m.herds[team].append({"id": "sewer_rats", "x": 0, "y": 0, "stars": 1})
	check_eq(m.can_buy(team, 1), "Your herd is full", "herd limit")
	check_eq(m.can_buy(team, 3), "Your herd is full", "a Mystery Crate needs room too")
	m.herds[team][0].id = "red_fox"
	check_eq(m.can_buy(team, 1), "", "but a copy of a herd animal still fits: it adds a star")
	for i in int(GameData.draft_rules.tools_max):
		m.tools[team].append("net")
	check_eq(m.can_buy(team, 2), "Your tool belt is full", "tool limit")


func test_buying_a_copy_adds_a_star() -> void:
	var m := _new_match(5, ["red_fox"])
	var star_max := int(GameData.draft_rules.star_max)
	m.acorns[0] = 99
	m.shops[0] = []
	for i in star_max + 1:
		m.shops[0].append({"id": "red_fox", "cost": 3, "mystery": false, "taken": -1})
	check(m.buy(0, 0), "buy a second fox")
	check_eq(m.herds[0].size(), 1, "it doesn't join as a new animal...")
	check_eq(int(m.herds[0][0].stars), 2, "...it gives the fox a star")
	check(m.take_events().any(func(e): return e.type == "buy" and e.merged and e.stars == 2), "the screen hears it merged")
	for i in range(1, star_max - 1):
		m.buy(0, i)
	check_eq(int(m.herds[0][0].stars), star_max, "up to the most stars")
	check(m.buy(0, star_max - 1), "one more fox...")
	check_eq(m.herds[0].size(), 2, "...joins as a new animal")
	check_eq(int(m.herds[0][1].stars), 1, "with one star")


func test_training() -> void:
	var m := _new_match(6, ["brown_bear"])
	var rules := GameData.draft_rules
	var cost := int(GameData.get_card("brown_bear").cost)
	check_eq(m.train_cost(0, 0), cost + int(rules.train_extra), "one star to two: the card's cost plus a bit")
	m.acorns[0] = 1
	check_eq(m.can_train(0, 0), "Not enough Acorns", "needs the Acorns")
	m.acorns[0] = 99
	check(m.train(0, 0), "train")
	check_eq(m.acorns[0], 99 - cost - int(rules.train_extra), "paid")
	check_eq(int(m.herds[0][0].stars), 2, "two stars")
	check_eq(m.train_cost(0, 0), cost * 2 + int(rules.train_extra), "the next star costs more")
	m.train(0, 0)
	check_eq(m.train_cost(0, 0), -1, "no more stars to give")
	check(m.can_train(0, 0) != "", "can't train past the top")
	m.finish_shopping(0)
	check(m.can_train(0, 0) != "", "only while shopping")


func test_stars_make_animals_stronger() -> void:
	var m := _new_match(8, ["brown_bear"], ["brown_bear"])
	m.acorns[0] = 99
	m.train(0, 0)
	var mine: BattleSim.Fighter = m.sim.units(0)[0]
	var theirs: BattleSim.Fighter = m.sim.units(1)[0]
	var pct := 100 + int(GameData.draft_rules.star_bonus_pct)
	check_eq(mine.max_hp, theirs.max_hp * pct / 100, "more health")
	check_eq(mine.damage, theirs.damage * pct / 100, "a harder bite")
	check_eq(int(mine.memory.stars), 2, "the field knows to draw two stars")
	check(m.sim.herd_value(0) > m.sim.herd_value(1), "and it counts for more at the bell")


func test_the_loser_gets_bonus_acorns() -> void:
	var m := _with_herds(["brown_bear"], [])
	_fight(m)
	var acorns := m.acorns.duplicate()
	m.next_round()
	var rules := GameData.draft_rules
	check_eq(m.acorns[0], int(acorns[0]) + int(rules.acorns_per_round), "the winner gets the usual income")
	check_eq(m.acorns[1], int(acorns[1]) + int(rules.acorns_per_round) + int(rules.loser_bonus), "the loser gets a little extra")


func test_herds_start_on_their_own_half() -> void:
	var m := _with_herds(["red_fox", "hippopotamus"], ["wild_boar"])
	check_eq(m.sim.units(0).size(), 2, "the herd stands on the field while placing")
	check(m.sim.units(0).all(func(f): return f.deploy_ticks == 0), "already standing, not dropping in")
	check(m.sim.units(0).all(func(f): return DraftMatch.can_start_at(0, f.y)), "new animals stand on the near half")
	check(m.sim.units(1).all(func(f): return DraftMatch.can_start_at(1, f.y)), "the opponent's on the far half")
	check(m.move(0, 0, 3 * T, 17 * T), "the fox moves")
	check_eq(Vector2i(m.herds[0][0].x, m.herds[0][0].y), Vector2i(3 * T, 17 * T), "to the spot")
	check(m.move(0, 0, 3 * T, 4 * T), "a move onto the other half...")
	check(DraftMatch.can_start_at(0, m.herds[0][0].y), "...stops at the edge of your own")
	check(not DraftMatch.can_start_at(0, BattleSim.MIDDLE), "nobody starts right on the middle line")
	check_eq(m.herd_index_at(0, m.herds[0][0].x, m.herds[0][0].y), 0, "tapping the fox finds it")


func test_fight_pays_the_pot_to_the_winner() -> void:
	var m := _with_herds(["brown_bear", "lion", "wolf_pack"], ["sewer_rats"])
	var before := m.acorns.duplicate()
	_fight(m)
	check_eq(m.phase, "round_over", "round over")
	check_eq(m.last_round.winner, 0, "the big herd wins")
	var ante := int(GameData.draft_rules.ante)
	check_eq(m.acorns[0], before[0] + ante, "winner takes both antes")
	check_eq(m.acorns[1], before[1] - ante, "loser loses its ante")
	check_eq(m.pot, 0, "pot paid out")
	var standing := int(m.last_round.standing[0])
	check(standing > 0, "some of the winners still stand")
	check_eq(m.last_round.hearts_lost, [0, m.heart_loss(standing, false)], "the loser loses hearts")
	check_eq(m.hearts[1], int(GameData.draft_rules.hearts) - m.heart_loss(standing, false), "off its total")
	check_eq(m.hearts[0], int(GameData.draft_rules.hearts), "the winner keeps them all")


func test_heart_loss_grows_with_the_round_and_survivors() -> void:
	var m := _new_match(1)
	var rules := GameData.draft_rules
	check_eq(m.heart_loss(0, false), int(rules.heart_loss_per_round), "round 1, nobody standing")
	check_eq(m.heart_loss(3, false), int(rules.heart_loss_per_round) + 3 * int(rules.heart_loss_per_animal), "plus each animal still standing")
	check_eq(m.heart_loss(3, true), int(rules.heart_loss_per_round), "folding saves the extra")
	m.round_number = 4
	check_eq(m.heart_loss(0, false), 4 * int(rules.heart_loss_per_round), "more each round")


func test_an_empty_herd_loses_at_once() -> void:
	var m := _with_herds(["red_fox"], [])
	_start(m)
	check_eq(m.phase, "round_over", "no fight without two herds")
	check_eq(m.last_round.winner, 0, "the side with animals wins")
	check_eq(m.last_round.standing, [1, 0], "the fox is still standing")


func test_herds_and_hearts_carry_over() -> void:
	var m := _with_herds(["red_fox"], [])
	_fight(m)
	var hearts := m.hearts.duplicate()
	check(hearts[1] < int(GameData.draft_rules.hearts), "hearts lost")
	m.next_round()
	check_eq(m.round_number, 2, "next round")
	check_eq(m.hearts, hearts, "lost hearts stay lost")
	check(m.sim.units(0).size() == 1 and m.sim.units(0)[0].hp == m.sim.units(0)[0].max_hp, "the herd stands ready again, fully healed")
	check_eq(m.acorns[0], int(GameData.draft_rules.acorns_start) + int(GameData.draft_rules.ante) + int(GameData.draft_rules.acorns_per_round), "income each round")


func test_halftime_raise_and_fold() -> void:
	var m := _with_herds(["brown_bear", "red_fox"], ["brown_bear", "red_fox"])
	_start(m)
	while m.phase == "fight":
		m.step()
	check_eq(m.phase, "halftime", "the whistle blows")
	check_eq(m.fight_tick, m.halftime_ticks, "at halftime")
	check_eq(int(m.halftime.turn), 0, "the player acts first")
	check(m.max_raise(1) == 0, "not the opponent's turn yet")
	var acorns := m.acorns.duplicate()
	var pot := m.pot
	check(m.raise_pot(0, 2), "raise 2")
	check_eq(m.acorns[0], acorns[0] - 2, "the raise is paid")
	check_eq(m.pot, pot + 2, "into the pot")
	check(not m.check(1), "a raise can't be checked")
	check(not m.fold(0), "only the one facing the raise can fold")
	check(m.fold(1), "fold")
	check_eq(m.phase, "round_over", "folding ends the round")
	check_eq(m.last_round.winner, 0, "the raiser wins")
	check_eq(m.last_round.folded, 1, "noted who folded")
	check_eq(m.acorns[0], acorns[0] + pot, "and takes the pot")
	check_eq(m.last_round.hearts_lost, [0, m.heart_loss(0, true)], "the folder loses only the round's base hearts")


func test_halftime_call_and_checks_resume_the_fight() -> void:
	var m := _with_herds(["brown_bear"], ["brown_bear"])
	_start(m)
	while m.phase == "fight":
		m.step()
	check(m.check(0), "player checks")
	check_eq(int(m.halftime.turn), 1, "opponent's turn")
	check(m.raise_pot(1, 1), "opponent raises")
	var pot := m.pot
	check(m.call_raise(0), "player calls")
	check_eq(m.pot, pot + 1, "the call goes in")
	check_eq(m.phase, "fight", "and the fight goes on")
	m = _with_herds(["brown_bear"], ["brown_bear"])
	_start(m)
	while m.phase == "fight":
		m.step()
	check(not m.fold(0), "no folding without a raise to answer")
	m.check(0)
	m.check(1)
	check_eq(m.phase, "fight", "two checks: play on")


func test_a_raise_is_never_more_than_the_other_can_call() -> void:
	var m := _with_herds(["brown_bear"], ["brown_bear"])
	_start(m)
	while m.phase == "fight":
		m.step()
	m.acorns = [9, 1]
	check_eq(m.max_raise(0), 1, "capped by the opponent's Acorns")
	m.acorns = [0, 9]
	check_eq(m.max_raise(0), 0, "can't raise with nothing")


func test_tools_work_in_the_fight() -> void:
	var m := _with_herds(["red_fox"], ["red_fox", "red_fox"])
	m.tools[0].append("net")
	_start(m)
	m.step()
	var enemy: BattleSim.Fighter = m.sim.units(1)[0]
	check(m.use_tool(0, 0, enemy.x, enemy.y), "throw the net")
	check(enemy.stun > 0, "the enemy is tangled")
	check(m.tools[0].is_empty(), "the tool is used up")
	check(not m.use_tool(0, 0, enemy.x, enemy.y), "nothing left to use")


func test_rally_once_a_fight() -> void:
	var m := _with_herds(["wolf_pack", "brown_bear"], ["brown_bear"])
	_start(m)
	m.step()
	var wolf: BattleSim.Fighter = m.sim.units(0)[0]
	check(m.rally(0, wolf.x, wolf.y), "rally")
	check(wolf.rage > 0 and wolf.rage_damage_pct > 0, "the animals there are fired up")
	check(m.sim.units(1)[0].rage == 0, "not the enemy's")
	check(not m.rally(0, wolf.x, wolf.y), "only once a fight")
	check(m.rally(1, 9 * T, 10 * T), "the other player has their own")
	while m.phase == "fight" or m.phase == "halftime":
		if m.phase == "halftime":
			m.check(int(m.halftime.turn))
		else:
			m.step()
	if m.phase == "round_over":
		m.next_round()
		_skip_draft(m)
		_start(m)
		check(m.rally_ready[0], "a new fight, a new rally")


func test_the_match_ends_after_the_last_round() -> void:
	var m := _new_match(6)
	for r in m.max_rounds():
		_skip_draft(m)
		_fight(m)
		if m.phase == "round_over":
			m.next_round()
	check_eq(m.phase, "over", "over after the last round")
	check_eq(m.round_number, m.max_rounds(), "every round played")
	check_eq(m.match_winner(), DraftMatch.NO_WINNER, "nobody fought: a draw")
	m.hearts = [3, 5]
	check_eq(m.match_winner(), 1, "otherwise more hearts wins")


func test_running_out_of_hearts_ends_the_match() -> void:
	var m := _with_herds(["brown_bear", "lion"], ["sewer_rats"])
	m.hearts[1] = 2
	_fight(m)
	check_eq(m.phase, "over", "match over")
	check_eq(m.hearts[1], 0, "no hearts left (never below zero)")
	check_eq(m.match_winner(), 0, "the other player wins")


func test_raccoon_steals_acorns() -> void:
	var m := _with_herds(["raccoon"], ["red_fox"])
	m.acorns = [5, 5]
	_start(m)
	var ante := int(GameData.draft_rules.ante)
	var amount := int(GameData.get_card("raccoon").ability.params.amount)
	check_eq(m.acorns, [5 - ante + amount, 5 - ante - amount], "one Acorn changes hands as the fight starts")
	check(m.take_events().any(func(e): return e.type == "steal" and e.team == 0), "and the screen hears about it")


func test_the_shop_draws_from_the_pool() -> void:
	var pool := ["red_fox", "raccoon", "wild_boar", "brown_bear", "sewer_rats", "net"]
	for seed_value in 5:
		var m := DraftMatch.new(seed_value, {"pool": pool})
		m.pick_starters(0, [])
		m.pick_starters(1, [])
		check(m.shops[0].all(func(item): return pool.has(item.id)), "seed %d: only cards from the pool" % seed_value)


func test_pool_from_a_collection() -> void:
	var starters := GameData.cards_in_arena(0)
	var pool := DraftMatch.pool_from_collection(func(id): return starters.has(id) or id == "tiger")
	check(pool.has("tiger"), "cards you own")
	check(starters.all(func(id): return pool.has(id)), "and your starters")
	check(not pool.has("amur_leopard"), "but not cards you haven't found")
	var tiny := DraftMatch.pool_from_collection(func(id): return id == "red_fox")
	var animals := tiny.filter(func(id): return not GameData.is_tool(id)).size()
	check(animals >= int(GameData.draft_rules.market_animals), "topped up to fill the Watering Hole")


func test_card_levels_carry_into_the_fight() -> void:
	var m := DraftMatch.new(1, {"levels": [{"red_fox": 6}, {}]})
	check_eq(m.sim.level_of(0, "red_fox"), 6, "your level")
	check_eq(m.sim.level_of(1, "red_fox"), GameData.start_level("common"), "theirs at the start level")


func test_backing_your_herd() -> void:
	var m := _with_herds(["red_fox"], ["brown_bear"])
	m.set_ready(0)
	m.set_ready(1)
	check_eq(m.phase, "wager", "the Bookie's turn after placing")
	check_eq(m.max_wager(0), 0, "no bets before the odds are posted")
	m.post_line(0.2)
	check(m.payout(0) > 300, "the long shot pays well (x%.2f)" % (m.payout(0) / 100.0))
	check(m.payout(1) < 130, "the favorite pays little (x%.2f)" % (m.payout(1) / 100.0))
	var rules := GameData.draft_rules
	check_eq(m.max_wager(0), mini(int(rules.wager_max), m.acorns[0] - int(rules.ante)), "keeps enough for the ante")
	var acorns: int = m.acorns[0]
	check(not m.wager(0, m.max_wager(0) + 1), "can't bet more than allowed")
	check(m.wager(0, 3), "bet 3 on the fox")
	check_eq(m.acorns[0], acorns - 3, "the stake is taken")
	check_eq(m.phase, "wager", "waiting for the other player")
	check(m.wager(1, 0), "no bet")
	check_eq(m.phase, "fight", "then the fight starts")
	m.sim.units(1)[0].hp = 1  # the bear is nearly beaten already
	while m.phase == "fight" or m.phase == "halftime":
		if m.phase == "halftime":
			m.check(int(m.halftime.turn))
		else:
			m.step()
	check_eq(m.last_round.winner, 0, "the fox wins")
	check_eq(m.last_round.paid[0], 3 * m.payout(0) / 100, "the Bookie pays the long shot")


func test_no_bets_on_a_sure_thing() -> void:
	var m := _with_herds(["brown_bear"], ["sewer_rats"])
	m.set_ready(0)
	m.set_ready(1)
	m.post_line(0.97)
	check_eq(m.max_wager(0), 0, "the Bookie won't take it")
	check(m.max_wager(1) > 0, "but the long shot may bet")


func test_bookie_odds() -> void:
	var m := _with_herds(["brown_bear", "lion", "wolf_pack", "tiger"], ["sewer_rats"])
	m.set_ready(0)
	m.set_ready(1)
	var checksum := m.sim.checksum()
	var bookie := Bookie.study(m, 1)
	check(not bookie.is_ready(), "takes some thinking")
	bookie.advance()
	check(bookie.is_ready(), "ready")
	check(bookie.chance(0) > 0.75, "favors the big herd (%.2f)" % bookie.chance(0))
	check(is_equal_approx(bookie.chance(0) + bookie.chance(1), 1.0), "the chances add up")
	check_eq(m.sim.checksum(), checksum, "thinking ahead doesn't change the real fight")


func test_a_copy_of_a_battle_plays_out_the_same() -> void:
	var m := _with_herds(["wolf_pack", "gray_squirrel", "red_panda"], ["cheetah", "peregrine_falcon", "raccoon"])
	_start(m)
	for i in 60:
		m.step()
	var copy := m.sim.clone()
	for i in 200:
		m.sim.step()
		copy.step()
	check_eq(copy.checksum(), m.sim.checksum(), "same moves, same result")


func _bot_match(seed_value: int) -> DraftMatch:
	var m := DraftMatch.new(seed_value)
	var bots := [DraftBot.new(m, 0, seed_value + 1, 0.5), DraftBot.new(m, 1, seed_value + 2, 0.8)]
	var guard := 0
	while not m.is_over() and guard < 200000:
		guard += 1
		match m.phase:
			"starters":
				for b in bots:
					b.pick_starters()
			"draft":
				for b in bots:
					b.shop()
			"place":
				for b in bots:
					if not m.ready[b.team]:
						b.place()
			"wager":
				m.post_line(0.5)
				for b in bots:
					b.back_herd(0.5)
			"fight":
				for b in bots:
					b.update()
				m.step()
			"halftime":
				bots[int(m.halftime.turn)].bet(0.5)
			"round_over":
				m.next_round()
		check(m.acorns[0] >= 0 and m.acorns[1] >= 0, "Acorns never go below zero")
	return m


func test_bots_play_whole_matches() -> void:
	for seed_value in [11, 12]:
		var m := _bot_match(seed_value)
		check(m.is_over(), "seed %d: the match finishes" % seed_value)
		check(m.herds[0].size() > 0 and m.herds[1].size() > 0, "seed %d: both have a herd" % seed_value)
		check(m.herds[0].size() + m.herds[1].size() > 2 * int(GameData.draft_rules.starters), "seed %d: and bought more" % seed_value)


func test_same_seed_same_match() -> void:
	var a := _bot_match(21)
	var b := _bot_match(21)
	check_eq(a.sim.checksum(), b.sim.checksum(), "deterministic")
	check_eq(a.acorns, b.acorns, "same Acorns")


func test_stakes_scale_trophies() -> void:
	var settings: Dictionary = GameData.progression.trophies
	var arenas := GameData.arenas
	# 1200 trophies: well above the arena's floor, so a loss isn't cut short.
	var normal := TrophyRules.trophies_after_match(1200, 1200, true, settings, arenas) - 1200
	check_eq(TrophyRules.trophies_after_match(1200, 1200, true, settings, arenas, 2.0) - 1200, normal * 2, "all-in doubles a win")
	check_eq(TrophyRules.trophies_after_match(1200, 1200, false, settings, arenas, 0.5) - 1200, -roundi(normal * 0.5), "safe halves a loss")
