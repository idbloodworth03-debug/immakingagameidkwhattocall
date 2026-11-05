extends TestCase
## Every animal's own attack style (data/styles.json, BattleStyles): each
## does what its card line says, in the fight itself.

const T := BattleSim.TILE


## A fight with no luck in the hits, so numbers can be checked exactly.
func _sim() -> BattleSim:
	var rules: Dictionary = GameData.battle_rules.duplicate(true)
	rules.damage_variance_pct = 0
	return BattleSim.new([{}, {}], 1, rules)


## One animal (not its whole squad) at (x, y) tiles, ready to fight.
func _one(sim: BattleSim, team: int, id: String, x: float, y: float) -> BattleSim.Fighter:
	var f: BattleSim.Fighter = sim.spawn_units(team, id, 1, roundi(x * T), roundi(y * T))[0]
	f.deploy_ticks = 0
	return f


func _run(sim: BattleSim, seconds: float) -> void:
	for i in roundi(seconds * sim.tps):
		sim.step()


func _hits_from(sim: BattleSim, f: BattleSim.Fighter, seconds: float) -> int:
	var count := 0
	for i in roundi(seconds * sim.tps):
		sim.step()
		for e in sim.take_events():
			if e.type == "hit" and int(e.from) == f.uid:
				count += 1
	return count


func test_every_animal_has_a_style_and_a_short_line() -> void:
	for id in GameData.card_order:
		if GameData.is_tool(id) or not GameData.styles.has(id):
			continue
		var line := GameData.style_line(id)
		check(line != "", "%s has a line" % id)
		check(line.split(" ", false).size() <= 8, "%s: '%s' is 8 words or fewer" % [id, line])
		check(BattleStyles.KINDS.has(String(GameData.styles[id].kind)), "%s: a known style" % id)
	for id in ["brown_bear", "snapping_turtle", "giant_panda", "hippopotamus", "asian_elephant", "black_rhino", "yeti"]:
		check(GameData.styles.has(id), "%s (Tank) has its style" % id)


# --- Tanks ---------------------------------------------------------------------

func test_brown_bear_swipes_two_at_once() -> void:
	var sim := _sim()
	var bear := _one(sim, 0, "brown_bear", 8, 10)
	var a := _one(sim, 1, "wild_boar", 8, 8.9)
	var b := _one(sim, 1, "wild_boar", 9.1, 9.2)
	a.stun = 9999
	b.stun = 9999
	var a_hp := a.hp
	var b_hp := b.hp
	bear.target = a
	sim.attack(bear, a)
	check(a.hp < a_hp, "the first one is hit")
	check(b.hp < b_hp, "the one beside it is swiped too")
	var first := a_hp - a.hp
	var second := b_hp - b.hp
	check(absi(second - first * int(GameData.styles.brown_bear.pct) / 100) <= 2, "for %d%% (%d of %d)" % [GameData.styles.brown_bear.pct, second, first])
	var far := _one(sim, 1, "wild_boar", 14, 10)
	far.stun = 9999
	var far_hp := far.hp
	sim.attack(bear, a)
	check_eq(far.hp, far_hp, "not one out of reach")


func test_snapping_turtle_hides_in_its_shell() -> void:
	var sim := _sim()
	var turtle := _one(sim, 0, "snapping_turtle", 8, 10)
	var boar := _one(sim, 1, "wild_boar", 8, 9)
	boar.stun = 9999
	sim.deal_damage(turtle, turtle.max_hp * 65 / 100, boar)
	check(int(turtle.memory.get("shell", 0)) > 0, "hurt below 40%: it hides")
	var before := turtle.hp
	sim.deal_damage(turtle, 400, boar)
	check_eq(before - turtle.hp, 400 * int(GameData.styles.snapping_turtle.taken_pct) / 100, "takes only a quarter in its shell")
	turtle.target = boar
	check_eq(_hits_from(sim, turtle, 2.0), 0, "and doesn't fight while hidden")
	_run(sim, 1.2)
	check_eq(int(turtle.memory.get("shell", 0)), 0, "comes out after 3 seconds")
	sim.deal_damage(turtle, 50, boar)
	check_eq(int(turtle.memory.get("shell", 0)), 0, "and can't hide again right away")


func test_giant_panda_sits_for_a_bamboo_snack() -> void:
	var sim := _sim()
	var panda := _one(sim, 0, "giant_panda", 8, 10)
	var boar := _one(sim, 1, "wild_boar", 8, 9)
	boar.stun = 9999
	sim.deal_damage(panda, panda.max_hp * 60 / 100, boar)
	check(int(panda.memory.get("snack", 0)) > 0, "at half health it sits down to munch")
	var low := panda.hp
	panda.target = boar
	check_eq(_hits_from(sim, panda, 1.9), 0, "no fighting while it eats")
	_run(sim, 0.1)
	var healed := panda.hp - low
	check_eq(healed, panda.max_hp * int(GameData.styles.giant_panda.heal_pct) / 100, "heals 35% of its health")
	sim.deal_damage(panda, panda.max_hp * 40 / 100, boar)
	check_eq(int(panda.memory.get("snack", 0)), 0, "only once a fight")


func test_hippopotamus_bites_back() -> void:
	var sim := _sim()
	var hippo := _one(sim, 0, "hippopotamus", 8, 10)
	var boar := _one(sim, 1, "wild_boar", 8, 9)
	var squirrel := _one(sim, 1, "gray_squirrel", 8, 5)
	var boar_hp := boar.hp
	var hippo_hp := hippo.hp
	sim.attack(boar, hippo)
	var taken := hippo_hp - hippo.hp
	check_eq(boar_hp - boar.hp, taken * int(GameData.styles.hippopotamus.pct) / 100, "a quarter of a bite comes back")
	var squirrel_hp := squirrel.hp
	sim.attack(squirrel, hippo)
	check_eq(squirrel.hp, squirrel_hp, "shots don't bounce back")


func test_asian_elephant_shields_who_is_behind_it() -> void:
	var sim := _sim()
	var elephant := _one(sim, 0, "asian_elephant", 8, 10)
	var behind := _one(sim, 0, "gray_squirrel", 8, 11.2)
	var beside := _one(sim, 0, "gray_squirrel", 11, 10.5)
	var shooter := _one(sim, 1, "gray_squirrel", 8, 4)
	var elephant_hp := elephant.hp
	var behind_hp := behind.hp
	sim.attack(shooter, behind)
	check_eq(behind.hp, behind_hp, "the one right behind it isn't hit")
	check(elephant.hp < elephant_hp, "the Elephant takes the shot")
	var beside_hp := beside.hp
	sim.attack(shooter, beside)
	check(beside.hp < beside_hp, "one off to the side isn't covered")
	var boar := _one(sim, 1, "wild_boar", 8, 12.2)
	behind_hp = behind.hp
	sim.attack(boar, behind)
	check(behind.hp < behind_hp, "a bite isn't a shot: no shield")


func test_black_rhino_charges_through_the_line() -> void:
	var sim := _sim()
	var rhino := _one(sim, 0, "black_rhino", 8, 14)
	var line := []
	for x in [6.5, 8.0, 9.5]:
		line.append(_one(sim, 1, "gray_squirrel", x, 10))
	var start_y := rhino.y
	var xs := line.map(func(f): return f.x)
	var knocked := false
	for i in 4 * sim.tps:
		sim.step()
		if int(rhino.memory.get("charge_state", 0)) == 2:
			break
	check_eq(int(rhino.memory.get("charge_state", 0)), 2, "it charged")
	check(start_y - rhino.y >= 4 * T, "straight through, %.1f tiles" % ((start_y - rhino.y) / float(T)))
	for i in line.size():
		if line[i].x != xs[i] or line[i].hp < line[i].max_hp:
			knocked = true
	check(knocked, "knocking the line aside")
	check(line.any(func(f): return f.hp < f.max_hp), "and hurting them")
	check(BattleStyles.act(sim, rhino) == false, "once a fight")


func test_yeti_pounds_every_third_hit() -> void:
	var sim := _sim()
	var yeti := _one(sim, 0, "yeti", 8, 10)
	var target := _one(sim, 1, "brown_bear", 8, 8.8)
	var near := _one(sim, 1, "wild_boar", 9.4, 9.4)
	target.stun = 9999
	near.stun = 9999
	var near_hp := near.hp
	sim.attack(yeti, target)
	sim.attack(yeti, target)
	check_eq(near.hp, near_hp, "not on the first two")
	var where := Vector2(near.x, near.y)
	sim.attack(yeti, target)
	check(near.hp < near_hp, "the third: everyone around is hit")
	check(Vector2(near.x, near.y).distance_to(Vector2(yeti.x, yeti.y)) > where.distance_to(Vector2(yeti.x, yeti.y)) + 500, "and knocked back")


# --- Tank Destroyers --------------------------------------------------------------

func test_wild_boar_charges_a_tank_with_a_huge_first_hit() -> void:
	var sim := _sim()
	var boar := _one(sim, 0, "wild_boar", 8, 14)
	var squirrel := _one(sim, 1, "gray_squirrel", 8, 12)
	var bear := _one(sim, 1, "brown_bear", 8, 8)
	squirrel.stun = 9999
	bear.stun = 9999
	_run(sim, 0.1)
	check(boar.target == bear, "it goes for the Tank, not the nearer squirrel")
	check(BattleStyles.speed_bonus(sim, boar) > 0, "sprinting at it")
	var hp := bear.hp
	sim.attack(boar, bear)
	var first := hp - bear.hp
	hp = bear.hp
	sim.attack(boar, bear)
	var second := hp - bear.hp
	check(first >= second * (int(GameData.styles.wild_boar.first_pct) - 10) / 100, "the first hit is huge (%d, then %d)" % [first, second])
	check_eq(BattleStyles.speed_bonus(sim, boar), 0, "no sprint once it's hit that Tank")


func test_wolf_pack_bites_harder_together() -> void:
	var sim := _sim()
	var a := _one(sim, 0, "wolf_pack", 7.6, 10)
	var b := _one(sim, 0, "wolf_pack", 8.4, 10)
	var bear := _one(sim, 1, "brown_bear", 8, 9)
	bear.stun = 9999
	var hp := bear.hp
	sim.attack(a, bear)
	var alone := hp - bear.hp
	b.target = bear
	hp = bear.hp
	sim.attack(a, bear)
	var together := hp - bear.hp
	check(absi(together - alone * (100 + int(GameData.styles.wolf_pack.pct)) / 100) <= 40, "40%% more with its packmate on the same one (%d, then %d)" % [alone, together])


func test_lion_roars_its_tank_destroyers_on() -> void:
	var sim := _sim()
	var lion := _one(sim, 0, "lion", 8, 11)
	var boar := _one(sim, 0, "wild_boar", 9, 11)
	var far_boar := _one(sim, 0, "wild_boar", 2, 18)
	var bear := _one(sim, 1, "brown_bear", 8, 9.6)
	sim.step()
	check(int(boar.memory.get("roared", -1)) > sim.tick, "a Tank Destroyer beside it is roused")
	check(BattleStyles.haste_pct(sim, boar) == int(GameData.styles.lion.haste_pct), "and attacks faster")
	check_eq(BattleStyles.haste_pct(sim, far_boar), 0, "not one far away")
	check(BattleStyles.haste_pct(sim, lion) > 0, "the Lion too")
	_run(sim, float(GameData.styles.lion.seconds) + 0.1)
	check_eq(BattleStyles.haste_pct(sim, boar), 0, "for a few seconds")


func test_honey_badger_goes_for_the_biggest_and_stands_firm() -> void:
	var sim := _sim()
	var badger := _one(sim, 0, "honey_badger", 8, 12)
	var small := _one(sim, 1, "gray_squirrel", 8, 11)
	var big := _one(sim, 1, "asian_elephant", 10, 9.5)
	small.stun = 9999
	big.stun = 9999
	sim.step()
	check(badger.target == big, "the Elephant, not the squirrel right in front of it")
	var where := Vector2i(badger.x, badger.y)
	sim.knock_back(badger, badger.x, badger.y - T, T)
	check_eq(Vector2i(badger.x, badger.y), where, "nothing knocks it back")


func test_tiger_circles_and_pounces_from_the_side() -> void:
	var sim := _sim()
	var tiger := _one(sim, 0, "tiger", 8, 15)
	var bear := _one(sim, 1, "brown_bear", 8, 9)
	bear.stun = 9999
	var widest := 0
	var hp := bear.hp
	var first := 0
	for i in 6 * sim.tps:
		sim.step()
		widest = maxi(widest, absi(tiger.x - bear.x))
		if bear.hp < hp:
			first = hp - bear.hp
			break
	check(widest >= T, "it swings out to the side (%.1f tiles)" % (widest / float(T)))
	check(absi(tiger.y - bear.y) < absi(tiger.x - bear.x) + T / 2, "and strikes from the side")
	hp = bear.hp
	sim.attack(tiger, bear)
	var second := hp - bear.hp
	check(first >= second * (int(GameData.styles.tiger.first_pct) - 10) / 100, "a big first strike (%d, then %d)" % [first, second])


func test_komodo_poisons_then_moves_on() -> void:
	var sim := _sim()
	var komodo := _one(sim, 0, "komodo_dragon", 8, 11)
	var a := _one(sim, 1, "brown_bear", 7.6, 10)
	var b := _one(sim, 1, "brown_bear", 9.4, 10)
	a.stun = 9999
	b.stun = 9999
	komodo.target = a
	sim.attack(komodo, a)
	check(a.poison > 0, "its bite poisons")
	var hp := a.hp
	_run(sim, 1.0)
	check(a.hp < hp, "and keeps hurting")
	check(komodo.target == b, "it's off to the one not poisoned yet")


func test_cerberus_bites_three_times() -> void:
	var sim := _sim()
	var cerberus := _one(sim, 0, "cerberus", 8, 11)
	var foes := [_one(sim, 1, "brown_bear", 7.2, 10.1), _one(sim, 1, "brown_bear", 8.0, 9.7), _one(sim, 1, "brown_bear", 8.8, 10.1)]
	for f in foes:
		f.stun = 9999
	var before := foes.map(func(f): return f.hp)
	sim.attack(cerberus, foes[1])
	var bitten := 0
	for i in foes.size():
		if foes[i].hp < before[i]:
			bitten += 1
	check_eq(bitten, 3, "three heads, three enemies bitten")
	var sim2 := _sim()
	var alone := _one(sim2, 0, "cerberus", 8, 11)
	var one := _one(sim2, 1, "brown_bear", 8, 9.7)
	one.stun = 9999
	var events_before := sim2.events.size()
	sim2.attack(alone, one)
	var hits := sim2.events.slice(events_before).filter(func(e): return e.type == "hit" and int(e.to) == one.uid).size()
	check_eq(hits, 3, "alone, all three bites on the one")


# --- Ranged ---------------------------------------------------------------------

func test_gray_squirrel_fires_little_pinecones() -> void:
	var sim := _sim()
	var squirrel := _one(sim, 0, "gray_squirrel", 8, 14)
	var bear := _one(sim, 1, "brown_bear", 8, 9)
	bear.stun = 9999
	var start := sim.events.size()
	var hp := bear.hp
	sim.attack(squirrel, bear)
	var shots := sim.events.slice(start).filter(func(e): return e.type == "hit")
	check_eq(shots.size(), int(GameData.styles.gray_squirrel.pellets), "three pinecones a shot")
	check(shots.all(func(e): return bool(e.ranged)), "all of them thrown")
	var one_bite := BattleAbilities.outgoing_damage(sim, squirrel, bear, squirrel.damage)
	check(absi((hp - bear.hp) - one_bite) <= 3, "the same damage as one shot between them (%d vs %d)" % [hp - bear.hp, one_bite])


func test_striped_skunk_sprays_a_whole_group() -> void:
	var sim := _sim()
	var skunk := _one(sim, 0, "striped_skunk", 8, 12)
	check(skunk.attack_range <= roundi(float(GameData.styles.striped_skunk.range) * T), "a short spray")
	var target := _one(sim, 1, "wild_boar", 8, 10)
	var beside := _one(sim, 1, "wild_boar", 8.9, 10.1)
	var behind_it := _one(sim, 1, "wild_boar", 8, 15)
	for f in [target, beside, behind_it]:
		f.stun = 9999
	var hp := [beside.hp, behind_it.hp]
	sim.attack(skunk, target)
	check(beside.hp < hp[0], "the one beside its target gets it too")
	check_eq(behind_it.hp, hp[1], "not one behind the skunk")
	check(int(beside.memory.get("stink_until", -1)) > sim.tick, "and goes stinky")


func test_raccoon_lobs_at_the_back_ranks() -> void:
	var sim := _sim()
	var raccoon := _one(sim, 0, "raccoon", 8, 16)
	var front := _one(sim, 1, "brown_bear", 8, 12)
	var back := _one(sim, 1, "gray_squirrel", 8.5, 9.5)
	front.stun = 9999
	back.stun = 9999
	sim.step()
	check(raccoon.target == back, "over the bear in front, at the one at the back")


func test_king_cobra_snipes_from_far() -> void:
	var sim := _sim()
	var cobra := _one(sim, 0, "king_cobra", 8, 18)
	var squirrel := _one(sim, 0, "gray_squirrel", 9, 18)
	check(cobra.attack_range >= roundi(float(GameData.styles.king_cobra.range) * T), "10 tiles of reach")
	check(cobra.attack_range > squirrel.attack_range, "further than any other shooter")
	var bear := _one(sim, 1, "brown_bear", 8, 9)
	bear.stun = 9999
	check(sim.in_range(cobra, bear), "it reaches a bear 9 tiles off")
	check(not sim.in_range(squirrel, bear), "the squirrel doesn't")


func test_camel_charges_one_giant_spit() -> void:
	var sim := _sim()
	var camel := _one(sim, 0, "wild_bactrian_camel", 8, 13)
	var bear := _one(sim, 1, "brown_bear", 8, 9)
	bear.stun = 9999
	camel.target = bear
	camel.cooldown = 0
	var hp := bear.hp
	var charge := float(GameData.styles.wild_bactrian_camel.charge)
	_run(sim, charge - 0.2)
	check_eq(bear.hp, hp, "nothing while it charges up")
	check(int(camel.memory.get("spit_at", -1)) >= 0, "charging")
	_run(sim, 0.4)
	var spit := hp - bear.hp
	var bite := BattleAbilities.outgoing_damage(sim, camel, bear, camel.damage)
	check(spit >= bite * (int(GameData.styles.wild_bactrian_camel.spit_pct) - 10) / 100, "then one giant spit (%d, a bite is %d)" % [spit, bite])


func test_orangutan_fruit_bounces_on() -> void:
	var sim := _sim()
	var ape := _one(sim, 0, "sumatran_orangutan", 8, 15)
	var foes := [_one(sim, 1, "wild_boar", 8, 9), _one(sim, 1, "wild_boar", 9.6, 9.3), _one(sim, 1, "wild_boar", 11.0, 9.8)]
	for f in foes:
		f.stun = 9999
	var hp := foes.map(func(f): return f.hp)
	sim.attack(ape, foes[0])
	var hit := 0
	for i in foes.size():
		if foes[i].hp < hp[i]:
			hit += 1
	check_eq(hit, 3, "one fruit, three enemies")


func test_unicorn_beam_pierces_the_line() -> void:
	var sim := _sim()
	var unicorn := _one(sim, 0, "unicorn", 8, 16)
	var first := _one(sim, 1, "wild_boar", 8, 12)
	var second := _one(sim, 1, "wild_boar", 8.1, 10.5)
	var aside := _one(sim, 1, "wild_boar", 11, 11)
	for f in [first, second, aside]:
		f.stun = 9999
	var hp := [second.hp, aside.hp]
	sim.attack(unicorn, first)
	check(second.hp < hp[0], "the one behind its target in the line is hit too")
	check_eq(aside.hp, hp[1], "not one off to the side")


# --- Air ------------------------------------------------------------------------

func test_peregrine_falcon_dives_then_climbs() -> void:
	var sim := _sim()
	var falcon := _one(sim, 0, "peregrine_falcon", 8, 14)
	var boar := _one(sim, 1, "wild_boar", 8, 9)
	boar.stun = 9999
	falcon.target = boar
	check(BattleStyles.speed_bonus(sim, falcon) > 0, "diving at its prey, fast")
	var hp := boar.hp
	sim.attack(falcon, boar)
	var dive := hp - boar.hp
	var plain := BattleAbilities.outgoing_damage(sim, falcon, boar, falcon.damage)
	check(dive >= plain * (int(GameData.styles.peregrine_falcon.dive_pct) - 5) / 100, "a dive hits harder (%d, a plain bite %d)" % [dive, plain])
	var y := falcon.y
	sim.step()
	check(falcon.y > y, "then it climbs away")


func test_barn_owl_hunts_the_ranged() -> void:
	var sim := _sim()
	var owl := _one(sim, 0, "barn_owl", 8, 15)
	var front := _one(sim, 1, "wild_boar", 8, 12)
	var back := _one(sim, 1, "gray_squirrel", 8, 7)
	front.stun = 9999
	back.stun = 9999
	sim.step()
	check(owl.target == back, "past the boar, after the squirrel at the back")
	# Silent: the Ranged it hunts barely notice it.
	var hp := owl.hp
	sim.strike(back, owl, 100)
	check_eq(hp - owl.hp, int(GameData.styles.barn_owl.ranged_taken_pct), "Ranged hurt it less (of a 100 blow)")
	hp = owl.hp
	sim.strike(front, owl, 100)
	check_eq(hp - owl.hp, 100, "others as much as ever")


func test_harpy_eagle_carries_one_off() -> void:
	var sim := _sim()
	var harpy := _one(sim, 0, "harpy_eagle", 8, 11)
	var squirrel := _one(sim, 1, "gray_squirrel", 8, 10)
	var start := squirrel.y
	sim.attack(harpy, squirrel)
	check(squirrel.memory.has("carried_by"), "grabbed")
	for i in 5 * sim.tps:
		sim.step()
		if not squirrel.memory.has("carried_by"):
			break
	check(not squirrel.memory.has("carried_by"), "and dropped")
	check(squirrel.y - start >= 3 * T, "far back over the eagle's own side (%.1f tiles)" % ((squirrel.y - start) / float(T)))
	var bear := _one(sim, 1, "brown_bear", 9, 10)
	harpy.memory.grab_ready = 0
	sim.attack(harpy, bear)
	check(not bear.memory.has("carried_by"), "a bear is too big to carry")


func test_hyacinth_macaw_cracks_armor() -> void:
	var sim := _sim()
	var macaw := _one(sim, 0, "hyacinth_macaw", 8, 11)
	var hippo := _one(sim, 0, "hippopotamus", 9, 11)
	var bear := _one(sim, 1, "brown_bear", 8, 9.6)
	bear.stun = 9999
	var hp := bear.hp
	sim.attack(hippo, bear)
	var before := hp - bear.hp
	sim.attack(macaw, bear)
	hp = bear.hp
	sim.attack(hippo, bear)
	var after := hp - bear.hp
	check(absi(after - before * (100 + int(GameData.styles.hyacinth_macaw.pct)) / 100) <= 3, "everyone hits it 25%% harder (%d, then %d)" % [before, after])
	macaw.stun = 9999
	hippo.stun = 9999
	_run(sim, float(GameData.styles.hyacinth_macaw.seconds) + 0.1)
	hp = bear.hp
	sim.attack(hippo, bear)
	check(absi((hp - bear.hp) - before) <= 3, "for a few seconds")


func test_california_condor_grows_on_every_fall() -> void:
	var sim := _sim()
	var condor := _one(sim, 0, "california_condor", 8, 11)
	var bear := _one(sim, 1, "brown_bear", 8, 9.6)
	bear.stun = 9999
	var hp := bear.hp
	sim.attack(condor, bear)
	var before := hp - bear.hp
	for i in 3:
		var squirrel := _one(sim, 1, "gray_squirrel", 9, 10)
		sim.deal_damage(squirrel, squirrel.hp, null)
	var far := _one(sim, 1, "gray_squirrel", 1, 1)
	sim.deal_damage(far, far.hp, null)
	check_eq(int(condor.memory.get("feasts", 0)), 3, "three fell near it (not the one far off)")
	hp = bear.hp
	sim.attack(condor, bear)
	var after := hp - bear.hp
	check(after > before, "its bite grows (%d, then %d)" % [before, after])


func test_dragon_leaves_a_burning_line() -> void:
	var sim := _sim()
	var dragon := _one(sim, 0, "dragon", 8, 15)
	var boars := [_one(sim, 1, "wild_boar", 8, 10), _one(sim, 1, "wild_boar", 8, 8.5)]
	for b in boars:
		b.stun = 9999
	sim.step()
	check(sim.zones.any(func(z): return z.has("line")), "a fire-breath run lays a burning line")
	var hp := boars.map(func(b): return b.hp)
	_run(sim, 1.0)
	check(boars[0].hp < hp[0] and boars[1].hp < hp[1], "that burns the enemies along it")


# --- Specialists -------------------------------------------------------------------

## Steps until `done` says so (up to `seconds`); whether it did.
func _until(sim: BattleSim, seconds: float, done: Callable) -> bool:
	for i in roundi(seconds * sim.tps):
		sim.step()
		if done.call():
			return true
	return false


func test_red_fox_pops_up_by_the_ranged_and_digs_again() -> void:
	var sim := _sim()
	var fox := _one(sim, 0, "red_fox", 8, 15)
	var bear := _one(sim, 1, "brown_bear", 8, 10)
	var a := _one(sim, 1, "gray_squirrel", 4, 8)
	var b := _one(sim, 1, "gray_squirrel", 12, 8)
	for e in [bear, a, b]:
		e.stun = 99999
		e.max_hp = 99999
		e.hp = 99999
	check(fox.memory.get("burrowing", false), "it starts underground")
	check(_until(sim, 10.0, func(): return not fox.memory.get("burrowing", false)), "and comes up")
	var first: BattleSim.Fighter = a if BattleSim.dist(fox, a) < BattleSim.dist(fox, b) else b
	var other: BattleSim.Fighter = b if first == a else a
	check(BattleSim.dist(fox, first) <= 2 * T, "right by a squirrel (%.1f tiles)" % (BattleSim.dist(fox, first) / float(T)))
	sim.step()
	check(fox.target == first, "and goes for it, not the bear")
	check(_until(sim, 8.0, func(): return fox.memory.get("burrowing", false)), "after a few hits it digs down again")
	check(_until(sim, 10.0, func(): return not fox.memory.get("burrowing", false)), "and comes up again")
	check(BattleSim.dist(fox, other) <= 2 * T, "by the other squirrel this time")
	# Badly hurt before its hits are up, a fresh fox digs away too.
	var sim2 := _sim()
	var fox2 := _one(sim2, 0, "red_fox", 8, 8.5)
	fox2.memory.burrowing = false
	var near := _one(sim2, 1, "gray_squirrel", 8, 7.6)
	var far := _one(sim2, 1, "gray_squirrel", 13, 7.6)
	near.stun = 99999
	far.stun = 99999
	sim2.strike(near, fox2, fox2.max_hp * (100 - int(GameData.styles.red_fox.below_pct)) / 100 + 1)
	check(fox2.memory.get("burrowing", false), "badly hurt, it digs away")


func test_sunda_pangolin_flips_a_tank_then_curls_up() -> void:
	var sim := _sim()
	var pangolin := _one(sim, 0, "sunda_pangolin", 8, 15)
	var bear := _one(sim, 1, "brown_bear", 6, 10)
	var squirrel := _one(sim, 1, "gray_squirrel", 10, 7)
	squirrel.stun = 99999
	bear.max_hp = 99999
	bear.hp = 99999
	check(_until(sim, 10.0, func(): return not pangolin.memory.get("burrowing", false)), "it comes up")
	check(BattleSim.dist(pangolin, bear) <= T * 3 / 2, "under the bear (the Tank), not by the squirrel")
	check(bear.stun > 0 and int(bear.memory.get("flipped_until", -1)) > sim.tick, "the bear is flipped and stunned")
	check(bear.hp < 99999, "and hurt")
	# Hit: it curls into a ball, taking half.
	bear.stun = 99999
	var hp := pangolin.hp
	sim.strike(bear, pangolin, 100)
	check(int(pangolin.memory.get("ball", 0)) > 0, "hit, it curls into a ball")
	hp = pangolin.hp
	sim.strike(bear, pangolin, 100)
	check_eq(hp - pangolin.hp, int(GameData.styles.sunda_pangolin.taken_pct), "taking half")
	check(BattleStyles.act(sim, pangolin), "and not fighting while curled up")


func test_harbor_seal_belly_slides_through_a_line() -> void:
	var sim := _sim()
	var seal := _one(sim, 0, "harbor_seal", 8, 13)
	var line := [_one(sim, 1, "wild_boar", 8, 11.6), _one(sim, 1, "wild_boar", 8.2, 10.6)]
	for b in line:
		b.stun = 99999
	var hp := line.map(func(b): return b.hp)
	var start := seal.y
	sim.step()
	check(int(seal.memory.get("slide_left", 0)) > 0, "it starts a slide")
	_until(sim, 3.0, func(): return int(seal.memory.get("slide_left", 0)) <= 0)
	check(start - seal.y >= 2 * T, "a long slide (%.1f tiles)" % ((start - seal.y) / float(T)))
	check(line[0].hp < hp[0] and line[1].hp < hp[1], "hitting both it passed")
	check(BattleStyles.owns_trait(seal), "its slide is its splash")


func test_kraken_slams_and_drags_them_in() -> void:
	var sim := _sim()
	var kraken := _one(sim, 0, "kraken", 8, 12)
	var bear := _one(sim, 1, "brown_bear", 8, 10.6)
	var left := _one(sim, 1, "wild_boar", 6.2, 11.6)
	var right := _one(sim, 1, "wild_boar", 9.8, 11.6)
	var far := _one(sim, 1, "wild_boar", 8, 5)
	var all := [bear, left, right, far]
	var hp := all.map(func(e): return e.hp)
	var gaps := all.map(func(e): return BattleSim.dist(kraken, e))
	sim.attack(kraken, bear)
	check(bear.hp < hp[0] and left.hp < hp[1] and right.hp < hp[2], "three tentacles, three slammed")
	check_eq(far.hp, hp[3], "not one out of reach")
	check(BattleSim.dist(kraken, left) < gaps[1] and BattleSim.dist(kraken, right) < gaps[2], "dragged in toward it")


func test_electric_eel_lightning_chains_and_stuns() -> void:
	var sim := _sim()
	var eel := _one(sim, 0, "electric_eel", 8, 11)
	var bear := _one(sim, 1, "brown_bear", 8, 9.8)
	var chain := [_one(sim, 1, "wild_boar", 9.6, 9.4), _one(sim, 1, "wild_boar", 11.1, 9.4), _one(sim, 1, "wild_boar", 12.6, 9.4)]
	var far := _one(sim, 1, "wild_boar", 3, 4)
	sim.attack(eel, bear)
	check(bear.stun <= 0 and chain.all(func(e): return e.stun <= 0), "the first hit: no lightning yet")
	var hp := chain.map(func(e): return e.hp)
	sim.attack(eel, bear)
	check(bear.stun > 0 and chain.all(func(e): return e.stun > 0), "the second: lightning through all four, stunned")
	check(chain[0].hp < hp[0] and chain[2].hp < hp[2], "and hurt")
	check(far.stun <= 0, "not one far off")
	check(BattleStyles.owns_trait(eel), "its lightning is its stun")


func test_mountain_gorilla_chest_beat_stuns_all_around() -> void:
	var sim := _sim()
	var gorilla := _one(sim, 0, "mountain_gorilla", 8, 11)
	var around := [_one(sim, 1, "wild_boar", 8, 9.9), _one(sim, 1, "wild_boar", 6.6, 11), _one(sim, 1, "wild_boar", 9.6, 12)]
	var far := _one(sim, 1, "wild_boar", 8, 4)
	var hp := around.map(func(e): return e.hp)
	sim.step()
	check(int(gorilla.memory.get("beat", 0)) > 0, "it beats its chest")
	check(_until(sim, 1.5, func(): return around.all(func(e): return e.stun > 0)), "then everyone around is stunned")
	check(around.all(func(e): return e.hp < hp[around.find(e)]), "and hurt")
	check(far.stun <= 0, "not one far off")


func test_red_panda_stands_tall_and_slows_everyone_near() -> void:
	var sim := _sim()
	var panda := _one(sim, 0, "red_panda", 8, 11)
	var near := [_one(sim, 1, "wild_boar", 8, 9.5), _one(sim, 1, "wild_boar", 6, 11.5)]
	var far := _one(sim, 1, "wild_boar", 8, 3)
	sim.step()
	check(int(panda.memory.get("tall", 0)) > 0, "it rears up")
	check(near.all(func(e): return e.slow > 0 and e.slow_pct == int(GameData.styles.red_panda.pct)), "everyone near slows down")
	check(far.slow <= 0, "not one far off")


func test_sloth_zone_makes_everything_crawl() -> void:
	var sim := _sim()
	var sloth := _one(sim, 0, "pygmy_three_toed_sloth", 8, 11)
	var friend := _one(sim, 0, "brown_bear", 8.8, 12)
	var boar := _one(sim, 1, "wild_boar", 8, 9.5)
	var squirrel := _one(sim, 1, "gray_squirrel", 8, 4)
	var out := _one(sim, 0, "brown_bear", 2, 4)
	sim.step()
	var pct := int(GameData.styles.pygmy_three_toed_sloth.pct)
	var attack := int(GameData.styles.pygmy_three_toed_sloth.attack_pct)
	check(boar.slow > 0 and boar.slow_pct == pct, "an enemy in its zone moves slower")
	check_eq(BattleStyles.haste_pct(sim, boar), -attack, "and attacks slower")
	squirrel.target = friend
	check_eq(BattleStyles.haste_pct(sim, squirrel), -attack, "a shot at someone in the zone crawls too")
	squirrel.target = out
	check_eq(BattleStyles.haste_pct(sim, squirrel), 0, "a shot at someone outside doesn't")
	check_eq(BattleStyles.haste_pct(sim, friend), 0, "its own side isn't slowed")
