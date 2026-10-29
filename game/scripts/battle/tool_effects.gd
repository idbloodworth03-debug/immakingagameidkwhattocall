class_name ToolEffects
extends RefCounted
## What each Ranger tool does when used. A tool's "ability" id in tools.json
## picks the effect; its numbers come from the tool's "stats" and "params"
## and grow 10% per card level like animal stats.

const KNOWN := ["net", "air_horn", "bait", "medkit", "tranq_dart", "flare"]


static func use(sim: BattleSim, team: int, card: Dictionary, level: int, x: int, y: int) -> void:
	var stats: Dictionary = card.stats
	var params: Dictionary = card.ability.get("params", {})
	var effect: String = card.ability.id
	var radius := roundi(float(stats.get("radius", 0)) * BattleSim.TILE)
	sim.events.append({"type": "tool", "effect": effect, "card": card.id, "team": team, "x": x, "y": y, "radius": radius})

	match effect:
		"net":
			for enemy in sim.enemies_near(team, x, y, radius):
				sim.deal_damage(enemy, _scaled(card, level, stats.damage), null)
				sim.stun(enemy, _ticks(sim, params.stun))
		"air_horn":
			_blast(sim, team, card, level, x, y, radius)
			for enemy in sim.enemies_near(team, x, y, radius):
				sim.knock_back(enemy, x, y, roundi(float(params.knockback) * BattleSim.TILE))
		"flare":
			_blast(sim, team, card, level, x, y, radius)
			for enemy in sim.enemies_near(team, x, y, radius):
				enemy.revealed = maxi(enemy.revealed, _ticks(sim, params.reveal))
		"bait":
			sim.make_bait(team, x, y, _scaled(card, level, stats.hp), _ticks(sim, stats.duration), radius)
		"medkit":
			for ally in sim.allies_near(team, x, y, radius):
				sim.heal(ally, _scaled(card, level, stats.heal))
		"tranq_dart":
			var closest: BattleSim.Fighter = null
			var closest_dist := 1 << 40
			for enemy in sim.enemies_near(team, x, y, radius):
				var d := BattleSim.dist_to_point(enemy, x, y)
				if d < closest_dist:
					closest = enemy
					closest_dist = d
			if closest != null:
				var duration := _ticks(sim, stats.duration)
				if BattleAbilities.is_fearless(closest):
					sim.slow_down(closest, 50, duration, true)
				else:
					sim.stun(closest, duration)
				sim.events.append({"type": "sleep", "x": closest.x, "y": closest.y})


## Damage to every enemy in the area; towers take a share.
static func _blast(sim: BattleSim, team: int, card: Dictionary, level: int, x: int, y: int, radius: int) -> void:
	var damage := _scaled(card, level, card.stats.damage)
	var tower_damage := damage * int(card.stats.get("tower_damage_pct", 0)) / 100
	for enemy in sim.enemies_near(team, x, y, radius, true):
		sim.deal_damage(enemy, tower_damage if enemy.kind == "tower" else damage, null)


static func _scaled(card: Dictionary, level: int, value: Variant) -> int:
	var growth := float(GameData.progression.stat_growth_per_level)
	return CardRules.stat_at_level(float(value), level, GameData.start_level(card.rarity), growth)


static func _ticks(sim: BattleSim, seconds: Variant) -> int:
	return roundi(float(seconds) * sim.tps)
