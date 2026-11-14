extends Control
## Shop tab: daily animal offers for gold, cages for gems, gold for gems and
## cosmetics. Real-money gem packs come later with the app store setup.

var _content: VBoxContainer


func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)
	_content = UIKit.vbox(16)
	margin.add_child(_content)
	Profile.changed.connect(_rebuild_later)
	_rebuild()


func _rebuild_later() -> void:
	_rebuild.call_deferred()


func _rebuild() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_add_daily_offers()
	_add_cages()
	_add_gold_packs()
	_add_cosmetics()
	_content.add_child(UIKit.heading("Gems"))
	var gems := UIKit.panel(UIKit.PANEL_DARK, 16)
	_content.add_child(gems)
	var gem_row := UIKit.hbox(14)
	gems.add_child(gem_row)
	gem_row.add_child(MenuArt.rect("gems_pile", 96) if MenuArt.has("gems_pile") else UIKit.icon_rect(GameData.ui_icon("gems"), UIKit.GEMS, 64))
	var note := UIKit.paragraph("Gem packs will be real-money purchases through the App Store and Google Play. They come when the store accounts are set up.", 20)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gem_row.add_child(note)


func _add_daily_offers() -> void:
	var seconds_left := 86400.0 - fmod(Profile.now(), 86400.0)
	var header := UIKit.hbox(8)
	_content.add_child(header)
	var title := UIKit.heading("Daily Animals")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UIKit.label("New in " + UIKit.format_duration(seconds_left), 20, UIKit.TEXT_DIM))

	var row := UIKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(row)
	for offer in Profile.daily_offers():
		var cell := UIKit.panel(UIKit.PANEL, 10, 20)
		row.add_child(cell)
		var column := UIKit.vbox(8)
		cell.add_child(column)
		var card := AnimalCard.create(offer.animal)
		# An offer, on its own: the full rarity show.
		card.full_show = true
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		UIKit.on_tap(card, func() -> void: Modal.open(AnimalDetail.create(offer.animal), ""))
		column.add_child(card)
		column.add_child(UIKit.label("x%d" % offer.amount, 28, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		var buy := UIKit.button("Bought", UIKit.GREY, 20, Vector2(0, 62)) if offer.bought else \
				UIKit.price_button(UIKit.format_number(offer.price), "gold", UIKit.GREEN, 22)
		buy.disabled = offer.bought
		buy.pressed.connect(func() -> void:
			if not Profile.buy_daily_offer(offer.index):
				UIKit.error_toast("Not enough gold")
			else:
				Sound.play("coin")
		)
		column.add_child(buy)


func _add_cages() -> void:
	_content.add_child(UIKit.heading("Cages"))
	var arena := Profile.arena_index()
	for cage_id in GameData.cage_order:
		var cage: Dictionary = GameData.cages[cage_id]
		var price := int(cage.get("shop_gems", 0))
		if price <= 0:
			continue
		var row_panel := UIKit.panel(UIKit.PANEL, 14, 20)
		_content.add_child(row_panel)
		var row := UIKit.hbox(14)
		row_panel.add_child(row)
		var art := IconArt.new()
		art.shape = IconArt.Shape.CAGE
		art.color = Color(cage.color)
		art.custom_minimum_size = Vector2(124, 116)
		row.add_child(art)
		var info := UIKit.vbox(4)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(UIKit.label(cage.name, 26))
		info.add_child(UIKit.paragraph(CageInfo.summary(cage_id, arena), 20))
		var buttons := UIKit.vbox(8)
		row.add_child(buttons)
		var odds := UIKit.button("Odds", UIKit.BLUE, 20, Vector2(160, 52))
		odds.pressed.connect(func() -> void: CageInfo.show_odds(cage_id, arena))
		buttons.add_child(odds)
		var buy := UIKit.price_button(UIKit.format_number(price), "gems", UIKit.GREEN, 22, Vector2(160, 62))
		if not Profile.can_buy_cage(cage_id):
			buy.disabled = true
			buy.text = "Reach\n%s" % GameData.get_arena(GameData.arena_index_by_id.get(cage.get("shop_requires_arena", ""), 0)).name
		buy.pressed.connect(func() -> void: _confirm_cage(cage_id))
		buttons.add_child(buy)


func _confirm_cage(cage_id: String) -> void:
	var cage: Dictionary = GameData.cages[cage_id]
	Modal.confirm("Buy a %s for %s gems?" % [cage.name, UIKit.format_number(int(cage.shop_gems))], "Buy", func() -> void:
		var rewards := Profile.buy_cage(cage_id)
		if rewards.is_empty():
			UIKit.error_toast("Not enough gems")
		else:
			CageOpening.play(rewards)
	)


func _add_gold_packs() -> void:
	_content.add_child(UIKit.heading("Gold"))
	var row := UIKit.hbox(12)
	_content.add_child(row)
	var packs: Array = GameData.progression.gold_packs
	for i in packs.size():
		var pack: Dictionary = packs[i]
		var cell := UIKit.panel(UIKit.PANEL, 12, 20)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(cell)
		var column := UIKit.vbox(8)
		cell.add_child(column)
		# A bigger heap for a bigger pack: a few coins, a pile, a chest.
		var heaps: Array = GameData.art.get("menu", {}).get("gold_packs", [])
		var heap := String(heaps[mini(i, heaps.size() - 1)]) if not heaps.is_empty() else ""
		var coins := MenuArt.rect(heap, 132) if MenuArt.has(heap) else UIKit.icon_rect(GameData.ui_icon("gold"), UIKit.GOLD, 96)
		coins.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(coins)
		column.add_child(UIKit.label(UIKit.format_number(int(pack.gold)), 28, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		var buy := UIKit.price_button(UIKit.format_number(int(pack.gems)), "gems", UIKit.GREEN, 22)
		buy.pressed.connect(func() -> void:
			Modal.confirm("Trade %s gems for %s gold?" % [UIKit.format_number(int(pack.gems)), UIKit.format_number(int(pack.gold))], "Buy", func() -> void:
				if not Profile.buy_gold_pack(i):
					UIKit.error_toast("Not enough gems")
				else:
					Sound.play("coin")
			)
		)
		column.add_child(buy)


func _add_cosmetics() -> void:
	var items := []
	for list in [GameData.emotes, GameData.banners]:
		for item in list:
			if item.get("unlock", {}).get("type", "") == "shop":
				items.append(item)
	if items.is_empty():
		return
	_content.add_child(UIKit.heading("Emotes & Banners"))
	for item in items:
		var row_panel := UIKit.panel(UIKit.PANEL, 12, 20)
		_content.add_child(row_panel)
		var row := UIKit.hbox(14)
		row_panel.add_child(row)
		var is_emote: bool = item.has("caption")
		var preview := IconArt.new()
		preview.shape = IconArt.Shape.CIRCLE if is_emote else IconArt.Shape.ROUNDED
		preview.color = Color(item.color if is_emote else item.colors[0])
		preview.text = UIKit.initials(item.name) if is_emote else ""
		if is_emote:
			preview.icon = UIKit.icon(GameData.emote_icon(item.id))
		preview.custom_minimum_size = Vector2(80, 80)
		row.add_child(preview)
		var info := UIKit.vbox(2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(UIKit.label(item.name, 24))
		info.add_child(UIKit.label(("Emote: \"%s\"" % item.caption) if is_emote else "Player banner", 20, UIKit.TEXT_DIM))
		var owned := Profile.is_unlocked(item)
		var buy := UIKit.button("Owned", UIKit.GREY, 20, Vector2(150, 60)) if owned else \
				UIKit.price_button(str(int(item.unlock.gems)), "gems", UIKit.GREEN, 22, Vector2(150, 60))
		buy.disabled = owned
		buy.pressed.connect(func() -> void:
			Modal.confirm("Buy %s for %d gems?" % [item.name, int(item.unlock.gems)], "Buy", func() -> void:
				if not Profile.buy_cosmetic(item):
					UIKit.error_toast("Not enough gems")
				else:
					Sound.play("coin")
			)
		)
		row.add_child(buy)
