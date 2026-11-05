class_name BattleStyles
extends RefCounted
## Every animal's own attack style (data/styles.json): something it does
## that fits the real animal, on top of its class's job (Tanks hold the
## front, Tank Destroyers beat Tanks, Ranged beat Air, Air beats Tank
## Destroyers, Specialists keep their trait). Called from BattleAbilities'
## hooks and from BattleSim; whole numbers only, like the rest of the fight.
## How each one looks: battle_field.gd (events) and fx/style_look.gd (poses
## and props on the animal).
##
## Tanks:
##   cleave (Brown Bear): every swipe also hits the next-nearest enemy in
##     reach (its reach plus `reach` tiles) for `pct` of its bite.
##   shell (Snapping Turtle): below `below_pct` health it hides in its
##     shell for `seconds`, taking `taken_pct` of the damage and not
##     fighting, then can't again for `cooldown` seconds.
##   snack (Giant Panda): once a fight, at `below_pct` health, it sits down
##     for `seconds` and munches its way back up by `heal_pct` of its health.
##   reflect (Hippopotamus): `pct` of every melee blow it takes goes back to
##     the attacker.
##   guard (Asian Elephant): a shot at a teammate right behind it (within
##     `reach` tiles) hits the Elephant instead.
##   rhino_charge (Black Rhino): once an enemy is within `trigger` tiles (or
##     the war starts, whichever comes first) it charges `tiles` tiles at the
##     nearest enemy at `speed_pct` of its speed, knocking everyone it meets
##     `knock` tiles aside, hit for `damage_pct` of its bite and stunned for
##     `stun` seconds. Once a fight.
##   pound (Yeti): every `every` hits, an icy ground pound: enemies on the
##     ground within `radius` tiles take `pct` of its bite and are knocked
##     back `knock` tiles.

const T := BattleSim.TILE
const KINDS := ["cleave", "shell", "snack", "reflect", "guard", "rhino_charge", "pound"]
## Reach (field units) from which a blow counts as a shot.
const SHOT_REACH := 1500


static func ticks(sim: BattleSim, seconds: Variant) -> int:
	return roundi(float(seconds) * sim.tps)


static func tiles(value: Variant) -> int:
	return roundi(float(value) * T)


## Its share of `pct` of its bite against `t`, with class counters.
static func bite(sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter, pct: Variant) -> int:
	return BattleAbilities.outgoing_damage(sim, f, t, f.damage * int(pct) / 100)


# --- Hooks ---------------------------------------------------------------------

static func on_spawn(_sim: BattleSim, _f: BattleSim.Fighter) -> void:
	pass


## Every tick, for every animal (even stunned): its style's timers.
static func on_tick(sim: BattleSim, f: BattleSim.Fighter) -> void:
	match f.style_kind:
		"shell":
			var left := int(f.memory.get("shell", 0))
			if left > 0:
				f.memory.shell = left - 1
				if left == 1:
					sim.events.append({"type": "shell", "uid": f.uid, "on": false, "x": f.x, "y": f.y})
		"snack":
			var left := int(f.memory.get("snack", 0))
			if left > 0:
				# A little more of the heal every tick; the last takes the rest.
				var heal_left := int(f.memory.snack_heal)
				var now := heal_left if left == 1 else heal_left / left
				var before := f.hp
				sim.heal(f, now)
				f.memory.snack_heal = heal_left - now
				f.memory.snack_shown = int(f.memory.get("snack_shown", 0)) + f.hp - before
				f.memory.snack = left - 1
				if left == 1 or left % (sim.tps / 2) == 0:
					sim.events.append({"type": "heal", "uid": f.uid, "amount": int(f.memory.snack_shown), "x": f.x, "y": f.y})
					f.memory.snack_shown = 0
				if left == 1:
					sim.events.append({"type": "snack", "uid": f.uid, "on": false, "x": f.x, "y": f.y})


## Whether its style takes its turn this tick (it doesn't move or fight by
## its class): a charge under way, hiding in its shell, a snack.
static func act(sim: BattleSim, f: BattleSim.Fighter) -> bool:
	match f.style_kind:
		"shell":
			return int(f.memory.get("shell", 0)) > 0
		"snack":
			return int(f.memory.get("snack", 0)) > 0
		"rhino_charge":
			return _rhino_charge(sim, f)
	return false


## After `f` lands a blow of `amount` on `t`.
static func after_hit(sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter, _amount: int) -> void:
	if not t.is_unit():
		return
	match f.style_kind:
		"cleave":
			_cleave(sim, f, t)
		"pound":
			f.memory.pounds = int(f.memory.get("pounds", 0)) + 1
			if int(f.memory.pounds) % maxi(1, int(f.sp("every", 3))) == 0:
				_pound(sim, f, t)


## The damage `t` takes of `amount` (from `source`, or null).
static func incoming(sim: BattleSim, t: BattleSim.Fighter, amount: int, source: BattleSim.Fighter) -> int:
	match t.style_kind:
		"shell":
			if int(t.memory.get("shell", 0)) > 0:
				amount = amount * int(t.sp("taken_pct", 25)) / 100
		"reflect":
			if source != null and source.is_unit() and source.alive and source.team != t.team and source.attack_range < SHOT_REACH:
				var back := amount * int(t.sp("pct", 25)) / 100
				if back > 0:
					sim.events.append({"type": "reflect", "uid": t.uid, "to": source.uid, "amount": back,
						"x": source.x, "y": source.y, "fx": t.x, "fy": t.y})
					# No source: what bounces back doesn't bounce again.
					sim.deal_damage(source, back, null)
	return amount


## After `t` takes damage and is still standing.
static func after_damaged(sim: BattleSim, t: BattleSim.Fighter) -> void:
	match t.style_kind:
		"shell":
			if int(t.memory.get("shell", 0)) <= 0 and t.hp * 100 < t.max_hp * int(t.sp("below_pct", 40)) and sim.tick >= int(t.memory.get("shell_ready", 0)):
				var seconds := float(t.sp("seconds", 3.0))
				t.memory.shell = ticks(sim, seconds)
				t.memory.shell_ready = sim.tick + ticks(sim, seconds + float(t.sp("cooldown", 8.0)))
				sim.events.append({"type": "shell", "uid": t.uid, "on": true, "x": t.x, "y": t.y})
		"snack":
			if not t.memory.get("snacked", false) and t.hp * 100 <= t.max_hp * int(t.sp("below_pct", 50)):
				t.memory.snacked = true
				t.memory.snack = maxi(1, ticks(sim, t.sp("seconds", 2.0)))
				t.memory.snack_heal = t.max_hp * int(t.sp("heal_pct", 35)) / 100
				t.memory.snack_shown = 0
				sim.events.append({"type": "snack", "uid": t.uid, "on": true, "x": t.x, "y": t.y})


## The one a shot from `f` at `t` really hits: a guardian standing right in
## front of `t` (toward the enemy) takes it instead.
static func redirect(sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter) -> BattleSim.Fighter:
	if f.attack_range < SHOT_REACH or t == null or not t.is_unit() or t.style_kind == "guard":
		return t
	var ahead := -1 if t.team == 0 else 1
	var best: BattleSim.Fighter = null
	var best_gap := 1 << 30
	for g: BattleSim.Fighter in sim.fighters:
		if g.style_kind != "guard" or g.team != t.team or g == t or not g.alive or g.memory.get("burrowing", false):
			continue
		# In front of `t` (toward the enemy), close, and covering it.
		var gap := (g.y - t.y) * ahead
		if gap <= 0 or gap > g.radius + t.radius + tiles(g.sp("reach", 1.6)):
			continue
		if absi(g.x - t.x) > g.radius + t.radius:
			continue
		if gap < best_gap:
			best = g
			best_gap = gap
	return best if best != null else t


# --- Tanks -----------------------------------------------------------------------

## The Brown Bear's swipe also catches the next-nearest enemy in reach.
static func _cleave(sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter) -> void:
	if f.attack_range >= SHOT_REACH:
		return
	var reach := f.attack_range + tiles(f.sp("reach", 0.4))
	var other: BattleSim.Fighter = null
	var best := 1 << 40
	for e: BattleSim.Fighter in sim.fighters:
		if e == t or e.team == f.team or not e.alive or not e.is_unit() or not sim.can_target(f, e):
			continue
		var d := BattleSim.edge_distance(f, e)
		if d <= reach and d < best:
			other = e
			best = d
	if other == null:
		return
	sim.events.append({"type": "cleave", "uid": f.uid, "a": t.uid, "b": other.uid, "x": f.x, "y": f.y,
		"ax": t.x, "ay": t.y, "bx": other.x, "by": other.y})
	sim.strike(f, other, bite(sim, f, other, f.sp("pct", 70)), {"cleave": true})


## The Yeti's ground pound: everyone on the ground around it is hit and
## knocked back.
static func _pound(sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter) -> void:
	var radius := tiles(f.sp("radius", 2.0))
	sim.events.append({"type": "pound", "uid": f.uid, "x": f.x, "y": f.y, "radius": radius})
	for e: BattleSim.Fighter in sim.enemies_near(f.team, f.x, f.y, radius):
		if e.is_flying() or e.memory.get("burrowing", false):
			continue
		if e != t:
			sim.strike(f, e, bite(sim, f, e, f.sp("pct", 60)), {"pound": true})
		sim.knock_back(e, f.x, f.y, tiles(f.sp("knock", 1.0)))


## The Black Rhino's charge: once, at the start of the war, straight at the
## nearest enemy and on through, knocking aside everyone it meets.
static func _rhino_charge(sim: BattleSim, f: BattleSim.Fighter) -> bool:
	var state := int(f.memory.get("charge_state", 0))
	if state == 2:
		return false
	if state == 0:
		var near: BattleSim.Fighter = null
		var near_d := 1 << 60
		for e: BattleSim.Fighter in sim.fighters:
			if e.team != f.team and e.alive and e.is_unit() and not e.is_flying() and sim.can_target(f, e):
				var d := (e.x - f.x) * (e.x - f.x) + (e.y - f.y) * (e.y - f.y)
				if d < near_d:
					near = e
					near_d = d
		if near == null:
			return false
		var go := BattleSim.edge_distance(f, near) <= tiles(f.sp("trigger", 5.0)) or (sim.army != null and sim.army.at_war())
		if not go:
			return false
		var dx := near.x - f.x
		var dy := near.y - f.y
		var d := BattleSim.isqrt(dx * dx + dy * dy)
		if d == 0:
			dx = 0
			dy = -1 if f.team == 0 else 1
			d = 1
		f.memory.charge_dir = Vector2i(dx * 1000 / d, dy * 1000 / d)
		f.memory.charge_left = tiles(f.sp("tiles", 5.0))
		f.memory.charge_hit = []
		f.memory.charge_state = 1
		sim.events.append({"type": "rhino_charge", "uid": f.uid, "x": f.x, "y": f.y})
	var dir: Vector2i = f.memory.charge_dir
	var step := mini(sim.current_speed(f) * int(f.sp("speed_pct", 260)) / 100, int(f.memory.charge_left))
	var nx := f.x + dir.x * step / 1000
	var ny := f.y + dir.y * step / 1000
	var cx := clampi(nx, f.radius, sim.width - f.radius)
	var cy := clampi(ny, f.radius, sim.height - f.radius)
	f.x = cx
	f.y = cy
	f.memory.run = int(f.memory.get("run", 0)) + step
	f.memory.charge_left = int(f.memory.charge_left) - step
	var hit: Array = f.memory.charge_hit
	for e: BattleSim.Fighter in sim.fighters:
		if e.team == f.team or not e.alive or not e.is_unit() or e.is_flying() or e.memory.get("burrowing", false) or hit.has(e.uid):
			continue
		var reach := f.radius + e.radius + T / 10
		var ex := e.x - f.x
		var ey := e.y - f.y
		if ex * ex + ey * ey > reach * reach:
			continue
		hit.append(e.uid)
		# Aside: away from the charge's line, to whichever side it's on.
		var side := -ex * dir.y + ey * dir.x
		var away := 1 if side > 0 else (-1 if side < 0 else (1 if e.uid % 2 == 0 else -1))
		sim.strike(f, e, bite(sim, f, e, f.sp("damage_pct", 60)), {"charge": true})
		sim.knock_back(e, e.x + dir.y * away, e.y - dir.x * away, tiles(f.sp("knock", 1.0)))
		sim.stun(e, ticks(sim, f.sp("stun", 0.4)))
	if int(f.memory.charge_left) <= 0 or cx != nx or cy != ny:
		f.memory.charge_state = 2
		sim.events.append({"type": "charge_end", "uid": f.uid, "x": f.x, "y": f.y})
	return true
