extends TestCase
## Fixing the mosh pit, part one: engagement slots (battle_rules.json
## "engagement", scripts/battle/battle_army.gd) and personal space
## ("spacing", battle_sim.gd). Only so many fighters attack one enemy at
## once (Tanks take more), each from its own spot round it; a full enemy is
## passed over for the next closest with a free slot; nobody overlaps.

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


func test_slots_from_the_data() -> void:
	var m := _armies(["lion"], ["brown_bear", "raccoon"])
	var army: BattleArmy = m.sim.army
	var rules: Dictionary = GameData.battle_rules.engagement
	for f: BattleSim.Fighter in m.sim.units(1):
		var want := int(rules.slots_by_class.get(f.cls, rules.slots))
		check_eq(army.cap_of(f), want, "a %s takes %d attackers at once" % [f.cls, want])
	check_eq(int(rules.slots), 2, "2 slots to an enemy")
	check_eq(int(rules.slots_by_class.tank), 3, "3 for a Tank")


## Plays a fight, checking every tick that no enemy has more fighters
## attacking it (in reach, holding one of its slots: only those may strike)
## than its slots, and that no more hold its slots than it has; returns the
## most attackers seen on one.
func _never_over(m: DraftMatch, seconds: float) -> int:
	var sim := m.sim
	var army: BattleArmy = sim.army
	var most := 0
	var over := 0
	for i in roundi(seconds * sim.tps):
		if m.phase != "fight":
			break
		m.step()
		sim.take_events()
		var on := {}
		for f: BattleSim.Fighter in sim.fighters:
			var t := f.target
			if f.alive and f.is_unit() and f.attack_range < army.shooter_reach and t != null and t.alive and sim.in_range(f, t) and army.has_slot(f, t):
				on[t] = int(on.get(t, 0)) + 1
		for e: BattleSim.Fighter in sim.fighters:
			var held := 0
			for f: BattleSim.Fighter in sim.fighters:
				if f.alive and f.team != e.team and int(f.memory.get("engage_on", -1)) == e.uid and f.target == e:
					held += 1
			if held > army.cap_of(e):
				over += 1
		for t in on:
			most = maxi(most, int(on[t]))
			if int(on[t]) > army.cap_of(t):
				over += 1
	check_eq(over, 0, "never more fighters on one enemy than its slots")
	return most


func test_twelve_lions_on_four_bears_take_turns() -> void:
	# Twelve lions, four bears: three on each bear at most, never a pile.
	var most := _never_over(_armies(["lion*6"], ["brown_bear*4"]), 30.0)
	check(most >= 2, "and they do fight (%d on one at most)" % most)


func test_a_big_fight_stays_within_the_slots() -> void:
	_never_over(_armies(["brown_bear*3", "wild_boar*4", "gray_squirrel*3", "red_fox", "wolf_pack*3"],
		["snapping_turtle*3", "lion*3", "striped_skunk*3", "honey_badger*4", "tiger"], 4), 40.0)


func test_a_full_enemy_is_passed_over_for_one_with_room() -> void:
	# Whenever a fighter holds no slot, every enemy it could fight is full:
	# it never waits while another enemy has room.
	var m := _armies(["lion*4", "wolf_pack*2"], ["brown_bear", "raccoon*2"], 2)
	var sim := m.sim
	var army: BattleArmy = sim.army
	var waited_wrongly := 0
	var holders := 0
	for i in 30 * sim.tps:
		if m.phase != "fight":
			break
		m.step()
		sim.take_events()
		if not army.at_war():
			continue
		for f: BattleSim.Fighter in sim.units(0):
			if f.target == null or f.attack_range >= army.shooter_reach or f.stun > 0 or f.memory.get("burrowing", false):
				continue
			if army.has_slot(f, f.target):
				holders += 1
				continue
			# Waiting: is there an enemy with room it could have taken? (A
			# turn's grace: it looks around twice a second.)
			if (sim.tick + f.uid) % sim.targeting.recheck_ticks != 1:
				continue
			for e: BattleSim.Fighter in sim.units(1):
				if sim.can_target(f, e) and army.room(sim, f, e):
					waited_wrongly += 1
					break
	check(holders > 0, "fighters hold slots")
	check_eq(waited_wrongly, 0, "nobody waits for a slot while another enemy has room")


func test_attackers_stand_apart_round_their_target() -> void:
	# Three lions on one bear: each from its own spot, side by side, not on
	# top of each other, and on their own side of it.
	var m := _armies(["lion*2"], ["brown_bear"], 3)
	var sim := m.sim
	var army: BattleArmy = sim.army
	for f in sim.units(1):
		f.hp = 1000000
		f.max_hp = 1000000
	var seen := false
	for i in 25 * sim.tps:
		if m.phase != "fight":
			break
		m.step()
		sim.take_events()
		var bear: BattleSim.Fighter = null
		for f in sim.units(1):
			bear = f
		if bear == null:
			break
		var on: Array = sim.units(0).filter(func(f): return f.target == bear and army.has_slot(f, bear) and sim.in_range(f, bear))
		if on.size() < 3:
			continue
		seen = true
		var ks := {}
		for a: BattleSim.Fighter in on:
			ks[int(a.memory.engage_k)] = true
			check(a.y > bear.y - bear.radius, "fighting from its own side of the bear")
			for b: BattleSim.Fighter in on:
				if a != b:
					check(BattleSim.dist(a, b) >= a.radius + b.radius - 20, "two lions don't overlap (%d apart)" % BattleSim.dist(a, b))
		check_eq(ks.size(), on.size(), "each in a slot of its own")
		break
	check(seen, "three lions got on the bear at once")


## The gap between two bodies' outlines (their spines' circles,
## BattleSim.spine): below 0, they overlap.
func _outline_gap(a: BattleSim.Fighter, b: BattleSim.Fighter) -> int:
	var gap := 1 << 30
	for pa: Vector2i in BattleSim.spine(a.x, a.y, a.half, a.hw, a.heading, a.across):
		for pb: Vector2i in BattleSim.spine(b.x, b.y, b.half, b.hw, b.heading, b.across):
			gap = mini(gap, roundi(Vector2(pa - pb).length()) - a.hw - b.hw)
	return gap


func test_personal_space() -> void:
	# Two animals dropped on the same spot spring apart and, standing about,
	# keep a little room between their bodies.
	var sim := BattleSim.new([{}, {}], 1)
	var a: BattleSim.Fighter = sim.spawn_units(0, "brown_bear", 1, 8 * T, 10 * T)[0]
	var b: BattleSim.Fighter = sim.spawn_units(0, "giant_panda", 1, 8 * T + 50, 10 * T)[0]
	sim.step()
	check(_outline_gap(a, b) >= -T / 50, "an overlap is pushed apart at once (%d)" % _outline_gap(a, b))
	for i in 3 * sim.tps:
		sim.step()
	var room := _outline_gap(a, b)
	check(room > sim.personal_space / 2, "and they ease apart into their personal space (%d of %d)" % [room, sim.personal_space])


func test_the_king_cobra_stands_at_the_very_back() -> void:
	# Its long reach shows: a line of its own behind every other Ranged.
	var m := _armies(["king_cobra", "gray_squirrel*2", "raccoon", "unicorn", "brown_bear"], ["brown_bear"])
	var cobras := []
	var others := []
	for f: BattleSim.Fighter in m.sim.units(0):
		if f.memory.rank == "ranged":
			(cobras if f.card.id == "king_cobra" else others).append(int(f.memory.slot.y))
	check(not cobras.is_empty() and not others.is_empty(), "Cobras and other Ranged in the army")
	check(cobras.min() > others.max(), "every Cobra behind every other Ranged (%s vs %s)" % [cobras, others])


func test_the_komodo_hops_on_without_waiting() -> void:
	# Hopping on to the next unpoisoned enemy is the Komodo's whole ability:
	# it needn't wait out the commit time between hops.
	var sim := BattleSim.new([{}, {}], 2)
	var komodo: BattleSim.Fighter = sim.spawn_units(0, "komodo_dragon", 1, 8 * T, 10 * T)[0]
	komodo.deploy_ticks = 0
	komodo.hp = 1000000
	komodo.max_hp = 1000000
	for x in [7.2, 8.0, 8.8]:
		var e: BattleSim.Fighter = sim.spawn_units(1, "snapping_turtle", 1, roundi(x * T), 9 * T)[0]
		e.deploy_ticks = 0
		e.hp = 1000000
		e.max_hp = 1000000
		e.damage = 0
	var hops := []
	var last := komodo.target
	for i in 6 * sim.tps:
		sim.step()
		if komodo.target != last and last != null:
			hops.append(sim.tick)
		last = komodo.target
	check(hops.size() >= 2, "it hops from one to the next (%d hops)" % hops.size())
	if hops.size() >= 2:
		check(hops[1] - hops[0] < sim.targeting.commit_ticks, "the next hop sooner than the commit time (%d ticks)" % (hops[1] - hops[0]))
