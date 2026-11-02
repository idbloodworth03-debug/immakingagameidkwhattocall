class_name ValuePill
extends PanelContainer
## A chip with an icon and a number (hearts, Acorns, trophies...). Changes
## tick up or down instead of jumping, with a little bump (feel.json "ui":
## count_seconds). `extra` shows a short gold note after the number, like
## "+5" interest.

var value := 0
var icon_rect: TextureRect
var amount: Label
var extra_label: Label
var _shown := 0.0
var _tween: Tween


static func make(icon_key: String, icon_tint: Color, start := 0) -> ValuePill:
	var pill := ValuePill.new()
	pill.theme_type_variation = "ChipPanel"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UIStyle.hbox("xs")
	pill.add_child(row)
	pill.icon_rect = UIStyle.icon(icon_key, icon_tint, int(UIStyle.num("chip", "icon", 40)))
	row.add_child(pill.icon_rect)
	pill.amount = UIStyle.label(str(start), "body")
	row.add_child(pill.amount)
	pill.extra_label = UIStyle.label("", "small", UIStyle.color("gold"))
	pill.extra_label.visible = false
	row.add_child(pill.extra_label)
	pill.value = start
	pill._shown = start
	return pill


## Ticks the number to `new_value`. `bump` gives it a little pop.
func set_value(new_value: int, bump := true) -> void:
	if new_value == value:
		return
	value = new_value
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var seconds := Feel.num("ui", "count_seconds", 0.4)
	if seconds <= 0.0 or not is_inside_tree():
		_show(float(new_value))
		return
	_tween = create_tween()
	_tween.tween_method(_show, _shown, float(new_value), seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if bump:
		pivot_offset = size / 2.0
		var pop := create_tween()
		pop.tween_property(self, "scale", Vector2.ONE * Feel.num("ui", "pill_bump", 1.22), 0.08)
		pop.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A short note after the number ("" hides it).
func set_extra(text: String) -> void:
	extra_label.text = text
	extra_label.visible = text != ""


func _show(shown: float) -> void:
	_shown = shown
	amount.text = str(roundi(shown))
