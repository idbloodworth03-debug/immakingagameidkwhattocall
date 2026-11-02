extends TestCase
## Draft Duel tests: the draft, placing, the Pot and halftime betting, rounds
## and dens, the Bookie's odds and the computer opponent.

const T := BattleSim.TILE


## Ends the draft with nobody buying anything.
func _skip_draft(m: DraftMatch) -> void:
	while m.phase == "draft":
		m.pass_turn(m.turn)


## Skips to placing and gives each team the herd listed, at its default spots.
func _with_herds(herd_0: Array, herd_1: Array, seed_value := 3) -> DraftMatch:
	var m := DraftMatch.new(seed_value)
	_skip_draft(m)
	for team in 2:
		for id in [herd_0, herd_1][team]:
			var spot := m.default_spot(team, id)
			m.herds[team].append({"id": id, "x": spot.x, "y": spot.y})
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


func test_a_match_starts_with_a_draft() -> void:
	var m := DraftMatch.new(1)
	var rules := GameData.draft_rules
	check_eq(m.phase, "draft", "starts at the Watering Hole")
	check_eq(m.round_number, 1, "round 1")
	check_eq(m.acorns, [int(rules.acorns_start), int(rules.acorns_start)], "same Acorns for both")
	check_eq(m.market.size(), int(rules.market_animals) + int(rules.market_tools) + int(rules.mystery_crates), "a full Watering Hole")
	check_eq(m.market.filter(func(s): return s.mystery).size(), int(rules.mystery_crates), "a Mystery Crate")
	check_eq(m.market.filter(func(s): return GameData.is_tool(s.id) and not s.mystery).size(), int(rules.market_tools), "a tool")
	check(m.sim.towers(0).size() == 3 and m.sim.towers(1).size() == 3, "three dens each")


func test_players_take_turns_buying() -> void:
	var m := DraftMatch.new(2)
	var first := m.turn
	var slot := -1
	for i in m.market.size():
		if m.can_buy(first, i) == "":
			slot = i
			break
	check(slot >= 0, "something affordable")
	check(m.can_buy(1 - first, slot) != "", "can't buy out of turn")
	var before: int = m.acorns[first]
	check(m.buy(first, slot), "buy")
	check_eq(m.acorns[first], before - int(m.market[slot].cost), "pays the price")
	check_eq(m.herds[first].size() + m.tools[first].size(), 1, "the card joins the herd or tool belt")
	check_eq(m.turn, 1 - first, "then it's the other player's turn")
	check(m.can_buy(1 - first, slot) != "", "a taken card can't be bought again")


func test_acorns_herd_and_tool_belt_limits() -> void:
	var m := DraftMatch.new(4)
	var team := m.turn
	m.market = [
		{"id": "asian_elephant", "cost": 8, "mystery": false, "taken": -1},
		{"id": "red_fox", "cost": 3, "mystery": false, "taken": -1},
		{"id": "net", "cost": 2, "mystery": false, "taken": -1},
	]
	m.acorns[team] = 5
	check_eq(m.can_buy(team, 0), "Not enough Acorns", "too pricey")
	for i in int(GameData.draft_rules.herd_max):
		m.herds[team].append({"id": "sewer_rats", "x": 0, "y": 0})
	check_eq(m.can_buy(team, 1), "Your herd is full", "herd limit")
	for i in int(GameData.draft_rules.tools_max):
		m.tools[team].append("net")
	check_eq(m.can_buy(team, 2), "Your tool belt is full", "tool limit")


func test_draft_ends_when_nobody_can_go_on() -> void:
	var m := DraftMatch.new(5)
	_skip_draft(m)
	check_eq(m.phase, "place", "on to placing")
	m = DraftMatch.new(5)
	m.acorns = [0, 0]
	m.passed = [false, false]
	m._next_turn()
	check_eq(m.phase, "place", "nobody can afford anything: the draft ends by itself")


func test_herds_start_on_their_own_side() -> void:
	var m := _with_herds(["red_fox", "hippopotamus"], ["wild_boar"])
	check_eq(m.sim.units(0).size(), 2, "the herd stands on the field while placing")
	check(m.sim.units(0).all(func(f): return f.deploy_ticks == 0), "already standing, not dropping in")
	check(m.move(0, 0, 9 * T, 25 * T), "fox moves on its own side")
	check(not m.move(0, 0, 9 * T, 8 * T), "not onto the enemy side")
	check(not m.move(0, 0, 9 * T, 15 * T), "not into the river")
	check(m.sim.zone_for(0, m.herds[0][1].x, m.herds[0][1].y) == "river", "the hippo starts in the river")
	check(not m.move(0, 1, 9 * T, 22 * T), "and can't start on land")
	check_eq(m.herd_index_at(0, 9 * T, 25 * T), 0, "tapping the fox finds it")


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
	check(int(m.last_round.dealt[0]) > 0, "the winning herd reached the dens")


func test_dens_keep_their_damage_between_rounds() -> void:
	var m := _with_herds(["red_fox"], [])
	_fight(m)
	var hurt := DraftMatch.den_health(m.sim, 1)
	check(hurt < m.den_before[1], "dens took damage")
	m.next_round()
	check_eq(m.round_number, 2, "next round")
	check_eq(DraftMatch.den_health(m.sim, 1), hurt, "the damage stays")
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
	var den := DraftMatch.den_health(m.sim, 1)
	check(m.fold(1), "fold")
	check_eq(m.phase, "round_over", "folding ends the round")
	check_eq(m.last_round.winner, 0, "the raiser wins")
	check_eq(m.last_round.folded, 1, "noted who folded")
	check_eq(m.acorns[0], acorns[0] + pot, "and takes the pot")
	check_eq(DraftMatch.den_health(m.sim, 1), den, "the folder's dens take no more damage")


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
	var m := DraftMatch.new(6)
	for r in m.rounds():
		_skip_draft(m)
		_fight(m)
		if m.phase == "round_over":
			m.next_round()
	check_eq(m.phase, "over", "over after the last round")
	check_eq(m.round_number, m.rounds(), "every round played")
	check_eq(m.match_winner(), DraftMatch.NO_WINNER, "nobody fought: a draw")


func test_the_main_den_falling_ends_the_match() -> void:
	var m := _with_herds(["asian_elephant", "black_rhino", "american_bison"], [])
	for t in m.sim.towers(1):
		t.hp = 50
	_fight(m)
	check_eq(m.phase, "over", "match over")
	check_eq(m.match_winner(), 0, "the den breakers win")


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
			"draft":
				bots[m.turn].pick()
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
		check(m.herds[0].size() > 0 and m.herds[1].size() > 0, "seed %d: both drafted a herd" % seed_value)


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
