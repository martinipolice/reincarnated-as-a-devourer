extends Node
## Persistent progress, available everywhere as `Save`, stored in
## user://save.json:
## - `journey`: the one journey in progress, checkpointed at every goddess
##   shrine so you can quit and continue (null when there is none). A hero
##   only reincarnates once: when the journey ends, by victory or by a death
##   you don't pay to undo, it is gone and the next one starts fresh.
## - lifetime records: journeys, victories, best day.
## Every save carries a version; _migrate() upgrades older ones so an update
## never wipes records (the terminal game's fixed-format save broke on any
## change to its fields).

const PATH := "user://save.json"
const VERSION := 2

var data := {}
## Set by the title screen: the next run scene continues the saved journey.
var resume := false


func _ready() -> void:
	load_game()


func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"journey": null,
		"journeys": 0,
		"wins": 0,
		"best_day": 0,
		"endings": [],  # endings seen: "spare", "devour"
		# Lifetime records behind the starting-weapon unlocks (Unlocks).
		"devoured_total": 0,
		"felled": [],  # mini-bosses ever felled, by name
		"start_weapon": "res://data/weapons/blade.tres",  # last chosen
		# The Codex: what this player has met and found, across journeys.
		"codex": {"enemies": {}, "upgrades": [], "essences": [], "resonances": []},
		# Set the moment the hero falls, cleared by a revive. Still set at
		# the next launch means the game closed on the death screen: the
		# journey is over (one life), not continued from the last shrine.
		"fallen_day": 0,
	}


## Headless tools (tools/balance_sim.gd) run under their own MainLoop script;
## they always start from a fresh save and never write the player's file.
func persistent() -> bool:
	# Benchmarks (scripts/debug/benchmark.gd) play scripted runs: never let
	# them touch the player's real save.
	return get_tree().get_script() == null and Benchmark.requested() == 0


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
	if int(data.fallen_day) > 0:
		end_journey(int(data.fallen_day), false)


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


# Fills in fields added since the save was written, and converts old ones.
func _migrate(old: Dictionary) -> Dictionary:
	var version := int(old.get("version", 1))
	if version < 2:
		# v1 was a roguelite: banked gold and permanent Sanctuary training
		# between runs. One-life journeys replace both; keep the records.
		old = {"journeys": old.get("runs", 0), "wins": old.get("wins", 0),
			"best_day": old.get("best_day", 0)}
	var result := defaults()
	result.merge(old, true)
	result.version = VERSION
	return result


func has_journey() -> bool:
	return data.journey is Dictionary


## Checkpoints the journey in progress (main.gd builds the snapshot).
func save_journey(snapshot: Dictionary) -> void:
	data.journey = snapshot
	save_game()


## Lifetime records for the unlocks; written with the next save.
func count_devour() -> void:
	data.devoured_total = int(data.devoured_total) + 1


func count_felled(boss_name: String) -> void:
	if not boss_name in data.felled:
		data.felled.append(boss_name)
	save_game()


## Adds a run's discoveries to the Codex; written with the next save.
## `kills`: enemy name -> kills since the last call.
func note_codex(kills: Dictionary, upgrades: Array, essences: Array, resonances: Array) -> void:
	var codex: Dictionary = data.codex
	for key: String in ["enemies", "upgrades", "essences", "resonances"]:
		if not codex.has(key):
			codex[key] = {} if key == "enemies" else []
	for enemy_name: String in kills:
		codex.enemies[enemy_name] = int(codex.enemies.get(enemy_name, 0)) + int(kills[enemy_name])
	for pair: Array in [[upgrades, codex.upgrades], [essences, codex.essences], [resonances, codex.resonances]]:
		for item: String in pair[0]:
			if not item in pair[1]:
				pair[1].append(item)


## The hero has fallen; until a revive, the journey counts as lost.
func mark_fallen(day: int) -> void:
	data.fallen_day = day
	save_game()


func clear_fallen() -> void:
	data.fallen_day = 0
	save_game()


func record_ending(id: String) -> void:
	if not id in data.endings:
		data.endings.append(id)
		save_game()


## The journey is over: record it and clear the checkpoint.
func end_journey(day: int, won: bool) -> void:
	data.journey = null
	data.fallen_day = 0
	data.journeys = int(data.journeys) + 1
	if won:
		data.wins = int(data.wins) + 1
	data.best_day = maxi(int(data.best_day), day)
	save_game()
