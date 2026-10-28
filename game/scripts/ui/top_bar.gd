extends PanelContainer
## The bar at the top of the menu: your banner (tap it for your profile)
## plus gold and gems.

var _badge_holder: Control
var _gold: PanelContainer
var _gems: PanelContainer


func _ready() -> void:
	add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.3), 0, 10))
	var row := UIKit.hbox(10)
	add_child(row)

	_badge_holder = PanelContainer.new()
	_badge_holder.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	row.add_child(_badge_holder)
	UIKit.on_tap(_badge_holder, func() -> void: Modal.open(ProfileView.create(), "Profile"))

	row.add_child(UIKit.spacer())

	var currencies := UIKit.vbox(6)
	currencies.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(currencies)
	_gold = UIKit.pill("G", UIKit.GOLD, "0")
	_gems = UIKit.pill("Gm", UIKit.GEMS, "0")
	for pill in [_gold, _gems]:
		pill.custom_minimum_size = Vector2(170, 0)
		currencies.add_child(pill)

	Profile.changed.connect(refresh)
	refresh()


func refresh() -> void:
	for child in _badge_holder.get_children():
		_badge_holder.remove_child(child)
		child.queue_free()
	var badge := PlayerBadge.for_player(true)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_holder.add_child(badge)
	_gold.find_child("Amount", true, false).text = UIKit.format_number(Profile.get_gold())
	_gems.find_child("Amount", true, false).text = UIKit.format_number(Profile.get_gems())
