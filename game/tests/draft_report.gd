extends Node
## Plays computer-vs-computer Draft Duel matches and prints how they go: how
## many rounds a match lasts, how many hearts a round costs, how the bots
## shop, and how close fights are halfway through. A guide for tuning draft_rules.json, not a verdict: bots
## aren't people.
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
		"wipes": 0, "halfway": 0, "herd": 0, "stars": 0,
		"buys": 0, "merges": 0, "trains": 0, "rerolls": 0}
	var wins := [0, 0, 0]          # draws, team 0, team 1
	# Team 0's share of the strength left 8 seconds into a fight, in fifths:
	# 0-20% ... 80-100%.
	var close := [0, 0, 0, 0, 0]
	var started := Time.get_ticks_msec()
	for match_index in matches:
		var seed_value := 1000 + match_index
		var m := DraftMatch.new(seed_value)
		var bots := [DraftBot.new(m, 0, seed_value + 1, 0.6), DraftBot.new(m, 1, seed_value + 2, 0.6)]
		while not m.is_over():
			match m.phase:
				"starters":
					for b in bots:
						b.pick_starters()
				"draft":
					for b in bots:
						b.shop()
				"place":
					for b in bots:
						if not m.ready[b.team]:
							b.place()
				"fight":
					for b in bots:
						b.update()
					m.step()
					if m.phase == "fight" and m.fight_tick == 8 * m.sim.tps:
						totals.halfway += 1
						var mine := float(m.sim.herd_value(0))
						var share := mine / maxf(1.0, mine + float(m.sim.herd_value(1)))
						close[mini(4, int(share * 5.0))] += 1
				"round_over":
					m.next_round()
			for e in m.take_events():
				match e.type:
					"buy":
						totals.buys += 1
						totals.merges += int(e.merged)
					"train":
						totals.trains += 1
					"reroll":
						totals.rerolls += 1
					"round_over":
						totals.fights += 1
						totals.fight_seconds += float(m.fight_tick) / m.sim.tps
						totals.hearts_lost += int(m.last_round.hearts_lost[0]) + int(m.last_round.hearts_lost[1])
						totals.wipes += int(m.wiped_at[0] >= 0 or m.wiped_at[1] >= 0)
						totals.herd += m.herds[0].size() + m.herds[1].size()
						for herd in m.herds:
							for entry in herd:
								totals.stars += int(entry.stars)
		totals.rounds += m.round_number
		totals.knockouts += int(m.hearts[0] <= 0 or m.hearts[1] <= 0)
		wins[m.match_winner() + 1] += 1

	var fights := maxf(1.0, float(totals.fights))
	print("\nDraft Duel: %d matches in %.0f s" % [matches, (Time.get_ticks_msec() - started) / 1000.0])
	print("  rounds per match     %.1f (someone ran out of hearts in %d)" % [float(totals.rounds) / matches, totals.knockouts])
	print("  wins                 team 0: %d, team 1: %d, draws: %d" % [wins[1], wins[2], wins[0]])
	print("  per fight            %.1f s, %.1f hearts lost, %d%% ended in a wipe-out" % [totals.fight_seconds / fights, totals.hearts_lost / fights, roundi(100.0 * totals.wipes / fights)])
	print("  herd size            %.1f animals each, %.2f stars per animal, on average" % [totals.herd / fights / 2.0, totals.stars / maxf(1.0, float(totals.herd))])
	print("  shopping             per match: %.1f buys (%.1f were copies for a star), %.1f trainings, %.1f rerolls" % [
		float(totals.buys) / matches, float(totals.merges) / matches, float(totals.trains) / matches, float(totals.rerolls) / matches])
	print("  strength at 8 s      0-20%%: %d, 20-40%%: %d, 40-60%%: %d, 60-80%%: %d, 80-100%%: %d (team 0's share, %d fights)" % (close + [totals.halfway]))
	get_tree().quit()
