extends Node
## How the classes do against each other as armies: for every pair of
## classes, armies of CARDS cards of one class (drawn from that class's
## animals as often as Draft Duel offers each rarity, every card at its
## starting level) fight armies of the other, FIGHTS times, sides swapped
## half the time. Prints each class's win rate against each other class, and
## how long the fights take. The counters should show: Tank Destroyers beat
## Tanks, Ranged beat Air, Air beats Tank Destroyers. For tuning, not a
## verdict.
##
## From the repository root:
##   godot --headless --path game res://tests/class_report.tscn
## FIGHTS (default 30), CARDS (default 4); OUT=file saves the report.

func _ready() -> void:
	var fights := int(OS.get_environment("FIGHTS")) if OS.get_environment("FIGHTS") != "" else 30
	var cards := int(OS.get_environment("CARDS")) if OS.get_environment("CARDS") != "" else 4
	var by_class := {}
	for id in GameData.card_order:
		if not GameData.is_tool(id):
			var cls := GameData.class_of(id)
			if not by_class.has(cls):
				by_class[cls] = []
			by_class[cls].append(id)
	var levels := {}
	for id in GameData.card_order:
		levels[id] = GameData.start_level(GameData.cards[id].rarity)
	var weights: Dictionary = GameData.draft_rules.get("rarity_weights", {})
	var pick := func(cls: String, rng: RandomNumberGenerator) -> String:
		var ids: Array = by_class[cls]
		var total := 0.0
		for id in ids:
			total += float(weights.get(GameData.cards[id].rarity, 1))
		var roll := rng.randf() * total
		for id in ids:
			roll -= float(weights.get(GameData.cards[id].rarity, 1))
			if roll <= 0.0:
				return id
		return ids[-1]
	var classes: Array = GameData.class_order
	var rate := {}
	var seconds := 0.0
	var count := 0
	for i in classes.size():
		for j in range(i + 1, classes.size()):
			var a: String = classes[i]
			var b: String = classes[j]
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(a + b)
			var won := 0.0
			for n in fights:
				var armies := [[], []]
				for side in 2:
					var cls: String = [a, b][side]
					for k in cards:
						var id: String = pick.call(cls, rng)
						var found := false
						for entry in armies[side]:
							if entry.id == id:
								entry.squads += 1
								found = true
						if not found:
							armies[side].append({"id": id, "stars": 1, "squads": 1})
				var m := DraftMatch.new(rng.randi(), {"levels": [levels, levels]})
				var swap := n % 2 == 1
				m.herds = [armies[1], armies[0]] if swap else armies
				m.picks_left = [0, 0]
				m.picks_made = [[], []]
				m.set_ready(0)
				m.set_ready(1)
				var guard := 0
				while m.phase == "fight" and guard < 5000:
					m.step()
					guard += 1
				seconds += float(m.fight_tick) / m.sim.tps
				count += 1
				var w := int(m.last_round.winner)
				var a_side := 1 if swap else 0
				won += 1.0 if w == a_side else (0.5 if w < 0 else 0.0)
			rate["%s/%s" % [a, b]] = won / fights
			rate["%s/%s" % [b, a]] = 1.0 - won / fights
	var lines := ["Class report: %d fights a pair, %d cards an army, %.1f s a fight on average" % [fights, cards, seconds / maxf(1, count)]]
	var head := "%-16s" % "wins vs"
	for b in classes:
		head += "%-10s" % String(b).substr(0, 9)
	lines.append(head)
	for a in classes:
		var row := "%-16s" % a
		var sum := 0.0
		for b in classes:
			if a == b:
				row += "%-10s" % "-"
			else:
				row += "%-10s" % ("%d%%" % roundi(100.0 * float(rate["%s/%s" % [a, b]])))
				sum += float(rate["%s/%s" % [a, b]])
		row += "  average %d%%" % roundi(100.0 * sum / (classes.size() - 1))
		lines.append(row)
	for line in lines:
		print(line)
	if OS.get_environment("OUT") != "":
		var f := FileAccess.open(OS.get_environment("OUT"), FileAccess.WRITE)
		f.store_string("\n".join(lines) + "\n")
		f.close()
	get_tree().quit()
