extends TestCase
## The targeting rules (scripts/battle/targeting.gd, battle_rules.json
## "targeting"): the closest enemy first (unless an ability or class says
## otherwise), committed to; a switch only when the target falls or can't be
## had, for a threat up close (after the reaction time, with a "!"), or for
## one much closer once the commit time is up; looked at on a timer, not
## every tick.

const T := BattleSim.TILE


func _sim(seed_value := 1) -> BattleSim:
	return BattleSim.new([{}, {}], seed_value)


func _ready_now(made: Array) -> Array:
	for f in made:
		f.deploy_ticks = 0
	return made


## A rule from battle_rules.json "targeting", in fight ticks.
func _ticks(sim: BattleSim, key: String) -> int:
	return roundi(float(GameData.battle_rules.targeting[key]) * sim.tps)


## Holds an animal still for the whole test without taking its target away
## (a stun would): it simply can't move or fight.
func _statue(f: BattleSim.Fighter) -> void:
	f.speed = 0
	f.damage = 0
	f.hp = 1000000
	f.max_hp = 1000000


func test_the_closest_first_then_committed() -> void:
	var sim := _sim()
	var commit := _ticks(sim, "commit_seconds")
	var recheck := _ticks(sim, "recheck_seconds")
	# A bear that stays where it is (so only its choice changes), and
	# enemies that do too.
	var bear: BattleSim.Fighter = _ready_now(sim.spawn(0, "brown_bear", 8 * T, 15 * T))[0]
	bear.speed = 0
	_ready_now(sim.spawn(1, "raccoon", 8 * T, 9 * T))
	for f in sim.fighters:
		if f.team == 1:
			_statue(f)
	sim.step()
	check(bear.target != null and bear.target.card.id == "raccoon", "it goes for the closest enemy")
	var first := bear.target
	var locked := sim.tick
	# One a little closer (about 30%, not 40%) turns up: it keeps its target,
	# however long.
	for f in _ready_now(sim.spawn(1, "gray_squirrel", 11 * T, 11 * T + 600)):
		_statue(f)
	for i in commit * 2:
		sim.step()
	check(bear.target == first, "not for one only a little closer")
	# One much closer turns up: it waits out the commit time, then switches
	# on its turn to look around.
	for f in _ready_now(sim.spawn(1, "wild_boar", 8 * T, 13 * T)):
		_statue(f)
	locked = int(bear.memory.get("locked", locked))
	var waited := sim.tick
	var switched_at := -1
	for i in commit + 2 * recheck:
		sim.step()
		if bear.target != first:
			switched_at = sim.tick
			break
	check(bear.target != null and bear.target.card.id == "wild_boar", "it does go for one much closer")
	check(switched_at - locked >= commit, "only once it's kept its target for the commit time (%d ticks, %d needed)" % [switched_at - locked, commit])
	check(switched_at - waited <= recheck, "and then at its next look around (%d ticks)" % [switched_at - waited])
	check((switched_at + bear.uid) % recheck == 0, "on its turn to look around, not any tick (%s)" % [bear.memory.get("locked_why")])


func test_a_new_target_is_kept_for_the_commit_time() -> void:
	# Just switched (its target fell): a much closer one turning up straight
	# after doesn't take it off its new one before the commit time is up.
	var sim := _sim()
	var commit := _ticks(sim, "commit_seconds")
	var bear: BattleSim.Fighter = _ready_now(sim.spawn(0, "brown_bear", 8 * T, 15 * T))[0]
	bear.speed = 0
	var gone: BattleSim.Fighter = _ready_now(sim.spawn(1, "wild_boar", 8 * T, 12 * T))[0]
	_ready_now(sim.spawn(1, "raccoon", 8 * T, 8 * T))
	for f in sim.fighters:
		if f.team == 1:
			_statue(f)
	for i in commit * 2:
		sim.step()
	check(bear.target != null and bear.target.card.id == "wild_boar", "on the closest")
	for f in sim.fighters:
		if f.card.id == "wild_boar":
			f.alive = false
	sim.step()
	check(bear.target != null and bear.target.card.id == "raccoon", "its target gone, it takes the next at once")
	var second := bear.target
	var near: BattleSim.Fighter = _ready_now(sim.spawn(1, "snapping_turtle", 8 * T, 13 * T))[0]
	_statue(near)  # (a Tank: a squad of one)
	var kept := 0
	while bear.target == second and kept < commit * 2:
		sim.step()
		kept += 1
	check(kept >= commit - 1, "it keeps the new one for the commit time (%d ticks)" % kept)
	check(bear.target == near, "then goes for the much closer one")


func test_the_backline_turns_on_a_fox_in_its_midst() -> void:
	var sim := _sim()
	var rules: Dictionary = GameData.battle_rules.targeting
	var reaction := _ticks(sim, "reaction_seconds")
	var commit := _ticks(sim, "commit_seconds")
	# The enemy's backline: one squad of 3 Ranged, shooting at a Tank up
	# front. (Made hardy here, so a Fox can't knock them out before they
	# turn: this is about whom they fight.)
	var shooters: Array = _ready_now(sim.spawn(1, "gray_squirrel", 8 * T, 4 * T))
	check_eq(shooters.size(), 3, "a backline of 3 Ranged")
	for s: BattleSim.Fighter in shooters:
		s.hp = 1000000
		s.max_hp = 1000000
		s.speed = 0
	var bear: BattleSim.Fighter = _ready_now(sim.spawn(0, "brown_bear", 8 * T, 9 * T))[0]
	_statue(bear)
	sim.step()
	for s: BattleSim.Fighter in shooters:
		check(s.target == bear, "they shoot at the Tank up front")
	# The Fox burrows in from its side of the field and pops up among them.
	var fox: BattleSim.Fighter = _ready_now(sim.spawn(0, "red_fox", 9 * T, 14 * T))[0]
	fox.hp = 1000000
	fox.max_hp = 1000000
	var first_bite := -1
	var bites := 0
	var bites_before_shot_back := -1
	var turned := {}      # shooter uid -> tick it turned on the Fox
	var changes := {}     # shooter uid -> target changes once the Fox is up
	var alerts := {}      # shooter uid -> "!" pops
	var last := {}
	var uids := shooters.map(func(s: BattleSim.Fighter) -> int: return s.uid)
	for i in 14 * sim.tps:
		sim.step()
		for e in sim.take_events():
			if e.type == "hit" and int(e.from) == fox.uid and uids.has(int(e.to)):
				bites += 1
				if first_bite < 0:
					first_bite = sim.tick
			elif e.type == "hit" and int(e.to) == fox.uid and uids.has(int(e.from)) and bites_before_shot_back < 0:
				bites_before_shot_back = bites
			elif e.type == "alert":
				alerts[int(e.uid)] = int(alerts.get(int(e.uid), 0)) + 1
				check(int(e.to) == fox.uid, "the \"!\" is for the Fox")
		for s: BattleSim.Fighter in shooters:
			var now: int = s.target.uid if s.target != null else -1
			if first_bite >= 0 and last.has(s.uid) and now != int(last[s.uid]):
				changes[s.uid] = int(changes.get(s.uid, 0)) + 1
				if now == fox.uid and not turned.has(s.uid):
					turned[s.uid] = sim.tick
			last[s.uid] = now
		if first_bite >= 0 and sim.tick > first_bite + reaction + commit * 2:
			break
	check(first_bite >= 0, "the Fox pops up and bites into the backline")
	check(fox.y < 6 * T, "right among them (at %.1f tiles)" % (fox.y / float(T)))
	check_eq(turned.size(), 3, "all 3 Ranged turn on the Fox")
	for s: BattleSim.Fighter in shooters:
		if not turned.has(s.uid):
			continue
		var after: int = int(turned[s.uid]) - first_bite
		check(after >= reaction and after <= reaction + 2, "turning after the reaction time (%.2f s after the first bite; %.2f s set)" % [after / float(sim.tps), float(rules.reaction_seconds)])
		check_eq(int(alerts.get(s.uid, 0)), 1, "with one \"!\" over its head")
		check_eq(int(changes.get(s.uid, 0)), 1, "and staying on it: no switching back and forth")
	check(bites_before_shot_back >= 2, "the Fox lands at least a couple of bites first (%d)" % bites_before_shot_back)


func test_no_threat_turn_while_fighting_up_close() -> void:
	# A Tank already in a scrap doesn't spin round to every enemy that bites
	# it: its target is right there too.
	var sim := _sim()
	var bear: BattleSim.Fighter = _ready_now(sim.spawn(0, "brown_bear", 8 * T, 10 * T))[0]
	bear.hp = 1000000
	bear.max_hp = 1000000
	var first: BattleSim.Fighter = _ready_now(sim.spawn(1, "snapping_turtle", 8 * T, 9 * T))[0]
	first.hp = 1000000
	first.max_hp = 1000000
	sim.step()
	check(bear.target == first, "it fights the one in front of it")
	var biter: BattleSim.Fighter = _ready_now(sim.spawn(1, "wild_boar", 9 * T, 10 * T))[0]
	biter.hp = 1000000
	biter.max_hp = 1000000
	for i in 5 * sim.tps:
		sim.step()
	check(bear.target == first, "and keeps on with it when another bites it from the side")


func test_an_ability_pick_comes_first_and_falls_back_to_the_closest() -> void:
	# The Barn Owl hunts Ranged (styles.json "hunt"): with none about it
	# takes the closest; when that one falls it's off after a Ranged over a
	# closer Tank; and on its way, a closer enemy doesn't draw it off.
	var sim := _sim()
	var commit := _ticks(sim, "commit_seconds")
	var owl: BattleSim.Fighter = _ready_now(sim.spawn(0, "barn_owl", 8 * T, 15 * T))[0]
	owl.hp = 1000000
	owl.max_hp = 1000000
	var tank: BattleSim.Fighter = _ready_now(sim.spawn(1, "snapping_turtle", 8 * T, 13 * T))[0]
	_statue(tank)
	sim.step()
	check(owl.target == tank, "no Ranged about: the closest")
	var shooter: BattleSim.Fighter = _ready_now(sim.spawn(1, "gray_squirrel", 4 * T, 5 * T))[0]
	var bear: BattleSim.Fighter = _ready_now(sim.spawn(1, "brown_bear", 10 * T, 11 * T))[0]
	for f in sim.fighters:
		if f.team == 1:
			_statue(f)
	for i in commit:
		sim.step()
	tank.alive = false
	sim.step()
	check(owl.target != null and owl.target.card.id == "gray_squirrel", "its target gone: a Ranged, though a Tank's closer")
	var prey := owl.target
	for f in _ready_now(sim.spawn(1, "hippopotamus", owl.x, owl.y - T)):
		_statue(f)
	for i in commit * 2:
		sim.step()
	check(owl.target == prey, "and a closer Tank turning up doesn't draw it off")
	check(bear.alive, "(the bear's still about)")


func test_the_same_rules_in_an_army_fight() -> void:
	# Draft Duel's armies go through the same rules: no switch for a threat,
	# a closer enemy or an ability's pick sooner than the commit time after
	# the last switch (only a target falling or slipping away is sooner).
	var m := DraftMatch.new(3)
	m.herds[0] = [{"id": "brown_bear", "stars": 1, "squads": 2}, {"id": "wild_boar", "stars": 1, "squads": 2},
		{"id": "gray_squirrel", "stars": 1, "squads": 2}, {"id": "red_fox", "stars": 1, "squads": 1}]
	m.herds[1] = [{"id": "snapping_turtle", "stars": 1, "squads": 2}, {"id": "lion", "stars": 1, "squads": 1},
		{"id": "striped_skunk", "stars": 1, "squads": 2}, {"id": "barn_owl", "stars": 1, "squads": 1}]
	for team in 2:
		m.picks_left[team] = 0
		m.picks_made[team] = []
	m._lay_out_herds()
	m.set_ready(0)
	m.set_ready(1)
	var sim: BattleSim = m.sim
	var commit := _ticks(sim, "commit_seconds")
	var last := {}
	var since := {}
	var early := 0
	var chosen := 0
	var whys := {}
	for i in 60 * sim.tps:
		if m.phase != "fight":
			break
		m.step()
		sim.take_events()
		for f: BattleSim.Fighter in sim.fighters:
			if not f.alive or not f.is_unit() or f.target == null:
				continue
			if last.has(f.uid) and last[f.uid] != f.target:
				var why := String(f.memory.get("locked_why", "lost"))
				whys[why] = int(whys.get(why, 0)) + 1
				if why != "lost":
					chosen += 1
					if int(f.memory.get("locked", sim.tick)) - int(since.get(f.uid, -100000)) < commit:
						early += 1
				since[f.uid] = int(f.memory.get("locked", sim.tick))
			last[f.uid] = f.target
	check(chosen > 0, "animals do switch by choice now and then (%s)" % [whys])
	check_eq(early, 0, "never sooner than the commit time after the last switch")
