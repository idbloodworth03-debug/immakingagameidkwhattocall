extends TestCase
## How fast a fight plays (feel.json "choreography" fight_speed; scripts/
## draft/draft_screen.gd): the screen steps the fight that many times as
## fast as the rules run it and the field plays at the same pace. Only the
## pace changes: the fight itself is the same at any speed.

var _made: Array = []
var _speed_was: Variant = null


func cleanup() -> void:
	if _speed_was != null:
		GameData.feel.choreography.fight_speed = _speed_was
	for thing in _made:
		if is_instance_valid(thing):
			thing.free()
	_made.clear()


## A fight on the fight screen, without the rest of the screen: these two
## armies (a squad of each animal), the fight on and past its opening beat.
func _fight(seed_value: int, herds: Array) -> Control:
	var screen: Control = load("res://scripts/draft/draft_screen.gd").new()
	var duel := DraftMatch.new(seed_value)
	for team in 2:
		var herd := []
		for id in herds[team]:
			herd.append({"id": id, "stars": 1, "squads": 1})
		duel.herds[team] = herd
		duel.picks_left[team] = 0
		duel.picks_made[team] = []
	duel.set_ready(0)
	duel.set_ready(1)
	duel.take_events()
	screen.duel = duel
	screen.bot = DraftBot.new(duel, 1, seed_value + 1, 0.5)
	var field := BattleField.new()
	field.size = Vector2(720, 1080)
	field._ready()
	field.sim = duel.sim
	screen._field = field
	screen._reset_speed()
	_made.append_array([field, screen])
	return screen


## A frame of the fight screen, as the game runs one.
func _frame(screen: Control, delta: float) -> void:
	screen._run_fight(delta)
	screen._field._process(delta)


func test_a_fight_plays_at_the_fight_speed() -> void:
	var speed := BattleField.fight_speed()
	check_eq(speed, Feel.num("choreography", "fight_speed", 1.0), "the fights' speed is feel.json's")
	check(speed >= 1.0 and speed <= 2.0, "never slower than the rules run it, nor too fast to follow (x%.2f)" % speed)
	var screen := _fight(11, [["brown_bear", "wolf_pack"], ["wild_boar", "black_rhino"]])
	var duel: DraftMatch = screen.duel
	check_eq(duel.phase, "fight", "the fight is on")
	check_eq(screen._field.playback, 1.0, "its opening beat plays at its own pace")
	# A second of frames (a big hit holds the whole fight still a moment:
	# those frames aside).
	var played := 0.0
	for i in 60:
		if not screen._field.is_frozen():
			played += 1.0 / 60.0
		_frame(screen, 1.0 / 60.0)
	check(played > 0.5, "the fight played most of that second (%.2f s)" % played)
	var expected := speed * duel.sim.tps * played
	check(absf(duel.fight_tick - expected) <= 1.0, "a second on the screen is %.2f seconds of the fight (%d ticks for %.1f)" % [speed, duel.fight_tick, expected])
	check(is_equal_approx(screen._field.playback, speed), "and the field plays at the same pace (x%.2f)" % screen._field.playback)


func test_a_dragging_ending_plays_faster_still() -> void:
	var screen := _fight(12, [["brown_bear", "wolf_pack"], ["wild_boar", "black_rhino"]])
	var duel: DraftMatch = screen.duel
	var speed := BattleField.fight_speed()
	# One animal left a side, and nobody knocked out for a long while.
	var kept := [0, 0]
	for f in duel.sim.fighters:
		if f.alive and f.is_unit():
			kept[f.team] += 1
			if kept[f.team] > 1:
				f.alive = false
	screen._quiet = 60.0
	for i in 200:
		screen._speed_up_ending(0.05)
	var top := speed * Feel.num("choreography", "stall_max_speed", 1.0)
	check(top > speed, "a dragging ending has a speed of its own (x%.2f)" % top)
	check(is_equal_approx(screen._speed, top), "it plays that much faster than a fight already does (x%.2f for x%.2f)" % [screen._speed, top])
	check(is_equal_approx(screen._field.playback, top), "the field with it")
	# The round over: the last knockout and the celebration at their own pace.
	screen._reset_speed()
	check_eq(screen._field.playback, 1.0, "the ending plays at its own pace")
	check(is_equal_approx(screen._speed, speed), "and the next fight starts at the fights' speed again")


## What happens in a fight never depends on how fast it plays: the same
## armies and the same seed give the same fight, tick for tick.
func test_the_fight_is_the_same_at_any_speed() -> void:
	_speed_was = GameData.feel.choreography.fight_speed
	var fights := []
	for speed in [1.0, 1.25, 2.0]:
		GameData.feel.choreography.fight_speed = speed
		var screen := _fight(13, [["brown_bear", "gray_squirrel"], ["wild_boar", "king_cobra"]])
		var duel: DraftMatch = screen.duel
		var frames := 0
		while duel.phase == "fight" and frames < 60 * 120:
			_frame(screen, 1.0 / 60.0)
			frames += 1
		var health := 0
		for f in duel.sim.fighters:
			if f.alive and f.is_unit():
				health += int(f.hp)
		fights.append({"ticks": duel.fight_tick, "wins": str(duel.wins), "health": health, "frames": frames})
		check(duel.phase != "fight", "the fight ends (x%.2f: %d ticks in %d frames)" % [speed, duel.fight_tick, frames])
	for i in range(1, fights.size()):
		check_eq(fights[i].ticks, fights[0].ticks, "as long a fight, by the rules' clock")
		check_eq(fights[i].wins, fights[0].wins, "won by the same side")
		check_eq(fights[i].health, fights[0].health, "with the same health left")
	check(fights[2].frames < fights[0].frames, "only the time it takes on the screen differs (%d frames at x2 for %d at x1)" % [fights[2].frames, fights[0].frames])
