extends TestCase
## Sorting animals (scripts/ui/animal_sort.gd, sort_bar.gd, data/sorting.json):
## Level, Rarity, Class and Biome, both ways, on Your Deck, the bans, the
## Animals tab, and inside a match (your starters, your army row). Each
## screen remembers its choice; sorting never touches what's picked,
## banned or in your army.

var _saved: Dictionary
var _autosave := true
var _switches := true
var _made: Array = []


func _init() -> void:
	_saved = Profile.data.duplicate(true)
	_autosave = Profile.autosave
	_switches = Profile.testing_switches
	Profile.autosave = false
	Profile.testing_switches = false


func cleanup() -> void:
	for node in _made:
		if is_instance_valid(node):
			node.free()
	_made.clear()
	Profile.data = _saved
	Profile.autosave = _autosave
	Profile.testing_switches = _switches
	MatchPlan.clear()


func _host() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_child(tree.root.get_child_count() - 1)


func _animals() -> Array:
	return GameData.card_order.filter(func(id): return not GameData.is_tool(id))


## A made-up collection: most animals owned at a spread of levels (with
## ties), every fifth one not yet.
func _levels() -> Dictionary:
	var levels := {}
	var all := _animals()
	for i in all.size():
		if i % 5 != 4:
			levels[all[i]] = 1 + (i * 7) % 12
	return levels


## The rules again, written another way: a list to compare, smallest first.
func _rank(id: String, key: String, desc: bool, levels: Dictionary) -> Array:
	var card := GameData.get_card(id)
	var rarity := GameData.rarity_order.find(String(card.rarity))
	var flip := -1 if desc else 1
	var tier := 0
	var main := 0
	match key:
		"level":
			tier = 0 if levels.has(id) else 1
			main = int(levels.get(id, 0))
		"rarity":
			main = rarity
		"class":
			main = GameData.class_order.find(GameData.class_of(id))
		"biome":
			main = GameData.habitat_order.size() if card.rarity == "mythic" else GameData.habitat_order.find(String(card.habitat))
	return [tier, flip * main, -rarity, String(card.name)]


func _in_order(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] < b[i]
	return true


func _check_sorted(order: Array, key: String, desc: bool, levels: Dictionary, what: String) -> void:
	var all := _animals()
	check_eq(order.size(), all.size(), "%s: all %d animals" % [what, all.size()])
	var copy := order.duplicate()
	copy.sort()
	var want := all.duplicate()
	want.sort()
	check_eq(copy, want, "%s: each animal once" % what)
	for i in order.size() - 1:
		if not _in_order(_rank(order[i], key, desc, levels), _rank(order[i + 1], key, desc, levels)):
			failures.append("%s: %s before %s" % [what, order[i], order[i + 1]])
			return


func test_each_sort_orders_all_35_both_ways() -> void:
	var levels := _levels()
	check_eq(_animals().size(), 35, "35 animals")
	for key in AnimalSort.KEYS:
		for desc in [true, false]:
			_check_sorted(AnimalSort.sorted(_animals(), key, desc, levels), key, desc, levels, "%s %s" % [key, "down" if desc else "up"])


func test_the_sorts_in_detail() -> void:
	var levels := _levels()
	var all := _animals()
	# Level: highest first, or lowest; the ones you don't own last both ways.
	var top := 0
	var bottom := 99
	for id in levels:
		top = maxi(top, int(levels[id]))
		bottom = mini(bottom, int(levels[id]))
	for desc in [true, false]:
		var order := AnimalSort.sorted(all, "level", desc, levels)
		check_eq(int(levels[order[0]]), top if desc else bottom, "Level %s: starts at level %d" % ["down" if desc else "up", top if desc else bottom])
		var owned := levels.size()
		for i in order.size():
			check(levels.has(order[i]) == (i < owned), "Level: animals you don't own come last (%s at %d)" % [order[i], i])
		var groups := AnimalSort.grouped(all, "level", desc, levels)
		check_eq(String(groups[-1].group), "not_owned", "Level: the last group is the ones you don't own")
		check_eq(String(groups[-1].label), String(GameData.sorting.not_owned.label), "with its name")
	# Rarity: Mythic first, or Common first.
	var rarity := AnimalSort.grouped(all, "rarity", true, levels)
	check_eq(rarity.map(func(g): return g.group), ["mythic", "legendary", "epic", "rare", "common"], "Rarity: Mythic first")
	check_eq(String(rarity[0].label), "Mythic", "headed Mythic")
	check_eq(AnimalSort.grouped(all, "rarity", false, levels).map(func(g): return g.group), ["common", "rare", "epic", "legendary", "mythic"], "and Common first the other way")
	# Class: in classes.json order, or the other way round.
	check_eq(AnimalSort.grouped(all, "class", false, levels).map(func(g): return g.group), GameData.class_order, "Class: Tank first")
	var back: Array = GameData.class_order.duplicate()
	back.reverse()
	check_eq(AnimalSort.grouped(all, "class", true, levels).map(func(g): return g.group), back, "Class: flipped")
	# Biome: habitats in order, the Mythics in a Legends group of their own.
	var biome := AnimalSort.grouped(all, "biome", false, levels)
	check_eq(String(biome[-1].group), "legends", "Biome: the Mythics in their own group")
	check_eq(String(biome[-1].label), "Legends", "called Legends")
	var mythics := all.filter(func(id): return GameData.cards[id].rarity == "mythic")
	var legends: Array = biome[-1].ids.duplicate()
	legends.sort()
	mythics.sort()
	check_eq(legends, mythics, "every Mythic, and only Mythics")
	for group in biome.slice(0, biome.size() - 1):
		check(GameData.habitats.has(group.group), "Biome: %s is a habitat" % group.group)
		for id: String in group.ids:
			check_eq(String(GameData.cards[id].habitat), String(group.group), "%s lives in %s" % [id, group.group])
	check_eq(String(AnimalSort.grouped(all, "biome", true, levels)[0].group), "legends", "Biome flipped: Legends first")
	# Ties: rarest first, then by name.
	var tanks: Array = AnimalSort.grouped(all, "class", false, levels)[0].ids
	for i in tanks.size() - 1:
		var ra := GameData.rarity_rank(GameData.cards[tanks[i]].rarity)
		var rb := GameData.rarity_rank(GameData.cards[tanks[i + 1]].rarity)
		check(ra > rb or (ra == rb and String(GameData.cards[tanks[i]].name) < String(GameData.cards[tanks[i + 1]].name)), "Tanks: rarest first, then by name (%s, %s)" % [tanks[i], tanks[i + 1]])
	# The same input in any order sorts the same.
	var shuffled := all.duplicate()
	shuffled.reverse()
	for key in AnimalSort.KEYS:
		check_eq(AnimalSort.sorted(shuffled, key, true, levels), AnimalSort.sorted(all, key, true, levels), "%s: the order never jumps about" % key)


func test_tools_come_after_the_animals() -> void:
	# (With Ranger tools on: they're switched off for now.)
	turn_tools_on()
	var levels := _levels()
	levels["net"] = 3
	for key in AnimalSort.KEYS:
		var groups := AnimalSort.grouped(GameData.card_order, key, true, levels)
		check_eq(String(groups[-1].group), "tools", "%s: the tools in a group at the end" % key)
		for id: String in groups[-1].ids:
			check(GameData.is_tool(id), "%s: only tools in it" % key)


func test_each_screen_remembers_its_choice() -> void:
	Profile.data["sort"] = {}
	var bar := SortBar.make("deck")
	_made.append(bar)
	check_eq(bar.key, String(GameData.sorting.screens.deck), "a screen starts on its own sort")
	bar.choose("level")
	check(bar.key == "level" and bar.desc, "Level: highest first")
	bar.choose("level")
	check(bar.key == "level" and not bar.desc, "tapping it again flips it: lowest first")
	var again := SortBar.make("deck")
	_made.append(again)
	check(again.key == "level" and not again.desc, "the next time: as you left it")
	var bans := SortBar.make("bans")
	_made.append(bans)
	check_eq(bans.key, String(GameData.sorting.screens.bans), "each screen its own choice")
	bar.choose("biome")
	check(bar.key == "biome" and not bar.desc, "a new sort starts its own way round")
	check_eq(Profile.sort_choice("deck"), {"key": "biome", "desc": false}, "saved in the profile")
	# The chosen button is lit, with its arrow.
	for o in AnimalSort.options():
		var b: ChunkyButton = bar.get_node("Sort_" + String(o.id))
		check_eq(b.kind, "primary" if o.id == "biome" else "secondary", "%s button lit only when chosen" % o.id)
		check_eq(b.content.get_node("Arrow").visible, o.id == "biome", "%s arrow only when chosen" % o.id)


## Owns these animals (and nothing else), at these levels.
func _own(levels: Dictionary) -> void:
	Profile.data.collection = {}
	for id in levels:
		Profile.data.collection[id] = {"level": int(levels[id]), "copies": 0, "new": false}


func test_your_deck_keeps_its_picks_through_every_sort() -> void:
	var levels := _levels()
	_own(levels)
	var owned: Array = _animals().filter(func(id): return levels.has(id))
	Profile.data["draft_deck"] = owned.slice(0, 8)
	MatchPlan.clear()
	MatchPlan.banned = [owned[9]]
	var screen: Control = load("res://scenes/deck.tscn").instantiate()
	_made.append(screen)
	_host().add_child(screen)
	# Take one out and put another in: the picks so far.
	screen._toggle(owned[2])
	screen._toggle(owned[12])
	var deck: Array = screen._deck.duplicate()
	check(deck.has(owned[12]) and not deck.has(owned[2]), "picked")
	for key in AnimalSort.KEYS:
		for flip in 2:
			screen._sort.choose(key)
			var desc: bool = screen._sort.desc
			check_eq(screen._deck, deck, "%s: your picks stay" % key)
			check_eq(screen.shown_order(), AnimalSort.sorted(owned, key, desc, levels), "%s %s: the collection in order" % [key, desc])
			for center in screen._collection.get_children():
				if center is CenterContainer:
					for card: AnimalCard in center.get_child(0).get_children():
						check_eq(card.checked, deck.has(card.animal_id), "%s: %s ticked only if in your deck" % [key, card.animal_id])
						check_eq(card.get_children().any(func(c): return c is BanX), card.animal_id == owned[9], "%s: only the banned one crossed out" % key)
	var headers: int = screen._collection.get_children().filter(func(c): return c.has_meta("group")).size()
	check_eq(headers, AnimalSort.grouped(owned, screen._sort.key, screen._sort.desc, levels).size(), "a header for each group")


func test_bans_survive_a_re_sort() -> void:
	var levels := {}
	for id in _animals():
		levels[id] = GameData.start_level(GameData.cards[id].rarity)
	levels.erase("dragon")
	_own(levels)
	var screen: Control = load("res://scenes/ban.tscn").instantiate()
	screen.auto_start = false
	_made.append(screen)
	_host().add_child(screen)
	var phase: BanPhase = screen.phase
	var mine: Array = phase.usable().filter(func(id): return phase.can_ban(phase.turn(), id) == "")
	var first: String = mine[0]
	var first_team := phase.turn()
	check(phase.ban(first_team, first), "a ban")
	screen._stamp(first, first_team)
	var second := ""
	for id: String in phase.usable():
		if phase.can_ban(phase.turn(), id) == "":
			second = id
			break
	var second_team := phase.turn()
	check(phase.ban(second_team, second), "another")
	screen._stamp(second, second_team)
	# A card you've tapped (picked, not banned yet), whoever's turn it is.
	var chosen: String = phase.usable().filter(func(id): return id != first and id != second)[0]
	screen._busy = false
	screen._select(chosen)
	var bans: String = str(phase.bans)
	for key in AnimalSort.KEYS:
		for flip in 2:
			screen._sort.choose(key)
			var desc: bool = screen._sort.desc
			check_eq(str(phase.bans), bans, "%s: the bans stay" % key)
			check_eq(screen.shown_order(), AnimalSort.sorted(phase.choices, key, desc, levels), "%s %s: the cards in order" % [key, desc])
			for id in [first, second]:
				var card: AnimalCard = screen._cards[id]
				check(card.get_children().any(func(c): return c is BanX), "%s: %s keeps its X" % [key, id])
			check_eq(screen._selected, chosen, "%s: the card you'd picked stays picked" % key)
			check(screen._cards[chosen].highlighted, "%s: and lit" % key)
	check_eq(screen._cards.size(), phase.choices.size(), "the same cards, moved")


func test_the_animals_tab_sorts_and_keeps_locked_ones_locked() -> void:
	var levels := _levels()
	_own(levels)
	var tab: Control = load("res://scripts/ui/tabs/animals_tab.gd").new()
	_made.append(tab)
	_host().add_child(tab)
	var not_owned := _animals().filter(func(id): return not levels.has(id))
	check(not not_owned.is_empty(), "some animals not found yet")
	for key in AnimalSort.KEYS:
		for flip in 2:
			tab._sort.choose(key)
			var desc: bool = tab._sort.desc
			var order: Array = tab.shown_order().filter(func(id): return not GameData.is_tool(id))
			_check_sorted(order, key, desc, levels, "Animals tab %s" % key)
			check_eq(order, AnimalSort.sorted(_animals(), key, desc, levels), "Animals tab %s %s" % [key, desc])
	# On screen: every card there, the ones you don't own still locked.
	var seen := {}
	for child in tab._content.get_children():
		if child is GridContainer:
			for card: AnimalCard in child.get_children():
				seen[card.animal_id] = true
				if not GameData.is_tool(card.animal_id):
					check_eq(card._owned, levels.has(card.animal_id), "%s shows as %s" % [card.animal_id, "owned" if levels.has(card.animal_id) else "locked"])
	check_eq(seen.size(), GameData.card_order.size(), "every animal and tool on the tab")


## Under a class's own header the cards leave out their class badge (the
## header says it); under any other sort they show it.
func test_cards_under_a_class_header_leave_out_their_class_badge() -> void:
	var levels := _levels()
	_own(levels)
	var tab: Control = load("res://scripts/ui/tabs/animals_tab.gd").new()
	_made.append(tab)
	_host().add_child(tab)
	for key in AnimalSort.KEYS:
		tab._sort.choose(key)
		tab._rebuild()
		var cards := 0
		for child in tab._content.get_children():
			if child is GridContainer:
				for card: AnimalCard in child.get_children():
					cards += 1
					check_eq(card.show_class, key != "class", "%s sorted by %s: its class badge %s" % [card.animal_id, key, "left out" if key == "class" else "shown"])
		check_eq(cards, GameData.card_order.size(), "every card on the tab (%s)" % key)


## A match's pick screen, without the rest (no intro, no fighting): just
## the pick view, in the tree.
func _pick_screen(duel: DraftMatch) -> Control:
	var screen: Control = load("res://scripts/draft/draft_screen.gd").new()
	screen.duel = duel
	screen._rival_check = Control.new()
	_made.append(screen._rival_check)
	_made.append(screen)
	var view: Control = screen._build_pick_view()
	_made.push_front(view)
	_host().add_child(view)
	return screen


func test_sorting_in_a_match_never_changes_your_picks_or_army() -> void:
	var levels := _levels()
	_own(levels)
	var deck := ["brown_bear", "lion", "gray_squirrel", "peregrine_falcon", "red_fox", "unicorn", "hippopotamus", "tiger"]
	var duel := DraftMatch.new(5, {"levels": [levels, {}], "pools": [deck + ["net"], ["wolf_pack", "raccoon", "barn_owl", "wild_boar", "snapping_turtle", "harbor_seal", "honey_badger", "striped_skunk"]]})
	check(duel.is_first_round(), "round 1")
	var screen := _pick_screen(duel)
	screen._build_options(false)
	var ids: Array = duel.offers[0].map(func(o): return String(o.id))
	# Two starters picked.
	for want in ["lion", "unicorn"]:
		check(duel.pick(0, ids.find(want)), "picked the %s" % want)
	var picks := str(duel.picks_made[0])
	var offers := str(duel.offers[0])
	for key in AnimalSort.KEYS:
		for flip in 2:
			screen._start_sort.choose(key)
			var desc: bool = screen._start_sort.desc
			check_eq(str(duel.picks_made[0]), picks, "%s: your picks stay" % key)
			check_eq(str(duel.offers[0]), offers, "%s: the offers stay" % key)
			var shown := []
			for group in screen.start_groups():
				for slot in group.slots:
					shown.append(ids[slot])
			check_eq(shown, AnimalSort.sorted(ids, key, desc, levels), "%s %s: your starters in order" % [key, desc])
			for slot in ids.size():
				check_eq(screen._option_cards[slot].card_id, ids[slot], "%s: tapping a card picks that animal (slot %d)" % [key, slot])
			var tags := 0
			for card: Control in screen._option_cards:
				if card.get_node_or_null("SortLine/SortTag") != null:
					tags += 1
			check_eq(tags, screen.start_groups().size(), "%s: a tag for each group" % key)
			var underlined := 0
			for card: Control in screen._option_cards:
				var line := card.get_node_or_null("SortLine")
				if line != null:
					underlined += int(line.get_meta("cards"))
			check_eq(underlined, ids.size(), "%s: every card underlined in its group's color" % key)
	# Later rounds: your army row.
	duel.round_number = 2
	duel.herds[0] = [{"id": "brown_bear", "stars": 2, "squads": 1}, {"id": "lion", "stars": 1, "squads": 2},
		{"id": "gray_squirrel", "stars": 1, "squads": 1}, {"id": "unicorn", "stars": 1, "squads": 1}, {"id": "peregrine_falcon", "stars": 3, "squads": 1}]
	duel.tools[0] = ["net"]
	var herd := str(duel.herds[0])
	var herd_ids: Array = duel.herds[0].map(func(e): return String(e.id))
	screen._refresh_herd_row()
	check(screen._army_sort.visible, "the army row's sort bar shows in round 2")
	for key in AnimalSort.KEYS:
		for flip in 2:
			screen._army_sort.choose(key)
			var desc: bool = screen._army_sort.desc
			check_eq(str(duel.herds[0]), herd, "%s: your army stays as it is" % key)
			check_eq(screen.herd_row_order(), AnimalSort.sorted(herd_ids, key, desc, levels), "%s %s: your army row in order" % [key, desc])
			for i in herd_ids.size():
				check_eq(screen._herd_card(i).card_id, herd_ids[i], "%s: tapping an animal upgrades that one (%d)" % [key, i])
			var dividers: int = screen._herd_row.get_children().filter(func(c): return String(c.get_meta("key", "")).begins_with("d:")).size()
			check_eq(dividers, AnimalSort.grouped(herd_ids, key, desc, levels).size() + 1, "%s: a divider before each group and the tools" % key)
			var last: Node = screen._herd_row.get_child(screen._herd_row.get_child_count() - 1)
			check_eq(String(last.get_meta("key", "")), "t:net", "%s: the tools still at the end" % key)
