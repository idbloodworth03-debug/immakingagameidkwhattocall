class_name BattleBot
extends RefCounted
## A simple computer opponent. It plays through the same release() call as a
## person, so it follows every rule (energy, requirements, where cards can go).
##
## Each "think" it:
##   1. uses a Ranger tool if there's a good target (a group of enemies, or
##      hurt allies for the Medkit),
##   2. defends when enemy animals come over to its side,
##   3. otherwise builds energy and pushes a lane.
## It also waits a little between decisions so it feels human and beatable.
##
## `difficulty` (0 = first arena, 1 = top arena) sets how quickly it reacts,
## how reliably it defends, how readily it uses tools and how patiently it
## saves up energy before attacking.

var sim: BattleSim
var team := 1
var rng := RandomNumberGenerator.new()
var difficulty := 0.5
var _wait := 0
# Tuned from `difficulty` in _init:
var _think_min := 0
var _think_max := 0
var _defend_chance := 100
var _cluster_needed := 3
var _push_energy := 8.5


func _init(battle: BattleSim, bot_team: int, seed_value: int, bot_difficulty := 0.5) -> void:
	sim = battle
	team = bot_team
	rng.seed = seed_value
	difficulty = clampf(bot_difficulty, 0.0, 1.0)
	_think_min = roundi(lerpf(0.9, 0.25, difficulty) * sim.tps)
	_think_max = roundi(lerpf(1.7, 0.6, difficulty) * sim.tps)
	_defend_chance = roundi(lerpf(60.0, 100.0, difficulty))
	_cluster_needed = 4 if difficulty < 0.34 else (3 if difficulty < 0.67 else 2)
	_push_energy = lerpf(9.8, 7.5, difficulty)
	_wait = rng.randi_range(2 * sim.tps, 4 * sim.tps)


## A deck for the bot from cards unlocked up to `arena_index`, at levels close
## to the player's (`level_offset` levels above each rarity's start).
static func make_deck(arena_index: int, level_offset: int, rng_source: RandomNumberGenerator) -> Dictionary:
	var animals := []
	var tools := []
	for id in GameData.card_order:
		var card: Dictionary = GameData.cards[id]
		if int(card.unlock_arena_index) > arena_index:
			continue
		if card.kind == "tool":
			tools.append(id)
		else:
			animals.append(id)
	_shuffle(animals, rng_source)
	_shuffle(tools, rng_source)
	var deck_size := int(GameData.progression.deck_size)
	var deck: Array = tools.slice(0, mini(2, tools.size()))
	for id in animals:
		if deck.size() >= deck_size:
			break
		deck.append(id)
	var levels := {}
	var max_level := int(GameData.progression.card_max_level)
	for id in deck:
		levels[id] = mini(max_level, GameData.start_level(GameData.cards[id].rarity) + level_offset)
	return {"deck": deck, "levels": levels}


static func _shuffle(list: Array, rng_source: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng_source.randi_range(0, i)
		var swap: Variant = list[i]
		list[i] = list[j]
		list[j] = swap


## Call once per tick, before sim.step().
func update() -> void:
	if sim.is_over():
		return
	_wait -= 1
	if _wait > 0:
		return
	_wait = rng.randi_range(_think_min, _think_max)
	if _use_tool():
		return
	var threats := _threats()
	if not threats.is_empty() and rng.randi_range(1, 100) <= _defend_chance and _defend(threats):
		return
	var energy := sim.energy(team)
	if energy >= _push_energy or (energy >= _push_energy - 2.5 and rng.randi_range(1, 100) <= 25):
		if not _push() and energy >= 9.5:
			_unstick()


# --- Positions from the bot's side of the field ----------------------------

## A y position `depth` tiles back from the river on the bot's own side.
func own_y(depth: float) -> int:
	var offset := roundi(depth * BattleSim.TILE)
	return BattleSim.RIVER_BOTTOM + offset if team == 0 else BattleSim.RIVER_TOP - offset


func _on_own_side(y: int) -> bool:
	return y >= BattleSim.RIVER_BOTTOM if team == 0 else y <= BattleSim.RIVER_TOP


## Enemy animals on our side, or at the river heading our way.
func _threats() -> Array:
	var found := []
	for f in sim.units(1 - team):
		var near_river := absi(f.y - (BattleSim.RIVER_TOP + BattleSim.RIVER_BOTTOM) / 2) <= 3 * BattleSim.TILE
		if _on_own_side(f.y) or near_river:
			found.append(f)
	# Most dangerous first: the one closest to our towers.
	found.sort_custom(func(a, b): return _distance_to_our_towers(a) < _distance_to_our_towers(b))
	return found


func _distance_to_our_towers(f: BattleSim.Fighter) -> int:
	var best := 1 << 40
	for t in sim.towers(team):
		if t.alive:
			best = mini(best, BattleSim.dist(f, t))
	return best


# --- Decisions -------------------------------------------------------------

func _try_release(index: int, x: int, y: int) -> bool:
	return sim.release(team, index, x, y)


func _use_tool() -> bool:
	var hand := sim.hand(team)
	for i in hand.size():
		var card := GameData.get_card(hand[i])
		if card.kind != "tool" or sim.energy(team) < float(card.cost):
			continue
		var radius := roundi(float(card.stats.get("radius", 2)) * BattleSim.TILE)
		match card.ability.id:
			"medkit":
				var spot := _best_cluster(sim.units(team), radius, func(f): return f.max_hp - f.hp)
				if spot.value >= 400 and _try_release(i, spot.x, spot.y):
					return true
			"bait":
				var threats := _threats().filter(func(f): return not f.is_flying())
				if threats.size() >= 1 and _on_own_side(threats[0].y):
					var target: BattleSim.Fighter = threats[0]
					if _try_release(i, target.x, own_y(4)):
						return true
			"tranq_dart":
				var biggest: BattleSim.Fighter = null
				for f in sim.units(1 - team):
					if f.deploy_ticks <= 0 and (biggest == null or f.hp > biggest.hp):
						biggest = f
				if biggest != null and biggest.hp >= 1200 and _distance_to_our_towers(biggest) < 9 * BattleSim.TILE:
					if _try_release(i, biggest.x, biggest.y):
						return true
			_:
				# Damage tools (Net, Air Horn, Flare): aim at the biggest group.
				var spot := _best_cluster(sim.units(1 - team), radius, func(_f): return 1)
				if spot.value >= _cluster_needed and _try_release(i, spot.x, spot.y):
					return true
	return false


## Finds the spot where `value_of` summed over animals within `radius` is
## highest. Returns {x, y, value}.
func _best_cluster(candidates: Array, radius: int, value_of: Callable) -> Dictionary:
	var best := {"x": 0, "y": 0, "value": 0}
	for center in candidates:
		var total := 0
		for f in candidates:
			if BattleSim.dist(center, f) <= radius:
				total += int(value_of.call(f))
		if total > best.value:
			best = {"x": center.x, "y": center.y, "value": total}
	return best


func _defend(threats: Array) -> bool:
	var threat: BattleSim.Fighter = threats[0]
	var hand := sim.hand(team)
	var order := range(hand.size())
	order.sort_custom(func(a, b): return GameData.get_card(hand[a]).cost < GameData.get_card(hand[b]).cost)
	for i in order:
		var card := GameData.get_card(hand[i])
		if card.kind == "tool":
			continue
		var spots := [
			Vector2i(threat.x, own_y(3.5)),
			Vector2i(threat.x + (1500 if threat.x < BattleSim.WIDTH / 2 else -1500), own_y(5.0)),
			Vector2i(threat.x, (BattleSim.RIVER_TOP + BattleSim.RIVER_BOTTOM) / 2),
		]
		if _on_own_side(threat.y):
			var toward_home := 2000 if team == 0 else -2000
			spots.push_front(Vector2i(threat.x, clampi(threat.y + toward_home, 0, BattleSim.HEIGHT)))
		for spot in spots:
			if sim.release_problems(team, i, spot.x, spot.y).is_empty():
				return _try_release(i, spot.x, spot.y)
	return false


## Returns true if it released something.
func _push() -> bool:
	var hand := sim.hand(team)
	var order := range(hand.size())
	# Tough animals lead the push.
	order.sort_custom(func(a, b): return GameData.get_card(hand[a]).stats.get("hp", 0) > GameData.get_card(hand[b]).stats.get("hp", 0))
	var lane: int = BattleSim.BRIDGE_XS[_weaker_lane()]
	for i in order:
		var card := GameData.get_card(hand[i])
		if card.kind == "tool":
			continue
		var spots := [Vector2i(lane, own_y(1.0)), Vector2i(lane, (BattleSim.RIVER_TOP + BattleSim.RIVER_BOTTOM) / 2), Vector2i(BattleSim.WIDTH / 2, own_y(9.0))]
		# Smarter bots drop straight into a lane whose den they've already destroyed.
		if difficulty >= 0.3:
			for pocket in sim.pocket_rects(team):
				var center: Vector2i = pocket.get_center()
				# As deep as allowed: the far edge of the pocket, toward the main den.
				var deep_y: int = pocket.position.y + BattleSim.TILE if team == 0 else pocket.end.y - BattleSim.TILE
				spots.push_front(Vector2i(center.x, deep_y))
		for spot in spots:
			if sim.release_problems(team, i, spot.x, spot.y).is_empty():
				return _try_release(i, spot.x, spot.y)
	return false


## Nothing in the hand fits the plan: swap a card if the hand is stuck,
## otherwise use a tool somewhere sensible just to keep cards moving.
func _unstick() -> void:
	if sim.can_swap(team):
		sim.swap(team, rng.randi_range(0, sim.hand(team).size() - 1))
		return
	var hand := sim.hand(team)
	for i in hand.size():
		var card := GameData.get_card(hand[i])
		if card.kind != "tool":
			continue
		var spots := []
		for f in sim.units(1 - team):
			spots.append(Vector2i(f.x, f.y))
		for f in sim.units(team):
			spots.append(Vector2i(f.x, f.y))
		spots.append(Vector2i(BattleSim.BRIDGE_XS[_weaker_lane()], own_y(3.0)))
		for spot in spots:
			if sim.release_problems(team, i, spot.x, spot.y).is_empty():
				_try_release(i, spot.x, spot.y)
				return


## 0 for the left lane, 1 for the right: whichever enemy side tower is
## weaker, or a coin flip if they're even.
func _weaker_lane() -> int:
	var side_towers: Array = sim.towers(1 - team).filter(func(t): return t.tower_kind == "side")
	side_towers.sort_custom(func(a, b): return a.x < b.x)
	var left_hp: int = side_towers[0].hp if side_towers[0].alive else 0
	var right_hp: int = side_towers[1].hp if side_towers[1].alive else 0
	if left_hp == right_hp:
		return rng.randi_range(0, 1)
	return 0 if left_hp < right_hp else 1
