extends "res://tests/test_case.gd"
## Tier 1 choices: reroll, banish and skip at level-ups, and the threads of
## fate the goddess sells.


func _level_up(main: Node) -> void:
	main.player.pending_level_ups = 1
	main._offer_next_level_up()


func test_reroll_deals_a_new_hand_and_spends_a_charge() -> void:
	var main: Node = await start_run()
	_level_up(main)
	var before: Array = main.level_up.offers.duplicate()
	main.level_up.rerolled.emit()
	check_eq(main.rerolls, main.START_REROLLS - 1, "a charge spent")
	check_eq(main.level_up.offers.size(), 3, "still three cards")
	check(main.level_up.visible and tree.paused, "still choosing")
	main.rerolls = 0
	main.level_up.rerolled.emit()
	check_eq(main.rerolls, 0, "no charge, no reroll")
	check(before.size() == 3, "dealt three before")
	main.level_up.pick(0)
	await end_run(main)


func test_banish_removes_it_for_the_journey() -> void:
	var main: Node = await start_run()
	_level_up(main)
	var gone: Resource = main.level_up.offers[1]
	main.level_up._toggle_banish()
	main.level_up.pick(1)
	check_eq(main.banishes, main.START_BANISHES - 1, "a charge spent")
	check(gone in main.banished, "recorded")
	check(not gone in main.level_up.offers, "replaced on the table")
	check_eq(main.level_up.offers.size(), 3, "still three cards")
	check(not gone in main.upgrade_pool(), "never offered again")
	main.level_up.pick(0)
	await end_run(main)


func test_skip_pays_gold() -> void:
	var main: Node = await start_run()
	main.elapsed = 4 * main.SECONDS_PER_DAY
	_level_up(main)
	var gold: int = main.gold
	main.level_up._skip.pressed.emit()
	check_eq(main.gold, gold + main.SKIP_GOLD_PER_DAY * 5, "gold by the day")
	check(not main.level_up.visible and not tree.paused, "back to the fight")
	await end_run(main)


func test_threads_of_fate_and_saving_them() -> void:
	var main: Node = await start_run()
	main.gold = 1000
	main.shrine.open(5, main)
	await tree.process_frame
	main.shrine._buy_fate(main.shrine.FATE[0])
	main.shrine._buy_fate(main.shrine.FATE[1])
	check_eq(main.rerolls, main.START_REROLLS + 1, "bought a reroll")
	check_eq(main.banishes, main.START_BANISHES + 1, "bought a banish")
	check_eq(main.gold, 1000 - 150 - 250, "paid")
	main.banished.append(load("res://data/items/fury.tres"))
	Save.data.journey = JourneyRecord.snapshot(main)
	main.shrine.skip()
	await end_run(main)
	main = await start_run(true)
	check_eq(main.rerolls, main.START_REROLLS + 1, "rerolls saved")
	check_eq(main.banishes, main.START_BANISHES + 1, "banishes saved")
	check_eq(main.banished.size(), 1, "banished saved")
	await end_run(main)
