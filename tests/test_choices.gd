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


func _weapon(main: Node, data: WeaponData) -> Weapon:
	for weapon: Weapon in main.player.weapons.get_children():
		if weapon.data == data:
			return weapon
	return null


func test_branches_open_at_lv3_and_lock_the_other() -> void:
	var main: Node = await start_run()
	var player: Player = main.player
	var light: WeaponData = load("res://data/weapons/goddess_light.tres")
	for i in 3:
		player.apply_upgrade(light)
	var offered := player.available_upgrades([light])
	check_eq(offered.size(), 2, "both branches offered at Lv 3")
	check(offered.all(func(u: Resource) -> bool: return u is BranchData), "as branch cards")
	var volley: BranchData = Branches.get_branch(light, "a")
	player.apply_upgrade(volley)
	check_eq(player.upgrade_level(light), 4, "Lv 4")
	check_eq(_weapon(main, light).branch_rank("a"), 1, "rank 1")
	check_eq(player.available_upgrades([light]), [volley], "only its own branch now")
	player.apply_upgrade(volley)
	check_eq(_weapon(main, light).branch_rank("a"), 2, "rank 2 at Lv 5")
	check(player.available_upgrades([light]).is_empty(), "maxed at Lv 5")
	await end_run(main)


func test_every_weapon_has_two_working_branches() -> void:
	for path: String in Branches.TABLE:
		var data: WeaponData = load(path)
		for branch: BranchData in Branches.of(data):
			var main: Node = await start_run()
			for i in 3:
				main.player.apply_upgrade(data)
			main.player.apply_upgrade(branch)
			main.player.apply_upgrade(branch)
			for i in 6:
				main.spawner.spawn_at(SpawnDirector.DREADLING, main.player.position + Vector2.from_angle(i) * 70.0)
			for frame in 90:
				main.player.set_invulnerable(1.0)
				await tree.physics_frame
			check_eq(_weapon(main, data).branch, branch.id, "%s took %s" % [data.display_name, branch.display_name])
			await end_run(main)


func test_rending_edge_bleeds_for_the_blade() -> void:
	var main: Node = await start_run()
	var blade: WeaponData = load("res://data/weapons/blade.tres")
	for i in 2:
		main.player.apply_upgrade(blade)
	main.player.apply_upgrade(Branches.get_branch(blade, "b"))
	var enemy: Enemy = main.spawner.spawn_at(SpawnDirector.WARDEN, main.player.position + Vector2(40, 0))
	for frame in 3:
		await tree.physics_frame  # the hitbox sees it only after a physics step
	var weapon := _weapon(main, blade)
	weapon._swing()
	check(enemy._burn_time > 0.0 and enemy._burn_source == "Blade", "bleeding, credited to the Blade")
	await end_run(main)


func test_branches_save_and_banish() -> void:
	var main: Node = await start_run()
	var bell: WeaponData = load("res://data/weapons/doom_bell.tres")
	for i in 3:
		main.player.apply_upgrade(bell)
	main.player.apply_upgrade(Branches.get_branch(bell, "b"))
	main.player.apply_upgrade(Branches.get_branch(bell, "b"))
	main.banished.append(Branches.get_branch(load("res://data/weapons/blade.tres"), "a"))
	Save.data.journey = JourneyRecord.snapshot(main)
	await end_run(main)
	main = await start_run(true)
	check_eq(main.player.upgrade_level(bell), 5, "Lv 5 restored")
	check_eq(_weapon(main, bell).branch_rank("b"), 2, "on Knell")
	check(Branches.get_branch(load("res://data/weapons/blade.tres"), "a") in main.banished, "banished branch restored")
	await end_run(main)


func test_mutation_is_the_same_essence_with_another_boost() -> void:
	var main: Node = await start_run()
	var player: Player = main.player
	var vexclaw: EssenceData = load("res://data/essences/vexclaw_essence.tres")
	var haste := player.stat("haste")
	var might := player.stat("might")
	var max_hp := player.stat("max_hp")
	player.add_essence(vexclaw, true)
	check_near(player.stat("haste"), haste + 0.15, 0.001, "Feral Reflexes: attack speed")
	check_near(player.stat("might"), might, 0.001, "not the classic might")
	check_near(player.stat("max_hp"), max_hp - 10.0, 0.001, "its own HP cost")
	check_eq(int(player.essences[vexclaw]), 1, "still counts as a Vexclaw essence")
	check_eq(int(player.mutations[vexclaw]), 1, "recorded as a mutation")
	await end_run(main)


func test_devour_offers_the_choice() -> void:
	var main: Node = await start_run()
	var hexeye: EssenceData = load("res://data/essences/hexeye_essence.tres")
	main.player.essence_taken.emit(hexeye)
	check(main.devour_choice.visible and tree.paused, "the choice pauses the run")
	main.devour_choice.pick(1)
	check_eq(int(main.player.mutations.get(hexeye, 0)), 1, "took the mutation")
	check(not tree.paused, "and resumes")
	await end_run(main)


func test_hunger_tiers_cost_and_pay() -> void:
	var main: Node = await start_run()
	var player: Player = main.player
	var dreadling: EssenceData = load("res://data/essences/dreadling_essence.tres")
	var rose := []
	player.hunger_rose.connect(func(tier: int) -> void: rose.append(tier))
	var might := player.stat("might")
	for i in 12:
		player.add_essence(dreadling)
	check_eq(player.hunger_tier(), 3, "12 Devours: Insatiable")
	check_eq(rose, [1, 2, 3], "announced each tier once")
	check_near(player.stat("might"), might + Hunger.MIGHT[3], 0.001, "the Hunger's strength, not stacked")
	player.hp = 1.0
	player.devour(dreadling)
	var healed := player.hp - 1.0
	check(healed < player.stat("max_hp") * Player.DEVOUR_HEAL * 0.3, "Devours barely heal")
	main.gold = 0
	main.shrine.open(5, main)
	await tree.process_frame
	check_eq(main.shrine.blessing_choices().size(), Hunger.BLESSINGS[3], "the goddess offers less")
	check_eq(main.revive_cost(), main.REVIVE_BASE_COST * 2, "and her revives cost double")
	main.shrine.skip()
	await end_run(main)


func test_mutations_save() -> void:
	var main: Node = await start_run()
	var warden: EssenceData = load("res://data/essences/warden_essence.tres")
	main.player.add_essence(warden, true)
	main.player.add_essence(warden, false)
	var defense: float = main.player.stat("defense")
	Save.data.journey = JourneyRecord.snapshot(main)
	await end_run(main)
	main = await start_run(true)
	check_eq(int(main.player.mutations.get(warden, 0)), 1, "one mutation restored")
	check_near(main.player.stat("defense"), defense, 0.001, "same stats")
	await end_run(main)


func test_stacking_one_essence_weakens() -> void:
	var main: Node = await start_run()
	var player: Player = main.player
	var vexclaw: EssenceData = load("res://data/essences/vexclaw_essence.tres")
	var gains := []
	for i in 5:
		var before: float = player.stat("might") - Hunger.MIGHT[player.hunger_tier()]
		player.add_essence(vexclaw)
		gains.append(snappedf(player.stat("might") - Hunger.MIGHT[player.hunger_tier()] - before, 0.001))
	check_eq(gains, [0.22, 0.22, 0.154, 0.11, 0.088], "full, full, 70%, 50%, 40%")
	await end_run(main)
