class_name ComingSoon
extends RefCounted
## Pieces for pages that preview features still to come (Clans, Events): a
## big toy with a title, and cards for each planned feature.


## The page's toy (a menu prop: MenuArt; `icon_key`'s icon in a circle
## without one), bobbing a little, then a title, a "Coming soon" ribbon and
## a line of text under it.
static func hero(icon_key: String, color: Color, title: String, text: String, prop := "") -> Control:
	var box := UIKit.vbox(10)
	var medal: Control
	if MenuArt.has(prop):
		medal = MenuArt.rect(prop, 190)
		# It bobs gently, like the cards in the shop.
		var bob := medal.create_tween().set_loops()
		var seconds := Feel.num("ui", "card_bob_seconds", 2.6) / 2.0
		var pixels := Feel.num("ui", "card_bob_pixels", 3.0) * 2.0
		bob.tween_property(medal, "position:y", -pixels, seconds).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(medal, "position:y", pixels, seconds).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		medal = IconArt.make(GameData.ui_icon(icon_key), color, IconArt.Shape.CIRCLE, Vector2(150, 150))
	medal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(medal)
	box.add_child(UIKit.label(title, 50, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(ribbon("Coming soon"))
	var blurb := UIKit.paragraph(text, 22, UIKit.TEXT)
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(blurb)
	return box


## A yellow tag with dark-outlined text.
static func ribbon(text: String) -> Control:
	var tag := PanelContainer.new()
	var style := UIKit.box(UIKit.YELLOW, 16, 6)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.set_border_width_all(3)
	style.border_color = UIKit.INK
	tag.add_theme_stylebox_override("panel", style)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tag.add_child(UIKit.label(text, 22, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	return tag


## A card for one planned feature: its icon, name and what it does.
static func feature(icon_key: String, title: String, text: String) -> Control:
	var panel := UIKit.panel(UIKit.PANEL, 16, 20)
	var row := UIKit.hbox(16)
	panel.add_child(row)
	var icon := IconArt.make(GameData.ui_icon(icon_key), UIKit.DEEP, IconArt.Shape.ROUNDED, Vector2(76, 76))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var words := UIKit.vbox(4)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	words.add_child(UIKit.label(title, 26, UIKit.YELLOW))
	words.add_child(UIKit.paragraph(text, 20, UIKit.TEXT))
	return panel
