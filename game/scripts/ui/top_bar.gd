extends PanelContainer
## The bar at the top of the menu: a wooden trail-sign plank with your
## banner (tap it for your profile) and your gold and gems, each a toy coin
## or gem on a slot of dark wood. Tap the + on a counter to go to the Shop.
## Sizes: feel.json "menu" (bar_*).

signal shop_requested

const C := "menu"

var _badge_holder: Control
## Each counter: {"amount": its Label, "shown": the number on it, "icon"}.
var _gold: Dictionary
var _gems: Dictionary


func _ready() -> void:
	var plank := SkinBox.make("sign", UIStyle.color("sign"))
	plank.content_margin_left = 20
	plank.content_margin_right = 18
	plank.content_margin_top = 8
	plank.content_margin_bottom = 14
	add_theme_stylebox_override("panel", plank)
	var row := UIKit.hbox(10)
	add_child(row)

	_badge_holder = PanelContainer.new()
	_badge_holder.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_badge_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_badge_holder)
	UIKit.on_tap(_badge_holder, func() -> void: Modal.open(ProfileView.create(), "Profile"))

	row.add_child(UIKit.spacer())

	_gold = _counter("coin")
	_gems = _counter("gem")
	for counter in [_gold, _gems]:
		row.add_child(counter.holder)

	Profile.changed.connect(refresh)
	refresh()


## A counter: a slot of dark wood with the amount, a toy coin or gem
## sitting over its left end, and a little green + that opens the Shop.
func _counter(prop: String) -> Dictionary:
	var icon_side := Feel.num(C, "bar_icon", 58.0)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(Feel.num(C, "bar_counter_width", 196.0), icon_side)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var slot := PanelContainer.new()
	var well := SkinBox.make("inset", UIKit.DEEP)
	well.content_margin_left = icon_side * 0.62
	well.content_margin_right = 6
	well.content_margin_top = 4
	well.content_margin_bottom = 4
	slot.add_theme_stylebox_override("panel", well)
	slot.anchor_right = 1.0
	slot.anchor_top = 0.5
	slot.anchor_bottom = 0.5
	var slot_height := Feel.num(C, "bar_slot_height", 48.0)
	slot.offset_left = icon_side * 0.34
	slot.offset_top = -slot_height / 2.0
	slot.offset_bottom = slot_height / 2.0
	holder.add_child(slot)
	var row := UIKit.hbox(4)
	slot.add_child(row)
	var amount := UIKit.label("0", 24, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	amount.name = "Amount"
	amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amount.clip_text = true
	row.add_child(amount)
	var plus := UIKit.button("+", UIKit.GREEN, 28, Vector2(40, 40))
	plus.add_theme_constant_override("outline_size", 5)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var margins := StyleBoxEmpty.new()
		margins.content_margin_bottom = 2.0 if state.contains("pressed") else 5.0
		plus.add_theme_stylebox_override(state, margins)
	plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plus.pressed.connect(shop_requested.emit)
	row.add_child(plus)

	var icon := MenuArt.rect(prop, icon_side)
	icon.position = Vector2(0, 0)
	icon.size = Vector2(icon_side, icon_side)
	holder.add_child(icon)
	return {"holder": holder, "amount": amount, "icon": icon, "shown": -1}


func refresh() -> void:
	for child in _badge_holder.get_children():
		_badge_holder.remove_child(child)
		child.queue_free()
	var badge := PlayerBadge.for_player(true)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_holder.add_child(badge)
	_show(_gold, Profile.get_gold())
	_show(_gems, Profile.get_gems())


## Shows a counter's new amount; when it changes, its toy icon hops.
func _show(counter: Dictionary, amount: int) -> void:
	(counter.amount as Label).text = short_amount(amount)
	if int(counter.shown) >= 0 and int(counter.shown) != amount and is_inside_tree():
		var icon: Control = counter.icon
		icon.pivot_offset = icon.size / 2.0
		var hop := icon.create_tween()
		hop.tween_property(icon, "scale", Vector2.ONE * Feel.num("ui", "pill_bump", 1.22), 0.08)
		hop.tween_property(icon, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	counter.shown = amount


## An amount as the bar shows it: in full up to 999,999, then in millions
## ("1.25M"), so it always fits its slot.
static func short_amount(amount: int) -> String:
	if absi(amount) < 1000000:
		return UIKit.format_number(amount)
	var millions := amount / 1000000.0
	return ("%.2fM" if absf(millions) < 10.0 else "%.1fM" if absf(millions) < 100.0 else "%.0fM") % millions
