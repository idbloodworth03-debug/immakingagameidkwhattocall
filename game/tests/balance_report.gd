extends Node
## Plays lots of computer-vs-computer battles with random decks and prints how
## each card does: how often the deck holding it wins, and how often it gets
## played. A starting point for balancing, not a verdict: bots play the cards,
## not people.
##
## From the repository root (the number of battles is optional):
##   godot --headless --path game res://tests/balance_report.tscn -- 600
## A second number starts at a later battle, to split a long run across
## several copies; `-- 300 300` plays battles 300 to 599.
##
## Both decks in a battle come from the same arena and card levels, so a
## card's win rate compares it with the other cards available at that point.

const DEFAULT_BATTLES := 400


func _ready() -> void:
	var battles := DEFAULT_BATTLES
	var first := 0
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1 and args[0].is_valid_int():
		battles = maxi(1, args[0].to_int())
	if args.size() >= 2 and args[1].is_valid_int():
		first = maxi(0, args[1].to_int())

	var per_card := {}      # id -> {"games", "score", "plays"}
	var outcomes := {"win": 0, "draw": 0, "overtime": 0, "three_dens": 0, "dens": 0, "seconds": 0.0}
	var started := Time.get_ticks_msec()
	for battle_index in range(first, first + battles):
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + battle_index
		var arena := battle_index % GameData.arenas.size()
		var level_offset := rng.randi_range(0, 2)
		var a := BattleBot.make_deck(arena, level_offset, rng)
		var b := BattleBot.make_deck(arena, level_offset, rng)
		var sim := BattleSim.new([a.deck, b.deck], [a.levels, b.levels], rng.randi())
		var bots := [BattleBot.new(sim, 0, rng.randi()), BattleBot.new(sim, 1, rng.randi())]
		var plays := [{}, {}]
		while not sim.is_over():
			for bot in bots:
				bot.update()
			sim.step()
			for e in sim.take_events():
				if e.type == "release":
					plays[e.team][e.card] = int(plays[e.team].get(e.card, 0)) + 1

		var decks := [a.deck, b.deck]
		for team in 2:
			var score := 0.5 if sim.outcome == BattleSim.DRAW else (1.0 if sim.outcome == team else 0.0)
			for id in decks[team]:
				var stats: Dictionary = per_card.get(id, {"games": 0, "score": 0.0, "plays": 0})
				stats.games += 1
				stats.score += score
				stats.plays += int(plays[team].get(id, 0))
				per_card[id] = stats
		if sim.outcome == BattleSim.DRAW:
			outcomes.draw += 1
		else:
			outcomes.win += 1
		if sim.tick > sim.match_ticks:
			outcomes.overtime += 1
		var dens: int = sim.teams[0].towers_destroyed + sim.teams[1].towers_destroyed
		outcomes.dens += dens
		if sim.teams[0].towers_destroyed == 3 or sim.teams[1].towers_destroyed == 3:
			outcomes.three_dens += 1
		outcomes.seconds += float(sim.tick) / sim.tps

	print("\n%d battles in %.1f s" % [battles, (Time.get_ticks_msec() - started) / 1000.0])
	print("  draws %d%%, went to overtime %d%%, 3-den wins %d%%" % [
		roundi(100.0 * outcomes.draw / battles), roundi(100.0 * outcomes.overtime / battles),
		roundi(100.0 * outcomes.three_dens / battles)])
	print("  dens destroyed per battle %.2f, average length %d s" % [
		float(outcomes.dens) / battles, roundi(outcomes.seconds / battles)])

	var rows := []
	for id in per_card:
		var stats: Dictionary = per_card[id]
		rows.append({"id": id, "win": stats.score / stats.games, "games": stats.games, "plays": float(stats.plays) / stats.games})
	rows.sort_custom(func(x, y): return x.win > y.win)
	print("\n  %-22s %-9s %4s %6s %6s %s" % ["card", "rarity", "cost", "win %", "games", "plays/battle"])
	for row in rows:
		var card := GameData.get_card(row.id)
		var flag := ""
		if row.games >= 30 and row.win >= 0.58:
			flag = "  << strong"
		elif row.games >= 30 and row.win <= 0.42:
			flag = "  << weak"
		elif row.plays < 0.8:
			flag = "  << rarely played"
		print("  %-22s %-9s %4d %5d%% %6d %6.1f%s" % [card.name, card.rarity, int(card.cost), roundi(row.win * 100.0), row.games, row.plays, flag])
	get_tree().quit()
