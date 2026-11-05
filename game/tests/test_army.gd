extends TestCase
## Armies in formation (scripts/battle/battle_army.gd): squads, places in
## the formation, the march in step, volleys, the clash, the charge, ranks
## closing up and the War Horn.

const T := BattleSim.TILE


## A match laid out with these armies ("id*squads" each), ready to fight.
func _armies(a: Array, b: Array, seed_value := 1) -> DraftMatch:
	var m := DraftMatch.new(seed_value)
	for team in 2:
		var herd := []
		for spec in [a, b][team]:
			var parts := String(spec).split("*")
			herd.append({"id": parts[0], "stars": 1, "squads": int(parts[1]) if parts.size() > 1 else 1})
		m.herds[team] = herd
		m.picks_left[team] = 0
		m.picks_made[team] = []
	m._lay_out_herds()
	m.set_ready(0)
	m.set_ready(1)
	return m


func _sample() -> DraftMatch:
	return _armies(["brown_bear*2", "wild_boar*2", "gray_squirrel*2", "peregrine_falcon", "red_fox"],
		["snapping_turtle*2", "lion", "striped_skunk*2", "barn_owl", "electric_eel"])


func test_squads_by_class() -> void:
	var squads: Dictionary = GameData.class_rules.squads
	for id in ["brown_bear", "wild_boar", "gray_squirrel", "peregrine_falcon", "red_fox", "dragon"]:
		var cls := GameData.class_of(id)
		var want := int(squads.mythic.units) if GameData.cards[id].rarity == "mythic" else int(squads[cls].units)
		check_eq(DraftMatch.squad_units(id), want, "%s comes %d to a squad" % [id, want])
	var m := _armies(["wild_boar", "gray_squirrel"], ["brown_bear"])
	var boars: Array = m.sim.units(0).filter(func(f): return f.card.id == "wild_boar")
	var one := m.sim._make_unit(0, GameData.cards.wild_boar, m.sim.level_of(0, "wild_boar"), 0, 0)
	check_eq(boars[0].max_hp, one.max_hp * int(squads.tank_destroyer.hp_pct) / 100, "each one has its share of the card's health")
	check(boars[0].memory.group == boars[1].memory.group, "a squad is one group")


func test_the_formation() -> void:
	var m := _armies(["gray_squirrel*2", "brown_bear*3", "wild_boar", "red_fox", "electric_eel", "peregrine_falcon", "yeti"], ["brown_bear"])
	var by_rank := {}
	for f in m.sim.units(0):
		var rank: String = f.memory.rank
		if not by_rank.has(rank):
			by_rank[rank] = []
		by_rank[rank].append(f)
	# Ranks one behind another, the Tank wall in front.
	var wall_y: int = by_rank.wall.map(func(f): return f.y).max()
	check(wall_y < by_rank.td.map(func(f): return f.y).min(), "the Tank wall in front of the Tank Destroyers")
	check(by_rank.td.map(func(f): return f.y).max() < by_rank.ranged.map(func(f): return f.y).min(), "Ranged at the back")
	# The wall: one line, shoulder to shoulder, the Mythic hero in the middle.
	var walls: Array = by_rank.wall.filter(func(f): return not f.memory.flank)
	check(walls.all(func(f): return f.y == walls[0].y), "the wall is one straight line")
	var middle_x := m.sim.width / 2
	var yeti: BattleSim.Fighter = walls.filter(func(f): return f.card.id == "yeti")[0]
	check(absi(yeti.x - middle_x) < T, "the hero stands in the middle")
	# Specialists on the flanks: past both ends of their rank's line.
	var fox: BattleSim.Fighter = m.sim.units(0).filter(func(f): return f.card.id == "red_fox")[0]
	var xs: Array = walls.map(func(f): return f.x)
	check(fox.x > xs.max() or fox.x < xs.min(), "the Red Fox (Burrow) on the wall's flank")
	var eel: BattleSim.Fighter = m.sim.units(0).filter(func(f): return f.card.id == "electric_eel")[0]
	var td_xs: Array = by_rank.td.filter(func(f): return not f.memory.flank).map(func(f): return f.x)
	check(eel.x > td_xs.max() or eel.x < td_xs.min(), "the Electric Eel (Stun) on the Tank Destroyers' flank")
	# The ranged lines are even: the same gap between neighbours.
	var ranged: Array = by_rank.ranged.filter(func(f): return f.y == by_rank.ranged[0].y)
	ranged.sort_custom(func(a, b): return a.x < b.x)
	for i in range(1, ranged.size() - 1):
		check_eq(ranged[i + 1].x - ranged[i].x, ranged[1].x - ranged[0].x, "evenly spaced")


func test_marching_in_step() -> void:
	var m := _sample()
	var army: BattleArmy = m.sim.army
	var start := [army.front[0], army.front[1]]
	var worst := 0
	for i in 20:
		m.step()
		for f in m.sim.units(0) + m.sim.units(1):
			if f.memory.has("slot") and not f.memory.get("free", false):
				var p := army.place_of(f)
				worst = maxi(worst, BattleSim.isqrt((p.x - f.x) * (p.x - f.x) + (p.y - f.y) * (p.y - f.y)))
	check_eq(start[0] - army.front[0], 20 * army.pace, "the front marches at one pace")
	check_eq(army.front[1] - start[1], 20 * army.pace, "both fronts do")
	check(worst <= T / 4, "everyone keeps their place on the march (at most %.2f tiles off)" % (worst / 1000.0))
	check_eq(army.marched[0], 20 * army.pace, "and the army knows how far it has come")


func test_volley_clash_charge() -> void:
	var m := _sample()
	var army: BattleArmy = m.sim.army
	var hit_ticks := {}
	var events := []
	while m.phase == "fight" and m.fight_tick < 20 * m.sim.tps:
		m.step()
		for e in m.sim.take_events():
			e.tick = m.sim.tick
			events.append(e)
	var first := {}
	for e in events:
		if not first.has(e.type):
			first[e.type] = int(e.tick)
		if e.type == "hit" and e.has("volley"):
			hit_ticks[int(e.tick)] = true
	check(first.has("volley") and first.has("clash") and first.has("charge"), "a volley, the clash and a charge")
	check(int(first.volley) < int(first.clash), "the first volley comes before the clash")
	check(int(first.charge) > int(first.clash), "the charge after it")
	# Every Ranged shot is part of a volley, fired on the volley ticks.
	for e in events:
		if e.type == "hit" and bool(e.ranged):
			for f in m.sim.fighters:
				if f.uid == int(e.from) and f.cls == "ranged":
					check(e.has("volley"), "a Ranged shot outside a volley")
	for t in hit_ticks:
		check(army.volleys[0].has(t) or army.volleys[1].has(t), "volley shots only on volley ticks")


func test_the_front_holds_while_it_fights() -> void:
	var m := _sample()
	var army: BattleArmy = m.sim.army
	while m.phase == "fight" and army.clash_tick < 0:
		m.step()
	var at: int = army.front[0]
	for i in 10:
		m.step()
	check_eq(army.front[0], at, "the front holds after the clash")


func test_ranks_close_up() -> void:
	var m := _armies(["brown_bear*3"], ["brown_bear"])
	var army: BattleArmy = m.sim.army
	var bears := m.sim.units(0)
	bears.sort_custom(func(a, b): return a.x < b.x)
	var left: BattleSim.Fighter = bears[0]
	m.step()
	m.sim.deal_damage(left, left.hp + 1, null)
	for i in army.repack_ticks + 1:
		m.step()
	var slots: Array = m.sim.units(0).map(func(f): return f.memory.slot.x)
	slots.sort()
	check_eq(slots.size(), 2, "two left")
	check_eq(slots[0] + slots[1], 0, "the wall closes up around the middle")


func test_tank_destroyers_charge_the_tanks() -> void:
	var m := _armies(["brown_bear*2", "lion*2"], ["brown_bear*2", "wild_boar"])
	var army: BattleArmy = m.sim.army
	while m.phase == "fight" and not army.charged[0]:
		m.step()
	check(army.charged[0], "they charge")
	var lions: Array = m.sim.units(0).filter(func(f): return f.cls == "tank_destroyer")
	check(lions.all(func(f): return f.memory.get("charging", false)), "every Tank Destroyer")
	m.step()
	check(lions.all(func(f): return f.target == null or f.target.cls == "tank"), "for the enemy Tanks")


func test_the_war_horn_rouses_the_whole_army() -> void:
	var m := _sample()
	check(m.rally(0, 8 * T, 12 * T), "blown")
	for f in m.sim.units(0):
		check(f.rage > 0, "%s surges" % f.card.id)
	for f in m.sim.units(1):
		check_eq(f.rage, 0, "not the enemy")
	check(not m.rally(0, 8 * T, 12 * T), "once a fight")


func test_armies_fight_to_the_end() -> void:
	var m := _sample()
	var guard := 0
	while m.phase == "fight" and guard < 100000:
		m.step()
		guard += 1
	check(m.phase != "fight", "the fight ends")
	check(m.wiped_at[0] >= 0 or m.wiped_at[1] >= 0, "with an army beaten")


func test_same_armies_same_fight() -> void:
	var a := _sample()
	var b := _sample()
	for i in 200:
		a.step()
		b.step()
	check_eq(a.sim.checksum(), b.sim.checksum(), "identical")
	var copy := a.sim.clone()
	for i in 100:
		a.sim.step()
		copy.step()
	check_eq(copy.checksum(), a.sim.checksum(), "a copy plays on the same")
