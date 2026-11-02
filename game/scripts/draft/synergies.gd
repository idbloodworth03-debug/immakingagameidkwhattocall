class_name Synergies
extends RefCounted
## Habitat synergies in Draft Duel (data/synergies.json). Every animal has a
## habitat. A herd with 2, 4 or 6 different animals of one habitat (copies
## of the same animal count once) turns on that habitat's bonus, stronger at
## each tier. Bonuses go to that habitat's own animals when a fight starts,
## except City, which pays Acorns at the start of each round.


static func habitat_of(card_id: String) -> String:
	return String(GameData.get_card(card_id).get("habitat", ""))


static func info(habitat: String) -> Dictionary:
	return GameData.synergies.get(habitat, {})


## How many different animals of each habitat are in `herd` (herd entries
## with an "id"): {habitat: count}.
static func counts(herd: Array) -> Dictionary:
	var seen := {}
	var result := {}
	for entry in herd:
		var id: String = entry.id
		if seen.has(id) or GameData.is_tool(id):
			continue
		seen[id] = true
		var habitat := habitat_of(id)
		if habitat != "":
			result[habitat] = int(result.get(habitat, 0)) + 1
	return result


## The tier a count reaches: 0 (none) up to the number of tiers.
static func tier_for(count: int) -> int:
	var tier := 0
	for needed in GameData.synergy_tiers:
		if count >= int(needed):
			tier += 1
	return tier


## How many animals the next tier needs (or the top tier's, when it's reached).
static func next_needed(count: int) -> int:
	for needed in GameData.synergy_tiers:
		if count < int(needed):
			return int(needed)
	return int(GameData.synergy_tiers[-1]) if not GameData.synergy_tiers.is_empty() else 0


## The active tiers of a herd: {habitat: tier (1 and up)}.
static func active(herd: Array) -> Dictionary:
	var result := {}
	var all := counts(herd)
	for habitat in all:
		var tier := tier_for(int(all[habitat]))
		if tier > 0:
			result[habitat] = tier
	return result


## A habitat's bonus value at a tier (1 and up).
static func value(habitat: String, tier: int) -> float:
	var values: Array = info(habitat).get("values", [])
	if tier <= 0 or values.is_empty():
		return 0.0
	return float(values[mini(tier, values.size()) - 1])


## The one-line description of a habitat's bonus at a tier (1 and up).
static func describe(habitat: String, tier: int) -> String:
	var v := value(habitat, maxi(tier, 1))
	var text: String = info(habitat).get("text", "")
	return text.replace("{v}", str(roundi(v)) if is_equal_approx(v, roundf(v)) else str(v))


## Gives `team`'s animals on `battle` their habitat bonuses, from the herd
## the fight started with. Called once, as the fight starts.
static func apply(battle: BattleSim, team: int, herd: Array) -> void:
	var tiers := active(herd)
	if tiers.is_empty():
		return
	for f in battle.units(team):
		var habitat := habitat_of(f.card.id)
		if not tiers.has(habitat):
			continue
		var v := value(habitat, int(tiers[habitat]))
		f.memory.habitat_bonus = habitat
		match String(info(habitat).get("effect", "")):
			"attack_speed":
				f.hit_ticks = maxi(1, roundi(f.hit_ticks * 100.0 / (100.0 + v)))
			"regen":
				f.memory.regen_pct = v
			"shield":
				f.shield += roundi(f.max_hp * v / 100.0)
			"slow_on_hit":
				f.memory.chill_pct = roundi(v)
				f.memory.chill_ticks = roundi(float(info(habitat).get("seconds", 2)) * battle.tps)
			"damage_reduction":
				f.memory.guard_pct = roundi(v)
			"damage":
				f.damage = roundi(f.damage * (100.0 + v) / 100.0)
			"health":
				f.max_hp = roundi(f.max_hp * (100.0 + v) / 100.0)
				f.hp = f.max_hp
			"speed":
				f.speed = roundi(f.speed * (100.0 + v) / 100.0)


## Bonus Acorns a herd's synergies pay at the start of a round (City).
static func round_acorns(herd: Array) -> int:
	var total := 0
	var tiers := active(herd)
	for habitat in tiers:
		if String(info(habitat).get("effect", "")) == "acorns":
			total += roundi(value(habitat, int(tiers[habitat])))
	return total
