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
