extends TestCase
## One field, no lanes (battle_rules.json "line"; scripts/battle/
## battle_army.gd). An army lines up as one block; once the war is on,
## every fighter charges whichever enemy is best for it, anywhere on the
## field; Ranged keep behind the battle line, which pushes back and forth
## as one side wins ground.

const T := BattleSim.TILE


## A match laid out with these armies ("id*groups" each), ready to fight.
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


const BIG_A := ["brown_bear", "wild_boar*2", "lion", "gray_squirrel*2", "peregrine_falcon", "tiger"]
const BIG_B := ["snapping_turtle", "wolf_pack*2", "honey_badger", "striped_skunk*2", "barn_owl"]


func test_there_are_no_lanes() -> void:
	check(not GameData.battle_rules.has("lanes"), "no lanes in the rules")
	var m := _armies(BIG_A, BIG_B)
	for f: BattleSim.Fighter in m.sim.units(0) + m.sim.units(1):
		check(not f.memory.has("lane"), "a %s has no lane to keep to" % f.card.id)
	# For a fighter in the war, an enemy counts as far as it is, wherever on
	# the field it stands: right across it too.
	var army: BattleArmy = m.sim.army
	army.war_tick = 0
	var bear: BattleSim.Fighter = m.sim.units(0).filter(func(f): return f.card.id == "brown_bear")[0]
	bear.x = bear.radius
	var place := Vector2i(bear.x, bear.y)
	for e: BattleSim.Fighter in m.sim.units(1):
		if m.sim.can_target(bear, e):
			check_eq(army._score(m.sim, bear, e, place, true), BattleSim.edge_distance(bear, e), "a %s at x %d is as far as it is" % [e.card.id, e.x])


## In the war a fighter goes for the closest enemy it can take on, even one
## right across the field, rather than a further one straight ahead.
func test_a_fighter_charges_the_closest_anywhere() -> void:
	var m := _armies(["snapping_turtle"], ["wild_boar", "wolf_pack"])
	var sim := m.sim
	var army: BattleArmy = sim.army
	army.war_tick = 0
	var turtle: BattleSim.Fighter = sim.units(0)[0]
	for f: BattleSim.Fighter in sim.units(0):
		if f != turtle:
			f.alive = false
	turtle.x = sim.width / 6
	turtle.y = sim.middle + 2 * T
	# Boars straight ahead, six tiles up the field; wolves level with it,
	# four tiles across.
	var k := 0
	for f: BattleSim.Fighter in sim.units(1):
		if f.card.id == "wild_boar":
			f.x = turtle.x + (k % 2) * T
			f.y = turtle.y - 6 * T
		else:
			f.x = turtle.x + 4 * T + (k % 2) * T
			f.y = turtle.y + (k % 3) * T / 2
		k += 1
	var found := army._find(sim, turtle, Vector2i(turtle.x, turtle.y), int(turtle.memory.leash), true, false)
	check(found != null and found.card.id == "wolf_pack", "the wolves across the field are closer: it goes for one (%s)" % (found.card.id if found != null else "nobody"))


## Plays a big fight and watches the battle line every tick of the war.
func _play(seconds: float, seed_value := 6) -> Dictionary:
	var m := _armies(BIG_A, BIG_B, seed_value)
	var sim := m.sim
	var army: BattleArmy = sim.army
	var out := {"ranged": 0, "ranged_past": 0, "line_ticks": 0, "line_jumps": 0, "line_moved": 0, "between": 0}
	var last_line := -1
	for i in roundi(seconds * sim.tps):
		if m.phase != "fight":
			break
		m.step()
		sim.take_events()
		if not army.at_war():
			continue
		var y := int(army.line)
		if y >= 0:
			out.line_ticks += 1
			if last_line >= 0:
				if absi(y - last_line) > army.line_pace:
					out.line_jumps += 1
				if y != last_line:
					out.line_moved += 1
		last_line = y
		for f: BattleSim.Fighter in sim.fighters:
			if not f.alive or not f.is_unit() or f.cls != "ranged" or not f.memory.has("slot") or army.crosses(f):
				continue
			if y >= 0:
				out.ranged += 1
				if army.past_line(1 - f.team, f) < 0:
					out.ranged_past += 1
	return out


func test_ranged_stay_behind_the_line() -> void:
	var out := _play(40.0)
	check(out.ranged > 200, "Ranged in the war (%d checks)" % out.ranged)
	check(float(out.ranged_past) / maxf(1, out.ranged) < 0.05, "Ranged stay behind the battle line (%.1f%% in front of it)" % [100.0 * out.ranged_past / maxf(1, out.ranged)])


func test_the_line_pushes_back_and_forth() -> void:
	var out := _play(40.0)
	check(out.line_ticks > 100, "a battle line in the war (%d ticks)" % out.line_ticks)
	check_eq(out.line_jumps, 0, "it never jumps: at most its pace a tick")
	check(out.line_moved > 20, "it moves as the fight goes (%d times)" % out.line_moved)


## Everyone may cross the line but the Ranged; a flanker off on its own
## isn't counted as its army's front.
func test_who_crosses_the_line() -> void:
	var line: Dictionary = GameData.battle_rules.line
	for id in ["tiger", "red_fox", "barn_owl"]:
		check(line.flankers.has(id), "the %s is a flanker" % id)
	var m := _armies(["lion", "tiger", "gray_squirrel"], ["brown_bear"])
	var sim := m.sim
	var army: BattleArmy = sim.army
	var by_id := {}
	for f: BattleSim.Fighter in sim.units(0):
		by_id[f.card.id] = f
	check(army.crosses(by_id.lion) and army.crosses(by_id.tiger), "fighters go past the line")
	check(not army.crosses(by_id.gray_squirrel), "Ranged stay behind it")
	check(army.roams(by_id.tiger) and not army.roams(by_id.lion), "the tiger is off on its own; the lion is part of the front")
	# The line is halfway between the fronts, and a flanker far ahead of
	# its army doesn't drag it along.
	army._move_line(sim)
	var before: int = army.line
	check(before > 0, "a line between the armies (%d)" % before)
	by_id.tiger.y = sim.units(1)[0].y - 2 * T
	army.line = -1
	army._move_line(sim)
	check_eq(army.line, before, "the tiger behind the enemy leaves the line where it is")
	by_id.lion.y -= 2 * T
	army.line = -1
	army._move_line(sim)
	check(army.line < before, "a lion out in front moves it up")


func test_the_war_starts_once_the_fronts_meet() -> void:
	var m := _armies(["brown_bear", "lion", "gray_squirrel"], ["red_fox", "brown_bear", "raccoon"], 5)
	var army: BattleArmy = m.sim.army
	var seconds := 0.0
	while m.phase == "fight" and seconds < 40.0:
		m.step()
		m.sim.take_events()
		seconds += 1.0 / m.sim.tps
	check(army.war_tick >= 0 and army.war_tick < 10 * m.sim.tps, "the war starts soon (at %.1f s)" % (army.war_tick / float(m.sim.tps)))
	check(seconds < 35.0, "and the fight's done before the time limit (%.1f s)" % seconds)
	# The two armies standing apart across the field (one pushed right over
	# to a side): the fronts still meet, and the war starts.
	var m2 := _armies(["brown_bear", "gray_squirrel"], ["brown_bear*2", "raccoon"], 6)
	m2.sim.army.center[0] = m2.sim.width - 2 * T
	m2.sim.army.layout(m2.sim, 0, true)
	var t := 0
	while m2.phase == "fight" and t < 40 * m2.sim.tps:
		m2.step()
		m2.sim.take_events()
		t += 1
	var army2: BattleArmy = m2.sim.army
	check(army2.war_tick >= 0 and army2.war_tick < 12 * m2.sim.tps, "with the armies apart across the field, the war still starts (at %.1f s)" % (army2.war_tick / float(m2.sim.tps)))
