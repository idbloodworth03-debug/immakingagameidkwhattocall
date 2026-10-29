extends Node
## The player's own progress: currencies, trophies, animal collection, deck,
## cages and cosmetics.
##
## For now this is saved on the device (user://profile.json) so the game can
## be built and tested offline. Once online play is added, the server becomes
## the boss: it decides cage contents, trophies and purchases (so nobody can
## cheat by editing a save file), and this script turns into a local copy of
## what the server says.

## Emitted after anything in the profile changes, so screens can refresh.
signal changed

const SAVE_VERSION := 1

var save_path := "user://profile.json"
## Tests turn this off so they never touch the real save file.
var autosave := true
## Seconds added to the real clock. Tests use it to fast-forward cage timers.
var time_offset := 0.0
## Result of the last battle, shown when we get back to the menu. Not saved.
var pending_match_result: Dictionary = {}

var data: Dictionary = {}


func _ready() -> void:
	load_or_create()


func now() -> float:
	return Time.get_unix_time_from_system() + time_offset


# --- Saving and loading ----------------------------------------------------

func load_or_create() -> void:
	if FileAccess.file_exists(save_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if parsed is Dictionary:
			data = parsed
			_repair()
			return
		push_warning("Profile: save file was unreadable, starting a new profile")
	reset()


func save() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Profile: could not save (%s)" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))


func reset() -> void:
	data = _new_profile()
	_changed()


func _new_profile() -> Dictionary:
	var prog := GameData.progression
	var profile := {
		"version": SAVE_VERSION,
		"player_id": "%08x%08x" % [randi(), randi()],
		"name": "Ranger%04d" % randi_range(0, 9999),
		"xp": 0,
		"gold": int(prog.starting_gold),
		"gems": int(prog.starting_gems),
		"trophies": 0,
		"best_trophies": 0,
		"highest_arena": 0,
		"wins": 0,
		"losses": 0,
		"draws": 0,
		"collection": {},
		"deck": [],
		"cage_slots": [],
		"cage_cycle_index": 0,
		"banner": _first_default(GameData.banners),
		"icon": _first_default(GameData.player_icons),
		"owned_cosmetics": [],
		"shop_day": "",
		"shop_bought": [],
	}
	for i in int(prog.cage_slots):
		profile.cage_slots.append(null)
	# Starter cards: everything from the first arena. The deck comes from
	# "starter_deck" in progression.json.
	for id in GameData.cards_in_arena(0):
		profile.collection[id] = {"level": GameData.start_level(GameData.cards[id].rarity), "copies": 0, "new": false}
	profile.deck = prog.starter_deck.duplicate()
	# A first cage so new players can try freeing animals right away.
	profile.cage_slots[0] = {"cage_id": "twig", "arena": 0, "unlock_at": 0.0}
	return profile


## Fixes up an older or edited save: fills in fields added since it was made
## and drops animals or cosmetics that no longer exist in the game data.
func _repair() -> void:
	var fresh := _new_profile()
	for key in fresh:
		if not data.has(key):
			data[key] = fresh[key]
	data.version = SAVE_VERSION

	for id in data.collection.keys():
		if not GameData.cards.has(id):
			data.collection.erase(id)
	# Starter cards added in an update are free for everyone.
	for id in GameData.cards_in_arena(0):
		if not data.collection.has(id):
			data.collection[id] = {"level": GameData.start_level(GameData.cards[id].rarity), "copies": 0, "new": true}

	var deck: Array = data.deck.filter(func(id): return data.collection.has(id))
	for id in GameData.card_order:
		if deck.size() >= int(GameData.progression.deck_size):
			break
		if data.collection.has(id) and not deck.has(id):
			deck.append(id)
	data.deck = deck

	var slot_count := int(GameData.progression.cage_slots)
	while data.cage_slots.size() < slot_count:
		data.cage_slots.append(null)
	data.cage_slots.resize(slot_count)
	for i in slot_count:
		var slot: Variant = data.cage_slots[i]
		if slot != null and not GameData.cages.has(slot.get("cage_id", "")):
			data.cage_slots[i] = null

	if GameData.find_by_id(GameData.banners, data.banner).is_empty():
		data.banner = fresh.banner
	if GameData.find_by_id(GameData.player_icons, data.icon).is_empty():
		data.icon = fresh.icon


func _first_default(items: Array) -> String:
	for item in items:
		if item.get("unlock", {}).get("type", "") == "default":
			return item.id
	return items[0].id if not items.is_empty() else ""


func _changed() -> void:
	if autosave:
		save()
	changed.emit()


# --- Basic info ------------------------------------------------------------

func get_player_name() -> String:
	return data.name


func set_player_name(new_name: String) -> void:
	new_name = new_name.strip_edges().left(16)
	if new_name.is_empty():
		return
	data.name = new_name
	_changed()


func get_gold() -> int:
	return int(data.gold)


func get_gems() -> int:
	return int(data.gems)


func get_trophies() -> int:
	return int(data.trophies)


func arena_index() -> int:
	return GameData.arena_index_for_trophies(get_trophies())


func highest_arena() -> int:
	return int(data.highest_arena)


func add_gold(amount: int) -> void:
	data.gold = get_gold() + amount
	_changed()


func add_gems(amount: int) -> void:
	data.gems = get_gems() + amount
	_changed()


func spend_gold(amount: int) -> bool:
	if amount < 0 or get_gold() < amount:
		return false
	data.gold = get_gold() - amount
	_changed()
	return true


func spend_gems(amount: int) -> bool:
	if amount < 0 or get_gems() < amount:
		return false
	data.gems = get_gems() - amount
	_changed()
	return true


# --- Ranger level ----------------------------------------------------------

## { level, xp, xp_needed } for the account level.
func ranger_info() -> Dictionary:
	var prog := GameData.progression
	return AccountRules.level_info(int(data.xp), prog.ranger_xp_to_next_level, int(prog.ranger_max_level))


func add_xp(amount: int) -> void:
	data.xp = int(data.xp) + amount
	_changed()


# --- Animal collection -----------------------------------------------------

func has_card(id: String) -> bool:
	return data.collection.has(id)


func card_level(id: String) -> int:
	if has_card(id):
		return int(data.collection[id].level)
	return GameData.start_level(GameData.get_card(id).get("rarity", "common"))


func card_copies(id: String) -> int:
	return int(data.collection[id].copies) if has_card(id) else 0


func is_card_new(id: String) -> bool:
	return has_card(id) and data.collection[id].get("new", false)


func mark_card_seen(id: String) -> void:
	if is_card_new(id):
		data.collection[id].new = false
		_changed()


func found_count() -> int:
	return data.collection.size()


## { copies, gold } needed for the next level, or an empty dictionary at max level.
func upgrade_cost(id: String) -> Dictionary:
	var prog := GameData.progression
	var level := card_level(id)
	if CardRules.is_max_level(level, prog):
		return {}
	return {
		"copies": CardRules.copies_to_upgrade(GameData.cards[id].rarity, level, prog),
		"gold": CardRules.gold_to_upgrade(level, prog),
	}


func can_upgrade(id: String) -> bool:
	return has_card(id) and CardRules.can_upgrade(GameData.cards[id].rarity, card_level(id), card_copies(id), get_gold(), GameData.progression)


## True when the card has enough copies to upgrade, even if gold is short.
func has_copies_for_upgrade(id: String) -> bool:
	return has_card(id) and CardRules.has_copies_for_upgrade(GameData.cards[id].rarity, card_level(id), card_copies(id), GameData.progression)


func upgrade_card(id: String) -> bool:
	if not can_upgrade(id):
		return false
	var cost := upgrade_cost(id)
	var level := card_level(id)
	data.gold = get_gold() - int(cost.gold)
	data.collection[id].copies = card_copies(id) - int(cost.copies)
	data.collection[id].level = level + 1
	data.xp = int(data.xp) + CardRules.xp_for_upgrade(level, GameData.progression)
	_changed()
	return true


## Adds copies of an animal. Returns true if this was the first copy.
## The first copy unlocks the card; only extra copies count toward upgrades.
func _add_cards(id: String, count: int) -> bool:
	if has_card(id):
		data.collection[id].copies = card_copies(id) + count
		return false
	data.collection[id] = {
		"level": GameData.start_level(GameData.cards[id].rarity),
		"copies": count - 1,
		"new": true,
	}
	return true


# --- Deck ------------------------------------------------------------------

func get_deck() -> Array:
	return data.deck.duplicate()


## Puts an animal into a deck slot. If it was already in another slot, the
## two cards swap places.
func set_deck_slot(slot: int, id: String) -> void:
	if not has_card(id) or slot < 0 or slot >= data.deck.size():
		return
	var deck: Array = data.deck
	var current_slot := deck.find(id)
	if current_slot == slot:
		return
	if current_slot >= 0:
		deck[current_slot] = deck[slot]
	deck[slot] = id
	_changed()


func average_deck_cost() -> float:
	var deck := get_deck()
	if deck.is_empty():
		return 0.0
	var total := 0.0
	for id in deck:
		total += float(GameData.cards[id].cost)
	return total / deck.size()


# --- Battles ---------------------------------------------------------------

## Updates trophies, stats and rewards after a battle. `outcome` is "win",
## "loss" or "draw" (draws change no trophies and give no cage).
## Returns a summary for the results screen.
func record_match(outcome: String, opponent_trophies: int) -> Dictionary:
	var prog := GameData.progression
	var won := outcome == "win"
	var before := get_trophies()
	var highest_before := highest_arena()
	var after := before
	if outcome != "draw":
		after = TrophyRules.trophies_after_match(before, opponent_trophies, won, prog.trophies, GameData.arenas)

	data.trophies = after
	data.best_trophies = maxi(int(data.best_trophies), after)
	data.highest_arena = maxi(highest_before, arena_index())
	match outcome:
		"win":
			data.wins = int(data.wins) + 1
		"loss":
			data.losses = int(data.losses) + 1
		_:
			data.draws = int(data.get("draws", 0)) + 1
	data.xp = int(data.xp) + int(prog.xp_per_win if won else prog.xp_per_loss)

	var cage_id := _award_win_cage() if won else ""
	_changed()
	return {
		"outcome": outcome,
		"won": won,
		"trophy_change": after - before,
		"trophies": after,
		"arena_index": arena_index(),
		"new_arena": highest_arena() > highest_before,
		"cage_id": cage_id,
		"slots_full": won and cage_id == "",
	}


func _award_win_cage() -> String:
	var slot: int = data.cage_slots.find(null)
	if slot == -1:
		return ""
	var cycle: Array = GameData.progression.win_cage_cycle
	var cage_id: String = cycle[int(data.cage_cycle_index) % cycle.size()]
	data.cage_cycle_index = int(data.cage_cycle_index) + 1
	data.cage_slots[slot] = {"cage_id": cage_id, "arena": arena_index(), "unlock_at": 0.0}
	return cage_id


# --- Cages -----------------------------------------------------------------
# A won cage sits in one of the slots. Only one cage can unlock at a time.
# "unlock_at" is 0 until unlocking starts, then the time it will be ready.

func cage_slot(slot: int) -> Variant:
	return data.cage_slots[slot]


## "empty", "locked" (waiting to start), "unlocking" or "ready".
func cage_slot_state(slot: int) -> String:
	var entry: Variant = data.cage_slots[slot]
	if entry == null:
		return "empty"
	var unlock_at := float(entry.unlock_at)
	if unlock_at <= 0.0:
		return "locked"
	return "unlocking" if now() < unlock_at else "ready"


func cage_seconds_left(slot: int) -> float:
	match cage_slot_state(slot):
		"locked":
			return float(GameData.cages[data.cage_slots[slot].cage_id].unlock_seconds)
		"unlocking":
			return float(data.cage_slots[slot].unlock_at) - now()
	return 0.0


func is_any_cage_unlocking() -> bool:
	for i in data.cage_slots.size():
		if cage_slot_state(i) == "unlocking":
			return true
	return false


func start_cage_unlock(slot: int) -> bool:
	if cage_slot_state(slot) != "locked" or is_any_cage_unlocking():
		return false
	var cage: Dictionary = GameData.cages[data.cage_slots[slot].cage_id]
	data.cage_slots[slot].unlock_at = now() + float(cage.unlock_seconds)
	_changed()
	return true


func cage_skip_cost(slot: int) -> int:
	if cage_slot_state(slot) in ["empty", "ready"]:
		return 0
	return CageRules.skip_cost_gems(cage_seconds_left(slot), GameData.cages[data.cage_slots[slot].cage_id])


## Spends gems to finish unlocking now.
func skip_cage_unlock(slot: int) -> bool:
	var cost := cage_skip_cost(slot)
	if cost <= 0 or not spend_gems(cost):
		return false
	data.cage_slots[slot].unlock_at = now()
	_changed()
	return true


## Opens a ready cage and gives its rewards. Returns the rewards.
func open_cage_slot(slot: int) -> Dictionary:
	if cage_slot_state(slot) != "ready":
		return {}
	var entry: Dictionary = data.cage_slots[slot]
	data.cage_slots[slot] = null
	return _open_cage(entry.cage_id, int(entry.arena))


func can_buy_cage(cage_id: String) -> bool:
	var cage: Dictionary = GameData.cages.get(cage_id, {})
	if int(cage.get("shop_gems", 0)) <= 0:
		return false
	if cage.has("shop_requires_arena"):
		return highest_arena() >= int(GameData.arena_index_by_id[cage.shop_requires_arena])
	return true


## Buys a cage from the shop with gems and opens it right away.
func buy_cage(cage_id: String) -> Dictionary:
	if not can_buy_cage(cage_id) or not spend_gems(int(GameData.cages[cage_id].shop_gems)):
		return {}
	return _open_cage(cage_id, arena_index())


func _open_cage(cage_id: String, arena: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var rewards := CageRules.roll(GameData.cages[cage_id], arena, GameData.cage_pools(arena), GameData.rarity_order, rng)
	grant_rewards(rewards)
	return rewards


## Adds gold, gems and animals. Each card stack gets "is_new" set so the
## opening screen can show a NEW! badge.
func grant_rewards(rewards: Dictionary) -> void:
	data.gold = get_gold() + int(rewards.get("gold", 0))
	data.gems = get_gems() + int(rewards.get("gems", 0))
	for stack in rewards.get("cards", []):
		stack["is_new"] = _add_cards(stack.animal, int(stack.count))
	_changed()


# --- Daily shop ------------------------------------------------------------

func _today() -> String:
	return Time.get_date_string_from_unix_time(int(now()))


## Three single-animal offers that change every day (UTC). Only animals the
## player already owns are offered, so nothing here can be a surprise.
func daily_offers() -> Array:
	var today := _today()
	if data.shop_day != today:
		data.shop_day = today
		data.shop_bought = []
	var prog := GameData.progression
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(today + String(data.player_id))
	var offers := []
	for rarity in ["common", "rare", "epic"]:
		var owned := GameData.card_order.filter(func(id): return has_card(id) and GameData.cards[id].rarity == rarity)
		if owned.is_empty():
			continue
		var amount := int(prog.daily_offer_amounts[rarity])
		offers.append({
			"index": offers.size(),
			"animal": owned[rng.randi_range(0, owned.size() - 1)],
			"rarity": rarity,
			"amount": amount,
			"price": amount * int(prog.daily_offer_gold_per_card[rarity]),
		})
	for offer in offers:
		offer["bought"] = data.shop_bought.has(offer.index)
	return offers


func buy_daily_offer(index: int) -> bool:
	var offers := daily_offers()
	if index < 0 or index >= offers.size() or offers[index].bought:
		return false
	if not spend_gold(offers[index].price):
		return false
	data.shop_bought.append(index)
	_add_cards(offers[index].animal, offers[index].amount)
	_changed()
	return true


func buy_gold_pack(index: int) -> bool:
	var pack: Dictionary = GameData.progression.gold_packs[index]
	if not spend_gems(int(pack.gems)):
		return false
	add_gold(int(pack.gold))
	return true


# --- Cosmetics: banners, icons, emotes -------------------------------------

func is_unlocked(item: Dictionary) -> bool:
	var unlock: Dictionary = item.get("unlock", {"type": "default"})
	match unlock.get("type", "default"):
		"default":
			return true
		"ranger_level":
			return int(ranger_info().level) >= int(unlock.level)
		"arena":
			return highest_arena() >= int(GameData.arena_index_by_id.get(unlock.arena, 999))
		"animal":
			return has_card(unlock.animal)
		"shop":
			return data.owned_cosmetics.has(item.id)
	return false


## Text for a locked item, e.g. "Reach Ranger Level 5".
func unlock_hint(item: Dictionary) -> String:
	var unlock: Dictionary = item.get("unlock", {})
	match unlock.get("type", ""):
		"ranger_level":
			return "Reach Ranger Level %d" % int(unlock.level)
		"arena":
			return "Reach %s" % GameData.get_arena(GameData.arena_index_by_id.get(unlock.arena, 0)).name
		"animal":
			return "Find the %s" % GameData.get_card(unlock.animal).get("name", "?")
		"shop":
			return "%d gems" % int(unlock.gems)
	return ""


func buy_cosmetic(item: Dictionary) -> bool:
	var unlock: Dictionary = item.get("unlock", {})
	if unlock.get("type", "") != "shop" or is_unlocked(item):
		return false
	if not spend_gems(int(unlock.gems)):
		return false
	data.owned_cosmetics.append(item.id)
	_changed()
	return true


func set_banner(id: String) -> void:
	var item := GameData.find_by_id(GameData.banners, id)
	if not item.is_empty() and is_unlocked(item):
		data.banner = id
		_changed()


func set_icon(id: String) -> void:
	var item := GameData.find_by_id(GameData.player_icons, id)
	if not item.is_empty() and is_unlocked(item):
		data.icon = id
		_changed()


func unlocked_emotes() -> Array:
	return GameData.emotes.filter(func(e): return is_unlocked(e))


# --- Developer tools (only shown in debug builds) --------------------------

func dev_add_trophies(amount: int) -> void:
	data.trophies = maxi(0, get_trophies() + amount)
	data.best_trophies = maxi(int(data.best_trophies), get_trophies())
	data.highest_arena = maxi(highest_arena(), arena_index())
	_changed()


## Moves every unlocking cage timer forward.
func dev_skip_time(seconds: float) -> void:
	for entry in data.cage_slots:
		if entry != null and float(entry.unlock_at) > 0.0:
			entry.unlock_at = float(entry.unlock_at) - seconds
	_changed()


func dev_unlock_all_animals() -> void:
	for id in GameData.card_order:
		_add_cards(id, 1)
	_changed()
