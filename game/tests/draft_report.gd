extends Node
## Plays computer-vs-computer Draft Duel matches and prints how they go: how
## many rounds a match lasts, how fights end, how big the herds get, what the
## bots pick, and how each class does. A guide for tuning draft_rules.json and
## classes.json, not a verdict: bots aren't people.
##
## From the repository root (the number of matches is optional):
##   godot --headless --path game res://tests/draft_report.tscn -- 40

const DEFAULT_MATCHES := 40


func _ready() -> void:
	var matches := DEFAULT_MATCHES
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1 and args[0].is_valid_int():
		matches = maxi(1, args[0].to_int())

	var totals := {"rounds": 0, "fights": 0, "fight_seconds": 0.0, "wipes": 0, "herd": 0, "units": 0,
		"new": 0, "squads": 0, "stars": 0, "tools": 0}
	var wins := [0, 0, 0]          # draws, team 0, team 1
	var class_fights := {}         # class -> fights a herd had at least one
	var class_wins := {}
	var biggest := 0
	var started := Time.get_ticks_msec()
	for match_index in matches:
		var seed_value := 1000 + match_index
		var m := DraftMatch.new(seed_value)
		var bots := [DraftBot.new(m, 0, seed_value + 1, 0.6), DraftBot.new(m, 1, seed_value + 2, 0.6)]
		while not m.is_over():
			match m.phase:
				"pick":
					for b in bots:
						b.pick_all()
				"fight":
					for b in bots:
						b.update()
					m.step()
				"round_over":
					m.next_round()
			for e in m.take_events():
				match e.type:
					"pick":
						var kind: String = {"animal": "new", "squad": "squads", "star": "stars", "tool": "tools"}[e.kind]
						totals[kind] += 1
					"round_over":
						totals.fights += 1
						totals.fight_seconds += float(m.fight_tick) / m.sim.tps
						totals.wipes += int(m.wiped_at[0] >= 0 or m.wiped_at[1] >= 0)
						totals.herd += m.herds[0].size() + m.herds[1].size()
						for team in 2:
							var classes := {}
							for entry in m.herds[team]:
								classes[GameData.class_of(entry.id)] = true
							for cls in classes:
								class_fights[cls] = int(class_fights.get(cls, 0)) + 1
								if int(e.winner) == team:
									class_wins[cls] = int(class_wins.get(cls, 0)) + 1
			if m.phase == "fight" and m.fight_tick == 1:
				var count: int = m.sim.units(0).size() + m.sim.units(1).size()
				totals.units += count
				biggest = maxi(biggest, count)
		totals.rounds += m.round_number
		wins[m.match_winner() + 1] += 1

	var fights := maxf(1.0, float(totals.fights))
	print("\nDraft Duel: %d matches in %.0f s" % [matches, (Time.get_ticks_msec() - started) / 1000.0])
	print("  rounds per match     %.1f" % (float(totals.rounds) / matches))
	print("  wins                 team 0: %d, team 1: %d, draws: %d" % [wins[1], wins[2], wins[0]])
	print("  per fight            %.1f s, %d%% ended in a wipe-out" % [totals.fight_seconds / fights, roundi(100.0 * totals.wipes / fights)])
	print("  armies               %.1f kinds of animal each on average; %.1f animals on the field per fight, %d at most" % [
		totals.herd / fights / 2.0, totals.units / fights, biggest])
	var picks := maxf(1.0, totals.new + totals.squads + totals.stars + totals.tools)
	print("  picks                %.0f%% new animals, %.0f%% more squads, %.0f%% upgrades, %.0f%% tools" % [
		100.0 * totals.new / picks, 100.0 * totals.squads / picks, 100.0 * totals.stars / picks, 100.0 * totals.tools / picks])
	print("  classes              (fights a herd had one: its round wins)")
	for cls in GameData.class_order:
		print("    %-16s %4d fights, won %d%%" % [cls, int(class_fights.get(cls, 0)), roundi(100.0 * int(class_wins.get(cls, 0)) / maxf(1.0, float(class_fights.get(cls, 0))))])
	get_tree().quit()
