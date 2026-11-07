extends Node
## How much an animal adds to a herd, compared with an average animal in the
## game today: it joins a random herd of four and fights the same herd with a
## random animal of the game's instead, FIGHTS times, every card at its
## starting level. 0.5 = an average pick. Covers the animals on the way
## (data/animals_later.json) too. For tuning stats, not a verdict.
##
## From the repository root (ONLY=id,id to test a few; OUT=file to save):
##   godot --headless --path game res://tests/power_report.tscn
## Fights per animal (FIGHTS overrides). SCALE=id:factor,... multiplies an
## animal's health and damage first, for trying out a change. POOL=all
## draws the herds from the whole roster, the animals on the way included.
## WEIGHTS=draft picks them as often as Draft Duel offers each rarity
## (draft_rules.json "rarity_weights"), so 0.5 = an average offered card.
## RUN=n draws different fights (n = 1, 2...: separate runs to average, so
## random noise doesn't pass for a change; RUN=0, the default, as before).
const FIGHTS := 48

func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals_later.json"))
	var base_ids: Array = GameData.card_order.filter(func(id): return not GameData.is_tool(id))
	var all_ids: Array = base_ids.duplicate()
	for card in parsed:
		card["kind"] = "animal"
		card["unlock_arena_index"] = GameData.arena_index_by_id.get(card.unlock_arena, -1)
		GameData.cards[card.id] = card
		all_ids.append(card.id)
	# POOL=all: the herds and the animal it's compared with come from the
	# whole roster, the ones on the way too (how it will play once they're in).
	if OS.get_environment("POOL") == "all":
		base_ids = all_ids.duplicate()
	for spec in OS.get_environment("SCALE").split(",", false):
		var bits := spec.split(":")
		var stats: Dictionary = GameData.cards[bits[0]].stats
		stats.hp = roundi(float(stats.hp) * float(bits[1]))
		stats.damage = roundi(float(stats.damage) * float(bits[1]))
	var fights := int(OS.get_environment("FIGHTS")) if OS.get_environment("FIGHTS") != "" else FIGHTS
	var weights: Array[float] = []
	var total := 0.0
	for id in base_ids:
		var w := 1.0
		if OS.get_environment("WEIGHTS") == "draft":
			w = float(GameData.draft_rules.get("rarity_weights", {}).get(GameData.cards[id].rarity, 1))
		total += w
		weights.append(total)
	var pick := func(rng: RandomNumberGenerator) -> String:
		var roll := rng.randf() * total
		for k in weights.size():
			if roll < weights[k]:
				return String(base_ids[k])
		return String(base_ids[-1])
	var levels := {}
	for id in all_ids:
		levels[id] = GameData.start_level(GameData.cards[id].rarity)
	var only := OS.get_environment("ONLY")
	var lines := []
	for id in all_ids:
		if only != "" and not only.split(",").has(id):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(id) + int(OS.get_environment("RUN")) * 1000003
		var won := 0.0
		for i in fights:
			var herd := []
			for k in 4:
				herd.append({"id": pick.call(rng), "stars": 1})
			var other: String = pick.call(rng)
			var m := DraftMatch.new(rng.randi(), {"levels": [levels, levels]})
			var a := herd.duplicate(true)
			a.append({"id": id, "stars": 1})
			var b := herd.duplicate(true)
			b.append({"id": other, "stars": 1})
			# Swap sides half the time.
			m.herds = [a, b] if i % 2 == 0 else [b, a]
			m.picks_left = [0, 0]
			m.picks_made = [[], []]
			m.set_ready(0)
			m.set_ready(1)
			var guard := 0
			while m.phase == "fight" and guard < 5000:
				m.step()
				guard += 1
			var w := int(m.last_round.winner)
			var mine := 0 if i % 2 == 0 else 1
			won += 1.0 if w == mine else (0.5 if w < 0 else 0.0)
		var card: Dictionary = GameData.cards[id]
		lines.append("%.2f %s %s %s cost %d level %d" % [won / fights, id, card.rarity, card["class"], int(card.cost), levels[id]])
		print(lines[-1])
	if OS.get_environment("OUT") != "":
		var f := FileAccess.open(OS.get_environment("OUT"), FileAccess.WRITE)
		f.store_string("\n".join(lines) + "\n")
		f.close()
	get_tree().quit()
