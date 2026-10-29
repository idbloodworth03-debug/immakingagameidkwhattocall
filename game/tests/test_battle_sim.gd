extends TestCase
## Battle engine tests. Most build a battle, place animals directly with
## spawn() and run ticks, so they don't depend on deck shuffling.

const T := BattleSim.TILE


func _sim(deck_a: Array = [], deck_b: Array = [], seed_value := 1) -> BattleSim:
	var filler := ["raccoon", "red_fox", "net", "air_horn", "brown_bear", "rattlesnake", "lion", "tiger"]
	var a := deck_a if not deck_a.is_empty() else filler
	var b := deck_b if not deck_b.is_empty() else filler
	return BattleSim.new([a, b], [{}, {}], seed_value)


func _run(sim: BattleSim, seconds: float) -> void:
	for i in roundi(seconds * sim.tps):
		sim.step()


func _tower(sim: BattleSim, team: int, kind: String, x_side := 0) -> BattleSim.Fighter:
	for t in sim.towers(team):
		if t.tower_kind == kind and (kind == "main" or (x_side < 0) == (t.x < BattleSim.WIDTH / 2)):
			return t
	return null


func test_starting_state() -> void:
	var sim := _sim()
	check_eq(sim.towers(0).size(), 3, "three towers each")
	check_eq(sim.hand(0).size(), 4, "four cards in hand")
	check_eq(sim.energy(0), 5.0, "start with 5 energy")
	var main := _tower(sim, 0, "main")
	var side := _tower(sim, 0, "side", -1)
	check(main.max_hp > side.max_hp and main.damage > side.damage, "main tower is tougher and hits harder")


func test_energy_refills_and_caps() -> void:
	var sim := _sim()
	_run(sim, 2.85)
	check_eq(floori(sim.energy(0)), 6, "one energy every 2.8 seconds")
	_run(sim, 30)
	check_eq(sim.energy(0), 10.0, "capped at 10")


func test_double_energy_in_last_minute() -> void:
	var sim := _sim()
	sim.tick = sim.double_energy_tick
	sim.teams[0].energy = 0
	_run(sim, 1.45)
	check_eq(floori(sim.energy(0)), 1, "twice as fast in the last minute")
	check(sim.is_double_energy(), "flag on")


func test_release_rules_and_card_cycle() -> void:
	var sim := _sim(["raccoon", "red_fox", "opossum", "gray_squirrel", "pigeon_flock", "sewer_rats", "platypus", "cheetah"])
	var first: String = sim.hand(0)[0]
	var next := sim.next_card(0)
	check(not sim.release(0, 0, 9 * T, 5 * T), "can't release animals on the enemy side")
	check(sim.release(0, 0, 9 * T, 22 * T), "own side is fine")
	check_eq(sim.hand(0)[0], next, "next card slides into the hand")
	check_eq(sim.teams[0].queue.back(), first, "played card goes to the back")
	check(sim.energy(0) < 5.0, "energy spent")


func test_tough_animal_walks_over_the_bridge_and_hits_a_tower() -> void:
	var sim := _sim()
	sim.spawn(0, "brown_bear", 4 * T, 21 * T)
	var tower := _tower(sim, 1, "side", -1)
	_run(sim, 30)
	check(tower.hp < tower.max_hp, "the bear reached the left enemy tower")


func test_towers_shoot_attackers() -> void:
	var sim := _sim()
	var bear: BattleSim.Fighter = sim.spawn(1, "brown_bear", 4 * T, 21 * T)[0]
	_run(sim, 6)
	check(bear.hp < bear.max_hp, "our tower is shooting the bear")


func test_destroying_the_main_tower_wins() -> void:
	var sim := _sim()
	sim.deal_damage(_tower(sim, 1, "main"), 999999, null)
	sim.step()
	check_eq(sim.outcome, 0, "team 0 wins at once")
	check_eq(sim.teams[0].towers_destroyed, 3, "the side towers fall with it")


func test_more_towers_wins_at_time() -> void:
	var sim := _sim()
	sim.deal_damage(_tower(sim, 1, "side", -1), 999999, null)
	sim.tick = sim.match_ticks - 1
	sim.step()
	check_eq(sim.outcome, 0, "one tower up wins when time runs out")


func test_tie_goes_to_overtime_then_sudden_death() -> void:
	var sim := _sim()
	sim.tick = sim.match_ticks - 1
	sim.step()
	check(not sim.is_over() and sim.in_overtime(), "tied: overtime")
	sim.deal_damage(_tower(sim, 0, "side", 1), 999999, null)
	sim.step()
	check_eq(sim.outcome, 1, "first tower in overtime wins")


func test_untouched_battle_is_a_draw() -> void:
	var sim := _sim()
	sim.tick = sim.match_ticks + sim.overtime_ticks - 1
	sim.step()
	check_eq(sim.outcome, BattleSim.DRAW, "nothing happened: draw")


func test_tiebreak_by_weakest_tower() -> void:
	var sim := _sim()
	sim.deal_damage(_tower(sim, 1, "side", -1), 300, null)
	sim.tick = sim.match_ticks + sim.overtime_ticks - 1
	sim.step()
	check_eq(sim.outcome, 0, "team 1's weakest tower is lower")


func test_flyers_cross_the_river_anywhere_walkers_use_bridges() -> void:
	var sim := _sim()
	var bird: BattleSim.Fighter = sim.spawn(0, "peregrine_falcon", 9 * T, 18 * T)[0]
	var boar: BattleSim.Fighter = sim.spawn(0, "wild_boar", 9 * T, 18 * T)[0]
	var bird_crossed_mid := false
	for i in 200:
		sim.step()
		if BattleSim.bank(boar.y) == 0:
			check(absi(boar.x - BattleSim.nearest_bridge(boar.x)) <= BattleSim.BRIDGE_HALF_WIDTH, "the boar is only in the river on a bridge")
		if BattleSim.bank(bird.y) == 0 and absi(bird.x - 9 * T) < 3 * T:
			bird_crossed_mid = true
	check(bird_crossed_mid, "the falcon flew straight across the middle")


func test_same_seed_same_battle() -> void:
	var results := []
	for run in 2:
		var sim := _sim([], [], 77)
		var bot_a := BattleBot.new(sim, 0, 5)
		var bot_b := BattleBot.new(sim, 1, 6)
		for i in 60 * sim.tps:
			bot_a.update()
			bot_b.update()
			sim.step()
		results.append(sim.checksum())
	check_eq(results[0], results[1], "identical battles from identical inputs")


func test_bots_can_finish_a_battle() -> void:
	for seed_value in [3, 11]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var deck_a := BattleBot.make_deck(GameData.arenas.size() - 1, 2, rng)
		var deck_b := BattleBot.make_deck(GameData.arenas.size() - 1, 2, rng)
		var sim := BattleSim.new([deck_a.deck, deck_b.deck], [deck_a.levels, deck_b.levels], seed_value)
		var bot_a := BattleBot.new(sim, 0, seed_value + 1)
		var bot_b := BattleBot.new(sim, 1, seed_value + 2)
		var released := 0
		while not sim.is_over():
			bot_a.update()
			bot_b.update()
			sim.step()
			for e in sim.take_events():
				if e.type == "release":
					released += 1
		check(sim.outcome in [0, 1, BattleSim.DRAW], "battle %d ended with a result" % seed_value)
		check(released > 10, "bots played cards in battle %d (%d)" % [seed_value, released])


func test_swap_only_when_stuck() -> void:
	var picky := ["california_condor", "asian_elephant", "lion", "black_footed_ferret", "california_condor", "asian_elephant", "lion", "black_footed_ferret"]
	var sim := _sim(picky)
	check(sim.can_swap(0), "every card waits on a requirement")
	var first: String = sim.hand(0)[0]
	check(sim.swap(0, 0), "swapped")
	check_eq(sim.teams[0].queue.back(), first, "swapped card goes to the back")
	var normal := _sim()
	check(not normal.can_swap(0), "no swapping when something is playable")
	check(not normal.swap(0, 0), "swap refused")


# --- Abilities -------------------------------------------------------------

func test_shield_absorbs_damage() -> void:
	var sim := _sim()
	var turtle: BattleSim.Fighter = sim.spawn(0, "snapping_turtle", 9 * T, 22 * T)[0]
	sim.deal_damage(turtle, 200, null)
	check_eq(turtle.hp, turtle.max_hp, "shell took it")
	sim.deal_damage(turtle, 200, null)
	check_eq(turtle.hp, turtle.max_hp - 100, "shell broke after 300")


func test_poison_keeps_hurting() -> void:
	var sim := _sim()
	var snake: BattleSim.Fighter = sim.spawn(0, "rattlesnake", 9 * T, 20 * T)[0]
	var rat: BattleSim.Fighter = sim.spawn(1, "honey_badger", 9 * T, 20 * T + 900)[0]
	var bear: BattleSim.Fighter = sim.spawn(1, "brown_bear", 9 * T, 20 * T - 900)[0]
	BattleAbilities.after_hit(sim, snake, bear, 10)
	BattleAbilities.after_hit(sim, snake, rat, 10)
	check(bear.poison > 0, "bear poisoned")
	check_eq(rat.poison, 0, "honey badger is fearless")
	var before := bear.hp
	_run(sim, 1)
	check(bear.hp < before, "poison hurts over time")


func test_opossum_plays_dead() -> void:
	var sim := _sim()
	var possum: BattleSim.Fighter = sim.spawn(0, "opossum", 9 * T, 22 * T)[0]
	sim.deal_damage(possum, 99999, null)
	check(possum.alive, "playing dead, not defeated")
	sim.deal_damage(possum, 99999, null)
	check(possum.alive, "can't be hurt while playing dead")
	_run(sim, 2.1)
	check_eq(possum.hp, possum.max_hp * 40 / 100, "gets back up with 40%")
	sim.deal_damage(possum, 99999, null)
	check(not possum.alive, "only once")


func test_pack_hunters_hit_harder_together() -> void:
	var sim := _sim()
	var wolves := sim.spawn(0, "wolf_pack", 9 * T, 22 * T)
	var dummy: BattleSim.Fighter = sim.spawn(1, "brown_bear", 9 * T, 8 * T)[0]
	var together := BattleAbilities.outgoing_damage(sim, wolves[0], dummy, 100)
	var lone: BattleSim.Fighter = sim.spawn(0, "coyote_pack", 2 * T, 28 * T)[0]
	sim.units(0).filter(func(f): return f != lone and f.card.id == "coyote_pack").map(func(f): f.alive = false)
	var alone := BattleAbilities.outgoing_damage(sim, lone, dummy, 100)
	check_eq(together, 130, "two other canines nearby: +30%")
	check_eq(alone, 100, "alone: no bonus")


func test_stealth_until_first_attack() -> void:
	var sim := _sim()
	var owl: BattleSim.Fighter = sim.spawn(0, "barn_owl", 9 * T, 22 * T)[0]
	var tower := _tower(sim, 1, "main")
	check(not sim.can_target(tower, owl), "hidden")
	owl.revealed = 10
	check(sim.can_target(tower, owl), "a flare reveals it")


func test_raccoon_steals_energy() -> void:
	var sim := _sim()
	sim.spawn(0, "raccoon", 9 * T, 22 * T)
	check_eq(sim.energy(1), 4.0, "enemy lost 1 energy")


func test_burrower_is_untargetable_then_emerges() -> void:
	var sim := _sim()
	var ferret: BattleSim.Fighter = sim.spawn(0, "black_footed_ferret", 4 * T, 22 * T)[0]
	check(not sim.can_target(_tower(sim, 1, "side", -1), ferret), "underground")
	_run(sim, 20)
	check(not ferret.memory.get("burrowing", true) or not ferret.alive, "popped up at the enemy")


# --- Ranger tools ----------------------------------------------------------

func _tool_sim(tool_id: String) -> BattleSim:
	return _sim([tool_id, tool_id, tool_id, tool_id, tool_id, tool_id, tool_id, tool_id])


func test_net_stuns() -> void:
	var sim := _tool_sim("net")
	var bear: BattleSim.Fighter = sim.spawn(1, "brown_bear", 9 * T, 10 * T)[0]
	check(sim.release(0, 0, 9 * T, 10 * T), "nets work on the enemy side")
	check(bear.stun > 0, "stuck in the net")
	check(bear.hp < bear.max_hp, "and slightly hurt")


func test_air_horn_damages_and_knocks_back() -> void:
	var sim := _tool_sim("air_horn")
	var rat: BattleSim.Fighter = sim.spawn(1, "sewer_rats", 9 * T, 10 * T)[0]
	var tower := _tower(sim, 1, "side", -1)
	sim.release(0, 0, 9 * T, 10 * T)
	check(not rat.alive, "rats can't take the blast")
	var sim2 := _tool_sim("air_horn")
	var tower2 := _tower(sim2, 1, "side", -1)
	sim2.release(0, 0, tower2.x, tower2.y)
	check(tower2.hp < tower2.max_hp and tower2.max_hp - tower2.hp < 180, "towers take only part of the damage")
	check_eq(tower.hp, tower.max_hp, "first tower untouched")


func test_medkit_heals_allies() -> void:
	var sim := _tool_sim("medkit")
	var bear: BattleSim.Fighter = sim.spawn(0, "brown_bear", 9 * T, 22 * T)[0]
	bear.hp = 100
	sim.release(0, 0, 9 * T, 22 * T)
	check_eq(bear.hp, 450, "healed by 350")


func test_food_bait_lures_enemies() -> void:
	var sim := _tool_sim("food_bait")
	var boar: BattleSim.Fighter = sim.spawn(1, "wild_boar", 4 * T, 18 * T)[0]
	check(not sim.release(0, 0, 9 * T, 8 * T), "bait only on your own side")
	check(sim.release(0, 0, 6 * T, 20 * T), "bait on your side")
	_run(sim, 1.5)
	check(boar.target != null and boar.target.kind == "bait", "the boar goes for the snack")


func test_tranq_dart_puts_the_closest_to_sleep() -> void:
	var sim := _tool_sim("tranq_dart")
	var near: BattleSim.Fighter = sim.spawn(1, "brown_bear", 9 * T, 10 * T)[0]
	var far: BattleSim.Fighter = sim.spawn(1, "moose", 12 * T, 10 * T)[0]
	sim.release(0, 0, 9 * T, 10 * T)
	check(near.stun > 0, "closest is asleep")
	check_eq(far.stun, 0, "only one target")
