class_name BattleSim
extends RefCounted
## The battle engine: two herds fighting it out on an open field.
##
## It runs in fixed steps ("ticks", 20 per second) and uses whole numbers for
## positions, health and time. That makes it deterministic: the same herds,
## seed and actions always play out exactly the same way. Online play will
## rely on this, because both phones run the fight and only the players'
## actions travel over the network.
##
## Positions are in thousandths of a tile. The field is 16 tiles wide and 20
## long unless set_size() makes it another size (Draft Duel's is smaller, from
## draft_rules.json "field", and grows keeping its shape for big herds). Team 0
## starts on the near half (the bottom), team 1 on the far half.
## Animals go for the nearest enemy they can reach, or, in Draft Duel's
## armies, fight in formation (battle_army.gd). Nothing here draws
## anything (battle_field.gd does that), and Draft Duel (draft_match.gd) runs
## the rounds around it.

const TILE := 1000
## The field's size unless set_size() gives it another (width, height).
const WIDTH := 16 * TILE
const HEIGHT := 20 * TILE
const MIDDLE := HEIGHT / 2
## The grid square for pushing overlapping animals apart: bigger than any two
## animals' radii together.
const SEPARATE_CELL := 2 * TILE


## Anything on the field that has health: animals and food bait.
class Fighter:
	extends RefCounted
	var uid := 0
	var team := 0
	var kind := "unit"            # "unit" or "bait"
	var card: Dictionary = {}     # the card an animal came from
	var level := 1
	var x := 0
	var y := 0
	var prev_x := 0               # position last tick, for smooth drawing
	var prev_y := 0
	var radius := 450
	## Half its body's length (bodies.json footprint): a strike reaches from here.
	var half := 0
	var shooter := false          # a shot flies from its body to its target's body (not nose to nose)
	## Half its body's width (bodies.json width): how thick its spine is.
	var hw := 300
	## Its long side runs across the way it faces (a flier's wings, an
	## upright animal's spread arms, bodies.json across), not nose to tail.
	var across := false
	## How far its front is from its middle, where its reach is measured
	## from: half its length, or (its long side across) half its width.
	var nose := 0
	## Which way its body points (thousandths of a unit vector): turning at
	## the drawn animal's pace toward its target in reach, else the way it
	## goes (`wants`), else up the field.
	var heading := Vector2i(0, -1000)
	var prev_heading := Vector2i(0, -1000)
	var wants := Vector2i(0, -1000)
	## How far it has walked in all (its own steps, not pushes or
	## knockbacks), so the screen can hold the walking part of a swing.
	var walked := Vector2i.ZERO
	var prev_walked := Vector2i.ZERO
	var hp := 0
	var max_hp := 0
	var damage := 0
	var hit_ticks := 20           # ticks between attacks
	var cooldown := 0             # hundredths of a tick until the next attack
	var attack_range := 700
	var speed := 50               # thousandths of a tile per tick
	var flying := false
	var targets := "ground"       # "ground" or "air_ground"
	var target: Fighter = null
	var deploy_ticks := 0
	var alive := true
	# Effects, counted in ticks remaining
	var stun := 0
	var slow := 0
	var slow_pct := 0
	var poison := 0
	var poison_dps := 0
	var anti_heal := 0
	var anti_heal_pct := 0
	var rage := 0
	var rage_damage_pct := 0
	var rage_speed_pct := 0
	var rage_attack_pct := 0
	var revealed := 0
	var invulnerable := 0
	var stealthed := false
	var shield := 0
	var lifetime := -1            # bait disappears when this reaches 0
	var lure_radius := 0
	## Its class ("tank", "tank_destroyer", "ranged", "air", "specialist")
	## and, for a Specialist, its trait (classes.json).
	var cls := ""
	var trait_id := ""
	## Extra per-ability state, e.g. "hits", "burrowing".
	var memory: Dictionary = {}
	## Its own attack style (styles.json): the kind, and its numbers.
	var style_kind := ""
	var style: Dictionary = {}

	## A number of its attack style (styles.json).
	func sp(param_name: String, default: Variant = 0) -> Variant:
		return style.get(param_name, default)

	## What it does besides fighting by its class: a Specialist's trait.
	func ability_id() -> String:
		return trait_id

	## A number for its trait, from classes.json.
	func param(param_name: String, default: Variant = 0) -> Variant:
		return GameData.traits.get(trait_id, {}).get(param_name, default)

	func has_tag(tag: String) -> bool:
		return card.get("tags", []).has(tag)

	func is_flying() -> bool:
		return flying and int(memory.get("grounded", 0)) <= 0

	func is_unit() -> bool:
		return kind == "unit"


## Per-player state.
class Team:
	extends RefCounted
	var levels: Dictionary = {}
	var defeated := 0             # own animals defeated


var rules: Dictionary
var tps := 20
var tick := 0
var fighters: Array = []
var teams: Array = []
## Areas that keep working for a while, e.g. the Orangutan's fruit tree.
var zones: Array = []
## Things that happened (hits, deaths, tool blasts) for the screen to
## animate. The screen collects them with take_events().
var events: Array = []
var rng := RandomNumberGenerator.new()

var deploy_ticks := 0
var melee := 0
## Who each animal fights and when it may switch (battle_rules.json
## "targeting").
var targeting: Targeting
## Personal space (battle_rules.json "spacing"): how close (edge to edge)
## animals may stand before being nudged apart, and how hard.
var personal_space := 0
var space_push_pct := 25
## Bodies going down ([x, y, radius, until tick]): they keep their room
## for body_down_ticks (battle_rules.json spacing body_down_seconds, the
## knockout on screen), so nobody walks through one.
var corpses: Array = []
var body_down_ticks := 16
## A swing (battle_rules.json "swing"): a fighter stands still from
## windup_ticks before its blow until recovery_ticks after it.
var windup_ticks := 6
var recovery_ticks := 6
## It holds its ground against shoves from firm_before_ticks before its
## blow until firm_after_ticks after it (its whole swing on the screen).
var firm_before_ticks := 8
var firm_after_ticks := 8
## How far a body turns a tick (battle_rules.json spacing
## turn_degrees_per_tick), as the rotation's cosine and sine in thousandths.
var turn_cos := 809
var turn_sin := 588
## The field's size this fight, and the line between the two halves.
var width := WIDTH
var height := HEIGHT
var middle := MIDDLE
## Its smallest size (set_size): it grows from this, keeping its shape.
var base_width := WIDTH
var base_height := HEIGHT
## The armies' formations and battle phases (Draft Duel), or null: then
## every animal simply goes for the nearest enemy.
var army: BattleArmy
var _next_uid := 1
var _next_group := 1


## `levels` is two dictionaries of card id -> level (a card not listed
## fights at its rarity's starting level). The seed decides the luck.
func _init(levels: Array, seed_value: int, battle_rules: Dictionary = {}) -> void:
	rules = battle_rules if not battle_rules.is_empty() else GameData.battle_rules
	rng.seed = seed_value
	tps = int(rules.ticks_per_second)
	deploy_ticks = roundi(float(rules.deploy_seconds) * tps)
	melee = roundi(float(rules.melee_range) * TILE)
	targeting = Targeting.new(rules, tps)
	var spacing: Dictionary = rules.get("spacing", {})
	personal_space = roundi(float(spacing.get("personal_space", 0.0)) * TILE)
	space_push_pct = int(spacing.get("push_pct", 25))
	body_down_ticks = roundi(float(spacing.get("body_down_seconds", 0.8)) * tps)
	var turn := deg_to_rad(float(spacing.get("turn_degrees_per_tick", 36)))
	turn_cos = roundi(cos(turn) * 1000.0)
	turn_sin = roundi(sin(turn) * 1000.0)
	var swing: Dictionary = rules.get("swing", {})
	windup_ticks = roundi(float(swing.get("windup_seconds", 0.3)) * tps)
	recovery_ticks = roundi(float(swing.get("recovery_seconds", 0.3)) * tps)
	firm_before_ticks = maxi(windup_ticks, roundi(float(swing.get("firm_before_seconds", 0.0)) * tps))
	firm_after_ticks = maxi(recovery_ticks, roundi(float(swing.get("firm_after_seconds", 0.0)) * tps))
	for team_index in 2:
		var team := Team.new()
		team.levels = levels[team_index]
		teams.append(team)


func _notification(what: int) -> void:
	# Animals point at their targets; clear that so finished fights free their memory.
	if what == NOTIFICATION_PREDELETE:
		for f in fighters:
			f.target = null


# --- Info ------------------------------------------------------------------

func level_of(team: int, card_id: String) -> int:
	return int(teams[team].levels.get(card_id, GameData.start_level(GameData.get_card(card_id).get("rarity", "common"))))


func units(team: int) -> Array:
	return fighters.filter(func(f): return f.alive and f.kind == "unit" and f.team == team)


## Makes the field `scale` times its smallest size (the same shape), for big
## herds; `smallest` (field units, if given) sets that smallest size. Only
## between fights: it doesn't move anyone.
func set_size(scale: float, smallest := Vector2i.ZERO) -> void:
	if smallest.x > 0 and smallest.y > 0:
		base_width = smallest.x
		base_height = smallest.y
	width = roundi(base_width * maxf(1.0, scale) / 2.0) * 2
	height = roundi(base_height * maxf(1.0, scale) / 2.0) * 2
	middle = height / 2


## True if (x, y) is on `team`'s own half of the field.
func on_own_half(team: int, y: int) -> bool:
	return y >= middle if team == 0 else y < middle


## How much of a team's herd is still standing: each animal counts its card's
## power ("cost" in animals.json; split among a pack or squad, and times its
## stars in Draft Duel) times the share of health it has left, in thousandths of a
## power point.
func herd_value(team: int) -> int:
	var total := 0
	for f in units(team):
		var count := int(f.memory.get("squad_units", group_size(f.card)))
		var stars := maxi(1, int(f.memory.get("stars", 1)))
		total += int(f.card.cost) * stars * 1000 * f.hp / maxi(1, f.max_hp) / count
	return total


# --- Running the fight -----------------------------------------------------

## Returns the events since the last call and forgets them.
func take_events() -> Array:
	var taken := events
	events = []
	return taken


## Advances the fight by one tick.
func step() -> void:
	if events.size() > 2000:
		events.clear()  # nobody is collecting them (tests, simulations)
	tick += 1
	for f in fighters:
		f.prev_x = f.x
		f.prev_y = f.y
		f.prev_heading = f.heading
		f.prev_walked = f.walked
	if army != null:
		army.before_tick(self)
	for f in fighters.duplicate():
		if f.alive:
			_update(f)
	_update_zones()
	_separate()
	for f in fighters:
		if not f.alive:
			f.target = null  # two animals aiming at each other would never be freed
	fighters = fighters.filter(func(f): return f.alive)


func _update(f: Fighter) -> void:
	_tick_effects(f)
	if not f.alive or f.kind == "bait":
		return
	if f.deploy_ticks > 0:
		f.deploy_ticks -= 1
		return
	if f.stun > 0:
		return
	if f.cooldown > 0:
		f.cooldown -= 100 + (f.rage_attack_pct if f.rage > 0 else 0) + BattleStyles.haste_pct(self, f)
	BattleAbilities.on_tick(self, f)
	if not f.alive or f.stun > 0:
		return
	# Panicked by a Dragon's fire: it runs out of it, and doesn't fight.
	if BattleStyles.scared(self, f):
		return
	# Its style may take this turn (a charge under way, hiding in its shell,
	# a snack).
	if BattleStyles.act(self, f):
		return

	if f.memory.get("burrowing", false):
		_move_burrowed(f)
		return
	if army != null and f.memory.has("slot"):
		army.update_unit(self, f)
		return
	_choose_target(f)
	if f.target == null:
		return
	note_swing(f, in_range(f, f.target))
	if in_range(f, f.target):
		if f.cooldown <= 0:
			attack(f, f.target)
			f.cooldown = f.hit_ticks * 100
	elif not mid_swing(f):
		move_toward_point(f, Vector2i(f.target.x, f.target.y), current_speed(f))


func _tick_effects(f: Fighter) -> void:
	if f.stun > 0:
		f.stun -= 1
	if f.slow > 0:
		f.slow -= 1
	if f.rage > 0:
		f.rage -= 1
	if f.revealed > 0:
		f.revealed -= 1
	if f.invulnerable > 0:
		f.invulnerable -= 1
	if f.anti_heal > 0:
		f.anti_heal -= 1
	if int(f.memory.get("grounded", 0)) > 0:
		f.memory.grounded -= 1
	if f.poison > 0:
		f.poison -= 1
		f.memory.poison_left = int(f.memory.get("poison_left", 0)) + f.poison_dps
		var amount := int(f.memory.poison_left) / tps
		f.memory.poison_left = int(f.memory.poison_left) % tps
		deal_damage(f, amount, null)
	# Burning (Cerberus's fire breath): like poison, in fire.
	if int(f.memory.get("burn", 0)) > 0:
		f.memory.burn = int(f.memory.burn) - 1
		f.memory.burn_left = int(f.memory.get("burn_left", 0)) + int(f.memory.get("burn_dps", 0))
		var burned := int(f.memory.burn_left) / tps
		f.memory.burn_left = int(f.memory.burn_left) % tps
		deal_damage(f, burned, null)
	if f.lifetime > 0:
		f.lifetime -= 1
		if f.lifetime == 0:
			f.alive = false
			events.append({"type": "expire", "uid": f.uid, "x": f.x, "y": f.y})
	if f.alive:
		BattleAbilities.on_tick_effects(self, f)


func _update_zones() -> void:
	for zone in zones:
		zone.ticks -= 1
		if zone.has("hps"):
			for f in units(zone.team):
				if dist_to_point(f, zone.x, zone.y) <= zone.radius + f.radius:
					zone.acc[f.uid] = int(zone.acc.get(f.uid, 0)) + int(zone.hps)
					heal(f, int(zone.acc[f.uid]) / tps)
					zone.acc[f.uid] = int(zone.acc[f.uid]) % tps
		if zone.has("line"):
			BattleStyles.burn(self, zone)
		if zone.has("crawl"):
			BattleStyles.crawl(self, zone)
		if zone.has("frost"):
			BattleStyles.frost(self, zone)
		if zone.has("ink"):
			BattleStyles.ink(self, zone)
	zones = zones.filter(func(z): return z.ticks > 0)


# --- Targeting and movement ------------------------------------------------

func can_target(f: Fighter, t: Fighter) -> bool:
	if t == null or not t.alive or t.team == f.team:
		return false
	if t.kind == "bait":
		return f.is_unit() and not f.is_flying()
	if t.stealthed and t.revealed <= 0:
		return false
	if t.is_flying() and f.targets != "air_ground":
		return false
	return not t.memory.get("burrowing", false)


## Who `f` fights: the targeting rules (targeting.gd) on the open field,
## where every enemy it can attack is in reach of its feet.
func _choose_target(f: Fighter) -> void:
	var t := f.target
	var ok := t != null and can_target(f, t)
	f.target = targeting.decide(self, f, ok, func() -> Fighter: return _find_target(f), prefers_of(f))


## Whether `f` likes `t` better than the closest enemy, as a Callable for
## the targeting rules: its ability's pick (BattleStyles.prefers), or the
## class its class goes after within that class's reach (classes.json
## "prefer").
func prefers_of(f: Fighter, wanted := "", reach := -1) -> Callable:
	var prefer: Dictionary = GameData.class_rules.get("prefer", {}).get(f.cls, {})
	if wanted == "":
		wanted = String(prefer.get("class", ""))
	if reach < 0:
		reach = roundi(float(prefer.get("tiles", 0)) * TILE)
	var memo := {}
	return func(t: Fighter) -> bool:
		if t.kind == "bait":
			return true
		if wanted != "" and t.cls == wanted and edge_distance(f, t) <= reach:
			return true
		return BattleStyles.prefers(self, f, t, memo)


## Food bait close by first; then what its class goes after (Tank Destroyers
## look for Tanks, Ranged for Air, within reach: classes.json "prefer"); then
## the nearest enemy, so nobody stands around.
func _find_target(f: Fighter) -> Fighter:
	if not f.is_flying():
		for t in fighters:
			if t.kind == "bait" and t.alive and t.team != f.team and dist(f, t) <= t.lure_radius:
				return t
	# Its style may have its own idea (the biggest enemy, a Tank to charge...).
	var picked := BattleStyles.prefer_target(self, f)
	if picked != null:
		return picked
	var prefer: Dictionary = GameData.class_rules.get("prefer", {}).get(f.cls, {})
	var reach := roundi(float(prefer.get("tiles", 0)) * TILE)
	var wanted := String(prefer.get("class", ""))
	# One pass: the nearest enemy, and the nearest one its class goes after.
	var best: Fighter = null
	var best_dist := 1 << 40
	var nearest: Fighter = null
	var nearest_dist := 1 << 40
	for t in fighters:
		if t.team == f.team or t.kind == "bait" or not can_target(f, t):
			continue
		var d := edge_distance(f, t)
		if d < nearest_dist:
			nearest = t
			nearest_dist = d
		if wanted != "" and d <= reach and d < best_dist and t.cls == wanted:
			best = t
			best_dist = d
	return best if best != null else nearest


## Whether `t` is within `f`'s reach: for a melee animal, the gap between
## the ends of their bodies (nose to nose, bodies.json footprint) is at
## most its reach; for a shooter, the gap between their bodies' circles
## (its shot flies from its body to the target's) is at most its range.
func in_range(f: Fighter, t: Fighter) -> bool:
	return reach_gap(f, t) <= f.attack_range


## The gap `f`'s reach is measured over to `t`: nose to nose for a melee
## animal, body to body for a shooter.
static func reach_gap(f: Fighter, t: Fighter) -> int:
	return edge_distance(f, t) if f.shooter else gap(f, t)


## How far `f`'s reach starts from its middle (half its body for a melee
## animal; its body's circle for a shooter), and how far `t`'s body
## extends toward it, the same way.
static func reach_from(f: Fighter) -> int:
	return f.radius if f.shooter else f.nose


static func reach_to(f: Fighter, t: Fighter) -> int:
	return t.radius if f.shooter else t.nose


## How far `f`'s body reaches out to each side of the way it faces: its
## room's circle, or half its long side when that runs across (a flier's
## wingspan, an upright animal's spread arms).
static func side_room(f: Fighter) -> int:
	return f.half if f.across else f.radius


## The gap between the fronts of two bodies (nose to nose), field units.
static func gap(a: Fighter, b: Fighter) -> int:
	return maxi(0, dist(a, b) - a.nose - b.nose)


## Whether `f` is in the middle of a swing and stands still for it: its
## blow was recovery_ticks ago or less, or is counting down to land within
## windup_ticks with its target in reach (the strike plays out where it
## started). With the target out of reach it walks after it as before.
func mid_swing(f: Fighter) -> bool:
	if tick - int(f.memory.get("blow", -1000)) < recovery_ticks:
		return true
	var t := f.target
	if t == null or not t.alive or f.cooldown <= 0 or f.cooldown > windup_ticks * 100:
		return false
	# (A fighter waiting for a slot on its target won't strike it.)
	if army != null and not army.has_slot(f, t):
		return false
	return in_range(f, t)


## Whether `f` holds its ground against the crowd's shoves: through its
## whole swing as the screen plays it, from firm_before_ticks before its
## blow (its target in reach, free to strike) until firm_after_ticks after
## (a little longer than it stands still for it: mid_swing).
func holds_firm(f: Fighter) -> bool:
	if tick - int(f.memory.get("blow", -1000)) < firm_after_ticks:
		return true
	var t := f.target
	if t == null or not t.alive or f.cooldown <= 0 or f.cooldown > firm_before_ticks * 100:
		return false
	if army != null and not army.has_slot(f, t):
		return false
	return in_range(f, t)


## Keeps track of when `f`'s swing began on the screen: from the tick it
## could strike (its target in reach and free to hit) with its blow within
## a wind-up's time; reset while it can't. (Only for how long it holds its
## ground after the blow: when the blow, and its damage, comes never changes.)
func note_swing(f: Fighter, can_strike: bool) -> void:
	if can_strike and f.cooldown <= firm_before_ticks * 100:
		if int(f.memory.get("swing_from", -1)) < 0:
			f.memory.swing_from = tick
	else:
		f.memory.swing_from = -1


func current_speed(f: Fighter) -> int:
	var pct := 100
	if f.slow > 0:
		pct -= f.slow_pct
	if f.rage > 0:
		pct += f.rage_speed_pct
	pct += BattleAbilities.speed_bonus_pct(self, f)
	return maxi(0, f.speed * maxi(0, pct) / 100)


func move_toward_point(f: Fighter, goal: Vector2i, step_size: int) -> void:
	var dx := goal.x - f.x
	var dy := goal.y - f.y
	var d := isqrt(dx * dx + dy * dy)
	if d == 0 or step_size <= 0:
		return
	var moved := mini(step_size, d)
	f.wants = Vector2i(dx * 1000 / d, dy * 1000 / d)
	var from := Vector2i(f.x, f.y)
	if d <= step_size:
		f.x = goal.x
		f.y = goal.y
	else:
		f.x += dx * step_size / d
		f.y += dy * step_size / d
	f.walked += Vector2i(f.x, f.y) - from
	f.memory.run = int(f.memory.get("run", 0)) + moved
	BattleAbilities.on_moved(self, f)


## Burrowing animals travel underground, unseen, to just behind the enemy's
## last row, and pop up there (or at once, when the rest of their herd is
## gone).
func _move_burrowed(f: Fighter) -> void:
	# The last of its herd above ground (the rest have fallen): it comes up
	# at once (nobody's left to keep the enemy busy while it digs).
	var company: bool = teams[f.team].defeated == 0
	for o in fighters:
		if company:
			break
		if o.alive and o.team == f.team and o.is_unit() and not o.memory.get("burrowing", false):
			company = true
			break
	var back: Fighter = null
	for t in fighters:
		if t.alive and t.team != f.team and t.is_unit() and not t.is_flying():
			# The enemy furthest from the middle, on its own side.
			if back == null or (t.y < back.y if t.team == 1 else t.y > back.y):
				back = t
	if back == null or not company:
		f.memory.burrowing = false
		if back != null:
			events.append({"type": "emerge", "uid": f.uid, "x": f.x, "y": f.y})
			BattleStyles.on_emerge(self, f)
		return
	# Just behind it, clear of its body (and its own).
	var behind := maxi(TILE, back.half + f.half + TILE / 10) * (1 if back.team == 1 else -1)
	var goal := Vector2i(back.x, clampi(back.y - behind, f.radius, height - f.radius))
	# Its style may pick the spot (the Fox by the Ranged, the Pangolin under
	# a Tank).
	var own: Variant = BattleStyles.burrow_goal(self, f)
	if own != null:
		goal = own
	if dist_to_point(f, goal.x, goal.y) <= TILE / 4:
		f.memory.burrowing = false
		events.append({"type": "emerge", "uid": f.uid, "x": f.x, "y": f.y})
		BattleStyles.on_emerge(self, f)
		return
	move_toward_point(f, goal, current_speed(f))


## Pushes overlapping animals apart and keeps everyone on the field. Only
## animals in neighboring squares of a coarse grid are compared, so big herds
## stay cheap.
func _separate() -> void:
	var walkers: Array = []
	var flying: Array = []
	var grid := {}
	for f in fighters:
		if f.alive and f.kind == "unit":
			_turn_body(f)
		if f.alive and f.kind == "unit" and not f.memory.get("burrowing", false):
			var key: int = (f.x / SEPARATE_CELL) * 4096 + f.y / SEPARATE_CELL
			if not grid.has(key):
				grid[key] = []
			grid[key].append(walkers.size())
			walkers.append(f)
			flying.append(f.is_flying())
	# Who holds its ground this tick: one mid-swing stands where its strike
	# began, one ploughing through keeps its line; the other takes the shove.
	var firm: Array = []
	for f: Fighter in walkers:
		var finishing := tick < int(f.memory.get("firm_until", -1)) and f.walked == f.prev_walked
		firm.append(ploughs(f) or holds_firm(f) or finishing)
	for i in walkers.size():
		var a: Fighter = walkers[i]
		var cell_x := a.x / SEPARATE_CELL
		var cell_y := a.y / SEPARATE_CELL
		for cx in range(cell_x - 1, cell_x + 2):
			for cy in range(cell_y - 1, cell_y + 2):
				var key := cx * 4096 + cy
				if grid.has(key):
					for j in grid[key]:
						if j > i and flying[i] == flying[j]:
							_push_apart(a, walkers[j], firm[i], firm[j])
	# Round the bodies going down, too.
	corpses = corpses.filter(func(c): return int(c[3]) > tick)
	for c in corpses:
		var cs := spine(int(c[0]), int(c[1]), int(c[4]), int(c[5]), c[6], bool(c[7]))
		for i in walkers.size():
			var f: Fighter = walkers[i]
			if flying[i]:
				continue
			if absi(f.x - int(c[0])) >= f.half + int(c[4]) or absi(f.y - int(c[1])) >= f.half + int(c[4]):
				continue
			var body := f.hw + int(c[5])
			# Out along its deepest overlap with the body going down (once, not
			# once for every pair of circles that touch).
			var best := 0
			var bx := 0
			var by := 0
			var bd := 1
			for pf: Vector2i in spine(f.x, f.y, f.half, f.hw, f.heading, f.across):
				for pc: Vector2i in cs:
					var dx := pf.x - pc.x
					var dy := pf.y - pc.y
					if absi(dx) >= body or absi(dy) >= body:
						continue
					var d := isqrt(dx * dx + dy * dy)
					if d >= body:
						continue
					if d == 0:
						dx = 1 if f.uid % 2 == 0 else -1
						d = 1
					if body - d + 1 > best:
						best = body - d + 1
						bx = dx
						by = dy
						bd = d
			if best > 0:
				f.x += bx * best / bd
				f.y += by * best / bd
	for f in walkers:
		f.x = clampi(f.x, f.radius, width - f.radius)
		f.y = clampi(f.y, f.radius, height - f.radius)


## Turns `f`'s body toward what it wants to face (its target in reach, or
## the way it goes) by at most turn_degrees_per_tick, as the drawn animal
## turns, so its spine sweeps round at the same pace. Whole numbers only.
## Through the follow-through of its blow it keeps facing where it struck
## (the swing finishes before it turns to the next).
func _turn_body(f: Fighter) -> void:
	if tick - int(f.memory.get("blow", -1000)) < recovery_ticks:
		return
	var t := f.target
	var in_reach := t != null and t.alive and in_range(f, t)
	if in_reach:
		var d := dist(f, t)
		if d > 0:
			f.wants = Vector2i((t.x - f.x) * 1000 / d, (t.y - f.y) * 1000 / d)
	elif army != null and not army.at_war() and f.memory.has("slot") and not f.memory.get("free", false) and not f.memory.get("charging", false) and f.stun <= 0:
		# In its place in the formation: facing the enemy's side, even while
		# stepping into place.
		f.wants = Vector2i(0, -1000) if f.team == 0 else Vector2i(0, 1000)
	var h := f.heading
	var w := f.wants
	var cross := h.x * w.y - h.y * w.x
	var dot := h.x * w.x + h.y * w.y
	# Within a tick's turn of it (the cosine of the angle between them is at
	# least the turn's): there.
	if dot >= turn_cos * 1000:
		f.heading = w
		return
	var sign := 1 if cross > 0 or (cross == 0 and (f.uid % 2 == 0)) else -1
	var nx := (h.x * turn_cos - sign * h.y * turn_sin) / 1000
	var ny := (sign * h.x * turn_sin + h.y * turn_cos) / 1000
	var n := isqrt(nx * nx + ny * ny)
	if n > 0:
		f.heading = Vector2i(nx * 1000 / n, ny * 1000 / n)


## An animal's body on the field as circles along its spine (nose to
## tail; across it, wingtip to wingtip or hand to hand, when its long side
## runs across), each half its width wide (bodies.json footprint and
## width), pointing where it heads or strikes: its middle and its two ends,
## and more between when it's long and thin, so its whole outline is
## covered (no ends sticking out past a round body's circle, no gaps
## between a thin body's circles).
static func spine(x: int, y: int, half: int, hw: int, heading: Vector2i, across: bool) -> Array:
	var s := half - hw
	if s <= 0:
		return [Vector2i(x, y)]
	var axis := Vector2i(-heading.y, heading.x) if across else heading
	var per_side := clampi((s + hw - 1) / maxi(1, hw), 1, 4)
	var out := [Vector2i(x, y)]
	for k in range(1, per_side + 1):
		var d := s * k / per_side
		out.append(Vector2i(x + axis.x * d / 1000, y + axis.y * d / 1000))
		out.append(Vector2i(x - axis.x * d / 1000, y - axis.y * d / 1000))
	return out


## Whether `f` ploughs through the others in its way, shoving them aside
## rather than being pushed back itself: a Rhino's charge, a Seal's
## belly-slide, a Dragon's fire run.
static func ploughs(f: Fighter) -> bool:
	return int(f.memory.get("charge_state", 0)) == 1 or int(f.memory.get("slide_left", 0)) > 0 or int(f.memory.get("run_left", 0)) > 0


## Two animals too close: their bodies (spine circles) overlapping are
## pushed apart at once, and within personal space they're nudged apart
## gently (push_pct of the gap a tick).
func _push_apart(a: Fighter, b: Fighter, firm_a := false, firm_b := false) -> void:
	var reach := a.half + b.half + personal_space
	if absi(b.x - a.x) >= reach or absi(b.y - a.y) >= reach:
		return
	var body := a.hw + b.hw
	var min_d := body + personal_space
	var ca := spine(a.x, a.y, a.half, a.hw, a.heading, a.across)
	var cb := spine(b.x, b.y, b.half, b.hw, b.heading, b.across)
	# One holding its ground (mid-swing, or ploughing through: a Rhino's
	# charge, a Seal's belly-slide, a Dragon's fire run) isn't pushed: the
	# other takes the whole shove.
	var share_a := 0 if firm_a and not firm_b else (2 if firm_b and not firm_a else 1)
	var share_b := 2 - share_a
	# One push, along the deepest overlap (not one for every pair of circles
	# that touch: a long body's many circles would shove far too hard).
	var best := 0
	var bx := 0
	var by := 0
	var bd := 1
	for pa: Vector2i in ca:
		for pb: Vector2i in cb:
			var dx := pb.x - pa.x
			var dy := pb.y - pa.y
			if absi(dx) >= min_d or absi(dy) >= min_d:
				continue
			var d := isqrt(dx * dx + dy * dy)
			if d >= min_d:
				continue
			if d == 0:
				dx = 1 if (a.uid + b.uid) % 2 == 0 else -1
				dy = 0
				d = 1
			var push := 0
			if d < body:
				push = (body - d) / 2 + 1
			push += (min_d - maxi(d, body)) * space_push_pct / 200
			if push > best:
				best = push
				bx = dx
				by = dy
				bd = d
	if best > 0:
		a.x -= bx * best * share_a / bd
		a.y -= by * best * share_a / bd
		b.x += bx * best * share_b / bd
		b.y += by * best * share_b / bd


# --- Fighting --------------------------------------------------------------

## One blow (or shot) from `f` at `t`, carrying `pct` percent of its bite
## (a volley's shot carries the time since the last).
func attack(f: Fighter, t: Fighter, pct := 100) -> void:
	# Blinded by a Kraken's ink: a Ranged or Air animal can't hit.
	if BattleStyles.blinded(self, f, t):
		events.append({"type": "blind_miss", "uid": f.uid, "to": t.uid, "x": f.x, "y": f.y})
		return
	# A shot at an animal right behind a guardian hits the guardian instead.
	var aimed := t
	t = BattleStyles.redirect(self, f, t)
	var amount := f.damage * pct / 100
	if f.rage > 0:
		amount = amount * (100 + f.rage_damage_pct) / 100
	# Its style's say in this blow (a huge first hit, a pack bite...).
	amount = BattleStyles.attack_amount(self, f, t, amount)
	amount = BattleAbilities.outgoing_damage(self, f, t, amount)
	# Some luck in every hit, if the rules ask for it.
	var variance := int(rules.get("damage_variance_pct", 0))
	if variance > 0:
		amount = amount * (100 + rng.randi_range(-variance, variance)) / 100
	f.stealthed = false
	f.memory.attacked = true
	f.memory.last_combat = tick
	f.memory.blow = tick
	# A blow before a full wind-up's worth of swing (it just got here, its
	# attack long ready): on the screen its swing is only starting, so it
	# holds its ground against shoves until that swing is done too.
	var from := int(f.memory.get("swing_from", -1))
	var swung := tick - from if from >= 0 else 0
	f.memory.firm_until = tick + firm_after_ticks + maxi(0, firm_before_ticks - swung)
	f.memory.swing_from = -1
	var hd := dist(f, t)
	if hd > 0:
		f.wants = Vector2i((t.x - f.x) * 1000 / hd, (t.y - f.y) * 1000 / hd)
	targeting.struck(self, f, t)
	var hit := {
		"type": "hit", "from": f.uid, "from_kind": f.kind, "to": t.uid, "to_kind": t.kind,
		"x": t.x, "y": t.y, "fx": f.x, "fy": f.y, "amount": amount, "ranged": f.attack_range > 1500,
	}
	if t != aimed:
		hit.guard = true
	if f.style_kind != "":
		hit.style = f.style_kind
	events.append(hit)
	var hp_before := t.hp
	deal_damage(t, amount, f)
	# What it really took (after shields), for the screen's health bar.
	hit.dealt = maxi(0, hp_before - maxi(t.hp, 0))
	BattleAbilities.after_hit(self, f, t, amount)
	f.memory.run = 0


## An extra blow from `f` at `t` that isn't one of its own attacks (a
## cleave's second target, a charge knocking an enemy aside...): shown on
## screen like a hit, with no follow-ups of its own. `extra` goes into the
## hit event (what kind of blow it is, for the screen).
func strike(f: Fighter, t: Fighter, amount: int, extra: Dictionary = {}) -> void:
	if not t.alive or amount <= 0:
		return
	var hit := {
		"type": "hit", "from": f.uid, "from_kind": f.kind, "to": t.uid, "to_kind": t.kind,
		"x": t.x, "y": t.y, "fx": f.x, "fy": f.y, "amount": amount, "ranged": false,
	}
	hit.merge(extra, true)
	events.append(hit)
	var hp_before := t.hp
	deal_damage(t, amount, f)
	hit.dealt = maxi(0, hp_before - maxi(t.hp, 0))
	t.memory.last_combat = tick


func deal_damage(t: Fighter, amount: int, source: Fighter) -> void:
	if not t.alive or amount <= 0:
		return
	amount = BattleAbilities.incoming_damage(self, t, amount, source)
	if amount <= 0:
		return
	t.hp -= amount
	t.memory.last_combat = tick
	if t.hp <= 0:
		_defeat(t, source)
	else:
		BattleAbilities.after_damaged(self, t)


func heal(f: Fighter, amount: int) -> void:
	if not f.alive or not f.is_unit() or amount <= 0:
		return
	if f.anti_heal > 0:
		amount = amount * (100 - f.anti_heal_pct) / 100
	f.hp = mini(f.max_hp, f.hp + amount)


func _defeat(t: Fighter, source: Fighter) -> void:
	if t.is_unit() and BattleAbilities.prevent_defeat(self, t):
		return
	t.alive = false
	t.hp = 0
	events.append({"type": "death", "uid": t.uid, "kind": t.kind, "team": t.team, "x": t.x, "y": t.y})
	if t.is_unit() and not t.is_flying():
		corpses.append([t.x, t.y, t.radius, tick + body_down_ticks, t.half, t.hw, t.heading, t.across])
	if t.is_unit():
		teams[t.team].defeated += 1
		BattleAbilities.on_defeated(self, t, source)
		if army != null:
			army.fell(self, t)


## Stuns `t` for `ticks`. It keeps its target (a stun is no reason to
## switch: the targeting rules) and carries on with it after.
func stun(t: Fighter, ticks: int) -> void:
	if t.alive and not BattleAbilities.is_fearless(t):
		t.stun = maxi(t.stun, ticks)


func slow_down(t: Fighter, pct: int, ticks: int, ignore_fearless := false) -> void:
	if not t.alive or (BattleAbilities.is_fearless(t) and not ignore_fearless):
		return
	var current := t.slow_pct if t.slow > 0 else 0
	t.slow = maxi(t.slow, ticks)
	t.slow_pct = maxi(current, pct)


func knock_back(t: Fighter, from_x: int, from_y: int, distance: int) -> void:
	if not t.alive or not t.is_unit() or BattleStyles.steady(t):
		return
	var dx := t.x - from_x
	var dy := t.y - from_y
	var d := isqrt(dx * dx + dy * dy)
	if d == 0:
		dy = -1 if t.team == 0 else 1
		d = 1
	t.x = clampi(t.x + dx * distance / d, t.radius, width - t.radius)
	t.y = clampi(t.y + dy * distance / d, t.radius, height - t.radius)


## Enemies of `team` within `radius` of a point (edges count).
func enemies_near(team: int, px: int, py: int, radius: int) -> Array:
	var found := []
	for f in fighters:
		if f.alive and f.team != team and f.is_unit():
			if dist_to_point(f, px, py) <= radius + f.radius:
				found.append(f)
	return found


func allies_near(team: int, px: int, py: int, radius: int) -> Array:
	var found := []
	for f in units(team):
		if dist_to_point(f, px, py) <= radius + f.radius:
			found.append(f)
	return found


# --- Creating fighters -----------------------------------------------------

## Puts one card's squad on the field around (x, y): as many animals as
## its class brings (classes.json "squads": Tank 1, Tank Destroyer 2,
## Ranged 3, Air 2, Specialist 1, Mythic 1), each with its share of the
## card's health and bite. (Draft Duel's armies go through BattleArmy,
## which does the same and gives each a place in the formation.)
func spawn(team: int, card_id: String, x: int, y: int) -> Array:
	var squad := BattleArmy.squad_of(card_id)
	var count := int(squad.units)
	var made := spawn_units(team, card_id, count, x, y)
	var bite := int(rules.get("army", {}).get("damage_pct", 100))
	for i in made.size():
		var f: Fighter = made[i]
		var offset := formation(i, count)
		# (Wider for big bodies, so a group's animals stand clear of each other.)
		var room := maxf(1.0, float(2 * side_room(f) + TILE / 10) / 800.0)
		f.x = clampi(x + roundi(offset.x * room), f.radius, width - f.radius)
		f.y = clampi(y + roundi(offset.y * room), f.radius, height - f.radius)
		f.prev_x = f.x
		f.prev_y = f.y
		BattleArmy.apply_share(f, squad, bite)
	return made


## Puts `count` animals of a card on the field at (x, y), as one group (an
## army's squad: BattleArmy gives them their places).
func spawn_units(team: int, card_id: String, count: int, x: int, y: int) -> Array:
	var card := GameData.get_card(card_id)
	var group := _next_group
	_next_group += 1
	var made := []
	for i in count:
		var f := _make_unit(team, card, level_of(team, card_id), x, y)
		f.memory.group = group
		f.memory.group_size = count
		fighters.append(f)
		made.append(f)
	for f in made:
		BattleAbilities.on_spawn(self, f, f == made[0])
	return made


func _make_unit(team: int, card: Dictionary, level: int, x: int, y: int) -> Fighter:
	var f := Fighter.new()
	f.uid = _next_uid
	_next_uid += 1
	f.team = team
	f.kind = "unit"
	f.card = card
	f.level = level
	var stats: Dictionary = card.stats
	var start := GameData.start_level(card.rarity)
	var growth := float(GameData.progression.stat_growth_per_level)
	f.max_hp = CardRules.stat_at_level(float(stats.hp), level, start, growth)
	f.hp = f.max_hp
	f.damage = CardRules.stat_at_level(float(stats.damage), level, start, growth)
	f.hit_ticks = maxi(1, roundi(float(stats.hit_speed) * tps))
	f.cooldown = f.hit_ticks * 50
	var tiles := float(stats.range)
	# A melee animal hits as far as its strike reaches beyond its body
	# (bodies.json reach); a shooter as far as its card says.
	f.attack_range = unit_reach(card) if tiles <= 1.0 else roundi(tiles * TILE)
	f.shooter = tiles > 1.0
	f.speed = int(rules.speed_values.get(stats.speed, 60)) * TILE / (60 * tps)
	# Its class decides what it can hit, whether it flies, and (for Ranged)
	# how far it reaches at least.
	f.cls = String(card.get("class", ""))
	f.trait_id = String(card.get("trait", ""))
	f.style = GameData.styles.get(String(card.get("id", "")), {})
	f.style_kind = String(f.style.get("kind", ""))
	var info: Dictionary = GameData.class_info(f.cls)
	f.flying = bool(info.get("flying", false))
	f.targets = String(info.get("targets", stats.targets))
	if info.has("range"):
		f.attack_range = maxi(f.attack_range, roundi(float(info.range) * TILE))
	f.radius = unit_radius(card)
	f.half = unit_half(card)
	f.hw = unit_half_width(card)
	var arms := bool(GameData.bodies.get("animals", {}).get(String(card.get("id", "")), {}).get("across", false))
	f.across = f.flying or arms
	# (A flier's reach is measured from its wingtips, as it always was: it
	# strikes diving from above.)
	f.nose = f.hw if arms and not f.flying else f.half
	f.heading = Vector2i(0, -1000) if team == 0 else Vector2i(0, 1000)
	f.prev_heading = f.heading
	f.wants = f.heading
	f.deploy_ticks = deploy_ticks
	f.x = clampi(x, f.radius, width - f.radius)
	f.y = clampi(y, f.radius, height - f.radius)
	f.prev_x = f.x
	f.prev_y = f.y
	return f


## Food bait from the Food Bait tool.
func make_bait(team: int, x: int, y: int, hp: int, ticks: int, lure_radius: int) -> Fighter:
	var f := Fighter.new()
	f.uid = _next_uid
	_next_uid += 1
	f.team = team
	f.kind = "bait"
	f.x = x
	f.y = y
	f.prev_x = x
	f.prev_y = y
	f.max_hp = hp
	f.hp = hp
	f.radius = 400
	f.lifetime = ticks
	f.lure_radius = lure_radius
	fighters.append(f)
	return f


func add_zone(zone: Dictionary) -> void:
	zone["acc"] = {}
	zones.append(zone)


## Takes everything off the field and ends lingering areas, ready for the
## next round.
func clear_units() -> void:
	for f in fighters:
		f.target = null
	fighters.clear()
	zones.clear()
	army = null


## A separate copy of the fight as it stands, to try out what happens next.
## Running the copy never changes this fight.
func clone() -> BattleSim:
	var copy := BattleSim.new([{}, {}], 0, rules)
	copy.tick = tick
	copy._next_uid = _next_uid
	copy._next_group = _next_group
	copy.width = width
	copy.height = height
	copy.middle = middle
	copy.base_width = base_width
	copy.base_height = base_height
	copy.rng.seed = rng.seed
	copy.rng.state = rng.state
	copy.zones = zones.duplicate(true)
	copy.corpses = corpses.duplicate(true)
	copy.army = army.copy() if army != null else null
	copy.teams = []
	for t in teams:
		copy.teams.append(_copy_fields(t, Team.new()))
	var by_uid := {}
	copy.fighters = []
	for f in fighters:
		var twin: Fighter = _copy_fields(f, Fighter.new())
		by_uid[f.uid] = twin
		copy.fighters.append(twin)
	for twin in copy.fighters:
		if twin.target != null:
			twin.target = by_uid.get(twin.target.uid)
	return copy


## Copies every script variable from one object to another. Arrays and
## dictionaries are copied too, except a fighter's card, which never changes.
static func _copy_fields(from: Object, to: Object) -> Object:
	for prop in from.get_property_list():
		if not prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			continue
		var value: Variant = from.get(prop.name)
		if (value is Dictionary or value is Array) and prop.name != "card" and prop.name != "style":
			value = value.duplicate(true)
		to.set(prop.name, value)
	return to


## How many animals a card brings: its class's squad (classes.json
## "squads").
static func group_size(card: Dictionary) -> int:
	return int(BattleArmy.squad_of(String(card.get("id", ""))).units)


## How much room an animal takes on the field: a circle between its body's
## width and its length (bodies.json footprint and width: the square root
## of the two, halved), so a line of bodies stands clear and nothing walks
## through one; its class's squad radius (classes.json "squads") when it
## has no body.
static func unit_radius(card: Dictionary) -> int:
	var body: Dictionary = GameData.bodies.get("animals", {}).get(String(card.get("id", "")), {})
	if body.has("footprint"):
		return roundi(sqrt(float(body.footprint) * float(body.get("width", body.footprint))) * TILE / 2.0)
	return int(BattleArmy.squad_of(String(card.get("id", ""))).radius)


## Half an animal's body width (bodies.json width, field units).
static func unit_half_width(card: Dictionary) -> int:
	var body: Dictionary = GameData.bodies.get("animals", {}).get(String(card.get("id", "")), {})
	if body.has("width"):
		return roundi(float(body.width) * TILE / 2.0)
	return unit_radius(card)


## Half an animal's body length (bodies.json footprint, field units): a
## strike is measured from its body's end.
static func unit_half(card: Dictionary) -> int:
	var body: Dictionary = GameData.bodies.get("animals", {}).get(String(card.get("id", "")), {})
	if body.has("footprint"):
		return roundi(float(body.footprint) * TILE / 2.0)
	return unit_radius(card)


## How far a melee animal's strike reaches beyond its body (bodies.json
## reach; the rules' melee_range when it has none), field units.
static func unit_reach(card: Dictionary) -> int:
	var body: Dictionary = GameData.bodies.get("animals", {}).get(String(card.get("id", "")), {})
	if body.has("reach") and not body.get("shooter", false):
		return roundi(float(body.reach) * TILE)
	return roundi(float(GameData.battle_rules.get("melee_range", 0.7)) * TILE)


## Where each animal of a group stands, relative to its spot.
static func formation(index: int, count: int) -> Vector2i:
	match count:
		2:
			return [Vector2i(-400, 0), Vector2i(400, 0)][index]
		3:
			return [Vector2i(0, -400), Vector2i(-420, 300), Vector2i(420, 300)][index]
		4:
			return [Vector2i(-380, -380), Vector2i(380, -380), Vector2i(-380, 380), Vector2i(380, 380)][index]
	return Vector2i.ZERO


# --- Geometry --------------------------------------------------------------

static func isqrt(n: int) -> int:
	if n <= 0:
		return 0
	var r := int(sqrt(float(n)))
	while r * r > n:
		r -= 1
	while (r + 1) * (r + 1) <= n:
		r += 1
	return r


static func dist(a: Fighter, b: Fighter) -> int:
	return isqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y))


static func edge_distance(a: Fighter, b: Fighter) -> int:
	return maxi(0, dist(a, b) - a.radius - b.radius)


static func dist_to_point(f: Fighter, px: int, py: int) -> int:
	return isqrt((f.x - px) * (f.x - px) + (f.y - py) * (f.y - py))


## A number that changes if anything about the fight differs. Two copies of
## the same fight must give the same checksum (online play depends on it).
func checksum() -> int:
	var total := tick * 31
	for f in fighters:
		total = (total * 131 + f.uid * 7 + f.x * 3 + f.y * 5 + f.hp) % 2147483647
	return total
