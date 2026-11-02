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
## long; team 0 starts on the near half (the bottom), team 1 on the far half.
## Animals go for the nearest enemy they can reach. Nothing here draws
## anything (battle_field.gd does that), and Draft Duel (draft_match.gd) runs
## the rounds around it.

const TILE := 1000
const WIDTH := 16 * TILE
const HEIGHT := 20 * TILE
## The line between the two halves.
const MIDDLE := HEIGHT / 2


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
	## Extra per-ability state, e.g. "pounced", "hits", "run".
	var memory: Dictionary = {}

	func ability_id() -> String:
		return card.get("ability", {}).get("id", "")

	func param(param_name: String, default: Variant = 0) -> Variant:
		return card.get("ability", {}).get("params", {}).get(param_name, default)

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


## True if (x, y) is on `team`'s own half of the field.
static func on_own_half(team: int, y: int) -> bool:
	return y >= MIDDLE if team == 0 else y < MIDDLE


## How much of a team's herd is still standing: each animal counts its card's
## cost (split among a pack, and times its stars in Draft Duel) times the
## share of health it has left, in thousandths of a cost point.
func herd_value(team: int) -> int:
	var total := 0
	for f in units(team):
		var count := maxi(1, int(f.card.get("count", 1)))
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
	if int(f.memory.get("playing_dead", 0)) > 0 or f.stun > 0:
		return
	if f.cooldown > 0:
		f.cooldown -= 100 + (f.rage_attack_pct if f.rage > 0 else 0)
	BattleAbilities.on_tick(self, f)
	if not f.alive or f.stun > 0:
		return

	if f.memory.get("burrowing", false):
		_move_burrowed(f)
		return
	_choose_target(f)
	if f.target == null:
		return
	if in_range(f, f.target):
		if f.cooldown <= 0:
			_attack(f, f.target)
			f.cooldown = f.hit_ticks * 100
	else:
		_move_toward(f, Vector2i(f.target.x, f.target.y), current_speed(f))


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
	zones = zones.filter(func(z): return z.ticks > 0)


# --- Targeting and movement ------------------------------------------------

func can_target(f: Fighter, t: Fighter) -> bool:
	if t == null or not t.alive or t.team == f.team or t.uid == f.uid:
		return false
	if t.kind == "bait":
		return f.is_unit() and not f.is_flying()
	if t.stealthed and t.revealed <= 0:
		return false
	if t.memory.get("burrowing", false) or int(t.memory.get("playing_dead", 0)) > 0:
		return false
	if t.is_flying() and f.targets != "air_ground":
		return false
	return true


func _choose_target(f: Fighter) -> void:
	if f.target != null and can_target(f, f.target) and in_range(f, f.target):
		return
	f.target = _find_target(f)


## Food bait close by first; then the nearest enemy in sight; failing that,
## the nearest enemy anywhere, so nobody stands around.
func _find_target(f: Fighter) -> Fighter:
	if not f.is_flying():
		for t in fighters:
			if t.kind == "bait" and t.alive and t.team != f.team and dist(f, t) <= t.lure_radius:
				return t
	var nearest: Fighter = null
	var nearest_dist := 1 << 40
	for t in fighters:
		if t.kind == "bait" or not can_target(f, t):
			continue
		var d := edge_distance(f, t)
		if d < nearest_dist:
			nearest = t
			nearest_dist = d
	return nearest


func in_range(f: Fighter, t: Fighter) -> bool:
	return edge_distance(f, t) <= f.attack_range


func current_speed(f: Fighter) -> int:
	var pct := 100
	if f.slow > 0:
		pct -= f.slow_pct
	if f.rage > 0:
		pct += f.rage_speed_pct
	pct += BattleAbilities.speed_bonus_pct(self, f)
	return maxi(0, f.speed * maxi(0, pct) / 100)


func _move_toward(f: Fighter, goal: Vector2i, step_size: int) -> void:
	var dx := goal.x - f.x
	var dy := goal.y - f.y
	var d := isqrt(dx * dx + dy * dy)
	if d == 0 or step_size <= 0:
		return
	var moved := mini(step_size, d)
	if d <= step_size:
		f.x = goal.x
		f.y = goal.y
	else:
		f.x += dx * step_size / d
		f.y += dy * step_size / d
	f.memory.run = int(f.memory.get("run", 0)) + moved
	BattleAbilities.on_moved(self, f)


## Burrowing animals travel underground straight at the nearest enemy and
## pop up as soon as one they can attack is close.
func _move_burrowed(f: Fighter) -> void:
	var goal: Fighter = null
	var best := 1 << 40
	for t in fighters:
		if t.alive and t.team != f.team and t.is_unit() and not t.is_flying():
			var d := edge_distance(f, t)
			if d <= TILE:
				f.memory.burrowing = false
				events.append({"type": "emerge", "uid": f.uid, "x": f.x, "y": f.y})
				return
			if d < best:
				goal = t
				best = d
	if goal != null:
		_move_toward(f, Vector2i(goal.x, goal.y), current_speed(f))


## Pushes overlapping animals apart and keeps everyone on the field.
func _separate() -> void:
	var walkers: Array = fighters.filter(func(f): return f.alive and f.is_unit() and not f.memory.get("burrowing", false))
	for i in walkers.size():
		var a: Fighter = walkers[i]
		for j in range(i + 1, walkers.size()):
			var b: Fighter = walkers[j]
			if a.is_flying() != b.is_flying():
				continue
			var min_d := a.radius + b.radius
			var dx := b.x - a.x
			var dy := b.y - a.y
			if absi(dx) >= min_d or absi(dy) >= min_d:
				continue
			var d := isqrt(dx * dx + dy * dy)
			if d >= min_d:
				continue
			if d == 0:
				dx = 1 if (a.uid + b.uid) % 2 == 0 else -1
				dy = 0
				d = 1
			var push := (min_d - d) / 2 + 1
			a.x -= dx * push / d
			a.y -= dy * push / d
			b.x += dx * push / d
			b.y += dy * push / d
	for f in walkers:
		f.x = clampi(f.x, f.radius, WIDTH - f.radius)
		f.y = clampi(f.y, f.radius, HEIGHT - f.radius)


# --- Fighting --------------------------------------------------------------

func _attack(f: Fighter, t: Fighter) -> void:
	var amount := f.damage
	if f.rage > 0:
		amount = amount * (100 + f.rage_damage_pct) / 100
	amount = BattleAbilities.outgoing_damage(self, f, t, amount)
	# Some luck in every hit, if the rules ask for it.
	var variance := int(rules.get("damage_variance_pct", 0))
	if variance > 0:
		amount = amount * (100 + rng.randi_range(-variance, variance)) / 100
	f.stealthed = false
	f.memory.attacked = true
	f.memory.last_combat = tick
	events.append({
		"type": "hit", "from": f.uid, "from_kind": f.kind, "to": t.uid, "to_kind": t.kind,
		"x": t.x, "y": t.y, "fx": f.x, "fy": f.y, "amount": amount, "ranged": f.attack_range > 1500,
	})
	deal_damage(t, amount, f)
	BattleAbilities.after_hit(self, f, t, amount)
	f.memory.run = 0


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
	if t.is_unit():
		teams[t.team].defeated += 1
		BattleAbilities.on_defeated(self, t, source)


func stun(t: Fighter, ticks: int) -> void:
	if t.alive and not BattleAbilities.is_fearless(t):
		t.stun = maxi(t.stun, ticks)
		t.target = null


func slow_down(t: Fighter, pct: int, ticks: int, ignore_fearless := false) -> void:
	if not t.alive or (BattleAbilities.is_fearless(t) and not ignore_fearless):
		return
	var current := t.slow_pct if t.slow > 0 else 0
	t.slow = maxi(t.slow, ticks)
	t.slow_pct = maxi(current, pct)


func knock_back(t: Fighter, from_x: int, from_y: int, distance: int) -> void:
	if not t.alive or not t.is_unit():
		return
	var dx := t.x - from_x
	var dy := t.y - from_y
	var d := isqrt(dx * dx + dy * dy)
	if d == 0:
		dy = -1 if t.team == 0 else 1
		d = 1
	t.x = clampi(t.x + dx * distance / d, t.radius, WIDTH - t.radius)
	t.y = clampi(t.y + dy * distance / d, t.radius, HEIGHT - t.radius)


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

## Puts an animal card's animals on the field.
func spawn(team: int, card_id: String, x: int, y: int) -> Array:
	var card := GameData.get_card(card_id)
	var count := int(card.get("count", 1))
	var group := _next_group
	_next_group += 1
	var made := []
	for i in count:
		var offset := formation(i, count)
		var f := _make_unit(team, card, level_of(team, card_id), x + offset.x, y + offset.y)
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
	f.attack_range = melee if tiles <= 1.0 else roundi(tiles * TILE)
	f.speed = int(rules.speed_values.get(stats.speed, 60)) * TILE / (60 * tps)
	f.flying = card.tags.has("flying")
	f.targets = stats.targets
	f.radius = unit_radius(card)
	f.deploy_ticks = deploy_ticks
	f.x = clampi(x, f.radius, WIDTH - f.radius)
	f.y = clampi(y, f.radius, HEIGHT - f.radius)
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


## A separate copy of the fight as it stands, to try out what happens next
## (Draft Duel's Bookie plays fights out ahead to set its odds). Running the
## copy never changes this fight.
func clone() -> BattleSim:
	var copy := BattleSim.new([{}, {}], 0, rules)
	copy.tick = tick
	copy._next_uid = _next_uid
	copy._next_group = _next_group
	copy.rng.seed = rng.seed
	copy.rng.state = rng.state
	copy.zones = zones.duplicate(true)
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
		if (value is Dictionary or value is Array) and prop.name != "card":
			value = value.duplicate(true)
		to.set(prop.name, value)
	return to


## How big an animal is on the field: swarm members are small, the
## toughest animals are big.
static func unit_radius(card: Dictionary) -> int:
	if int(card.get("count", 1)) > 1:
		return 320
	if float(card.stats.hp) >= 1500:
		return 700
	return 450


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

## The middle of the tile under a point. Placing animals snaps to it.
static func tile_center(x: int, y: int) -> Vector2i:
	var col := clampi(x / TILE, 0, WIDTH / TILE - 1)
	var row := clampi(y / TILE, 0, HEIGHT / TILE - 1)
	return Vector2i(col * TILE + TILE / 2, row * TILE + TILE / 2)


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
