extends "res://tests/test_case.gd"
## Save records, migration, the Codex and starting-weapon unlocks.


func test_never_writes_the_real_save() -> void:
	check(not Save.persistent(), "tests must run with saving off")


func test_old_saves_keep_their_records() -> void:
	var migrated: Dictionary = Save._migrate({"runs": 7, "wins": 2, "best_day": 14, "gold": 900})
	check_eq(migrated.journeys, 7, "v1 runs become journeys")
	check_eq(migrated.wins, 2, "wins kept")
	check_eq(migrated.best_day, 14, "best day kept")
	check(not migrated.has("gold"), "banked gold is dropped")
	check_eq(migrated.version, Save.VERSION, "version bumped")
	for key: String in Save.defaults():
		check(migrated.has(key), "new field %s filled in" % key)


func test_end_journey_records_and_clears() -> void:
	Save.data = Save.defaults()
	Save.data.journey = {"day": 5}
	Save.mark_fallen(8)
	Save.end_journey(8, false)
	check_eq(Save.data.journey, null, "checkpoint cleared")
	check_eq(int(Save.data.fallen_day), 0, "fallen mark cleared")
	check_eq(int(Save.data.journeys), 1, "journey counted")
	check_eq(int(Save.data.best_day), 8, "best day")
	Save.end_journey(20, true)
	check_eq(int(Save.data.wins), 1, "victory counted")
	check_eq(int(Save.data.best_day), 20, "best day rises")
	Save.end_journey(3, false)
	check_eq(int(Save.data.best_day), 20, "best day never falls")


func test_codex_merges_without_duplicates() -> void:
	Save.data = Save.defaults()
	Save.note_codex({"Dreadling": 10}, ["res://a"], ["res://e"], ["Iron Rot"])
	Save.note_codex({"Dreadling": 5, "Warden": 1}, ["res://a", "res://b"], ["res://e"], ["Iron Rot"])
	var codex: Dictionary = Save.data.codex
	check_eq(int(codex.enemies.Dreadling), 15, "kills add up")
	check_eq(int(codex.enemies.Warden), 1, "new monster")
	check_eq(codex.upgrades.size(), 2, "upgrades deduplicated")
	check_eq(codex.essences.size(), 1, "essences deduplicated")
	check_eq(codex.resonances.size(), 1, "resonances deduplicated")


func test_codex_survives_a_save_without_it() -> void:
	Save.data = Save._migrate({"version": 2, "journeys": 1})
	Save.note_codex({"Hexeye": 2}, [], [], [])
	check_eq(int(Save.data.codex.enemies.Hexeye), 2, "codex created on old saves")


func test_unlocks() -> void:
	var fresh := Save.defaults()
	check_eq(Unlocks.unlocked(fresh), ["res://data/weapons/blade.tres"] as Array[String], "only the Blade at first")
	var records := Save.defaults()
	records.best_day = 10
	records.devoured_total = 15
	records.felled = ["Hollow Spirit"]
	var paths := Unlocks.unlocked(records)
	check("res://data/weapons/goddess_light.tres" in paths, "Day 10 unlocks Goddess Light")
	check(not "res://data/weapons/aegis.tres" in paths, "Aegis needs Day 19")
	check("res://data/weapons/maw.tres" in paths, "15 essences unlock the Maw")
	check("res://data/weapons/doom_bell.tres" in paths, "the Hollow Spirit unlocks the Doom Bell")
	check(not "res://data/weapons/chains.tres" in paths, "Chains need the Ruin Guardian")


func test_lifetime_counters() -> void:
	Save.data = Save.defaults()
	Save.count_devour()
	Save.count_devour()
	Save.count_felled("Ruin Guardian")
	Save.count_felled("Ruin Guardian")
	check_eq(int(Save.data.devoured_total), 2, "devours counted")
	check_eq(Save.data.felled.size(), 1, "a mini-boss is felled once")
