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
##
## Tank Destroyers:
##   rush (Wild Boar): goes for the nearest enemy Tank within `reach` tiles,
##     sprinting at it `speed_pct` faster; its first hit on each Tank does
##     `first_pct` of its bite.
##   pack (Wolf Pack): `pct` more bite while another wolf of its pack is
##     biting the same enemy.
##   roar (Lion): with an enemy within `trigger` tiles, it roars every
##     `every` seconds: its Tank Destroyers within `radius` tiles (itself
##     too) attack `haste_pct` faster for `seconds`.
##   fearless (Honey Badger): goes for the biggest enemy (most health)
##     within `reach` tiles, and can't be knocked back.
##   stalk (Tiger): circles out `flank` tiles to its prey's side at
##     `speed_pct` of its speed, then pounces from within `pounce` tiles at
##     `pounce_pct`; its first hit on each enemy does `first_pct`.
##   venom (Komodo Dragon): its bite poisons for `seconds` (`dps_pct` of its
##     bite every second), then it goes for the nearest enemy within `reach`
##     tiles that isn't poisoned yet.
##   triple (Cerberus): every attack is three bites of `pct` each, spread
##     over the enemies within its reach plus `reach` tiles (the one it's
##     after again if there aren't three).
##
## Ranged:
##   burst (Gray Squirrel): every shot is `pellets` little pinecones (the
##     same damage between them).
##   spray (Striped Skunk): a short spray (`range` tiles) that also hits
##     everyone else in a `cone`-degree cone, for `pct` of its bite.
##   lob (Raccoon): lobs its trash at the enemy furthest back in its reach.
##   sniper (King Cobra): `range` tiles of reach; its shots come
##     `slow_pct` slower and hit as much harder.
##   spit (Wild Bactrian Camel): charges up for `charge` seconds, then one
##     giant spit of `spit_pct` of its bite (its own rhythm, not the volley).
##   bounce (Sumatran Orangutan): its fruit bounces on to `bounces` more
##     enemies, each within `reach` tiles of the last, for `pct` of its bite.
##   pierce (Unicorn): its beam goes on through the line, hitting every
##     enemy along it (within `width` tiles) for `pct` of its bite.

const T := BattleSim.TILE
const KINDS := ["cleave", "shell", "snack", "reflect", "guard", "rhino_charge", "pound",
	"rush", "pack", "roar", "fearless", "stalk", "venom", "triple",
	"burst", "spray", "lob", "sniper", "spit", "bounce", "pierce"]
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

static func on_spawn(_sim: BattleSim, f: BattleSim.Fighter) -> void:
	match f.style_kind:
		"spray":
			f.attack_range = tiles(f.sp("range", 3.0))
		"sniper":
			f.attack_range = maxi(f.attack_range, tiles(f.sp("range", 10.0)))
			var slow := int(f.sp("slow_pct", 160))
			f.hit_ticks = maxi(1, f.hit_ticks * slow / 100)
			f.damage = maxi(1, f.damage * slow / 100)
			f.cooldown = f.hit_ticks * 50


## Every tick, for every animal (even stunned): its style's timers.
static func on_tick(sim: BattleSim, f: BattleSim.Fighter) -> void:
	match f.style_kind:
		"roar":
			if f.stun <= 0 and f.deploy_ticks <= 0 and sim.tick >= int(f.memory.get("roar_at", 0)):
				var trigger := tiles(f.sp("trigger", 3.0))
				for e: BattleSim.Fighter in sim.fighters:
					if e.team != f.team and e.alive and e.is_unit() and BattleSim.edge_distance(f, e) <= trigger:
						_roar(sim, f)
						break
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
		"stalk":
			return _stalk(sim, f)
		"spit":
			return _spit(sim, f)
	return false


## Whether `f` keeps its own rhythm rather than firing with its army's
## volleys (the Camel, charging up its spit).
static func own_rhythm(f: BattleSim.Fighter) -> bool:
	return f.style_kind == "spit"


## How much faster than usual `f` attacks this tick (percent).
static func haste_pct(sim: BattleSim, f: BattleSim.Fighter) -> int:
	if int(f.memory.get("roared", -1)) > sim.tick:
		return int(f.memory.get("roar_pct", 0))
	return 0


## How much faster than usual `f` moves (percent).
static func speed_bonus(sim: BattleSim, f: BattleSim.Fighter) -> int:
	if f.style_kind == "rush":
		var t := f.target
		if t != null and t.alive and t.cls == "tank" and not f.memory.get("slammed", []).has(t.uid) and not sim.in_range(f, t):
			return int(f.sp("speed_pct", 60))
	return 0


## `f`'s blow at `t` (`amount` so far) as its style has it.
static func attack_amount(sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter, amount: int) -> int:
	if not t.is_unit():
		return amount
	match f.style_kind:
		"rush":
			if t.cls == "tank" and not f.memory.get("slammed", []).has(t.uid):
				f.memory.slam = true
				return amount * int(f.sp("first_pct", 250)) / 100
		"stalk":
			if not f.memory.get("pounced", []).has(t.uid):
				f.memory.slam = true
				return amount * int(f.sp("first_pct", 250)) / 100
		"pack":
			for o: BattleSim.Fighter in sim.fighters:
				if o != f and o.alive and o.team == f.team and o.style_kind == "pack" and o.target == t and sim.in_range(o, t):
					f.memory.pack_tick = sim.tick
					return amount * (100 + int(f.sp("pct", 40))) / 100
		"triple":
			return amount * int(f.sp("pct", 45)) / 100
		"burst":
			return amount / maxi(1, int(f.sp("pellets", 3)))
	return amount


## Whether nothing can knock `t` back.
static func steady(t: BattleSim.Fighter) -> bool:
	return t.style_kind == "fearless"


## The enemy `f`'s style wants to go for, or null (then it chooses as its
## class does).
static func prefer_target(sim: BattleSim, f: BattleSim.Fighter) -> BattleSim.Fighter:
	match f.style_kind:
		"rush":
			# The nearest Tank in reach it hasn't hit yet (in an army, its
			# class already goes for Tanks, spreading out along them).
			if f.memory.has("slot"):
				return null
			var reach := tiles(f.sp("reach", 8.0))
			var slammed: Array = f.memory.get("slammed", [])
			return _nearest(sim, f, reach, func(e): return e.cls == "tank" and not slammed.has(e.uid))
		"fearless":
			# The biggest one around.
			var reach := tiles(f.sp("reach", 4.0))
			var best: BattleSim.Fighter = null
			for e: BattleSim.Fighter in sim.fighters:
				if e.team == f.team or not e.alive or not e.is_unit() or not sim.can_target(f, e):
					continue
				if BattleSim.edge_distance(f, e) > reach:
					continue
				if best == null or e.max_hp > best.max_hp or (e.max_hp == best.max_hp and e.uid < best.uid):
					best = e
			return best
		"venom":
			return _nearest(sim, f, tiles(f.sp("reach", 5.0)), func(e): return e.poison <= 0)
		"lob":
			# The one furthest back of those in reach (its army's back ranks).
			var best: BattleSim.Fighter = null
			for e: BattleSim.Fighter in sim.fighters:
				if e.team == f.team or not e.alive or not e.is_unit() or not sim.can_target(f, e) or not sim.in_range(f, e):
					continue
				var back := -e.y if f.team == 0 else e.y
				if best == null or back > (-best.y if f.team == 0 else best.y):
					best = e
			return best
	return null


## The nearest enemy `f` can hit within `reach` (edge to edge) that `ok`
## says yes to, or null.
static func _nearest(sim: BattleSim, f: BattleSim.Fighter, reach: int, ok: Callable) -> BattleSim.Fighter:
	var best: BattleSim.Fighter = null
	var best_d := 1 << 40
	for e: BattleSim.Fighter in sim.fighters:
		if e.team == f.team or not e.alive or not e.is_unit() or not sim.can_target(f, e):
			continue
		var d := BattleSim.edge_distance(f, e)
		if d <= reach and d < best_d and ok.call(e):
			best = e
			best_d = d
	return best


## After `f` lands a blow of `amount` on `t`.
static func after_hit(sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter, amount: int) -> void:
	if not t.is_unit():
		return
	match f.style_kind:
		"rush", "stalk":
			if f.memory.get("slam", false):
				f.memory.slam = false
				var key := "slammed" if f.style_kind == "rush" else "pounced"
				var done: Array = f.memory.get(key, [])
				done.append(t.uid)
				f.memory[key] = done
				f.memory.stalk_phase = 0
				sim.events.append({"type": "slam", "uid": f.uid, "to": t.uid, "x": t.x, "y": t.y, "kind": f.style_kind})
		"pack":
			if int(f.memory.get("pack_tick", -1)) == sim.tick:
				sim.events.append({"type": "pack_bite", "uid": f.uid, "to": t.uid, "x": t.x, "y": t.y})
		"venom":
			_venom(sim, f, t)
		"triple":
			_triple(sim, f, t)
		"burst":
			for k in range(1, maxi(1, int(f.sp("pellets", 3)))):
				sim.strike(f, t, amount, {"ranged": true, "pellet": k, "style": "burst"})
		"spray":
			_spray(sim, f, t)
		"bounce":
			_bounce(sim, f, t)
		"pierce":
			_pierce(sim, f, t)
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


# --- Ranged ---------------------------------------------------------------------

## The Skunk's spray: everyone else in the cone toward its target gets it
## too, and goes stinky for a moment.
static func _spray(sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter) -> void:
	var dx := t.x - f.x
	var dy := t.y - f.y
	var d := maxi(1, BattleSim.isqrt(dx * dx + dy * dy))
	var cos_half := roundi(cos(deg_to_rad(float(f.sp("cone", 60)) / 2.0)) * 1000.0)
	var reach := f.attack_range + f.radius
	var stink := sim.tick + ticks(sim, 1.0)
	t.memory.stink_until = stink
	for e: BattleSim.Fighter in sim.fighters:
		if e == t or e.team == f.team or not e.alive or not e.is_unit() or not sim.can_target(f, e):
			continue
		var ex := e.x - f.x
		var ey := e.y - f.y
		var ed := maxi(1, BattleSim.isqrt(ex * ex + ey * ey))
		if ed - e.radius > reach or (ex * dx + ey * dy) * 1000 / (ed * d) < cos_half:
			continue
		e.memory.stink_until = stink
		sim.strike(f, e, bite(sim, f, e, f.sp("pct", 70)), {"style": "spray"})
	sim.events.append({"type": "spray", "uid": f.uid, "x": f.x, "y": f.y, "tx": t.x, "ty": t.y, "reach": reach, "cone": int(f.sp("cone", 60))})


## The Orangutan's fruit bounces on from enemy to enemy.
static func _bounce(sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter) -> void:
	var hit := [t.uid]
	var last := t
	var reach := tiles(f.sp("reach", 2.5))
	for k in range(1, int(f.sp("bounces", 2)) + 1):
		var next: BattleSim.Fighter = null
		var best := 1 << 40
		for e: BattleSim.Fighter in sim.fighters:
			if e.team == f.team or not e.alive or not e.is_unit() or hit.has(e.uid) or not sim.can_target(f, e):
				continue
			var d := BattleSim.edge_distance(last, e)
			if d <= reach and d < best:
				next = e
				best = d
		if next == null:
			return
		hit.append(next.uid)
		sim.strike(f, next, bite(sim, f, next, f.sp("pct", 70)), {"ranged": true, "bounce": k, "bounce_from": last.uid, "style": "bounce"})
		last = next


## The Unicorn's beam goes on through its target, hitting everyone along
## the line out to its reach.
static func _pierce(sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter) -> void:
	var dx := t.x - f.x
	var dy := t.y - f.y
	var d := maxi(1, BattleSim.isqrt(dx * dx + dy * dy))
	var length := f.attack_range + f.radius + T
	var width := tiles(f.sp("width", 0.3))
	for e: BattleSim.Fighter in sim.fighters:
		if e == t or e.team == f.team or not e.alive or not e.is_unit() or not sim.can_target(f, e):
			continue
		var ex := e.x - f.x
		var ey := e.y - f.y
		var along := (ex * dx + ey * dy) / d
		var side := absi(ey * dx - ex * dy) / d
		if along > 0 and along <= length and side <= e.radius + width:
			sim.strike(f, e, bite(sim, f, e, f.sp("pct", 60)), {"style": "pierce"})
	sim.events.append({"type": "pierce", "uid": f.uid, "x": f.x, "y": f.y,
		"ex": f.x + dx * length / d, "ey": f.y + dy * length / d})


## The Camel: in reach and ready, it charges up (standing still), then lets
## fly one giant spit.
static func _spit(sim: BattleSim, f: BattleSim.Fighter) -> bool:
	var t := f.target
	var at := int(f.memory.get("spit_at", -1))
	var ok := t != null and t.alive and sim.can_target(f, t) and sim.in_range(f, t)
	if at >= 0:
		if not ok:
			f.memory.spit_at = -1
			return false
		if sim.tick >= at:
			f.memory.spit_at = -1
			sim.attack(f, t, int(f.sp("spit_pct", 300)))
			f.cooldown = f.hit_ticks * 100
		return true
	if ok and f.cooldown <= 0:
		f.memory.spit_at = sim.tick + ticks(sim, f.sp("charge", 1.5))
		sim.events.append({"type": "spit_charge", "uid": f.uid, "x": f.x, "y": f.y})
		return true
	return false


# --- Tank Destroyers -------------------------------------------------------------

## The Lion roars: its Tank Destroyers around it (itself too) attack faster
## for a while.
static func _roar(sim: BattleSim, f: BattleSim.Fighter) -> void:
	f.memory.roar_at = sim.tick + ticks(sim, f.sp("every", 5.0))
	var radius := tiles(f.sp("radius", 3.0))
	var until := sim.tick + ticks(sim, f.sp("seconds", 3.0))
	var pct := int(f.sp("haste_pct", 30))
	var roused := []
	for a: BattleSim.Fighter in sim.units(f.team):
		if a.cls == "tank_destroyer" and BattleSim.dist(f, a) <= radius + a.radius:
			a.memory.roared = until
			a.memory.roar_pct = pct
			roused.append(a.uid)
	sim.events.append({"type": "roar", "uid": f.uid, "x": f.x, "y": f.y, "radius": radius, "roused": roused})


## The Komodo's bite poisons; then it's off to someone not poisoned yet.
static func _venom(sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter) -> void:
	if not t.alive:
		return
	t.poison = maxi(t.poison, ticks(sim, f.sp("seconds", 4.0)))
	t.poison_dps = maxi(t.poison_dps, f.damage * int(f.sp("dps_pct", 35)) / 100)
	sim.events.append({"type": "venom", "uid": f.uid, "to": t.uid, "x": t.x, "y": t.y})
	var next := prefer_target(sim, f)
	if next != null and next != t:
		f.target = next


## Cerberus's other two heads bite too: the nearest other enemies in reach,
## or the same one again.
static func _triple(sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter) -> void:
	var reach := f.attack_range + tiles(f.sp("reach", 0.6))
	var others := []
	for e: BattleSim.Fighter in sim.fighters:
		if e != t and e.team != f.team and e.alive and e.is_unit() and sim.can_target(f, e) and BattleSim.edge_distance(f, e) <= reach:
			others.append(e)
	others.sort_custom(func(a, b): return BattleSim.edge_distance(f, a) < BattleSim.edge_distance(f, b) or (BattleSim.edge_distance(f, a) == BattleSim.edge_distance(f, b) and a.uid < b.uid))
	var bitten := [t.uid]
	for head in [1, 2]:
		var victim: BattleSim.Fighter = others[head - 1] if others.size() >= head else t
		if not victim.alive:
			continue
		bitten.append(victim.uid)
		sim.strike(f, victim, bite(sim, f, victim, f.sp("pct", 45)), {"head": head})
	sim.events.append({"type": "triple", "uid": f.uid, "bitten": bitten, "x": t.x, "y": t.y})


## The Tiger, after prey it hasn't struck yet: out to its side first, then a
## pounce. Its turn while it's on its way; once in reach it fights as usual.
static func _stalk(sim: BattleSim, f: BattleSim.Fighter) -> bool:
	var t := f.target
	if t == null or not t.alive or not t.is_unit() or f.memory.get("pounced", []).has(t.uid) or sim.in_range(f, t):
		return false
	if sim.army != null and f.memory.has("slot") and not sim.army.at_war():
		return false
	if int(f.memory.get("stalk_uid", -1)) != t.uid:
		f.memory.stalk_uid = t.uid
		f.memory.stalk_phase = 0
		f.memory.stalk_side = 1 if (f.x > t.x or (f.x == t.x and f.uid % 2 == 0)) else -1
	var speed := sim.current_speed(f)
	if int(f.memory.stalk_phase) == 0:
		# Its prey's side: across from the line between them, out `flank`.
		var dx := t.x - f.x
		var dy := t.y - f.y
		var d := maxi(1, BattleSim.isqrt(dx * dx + dy * dy))
		var side := int(f.memory.stalk_side)
		var out := tiles(f.sp("flank", 2.0)) + t.radius
		var spot := Vector2i(t.x - dy * side * out / d, t.y + dx * side * out / d)
		spot.x = clampi(spot.x, f.radius, sim.width - f.radius)
		spot.y = clampi(spot.y, f.radius, sim.height - f.radius)
		var near_spot := BattleSim.dist_to_point(f, spot.x, spot.y) <= T / 2
		if near_spot or BattleSim.edge_distance(f, t) <= tiles(f.sp("pounce", 1.8)) and absi(dy) * 2 < absi(dx) + 1:
			f.memory.stalk_phase = 1
			sim.events.append({"type": "pounce", "uid": f.uid, "x": f.x, "y": f.y})
		else:
			var step := speed * int(f.sp("speed_pct", 130)) / 100
			if sim.army != null:
				sim.army._go(sim, f, spot, step)
			else:
				sim.move_toward_point(f, spot, step)
			return true
	sim.move_toward_point(f, Vector2i(t.x, t.y), speed * int(f.sp("pounce_pct", 220)) / 100)
	return true


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
