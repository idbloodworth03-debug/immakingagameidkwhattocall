extends TestCase
## The Mythics' upgraded abilities (data/styles.json, BattleStyles): the
## Yeti's frost, Cerberus's fire breath, the Unicorn's healing beam, the
## Dragon's scattering flames and the Kraken's ink; and the computer bans at
## most one Mythic a match (draft_rules.json bans "most_mythic").

const T := BattleSim.TILE


func _sim() -> BattleSim:
	var rules: Dictionary = GameData.battle_rules.duplicate(true)
	rules.damage_variance_pct = 0
	return BattleSim.new([{}, {}], 1, rules)


func _one(sim: BattleSim, team: int, id: String, x: float, y: float) -> BattleSim.Fighter:
	var f: BattleSim.Fighter = sim.spawn_units(team, id, 1, roundi(x * T), roundi(y * T))[0]
	f.deploy_ticks = 0
	return f


## Sturdy and harmless: it can take a beating and bites for nothing.
func _dummy(f: BattleSim.Fighter) -> BattleSim.Fighter:
	f.hp = 1000000
	f.max_hp = 1000000
	f.damage = 0
	return f


func _events(sim: BattleSim, seconds: float, kind: String) -> Array:
	var out := []
	for i in roundi(seconds * sim.tps):
		sim.step()
		for e in sim.take_events():
			if e.type == kind:
				out.append(e)
	return out


func test_card_lines() -> void:
	for id in ["yeti", "cerberus", "unicorn", "dragon", "kraken"]:
		var line := String(GameData.styles[id].line)
		check(line.split(" ", false).size() <= 8, "%s's card line is 8 words or fewer (%s)" % [id, line])
	check(String(GameData.styles.yeti.line).contains("frost"), "the Yeti's line tells of its frost")
	check(String(GameData.styles.cerberus.line).contains("fire"), "Cerberus's of its fire")
	check(String(GameData.styles.unicorn.line).contains("heals"), "the Unicorn's of its healing")
	check(String(GameData.styles.dragon.line).contains("scatter"), "the Dragon's of its scattering flames")
	check(String(GameData.styles.kraken.line).contains("ink"), "the Kraken's of its ink")


func test_yeti_frost_slows_and_a_second_pound_freezes() -> void:
	var sim := _sim()
	var yeti := _dummy(_one(sim, 0, "yeti", 8, 10))
	yeti.damage = 1
	var bear := _dummy(_one(sim, 1, "brown_bear", 8, 8.9))
	var s: Dictionary = GameData.styles.yeti
	# Three hits: the pound, and a frost patch where it landed.
	for i in 3:
		sim.attack(yeti, bear)
	var patch: Array = sim.zones.filter(func(z): return z.has("frost"))
	check_eq(patch.size(), 1, "the pound leaves a frost patch")
	if patch.is_empty():
		return
	check_eq(int(patch[0].ticks), roundi(float(s.frost_seconds) * sim.tps), "for frost_seconds")
	# The bear walks back in onto the frost: slowed, moving and attacking.
	bear.x = yeti.x
	bear.y = yeti.y - yeti.radius - bear.radius - 50
	bear.stun = 9999
	sim.step()
	check(bear.slow > 0 and bear.slow_pct == int(s.frost_slow_pct), "on the frost it moves %d%% slower" % int(s.frost_slow_pct))
	check(BattleStyles.haste_pct(sim, bear) <= -int(s.frost_attack_pct), "and attacks slower")
	# A flyer over it isn't slowed.
	var falcon := _dummy(_one(sim, 1, "peregrine_falcon", 8, 9.6))
	sim.step()
	check(falcon.slow <= 0, "a flyer passes over it")
	# The next pound freezes it solid: it was still on the frost.
	bear.stun = 0
	for i in 3:
		sim.attack(yeti, bear)
	check(int(bear.memory.get("frozen_until", -1)) > sim.tick, "a second pound freezes it")
	check(bear.stun >= roundi(float(s.freeze_seconds) * sim.tps) - 1, "for freeze_seconds")
	# One off the frost isn't frozen, just knocked back as before.
	var boar := _dummy(_one(sim, 1, "wild_boar", 9.6, 10.2))
	boar.memory.erase("frost_until")
	var gap := BattleSim.dist(yeti, boar)
	for i in 3:
		sim.attack(yeti, bear)
	check(int(boar.memory.get("frozen_until", -1)) <= sim.tick, "one that wasn't on the frost isn't frozen")
	check(BattleSim.dist(yeti, boar) > gap, "just knocked back")


func test_cerberus_knockout_lights_a_fire_breathing_head() -> void:
	var sim := _sim()
	var cerberus := _dummy(_one(sim, 0, "cerberus", 8, 10))
	cerberus.damage = 300
	var weak := _one(sim, 1, "gray_squirrel", 8, 9.2)
	weak.hp = 1
	var front := _dummy(_one(sim, 1, "brown_bear", 8, 8.9))
	# About 30 degrees off: inside the cone.
	var beside := _dummy(_one(sim, 1, "wild_boar", 8.6, 9.0))
	var behind := _dummy(_one(sim, 1, "wild_boar", 8, 13))
	for e in [front, beside, behind]:
		e.stun = 9999
	check_eq(int(cerberus.memory.get("fire", 0)), 0, "no fire to begin with")
	sim.attack(cerberus, weak)
	check(not weak.alive, "a knockout")
	check_eq(int(cerberus.memory.get("fire", 0)), 1, "lights a head")
	sim.take_events()
	sim.attack(cerberus, front)
	var breaths := sim.take_events().filter(func(e): return e.type == "fire_breath")
	check_eq(breaths.size(), 1, "its next attack breathes fire")
	check_eq(int(cerberus.memory.get("fire", 0)), 0, "spending the lit head")
	check(int(front.memory.get("burn", 0)) > 0 and int(beside.memory.get("burn", 0)) > 0, "everyone in the cone burns")
	check(int(behind.memory.get("burn", 0)) == 0, "not one behind it")
	# The burn hurts over time, with no more bites.
	cerberus.stun = 9999
	var hp := front.hp
	for i in sim.tps:
		sim.step()
	check(front.hp < hp, "burning hurts (%d a second)" % (hp - front.hp))
	check_eq(hp - front.hp, int(GameData.styles.cerberus.fire_dps_pct) * cerberus.damage / 100, "fire_dps_pct of its bite a second")
	# Never more lit heads than fire_most.
	cerberus.memory.fire = int(GameData.styles.cerberus.fire_most)
	cerberus.stun = 0
	var more := _one(sim, 1, "gray_squirrel", 7.4, 9.4)
	more.hp = 1
	var head := _one(sim, 1, "gray_squirrel", 8.6, 9.4)
	head.hp = 1
	sim.attack(cerberus, more)
	check(int(cerberus.memory.fire) <= int(GameData.styles.cerberus.fire_most), "at most fire_most lit heads")


func test_unicorn_beam_heals_the_teammates_it_passes() -> void:
	var sim := _sim()
	var unicorn := _one(sim, 0, "unicorn", 8, 16)
	var front := _one(sim, 0, "brown_bear", 8, 13.5)
	var aside := _one(sim, 0, "wild_boar", 11, 13.5)
	var full := _one(sim, 0, "snapping_turtle", 8.1, 12.5)
	var enemy := _dummy(_one(sim, 1, "wild_boar", 8, 10))
	enemy.stun = 9999
	front.hp = front.max_hp / 2
	aside.hp = aside.max_hp / 2
	var before := [front.hp, aside.hp]
	sim.attack(unicorn, enemy)
	var heal := unicorn.damage * int(GameData.styles.unicorn.heal_pct) / 100
	check_eq(front.hp - int(before[0]), heal, "the teammate in the beam is healed heal_pct of its bite")
	check_eq(aside.hp, int(before[1]), "not one off to the side")
	check_eq(full.hp, full.max_hp, "never above full health")
	var heals := sim.take_events().filter(func(e): return e.type == "beam_heal")
	check_eq(heals.size(), 1, "one heal shown (the one it really healed)")
	check(enemy.hp < enemy.max_hp, "and the beam still hurts the enemy")


func test_dragon_fire_scatters_the_enemies_it_touches() -> void:
	var sim := _sim()
	var dragon := _dummy(_one(sim, 0, "dragon", 8, 15))
	var boar := _dummy(_one(sim, 1, "wild_boar", 8, 10))
	boar.damage = 10
	var badger := _dummy(_one(sim, 1, "honey_badger", 8.2, 9.2))
	var bear := _dummy(_one(sim, 0, "brown_bear", 8, 9.0))
	bear.stun = 9999
	var scared := []
	var hits_while_scared := 0
	var start := Vector2.ZERO
	var ran := 0.0
	for i in 4 * sim.tps:
		sim.step()
		for e in sim.take_events():
			if e.type == "scared":
				scared.append(int(e.uid))
				if int(e.uid) == boar.uid:
					start = Vector2(boar.x, boar.y)
			if e.type == "hit" and int(e.from) == boar.uid and int(boar.memory.get("scared_until", -1)) > sim.tick:
				hits_while_scared += 1
		if int(boar.memory.get("scared_until", -1)) > sim.tick:
			ran = maxf(ran, Vector2(boar.x, boar.y).distance_to(start))
	check(scared.has(boar.uid), "the boar touching the fire panics")
	check_eq(scared.count(boar.uid), 1, "once a run")
	check_eq(hits_while_scared, 0, "and doesn't attack while it does")
	check(ran > 200, "it runs out of the flames (%d)" % ran)
	check(not scared.has(badger.uid), "the fearless Honey Badger stands firm")


func test_kraken_ink_blinds_ranged_and_air() -> void:
	var sim := _sim()
	var kraken := _dummy(_one(sim, 0, "kraken", 8, 12))
	kraken.damage = 1
	var squirrel := _dummy(_one(sim, 1, "gray_squirrel", 8, 10.8))
	squirrel.damage = 10
	var raccoon := _dummy(_one(sim, 1, "raccoon", 8, 6.5))
	raccoon.damage = 10
	var bear := _dummy(_one(sim, 1, "brown_bear", 9.2, 11.2))
	bear.damage = 10
	sim.attack(kraken, squirrel)
	var clouds: Array = sim.zones.filter(func(z): return z.has("ink"))
	check_eq(clouds.size(), 1, "after its slams, a cloud of ink")
	if clouds.is_empty():
		return
	var cloud: Dictionary = clouds[0]
	check_eq(int(cloud.ticks), roundi(float(GameData.styles.kraken.ink_seconds) * sim.tps), "for ink_seconds")
	sim.take_events()
	kraken.stun = 9999
	var hits := {}
	var misses := 0
	for i in roundi(float(GameData.styles.kraken.ink_seconds) * sim.tps) - 2:
		sim.step()
		for e in sim.take_events():
			if e.type == "hit":
				hits[int(e.from)] = int(hits.get(int(e.from), 0)) + 1
			if e.type == "blind_miss":
				misses += 1
	check_eq(int(hits.get(squirrel.uid, 0)), 0, "a Ranged animal in the ink can't hit")
	check_eq(int(hits.get(raccoon.uid, 0)), 0, "nor one shooting into it from afar")
	check(misses > 0, "its shots fizzle (%d)" % misses)
	check(int(hits.get(bear.uid, 0)) > 0, "a biter in the ink still bites")
	# Once the ink's gone, they shoot again.
	var after := 0
	for i in 4 * sim.tps:
		sim.step()
		for e in sim.take_events():
			if e.type == "hit" and int(e.from) == squirrel.uid:
				after += 1
	check(after > 0, "after the ink clears, it hits again")


func test_the_computer_bans_at_most_one_mythic() -> void:
	check_eq(int(GameData.draft_rules.bans.most_mythic), 1, "most_mythic in draft_rules.json")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var owned: Array = GameData.card_order.filter(func(id): return not GameData.is_tool(id))
	var levels := {}
	for id in owned:
		levels[id] = GameData.start_level(GameData.cards[id].rarity)
	var with_one := 0
	var most := 0
	var runs := 300
	for i in runs:
		var rival: Dictionary = GameData.rivals[i % GameData.rivals.size()]
		var phase := BanPhase.new(BanPhase.choices_for(owned, int(rival.get("arena_index", 0))), owned, 1)
		var mythics := 0
		for k in phase.per_player:
			var id := phase.bot_choice(rival.get("style", {}), levels, rng, float(rival.get("difficulty", 0.5)))
			if id == "" or not phase.ban(1, id):
				break
			if GameData.cards[id].rarity == "mythic":
				mythics += 1
			var theirs: Array = phase.usable().filter(func(x): return phase.can_ban(0, x) == "")
			if not theirs.is_empty():
				phase.ban(0, theirs[rng.randi() % theirs.size()])
		most = maxi(most, mythics)
		if mythics > 0:
			with_one += 1
	check(most <= 1, "never more than one of your Mythics banned (%d)" % most)
	check(with_one > runs / 3, "but it still bans one in many matches (%d of %d)" % [with_one, runs])


func test_each_upgrade_shows_in_the_attack_styles_showcase() -> void:
	# Profile > Developer tools > Attack styles: each Mythic's little fight
	# shows its upgrade before it starts over (as many times as it loops).
	var showcase: GDScript = load("res://scripts/ui/style_showcase.gd")
	var wanted := {"yeti": ["frost", "freeze"], "cerberus": ["head_lit", "fire_breath"], "unicorn": ["beam_heal"],
		"dragon": ["scared"], "kraken": ["ink", "blind_miss"]}
	for id: String in wanted:
		for seed_value in [7, 11, 23]:
			var sim: BattleSim = showcase.stage_sim(id, seed_value)
			var seen := {}
			for i in roundi(showcase.stage_seconds(id) * sim.tps):
				sim.step()
				for e in sim.take_events():
					seen[String(e.type)] = true
				if sim.units(0).is_empty() or sim.units(1).is_empty():
					break
			for kind: String in wanted[id]:
				check(seen.has(kind), "%s's showcase (seed %d) shows its %s" % [id, seed_value, kind])
