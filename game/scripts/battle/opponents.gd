class_name Opponents
extends RefCounted
## Made-up opponents for matches against the computer: a name, a banner and
## icon anyone could have, and trophies and a Ranger level close to yours.

const NAMES := ["MossyFox", "RiverOtter42", "SilentOwl", "BadgerBoss", "TundraTom", "ZebraZoe", "CanopyKid", "DuneRunner"]


static func random(rng: RandomNumberGenerator) -> Dictionary:
	var banners := GameData.banners.filter(func(b): return b.unlock.type == "default")
	var icons := GameData.player_icons.filter(func(i): return i.unlock.type == "default")
	return {
		"name": NAMES[rng.randi_range(0, NAMES.size() - 1)],
		"trophies": maxi(0, Profile.get_trophies() + rng.randi_range(-80, 80)),
		"banner": banners[rng.randi_range(0, banners.size() - 1)].id,
		"icon": icons[rng.randi_range(0, icons.size() - 1)].id,
		"level": maxi(1, int(Profile.ranger_info().level) + rng.randi_range(-1, 1)),
	}
