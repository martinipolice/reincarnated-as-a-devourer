extends Node
## Persistent progress, available everywhere as `Save`: banked gold,
## Sanctuary training ranks and lifetime stats, stored in user://save.json.
## Every save carries a version; _migrate() upgrades older ones so an update
## never wipes progress (the terminal game's fixed-format save broke on any
## change to its fields).

const PATH := "user://save.json"
const VERSION := 1

var data := {}


func _ready() -> void:
	load_game()


func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"gold": 0,
		"training": {},  # TrainingData.id -> rank
		"runs": 0,
		"wins": 0,
		"best_day": 0,
	}


## Headless tools (tools/balance_sim.gd) run under their own MainLoop script;
## they always start from a fresh save and never write the player's file.
func persistent() -> bool:
	return get_tree().get_script() == null


func load_game() -> void:
	data = defaults()
	if not persistent() or not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		# Keep the broken file for inspection instead of silently losing it.
		DirAccess.copy_absolute(ProjectSettings.globalize_path(PATH),
			ProjectSettings.globalize_path(PATH + ".bad"))
		push_warning("Save file was unreadable; copied to save.json.bad and started fresh.")
		return
	data = _migrate(parsed)


func save_game() -> void:
	if not persistent():
		return
	# Write to a temp file first so a crash mid-write can't corrupt the save.
	var tmp := PATH + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("Could not write save: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(PATH))


# Fills in fields added since the save was written. When a field changes
# meaning, add a step here, e.g.:
#   if int(old.version) < 2: old.gold = int(old.gold) * 10
func _migrate(old: Dictionary) -> Dictionary:
	var result := defaults()
	result.merge(old, true)
	result.version = VERSION
	return result


func gold() -> int:
	return int(data.gold)


func add_gold(amount: int) -> void:
	data.gold = gold() + amount


func training_rank(training: TrainingData) -> int:
	return int(data.training.get(training.id, 0))


func buy_training(training: TrainingData) -> bool:
	var rank := training_rank(training)
	if rank >= training.max_rank or gold() < training.cost(rank):
		return false
	data.gold = gold() - training.cost(rank)
	data.training[training.id] = rank + 1
	save_game()
	return true


func record_run(day: int, won: bool) -> void:
	data.runs = int(data.runs) + 1
	if won:
		data.wins = int(data.wins) + 1
	data.best_day = maxi(int(data.best_day), day)
