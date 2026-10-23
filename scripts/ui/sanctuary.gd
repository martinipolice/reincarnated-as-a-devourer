extends Control
## The Goddess's Sanctuary, between runs: spend banked gold on permanent
## training (the terminal game's Train menu), then begin a new run.

const RUN_SCENE := "res://scenes/main.tscn"
## Also read by main.gd to apply ranks at the start of a run.
const TRAININGS := [
	preload("res://data/training/stamina.tres"),
	preload("res://data/training/strength.tres"),
	preload("res://data/training/resilience.tres"),
	preload("res://data/training/dexterity.tres"),
	preload("res://data/training/guts.tres"),
]

@onready var gold_label: Label = %Gold
@onready var stats_label: Label = %Stats
@onready var rows: VBoxContainer = %Rows
@onready var begin_button: Button = %Begin


func _ready() -> void:
	begin_button.pressed.connect(_begin)
	_refresh()
	begin_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		_begin()


func _refresh() -> void:
	gold_label.text = "Gold: %d" % Save.gold()
	stats_label.text = "Runs %d   ·   Victories %d   ·   Best day %d" % [
		int(Save.data.runs), int(Save.data.wins), int(Save.data.best_day)]
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	for training: TrainingData in TRAININGS:
		rows.add_child(_make_row(training))


func _make_row(training: TrainingData) -> Control:
	var rank := Save.training_rank(training)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var info := Label.new()
	info.text = "%s\n%s" % [training.display_name, training.description]
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var pips := Label.new()
	pips.text = "■".repeat(rank) + "□".repeat(training.max_rank - rank)
	pips.custom_minimum_size = Vector2(90, 0)
	pips.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(pips)

	var buy := Button.new()
	buy.custom_minimum_size = Vector2(150, 44)
	if rank >= training.max_rank:
		buy.text = "Mastered"
		buy.disabled = true
	else:
		var cost := training.cost(rank)
		buy.text = "Train  %dg" % cost
		buy.disabled = Save.gold() < cost
		buy.pressed.connect(_buy.bind(training))
	row.add_child(buy)
	return row


func _buy(training: TrainingData) -> void:
	if Save.buy_training(training):
		Game.sfx("coins", 0.0)
	else:
		Game.sfx("denied", 0.0)
	_refresh()
	begin_button.grab_focus()


func _begin() -> void:
	Game.sfx("click", 0.0)
	get_tree().change_scene_to_file(RUN_SCENE)
