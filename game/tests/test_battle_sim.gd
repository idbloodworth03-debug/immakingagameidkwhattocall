extends TestCase
## Battle engine tests. Each builds a fight, puts animals on the field with
## spawn() and runs ticks.

const T := BattleSim.TILE


func _sim(seed_value := 1, levels: Array = [{}, {}]) -> BattleSim:
	return BattleSim.new(levels, seed_value)


func _run(sim: BattleSim, seconds: float) -> void:
	for i in roundi(seconds * sim.tps):
		sim.step()


func _ready_now(made: Array) -> Array:
	for f in made:
		f.deploy_ticks = 0
	return made


func test_open_field_and_halves() -> void:
	var sim := _sim()
	check_eq(sim.fighters.size(), 0, "an empty field to start")
	check_eq(sim.width, 16 * T, "16 tiles wide")
	check_eq(sim.height, 20 * T, "20 tiles long")
	check(sim.on_own_half(0, 15 * T) and not sim.on_own_half(0, 5 * T), "team 0 has the near half")
	check(sim.on_own_half(1, 5 * T) and not sim.on_own_half(1, 15 * T), "team 1 has the far half")
	sim.set_size(1.5)
	check_eq(sim.width, 24 * T, "a bigger field for big herds")
	check_eq(sim.height, 30 * T, "the same shape")
	check_eq(sim.middle, 15 * T, "the middle line moves with it")


func test_nothing_to_fight_means_standing_still() -> void:
	var sim := _sim()
	var fox: BattleSim.Fighter = _ready_now(sim.spawn(0, "red_fox", 8 * T, 15 * T))[0]
	_run(sim, 3)
	check_eq(Vector2i(fox.x, fox.y), Vector2i(8 * T, 15 * T), "no enemies, no walking")


func test_animals_find_the_nearest_enemy_and_fight() -> void:
	var sim := _sim()
	var bear: BattleSim.Fighter = _ready_now(sim.spawn(0, "brown_bear", 8 * T, 15 * T))[0]
	var near: BattleSim.Fighter = _ready_now(sim.spawn(1, "gray_squirrel", 3 * T, 6 * T))[0]
	var far: BattleSim.Fighter = _ready_now(sim.spawn(1, "raccoon", 15 * T, 1 * T))[0]
	_run(sim, 0.2)
	check(bear.target == near, "the bear goes for the closer squirrel")
	var guard := 0
	while near.alive and bear.alive and guard < 30 * sim.tps:
		sim.step()
		guard += 1
	check(not near.alive, "and beats it")
	sim.step()
	check(bear.target == far, "then goes after the raccoon")


func test_ground_animals_cant_reach_flyers() -> void:
	var sim := _sim()
	var bear: BattleSim.Fighter = sim.spawn(0, "brown_bear", 8 * T, 15 * T)[0]
	var squirrel: BattleSim.Fighter = sim.spawn(0, "gray_squirrel", 6 * T, 15 * T)[0]
	var falcon: BattleSim.Fighter = sim.spawn(1, "peregrine_falcon", 8 * T, 5 * T)[0]
	check(falcon.is_flying(), "the falcon flies")
	check(not sim.can_target(bear, falcon), "a bear can't reach it")
	check(sim.can_target(squirrel, falcon), "a squirrel's acorns can")


func test_everyone_stays_on_the_field() -> void:
	var sim := _sim(9)
	for i in 3:
		sim.spawn(0, "wild_boar", (3 + 5 * i) * T, 18 * T)
		sim.spawn(1, "hippopotamus", (3 + 5 * i) * T, 2 * T)
	for i in 30 * sim.tps:
		sim.step()
		for f in sim.fighters:
			if f.x < 0 or f.x > sim.width or f.y < 0 or f.y > sim.height:
				check(false, "%s left the field at (%d, %d)" % [f.card.id, f.x, f.y])
				return
	check(true, "nobody left the field")


func test_levels_make_animals_stronger() -> void:
	var start := GameData.start_level("common")
	var sim := _sim(1, [{"red_fox": start + 4}, {}])
	var strong: BattleSim.Fighter = sim.spawn(0, "red_fox", 4 * T, 15 * T)[0]
	var normal: BattleSim.Fighter = sim.spawn(1, "red_fox", 4 * T, 5 * T)[0]
	check_eq(sim.level_of(1, "red_fox"), start, "unlisted cards fight at their starting level")
	check(strong.max_hp > normal.max_hp and strong.damage > normal.damage, "four levels up: more health, harder bites")


func test_herd_value_counts_health_left() -> void:
	var sim := _sim()
	var bear: BattleSim.Fighter = sim.spawn(0, "brown_bear", 8 * T, 15 * T)[0]
	var cost := int(GameData.get_card("brown_bear").cost)
	check_eq(sim.herd_value(0), cost * 1000, "a fresh bear counts its whole cost")
	bear.hp = bear.max_hp / 2
	check_eq(sim.herd_value(0), cost * 500, "half its health, half its value")
	check_eq(sim.herd_value(1), 0, "an empty herd is worth nothing")


func test_same_seed_same_fight() -> void:
	var results := []
	for run in 2:
		var sim := _sim(77)
		for id in ["wolf_pack", "red_fox", "gray_squirrel"]:
			sim.spawn(0, id, 8 * T, 14 * T)
		for id in ["brown_bear", "harbor_seal", "peregrine_falcon"]:
			sim.spawn(1, id, 8 * T, 6 * T)
		_run(sim, 30)
		results.append(sim.checksum())
	check_eq(results[0], results[1], "identical fights from identical starts")


func test_a_clone_plays_out_the_same() -> void:
	var sim := _sim(5)
	sim.spawn(0, "lion", 6 * T, 14 * T)
	sim.spawn(0, "wild_boar", 10 * T, 14 * T)
	sim.spawn(1, "tiger", 8 * T, 6 * T)
	_run(sim, 2)
	var copy := sim.clone()
	_run(sim, 10)
	_run(copy, 10)
	check_eq(copy.checksum(), sim.checksum(), "the copy matches the original")


func test_clear_units_empties_the_field() -> void:
	var sim := _sim()
	sim.spawn(0, "wolf_pack", 8 * T, 15 * T)
	sim.make_bait(1, 8 * T, 5 * T, 100, 100, 3 * T)
	sim.clear_units()
	check_eq(sim.fighters.size(), 0, "nothing left")


# --- Classes and traits ----------------------------------------------------

func test_every_animal_has_a_class() -> void:
	var later: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals_later.json"))
	for card in GameData.cards.values().filter(func(c): return c.kind == "animal") + Array(later):
		check(GameData.classes.has(card.get("class", "")), "%s has a class" % card.id)
		check((card.get("class", "") == "specialist") == GameData.traits.has(card.get("trait", "")), "%s: Specialists, and only they, have a trait" % card.id)


func test_air_is_hit_only_by_ranged_and_air() -> void:
	var sim := _sim()
	var falcon: BattleSim.Fighter = sim.spawn(1, "peregrine_falcon", 8 * T, 5 * T)[0]
	var tank: BattleSim.Fighter = sim.spawn(0, "brown_bear", 8 * T, 15 * T)[0]
	var destroyer: BattleSim.Fighter = sim.spawn(0, "lion", 6 * T, 15 * T)[0]
	var ranged: BattleSim.Fighter = sim.spawn(0, "raccoon", 4 * T, 15 * T)[0]
	var air: BattleSim.Fighter = sim.spawn(0, "california_condor", 10 * T, 15 * T)[0]
	check(falcon.is_flying() and air.is_flying(), "Air flies")
	check(not sim.can_target(tank, falcon) and not sim.can_target(destroyer, falcon), "Tanks and Tank Destroyers can't reach it")
	check(sim.can_target(ranged, falcon) and sim.can_target(air, falcon), "Ranged and Air can")
	check(ranged.attack_range >= roundi(float(GameData.class_info("ranged").range) * T), "Ranged reach far, even a Raccoon")


func test_tank_destroyers_hit_tanks_hard() -> void:
	var sim := _sim()
	var lion: BattleSim.Fighter = sim.spawn(0, "lion", 8 * T, 15 * T)[0]
	var bear: BattleSim.Fighter = sim.spawn(1, "brown_bear", 8 * T, 5 * T)[0]
	var boar: BattleSim.Fighter = sim.spawn(1, "wild_boar", 6 * T, 5 * T)[0]
	var bonus := BattleAbilities.counter_pct("tank_destroyer", "tank")
	check(bonus > 0, "a counter bonus in classes.json")
	check_eq(BattleAbilities.outgoing_damage(sim, lion, bear, 100), 100 + bonus, "extra damage to a Tank")
	check_eq(BattleAbilities.outgoing_damage(sim, lion, boar, 100), 100, "none to another Tank Destroyer")


func test_tank_destroyers_go_for_tanks() -> void:
	var sim := _sim()
	var lion: BattleSim.Fighter = _ready_now(sim.spawn(0, "lion", 8 * T, 13 * T))[0]
	_ready_now(sim.spawn(1, "wild_boar", 8 * T, 9 * T))
	var bear: BattleSim.Fighter = _ready_now(sim.spawn(1, "brown_bear", 10 * T, 7 * T))[0]
	_run(sim, 0.1)
	check(lion.target == bear, "a Tank in reach comes first, even if something's closer")


func test_ranged_go_for_air() -> void:
	var sim := _sim()
	var squirrel: BattleSim.Fighter = _ready_now(sim.spawn(0, "gray_squirrel", 8 * T, 14 * T))[0]
	_ready_now(sim.spawn(1, "brown_bear", 8 * T, 10 * T))
	var falcon: BattleSim.Fighter = _ready_now(sim.spawn(1, "peregrine_falcon", 11 * T, 9 * T))[0]
	_run(sim, 0.1)
	check(squirrel.target == falcon, "Air in reach comes first")


func test_animals_stick_to_their_target() -> void:
	var sim := _sim()
	var bear: BattleSim.Fighter = _ready_now(sim.spawn(0, "brown_bear", 8 * T, 15 * T))[0]
	var raccoon: BattleSim.Fighter = _ready_now(sim.spawn(1, "raccoon", 8 * T, 7 * T))[0]
	# The enemies hold still, so only the bear's choice changes.
	sim.stun(raccoon, 200)
	_run(sim, 0.1)
	check(bear.target == raccoon, "the bear heads for the raccoon")
	var squirrel: BattleSim.Fighter = _ready_now(sim.spawn(1, "gray_squirrel", 11 * T, 8 * T))[0]
	sim.stun(squirrel, 200)
	_run(sim, 0.5)
	check(bear.target == raccoon, "it doesn't switch for one only a little closer")
	var boar: BattleSim.Fighter = _ready_now(sim.spawn(1, "wild_boar", 8 * T, 11 * T))[0]
	sim.stun(boar, 200)
	_run(sim, 0.5)
	check(bear.target == boar, "it does for one much closer")


func test_burrowers_pop_up_behind_the_enemy() -> void:
	var sim := _sim()
	var fox: BattleSim.Fighter = _ready_now(sim.spawn(0, "red_fox", 4 * T, 12 * T))[0]
	var bear: BattleSim.Fighter = _ready_now(sim.spawn(1, "brown_bear", 4 * T, 8 * T))[0]
	var squirrel: BattleSim.Fighter = _ready_now(sim.spawn(1, "gray_squirrel", 10 * T, 3 * T))[0]
	bear.stun = 9999
	squirrel.stun = 9999
	check(not sim.can_target(bear, fox), "underground, it can't be hit")
	var emerged := false
	for i in 20 * sim.tps:
		sim.step()
		if not fox.memory.get("burrowing", true):
			emerged = true
			break
	check(emerged, "it comes up")
	check(fox.y < 5 * T, "behind the enemy's last row (at %.1f tiles)" % (fox.y / float(T)))


func test_splash_stun_and_slow() -> void:
	var sim := _sim()
	var seal: BattleSim.Fighter = sim.spawn(0, "harbor_seal", 8 * T, 12 * T)[0]
	var target: BattleSim.Fighter = sim.spawn(1, "brown_bear", 8 * T, 10 * T)[0]
	var beside: BattleSim.Fighter = sim.spawn(1, "wild_boar", 9 * T, 10 * T)[0]
	var before := beside.hp
	BattleAbilities.after_hit(sim, seal, target, 100)
	check(beside.hp < before, "Splash hits the one beside it too")
	var gorilla: BattleSim.Fighter = sim.spawn(0, "mountain_gorilla", 6 * T, 12 * T)[0]
	for i in int(GameData.traits.stun.every):
		BattleAbilities.after_hit(sim, gorilla, target, 10)
	check(target.stun > 0, "Stun: every few hits freeze the target")
	var panda: BattleSim.Fighter = sim.spawn(0, "red_panda", 4 * T, 12 * T)[0]
	BattleAbilities.after_hit(sim, panda, beside, 10)
	check(beside.slow > 0 and beside.slow_pct == int(GameData.traits.slow.pct), "Slow slows")


func test_swarms_bring_at_most_two() -> void:
	var sim := _sim()
	check_eq(sim.spawn(0, "wolf_pack", 8 * T, 15 * T).size(), int(GameData.class_rules.swarm_max), "three wolves on the card, two on the field")


# --- Ranger tools ----------------------------------------------------------

func _use(sim: BattleSim, tool_id: String, x: int, y: int) -> void:
	var card := GameData.get_card(tool_id)
	ToolEffects.use(sim, 0, card, GameData.start_level(card.rarity), x, y)


func test_net_stuns() -> void:
	var sim := _sim()
	var bear: BattleSim.Fighter = sim.spawn(1, "brown_bear", 8 * T, 6 * T)[0]
	_use(sim, "net", 8 * T, 6 * T)
	check(bear.stun > 0, "stuck in the net")
	check(bear.hp < bear.max_hp, "and slightly hurt")


func test_air_horn_damages_and_knocks_back() -> void:
	var sim := _sim()
	var rat: BattleSim.Fighter = sim.spawn(1, "gray_squirrel", 8 * T, 6 * T)[0]
	var bear: BattleSim.Fighter = sim.spawn(1, "brown_bear", 8 * T + 800, 6 * T)[0]
	var ally: BattleSim.Fighter = sim.spawn(0, "brown_bear", 8 * T - 800, 6 * T)[0]
	rat.hp = 1  # nearly beaten: the blast finishes it off
	_use(sim, "air_horn", 8 * T, 6 * T)
	check(not rat.alive, "a nearly beaten squirrel can't take the blast")
	check(bear.hp < bear.max_hp and bear.x > 8 * T + 800, "the bear is hurt and pushed back")
	check_eq(ally.hp, ally.max_hp, "your own animals aren't hurt")


func test_medkit_heals_allies() -> void:
	var sim := _sim()
	var bear: BattleSim.Fighter = sim.spawn(0, "brown_bear", 8 * T, 15 * T)[0]
	bear.hp = 100
	_use(sim, "medkit", 8 * T, 15 * T)
	var heal := int(GameData.get_card("medkit").stats.heal)
	check_eq(bear.hp, 100 + heal, "healed by the Medkit's amount")


func test_food_bait_lures_enemies() -> void:
	var sim := _sim()
	var boar: BattleSim.Fighter = _ready_now(sim.spawn(1, "wild_boar", 4 * T, 8 * T))[0]
	_ready_now(sim.spawn(0, "red_fox", 12 * T, 16 * T))
	_use(sim, "food_bait", 5 * T, 10 * T)
	_run(sim, 1.0)
	check(boar.target != null and boar.target.kind == "bait", "the boar goes for the snack")


func test_tranq_dart_puts_the_closest_to_sleep() -> void:
	var sim := _sim()
	var near: BattleSim.Fighter = sim.spawn(1, "brown_bear", 8 * T, 6 * T)[0]
	var far: BattleSim.Fighter = sim.spawn(1, "black_rhino", 12 * T, 6 * T)[0]
	_use(sim, "tranq_dart", 8 * T, 6 * T)
	check(near.stun > 0, "closest is asleep")
	check_eq(far.stun, 0, "only one target")
