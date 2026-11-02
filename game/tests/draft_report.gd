extends Node
## Plays computer-vs-computer Draft Duel matches, with the real Bookie setting
## the odds, and prints how they go: how many rounds a match lasts, how many
## hearts a round costs, how often the bots bet, raise and fold, how sure
## the Bookie's odds are, and how long the Bookie takes to think. A guide for
## tuning draft_rules.json, not a verdict: bots aren't people.
##
## From the repository root (the number of matches is optional):
##   godot --headless --path game res://tests/draft_report.tscn -- 40

const DEFAULT_MATCHES := 40


func _ready() -> void:
	var matches := DEFAULT_MATCHES
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1 and args[0].is_valid_int():
		matches = maxi(1, args[0].to_int())

	var totals := {"rounds": 0, "knockouts": 0, "fights": 0, "fight_seconds": 0.0, "hearts_lost": 0,
		"wipes": 0, "bets": 0, "raises": 0, "folds": 0, "halftimes": 0, "herd": 0}
	var wins := [0, 0, 0]          # draws, team 0, team 1
	var odds := [0, 0, 0, 0, 0]    # Bookie's pre-fight odds in fifths: 0-20% ... 80-100%
	var think_ms := []
	var started := Time.get_ticks_msec()
	for match_index in matches:
		var seed_value := 1000 + match_index
		var m := DraftMatch.new(seed_value)
		var bots := [DraftBot.new(m, 0, seed_value + 1, 0.6), DraftBot.new(m, 1, seed_value + 2, 0.6)]
		var halftime_line := -1.0
		while not m.is_over():
			match m.phase:
				"draft":
					bots[m.turn].pick()
				"place":
					for b in bots:
						if not m.ready[b.team]:
							b.place()
				"wager":
					var t0 := Time.get_ticks_msec()
					var bookie := Bookie.study(m, seed_value)
					bookie.advance()
					think_ms.append(Time.get_ticks_msec() - t0)
					var chance := bookie.chance(0)
					odds[mini(4, int(chance * 5.0))] += 1
					m.post_line(chance)
					bots[0].back_herd(chance)
					bots[1].back_herd(1.0 - chance)
					totals.bets += int(m.wagers[0] > 0) + int(m.wagers[1] > 0)
				"fight":
					for b in bots:
						b.update()
					m.step()
					halftime_line = -1.0
				"halftime":
					if halftime_line < 0.0:
						var bookie := Bookie.study(m, seed_value + 7)
						bookie.advance()
						halftime_line = bookie.chance(0)
						totals.halftimes += 1
					var team := int(m.halftime.turn)
					bots[team].bet(halftime_line if team == 0 else 1.0 - halftime_line)
				"round_over":
					m.next_round()
			for e in m.take_events():
				match e.type:
					"raise":
						totals.raises += 1
					"fold":
						totals.folds += 1
					"round_over":
						totals.fights += 1
						totals.fight_seconds += float(m.fight_tick) / m.sim.tps
						totals.hearts_lost += int(m.last_round.hearts_lost[0]) + int(m.last_round.hearts_lost[1])
						totals.wipes += int(m.wiped_at[0] >= 0 or m.wiped_at[1] >= 0)
						totals.herd += m.herds[0].size() + m.herds[1].size()
		totals.rounds += m.round_number
		totals.knockouts += int(m.hearts[0] <= 0 or m.hearts[1] <= 0)
		wins[m.match_winner() + 1] += 1

	var fights := maxf(1.0, float(totals.fights))
	print("\nDraft Duel: %d matches in %.0f s" % [matches, (Time.get_ticks_msec() - started) / 1000.0])
	print("  rounds per match     %.1f (someone ran out of hearts in %d)" % [float(totals.rounds) / matches, totals.knockouts])
	print("  wins                 team 0: %d, team 1: %d, draws: %d" % [wins[1], wins[2], wins[0]])
	print("  per fight            %.1f s, %.1f hearts lost, %d%% ended in a wipe-out" % [totals.fight_seconds / fights, totals.hearts_lost / fights, roundi(100.0 * totals.wipes / fights)])
	print("  herd size            %.1f animals each, on average" % (totals.herd / fights / 2.0))
	print("  betting              %d bets on own herd, %d raises, %d folds in %d halftimes" % [totals.bets, totals.raises, totals.folds, totals.halftimes])
	print("  Bookie's odds        0-20%%: %d, 20-40%%: %d, 40-60%%: %d, 60-80%%: %d, 80-100%%: %d" % odds)
	think_ms.sort()
	if not think_ms.is_empty():
		print("  Bookie's thinking    median %d ms, slowest %d ms (this computer)" % [think_ms[think_ms.size() / 2], think_ms[-1]])
	get_tree().quit()
