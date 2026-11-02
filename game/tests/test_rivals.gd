extends TestCase
## Rival Rangers (data/rivals.json, scripts/battle/opponents.gd): who you
## face, bosses, quietly easing after losses, and their ways of playing.

var profile: Node


func _init() -> void:
	profile = load("res://scripts/autoload/profile.gd").new()
	profile.autosave = false
	profile.testing_switches = false
	profile.reset()


func cleanup() -> void:
	profile.free()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_every_arena_has_rivals_and_one_boss() -> void:
	for i in GameData.arenas.size():
		var regulars := GameData.rivals_in_arena(i, false).size()
		check(regulars >= 2 and regulars <= 3, "%s has 2 or 3 regular rivals (%d)" % [GameData.arenas[i].id, regulars])
		check_eq(GameData.rivals_in_arena(i, true).size(), 1, "%s has one boss" % GameData.arenas[i].id)
	var names := {}
	for r in GameData.rivals:
		check(not names.has(r.name), "%s is the only rival with that name" % r.name)
		names[r.name] = true
		check(String(r.get("line", "")) != "", "%s has a line" % r.name)


func test_the_boss_guards_the_way_up() -> void:
	var next_at := int(GameData.arenas[1].min_trophies)
	var within := int(GameData.rival_rules.boss_within_trophies)
	check(not Opponents.is_boss_match(0, []), "a new player meets a regular")
	check(not Opponents.is_boss_match(next_at - within - 1, []), "too far from the next arena for the boss")
	check(Opponents.is_boss_match(next_at - within, []), "a win could take you up: the boss")
	var boss := Opponents.pick(_rng(1), next_at - 10, 0, [], 3)
	check(boss.boss, "picked the boss")
	check_eq(boss.id, GameData.rivals_in_arena(0, true)[0].id, "the first arena's boss")
	check(int(boss.trophies) >= next_at, "the boss has the next arena's trophies")
	var regular := Opponents.pick(_rng(2), 100, 0, [], 3)
	check(not regular.boss, "a regular otherwise")
	check_eq(regular.arena, GameData.arenas[0].id, "from your arena")


func test_the_top_arena_boss() -> void:
	var top := GameData.arenas.size() - 1
	var start := int(GameData.arenas[top].min_trophies)
	var after := int(GameData.rival_rules.top_arena_boss_after)
	check(not Opponents.is_boss_match(start, []), "not right away in the top arena")
	check(Opponents.is_boss_match(start + after, []), "once you're settled in")
	check(not Opponents.is_boss_match(start + after, [GameData.arenas[top].id]), "beaten: no longer every match")
	var seen_boss := false
	for seed_value in 40:
		seen_boss = seen_boss or Opponents.pick(_rng(seed_value), start + after, 0, [GameData.arenas[top].id], 9).boss
	check(seen_boss, "but it still turns up for rematches")


func test_difficulty_scales_and_eases_after_losses() -> void:
	var first: Dictionary = GameData.rivals_in_arena(0, false)[0]
	var last: Dictionary = GameData.rivals_in_arena(GameData.arenas.size() - 1, false)[0]
	check(Opponents.difficulty_for(last, GameData.arenas.size() - 1, false) > Opponents.difficulty_for(first, 0, false) + 0.5, "higher arenas are much sharper")
	var mid := 5
	var regular: Dictionary = GameData.rivals_in_arena(mid, false)[0]
	var boss: Dictionary = GameData.rivals_in_arena(mid, true)[0]
	check(Opponents.difficulty_for(boss, mid, false) > Opponents.difficulty_for(regular, mid, false), "a boss is sharper than its arena's regulars")
	check(Opponents.difficulty_for(boss, mid, true) < Opponents.difficulty_for(boss, mid, false), "eased is easier")
	var losses := int(GameData.rival_rules.ease_after_losses)
	check(not Opponents.is_eased(losses - 1), "not eased yet")
	check(Opponents.is_eased(losses), "eased after %d losses in a row" % losses)
	var eased := Opponents.pick(_rng(3), 2000, losses, [], 5)
	check(eased.eased, "the pick knows")
	check(Opponents.level_drop(eased) > 0, "and its cards are a little lower")
	check_eq(Opponents.level_drop(Opponents.pick(_rng(3), 2000, 0, [], 5)), 0, "not otherwise")


func test_regular_wins_cant_skip_the_boss() -> void:
	var next_at := int(GameData.arenas[1].min_trophies)
	profile.data.trophies = next_at - 10
	var result: Dictionary = profile.record_match("win", next_at)
	check_eq(profile.get_trophies(), next_at - 1, "stops just short of the next arena")
	check(not result.new_arena, "no new arena")


func test_beating_a_boss_promotes_and_rewards_once() -> void:
	var next_at := int(GameData.arenas[1].min_trophies)
	profile.data.trophies = next_at - 35
	var gold: int = profile.get_gold()
	var gems: int = profile.get_gems()
	var result: Dictionary = profile.record_match("win", next_at, true)
	check(result.boss_beaten, "boss beaten")
	check(result.new_arena and profile.arena_index() == 1, "promoted")
	var reward: Dictionary = GameData.rival_rules.boss_reward
	check_eq(result.boss_reward.gold, int(reward.gold), "reward: gold")
	check_eq(profile.get_gold(), gold + int(reward.gold), "gold given")
	check_eq(profile.get_gems(), gems + int(reward.gems), "gems given")
	check_eq(result.boss_reward.cage_id, String(reward.cage), "a cage too, while there's a free slot")
	check(profile.bosses_beaten().has(GameData.arenas[0].id), "remembered")
	# Back down (say, a reset of the arena) and beat it again: no second reward.
	profile.data.trophies = next_at - 35
	var again: Dictionary = profile.record_match("win", next_at, true)
	check(again.boss_beaten, "beaten again")
	check(again.boss_reward.is_empty(), "but the reward is only the first time")


func test_losing_to_a_boss() -> void:
	profile.data.trophies = 280
	var result: Dictionary = profile.record_match("loss", 300, true)
	check(not result.boss_beaten, "not beaten")
	check(result.boss_reward.is_empty(), "no reward")
	check(profile.bosses_beaten().is_empty(), "nothing remembered")


func test_loss_streak() -> void:
	profile.record_match("loss", 0)
	profile.record_match("loss", 0)
	check_eq(profile.loss_streak(), 2, "two losses in a row")
	profile.record_match("draw", 0)
	check_eq(profile.loss_streak(), 2, "a draw doesn't break it")
	profile.record_match("win", 0)
	check_eq(profile.loss_streak(), 0, "a win resets it")


func _shop_match() -> DraftMatch:
	var m := DraftMatch.new(6)
	m.pick_starters(0, [])
	m.pick_starters(1, [])
	return m


func test_a_favorite_habitat() -> void:
	var m := _shop_match()
	var fan := DraftBot.new(m, 1, 9, 0.5, {"favorite": "forest"})
	var plain := DraftBot.new(m, 1, 9, 0.5)
	check_eq(fan.favorite, "forest", "builds around Forest")
	var item := {"id": "red_fox", "cost": GameData.get_card("red_fox").cost}
	check_eq(fan._want(item) - plain._want(item), DraftBot.FAVORITE_BONUS, "wants Forest animals more")
	var other := {"id": "lion", "cost": GameData.get_card("lion").cost}
	check_eq(fan._want(other), plain._want(other), "and the rest the same")
	var unbuildable := DraftBot.new(m, 1, 9, 0.5, {"favorite": "ocean"})
	check_eq(unbuildable.favorite, "", "a habitat with too few animals in the pool is ignored")


func test_personalities() -> void:
	var m := _shop_match()
	var herd := ["brown_bear", "lion", "wolf_pack", "cheetah", "red_fox"]
	m.herds[1] = herd.map(func(id): return {"id": id, "x": 0, "y": 0, "stars": 1})
	m.acorns[1] = 26
	var saver := DraftBot.new(m, 1, 1, 0.5, {"saving": 0.95})
	var spender := DraftBot.new(m, 1, 1, 0.5, {"saving": 0.0})
	check(saver._reserve() > spender._reserve(), "a saver keeps more Acorns back (%d vs %d)" % [saver._reserve(), spender._reserve()])
	var trainer := DraftBot.new(m, 1, 1, 0.5, {"stars": 0.95})
	var casual := DraftBot.new(m, 1, 1, 0.5, {"stars": 0.1})
	check(trainer._train_value(0, 4) > casual._train_value(0, 4), "a star-chaser trains more")
	m.tools[1] = ["net"]
	var tinkerer := DraftBot.new(m, 1, 1, 0.5, {"tools": 0.95})
	var plain := DraftBot.new(m, 1, 1, 0.5)
	var tool := {"id": "net", "cost": GameData.get_card("net").cost}
	check(tinkerer._want(tool) > plain._want(tool) + 1.0, "a tool lover wants a second tool")


func test_rival_bots_play_whole_matches() -> void:
	# Every rival's style on both sides, a short match each.
	var rules := GameData.draft_rules.duplicate()
	rules.max_rounds = 3
	for i in range(0, GameData.rivals.size(), 6):
		var a: Dictionary = GameData.rivals[i]
		var b: Dictionary = GameData.rivals[(i + 3) % GameData.rivals.size()]
		var m := DraftMatch.new(100 + i, {}, rules)
		var bots := [DraftBot.new(m, 0, i + 1, Opponents.difficulty_for(a, 3, false), a.style), DraftBot.new(m, 1, i + 2, Opponents.difficulty_for(b, 3, false), b.style)]
		var guard := 0
		while not m.is_over() and guard < 100000:
			guard += 1
			match m.phase:
				"starters":
					for bot in bots:
						bot.pick_starters()
				"draft":
					for bot in bots:
						bot.shop()
				"place":
					for bot in bots:
						if not m.ready[bot.team]:
							bot.place()
				"fight":
					for bot in bots:
						bot.update()
					m.step()
				"round_over":
					m.next_round()
		check(m.is_over(), "%s vs %s finishes" % [a.name, b.name])
