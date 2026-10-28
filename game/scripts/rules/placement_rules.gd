class_name PlacementRules
extends RefCounted
## Checks whether an animal can be released (placed) right now in a battle.
##
## Every animal costs energy, and many also have prerequisites, listed in
## animals.json under "prerequisites". `state` describes the battle from the
## releasing player's side:
##   energy             float, current energy
##   elapsed            float, seconds since the battle started
##   zone               "own_side", "river" or "enemy_side" (where the player tapped)
##   allies             Array of animal dictionaries on the player's side of the field
##   deployed_count     int, animals this player has released so far this battle
##   allies_defeated    int, this player's animals defeated so far
##   own_tower_damaged  bool, true once any of this player's towers took damage


## Returns the reasons this animal can't be released right now.
## An empty list means it's allowed.
static func blocking_reasons(animal: Dictionary, state: Dictionary) -> Array:
	var reasons := []
	if float(state.get("energy", 0.0)) < float(animal.get("cost", 0)):
		reasons.append("Not enough energy")

	var zone := String(state.get("zone", "own_side"))
	if not allowed_zones(animal).has(zone):
		reasons.append(_zone_reason(animal, zone))

	for req in animal.get("prerequisites", []):
		if req.type != "zone" and not is_met(req, animal, state):
			reasons.append(describe(req))
	return reasons


## Where this animal may be released. Normally only your own side, aquatic
## animals may also swim in from the river, and some must use the river.
static func allowed_zones(animal: Dictionary) -> Array:
	for req in animal.get("prerequisites", []):
		if req.type == "zone":
			return [req.zone]
	if animal.get("tags", []).has("aquatic"):
		return ["own_side", "river"]
	return ["own_side"]


static func is_met(req: Dictionary, animal: Dictionary, state: Dictionary) -> bool:
	match String(req.get("type", "")):
		"allies_with_tag":
			return count_allies_with_tag(state, req.tag) >= int(req.get("count", 1))
		"no_allies_with_tag":
			return count_allies_with_tag(state, req.tag) == 0
		"deployed_count":
			return int(state.get("deployed_count", 0)) >= int(req.count)
		"match_time":
			return float(state.get("elapsed", 0.0)) >= float(req.seconds)
		"own_tower_damaged":
			return bool(state.get("own_tower_damaged", false))
		"allies_defeated":
			return int(state.get("allies_defeated", 0)) >= int(req.count)
		"unique":
			for ally in state.get("allies", []):
				if ally.get("id", "") == animal.get("id", ""):
					return false
			return true
		"zone":
			return String(state.get("zone", "own_side")) == String(req.zone)
	push_warning("PlacementRules: unknown prerequisite type '%s'" % req.get("type"))
	return true


static func count_allies_with_tag(state: Dictionary, tag: String) -> int:
	var total := 0
	for ally in state.get("allies", []):
		if ally.get("tags", []).has(tag):
			total += 1
	return total


## A short sentence players can read, like "Needs 1 allied Canine on the field".
static func describe(req: Dictionary) -> String:
	match String(req.get("type", "")):
		"allies_with_tag":
			var count := int(req.get("count", 1))
			return "Needs %d allied %s on the field" % [count, GameData.tag_name(req.tag, count)]
		"no_allies_with_tag":
			return "Can't be released while you have a %s on the field" % GameData.tag_name(req.tag)
		"deployed_count":
			var count := int(req.count)
			return "Release %d other animal%s first" % [count, "" if count == 1 else "s"]
		"match_time":
			return "Available after %s of battle" % _clock(float(req.seconds))
		"own_tower_damaged":
			return "Only after one of your towers takes damage"
		"allies_defeated":
			return "Only after %d of your animals are defeated" % int(req.count)
		"unique":
			return "Only one on the field at a time"
		"zone":
			return "Must be released in the river" if req.zone == "river" else "Must be released in: %s" % req.zone
	return "Unknown requirement"


static func _zone_reason(animal: Dictionary, zone: String) -> String:
	var allowed := allowed_zones(animal)
	if allowed == ["river"]:
		return "Must be released in the river"
	if zone == "river":
		return "Only Aquatic animals can be released in the river"
	return "Release animals on your side of the field"


static func _clock(seconds: float) -> String:
	return "%d:%02d" % [floori(seconds / 60.0), int(seconds) % 60]
