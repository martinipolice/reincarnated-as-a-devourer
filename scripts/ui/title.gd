extends Control
## The title screen: continue the journey in progress (saved at the last
## goddess shrine) or begin a new one, plus lifetime records. A hero only
## reincarnates once, so a new journey replaces any saved one.

const RUN_SCENE := "res://scenes/main.tscn"

@onready var continue_button: Button = %Continue
@onready var new_button: Button = %New
@onready var stats_label: Label = %Stats
@onready var note_label: Label = %Note


func _ready() -> void:
	continue_button.pressed.connect(_continue)
	new_button.pressed.connect(_new_journey)
	var journey: Variant = Save.data.journey
	if Save.has_journey():
		continue_button.text = "Continue your journey  (Day %d · Lv %d)" % [
			int(journey.day), int(journey.level)]
		new_button.text = "Begin a new journey"
		note_label.text = "Beginning anew abandons the journey in progress."
		continue_button.grab_focus()
	else:
		continue_button.hide()
		note_label.text = "You have twenty days, and only one life.\nThe goddess will find you on Days 5, 10, 15 and 19."
		new_button.grab_focus()
	stats_label.text = "Journeys %d   ·   Victories %d   ·   Best day %d" % [
		int(Save.data.journeys), int(Save.data.wins), int(Save.data.best_day)]


func _continue() -> void:
	Game.sfx("click", 0.0)
	Save.resume = true
	get_tree().change_scene_to_file(RUN_SCENE)


func _new_journey() -> void:
	Game.sfx("click", 0.0)
	if Save.has_journey():
		Save.data.journey = null
		Save.save_game()
	Save.resume = false
	get_tree().change_scene_to_file(RUN_SCENE)
