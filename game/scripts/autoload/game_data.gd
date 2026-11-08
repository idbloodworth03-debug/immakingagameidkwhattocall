extends Node
## All the fixed game content, loaded from the JSON files in res://data/:
## cards (animals and Ranger tools), arenas, cages, cosmetics and tuning numbers.
##
## Nothing here changes while you play. To add an animal or rebalance a cage,
## edit the JSON file, not this script. The game server will read the same
## files later, so the phone and the server always agree on the rules.

const DATA_DIR := "res://data/"

## IUCN Red List categories. A rarer card means a rarer animal in real life.
const STATUS_NAMES := {
	"LC": "Least Concern",
	"NT": "Near Threatened",
	"VU": "Vulnerable",
	"EN": "Endangered",
	"CR": "Critically Endangered",
	# Never assessed (no snapping shrimp has been): shown as Common.
	"NE": "Not Evaluated",
}

const UNLOCK_TYPES := ["default", "ranger_level", "arena", "animal", "shop"]

var rarities: Dictionary = {}        # rarity id -> rarity info
var rarity_order: Array = []         # rarity ids, most common first
var tags: Dictionary = {}            # tag id -> display name
var cards: Dictionary = {}           # card id -> card info (animals and tools)
var card_order: Array = []           # animals.json order, then tools.json
var arenas: Array = []               # arena infos, lowest trophies first
var arena_index_by_id: Dictionary = {}
var cages: Dictionary = {}           # cage id -> cage info
var cage_order: Array = []
var emotes: Array = []
var quick_chats: Array = []
var banners: Array = []
var player_icons: Array = []
var progression: Dictionary = {}
var battle_rules: Dictionary = {}
var draft_rules: Dictionary = {}     # Draft Duel tuning
var feel: Dictionary = {}            # animation, effects and juice (feel.json)
var bodies: Dictionary = {}          # how big each animal is drawn in battle, and the limits (bodies.json)
var shots: Dictionary = {}           # how Ranged animals' shots look (shots.json)
var styles: Dictionary = {}          # each animal's attack style (styles.json)
var viewer: Dictionary = {}          # the 3D animal viewer (viewer.json)
var journal: Dictionary = {}         # Ranger Journal entries by animal id (journal.json)
var testing: Dictionary = {}         # testing switches (testing.json)
var habitats: Dictionary = {}        # habitat id -> name, icon, color (habitats.json; flavor)
var habitat_order: Array = []        # habitat ids, in habitats.json order
var classes: Dictionary = {}         # class id -> its info (classes.json)
var class_order: Array = []          # class ids, in classes.json order
var traits: Dictionary = {}          # Specialist trait id -> its info
var class_rules: Dictionary = {}     # the rest of classes.json: counters, rows, ...
var rival_rules: Dictionary = {}     # rivals.json settings (bosses, easing, reward)
var rivals: Array = []               # Rival Rangers, in rivals.json order
var ui_style: Dictionary = {}        # the design system (ui_style.json, see UIStyle)
var art: Dictionary = {}
var sorting: Dictionary = {}       # how animals sort (sorting.json)


func _init() -> void:
	reload()


func reload() -> void:
	rarities.clear()
	rarity_order.clear()
	for rarity in _load("rarities.json"):
		rarities[rarity.id] = rarity
		rarity_order.append(rarity.id)

	tags = _load("tags.json")

	arenas = _load("arenas.json")
	arenas.sort_custom(func(a, b): return a.min_trophies < b.min_trophies)
	arena_index_by_id.clear()
	for i in arenas.size():
		arena_index_by_id[arenas[i].id] = i

	cards.clear()
	card_order.clear()
	for file_name in ["animals.json", "tools.json"]:
		for card in _load(file_name):
			if not card.has("kind"):
				card["kind"] = "animal"
			card["unlock_arena_index"] = arena_index_by_id.get(card.unlock_arena, -1)
			cards[card.id] = card
			card_order.append(card.id)

	cages.clear()
	cage_order.clear()
	for cage in _load("cages.json"):
		cages[cage.id] = cage
		cage_order.append(cage.id)

	emotes = _load("emotes.json")
	quick_chats = _load("quick_chats.json")
	banners = _load("banners.json")
	player_icons = _load("player_icons.json")
	progression = _load("progression.json")
	battle_rules = _load("battle_rules.json")
	draft_rules = _load("draft_rules.json")
	feel = _load("feel.json")
	bodies = _load("bodies.json")
	shots = _load("shots.json")
	styles = _load("styles.json")
	viewer = _load("viewer.json")
	journal = _load("journal.json").get("entries", {})
	testing = _load("testing.json")
	var habitat_data: Dictionary = _load("habitats.json")
	habitats.clear()
	habitat_order.clear()
	for habitat in habitat_data.get("habitats", []):
		habitats[habitat.id] = habitat
		habitat_order.append(habitat.id)
	class_rules = _load("classes.json")
	classes.clear()
	class_order.clear()
	traits.clear()
	for info in class_rules.get("classes", []):
		classes[info.id] = info
		class_order.append(info.id)
	for info in class_rules.get("traits", []):
		traits[info.id] = info
	rival_rules = _load("rivals.json")
	rivals = rival_rules.get("rivals", [])
	ui_style = _load("ui_style.json")
	art = _load("art.json")
	sorting = _load("sorting.json")
	_paint()


## Every color lives in ui_style.json: rarities, classes and habitats get
## theirs from there ("rarity_*", "class_*", "habitat_*"), as their "color".
func _paint() -> void:
	UIStyle.forget_colors()
	var colors: Dictionary = ui_style.get("colors", {})
	for group in [["rarity_", rarities], ["class_", classes], ["habitat_", habitats]]:
		var table: Dictionary = group[1]
		for id in table:
			table[id]["color"] = String(colors.get(String(group[0]) + String(id), "#ff00ff"))


func _load(file_name: String) -> Variant:
	var path := DATA_DIR + file_name
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("GameData: could not read %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_error("GameData: %s is not valid JSON" % path)
		return {}
	return parsed


# --- Cards -----------------------------------------------------------------

func get_card(id: String) -> Dictionary:
	return cards.get(id, {})


func is_tool(id: String) -> bool:
	return cards.get(id, {}).get("kind", "") == "tool"


func cards_in_arena(arena_index: int) -> Array:
	return card_order.filter(func(id): return cards[id].unlock_arena_index == arena_index)


## Card ids that can drop from cages once the player has reached `arena_index`,
## grouped by rarity: { "common": [...], "rare": [...], ... }
func cage_pools(arena_index: int) -> Dictionary:
	var pools := {}
	for rarity in rarity_order:
		pools[rarity] = []
	for id in card_order:
		var card: Dictionary = cards[id]
		if card.unlock_arena_index <= arena_index:
			pools[card.rarity].append(id)
	return pools


func rarity_name(rarity_id: String) -> String:
	return rarities.get(rarity_id, {}).get("name", rarity_id)


func rarity_color(rarity_id: String) -> Color:
	return UIStyle.rarity_color(rarity_id)


func start_level(rarity_id: String) -> int:
	return int(rarities.get(rarity_id, {}).get("start_level", 1))


func status_name(code: String) -> String:
	return STATUS_NAMES.get(code, code)


## "Canine", or "Canines" when `count` is more than one.
func tag_name(tag: String, count := 1) -> String:
	var label: String = tags.get(tag, tag.capitalize())
	return label + ("s" if count != 1 else "")


# --- Arenas ----------------------------------------------------------------

func arena_index_for_trophies(trophies: int) -> int:
	return TrophyRules.arena_index_for(trophies, arenas)


func get_arena(index: int) -> Dictionary:
	return arenas[clampi(index, 0, arenas.size() - 1)]


# --- Classes -----------------------------------------------------------------

## 0 for the commonest rarity, then 1, 2...
func rarity_rank(rarity: String) -> int:
	return maxi(0, rarity_order.find(rarity))


## An animal's class ("tank", "tank_destroyer", "ranged", "air" or
## "specialist"); "" for a tool.
func class_of(card_id: String) -> String:
	return String(cards.get(card_id, {}).get("class", ""))


## A Specialist's trait ("burrow", "splash", "stun" or "slow"), or "".
func trait_of(card_id: String) -> String:
	return String(cards.get(card_id, {}).get("trait", ""))


## The one line about an animal's attack style its card shows when held
## (styles.json), or "".
func style_line(id: String) -> String:
	return String(styles.get(id, {}).get("line", ""))


func class_info(class_id: String) -> Dictionary:
	return classes.get(class_id, {})


## The one short line about a card (shown when you hold it).
## The one line a card shows when you hold it: a tool's effect, an animal's
## attack style (styles.json), or else its trait's or class's line.
func card_line(card_id: String) -> String:
	if is_tool(card_id):
		return String(cards[card_id].get("ability", {}).get("short", cards[card_id].get("ability", {}).get("text", "")))
	if style_line(card_id) != "":
		return style_line(card_id)
	var trait_id := trait_of(card_id)
	if trait_id != "":
		return String(traits.get(trait_id, {}).get("line", ""))
	return String(class_info(class_of(card_id)).get("line", ""))


# --- Rival Rangers ----------------------------------------------------------

## The rivals of one arena; bosses only, or only the regulars.
func rivals_in_arena(index: int, boss: bool) -> Array:
	var arena_id: String = get_arena(index).id
	return rivals.filter(func(r): return r.arena == arena_id and bool(r.get("boss", false)) == boss)


func rival(id: String) -> Dictionary:
	return find_by_id(rivals, id)


# --- Art -------------------------------------------------------------------
# Icon names refer to files in res://art/icons/ (see data/art.json).

func card_icon(card_id: String) -> String:
	return _icon_name(art.get("cards", {}).get(card_id, ""))


func card_icon_flipped(card_id: String) -> bool:
	return art.get("flipped", []).has(card_id)


func emote_icon(emote_id: String) -> String:
	return _icon_name(art.get("emotes", {}).get(emote_id, ""))


func player_icon(icon_id: String) -> String:
	return _icon_name(art.get("player_icons", {}).get(icon_id, ""))


func arena_icons(arena_id: String) -> Array:
	return art.get("arenas", {}).get(arena_id, []).map(func(ref): return _icon_name(ref))


func ui_icon(key: String) -> String:
	return _icon_name(art.get("ui", {}).get(key, ""))


## "author/name" -> "name"
func _icon_name(ref: String) -> String:
	return ref.get_file()


# --- Cosmetics -------------------------------------------------------------

func find_by_id(list: Array, id: String) -> Dictionary:
	for item in list:
		if item.id == id:
			return item
	return {}


# --- Self-check ------------------------------------------------------------

## Looks for mistakes in the JSON files (typos in ids, missing fields...).
## Returns a list of problems; an empty list means everything looks right.
## The tests run this, so a broken data file is caught before it ships.
## Animals on the way (data/animals_later.json), by id: a legend can link to
## one before it's in the game.
func _later_ids() -> Dictionary:
	var ids := {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals_later.json"))
	if parsed is Array:
		for card in parsed:
			ids[String(card.get("id", ""))] = true
	return ids


func validate() -> Array:
	var problems := []

	# Every rarity, class and habitat has its color in ui_style.json.
	var colors: Dictionary = ui_style.get("colors", {})
	for group in [["rarity_", rarity_order], ["class_", class_order], ["habitat_", habitat_order]]:
		for id in group[1]:
			if not colors.has(String(group[0]) + String(id)):
				problems.append("ui_style.json: no color %s%s" % [group[0], id])

	# New players own the starting cards, and draft from them: enough to fill
	# the options, with enough animals for the first round's picks.
	var starters: Array = progression.get("starting_cards", [])
	for id in starters:
		if not cards.has(id):
			problems.append("Starting card %s doesn't exist" % id)
	var starter_animals := starters.filter(func(id): return cards.has(id) and not is_tool(id)).size()
	if starter_animals < int(draft_rules.get("deck_size", 8)):
		problems.append("There must be at least %d starting animals: a new player's first deck" % int(draft_rules.get("deck_size", 8)))
	if starters.size() - starter_animals < int(draft_rules.get("offer_tools", 2)):
		problems.append("There must be at least %d starting tools to fill the Draft Duel tool options" % int(draft_rules.get("offer_tools", 2)))
	if starter_animals < int(draft_rules.get("offer_animals", 4)):
		problems.append("There must be at least %d starting animals to fill the Draft Duel animal options" % int(draft_rules.get("offer_animals", 4)))
	var bans: Dictionary = draft_rules.get("bans", {})
	if int(bans.get("unlock_owned", 11)) < int(draft_rules.get("deck_size", 8)) + int(bans.get("per_player", 3)):
		problems.append("Bans must unlock at a deck plus the rival's bans at least, so a deck can always be filled")
	if starter_animals < int(draft_rules.get("picks_per_round", 3)):
		problems.append("At least %d starting cards must be animals" % int(draft_rules.get("picks_per_round", 3)))
	var starter_classes := {}
	for id in starters:
		if cards.has(id) and not is_tool(id):
			starter_classes[class_of(id)] = true
	if starter_classes.size() < mini(starter_animals, 3):
		problems.append("The starting animals should be from different classes")

	for id in card_order:
		var a: Dictionary = cards[id]
		for field in ["name", "rarity", "cost", "tags", "stats"]:
			if not a.has(field):
				problems.append("%s: missing '%s'" % [id, field])
		if not ["animal", "tool"].has(a.kind):
			problems.append("%s: kind must be 'animal' or 'tool'" % id)
		if not rarities.has(a.get("rarity", "")):
			problems.append("%s: unknown rarity '%s'" % [id, a.get("rarity")])
		if a.unlock_arena_index < 0:
			problems.append("%s: unknown arena '%s'" % [id, a.get("unlock_arena")])
		if a.kind == "animal" and a.rarity != "mythic" and not STATUS_NAMES.has(a.get("status", "")):
			problems.append("%s: unknown conservation status '%s'" % [id, a.get("status")])
		if a.kind == "animal" and not habitats.has(a.get("habitat", "")):
			problems.append("%s: unknown habitat '%s' (see habitats.json)" % [id, a.get("habitat")])
		if a.kind == "animal" and not classes.has(a.get("class", "")):
			problems.append("%s: unknown class '%s' (see classes.json)" % [id, a.get("class")])
		if a.kind == "animal" and (a.get("class", "") == "specialist") != traits.has(a.get("trait", "")):
			problems.append("%s: Specialists (and only they) need a known trait" % id)
		if a.kind == "animal" and not ["ground", "air_ground"].has(a.get("stats", {}).get("targets", "")):
			problems.append("%s: targets must be 'ground' or 'air_ground'" % id)
		if a.kind == "tool" and not ToolEffects.KNOWN.has(a.get("ability", {}).get("id", "")):
			problems.append("%s: the battle engine doesn't know tool effect '%s'" % [id, a.get("ability", {}).get("id")])
		if a.kind == "animal" and a.rarity == "mythic" and a.get("legend", "") == "":
			problems.append("%s: a Mythic needs its legend line (the real story behind it)" % id)
		if a.has("legend_card") and not cards.has(String(a.legend_card)) and not _later_ids().has(String(a.legend_card)):
			problems.append("%s: its legend links to unknown card '%s'" % [id, a.legend_card])
		for tag in a.get("tags", []):
			if not tags.has(tag):
				problems.append("%s: unknown tag '%s' (add it to tags.json)" % [id, tag])
		if a.has("shot") and not shots.has(String(a.shot)):
			problems.append("%s: unknown shot '%s' (see shots.json)" % [id, a.shot])
		if styles.has(id):
			var style: Dictionary = styles[id]
			if not BattleStyles.KINDS.has(String(style.get("kind", ""))):
				problems.append("%s: unknown attack style '%s' (see styles.json)" % [id, style.get("kind", "")])
			if String(style.get("line", "")).split(" ", false).size() > 8:
				problems.append("%s: its style line must be 8 words or fewer" % id)

	for cage_id in cage_order:
		var cage: Dictionary = cages[cage_id]
		var total_weight := 0.0
		for rarity in cage.weights:
			if not rarities.has(rarity):
				problems.append("cage %s: unknown rarity '%s'" % [cage_id, rarity])
			total_weight += float(cage.weights[rarity])
		if total_weight <= 0.0:
			problems.append("cage %s: weights add up to zero" % cage_id)
		if cage.has("shop_requires_arena") and not arena_index_by_id.has(cage.shop_requires_arena):
			problems.append("cage %s: unknown arena '%s'" % [cage_id, cage.shop_requires_arena])

	if not shots.has(ShotLooks.DEFAULT):
		problems.append("shots.json needs a '%s' look (for animals without a shot of their own)" % ShotLooks.DEFAULT)
	for rarity in draft_rules.get("rarity_weights", {}):
		if not rarities.has(rarity):
			problems.append("draft_rules: unknown rarity '%s'" % rarity)
	for habitat_id in habitat_order:
		if not art.get("ui", {}).has(habitats[habitat_id].get("icon", "")):
			problems.append("habitats: %s's icon '%s' isn't in art.json" % [habitat_id, habitats[habitat_id].get("icon")])
	for info in classes.values() + traits.values():
		if not art.get("ui", {}).has(info.get("icon", "")):
			problems.append("classes: %s's icon '%s' isn't in art.json" % [info.id, info.get("icon")])
	if int(draft_rules.get("wins_needed", 0)) <= 0 or int(draft_rules.get("max_rounds", 0)) < int(draft_rules.get("wins_needed", 0)) * 2 - 1:
		problems.append("draft_rules: wins_needed must be above zero and max_rounds at least 2 x wins_needed - 1")

	const LOOKS := {
		"hair_style": ["short", "spiky", "long", "ponytail", "bun", "curly", "bald"],
		"hat": ["none", "cap", "beanie", "bandana", "safari", "ranger", "crown"],
		"eyes": ["happy", "sly", "determined", "sleepy", "wide"],
		"mouth": ["grin", "smile", "smirk", "open", "flat"],
		"extra": ["none", "glasses", "freckles", "mustache", "scarf"],
	}
	var banner_ids := _ids(banners)
	var emote_ids := _ids(emotes)
	for i in arenas.size():
		if rivals_in_arena(i, false).is_empty() or rivals_in_arena(i, true).size() != 1:
			problems.append("rivals: arena '%s' needs regulars and exactly one boss" % arenas[i].id)
	for r in rivals:
		if not arena_index_by_id.has(r.get("arena", "")):
			problems.append("rival %s: unknown arena '%s'" % [r.id, r.get("arena")])
		if not banner_ids.has(r.get("banner", "")):
			problems.append("rival %s: unknown banner '%s'" % [r.id, r.get("banner")])
		for moment in ["start", "big_hit", "winning", "losing"]:
			if not emote_ids.has(r.get("emotes", {}).get(moment, "")):
				problems.append("rival %s: unknown %s emote '%s'" % [r.id, moment, r.get("emotes", {}).get(moment)])
		var favorite: String = r.get("style", {}).get("favorite", "")
		if favorite != "" and not classes.has(favorite):
			problems.append("rival %s: unknown favorite class '%s'" % [r.id, favorite])
		for part in LOOKS:
			if not LOOKS[part].has(r.get("look", {}).get(part, "")):
				problems.append("rival %s: look.%s must be one of %s" % [r.id, part, ", ".join(LOOKS[part])])
	var reward_cage: String = rival_rules.get("boss_reward", {}).get("cage", "")
	if reward_cage != "" and not cages.has(reward_cage):
		problems.append("rivals: unknown boss reward cage '%s'" % reward_cage)

	for cage_id in progression.get("win_cage_cycle", []):
		if not cages.has(cage_id):
			problems.append("win_cage_cycle: unknown cage '%s'" % cage_id)

	for section in ["cards", "emotes", "player_icons"]:
		var source: Dictionary = {"cards": cards, "emotes": _ids(emotes), "player_icons": _ids(player_icons)}[section]
		for id in source:
			var icon_name: String = _icon_name(art.get(section, {}).get(id, ""))
			if icon_name == "" or not ResourceLoader.exists("res://art/icons/%s.svg" % icon_name):
				problems.append("art.json: %s '%s' has no icon file" % [section, id])
	for arena in arenas:
		if arena_icons(arena.id).is_empty():
			problems.append("art.json: arena '%s' has no icons" % arena.id)

	for list_name in ["emotes", "banners", "player_icons"]:
		var list: Array = get(list_name)
		for item in list:
			var unlock: Dictionary = item.get("unlock", {})
			var kind: String = unlock.get("type", "")
			if not UNLOCK_TYPES.has(kind):
				problems.append("%s %s: unknown unlock type '%s'" % [list_name, item.id, kind])
			elif kind == "arena" and not arena_index_by_id.has(unlock.get("arena", "")):
				problems.append("%s %s: unknown arena '%s'" % [list_name, item.id, unlock.get("arena")])
			elif kind == "animal" and not cards.has(unlock.get("animal", "")):
				problems.append("%s %s: unknown animal '%s'" % [list_name, item.id, unlock.get("animal")])

	return problems


func _ids(list: Array) -> Dictionary:
	var ids := {}
	for item in list:
		ids[item.id] = true
	return ids
