extends TestCase
## Fixing the mosh pit, part two: lanes and the battle line
## (battle_rules.json "lanes", scripts/battle/battle_army.gd). Squads spread
## over three lanes and fight in their own; the melee clash happens along a
## battle line in each lane that pushes back and forth; Ranged stay behind
## it; flankers roam free of both.

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


const BIG_A := ["brown_bear*3", "wild_boar*3", "lion*2", "gray_squirrel*3", "peregrine_falcon*2", "tiger"]
const BIG_B := ["snapping_turtle*3", "wolf_pack*3", "honey_badger*2", "striped_skunk*3", "barn_owl*2", "red_fox"]


func test_squads_spread_over_three_lanes() -> void:
	var m := _armies(BIG_A, BIG_B)
	for team in 2:
		var per_lane := {-1: 0, 0: 0, 1: 0}
		for f: BattleSim.Fighter in m.sim.units(team):
			per_lane[int(f.memory.lane)] += 1
			check_eq(BattleArmy.lane_at(m.sim, f.x), int(f.memory.lane), "team %d: a %s lines up in its lane" % [team, f.card.id])
		var most := maxi(per_lane[-1], maxi(per_lane[0], per_lane[1]))
		var least := mini(per_lane[-1], mini(per_lane[0], per_lane[1]))
		check(least > 0, "team %d: every lane has animals (%s)" % [team, per_lane])
		check(most - least <= most / 2, "team %d: spread evenly (%s)" % [team, per_lane])
	# One squad of each class: one column in the middle lane.
	var small := _armies(["brown_bear", "wild_boar", "gray_squirrel"], ["snapping_turtle", "lion", "raccoon"])
	for f: BattleSim.Fighter in small.sim.units(0):
		check_eq(int(f.memory.lane), 0, "a small army keeps to the middle lane (%s)" % f.card.id)


## Plays a big fight and checks the lane and line rules every tick of the
## war; returns the shares of the checks that held.
func _play(seconds: float) -> Dictionary:
	var m := _armies(BIG_A, BIG_B, 6)
	var sim := m.sim
	var army: BattleArmy = sim.army
	var out := {"own_lane": 0, "picks": 0, "fresh": 0, "left_lane_wrongly": 0, "deep": 0, "ranged": 0, "ranged_past": 0,
		"line_ticks": 0, "line_jumps": 0, "line_moved": 0, "roam_far": 0}
	var last_line := [-1, -1, -1]
	for i in roundi(seconds * sim.tps):
		if m.phase != "fight":
			break
		# Who had room on whom as the tick began (a slot freed later in the
		# tick wasn't there to pick).
		var before: Array = army.crowd.duplicate(true)
		m.step()
		sim.take_events()
		if not army.at_war():
			continue
		for l in 3:
			var y := int(army.line[l])
			if y >= 0:
				out.line_ticks += 1
				if int(last_line[l]) >= 0:
					if absi(y - int(last_line[l])) > army.line_pace:
						out.line_jumps += 1
					if y != int(last_line[l]):
						out.line_moved += 1
			last_line[l] = y
		for f: BattleSim.Fighter in sim.fighters:
			var t := f.target
			if not f.alive or not f.is_unit() or not f.memory.has("slot") or t == null or not t.alive or not t.is_unit():
				continue
			if army.roams(f):
				if army.lane_steps(sim, f, t) > 0:
					out.roam_far += 1
				continue
			out.picks += 1
			var steps := army.lane_steps(sim, f, t)
			if steps == 0:
				out.own_lane += 1
			var fresh := int(f.memory.get("locked", -1)) == sim.tick and String(f.memory.get("locked_why", "")) != "threat"
			if fresh and f.attack_range < army.shooter_reach and not army.crosses(f):
				out.fresh += 1
				# A fighter picking outside its lane or deep past the line: only
				# if its own lane had nobody near the line it could take on.
				# (Half a tile's leeway at the line and a quarter at a lane's edge:
				# animals move a little within a tick.)
				var own := int(f.memory.lane)
				var outside: bool = t.x < (own + 1) * sim.width / 3 - army.lane_slack - T / 4 or t.x > (own + 2) * sim.width / 3 + army.lane_slack + T / 4
				if outside or army.past_line(sim, f.team, t) > army.line_reach + T / 2:
					for e: BattleSim.Fighter in sim.fighters:
						if e.team != f.team and e.alive and e.is_unit() and sim.can_target(f, e) and army.room(sim, f, e) and int(before[f.team].get(e.uid, 0)) < army.cap_of(e) \
								and army.lane_steps(sim, f, e) == 0 and army.past_line(sim, f.team, e) <= army.line_reach - T / 2:
							out.left_lane_wrongly += 1
							if OS.get_environment("LANE_LOG") != "":
								print("LANEDBG %s why=%s charging=%s steps=%d past=%d tgt=%s alt=%s(%d,%d) alt_score=%d tgt_score=%d" % [f.card.id, f.memory.get("locked_why"), f.memory.get("charging", false), steps, army.past_line(sim, f.team, t), t.card.id, e.card.id, army.lane_steps(sim, f, e), army.past_line(sim, f.team, e), army._score(sim, f, e, Vector2i(f.x, f.y), true), army._score(sim, f, t, Vector2i(f.x, f.y), true)])
							break
			if f.attack_range < army.shooter_reach and not army.crosses(f) and army.past_line(sim, f.team, t) > army.line_reach + T:
				out.deep += 1
			if f.cls == "ranged" and not army.crosses(f):
				out.ranged += 1
				var y := int(army.line[BattleArmy.lane_at(sim, f.x) + 1])
				if y >= 0 and (y - f.y if f.team == 0 else f.y - y) > 0:
					out.ranged_past += 1
	return out


func test_fighters_keep_to_their_lane_and_the_line() -> void:
	var out := _play(40.0)
	check(out.picks > 1000, "a real fight (%d checks)" % out.picks)
	check(float(out.own_lane) / out.picks > 0.7, "mostly fighting in their own lane (%.0f%%)" % [100.0 * out.own_lane / out.picks])
	check(out.fresh > 20, "fighters pick targets (%d)" % out.fresh)
	check_eq(out.left_lane_wrongly, 0, "a fighter only picks outside its lane, or deep past the line, when its own lane has nobody near the line it can take on")
	check(float(out.deep) / out.picks < 0.05, "fighters seldom end up on an enemy deep past the battle line (%.1f%%)" % [100.0 * out.deep / out.picks])


func test_ranged_stay_behind_the_line() -> void:
	var out := _play(40.0)
	check(out.ranged > 200, "Ranged in the war (%d checks)" % out.ranged)
	check(float(out.ranged_past) / out.ranged < 0.05, "Ranged stay behind the battle line (%.1f%% in front of it)" % [100.0 * out.ranged_past / out.ranged])


func test_the_line_pushes_back_and_forth() -> void:
	var out := _play(40.0)
	check(out.line_ticks > 100, "a battle line in the war (%d lane-ticks)" % out.line_ticks)
	check_eq(out.line_jumps, 0, "it never jumps: at most line_pace a tick")
	check(out.line_moved > 20, "it moves as the fight goes (%d times)" % out.line_moved)


func test_flankers_roam() -> void:
	var lanes: Dictionary = GameData.battle_rules.lanes
	for id in ["tiger", "red_fox", "barn_owl"]:
		check(lanes.flankers.has(id), "the %s is a flanker" % id)
	# A lion and a tiger in the left lane, the only enemy in the right lane:
	# for the lion it's two lanes away, for the tiger just an enemy.
	var m := _armies(["lion*3", "tiger"], ["brown_bear"])
	var sim := m.sim
	var army: BattleArmy = sim.army
	var bear: BattleSim.Fighter = sim.units(1)[0]
	bear.x = sim.width * 5 / 6
	var lion: BattleSim.Fighter = null
	var tiger: BattleSim.Fighter = null
	for f: BattleSim.Fighter in sim.units(0):
		if f.card.id == "lion" and int(f.memory.lane) == -1:
			lion = f
		if f.card.id == "tiger":
			tiger = f
	tiger.memory.lane = -1
	check(lion != null, "a lion in the left lane")
	var place := Vector2i(lion.x, lion.y)
	check(army._score(sim, lion, bear, place, true) - BattleSim.edge_distance(lion, bear) >= 2 * army.fighter_lane_cost, "for the lion, an enemy two lanes over counts much further")
	check_eq(army._score(sim, tiger, bear, place, true), BattleSim.edge_distance(tiger, bear), "for the tiger, it's just as far as it is")
	check(army.crosses(tiger) and army.crosses(sim.units(1)[0]) == false, "the tiger may cross the line; the bear not")


func test_the_war_starts_even_with_the_fronts_in_other_lanes() -> void:
	# A Fox listed before the Bear: the Bear still takes the middle lane,
	# and even if the two fronts end up in different lanes, the war starts
	# once they've marched as close as they can.
	var m := _armies(["brown_bear", "lion", "gray_squirrel"], ["red_fox", "brown_bear", "raccoon"], 5)
	var army: BattleArmy = m.sim.army
	for f: BattleSim.Fighter in m.sim.units(1):
		if f.card.id == "brown_bear":
			check_eq(int(f.memory.lane), 0, "the Bear holds the middle lane, not the Fox")
	var seconds := 0.0
	while m.phase == "fight" and seconds < 40.0:
		m.step()
		m.sim.take_events()
		seconds += 1.0 / m.sim.tps
	check(army.war_tick >= 0 and army.war_tick < 10 * m.sim.tps, "the war starts soon (at %.1f s)" % (army.war_tick / float(m.sim.tps)))
	check(seconds < 30.0, "and the fight's done well before the time limit (%.1f s)" % seconds)
	# Fronts in different lanes from the start: a lone enemy Tank on a side.
	var m2 := _armies(["brown_bear", "gray_squirrel"], ["brown_bear*2", "raccoon"], 6)
	for f: BattleSim.Fighter in m2.sim.units(0):
		f.memory.lane = 1
		f.x = m2.sim.width * 5 / 6
	m2.sim.army.layout(m2.sim, 0, true)
	var t := 0
	while m2.phase == "fight" and t < 40 * m2.sim.tps:
		m2.step()
		m2.sim.take_events()
		t += 1
	var army2: BattleArmy = m2.sim.army
	check(army2.war_tick >= 0 and army2.war_tick < 12 * m2.sim.tps, "with the armies in different lanes, the war still starts (at %.1f s)" % (army2.war_tick / float(m2.sim.tps)))

