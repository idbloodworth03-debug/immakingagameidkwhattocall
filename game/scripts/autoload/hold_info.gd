extends CanvasLayer
## Hold for info, everywhere: holding a finger on any card (in the group
## "hold_info": animal cards and game cards, on every screen), or on an
## animal on the battlefield (BattleField.view_at), shows its InfoPop near
## the finger until it lets go. It only watches: nothing pauses, and the
## fight goes on. A hold isn't a tap: a card's tap handler asks just_held()
## and does nothing on the release that ends a hold. Timing: feel.json
## "info".

const GROUP := "hold_info"
const FIELD_GROUP := "hold_info_field"

var _down := false
var _at := Vector2.ZERO
var _serial := 0
var _pop: InfoPop
var _held_frame := -100


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			_at = event.position
			_serial += 1
			var serial := _serial
			get_tree().create_timer(Feel.num("info", "hold_seconds", 0.35), true, false, true).timeout.connect(func() -> void:
				if _down and _serial == serial:
					_show_at(_at))
		else:
			_down = false
			if _pop != null:
				_held_frame = Engine.get_process_frames()
				hide_pop()
	elif event is InputEventMouseMotion and _down:
		if event.position.distance_to(_at) > Feel.num("info", "move_pixels", 24.0) and _pop == null:
			# A drag (scrolling, aiming a tool): not a hold.
			_down = false


## True on the release that ended a hold (so it isn't also a tap).
func just_held() -> bool:
	return Engine.get_process_frames() - _held_frame <= 1


## What's under the finger: a card's (id, stars, level) or an animal's.
func target_at(point: Vector2) -> Dictionary:
	var found := {}
	var best_area := INF
	for node in get_tree().get_nodes_in_group(GROUP):
		var card := node as Control
		if card == null or not card.is_visible_in_tree() or not card.get_global_rect().has_point(point):
			continue
		var id := String(card.get("animal_id") if card.get("animal_id") != null else card.get("card_id"))
		if id == "" or not GameData.cards.has(id):
			continue
		# The smallest card under the finger (a card inside a slot, not the slot).
		var area := card.get_global_rect().get_area()
		if area < best_area:
			best_area = area
			var star_count: Variant = card.get("stars")
			found = {"id": id, "stars": int(star_count) if star_count != null else 0, "level": int(card.get_meta("level", -1))}
	if not found.is_empty():
		return found
	for node in get_tree().get_nodes_in_group(FIELD_GROUP):
		var field := node as BattleField
		if field == null or not field.is_visible_in_tree() or not field.get_global_rect().has_point(point):
			continue
		var view := field.view_at(point)
		if view != null and view.fighter != null:
			return {"id": view.id, "stars": view.stars, "level": view.fighter.level}
	return {}


func _show_at(point: Vector2) -> void:
	var target := target_at(point)
	if target.is_empty():
		return
	hide_pop()
	_pop = InfoPop.make(String(target.id), int(target.stars), int(target.level))
	add_child(_pop)
	# Above the finger if there's room, else below; never off the screen.
	var screen := get_viewport().get_visible_rect().size
	var gap := Feel.num("info", "gap", 48.0)
	var above := point.y - gap - _pop.size.y > 12.0
	var y := point.y - gap - _pop.size.y if above else point.y + gap
	var x := clampf(point.x - _pop.size.x / 2.0, 10.0, screen.x - _pop.size.x - 10.0)
	_pop.position = Vector2(x, clampf(y, 10.0, screen.y - _pop.size.y - 10.0))
	_pop.pivot_offset = Vector2(clampf(point.x - x, 0.0, _pop.size.x), _pop.size.y if above else 0.0)
	Sound.play("select", -6.0)


func hide_pop() -> void:
	if _pop != null and is_instance_valid(_pop):
		_pop.queue_free()
	_pop = null


## The popup showing now, or null.
func showing() -> InfoPop:
	return _pop if _pop != null and is_instance_valid(_pop) else null
