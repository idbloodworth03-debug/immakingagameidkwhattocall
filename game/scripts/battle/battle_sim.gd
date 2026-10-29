class_name BattleSim
extends RefCounted
## The battle engine.
##
## It runs in fixed steps ("ticks", 20 per second) and uses whole numbers for
## positions, health and time. That makes it deterministic: the same decks,
## seed and releases always play out exactly the same way. Online play will
## rely on this, because both phones run the battle and only the releases
## travel over the network.
##
## Positions are in thousandths of a tile. The field is 18 tiles wide and 30
## tall with a river across the middle. Team 0 plays from the bottom, team 1
## from the top. Nothing here draws anything; battle_field.gd does that.

const TILE := 1000
const WIDTH := 18 * TILE
const HEIGHT := 30 * TILE
const RIVER_TOP := 14 * TILE
const RIVER_BOTTOM := 16 * TILE
const BRIDGE_XS := [4 * TILE, 14 * TILE]
const BRIDGE_HALF_WIDTH := 1 * TILE
## Tower spots for team 0 (bottom). Team 1's are mirrored at the top.
const TOWER_SPOTS := [
	{"kind": "side", "x": 4000, "y": 25500},
	{"kind": "side", "x": 14000, "y": 25500},
	{"kind": "main", "x": 9000, "y": 28200},
]
## Energy is stored in millionths so refilling stays exact in whole numbers.
const ENERGY_UNIT := 1000000
const DRAW := -1
const RUNNING := -2


## Anything on the field that has health: animals, towers and food bait.
class Fighter:
	extends RefCounted
	var uid := 0
	var team := 0
	var kind := "unit"            # "unit", "tower" or "bait"
	var tower_kind := ""          # "side" or "main" for towers
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
	var targets := "ground"       # "ground", "air_ground" or "buildings"
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


## Per-player battle state.
class Team:
	extends RefCounted
	var energy := 0
	var hand: Array = []
	var queue: Array = []
	var levels: Dictionary = {}
	var deployed := 0             # animals released this battle
	var defeated := 0             # own animals defeated
	var tower_damaged := false
	var towers_destroyed := 0     # enemy towers this team has destroyed


var rules: Dictionary
var tps := 20
var tick := 0
var fighters: Array = []
var teams: Array = []
## Areas that keep working for a while, e.g. the Orangutan's fruit tree.
var zones: Array = []
## Things that happened (releases, hits, deaths, tool blasts) for the screen
## to animate. The screen collects them with take_events().
var events: Array = []
var outcome := RUNNING
var rng := RandomNumberGenerator.new()

var match_ticks := 0
var overtime_ticks := 0
var double_energy_tick := 0
var deploy_ticks := 0
var sight := 0
var melee := 0
var _next_uid := 1
var _next_group := 1


## `decks` is two arrays of 8 card ids, `levels` two dictionaries of
## card id -> level. The seed decides deck order and any random rolls.
func _init(decks: Array, levels: Array, seed_value: int, battle_rules: Dictionary = {}) -> void:
	rules = battle_rules if not battle_rules.is_empty() else GameData.battle_rules
	rng.seed = seed_value
	tps = int(rules.ticks_per_second)
	match_ticks = roundi(float(rules.match_seconds) * tps)
	overtime_ticks = roundi(float(rules.overtime_seconds) * tps)
	double_energy_tick = match_ticks - roundi(float(rules.double_energy_seconds) * tps)
	deploy_ticks = roundi(float(rules.deploy_seconds) * tps)
	sight = roundi(float(rules.sight_range) * TILE)
	melee = roundi(float(rules.melee_range) * TILE)

	for team_index in 2:
		var team := Team.new()
		var deck: Array = decks[team_index].duplicate()
		_shuffle(deck)
		var hand_size := int(rules.hand_size)
		team.hand = deck.slice(0, hand_size)
		team.queue = deck.slice(hand_size)
		team.levels = levels[team_index]
		team.energy = int(rules.energy_start) * ENERGY_UNIT
		teams.append(team)
		for spot in TOWER_SPOTS:
			fighters.append(_make_tower(team_index, spot))


func _notification(what: int) -> void:
	# Animals point at their targets; clear that so finished battles free their memory.
	if what == NOTIFICATION_PREDELETE:
		for f in fighters:
			f.target = null


# --- Info for the screen and the bot ---------------------------------------

func is_over() -> bool:
	return outcome != RUNNING


func energy(team: int) -> float:
	return float(teams[team].energy) / ENERGY_UNIT


func seconds_left() -> float:
	var end := match_ticks if tick < match_ticks else match_ticks + overtime_ticks
	return maxf(0.0, float(end - tick) / tps)


func in_overtime() -> bool:
	return tick >= match_ticks


func is_double_energy() -> bool:
	return tick >= double_energy_tick


func hand(team: int) -> Array:
	return teams[team].hand


func next_card(team: int) -> String:
	return teams[team].queue[0] if not teams[team].queue.is_empty() else ""


func level_of(team: int, card_id: String) -> int:
	return int(teams[team].levels.get(card_id, GameData.start_level(GameData.get_card(card_id).get("rarity", "common"))))


func towers(team: int) -> Array:
	return fighters.filter(func(f): return f.kind == "tower" and f.team == team)


func units(team: int) -> Array:
	return fighters.filter(func(f): return f.alive and f.kind == "unit" and f.team == team)


## "own_side", "river" or "enemy_side", from `team`'s point of view.
func zone_for(team: int, y: int) -> String:
	if y > RIVER_TOP and y < RIVER_BOTTOM:
		return "river"
	var bottom := y >= RIVER_BOTTOM
	return "own_side" if bottom == (team == 0) else "enemy_side"


## Battle state in the form PlacementRules expects.
func placement_state(team: int, zone: String) -> Dictionary:
	var allies := []
	for f in units(team):
		allies.append(f.card)
	var t: Team = teams[team]
	return {
		"energy": energy(team),
		"elapsed": float(tick) / tps,
		"zone": zone,
		"allies": allies,
		"deployed_count": t.deployed,
		"allies_defeated": t.defeated,
		"own_tower_damaged": t.tower_damaged,
	}


## Why the card in `hand_index` can't be played at (x, y). Empty means it can.
func release_problems(team: int, hand_index: int, _x: int, y: int) -> Array:
	if is_over():
		return ["The battle is over"]
	if hand_index < 0 or hand_index >= teams[team].hand.size():
		return ["No card there"]
	var card := GameData.get_card(teams[team].hand[hand_index])
	return PlacementRules.blocking_reasons(card, placement_state(team, zone_for(team, y)))


## Plays a card from the hand. Returns false (and changes nothing) if it
## isn't allowed. The played card goes to the back of the deck.
func release(team: int, hand_index: int, x: int, y: int) -> bool:
	if not release_problems(team, hand_index, x, y).is_empty():
		return false
	x = clampi(x, 0, WIDTH)
	y = clampi(y, 0, HEIGHT)
	var t: Team = teams[team]
	var id: String = t.hand[hand_index]
	var card := GameData.get_card(id)
	t.energy -= int(card.cost) * ENERGY_UNIT
	t.queue.push_back(id)
	t.hand[hand_index] = t.queue.pop_front()
	events.append({"type": "release", "team": team, "card": id, "x": x, "y": y})
	if card.kind == "tool":
		ToolEffects.use(self, team, card, level_of(team, id), x, y)
	else:
		spawn(team, id, x, y)
		t.deployed += 1
	return true


## Requirement problems for a hand card, ignoring energy and where it's aimed.
func requirement_problems(team: int, hand_index: int) -> Array:
	var card := GameData.get_card(teams[team].hand[hand_index])
	var state := placement_state(team, PlacementRules.allowed_zones(card)[0])
	state.energy = 1000.0
	return PlacementRules.blocking_reasons(card, state)


## True when no card in the hand can be played because of its requirements
## (not counting energy). Then a card may be swapped out for free, so a hand
## full of picky cards never gets stuck.
func can_swap(team: int) -> bool:
	for i in teams[team].hand.size():
		if requirement_problems(team, i).is_empty():
			return false
	return true


## Sends a hand card to the back of the deck. Only allowed when can_swap().
func swap(team: int, hand_index: int) -> bool:
	var t: Team = teams[team]
	if is_over() or not can_swap(team) or hand_index < 0 or hand_index >= t.hand.size():
		return false
	t.queue.push_back(t.hand[hand_index])
	t.hand[hand_index] = t.queue.pop_front()
	events.append({"type": "swap", "team": team})
	return true


# --- Running the battle ----------------------------------------------------

## Returns the events since the last call and forgets them.
func take_events() -> Array:
	var taken := events
	events = []
	return taken


## Advances the battle by one tick.
func step() -> void:
	if is_over():
		return
	if events.size() > 2000:
		events.clear()  # nobody is collecting them (tests, simulations)
	tick += 1
	_refill_energy()
	for f in fighters:
		f.prev_x = f.x
		f.prev_y = f.y
	for f in fighters.duplicate():
		if f.alive:
			_update(f)
	_update_zones()
	_separate()
	fighters = fighters.filter(func(f): return f.alive or f.kind == "tower")
	_check_end()


func _refill_energy() -> void:
	var regen_ms := roundi(float(rules.energy_regen_seconds) * 1000.0)
	var per_tick := ENERGY_UNIT * 1000 / (regen_ms * tps)
	if is_double_energy():
		per_tick *= 2
	var cap := int(rules.energy_max) * ENERGY_UNIT
	for team_index in 2:
		var boost := 0
		for f in units(team_index):
			if f.ability_id() == "energy_boost" and f.deploy_ticks <= 0:
				boost += int(f.param("pct"))
		var t: Team = teams[team_index]
		t.energy = mini(cap, t.energy + per_tick * (100 + boost) / 100)


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
	if f.target != null and in_range(f, f.target):
		if f.cooldown <= 0:
			_attack(f, f.target)
			f.cooldown = f.hit_ticks * 100
	elif f.is_unit():
		var goal: Fighter = f.target if f.target != null else nearest_enemy_tower(f)
		if goal != null:
			_move_toward(f, _waypoint(f, Vector2i(goal.x, goal.y)), current_speed(f))


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


func _check_end() -> void:
	var main_alive := [false, false]
	for f in fighters:
		if f.kind == "tower" and f.tower_kind == "main" and f.alive:
			main_alive[f.team] = true
	if not main_alive[0] and not main_alive[1]:
		outcome = DRAW
	elif not main_alive[0]:
		outcome = 1
	elif not main_alive[1]:
		outcome = 0
	if is_over():
		return

	var crowns_0: int = teams[0].towers_destroyed
	var crowns_1: int = teams[1].towers_destroyed
	if tick >= match_ticks and crowns_0 != crowns_1:
		# End of regular time, or a tower falls in sudden-death overtime.
		outcome = 0 if crowns_0 > crowns_1 else 1
	elif tick >= match_ticks + overtime_ticks:
		# Still tied after overtime: the side whose weakest tower is healthier wins.
		var weakest := [_weakest_tower_hp(0), _weakest_tower_hp(1)]
		if weakest[0] == weakest[1]:
			outcome = DRAW
		else:
			outcome = 0 if weakest[0] > weakest[1] else 1


func _weakest_tower_hp(team: int) -> int:
	var lowest := 1 << 30
	for f in towers(team):
		if f.alive:
			lowest = mini(lowest, f.hp)
	return lowest


# --- Targeting and movement ------------------------------------------------

func can_target(f: Fighter, t: Fighter) -> bool:
	if t == null or not t.alive or t.team == f.team or t.uid == f.uid:
		return false
	if t.kind == "bait":
		return f.is_unit() and not f.is_flying()
	if t.kind == "tower":
		return true
	if f.targets == "buildings":
		return false
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


func _find_target(f: Fighter) -> Fighter:
	if f.kind == "tower":
		var best: Fighter = null
		var best_dist := 1 << 40
		for t in fighters:
			if t.is_unit() and can_target(f, t):
				var d := edge_distance(f, t)
				if d <= f.attack_range and d < best_dist:
					best = t
					best_dist = d
		return best

	# Food bait pulls in nearby enemy ground animals first.
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
		if d <= sight and d < nearest_dist:
			nearest = t
			nearest_dist = d
	return nearest if nearest != null else nearest_enemy_tower(f)


func nearest_enemy_tower(f: Fighter) -> Fighter:
	var best: Fighter = null
	var best_dist := 1 << 40
	for t in fighters:
		if t.kind == "tower" and t.alive and t.team != f.team:
			var d := dist(f, t)
			if d < best_dist:
				best = t
				best_dist = d
	return best


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


## Where a ground animal should walk next to reach `goal`: straight there if
## it's on the same bank, otherwise to the nearest bridge and across.
## Flyers, swimmers, burrowers and leapers go straight.
func _waypoint(f: Fighter, goal: Vector2i) -> Vector2i:
	if f.is_flying() or f.has_tag("aquatic") or f.ability_id() == "jump_river":
		return goal
	var my_bank := bank(f.y)
	var goal_bank := bank(goal.y)
	if goal_bank == 0 and absi(goal.x - nearest_bridge(goal.x)) > BRIDGE_HALF_WIDTH:
		# The goal is in the water: walk to the nearest shore point.
		goal = Vector2i(goal.x, RIVER_BOTTOM if f.y > goal.y else RIVER_TOP)
		goal_bank = my_bank
	if my_bank != 0 and goal_bank == my_bank:
		return goal
	var bridge := nearest_bridge(f.x)
	var lane := BRIDGE_HALF_WIDTH - 250
	var heading_down := goal.y > f.y
	if my_bank == 0 or absi(f.x - bridge) <= lane:
		var far_bank := RIVER_BOTTOM + 400 if heading_down else RIVER_TOP - 400
		if goal_bank == 0:
			return goal
		return Vector2i(clampi(f.x, bridge - lane, bridge + lane), far_bank)
	var near_bank := RIVER_TOP - 400 if heading_down else RIVER_BOTTOM + 400
	return Vector2i(bridge, near_bank)


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


## Burrowing animals travel underground straight to the nearest enemy tower
## and pop up as soon as anything they can attack is close.
func _move_burrowed(f: Fighter) -> void:
	for t in fighters:
		if t.alive and t.team != f.team and (t.kind == "tower" or (t.is_unit() and not t.is_flying())) and edge_distance(f, t) <= TILE:
			f.memory.burrowing = false
			events.append({"type": "emerge", "uid": f.uid, "x": f.x, "y": f.y})
			return
	var goal := nearest_enemy_tower(f)
	if goal != null:
		_move_toward(f, Vector2i(goal.x, goal.y), current_speed(f))


## Pushes overlapping animals apart and keeps walkers out of towers and water.
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
		if not f.is_flying():
			for t in fighters:
				if t.kind == "tower" and t.alive:
					_push_out(f, t)
		f.x = clampi(f.x, f.radius, WIDTH - f.radius)
		f.y = clampi(f.y, f.radius, HEIGHT - f.radius)
		_keep_out_of_water(f)


func _push_out(f: Fighter, solid: Fighter) -> void:
	var min_d := f.radius + solid.radius
	var dx := f.x - solid.x
	var dy := f.y - solid.y
	if absi(dx) >= min_d or absi(dy) >= min_d:
		return
	var d := isqrt(dx * dx + dy * dy)
	if d >= min_d:
		return
	if d == 0:
		dx = 1
		d = 1
	f.x = solid.x + dx * min_d / d
	f.y = solid.y + dy * min_d / d


func _keep_out_of_water(f: Fighter) -> void:
	if f.is_flying() or f.has_tag("aquatic") or f.ability_id() == "jump_river":
		return
	if bank(f.y) == 0 and absi(f.x - nearest_bridge(f.x)) > BRIDGE_HALF_WIDTH:
		f.y = RIVER_TOP if f.y < (RIVER_TOP + RIVER_BOTTOM) / 2 else RIVER_BOTTOM


# --- Fighting --------------------------------------------------------------

func _attack(f: Fighter, t: Fighter) -> void:
	var amount := f.damage
	if f.rage > 0:
		amount = amount * (100 + f.rage_damage_pct) / 100
	amount = BattleAbilities.outgoing_damage(self, f, t, amount)
	f.stealthed = false
	f.memory.attacked = true
	f.memory.last_combat = tick
	events.append({"type": "hit", "from": f.uid, "to": t.uid, "x": t.x, "y": t.y, "ranged": f.attack_range > 1500})
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
	if t.kind == "tower":
		teams[t.team].tower_damaged = true
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
	if t.kind == "tower":
		teams[1 - t.team].towers_destroyed += 1
		if t.tower_kind == "main":
			# The main tower takes the side towers down with it.
			for other in towers(t.team):
				if other.alive:
					other.alive = false
					other.hp = 0
					teams[1 - t.team].towers_destroyed += 1
	elif t.is_unit():
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
	_keep_out_of_water(t)


## Enemies of `team` within `radius` of a point (edges count).
func enemies_near(team: int, px: int, py: int, radius: int, include_towers := false) -> Array:
	var found := []
	for f in fighters:
		if f.alive and f.team != team and (f.is_unit() or (include_towers and f.kind == "tower")):
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

## Puts an animal card's animals on the field (no energy or hand checks).
func spawn(team: int, card_id: String, x: int, y: int) -> Array:
	var card := GameData.get_card(card_id)
	var count := int(card.get("count", 1))
	var group := _next_group
	_next_group += 1
	var made := []
	for i in count:
		var offset := _formation(i, count)
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
	if int(card.count) > 1:
		f.radius = 320
	elif float(stats.hp) >= 1500:
		f.radius = 700
	else:
		f.radius = 450
	f.deploy_ticks = deploy_ticks
	f.x = clampi(x, f.radius, WIDTH - f.radius)
	f.y = clampi(y, f.radius, HEIGHT - f.radius)
	f.prev_x = f.x
	f.prev_y = f.y
	return f


func _make_tower(team: int, spot: Dictionary) -> Fighter:
	var conf: Dictionary = rules.towers[spot.kind]
	var f := Fighter.new()
	f.uid = _next_uid
	_next_uid += 1
	f.team = team
	f.kind = "tower"
	f.tower_kind = spot.kind
	f.x = spot.x
	f.y = spot.y if team == 0 else HEIGHT - int(spot.y)
	f.prev_x = f.x
	f.prev_y = f.y
	f.max_hp = int(conf.hp)
	f.hp = f.max_hp
	f.damage = int(conf.damage)
	f.hit_ticks = maxi(1, roundi(float(conf.hit_speed) * tps))
	f.attack_range = roundi(float(conf.range) * TILE)
	f.radius = roundi(float(conf.size) * TILE)
	f.targets = "air_ground"
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


func _formation(index: int, count: int) -> Vector2i:
	match count:
		2:
			return [Vector2i(-400, 0), Vector2i(400, 0)][index]
		3:
			return [Vector2i(0, -400), Vector2i(-420, 300), Vector2i(420, 300)][index]
		4:
			return [Vector2i(-380, -380), Vector2i(380, -380), Vector2i(-380, 380), Vector2i(380, 380)][index]
	return Vector2i.ZERO


func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var held: Variant = list[i]
		list[i] = list[j]
		list[j] = held


# --- Geometry --------------------------------------------------------------

## 1 = bottom bank, -1 = top bank, 0 = in the river band.
static func bank(y: int) -> int:
	if y >= RIVER_BOTTOM:
		return 1
	if y <= RIVER_TOP:
		return -1
	return 0


static func nearest_bridge(x: int) -> int:
	return BRIDGE_XS[0] if absi(x - BRIDGE_XS[0]) <= absi(x - BRIDGE_XS[1]) else BRIDGE_XS[1]


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


## A number that changes if anything about the battle differs. Two copies of
## the same battle must give the same checksum (online play depends on it).
func checksum() -> int:
	var total := tick * 31 + outcome
	for f in fighters:
		total = (total * 131 + f.uid * 7 + f.x * 3 + f.y * 5 + f.hp) % 2147483647
	for t in teams:
		total = (total * 17 + t.energy) % 2147483647
	return total
