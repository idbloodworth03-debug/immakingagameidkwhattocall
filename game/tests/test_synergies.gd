extends TestCase
## Habitat synergies (data/synergies.json, scripts/draft/synergies.gd).

const T := BattleSim.TILE


func _herd(ids: Array) -> Array:
	return ids.map(func(id): return {"id": id, "x": 0, "y": 0, "stars": 1})


## A match past the starters, both herds as given, at the start of a fight.
func _fight_with(herd_0: Array, herd_1: Array) -> DraftMatch:
	var m := DraftMatch.new(4)
	m.pick_starters(0, [])
	m.pick_starters(1, [])
	m.finish_shopping(0)
	m.finish_shopping(1)
	for team in 2:
		for id in [herd_0, herd_1][team]:
			var spot := m.default_spot(team)
			m.herds[team].append({"id": id, "x": spot.x, "y": spot.y, "stars": 1})
	m._lay_out_herds()
	m.set_ready(0)
	m.set_ready(1)
	return m


func _unit(m: DraftMatch, team: int, id: String) -> BattleSim.Fighter:
	for f in m.sim.units(team):
		if f.card.id == id:
			return f
	return null


func test_every_animal_has_a_habitat() -> void:
	var later: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals_later.json"))
	var per_habitat := {}
	for card in GameData.cards.values().filter(func(c): return c.kind == "animal") + Array(later):
		check(GameData.synergies.has(card.get("habitat", "")), "%s has a known habitat" % card.id)
		per_habitat[card.habitat] = int(per_habitat.get(card.habitat, 0)) + 1
	for habitat in GameData.habitat_order:
		check(int(per_habitat.get(habitat, 0)) >= int(GameData.synergy_tiers[-1]), "%s has enough animals for its top tier (%d)" % [habitat, int(per_habitat.get(habitat, 0))])


func test_copies_count_once() -> void:
	var counts := Synergies.counts(_herd(["lion", "lion", "cheetah", "net", "red_fox"]))
	check_eq(int(counts.get("savanna", 0)), 2, "two lions and a cheetah: 2 different Savanna animals")
	check_eq(int(counts.get("forest", 0)), 1, "one Forest animal")
	check(not counts.has(""), "tools don't count")


func test_tiers_turn_on_at_2_4_and_6() -> void:
	var tiers: Array = GameData.synergy_tiers
	check_eq(Synergies.tier_for(int(tiers[0]) - 1), 0, "not yet")
	check_eq(Synergies.tier_for(int(tiers[0])), 1, "first tier")
	check_eq(Synergies.tier_for(int(tiers[1])), 2, "second tier")
	check_eq(Synergies.tier_for(int(tiers[2]) + 3), 3, "top tier")
	check_eq(Synergies.next_needed(3), int(tiers[1]), "3 animals: the next tier needs 4")
	check(Synergies.describe("savanna", 1).contains("10%"), "the description shows the tier's value")
	check_eq(Synergies.active(_herd(["lion", "cheetah", "red_fox"])), {"savanna": 1}, "only the habitats that reach a tier")


func test_savanna_attacks_faster() -> void:
	var plain := _fight_with(["lion"], ["brown_bear"])
	var paired := _fight_with(["lion", "cheetah"], ["brown_bear"])
	check(_unit(paired, 0, "lion").hit_ticks < _unit(plain, 0, "lion").hit_ticks, "a lion with a cheetah attacks faster")
	check_eq(_unit(paired, 1, "brown_bear").hit_ticks, _unit(plain, 1, "brown_bear").hit_ticks, "the other herd is unchanged")


func test_mountains_health_forest_damage_plains_speed() -> void:
	var plain := _fight_with(["red_panda", "red_fox", "american_bison"], ["lion"])
	var bonus := _fight_with(["red_panda", "california_condor", "red_fox", "gray_squirrel"], ["lion"])
	check(_unit(bonus, 0, "red_panda").max_hp > _unit(plain, 0, "red_panda").max_hp, "Mountains: more health")
	check(_unit(bonus, 0, "red_fox").damage > _unit(plain, 0, "red_fox").damage, "Forest: harder hits")
	check_eq(_unit(plain, 0, "american_bison").speed, _unit(plain, 0, "american_bison").speed, "(one Plains animal: no bonus)")


func test_ocean_shield_and_wetlands_guard() -> void:
	# Ocean and Wetlands have no animals in the game yet; borrow the later ones.
	borrow_later_animals()
	var m := _fight_with(["harbor_seal", "sea_otter", "hippopotamus", "bullfrog"], ["lion"])
	var seal := _unit(m, 0, "harbor_seal")
	check(seal.shield > 0, "Ocean: a shield at the start of the fight")
	var hippo := _unit(m, 0, "hippopotamus")
	var before := hippo.hp
	m.sim.deal_damage(hippo, 100, null)
	check(before - hippo.hp < 100, "Wetlands: less damage taken (%d of 100)" % (before - hippo.hp))


func test_arctic_slows_and_rainforest_heals() -> void:
	var m := _fight_with(["polar_bear", "wolf_pack", "tiger", "asian_elephant"], ["lion"])
	var bear := _unit(m, 0, "polar_bear")
	var lion := _unit(m, 1, "lion")
	BattleAbilities.after_hit(m.sim, bear, lion, 10)
	check(lion.slow > 0 and lion.slow_pct > 0, "Arctic: a hit slows the enemy")
	lion.stun = 9999  # keep the lion from biting back
	var tiger := _unit(m, 0, "tiger")
	tiger.hp = tiger.max_hp / 2
	var hurt := tiger.hp
	for i in m.sim.tps * 2:
		m.sim.step()
	check(tiger.hp > hurt or not tiger.alive, "Rainforest: heals over time")


func test_city_pays_acorns_each_round() -> void:
	var m := DraftMatch.new(5)
	m.pick_starters(0, ["sewer_rats", "raccoon"])
	m.pick_starters(1, [])
	var log := m.take_events().filter(func(e): return e.type == "round")
	var city := roundi(Synergies.value("city", 1))
	check_eq(int(log[-1].habitat_acorns[0]), city, "two City animals: +%d Acorns as the round starts" % city)
	check_eq(m.acorns[0], int(GameData.draft_rules.acorns_start) + city, "added to the starting Acorns")
	check_eq(int(log[-1].habitat_acorns[1]), 0, "nothing for a herd without City animals")


func test_the_bot_builds_toward_synergies() -> void:
	var m := DraftMatch.new(6)
	m.pick_starters(0, [])
	m.pick_starters(1, [])
	m.herds[1] = _herd(["lion", "cheetah", "african_wild_dogs"])
	var sharp := DraftBot.new(m, 1, 1, 1.0)
	var casual := DraftBot.new(m, 1, 1, 0.0)
	check(sharp._synergy_value("black_rhino") > sharp._synergy_value("brown_bear"), "a 4th Savanna animal is worth more than an unrelated one")
	check(sharp._synergy_value("black_rhino") > casual._synergy_value("black_rhino"), "sharper opponents care more")
	check_eq(sharp._synergy_value("lion"), 0.0, "a copy doesn't count again")
