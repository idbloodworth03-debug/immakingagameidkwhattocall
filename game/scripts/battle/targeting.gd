class_name Targeting
extends RefCounted
## Who an animal fights: the same clear rules in every fight
## (battle_rules.json "targeting").
##
## It goes for the closest enemy it can attack, unless its ability (styles:
## the Boar's nearest Tank, the Badger's biggest enemy, the Owl's and the
## Fox's Ranged, the Raccoon's back ranks...) or its class (classes.json
## "prefer": Tank Destroyers after Tanks, Ranged after Air) says otherwise,
## falling back to the closest when there's none of those. Food bait and a
## Tank Destroyer charge are tools and class rules and come first, as
## before.
##
## Once it has a target it commits to it. It only switches when:
##   1. its target falls, can't be attacked any more (it burrowed, hid or
##      flew off for a ground fighter) or can't be reached;
##   2. threat response: an enemy attacks it, or a teammate right next to
##      it, up close while it's busy with something further off (the Fox
##      popping up in the backline). After reaction_seconds it turns on the
##      attacker, with an "alert" event (a cartoon "!" over its head). The
##      delay gives the attacker a moment to do its damage;
##   3. while it's still on its way to its target (not hitting it yet): a
##      clearly closer enemy (closer_pct closer), or one its ability or
##      class prefers, once it has kept its target for commit_seconds.
## After any switch it keeps the new target for commit_seconds (unless that
## one falls), and it only looks around every recheck_seconds (animals take
## turns), not every tick.

## The rules in ticks and field units, read once per fight (BattleSim).
var recheck_ticks := 10
var commit_ticks := 40
var reaction_ticks := 20
var closer_pct := 40
var threat_reach := 1200
var threat_forget_ticks := 40


func _init(rules: Dictionary = {}, tps := 20) -> void:
	var r: Dictionary = rules.get("targeting", GameData.battle_rules.get("targeting", {}))
	recheck_ticks = maxi(1, roundi(float(r.get("recheck_seconds", 0.5)) * tps))
	commit_ticks = roundi(float(r.get("commit_seconds", 2.0)) * tps)
	reaction_ticks = roundi(float(r.get("reaction_seconds", 1.0)) * tps)
	closer_pct = int(r.get("closer_pct", 40))
	threat_reach = roundi(float(r.get("threat_tiles", 1.2)) * BattleSim.TILE)
	threat_forget_ticks = roundi(float(r.get("threat_forget_seconds", 2.0)) * tps)


## What `f` should be fighting this tick. `current_ok` says whether its
## target is still good (it can attack it and reach it), `find` picks a
## fresh one (Callable() -> Fighter: the closest it can attack, or what its
## ability or class prefers), and `preferred` says whether a target is one
## of those it prefers (Callable(Fighter) -> bool), and `room` whether it
## may take on a given enemy (Callable(Fighter) -> bool: a fighter needs a
## free engagement slot, BattleArmy; none: always). Returns the target to
## have (maybe its current one); a switch is stamped (lock()), and a threat
## response raises an "alert".
func decide(sim: BattleSim, f: BattleSim.Fighter, current_ok: bool, find: Callable, preferred: Callable, room := Callable()) -> BattleSim.Fighter:
	var t := f.target
	# 1. Its target fell or can't be had: a new one at once.
	if t == null or not current_ok:
		var fresh: BattleSim.Fighter = find.call()
		if t == null and fresh == null:
			return null
		lock(sim, f, fresh)
		return fresh
	var calm := settled(sim, f)
	# 2. Threat response: it's been bitten up close for reaction_seconds
	# while busy with something further off. (The cheap checks first.)
	var uid := int(f.memory.get("threat", -1))
	if uid >= 0 and uid != t.uid and calm and sim.tick - int(f.memory.get("threat_at", sim.tick)) >= reaction_ticks \
			and BattleSim.edge_distance(f, t) > threat_reach:
		var threat := _threat(sim, f)
		if threat != null and sim.can_target(f, threat) and (not room.is_valid() or room.call(threat)):
			lock(sim, f, threat, "threat")
			sim.events.append({"type": "alert", "uid": f.uid, "to": threat.uid, "x": f.x, "y": f.y})
			return threat
	# 3. Now and then (animals take turns), only once settled, and only
	# while it's still on its way (one already hitting its target keeps on
	# with it: only a threat turns it): a clearly closer enemy, or one it
	# prefers.
	if not calm or (sim.tick + f.uid) % recheck_ticks != 0 or sim.in_range(f, t):
		return t
	var found: BattleSim.Fighter = find.call()
	if found == null or found == t:
		return t
	if better(f, found, t, preferred) and (not room.is_valid() or room.call(found)):
		lock(sim, f, found, "ability" if preferred.call(found) else "closer")
		return found
	return t


## Whether `found` is worth leaving `current` for: food bait, one it
## prefers when its current one isn't, or one at least closer_pct closer.
func better(f: BattleSim.Fighter, found: BattleSim.Fighter, current: BattleSim.Fighter, preferred: Callable) -> bool:
	if found.kind == "bait" or current.kind == "bait":
		return found.kind == "bait"
	var likes_found: bool = preferred.call(found)
	var likes_current: bool = preferred.call(current)
	if likes_found and not likes_current:
		return true
	if likes_current and not likes_found:
		return false
	var near := maxi(0, BattleSim.edge_distance(f, found))
	var far := maxi(0, BattleSim.edge_distance(f, current))
	return near < far and near * 100 <= far * (100 - closer_pct)


## Whether `f` has kept its target for the commit time (and may switch).
func settled(sim: BattleSim, f: BattleSim.Fighter) -> bool:
	return sim.tick - int(f.memory.get("locked", -100000)) >= commit_ticks


## `f` takes `t` as its target now: the commit time starts. `why`: "lost"
## (its old one fell or can't be had), "no_room" (no way in to it),
## "threat", "closer", "ability" (one its ability or class prefers) or
## "hop" (an ability whose whole point is moving on: the Komodo Dragon's
## venom, free of the commit time), for the record (tests, reports).
static func lock(sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter, why := "lost") -> void:
	if t != f.target:
		f.memory.locked = sim.tick
		f.memory.locked_why = why


## `f` attacked `t` (BattleSim.attack calls this for every blow): from up
## close, that's a threat to `t` and to its teammates right there too (the
## backline noticing the Fox in its midst), which they may turn on. The
## reaction time runs from the first of a run of close blows (gaps under
## threat_forget_seconds), and they turn on whoever bit last.
func struck(sim: BattleSim, f: BattleSim.Fighter, t: BattleSim.Fighter) -> void:
	if not t.is_unit() or not f.is_unit() or f.team == t.team:
		return
	if BattleSim.edge_distance(f, t) > threat_reach:
		return
	for o: BattleSim.Fighter in sim.fighters:
		if o.team == t.team and o.alive and o.is_unit() and (o == t or BattleSim.edge_distance(f, o) <= threat_reach):
			if int(o.memory.get("threat", -1)) < 0 or sim.tick - int(o.memory.get("threat_last", -100000)) > threat_forget_ticks:
				o.memory.threat_at = sim.tick
			o.memory.threat = f.uid
			o.memory.threat_last = sim.tick


## The enemy biting `f` up close right now, or null (gone, moved off, or
## it stopped).
func _threat(sim: BattleSim, f: BattleSim.Fighter) -> BattleSim.Fighter:
	var uid := int(f.memory.get("threat", -1))
	if uid < 0:
		return null
	if sim.tick - int(f.memory.get("threat_last", -100000)) > threat_forget_ticks:
		f.memory.threat = -1
		return null
	for e: BattleSim.Fighter in sim.fighters:
		if e.uid == uid:
			if e.alive and BattleSim.edge_distance(f, e) <= threat_reach * 2:
				return e
			break
	f.memory.threat = -1
	return null
