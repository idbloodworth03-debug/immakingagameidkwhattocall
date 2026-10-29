class_name BattleAbilities
extends RefCounted
## What every animal ability does in battle.
##
## Each animal in animals.json has an ability "id" that matches one of the
## types below, with its numbers in "params". Many animals share a type (the
## Rattlesnake, Platypus, King Cobra and Komodo Dragon all use "poison"), so
## each type is written once. BattleSim calls these hooks at the right moments.

const KNOWN := [
	"bonus_vs_tag", "burrow", "charge", "colony_bonus", "damage_reduction", "death_cloud",
	"deploy_haste", "dive_bomb", "dodge", "energy_boost", "energy_steal", "fearless", "grab",
	"habitat_bonus", "heal_aura", "heal_burst", "heal_on_death", "heal_on_kill",
	"invulnerable_once", "jump_river", "knockback", "pack_bonus", "poison", "pounce",
	"protect_aura", "pull", "pulse_stun", "rage_aura", "regenerate", "revive_once", "shield",
	"slow_burst", "slow_on_hit", "splash", "stealth", "stun_hits", "trample", "water_speed",
]


static func is_fearless(f: BattleSim.Fighter) -> bool:
	return f.ability_id() == "fearless"


## An ability number that grows with card level, like damage does.
static func scaled(f: BattleSim.Fighter, value: Variant) -> int:
	var growth := float(GameData.progression.stat_growth_per_level)
	return CardRules.stat_at_level(float(value), f.level, GameData.start_level(f.card.rarity), growth)


static func ticks(sim: BattleSim, seconds: Variant) -> int:
	return roundi(float(seconds) * sim.tps)


static func tiles(value: Variant) -> int:
	return roundi(float(value) * BattleSim.TILE)


# --- Placing an animal -----------------------------------------------------

## Right after an animal appears. `first` is true for the first animal of a
## group, so once-per-card effects (like stealing energy) happen once.
static func on_spawn(sim: BattleSim, f: BattleSim.Fighter, first: bool) -> void:
	match f.ability_id():
		"stealth":
			f.stealthed = true
		"shield":
			f.shield = scaled(f, f.param("amount"))
		"burrow":
			f.memory.burrowing = true
		"deploy_haste":
			f.memory.haste = ticks(sim, f.param("duration"))
		"energy_steal":
			if first:
				var enemy: BattleSim.Team = sim.teams[1 - f.team]
				enemy.energy = maxi(0, enemy.energy - int(f.param("amount")) * BattleSim.ENERGY_UNIT)
				sim.events.append({"type": "steal", "team": f.team, "x": f.x, "y": f.y})
		"heal_burst":
			if first:
				for ally in sim.allies_near(f.team, f.x, f.y, tiles(f.param("radius"))):
					sim.heal(ally, scaled(f, f.param("amount")))
				sim.events.append({"type": "heal", "x": f.x, "y": f.y, "radius": tiles(f.param("radius"))})
		"rage_aura":
			if first:
				_rage(sim, f)
		"slow_burst":
			if first:
				for enemy in sim.enemies_near(f.team, f.x, f.y, tiles(f.param("radius"))):
					sim.slow_down(enemy, int(f.param("pct")), ticks(sim, f.param("duration")))
				sim.events.append({"type": "scare", "x": f.x, "y": f.y, "radius": tiles(f.param("radius"))})
		"heal_aura":
			# With a duration, the animal plants a healing spot (Orangutan's
			# fruit tree). Without one, it heals around itself (see on_tick_effects).
			if first and float(f.param("duration", 0)) > 0.0:
				sim.add_zone({
					"team": f.team, "x": f.x, "y": f.y, "radius": tiles(f.param("radius")),
					"hps": scaled(f, f.param("hps")), "ticks": ticks(sim, f.param("duration")),
				})
				sim.events.append({"type": "tree", "x": f.x, "y": f.y, "radius": tiles(f.param("radius")), "seconds": float(f.param("duration"))})


static func _rage(sim: BattleSim, f: BattleSim.Fighter) -> void:
	var radius := tiles(f.param("radius", 0))
	var tag := String(f.param("tag", ""))
	var duration := ticks(sim, f.param("duration"))
	for ally in sim.units(f.team):
		if tag != "" and not ally.has_tag(tag):
			continue
		if radius > 0 and BattleSim.dist(ally, f) > radius + ally.radius:
			continue
		ally.rage = maxi(ally.rage, duration)
		ally.rage_damage_pct = maxi(ally.rage_damage_pct, int(f.param("damage_pct", 0)))
		ally.rage_speed_pct = maxi(ally.rage_speed_pct, int(f.param("speed_pct", 0)))
		ally.rage_attack_pct = maxi(ally.rage_attack_pct, int(f.param("attack_speed_pct", 0)))
	sim.events.append({"type": "rage", "x": f.x, "y": f.y, "radius": radius if radius > 0 else BattleSim.WIDTH})


# --- Every tick ------------------------------------------------------------

## Runs every tick, even while deploying or stunned.
static func on_tick_effects(sim: BattleSim, f: BattleSim.Fighter) -> void:
	if int(f.memory.get("playing_dead", 0)) > 0:
		f.memory.playing_dead -= 1
		if f.memory.playing_dead == 0:
			f.hp = maxi(1, int(f.memory.revive_hp))
			sim.events.append({"type": "revive", "x": f.x, "y": f.y})
		return

	var half_second := maxi(1, sim.tps / 2)
	if sim.tick % half_second != 0:
		return
	match f.ability_id():
		"regenerate":
			if f.param("only_idle", false) and sim.tick - int(f.memory.get("last_combat", -100000)) < 2 * sim.tps:
				return
			sim.heal(f, f.max_hp * int(f.param("pct_per_second")) / 200)
		"heal_aura":
			if float(f.param("duration", 0)) <= 0.0 and f.deploy_ticks <= 0:
				var tag := String(f.param("tag", ""))
				for ally in sim.allies_near(f.team, f.x, f.y, tiles(f.param("radius"))):
					if tag == "" or ally.has_tag(tag):
						sim.heal(ally, scaled(f, f.param("hps")) / 2)


## Runs every tick while the animal is deployed and able to act.
static func on_tick(sim: BattleSim, f: BattleSim.Fighter) -> void:
	if int(f.memory.get("haste", 0)) > 0:
		f.memory.haste -= 1
	match f.ability_id():
		"pounce":
			_try_pounce(sim, f)
		"pulse_stun":
			var left := int(f.memory.get("pulse", ticks(sim, f.param("interval")))) - 1
			if left <= 0:
				for enemy in sim.enemies_near(f.team, f.x, f.y, tiles(f.param("radius"))):
					sim.stun(enemy, ticks(sim, f.param("duration")))
				sim.events.append({"type": "stun_pulse", "x": f.x, "y": f.y, "radius": tiles(f.param("radius"))})
				left = ticks(sim, f.param("interval"))
			f.memory.pulse = left


static func _try_pounce(sim: BattleSim, f: BattleSim.Fighter) -> void:
	if f.memory.get("pounced", false):
		return
	var reach := tiles(f.param("range", 3))
	if String(f.param("target", "")) == "highest_hp":
		var best: BattleSim.Fighter = null
		for enemy in sim.fighters:
			if enemy.is_unit() and sim.can_target(f, enemy) and BattleSim.edge_distance(f, enemy) <= reach:
				if best == null or enemy.hp > best.hp:
					best = enemy
		if best != null:
			f.target = best
	var target: BattleSim.Fighter = f.target
	if target == null or not sim.can_target(f, target) or BattleSim.edge_distance(f, target) > reach:
		return
	var total := BattleSim.dist(f, target)
	var stop := f.radius + target.radius + f.attack_range / 2
	if total > stop:
		f.x = target.x + (f.x - target.x) * stop / total
		f.y = target.y + (f.y - target.y) * stop / total
	f.memory.pounced = true
	f.memory.pounce_bonus = true
	sim.events.append({"type": "pounce", "x": f.x, "y": f.y})


static func speed_bonus_pct(_sim: BattleSim, f: BattleSim.Fighter) -> int:
	var pct := 0
	if int(f.memory.get("haste", 0)) > 0:
		pct += int(f.param("speed_pct"))
	match f.ability_id():
		"water_speed":
			if BattleSim.bank(f.y) == 0:
				pct += int(f.param("pct"))
		"charge":
			if int(f.memory.get("run", 0)) >= tiles(f.param("distance")):
				pct += 100
	return pct


static func on_moved(sim: BattleSim, f: BattleSim.Fighter) -> void:
	match f.ability_id():
		"trample":
			var per_tick := scaled(f, f.param("dps")) / sim.tps
			for enemy in sim.enemies_near(f.team, f.x, f.y, f.radius + 150):
				if not enemy.is_flying():
					sim.deal_damage(enemy, per_tick, f)
		"knockback":
			# Tower-chasers like the Bison shove animals out of their way.
			if f.targets == "buildings":
				var cooldowns: Dictionary = f.memory.get("shoved", {})
				for enemy in sim.enemies_near(f.team, f.x, f.y, f.radius + 150):
					if not enemy.is_flying() and int(cooldowns.get(enemy.uid, -1)) <= sim.tick:
						sim.knock_back(enemy, f.x, f.y, tiles(f.param("distance")))
						cooldowns[enemy.uid] = sim.tick + sim.tps
				f.memory.shoved = cooldowns


# --- Attacking -------------------------------------------------------------

static func outgoing_damage(sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter, amount: int) -> int:
	var pct := 100
	match f.ability_id():
		"pack_bonus":
			var tag := String(f.param("tag"))
			var count := 0
			for ally in sim.allies_near(f.team, f.x, f.y, tiles(f.param("radius"))):
				if ally != f and ally.has_tag(tag):
					count += 1
			pct += int(f.param("damage_pct")) * mini(count, int(f.param("max_stacks", 5)))
		"charge":
			if int(f.memory.get("run", 0)) >= tiles(f.param("distance")):
				amount *= int(f.param("damage_mult"))
				f.memory.charged_hit = true
		"dive_bomb":
			if not f.memory.get("dived", false):
				amount *= int(f.param("damage_mult"))
				f.memory.dived = true
		"pounce":
			if f.memory.get("pounce_bonus", false):
				amount *= int(f.param("damage_mult"))
				f.memory.pounce_bonus = false
		"bonus_vs_tag":
			if t.has_tag(String(f.param("tag"))):
				pct += int(f.param("damage_pct"))
		"habitat_bonus":
			if absi(f.y - (BattleSim.RIVER_TOP + BattleSim.RIVER_BOTTOM) / 2) <= 2 * BattleSim.TILE:
				pct += int(f.param("damage_pct"))
		"colony_bonus":
			if _group_complete(sim, f):
				pct += int(f.param("pct"))
		"grab":
			if not f.memory.get("grabbed", false) and t.is_unit() and not t.is_flying():
				amount *= int(f.param("damage_mult"))
				f.memory.grabbed = true
				f.memory.grab_now = true
	return amount * pct / 100


static func after_hit(sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter, amount: int) -> void:
	match f.ability_id():
		"poison":
			if t.is_unit() and t.alive and not is_fearless(t):
				var duration := ticks(sim, f.param("duration"))
				t.poison_dps = maxi(t.poison_dps if t.poison > 0 else 0, scaled(f, f.param("dps")))
				t.poison = maxi(t.poison, duration)
				if int(f.param("anti_heal_pct", 0)) > 0:
					t.anti_heal = maxi(t.anti_heal, duration)
					t.anti_heal_pct = int(f.param("anti_heal_pct"))
		"stun_hits":
			f.memory.hits = int(f.memory.get("hits", 0)) + 1
			if int(f.memory.hits) % int(f.param("every")) == 0:
				sim.stun(t, ticks(sim, f.param("duration")))
		"slow_on_hit":
			sim.slow_down(t, int(f.param("pct")), ticks(sim, 1.5))
		"knockback":
			sim.knock_back(t, f.x, f.y, tiles(f.param("distance")))
		"pull":
			if t.flying and t.alive and not is_fearless(t):
				t.memory.grounded = ticks(sim, f.param("duration"))
		"splash":
			for enemy in sim.enemies_near(f.team, t.x, t.y, tiles(f.param("radius"))):
				if enemy != t and not enemy.is_flying():
					sim.deal_damage(enemy, amount, f)
		"charge":
			if f.memory.get("charged_hit", false):
				f.memory.charged_hit = false
				if float(f.param("stun", 0)) > 0.0:
					sim.stun(t, ticks(sim, f.param("stun")))
		"grab":
			if f.memory.get("grab_now", false):
				f.memory.grab_now = false
				sim.stun(t, ticks(sim, f.param("lift_seconds")))


# --- Taking damage ---------------------------------------------------------

static func incoming_damage(sim: BattleSim, t: BattleSim.Fighter, amount: int, source: BattleSim.Fighter) -> int:
	if t.invulnerable > 0 or int(t.memory.get("playing_dead", 0)) > 0:
		return 0
	if t.is_unit():
		for guardian in sim.units(t.team):
			if guardian.ability_id() == "protect_aura" and BattleSim.dist(guardian, t) <= tiles(guardian.param("radius")) + t.radius:
				amount = amount * (100 - int(guardian.param("pct"))) / 100
				break
	match t.ability_id():
		"dodge":
			if source != null and sim.rng.randi_range(1, 100) <= int(t.param("chance")):
				sim.events.append({"type": "dodge", "x": t.x, "y": t.y})
				return 0
		"damage_reduction":
			var applies := true
			if t.param("below_hp_pct", 0) != 0:
				applies = t.hp * 100 < t.max_hp * int(t.param("below_hp_pct"))
			if String(t.param("vs", "")) == "ranged":
				applies = source == null or source.kind == "tower" or source.attack_range > 1500
			if applies:
				amount = amount * (100 - int(t.param("pct"))) / 100
		"colony_bonus":
			if _group_complete(sim, t):
				amount = amount * 80 / 100
	if t.shield > 0:
		var absorbed := mini(t.shield, amount)
		t.shield -= absorbed
		amount -= absorbed
	return amount


static func after_damaged(sim: BattleSim, t: BattleSim.Fighter) -> void:
	if t.ability_id() == "invulnerable_once" and not t.memory.get("rolled", false):
		if t.hp * 100 < t.max_hp * int(t.param("below_hp_pct")):
			t.memory.rolled = true
			t.invulnerable = ticks(sim, t.param("duration"))
			sim.events.append({"type": "roll_up", "x": t.x, "y": t.y})


## Returns true if the animal avoids being defeated (the Opossum plays dead).
static func prevent_defeat(sim: BattleSim, t: BattleSim.Fighter) -> bool:
	if t.ability_id() != "revive_once" or t.memory.get("revived", false):
		return false
	t.memory.revived = true
	t.hp = 1
	t.memory.revive_hp = t.max_hp * int(t.param("hp_pct")) / 100
	t.memory.playing_dead = ticks(sim, t.param("delay"))
	t.target = null
	t.poison = 0
	sim.events.append({"type": "play_dead", "x": t.x, "y": t.y})
	return true


static func on_defeated(sim: BattleSim, t: BattleSim.Fighter, source: BattleSim.Fighter) -> void:
	match t.ability_id():
		"death_cloud":
			for enemy in sim.enemies_near(t.team, t.x, t.y, tiles(t.param("radius"))):
				sim.slow_down(enemy, int(t.param("slow_pct")), ticks(sim, t.param("duration")))
			sim.events.append({"type": "cloud", "x": t.x, "y": t.y, "radius": tiles(t.param("radius"))})
		"heal_on_death":
			for ally in sim.allies_near(t.team, t.x, t.y, tiles(t.param("radius"))):
				sim.heal(ally, scaled(t, t.param("amount")))
			sim.events.append({"type": "heal", "x": t.x, "y": t.y, "radius": tiles(t.param("radius"))})

	# Animals that react when something nearby is defeated.
	for f in sim.fighters:
		if not f.alive or not f.is_unit():
			continue
		match f.ability_id():
			"heal_on_kill":
				var counts: bool = f.team != t.team or f.param("any_side", false)
				if counts and BattleSim.dist(f, t) <= tiles(f.param("radius")) + f.radius:
					var amount: int = f.max_hp * int(f.param("pct", 0)) / 100
					if f.param("amount", 0) != 0:
						amount = scaled(f, f.param("amount"))
					sim.heal(f, amount)
			"stealth":
				if source == f and f.param("restealth_on_kill", false):
					f.stealthed = true
					f.target = null


## True while every animal released together with `f` is still alive.
static func _group_complete(sim: BattleSim, f: BattleSim.Fighter) -> bool:
	var alive := 0
	for other in sim.units(f.team):
		if other.memory.get("group", -1) == f.memory.get("group", -2):
			alive += 1
	return alive >= int(f.memory.get("group_size", 1))
