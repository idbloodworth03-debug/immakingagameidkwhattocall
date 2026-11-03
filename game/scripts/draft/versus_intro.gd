class_name VersusIntro
extends Control
## The VS screen before a Draft Duel: the Rival Ranger on their banner at
## the top, you on yours at the bottom, and a big bouncy VS between. Shows
## the rival's line, their favorite habitat, and an ARENA BOSS ribbon for a
## boss. Tap to go on (or it goes on by itself after a few seconds).
##
## Timings and sizes are in feel.json ("rivals").

signal finished
## Starts fading out: what's under it can show again.
signal leaving

const C := "rivals"

var rival: Dictionary = {}
var _rival_block: Control
var _player_block: Control
var _vs: Label
var _hint: Label
var _portrait: RangerPortrait
var _time := 0.0
var _leaving := false
var _top_colors: Array = []
var _bottom_colors: Array = []


static func create(rival_info: Dictionary) -> VersusIntro:
	var intro := VersusIntro.new()
	intro.rival = rival_info
	intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro.mouse_filter = Control.MOUSE_FILTER_STOP
	return intro


func _ready() -> void:
	var theirs := GameData.find_by_id(GameData.banners, rival.get("banner", ""))
	var mine := GameData.find_by_id(GameData.banners, Profile.data.banner)
	_top_colors = theirs.get("colors", ["#a8321e", "#ffb347"])
	_bottom_colors = mine.get("colors", ["#1e4f96", "#3277c9"])
	_rival_block = _build_rival()
	add_child(_rival_block)
	_player_block = _build_player()
	add_child(_player_block)
	_vs = UIKit.label("VS", Feel.count(C, "vs_size", 128), UIKit.YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
	_vs.add_theme_constant_override("outline_size", 22)
	_vs.add_theme_color_override("font_outline_color", UIKit.INK)
	_vs.add_theme_constant_override("shadow_offset_y", 8)
	_vs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vs)
	_hint = UIKit.label("Tap to start", 24, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.add_theme_color_override("font_outline_color", UIKit.INK)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	resized.connect(_layout)
	_layout.call_deferred()
	_animate_in.call_deferred()


func _build_rival() -> Control:
	var box := UIKit.vbox(6)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var arena := GameData.get_arena(int(rival.get("arena_index", 0)))
	box.add_child(_outlined(String(arena.name).to_upper(), 22, Color(1, 1, 1, 0.9)))
	if rival.get("boss", false):
		var ribbon_style := UIKit.raised(UIKit.GOLD, 12, 6)
		ribbon_style.content_margin_left = 22
		ribbon_style.content_margin_right = 22
		var ribbon := PanelContainer.new()
		ribbon.add_theme_stylebox_override("panel", ribbon_style)
		ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var ribbon_text := UIKit.label("ARENA BOSS", 28, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
		ribbon_text.add_theme_constant_override("outline_size", 0)
		ribbon.add_child(ribbon_text)
		box.add_child(ribbon)
	_portrait = RangerPortrait.create(rival, Feel.num(C, "portrait_size", 236.0))
	_portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_portrait)
	box.add_child(_outlined(rival.get("name", "Rival"), 46, Color.WHITE))
	if rival.get("title", "") != "":
		box.add_child(_outlined(rival.title, 22, UIKit.GOLD))
	var bubble_style := UIKit.box(Color.WHITE, 18, 12)
	bubble_style.content_margin_left = 18
	bubble_style.content_margin_right = 18
	bubble_style.shadow_color = Color(UIKit.INK, 0.35)
	bubble_style.shadow_size = 0
	bubble_style.shadow_offset = Vector2(0, 4)
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", bubble_style)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var line := UIKit.paragraph("\"%s\"" % rival.get("line", ""), 21, UIKit.INK)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.custom_minimum_size.x = 480
	bubble.add_child(line)
	box.add_child(bubble)
	# Their favorite class, as its badge.
	var favorite: String = rival.get("style", {}).get("favorite", "")
	if GameData.classes.has(favorite):
		var info := GameData.class_info(favorite)
		var row := UIKit.hbox(8)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(UIKit.icon_rect(GameData.ui_icon(String(info.icon)), Color(String(info.color)).lightened(0.3), 34))
		row.add_child(_outlined("Loves %s" % String(info.name), 20, Color.WHITE))
		box.add_child(row)
	return box


func _build_player() -> Control:
	var box := UIKit.vbox(4)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := GameData.find_by_id(GameData.player_icons, Profile.data.icon)
	var art := IconArt.make(GameData.player_icon(Profile.data.icon), Color(icon.get("color", "#888888")))
	art.text = icon.get("text", "?")
	var side := Feel.num(C, "player_icon_size", 150.0)
	art.custom_minimum_size = Vector2(side, side)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(art)
	box.add_child(_outlined(Profile.get_player_name(), 40, Color.WHITE))
	box.add_child(_outlined("Ranger Lv %d  ·  %d trophies" % [int(Profile.ranger_info().level), Profile.get_trophies()], 20, Color(1, 1, 1, 0.85)))
	return box


func _outlined(text: String, font_size: int, color: Color) -> Label:
	var label := UIKit.label(text, font_size, color, HORIZONTAL_ALIGNMENT_CENTER)
	label.add_theme_constant_override("outline_size", maxi(6, font_size / 5))
	label.add_theme_color_override("font_outline_color", UIKit.INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _layout() -> void:
	var w := size.x
	var h := size.y
	for block in [_rival_block, _player_block, _vs, _hint]:
		(block as Control).reset_size()
	_rival_block.position = Vector2((w - _rival_block.size.x) / 2.0, maxf(16.0, h * 0.3 - _rival_block.size.y * 0.5))
	_player_block.position = Vector2((w - _player_block.size.x) / 2.0, h * 0.78 - _player_block.size.y * 0.5)
	_vs.position = Vector2((w - _vs.size.x) / 2.0, h * 0.585 - _vs.size.y * 0.5)
	_vs.pivot_offset = _vs.size / 2.0
	_hint.position = Vector2((w - _hint.size.x) / 2.0, h - _hint.size.y - 26.0)
	_rival_block.pivot_offset = _rival_block.size / 2.0
	_player_block.pivot_offset = _player_block.size / 2.0


## Rival slides in from the left, you from the right, then the VS slams down.
func _animate_in() -> void:
	_layout()
	var w := size.x
	var rival_at := _rival_block.position
	var player_at := _player_block.position
	_rival_block.position.x = rival_at.x - w
	_player_block.position.x = player_at.x + w
	_vs.scale = Vector2(3.0, 3.0)
	_vs.modulate.a = 0.0
	_hint.modulate.a = 0.0
	Sound.play("whoosh")
	var tween := create_tween()
	tween.tween_property(_rival_block, "position:x", rival_at.x, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_player_block, "position:x", player_at.x, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.08)
	tween.tween_callback(func() -> void:
		Sound.play("versus")
		if rival.get("boss", false):
			Sound.play("boom", -6.0)
	)
	tween.tween_property(_vs, "modulate:a", 1.0, 0.08)
	tween.parallel().tween_property(_vs, "scale", Vector2(0.86, 0.86), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_slam)
	tween.tween_property(_vs, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_hint, "modulate:a", 1.0, 0.3)
	var hold := Feel.num(C, "versus_seconds", 3.6)
	if hold > 0.0:
		get_tree().create_timer(hold).timeout.connect(_leave)


## The VS lands: everything jolts, and the rival reacts.
func _slam() -> void:
	var jolt := create_tween()
	for i in 4:
		var amount := 10.0 * (1.0 - i / 4.0)
		jolt.tween_property(self, "position", Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), 0.035)
	jolt.tween_property(self, "position", Vector2.ZERO, 0.035)
	_portrait.mood = "happy" if rival.get("boss", false) else "normal"
	_portrait.pivot_offset = _portrait.size / 2.0
	var bounce := _portrait.create_tween()
	bounce.tween_property(_portrait, "scale", Vector2(1.12, 0.9), 0.08)
	bounce.tween_property(_portrait, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_time += delta
	if _hint != null and _hint.modulate.a > 0.5:
		_hint.modulate.a = 0.65 + 0.35 * sin(_time * 4.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if tap and _time >= Feel.num(C, "versus_min_seconds", 0.6):
		accept_event()
		_leave()


func _leave() -> void:
	if _leaving or not is_inside_tree():
		return
	_leaving = true
	leaving.emit()
	Sound.play("whoosh", -4.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void:
		finished.emit()
		queue_free()
	)


## Two banner-colored halves split on a slant, with a bright seam and
## slow-moving stripes.
func _draw() -> void:
	var w := size.x
	var h := size.y
	var split_left := h * 0.6
	var split_right := h * 0.56
	var top := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, split_right), Vector2(0, split_left)])
	var bottom := PackedVector2Array([Vector2(0, split_left), Vector2(w, split_right), Vector2(w, h), Vector2(0, h)])
	var a0 := Color(_top_colors[0]).darkened(0.25)
	var a1 := Color(_top_colors[1]).darkened(0.05)
	var b0 := Color(_bottom_colors[0]).darkened(0.25)
	var b1 := Color(_bottom_colors[1]).darkened(0.05)
	draw_polygon(top, PackedColorArray([a1, a1, a0, a0]))
	draw_polygon(bottom, PackedColorArray([b0, b0, b1, b1]))
	# Stripes drifting along the slant.
	var shift := fmod(_time * 40.0, 80.0)
	for i in range(-4, int(w / 80.0) + 6):
		var x := i * 80.0 + shift
		draw_line(Vector2(x, 0), Vector2(x - h * 0.4, h), Color(1, 1, 1, 0.05), 26.0)
	draw_line(Vector2(0, split_left), Vector2(w, split_right), Color(UIKit.INK, 0.6), 18.0)
	draw_line(Vector2(0, split_left), Vector2(w, split_right), Color.WHITE, 7.0)
	if rival.get("boss", false):
		var glow := 0.5 + 0.5 * sin(_time * 3.0)
		draw_rect(Rect2(0, 0, w, h), Color(UIKit.GOLD, 0.06 + 0.05 * glow), false, 14.0)
