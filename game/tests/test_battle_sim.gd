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
	check_eq(BattleSim.WIDTH, 16 * T, "16 tiles wide")
	check_eq(BattleSim.HEIGHT, 20 * T, "20 tiles long")
	check(BattleSim.on_own_half(0, 15 * T) and not BattleSim.on_own_half(0, 5 * T), "team 0 has the near half")
	check(BattleSim.on_own_half(1, 5 * T) and not BattleSim.on_own_half(1, 15 * T), "team 1 has the far half")


func test_nothing_to_fight_means_standing_still() -> void:
	var sim := _sim()
	var fox: BattleSim.Fighter = _ready_now(sim.spawn(0, "red_fox", 8 * T, 15 * T))[0]
	_run(sim, 3)
	check_eq(Vector2i(fox.x, fox.y), Vector2i(8 * T, 15 * T), "no enemies, no walking")


func test_animals_find_the_nearest_enemy_and_fight() -> void:
	var sim := _sim()
	var bear: BattleSim.Fighter = _ready_now(sim.spawn(0, "brown_bear", 8 * T, 15 * T))[0]
	var near: BattleSim.Fighter = _ready_now(sim.spawn(1, "red_fox", 3 * T, 6 * T))[0]
	var far: BattleSim.Fighter = _ready_now(sim.spawn(1, "raccoon", 15 * T, 1 * T))[0]
	_run(sim, 0.2)
	check(bear.target == near, "the bear goes for the closer fox")
	_run(sim, 15)
	check(not near.alive, "and beats it")
	check(bear.target == far or not far.alive, "then goes after the raccoon")


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
		sim.spawn(1, "american_bison", (3 + 5 * i) * T, 2 * T)
	for i in 30 * sim.tps:
		sim.step()
		for f in sim.fighters:
			if f.x < 0 or f.x > BattleSim.WIDTH or f.y < 0 or f.y > BattleSim.HEIGHT:
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
		for id in ["brown_bear", "sewer_rats", "peregrine_falcon"]:
			sim.spawn(1, id, 8 * T, 6 * T)
		_run(sim, 30)
		results.append(sim.checksum())
	check_eq(results[0], results[1], "identical fights from identical starts")


func test_a_clone_plays_out_the_same() -> void:
	var sim := _sim(5)
	sim.spawn(0, "lion", 6 * T, 14 * T)
	sim.spawn(0, "cheetah", 10 * T, 14 * T)
	sim.spawn(1, "tiger", 8 * T, 6 * T)
	_run(sim, 2)
	var copy := sim.clone()
	_run(sim, 10)
	_run(copy, 10)
	check_eq(copy.checksum(), sim.checksum(), "the copy matches the original")


func test_clear_units_empties_the_field() -> void:
	var sim := _sim()
	sim.spawn(0, "sewer_rats", 8 * T, 15 * T)
	sim.make_bait(1, 8 * T, 5 * T, 100, 100, 3 * T)
	sim.clear_units()
	check_eq(sim.fighters.size(), 0, "nothing left")


# --- Abilities -------------------------------------------------------------

func test_shield_absorbs_damage() -> void:
	borrow_later_animals()
	var sim := _sim()
	var turtle: BattleSim.Fighter = sim.spawn(0, "snapping_turtle", 8 * T, 15 * T)[0]
	sim.deal_damage(turtle, 200, null)
	check_eq(turtle.hp, turtle.max_hp, "shell took it")
	sim.deal_damage(turtle, 200, null)
	check_eq(turtle.hp, turtle.max_hp - 100, "shell broke after 300")


func test_poison_keeps_hurting() -> void:
	borrow_later_animals()
	var sim := _sim()
	var snake: BattleSim.Fighter = sim.spawn(0, "rattlesnake", 8 * T, 12 * T)[0]
	var badger: BattleSim.Fighter = sim.spawn(1, "honey_badger", 8 * T, 12 * T + 900)[0]
	var bear: BattleSim.Fighter = sim.spawn(1, "brown_bear", 8 * T, 12 * T - 900)[0]
	BattleAbilities.after_hit(sim, snake, bear, 10)
	BattleAbilities.after_hit(sim, snake, badger, 10)
	check(bear.poison > 0, "bear poisoned")
	check_eq(badger.poison, 0, "honey badger is fearless")
	var before := bear.hp
	_run(sim, 1)
	check(bear.hp < before, "poison hurts over time")


func test_opossum_plays_dead() -> void:
	borrow_later_animals()
	var sim := _sim()
	var possum: BattleSim.Fighter = sim.spawn(0, "opossum", 8 * T, 15 * T)[0]
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
	var wolves := sim.spawn(0, "wolf_pack", 8 * T, 15 * T)
	var dummy: BattleSim.Fighter = sim.spawn(1, "brown_bear", 8 * T, 5 * T)[0]
	var together := BattleAbilities.outgoing_damage(sim, wolves[0], dummy, 100)
	wolves[1].alive = false
	wolves[2].alive = false
	var alone := BattleAbilities.outgoing_damage(sim, wolves[0], dummy, 100)
	check(together > 100, "packmates nearby: a bonus")
	check_eq(alone, 100, "alone: no bonus")


func test_hippo_is_fiercer_on_its_own_half() -> void:
	var sim := _sim()
	var hippo: BattleSim.Fighter = sim.spawn(0, "hippopotamus", 8 * T, 15 * T)[0]
	var dummy: BattleSim.Fighter = sim.spawn(1, "brown_bear", 8 * T, 5 * T)[0]
	var home := BattleAbilities.outgoing_damage(sim, hippo, dummy, 100)
	hippo.y = 5 * T
	var away := BattleAbilities.outgoing_damage(sim, hippo, dummy, 100)
	check(home > away and away == 100, "a bonus at home only")


func test_bison_shoves_animals_aside() -> void:
	var sim := _sim()
	var bison: BattleSim.Fighter = _ready_now(sim.spawn(0, "american_bison", 8 * T, 16 * T))[0]
	var target: BattleSim.Fighter = _ready_now(sim.spawn(1, "brown_bear", 8 * T, 4 * T))[0]
	var in_the_way: BattleSim.Fighter = _ready_now(sim.spawn(1, "sewer_rats", 8 * T, 12 * T))[0]
	var start := Vector2(in_the_way.x, in_the_way.y)
	bison.target = target
	BattleAbilities.on_moved(sim, bison)
	check_eq(Vector2(in_the_way.x, in_the_way.y), start, "too far away to shove")
	in_the_way.x = bison.x
	in_the_way.y = bison.y - bison.radius
	BattleAbilities.on_moved(sim, bison)
	check(in_the_way.y < bison.y - bison.radius, "shoved out of the way")
	check_eq(target.y, 4 * T, "but not its target")


func test_stealth_until_first_attack() -> void:
	var sim := _sim()
	var leopard: BattleSim.Fighter = sim.spawn(0, "amur_leopard", 8 * T, 15 * T)[0]
	var bear: BattleSim.Fighter = sim.spawn(1, "brown_bear", 8 * T, 5 * T)[0]
	check(not sim.can_target(bear, leopard), "hidden")
	leopard.revealed = 10
	check(sim.can_target(bear, leopard), "a flare reveals it")


func test_burrower_is_untargetable_then_emerges() -> void:
	borrow_later_animals()
	var sim := _sim()
	var ferret: BattleSim.Fighter = _ready_now(sim.spawn(0, "black_footed_ferret", 4 * T, 16 * T))[0]
	var bear: BattleSim.Fighter = _ready_now(sim.spawn(1, "brown_bear", 4 * T, 4 * T))[0]
	check(not sim.can_target(bear, ferret), "underground")
	_run(sim, 20)
	check(not ferret.memory.get("burrowing", true) or not ferret.alive, "popped up at the enemy")


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
	var rat: BattleSim.Fighter = sim.spawn(1, "sewer_rats", 8 * T, 6 * T)[0]
	var bear: BattleSim.Fighter = sim.spawn(1, "brown_bear", 8 * T + 800, 6 * T)[0]
	var ally: BattleSim.Fighter = sim.spawn(0, "brown_bear", 8 * T - 800, 6 * T)[0]
	_use(sim, "air_horn", 8 * T, 6 * T)
	check(not rat.alive, "rats can't take the blast")
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
	borrow_later_animals()
	var sim := _sim()
	var near: BattleSim.Fighter = sim.spawn(1, "brown_bear", 8 * T, 6 * T)[0]
	var far: BattleSim.Fighter = sim.spawn(1, "moose", 12 * T, 6 * T)[0]
	_use(sim, "tranq_dart", 8 * T, 6 * T)
	check(near.stun > 0, "closest is asleep")
	check_eq(far.stun, 0, "only one target")
