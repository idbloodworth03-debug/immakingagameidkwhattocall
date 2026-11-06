extends Node
## How often the computer bans each rarity (BanPhase.bot_choice), over many
## ban phases with a player who owns every animal at its rarity's starting
## level, against every rival:
##   godot --headless --path game res://tests/ban_report.tscn -- 2000

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 2000
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var owned: Array = GameData.card_order.filter(func(id): return not GameData.is_tool(id))
	var levels := {}
	for id in owned:
		levels[id] = GameData.start_level(GameData.cards[id].rarity)
	var by_rarity := {}
	var by_animal := {}
	var with_mythic := 0
	var bans := 0
	for i in runs:
		var rival: Dictionary = GameData.rivals[i % GameData.rivals.size()]
		var phase := BanPhase.new(BanPhase.choices_for(owned, int(rival.get("arena_index", 0))), owned, 1)
		var any := false
		for k in phase.per_player:
			var id := phase.bot_choice(rival.get("style", {}), levels, rng, float(rival.get("difficulty", 0.5)))
			if id == "" or not phase.ban(1, id):
				break
			bans += 1
			var rarity := String(GameData.cards[id].rarity)
			by_rarity[rarity] = int(by_rarity.get(rarity, 0)) + 1
			by_animal[id] = int(by_animal.get(id, 0)) + 1
			if rarity == "mythic":
				any = true
			# The player bans too (something of the rival's): a random choice.
			var theirs: Array = phase.usable().filter(func(x): return phase.can_ban(0, x) == "")
			if not theirs.is_empty():
				phase.ban(0, theirs[rng.randi() % theirs.size()])
		if any:
			with_mythic += 1
	print("ban phases: %d, computer bans: %d" % [runs, bans])
	for r in GameData.rarity_order:
		var count := owned.filter(func(id): return GameData.cards[id].rarity == r).size()
		print("  %-10s %5.1f%% of its bans (%d animals, %.1f%% of the roster)" % [r, 100.0 * int(by_rarity.get(r, 0)) / maxf(1, bans), count, 100.0 * count / owned.size()])
	print("  a Mythic banned in %.1f%% of matches" % [100.0 * with_mythic / runs])
	var top := by_animal.keys()
	top.sort_custom(func(a, b): return by_animal[a] > by_animal[b])
	for id in top.slice(0, 8):
		print("    %-24s banned in %.1f%% of matches" % [id, 100.0 * by_animal[id] / runs])
	get_tree().quit()
