extends TestCase
## A bigger show for the rarest cards (scripts/ui/card_show.gd, feel.json
## "card_show", ui_style.json "show_*"): Common plain, Rare a soft shine,
## Epic a sweep of light, Legendary sparkles and a glowing edge, Mythic the
## full show and a moment when offered, picked or freed. Lighter in big
## grids; only cards on screen move; nothing covers a card's name or level.

const RARITIES := ["common", "rare", "epic", "legendary", "mythic"]
const BY_RARITY := {"common": "brown_bear", "rare": "lion", "epic": "tiger", "legendary": "black_rhino", "mythic": "dragon"}

var _saved: Dictionary
var _autosave := true
var _made: Array = []


func _init() -> void:
	_saved = Profile.data.duplicate(true)
	_autosave = Profile.autosave
	Profile.autosave = false
	for id in BY_RARITY.values():
		Profile.data.collection[id] = {"level": 5, "copies": 0, "new": false}


func cleanup() -> void:
	for node in _made:
		if is_instance_valid(node):
			node.free()
	_made.clear()
	Profile.data = _saved
	Profile.autosave = _autosave


func _host() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_child(tree.root.get_child_count() - 1)


func test_the_numbers_are_in_the_data() -> void:
	var show: Dictionary = GameData.feel.get("card_show", {})
	for rarity in ["rare", "epic", "legendary", "mythic"]:
		check(show.has(rarity), "feel.json card_show has %s" % rarity)
	check(show.mythic.has("moment"), "and the Mythic moment")
	check(show.has("grid_fps"), "and how often grid cards redraw")
	for key in ["show_shine", "show_sweep", "show_legendary_sparkle", "show_mythic_sparkle", "show_ray", "show_flash", "show_burst_1"]:
		check(GameData.ui_style.colors.has(key), "its color %s is in ui_style.json" % key)
	check(not FileAccess.get_file_as_string("res://data/rarities.json").contains("\"frame\""), "the Mythic frame's numbers moved out of rarities.json")


func test_the_rarer_the_bigger_the_show() -> void:
	check(not CardShow.moves("common") and not CardShow.moves("rare"), "Common and Rare cards stay still (no cost)")
	for rarity in ["epic", "legendary", "mythic"]:
		check(CardShow.moves(rarity), "%s cards move" % rarity)
	# On the cards themselves, both kinds.
	for rarity in RARITIES:
		var id: String = BY_RARITY[rarity]
		var a := AnimalCard.create(id)
		var g := GameCard.make(id, Vector2(156, 184))
		_made.append_array([a, g])
		_host().add_child(a)
		_host().add_child(g)
		check_eq(a.is_processing(), CardShow.moves(rarity), "a %s collection card %s" % [rarity, "moves" if CardShow.moves(rarity) else "is drawn once"])
		check_eq(g.is_processing(), CardShow.moves(rarity), "a %s match card %s" % [rarity, "moves" if CardShow.moves(rarity) else "is drawn once"])
	# More show the rarer: sparkles only from Legendary up, more on a Mythic,
	# rays only on a Mythic.
	var rect := Rect2(0, 0, 158, 214)
	var counts := {}
	for rarity in RARITIES:
		var most := 0
		for i in 60:
			most = maxi(most, CardShow.sparkles(rect, 150.0, rarity, i * 0.1, true).size() if rarity in ["legendary", "mythic"] else 0)
		counts[rarity] = most
	check(counts.legendary > 0, "Legendary sparkles (%d at once)" % counts.legendary)
	check(counts.mythic > counts.legendary, "Mythic more (%d)" % counts.mythic)
	check(CardShow.ray_polygons(Rect2(10, 10, 138, 130), 1.0, true).size() > 0, "Mythic light rays behind the animal")
	check(CardShow.count("mythic", "rays", true) >= 8, "plenty of them")


func test_lighter_in_big_grids() -> void:
	for key in ["sparkles"]:
		check(CardShow.count("legendary", key, false) < CardShow.count("legendary", key, true), "Legendary: fewer %s in a grid" % key)
	for key in ["sparkles", "rays"]:
		check(CardShow.count("mythic", key, false) < CardShow.count("mythic", key, true), "Mythic: fewer %s in a grid" % key)
	check(CardShow.grid_fps() <= 30.0, "grid cards redraw at most 30 times a second (%d)" % CardShow.grid_fps())
	# Grid cards are light; offers, picks, cage openings and single cards full.
	var grid_card := AnimalCard.create("dragon")
	_made.append(grid_card)
	check(not grid_card.full_show, "a collection card is light by default (Your Deck, bans, Animals tab)")
	var cage := CageOpening.new()
	cage._rays = LightRays.new()
	_made.append_array([cage, cage._rays])
	var reward := cage._card_reward({"animal": "dragon", "rarity": "mythic", "count": 1})
	_made.push_front(reward)
	var cards := reward.find_children("*", "AnimalCard", true, false)
	check(cards.size() == 1 and cards[0].full_show, "a cage opening's card gets the full show")
	var offer := GameCard.make("dragon", Vector2(156, 184))
	_made.append(offer)
	check(not offer.light, "a match's offers and picks get the full show")


func test_never_over_the_name_or_level() -> void:
	var card := AnimalCard.create("dragon")
	_made.append(card)
	var rect := Rect2(Vector2.ZERO, AnimalCard.SIZE_NORMAL)
	# The name plate's top, as the card draws it.
	var h := rect.size.y
	var margin := rect.size.x * 0.055
	var art := Rect2(margin, margin, rect.size.x - margin * 2, h * 0.66 - margin)
	var plate_top := art.end.y - h * 0.11 * 0.55
	var over := 0
	for rarity in ["legendary", "mythic"]:
		for full in [true, false]:
			for i in 400:
				for s in CardShow.sparkles(rect, plate_top, rarity, i * 0.037, full):
					if float(s[0].y) + float(s[1]) > plate_top + 0.5:
						over += 1
	check_eq(over, 0, "no sparkle ever reaches the name plate or the level below it")
	# The sweep and the rays stay inside the picture (which the name plate
	# is drawn over).
	var outside := 0
	for i in 200:
		var pieces: Array = CardShow.sweep_polygons(art, i * 0.05) + CardShow.ray_polygons(art, i * 0.05, i % 2 == 0)
		for piece in pieces:
			for p: Vector2 in piece:
				if not art.grow(0.5).has_point(p):
					outside += 1
	check_eq(outside, 0, "the sweep and the rays stay inside the picture")


func test_only_cards_on_screen_move() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 0)
	scroll.size = Vector2(400, 300)
	_made.append(scroll)
	_host().add_child(scroll)
	var content := Control.new()
	content.size = Vector2(400, 3000)
	scroll.add_child(content)
	var seen := AnimalCard.create("dragon")
	seen.position = Vector2(20, 40)
	seen.size = AnimalCard.SIZE_NORMAL
	var below := AnimalCard.create("black_rhino")
	below.position = Vector2(20, 2000)
	below.size = AnimalCard.SIZE_NORMAL
	content.add_child(seen)
	content.add_child(below)
	check(CardShow.on_screen(seen), "a card in view moves")
	check(not CardShow.on_screen(below), "a card scrolled out of view doesn't")
	seen.visible = false
	check(not CardShow.on_screen(seen), "nor does a hidden one")


func test_the_mythic_moment() -> void:
	var mythic := GameCard.make("dragon", Vector2(156, 184))
	var plain := GameCard.make("tiger", Vector2(156, 184))
	_made.append_array([mythic, plain])
	_host().add_child(mythic)
	_host().add_child(plain)
	var before: int = UIFx.particles.particles.size()
	var screen: Control = load("res://scripts/draft/draft_screen.gd").new()
	_made.append(screen)
	var lead := float(CardShow.cfg("mythic").get("moment", {}).get("delay", 0.25))
	screen._mythic_moment(mythic, -lead)
	screen._mythic_moment(plain, -lead)
	check(mythic.get_node_or_null("MythicFlash") != null, "a Mythic offered or picked flashes")
	check(plain.get_node_or_null("MythicFlash") == null, "an Epic doesn't")
	check(UIFx.particles.particles.size() > before, "and bursts (%d particles)" % (UIFx.particles.particles.size() - before))
	var off := GameCard.make("dragon", Vector2(156, 184))
	_made.append(off)
	CardShow.moment(off, 0.0)
	check(off.get_node_or_null("MythicFlash") == null, "nothing for a card that isn't on screen yet")


func test_the_card_show_page() -> void:
	# Developer tools > Card show: one card of each rarity, three ways, and
	# a button for the Mythic moment.
	var page: Control = load("res://scenes/card_show.tscn").instantiate()
	_made.append(page)
	_host().add_child(page)
	var collection := page.find_children("*", "AnimalCard", true, false)
	var match_cards := page.find_children("*", "GameCard", true, false)
	check_eq(collection.size(), 10, "five collection cards, full and light")
	check_eq(collection.filter(func(c): return c.full_show).size(), 5, "five with the full show")
	check_eq(match_cards.size(), 5, "five match cards")
	var rarities := {}
	for c in match_cards:
		rarities[GameData.cards[c.card_id].rarity] = true
	check_eq(rarities.size(), 5, "one of each rarity")
	var button: ChunkyButton = page.find_child("MythicMoment", true, false)
	check(button != null, "a Mythic moment button")
	button.pressed.emit()
	var flashes := 0
	for c in collection + match_cards:
		if c.get_node_or_null("MythicFlash") != null:
			flashes += 1
	check_eq(flashes, 2, "it flashes both Mythics (the full collection card and the match card)")
