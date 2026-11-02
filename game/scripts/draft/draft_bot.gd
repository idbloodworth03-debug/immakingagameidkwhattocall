class_name DraftBot
extends RefCounted
## The computer opponent in Draft Duel. It drafts, places its herd, uses its
## tools in the fight and bets at halftime, all through DraftMatch's public
## calls, so it follows the same rules as a person.
##
## `difficulty` (0 = first arena, 1 = top arena) sets how well it drafts
## (less random), how quickly and how well it uses tools, and how it bets.

const T := BattleSim.TILE

var duel: DraftMatch
var team := 1
var rng := RandomNumberGenerator.new()
var difficulty := 0.5
var _tool_wait := 0


func _init(draft_match: DraftMatch, bot_team: int, seed_value: int, bot_difficulty := 0.5) -> void:
	duel = draft_match
	team = bot_team
	rng.seed = seed_value
	difficulty = clampf(bot_difficulty, 0.0, 1.0)
	_tool_wait = _reaction()


# --- Draft -----------------------------------------------------------------

## Makes one draft decision on the bot's turn: buys the card it wants most,
## or passes.
func pick() -> void:
	if duel.phase != "draft" or duel.turn != team:
		return
	var best := -1
	var best_score := 1.5
	for i in duel.market.size():
		if duel.can_buy(team, i) != "":
			continue
		var score := _want(duel.market[i])
		if score > best_score:
			best = i
			best_score = score
	if best >= 0:
		duel.buy(team, best)
	else:
		duel.pass_turn(team)


## How much it wants a market card. Pricier animals are stronger; it wants
## one tool, sometimes gambles on the Mystery Crate, and once its herd is
## decent it keeps some Acorns back to bet with.
func _want(item: Dictionary) -> float:
	var cost := int(item.cost)
	var left: int = duel.acorns[team] - cost
	var herd_size: int = duel.herds[team].size()
	var noise := rng.randf() * lerpf(3.0, 0.8, difficulty)
	var keep := 0 if herd_size < 3 else int(duel.rules.ante) + (2 if herd_size < 5 else 4)
	if left < keep:
		return 0.0
	if GameData.is_tool(item.id):
		return (3.0 + 2.0 * difficulty if duel.tools[team].is_empty() else 0.5) + noise
	if item.mystery:
		return 3.5 + noise
	# Early on, numbers matter more than size: two cheap animals can beat one big one.
	var size_need := 1.5 if herd_size < 2 else 0.0
	return float(cost) + size_need + noise


# --- Placing ---------------------------------------------------------------

## Arranges its herd: the tough animals in front, ranged ones at the back, the
## rest in between, leaning toward the lane where the enemy is strongest.
func place() -> void:
	if duel.phase != "place":
		return
	var herd: Array = duel.herds[team]
	var front := []
	var middle := []
	var back := []
	for i in herd.size():
		var card := GameData.get_card(herd[i].id)
		if float(card.stats.range) > 1.0:
			back.append(i)
		elif float(card.stats.hp) >= 1500.0 or card.stats.targets == "buildings":
			front.append(i)
		else:
			middle.append(i)
	var strong_left := _enemy_strength(true) >= _enemy_strength(false)
	var lanes := [4.5, 13.5, 9.0, 6.5, 11.5, 3.0, 15.0] if strong_left else [13.5, 4.5, 9.0, 11.5, 6.5, 15.0, 3.0]
	var rows := [[front, 11.0], [middle, 9.0], [back, 6.5]]
	var slot := 0
	for row in rows:
		for i in row[0]:
			var x := roundi(float(lanes[slot % lanes.size()]) * T) + rng.randi_range(-300, 300)
			var y := roundi(float(row[1]) * T) + rng.randi_range(-300, 300)
			if team == 0:
				y = BattleSim.HEIGHT - y
			if not duel.move(team, i, x, y):
				var spot := duel.default_spot(team, herd[i].id)
				duel.move(team, i, spot.x, spot.y)
			slot += 1
	duel.set_ready(team)


func _enemy_strength(left: bool) -> float:
	var total := 0.0
	for entry in duel.herds[1 - team]:
		if (int(entry.x) < BattleSim.WIDTH / 2) == left:
			total += float(GameData.get_card(entry.id).cost)
	return total


# --- Backing its herd ------------------------------------------------------

## Bets on its own herd when the Bookie's price is better than it thinks the
## odds are. `odds` is the Bookie's chance that the bot wins; its own tools
## make it more hopeful than the Bookie, the other side's less.
func back_herd(odds: float) -> void:
	if duel.phase != "wager" or duel.wagers[team] >= 0:
		return
	var hope := clampf(odds + 0.1 * duel.tools[team].size() - 0.06 * duel.tools[1 - team].size(), 0.0, 1.0)
	var gain := hope * float(duel.payout(team)) / 100.0 - 1.0
	var most := duel.max_wager(team)
	var amount := 0
	if gain > 0.1 and most > 0:
		amount = clampi(roundi(gain * float(most)), 1, most)
	elif most > 0 and rng.randf() < 0.15 * (1.0 - difficulty):
		amount = 1  # a hunch
	duel.wager(team, amount)


# --- Fighting --------------------------------------------------------------

## Call every fight tick. Now and then it looks for a good moment to rally
## or use a tool.
func update() -> void:
	if duel.phase != "fight":
		return
	_tool_wait -= 1
	if _tool_wait > 0:
		return
	_tool_wait = _reaction()
	if duel.rally_ready[team]:
		var spot := _rally_spot()
		if not spot.is_empty():
			duel.rally(team, spot.x, spot.y)
			return
	for i in duel.tools[team].size():
		var aim := _aim(duel.tools[team][i])
		if not aim.is_empty():
			duel.use_tool(team, i, aim.x, aim.y)
			return


## Where its animals are fighting hardest, once at least two are at it.
func _rally_spot() -> Dictionary:
	var fighting := duel.sim.units(team).filter(func(f): return f.target != null and f.target.is_unit() and duel.sim.in_range(f, f.target))
	var radius := roundi(float(duel.rules.rally.radius) * T)
	var best := _best_cluster(fighting, radius, func(_f): return 1.0)
	return best if float(best.get("value", 0)) >= 2.0 else {}


func _reaction() -> int:
	return roundi(lerpf(1.6, 0.4, difficulty) * 20) + rng.randi_range(0, 10)


## Where to use a tool, or {} if there's no good target yet.
func _aim(tool_id: String) -> Dictionary:
	var card := GameData.get_card(tool_id)
	var radius := roundi(float(card.stats.get("radius", 1.0)) * T)
	var enemies := duel.sim.units(1 - team)
	match card.ability.id:
		"medkit":
			var allies := duel.sim.units(team)
			var best := _best_cluster(allies, radius, func(f): return f.max_hp - f.hp)
			return best if float(best.get("value", 0)) >= 600.0 else {}
		"tranq_dart":
			var biggest: BattleSim.Fighter = null
			for f in enemies:
				if f.target != null and (biggest == null or f.max_hp > biggest.max_hp):
					biggest = f
			return {"x": biggest.x, "y": biggest.y} if biggest != null and biggest.max_hp >= 1000 else {}
		"bait":
			var near := enemies.filter(func(f): return _on_own_side(f.y))
			var lure := _best_cluster(near, radius, func(f): return float(f.card.cost) / int(f.card.get("count", 1)))
			if float(lure.get("value", 0)) < 4.0:
				return {}
			# Drop it between them and our dens.
			var toward_dens := -2 * T if team == 1 else 2 * T
			return {"x": lure.x, "y": lure.y + toward_dens}
		_:
			var hit := _best_cluster(enemies, radius, func(f): return float(f.card.cost) / int(f.card.get("count", 1)))
			return hit if float(hit.get("value", 0)) >= lerpf(5.0, 3.5, difficulty) else {}


func _on_own_side(y: int) -> bool:
	return y < BattleSim.RIVER_TOP if team == 1 else y > BattleSim.RIVER_BOTTOM


## The fighter whose surroundings (within `radius`) add up to the most
## `value_of`: {"x", "y", "value"}, or {} if there are none.
func _best_cluster(candidates: Array, radius: int, value_of: Callable) -> Dictionary:
	var best := {}
	for center in candidates:
		var value := 0.0
		for other in candidates:
			if BattleSim.dist(center, other) <= radius:
				value += float(value_of.call(other))
		if best.is_empty() or value > float(best.value):
			best = {"x": center.x, "y": center.y, "value": value}
	return best


# --- Halftime betting ------------------------------------------------------

## Makes its halftime move when it's the bot's turn. `odds` is the Bookie's
## chance that the bot wins the round. It knows its own tools, so it's
## braver with tools in hand, and it sometimes bluffs.
func bet(odds: float) -> void:
	var h := duel.halftime
	if h.is_empty() or int(h.turn) != team:
		return
	# Its own tools give it hope; the other side's (it can count them) take some away.
	var hope := clampf(odds + 0.12 * duel.tools[team].size() - 0.08 * duel.tools[1 - team].size(), 0.0, 1.0)
	if int(h.raise) > 0:
		# Worth calling if the chance of winning beats the price of staying in.
		var price := float(h.raise) / float(duel.pot + int(h.raise))
		if hope < 0.3 and hope < price + 0.1:
			duel.fold(team)
		else:
			duel.call_raise(team)
		return
	var most := duel.max_raise(team)
	var bluff: bool = not duel.tools[team].is_empty() and hope > 0.3 and rng.randf() < 0.1 + 0.2 * difficulty
	# Far ahead, it would rather let its herd hit the dens than offer a way
	# out; a little ahead, it raises to win Acorns.
	var value_raise := hope > 0.6 and hope < lerpf(1.01, 0.9, difficulty)
	if most > 0 and (value_raise or bluff):
		var amount := clampi(roundi(lerpf(1.0, float(most), clampf((hope - 0.5) * 2.5, 0.0, 1.0))), 1, most)
		duel.raise_pot(team, amount)
	else:
		duel.check(team)
