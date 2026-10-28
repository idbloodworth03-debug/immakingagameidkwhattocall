extends Node
## All the fixed game content, loaded from the JSON files in res://data/:
## animals, arenas, cages, cosmetics and tuning numbers.
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
}

const PREREQUISITE_TYPES := [
	"allies_with_tag", "no_allies_with_tag", "deployed_count", "match_time",
	"own_tower_damaged", "allies_defeated", "unique", "zone",
]

const UNLOCK_TYPES := ["default", "ranger_level", "arena", "animal", "shop"]

var rarities: Dictionary = {}        # rarity id -> rarity info
var rarity_order: Array = []         # rarity ids, most common first
var tags: Dictionary = {}            # tag id -> display name
var animals: Dictionary = {}         # animal id -> animal info
var animal_order: Array = []         # animal ids in the order of animals.json
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

	animals.clear()
	animal_order.clear()
	for animal in _load("animals.json"):
		animal["unlock_arena_index"] = arena_index_by_id.get(animal.unlock_arena, -1)
		animals[animal.id] = animal
		animal_order.append(animal.id)

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


# --- Animals ---------------------------------------------------------------

func get_animal(id: String) -> Dictionary:
	return animals.get(id, {})


func animals_in_arena(arena_index: int) -> Array:
	return animal_order.filter(func(id): return animals[id].unlock_arena_index == arena_index)


## Animal ids that can drop from cages once the player has reached `arena_index`,
## grouped by rarity: { "common": [...], "rare": [...], ... }
func cage_pools(arena_index: int) -> Dictionary:
	var pools := {}
	for rarity in rarity_order:
		pools[rarity] = []
	for id in animal_order:
		var animal: Dictionary = animals[id]
		if animal.unlock_arena_index <= arena_index:
			pools[animal.rarity].append(id)
	return pools


func rarity_name(rarity_id: String) -> String:
	return rarities.get(rarity_id, {}).get("name", rarity_id)


func rarity_color(rarity_id: String) -> Color:
	return Color(rarities.get(rarity_id, {}).get("color", "#ffffff"))


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
func validate() -> Array:
	var problems := []
	var deck_size := int(progression.get("deck_size", 8))

	if animals_in_arena(0).size() < deck_size:
		problems.append("The first arena must unlock at least %d animals for the starting deck" % deck_size)

	for id in animal_order:
		var a: Dictionary = animals[id]
		for field in ["name", "rarity", "status", "cost", "count", "tags", "stats", "ability", "prerequisites"]:
			if not a.has(field):
				problems.append("%s: missing '%s'" % [id, field])
		if not rarities.has(a.get("rarity", "")):
			problems.append("%s: unknown rarity '%s'" % [id, a.get("rarity")])
		if a.unlock_arena_index < 0:
			problems.append("%s: unknown arena '%s'" % [id, a.get("unlock_arena")])
		if not STATUS_NAMES.has(a.get("status", "")):
			problems.append("%s: unknown conservation status '%s'" % [id, a.get("status")])
		for tag in a.get("tags", []):
			if not tags.has(tag):
				problems.append("%s: unknown tag '%s' (add it to tags.json)" % [id, tag])
		for req in a.get("prerequisites", []):
			if not PREREQUISITE_TYPES.has(req.get("type", "")):
				problems.append("%s: unknown prerequisite type '%s'" % [id, req.get("type")])
			if req.has("tag") and not tags.has(req.tag):
				problems.append("%s: prerequisite uses unknown tag '%s'" % [id, req.tag])

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

	for cage_id in progression.get("win_cage_cycle", []):
		if not cages.has(cage_id):
			problems.append("win_cage_cycle: unknown cage '%s'" % cage_id)

	for list_name in ["emotes", "banners", "player_icons"]:
		var list: Array = get(list_name)
		for item in list:
			var unlock: Dictionary = item.get("unlock", {})
			var kind: String = unlock.get("type", "")
			if not UNLOCK_TYPES.has(kind):
				problems.append("%s %s: unknown unlock type '%s'" % [list_name, item.id, kind])
			elif kind == "arena" and not arena_index_by_id.has(unlock.get("arena", "")):
				problems.append("%s %s: unknown arena '%s'" % [list_name, item.id, unlock.get("arena")])
			elif kind == "animal" and not animals.has(unlock.get("animal", "")):
				problems.append("%s %s: unknown animal '%s'" % [list_name, item.id, unlock.get("animal")])

	return problems
