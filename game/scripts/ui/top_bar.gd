extends PanelContainer
## The bar at the top of the menu: your banner (tap it for your profile)
## plus gold and gems. Tap the + on a counter to go to the Shop.

signal shop_requested

var _badge_holder: Control
var _gold: PanelContainer
var _gems: PanelContainer


func _ready() -> void:
	var style := UIKit.box(UIKit.DEEP, 0, 10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.border_width_bottom = 2
	style.border_color = UIKit.PANEL
	style.shadow_color = Color(UIKit.INK, 0.3)
	style.shadow_size = 8
	add_theme_stylebox_override("panel", style)
	var row := UIKit.hbox(10)
	add_child(row)

	_badge_holder = PanelContainer.new()
	_badge_holder.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	row.add_child(_badge_holder)
	UIKit.on_tap(_badge_holder, func() -> void: Modal.open(ProfileView.create(), "Profile"))

	row.add_child(UIKit.spacer())

	_gold = _counter(GameData.ui_icon("gold"), UIKit.GOLD)
	_gems = _counter(GameData.ui_icon("gems"), UIKit.GEMS)
	for counter in [_gold, _gems]:
		counter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(counter)

	Profile.changed.connect(refresh)
	refresh()


## A currency pill with a little green + that opens the Shop.
func _counter(icon_name: String, color: Color) -> PanelContainer:
	var pill := UIKit.pill(icon_name, color, "0")
	pill.custom_minimum_size = Vector2(160, 0)
	var row: HBoxContainer = pill.get_child(0)
	var amount: Label = pill.find_child("Amount", true, false)
	amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var plus := UIKit.button("+", UIKit.GREEN, 26, Vector2(36, 36))
	plus.add_theme_constant_override("outline_size", 5)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var margins: StyleBoxEmpty = plus.get_theme_stylebox(state)
		margins.content_margin_left = 0
		margins.content_margin_right = 0
	plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	plus.pressed.connect(shop_requested.emit)
	row.add_child(plus)
	var style: StyleBoxFlat = pill.get_theme_stylebox("panel")
	style.content_margin_right = 6
	return pill


func refresh() -> void:
	for child in _badge_holder.get_children():
		_badge_holder.remove_child(child)
		child.queue_free()
	var badge := PlayerBadge.for_player(true)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_holder.add_child(badge)
	_gold.find_child("Amount", true, false).text = UIKit.format_number(Profile.get_gold())
	_gems.find_child("Amount", true, false).text = UIKit.format_number(Profile.get_gems())
