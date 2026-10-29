class_name CageInfo
extends RefCounted
## Shared pieces for showing what's inside a cage, used by the cage slots on
## the Battle tab and by the Shop.


## Short summary like "About 16 animals, 25-45 gold".
static func summary(cage_id: String, arena_index: int) -> String:
	var cage: Dictionary = GameData.cages[cage_id]
	var gold := CageRules.gold_range(cage, arena_index)
	var count := CageRules.card_count(cage, arena_index)
	var text := "%d animal%s" % [count, "" if count == 1 else "s"]
	if gold.y > 0:
		text += ", %s-%s gold" % [UIKit.format_number(gold.x), UIKit.format_number(gold.y)]
	if int(cage.get("gems", 0)) > 0:
		text += ", %d gems" % int(cage.gems)
	return text


## A block with the cage art, description, contents and an Odds button.
static func details(cage_id: String, arena_index: int) -> VBoxContainer:
	var cage: Dictionary = GameData.cages[cage_id]
	var box := UIKit.vbox(12)
	var art := IconArt.new()
	art.shape = IconArt.Shape.CAGE
	art.color = Color(cage.color)
	art.custom_minimum_size = Vector2(200, 180)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(art)
	box.add_child(UIKit.paragraph(cage.description, 22, UIKit.TEXT))
	box.add_child(UIKit.label(summary(cage_id, arena_index), 22, UIKit.YELLOW))
	var promised := CageRules.guaranteed(cage, GameData.cage_pools(arena_index), GameData.rarity_order)
	var parts := []
	for rarity in GameData.rarity_order:
		if promised[rarity] > 0:
			parts.append("%d %s" % [promised[rarity], GameData.rarity_name(rarity)])
	if not parts.is_empty():
		box.add_child(UIKit.paragraph("Guaranteed: " + ", ".join(parts), 21, UIKit.TEXT))
	box.add_child(UIKit.paragraph("Unlock time: " + UIKit.format_duration(float(cage.unlock_seconds)), 21))
	var odds_button := UIKit.button("See odds", UIKit.GREY, 22, Vector2(200, 60))
	odds_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	odds_button.pressed.connect(func() -> void: show_odds(cage_id, arena_index))
	box.add_child(odds_button)
	return box


## Exact drop chances for the player's arena. App stores require this for
## anything random that can be bought.
static func show_odds(cage_id: String, arena_index: int) -> void:
	var cage: Dictionary = GameData.cages[cage_id]
	var odds := CageRules.odds(cage, GameData.cage_pools(arena_index), GameData.rarity_order)
	var box := UIKit.vbox(10)
	box.add_child(UIKit.paragraph("Each animal in this cage is rolled separately with these chances (Arena %d):" % (arena_index + 1), 21, UIKit.TEXT))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	box.add_child(grid)
	for rarity in GameData.rarity_order:
		grid.add_child(UIKit.label(GameData.rarity_name(rarity), 24, GameData.rarity_color(rarity)))
		var chance := float(odds.get(rarity, 0.0))
		grid.add_child(UIKit.label("%.2f%%" % chance if chance > 0.0 else "Locked", 24))
	box.add_child(UIKit.paragraph("Guaranteed animals are added on top of these rolls. Rarities you haven't unlocked yet pass their chance to the next rarity down.", 19))
	Modal.open(box, cage.name + " odds", 600)
