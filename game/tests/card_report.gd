extends Node
## How much a screen full of cards costs (the rarity show, CardShow): opens
## the Animals tab and Your Deck at phone size with every animal owned, runs
## them for a few seconds and counts how often cards are redrawn.
##   godot --headless --fixed-fps 60 --path game res://tests/card_report.tscn

const SECONDS := 3.0

var _screen: Control
var _frames := 0
var _which := 0
var _start := 0


func _ready() -> void:
	Profile.autosave = false
	for id in GameData.card_order:
		if not Profile.data.collection.has(id):
			Profile.data.collection[id] = {"level": GameData.start_level(GameData.cards[id].rarity), "copies": 0, "new": false}
	get_window().size = Vector2i(720, 1558)
	_open()


func _open() -> void:
	if _screen != null:
		_screen.queue_free()
	var path: String = ["res://scripts/ui/tabs/animals_tab.gd", "res://scenes/deck.tscn"][_which]
	_screen = load(path).new() if path.ends_with(".gd") else load(path).instantiate()
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_screen)
	_frames = 0


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 30:
		_start = AnimalCard.draws
	if _frames == 30 + int(SECONDS * 60):
		var cards := _screen.find_children("*", "AnimalCard", true, false)
		var moving := cards.filter(func(c): return c.is_processing())
		var seen := moving.filter(func(c): return CardShow.on_screen(c))
		var per_second := (AnimalCard.draws - _start) / SECONDS
		print("%s: %d cards, %d that move (Epic and up), %d of them on screen; %.0f card redraws a second (each moving card every frame would be %d)" % [
			["Animals tab", "Your Deck"][_which], cards.size(), moving.size(), seen.size(), per_second, moving.size() * 60])
		_which += 1
		if _which >= 2:
			get_tree().quit()
		else:
			_open()
