extends "res://tests/test_case.gd"
## Points of interest: placement by day, and what each landmark does.


# Stands the hero at `at` for `seconds` of real time (landmarks run on it).
func _walk_to(main: Node, at: Vector2, seconds: float) -> void:
	var until := Time.get_ticks_msec() + seconds * 1000.0
	while Time.get_ticks_msec() < until:
		main.player.global_position = at
		main.player.set_invulnerable(1.0)
		await tree.process_frame


func test_landmarks_appear_by_day() -> void:
	var main: Node = await start_run()
	main.landmarks._on_day(1, 20, 5)
	check(tree.get_nodes_in_group("landmarks").is_empty(), "none on Day 1")
	main.landmarks._on_day(3, 20, 5)
	check_eq(tree.get_nodes_in_group("landmarks").size(), 1, "one on Day 3")
	main.landmarks._on_day(9, 20, 10)
	check_eq(tree.get_nodes_in_group("landmarks").size(), Landmarks.MAX_ACTIVE, "two more from Day 8, capped")
	await end_run(main)


func test_well_trades_blood_for_gold() -> void:
	var main: Node = await start_run()
	var well: Landmark = main.landmarks.place("well", main.player.position + Vector2(300, 0))
	var hp: float = main.player.hp
	var gold: int = main.gold
	await _walk_to(main, well.global_position, Landmark.WELL_TIME + 0.3)
	check(well.spent, "used")
	check_near(main.player.hp, hp * (1.0 - Landmarks.WELL_SHARE), 1.0, "a fifth of your HP")
	check_eq(main.gold, gold + Landmarks.WELL_GOLD_PER_DAY, "gold by the day")
	await end_run(main)


func test_cage_frees_a_traited_elite() -> void:
	var main: Node = await start_run()
	var cage: Landmark = main.landmarks.place("cage", main.player.position + Vector2(400, 0))
	await _walk_to(main, cage.global_position + Vector2(100, 0), 0.1)
	var elites: Array = main.enemies.get_children().filter(func(e: Node) -> bool: return e is Enemy and e.elite)
	check_eq(elites.size(), 1, "an elite is free")
	if not elites.is_empty():
		check(elites[0].affix != "", "with a trait")
	await end_run(main)


func test_grave_gives_a_boon() -> void:
	var main: Node = await start_run()
	var grave: Landmark = main.landmarks.place("grave", main.player.position + Vector2(300, 0))
	await _walk_to(main, grave.global_position, 0.1)
	check(grave.spent, "used once")
	await end_run(main)


func test_altar_trial_won_and_lost() -> void:
	var main: Node = await start_run()
	var altar: Landmark = main.landmarks.place("altar", main.player.position + Vector2(300, 0))
	var before: int = main.enemies.get_child_count()
	await _walk_to(main, altar.global_position, 1.0)
	check(altar.trial >= 0.0, "stepping in starts the trial")
	check(main.enemies.get_child_count() > before, "a surge came")
	altar.trial = Landmark.ALTAR_TIME - 0.05
	await _walk_to(main, altar.global_position, 0.2)
	check(main.landmarks._pick.visible, "won: the reward pick opens")
	var might: float = main.player.stat("might")
	main.landmarks._pick.picked.disconnect(main.landmarks._pick.picked.get_connections()[0].callable)
	main.landmarks._pick.pick(0)
	main.landmarks.grant("edge")
	check_near(main.player.stat("might"), might + 0.08, 0.001, "Altar's Edge")
	var second: Landmark = main.landmarks.place("altar", main.player.position + Vector2(600, 0))
	await _walk_to(main, second.global_position, 0.1)
	await _walk_to(main, second.global_position + Vector2(400, 0), Landmark.ALTAR_GRACE + 0.3)
	check(second.spent and not main.landmarks._pick.visible, "leaving the circle fails it")
	await end_run(main)


func test_altar_rewards_survive_a_save() -> void:
	var main: Node = await start_run()
	main.landmarks.grant("ward")
	var defense: float = main.player.stat("defense")
	Save.data.journey = JourneyRecord.snapshot(main)
	await end_run(main)
	main = await start_run(true)
	check_near(main.player.stat("defense"), defense, 0.001, "Altar's Ward restored")
	await end_run(main)


func test_landmarks_end_when_the_duel_begins() -> void:
	var main: Node = await start_run()
	var altar: Landmark = main.landmarks.place("altar", main.player.position + Vector2(200, 0))
	main.elapsed = 19 * main.SECONDS_PER_DAY + 0.5
	for i in 5:
		await tree.process_frame
	check(main.boss_spawned, "the Demon King arrived")
	var before: int = main.enemies.get_child_count()
	await _walk_to(main, main.player.position + Vector2(200, 0), 1.0)
	check(not is_instance_valid(altar) or altar.spent, "the altar is gone or spent")
	check_eq(main.enemies.get_child_count(), before, "no surge in the duel")
	await end_run(main)


func test_names_hide_under_an_area_title() -> void:
	var main: Node = await start_run()
	var grave: Landmark = main.landmarks.place("grave", main.player.position + Vector2(150, 0))
	main.moments.area_card("The Fallen Ruins")
	await _walk_to(main, main.player.position, main.moments.CARD_FADE + 0.2)
	check(main.moments.card_showing(), "the area title is up")
	check(grave._label == null or not grave._label.visible, "the landmark's name hides under it")
	await _walk_to(main, main.player.position, main.moments.CARD_HOLD + main.moments.CARD_FADE + 0.4)
	check(grave._label != null and grave._label.visible, "and shows once it fades")
	await end_run(main)
