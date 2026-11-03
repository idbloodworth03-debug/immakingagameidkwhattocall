class_name BattleAbilities
extends RefCounted
## The Specialists' traits in battle (classes.json "traits"):
##
## - Burrow: starts underground, travels unseen to just behind the enemy's
##   last row and pops up there.
## - Splash: every hit also hits enemies around the target (a share of it).
## - Stun: every few hits freezes the target for a moment.
## - Slow: hits make the target move and attack slower for a while.
##
## Every other animal fights by its class alone (see BattleSim). BattleSim
## calls these hooks at the right moments; an animal's trait is its
## "ability" here, and the numbers come from classes.json.

const KNOWN := ["burrow", "splash", "stun", "slow"]


## Nothing is immune to stuns or slows any more (the old "fearless").
static func is_fearless(_f: BattleSim.Fighter) -> bool:
	return false


static func ticks(sim: BattleSim, seconds: Variant) -> int:
	return roundi(float(seconds) * sim.tps)


static func tiles(value: Variant) -> int:
	return roundi(float(value) * BattleSim.TILE)


# --- Placing an animal -----------------------------------------------------

static func on_spawn(_sim: BattleSim, f: BattleSim.Fighter, _first: bool) -> void:
	if f.ability_id() == "burrow":
		f.memory.burrowing = true


# --- Every tick ------------------------------------------------------------

static func on_tick_effects(_sim: BattleSim, _f: BattleSim.Fighter) -> void:
	pass


static func on_tick(_sim: BattleSim, _f: BattleSim.Fighter) -> void:
	pass


static func speed_bonus_pct(_sim: BattleSim, _f: BattleSim.Fighter) -> int:
	return 0


static func on_moved(_sim: BattleSim, _f: BattleSim.Fighter) -> void:
	pass


# --- Attacking -------------------------------------------------------------

## Class counters: extra damage from one class to another (classes.json).
static func outgoing_damage(_sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter, amount: int) -> int:
	if not t.is_unit():
		return amount
	var pct := counter_pct(f.cls, t.cls)
	return amount * (100 + pct) / 100 if pct != 0 else amount


## The extra damage (percent) class `from` does to class `to`.
static func counter_pct(from: String, to: String) -> int:
	for counter in GameData.class_rules.get("counters", []):
		if counter.get("from", "") == from and counter.get("to", "") == to:
			return int(counter.get("pct", 0))
	return 0


static func after_hit(sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter, amount: int) -> void:
	match f.ability_id():
		"splash":
			var share := amount * int(f.param("pct", 60)) / 100
			var hit_any := false
			for enemy in sim.enemies_near(f.team, t.x, t.y, tiles(f.param("radius", 1.5))):
				if enemy != t and (not enemy.is_flying() or f.targets == "air_ground"):
					sim.deal_damage(enemy, share, f)
					hit_any = true
			if hit_any:
				sim.events.append({"type": "splash", "x": t.x, "y": t.y, "radius": tiles(f.param("radius", 1.5))})
		"stun":
			f.memory.hits = int(f.memory.get("hits", 0)) + 1
			if int(f.memory.hits) % maxi(1, int(f.param("every", 3))) == 0 and t.is_unit():
				sim.stun(t, ticks(sim, f.param("seconds", 1.0)))
				sim.events.append({"type": "stun", "uid": t.uid, "x": t.x, "y": t.y})
		"slow":
			if t.is_unit() and t.alive:
				sim.slow_down(t, int(f.param("pct", 40)), ticks(sim, f.param("seconds", 2.0)))


# --- Taking damage ---------------------------------------------------------

static func incoming_damage(_sim: BattleSim, t: BattleSim.Fighter, amount: int, _source: BattleSim.Fighter) -> int:
	if t.invulnerable > 0:
		return 0
	if t.shield > 0:
		var absorbed := mini(t.shield, amount)
		t.shield -= absorbed
		amount -= absorbed
	return amount


static func after_damaged(_sim: BattleSim, _t: BattleSim.Fighter) -> void:
	pass


static func prevent_defeat(_sim: BattleSim, _t: BattleSim.Fighter) -> bool:
	return false


static func on_defeated(_sim: BattleSim, _t: BattleSim.Fighter, _source: BattleSim.Fighter) -> void:
	pass
