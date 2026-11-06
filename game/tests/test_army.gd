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
	check(by_rank.wall.all(func(f): return f.y == walls[0].y), "the wall is one straight line")
	var middle_x := m.sim.width / 2
	var yeti: BattleSim.Fighter = walls.filter(func(f): return f.card.id == "yeti")[0]
	check(absi(yeti.x - middle_x) < T, "the hero stands in the middle")
	# Three or more squads of a rank: spread over the three lanes.
	var wall_lanes := {}
	for f in by_rank.wall:
		wall_lanes[int(f.memory.lane)] = true
	check_eq(wall_lanes.size(), 3, "the wall's squads spread over all three lanes")
	for f in m.sim.units(0):
		check_eq(BattleArmy.lane_at(m.sim, f.x), int(f.memory.lane), "%s stands in its own lane" % f.card.id)
	# Specialists on the flanks: an outer end of their lane's line.
	for spec in [["red_fox", "wall"], ["electric_eel", "td"]]:
		var s: BattleSim.Fighter = m.sim.units(0).filter(func(f): return f.card.id == spec[0])[0]
		var xs: Array = by_rank[spec[1]].filter(func(f): return f != s and int(f.memory.lane) == int(s.memory.lane) and f.y == s.y).map(func(f): return f.x)
		check(xs.is_empty() or s.x > xs.max() or s.x < xs.min(), "the %s at an end of its lane's line" % spec[0])
	# The ranged lines are even in each lane: the same gap between neighbours.
	for lane in [-1, 0, 1]:
		var ranged: Array = by_rank.ranged.filter(func(f): return f.y == by_rank.ranged[0].y and int(f.memory.lane) == lane)
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
	# Six bears: two in each lane. One falls; the other in its lane closes
	# up into the middle of the lane, and nobody changes lanes.
	var m := _armies(["brown_bear*6"], ["brown_bear"])
	var army: BattleArmy = m.sim.army
	var lane_w := m.sim.width / 3
	var bears := m.sim.units(0).filter(func(f): return int(f.memory.lane) == -1)
	check_eq(bears.size(), 2, "two bears in the left lane")
	var lanes_before := {}
	for f in m.sim.units(0):
		lanes_before[f.uid] = int(f.memory.lane)
	m.step()
	m.sim.deal_damage(bears[0], bears[0].hp + 1, null)
	for i in army.repack_ticks + 1:
		m.step()
	check_eq(m.sim.units(0).size(), 5, "five left")
	check_eq(int(bears[1].memory.slot.x), -lane_w, "the other closes up into the middle of its lane")
	for f in m.sim.units(0):
		check_eq(int(f.memory.lane), int(lanes_before[f.uid]), "everyone keeps its lane")


func test_tank_destroyers_charge_the_tanks() -> void:
	# A Tank in every lane: each lane's Tank Destroyers charge the Tank in
	# their lane (battle_rules.json "lanes").
	var m := _armies(["brown_bear*3", "lion*3"], ["brown_bear*3", "wild_boar"])
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


# --- All-out war: nobody waits -------------------------------------------------

## The feel report's idle check without the screen: of the time animals are
## on the field while the other side still has animals, the share spent
## standing about (not fighting, nor in the last half second, and moving less
## than a quarter of what it could in half a second) with an enemy it could
## hit and that has a slot free for it (waiting for a slot while every enemy
## is full is the engagement rule, not standing about). Plays the fight to
## its end.
func _idle_share(m: DraftMatch) -> float:
	var window := 10
	var trail := {}
	var fought := {}
	var on_field := 0
	var idle := 0
	var steps := 0
	while m.phase == "fight" and steps < 90 * m.sim.tps:
		var sim := m.sim
		var standing := [0, 0]
		for f in sim.fighters:
			if f.alive and f.is_unit():
				standing[f.team] += 1
		for f in sim.fighters:
			if not f.alive or not f.is_unit():
				continue
			var path: Array = trail.get(f.uid, [])
			path.append(Vector2i(f.x, f.y))
			if path.size() > window + 1:
				path.pop_front()
			trail[f.uid] = path
			if standing[0] == 0 or standing[1] == 0 or f.deploy_ticks > 0 or f.stun > 0 or f.memory.get("burrowing", false) or BattleStyles.busy(sim, f):
				continue
			on_field += 1
			if f.target != null and f.target.alive and sim.in_range(f, f.target):
				fought[f.uid] = sim.tick
				continue
			if path.size() <= window or sim.tick - int(fought.get(f.uid, -1000)) <= window:
				continue
			if Vector2(path[-1] - path[0]).length() * 4.0 >= float(f.speed * window):
				continue
			if not sim.fighters.any(func(t): return t.is_unit() and sim.can_target(f, t)):
				continue
			# Waiting its turn for a slot while every enemy it could fight
			# is full (engagement slots) isn't standing about.
			if not sim.fighters.any(func(t): return t.is_unit() and sim.can_target(f, t) and sim.army.room(sim, f, t)):
				continue
			idle += 1
		m.step()
		steps += 1
	return float(idle) / maxf(1.0, on_field)


func test_nobody_stands_about_while_enemies_are_left() -> void:
	var fights := [
		[["brown_bear*2", "wild_boar*2", "gray_squirrel*2", "peregrine_falcon", "red_fox"], ["snapping_turtle*2", "lion", "striped_skunk*2", "barn_owl", "electric_eel"]],
		[["asian_elephant*3", "wolf_pack*3", "king_cobra*2", "harbor_seal*2"], ["hippopotamus", "tiger*4", "raccoon*3", "mountain_gorilla"]],
		[["giant_panda", "honey_badger*5", "sunda_pangolin*2"], ["black_rhino*4", "komodo_dragon", "hyacinth_macaw*2", "red_panda"]],
	]
	for i in fights.size():
		var share := _idle_share(_armies(fights[i][0], fights[i][1], 3 + i))
		check(share < 0.01, "fight %d: standing about %.1f%% of the time with an enemy to fight (should be close to none)" % [i + 1, share * 100.0])


func test_the_whole_front_is_fought() -> void:
	# Twelve lions against a wall of four bears: the lions spread out along
	# the wall, one or more on every bear, not all on the middle ones.
	var m := _armies(["lion*6"], ["brown_bear*4"])
	var army: BattleArmy = m.sim.army
	var covered := false
	for i in 30 * m.sim.tps:
		m.step()
		var bears: Array = m.sim.units(1)
		if bears.size() < 4:
			break
		if army.at_war() and bears.all(func(b): return m.sim.units(0).any(func(f): return f.target == b and m.sim.in_range(f, b))):
			covered = true
			break
	check(army.at_war(), "the war started")
	check(covered, "while all four bears stand, every one has a lion on it")


func test_fighters_walk_round_their_own_line() -> void:
	# Lions stuck behind a wide wall of their own elephants, the enemy
	# squirrels straight ahead: they walk round the end of the wall and get
	# past it (or reach an enemy first), every one of them.
	var m := _armies(["asian_elephant*5", "lion*3"], ["gray_squirrel*3", "brown_bear"])
	var lions: Array = m.sim.units(0).filter(func(f): return f.card.id == "lion")
	var wall_y: int = m.sim.units(0).filter(func(f): return f.card.id == "asian_elephant").map(func(f): return f.y).min()
	check(lions.all(func(b): return b.y > wall_y), "they start behind the wall")
	var through := {}
	for i in 40 * m.sim.tps:
		if m.phase != "fight":
			break
		m.step()
		for b in lions:
			if b.alive and (b.y < wall_y or b.memory.get("attacked", false) or (b.target != null and b.target.alive and m.sim.in_range(b, b.target))):
				through[b.uid] = true
	check_eq(through.size(), lions.size(), "every lion got round it")


func test_shots_go_over_teammates() -> void:
	# Squirrels behind their own bears hit the enemy in front of the bears.
	var m := _armies(["brown_bear*3", "gray_squirrel"], ["brown_bear"])
	var squirrels: Array = m.sim.units(0).filter(func(f): return f.card.id == "gray_squirrel")
	var enemy: BattleSim.Fighter = m.sim.units(1)[0]
	var start := enemy.hp
	var behind := true
	for i in 8 * m.sim.tps:
		m.step()
		for s in squirrels:
			if s.alive and m.sim.units(0).any(func(b): return b.card.id == "brown_bear" and b.y > s.y):
				behind = false
	check(squirrels.any(func(s): return s.memory.get("attacked", false)), "the squirrels shot")
	check(behind, "from behind their own bears")
	check(enemy.hp < start, "and hit the enemy past them")
