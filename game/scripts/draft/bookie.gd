class_name Bookie
extends RefCounted
## The raccoon who runs Draft Duel's betting table. To set the odds of a
## round, the Bookie plays the rest of the fight out ahead on copies of the
## battle, a few times over, each with its own dice for the animals' moods
## and the luck of the hits (so it can't peek at the real fight's) and every
## animal nudged a little,
## and counts how often each side wins. It can't see the tools in anyone's
## hand, so its odds leave them out: a well-timed tool is how you beat the
## Bookie.
##
## The Bookie works a little at a time (advance), so the screen keeps moving
## while it thinks.

## One play-through: {"sim": BattleSim, "tick": fight tick, "wiped": [int, int]}.
var _tries: Array = []
var _current := 0
var _wins := [0.0, 0.0]
var _fight_ticks := 0
var _dens_at_start: Array = []


## Starts working out the odds of the fight in `match_` from where it is now.
static func study(match_: DraftMatch, seed_value: int) -> Bookie:
	var bookie := Bookie.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var jitter := roundi(float(match_.rules.get("bookie_jitter", 0.4)) * BattleSim.TILE)
	# Before the fight (while players place their bets) it starts from the
	# whistle; at halftime, from where the fight stands.
	var starting := match_.phase == "wager"
	var tick := 0 if starting else match_.fight_tick
	var wiped: Array = match_.wiped_at.duplicate()
	bookie._dens_at_start = match_.den_before.duplicate()
	if starting:
		wiped = [-1, -1]
		for team in 2:
			bookie._dens_at_start[team] = DraftMatch.den_health(match_.sim, team)
			if match_.sim.units(team).is_empty():
				wiped[team] = 0
	# It only looks so far ahead; by then the fight is usually settled.
	var lookahead := roundi(float(match_.rules.get("bookie_lookahead_seconds", 25)) * match_.sim.tps)
	bookie._fight_ticks = mini(match_.fight_ticks, tick + lookahead)
	for i in int(match_.rules.get("bookie_trials", 4)):
		var copy := match_.sim.clone()
		copy.rng.seed = rng.randi()
		if starting:
			DraftMatch.roll_moods(copy, rng, int(match_.rules.get("mood_pct", 0)))
		if i > 0:
			# The first try starts from exactly where things stand; the others
			# shuffle everyone a little too.
			for f in copy.fighters:
				if f.is_unit():
					f.x = clampi(f.x + rng.randi_range(-jitter, jitter), f.radius, BattleSim.WIDTH - f.radius)
					f.y = clampi(f.y + rng.randi_range(-jitter, jitter), f.radius, BattleSim.HEIGHT - f.radius)
					f.prev_x = f.x
					f.prev_y = f.y
		bookie._tries.append({"sim": copy, "tick": tick, "wiped": wiped.duplicate()})
	return bookie


## Works for up to `budget_usec` microseconds. Returns true once the odds are ready.
func advance(budget_usec := 1000000000) -> bool:
	var start := Time.get_ticks_usec()
	while _current < _tries.size():
		var t: Dictionary = _tries[_current]
		var battle: BattleSim = t.sim
		# Stop as soon as the round is decided: a herd wiped out decides it.
		while not battle.is_over() and int(t.tick) < _fight_ticks and t.wiped[0] < 0 and t.wiped[1] < 0:
			battle.step()
			t.tick = int(t.tick) + 1
			for team in 2:
				if t.wiped[team] < 0 and battle.units(team).is_empty():
					t.wiped[team] = int(t.tick)
			if int(t.tick) % 5 == 0 and Time.get_ticks_usec() - start > budget_usec:
				return false
		var winner := DraftMatch.judge(battle, t.wiped, _dens_at_start)
		if winner == DraftMatch.NO_WINNER:
			_wins[0] += 0.5
			_wins[1] += 0.5
		else:
			_wins[winner] += 1.0
		t.sim = null
		_current += 1
	return true


func is_ready() -> bool:
	return _current >= _tries.size()


## Settles on the tries finished so far (a slow phone can't wait for them
## all). False if not even one is finished yet.
func settle() -> bool:
	if _current == 0:
		return false
	_tries.resize(_current)
	return true


## How likely `team` is to win the round, from 0 to 1. Only meaningful once ready.
func chance(team := 0) -> float:
	return _wins[team] / maxf(1.0, float(_current))
