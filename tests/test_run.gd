extends "res://tests/test_case.gd"
## The journey: starting weapons, spawning by day, mini-bosses, revives,
## resonances, evolutions, covenants, and the shrine checkpoint round trip.

const BLADE := preload("res://data/weapons/blade.tres")
const LIGHT := preload("res://data/weapons/goddess_light.tres")
const HUNGER := preload("res://data/items/hunger.tres")
const VEXCLAW_ESSENCE := preload("res://data/essences/vexclaw_essence.tres")
const DREADLING_ESSENCE := preload("res://data/essences/dreadling_essence.tres")


func test_starts_with_the_chosen_weapon_only_if_unlocked() -> void:
	Save.data.start_weapon = LIGHT.resource_path
	Save.data.best_day = 0
	var main: Node = await start_run()
	check_eq(main.player.upgrade_level(BLADE), 1, "locked choice falls back to the Blade")
	await end_run(main)
	Save.data.best_day = 10
	main = await start_run()
	check_eq(main.player.upgrade_level(LIGHT), 1, "unlocked choice is used")
	check_eq(main.player.upgrade_level(BLADE), 0, "and replaces the Blade")
	await end_run(main)


func test_spawn_table_by_day() -> void:
	var main: Node = await start_run()
	var seen := {}
	for i in 400:
		seen[main.spawner.pick_enemy()] = true
	check(not SpawnDirector.PLAGUEWING in seen, "no Plaguewings on Day 1")
	check(not SpawnDirector.WARDEN in seen, "no Wardens on Day 1")
	main.elapsed = 15 * main.SECONDS_PER_DAY
	seen.clear()
	for i in 1000:
		seen[main.spawner.pick_enemy()] = true
	check_eq(seen.size(), SpawnDirector.KINDS.size(), "every kind by Day 16")
	await end_run(main)


func test_mini_boss_arrives_on_day_10() -> void:
	var main: Node = await start_run()
	main.elapsed = 9 * main.SECONDS_PER_DAY + SpawnDirector.MINI_BOSS_DELAY - 1.0
	main.spawner.update(0.1)
	check(not is_instance_valid(main.mini_boss), "not before its delay")
	main.elapsed += 2.0
	main.spawner.update(0.1)
	check(is_instance_valid(main.mini_boss), "arrives after its delay")
	if is_instance_valid(main.mini_boss):
		check_eq(main.mini_boss.data.display_name, "Ruin Guardian", "the Day 10 guardian")
		main.spawner.update(0.1)
		check_eq(main.enemies.get_children().filter(func(e: Node) -> bool: return e is Boss).size(), 1, "only once")
	await end_run(main)


func test_revive_costs_double_and_accepting_ends_it() -> void:
	var main: Node = await start_run()
	check_eq(main.revive_cost(), 800, "first revive")
	main.revives = 2
	check_eq(main.revive_cost(), 3200, "third revive")
	main.revives = 0
	main.awaiting_revive = true
	main.gold = 100
	check(not main.revive(), "can't pay")
	main.gold = 900
	check(main.revive(), "pays")
	check_eq(main.gold, 100, "gold spent")
	check_eq(main.revive_cost(), 1600, "next one doubles")
	var journeys := int(Save.data.journeys)
	main.awaiting_revive = true
	main.accept_fate()
	check(main.over, "accepting ends the journey")
	check_eq(int(Save.data.journeys), journeys + 1, "and records it")
	check_eq(Save.data.journey, null, "no checkpoint left")
	await end_run(main)


func test_resonance_awakens_once() -> void:
	var main: Node = await start_run()
	var player: Player = main.player
	var might := player.stat("might")
	for i in 2:
		player.add_essence(VEXCLAW_ESSENCE)
	check(player.resonances.is_empty(), "needs both essences")
	for i in 3:
		player.add_essence(DREADLING_ESSENCE)
	check_eq(player.resonances, ["Predator's Pace"] as Array[String], "awakened once")
	var from_essences := 2 * VEXCLAW_ESSENCE.add if VEXCLAW_ESSENCE.stat == "might" else 0.0
	var hunger: float = Hunger.MIGHT[player.hunger_tier()]
	check_near(player.stat("might"), might + from_essences + 0.1 + hunger, 0.001, "its bonus applies")
	await end_run(main)


func test_blade_evolves_with_vexclaw_essences() -> void:
	var main: Node = await start_run()
	var player: Player = main.player
	player.apply_upgrade(BLADE)
	player.apply_upgrade(BLADE)
	for i in 3:
		player.add_essence(VEXCLAW_ESSENCE)
	var blade: Weapon
	for weapon: Weapon in player.weapons.get_children():
		if weapon.data == BLADE:
			blade = weapon
	check(blade != null and blade.evolved, "Lv 3 Blade + 3 Vexclaw essences evolves")
	await end_run(main)


func test_hunger_speeds_devour() -> void:
	var main: Node = await start_run()
	var player: Player = main.player
	var before := player._devour_time()
	for i in 3:
		player.apply_upgrade(HUNGER)
	check_near(player._devour_time(), before / 1.9, 0.001, "+30% per level")
	await end_run(main)


func test_frailty_covenant() -> void:
	var main: Node = await start_run()
	var player: Player = main.player
	var max_hp := player.stat("max_hp")
	main.set_covenant("frailty")
	check_near(player.stat("max_hp"), max_hp * 0.7, 0.01, "max HP -30%")
	main.set_covenant("")
	check_near(player.stat("max_hp"), max_hp, 0.01, "lifted at the next shrine")
	await end_run(main)


func test_shrine_checkpoint_round_trip() -> void:
	var main: Node = await start_run()
	var player: Player = main.player
	main.elapsed = 9 * main.SECONDS_PER_DAY + 3.0
	main.gold = 1234
	main.kills = 456
	main.revives = 1
	player.level = 12
	player.apply_upgrade(LIGHT)
	player.apply_upgrade(LIGHT)
	player.add_essence(VEXCLAW_ESSENCE)
	main.add_training(main.SHRINE.TRAININGS[0])
	main.set_covenant("blood")
	Enemy.damage_log = {"Blade": 999.0}
	main.best_rank = 4
	Save.data.journey = JourneyRecord.snapshot(main)
	var max_hp := player.stat("max_hp")
	await end_run(main)

	main = await start_run(true)
	player = main.player
	check_eq(main.day(), 10, "same day")
	check_eq(main.gold, 1234, "gold")
	check_eq(main.kills, 456, "kills")
	check_eq(main.revive_cost(), 1600, "revives")
	check_eq(player.level, 12, "level")
	check_eq(player.upgrade_level(LIGHT), 2, "upgrades")
	check_eq(int(player.essences.get(VEXCLAW_ESSENCE, 0)), 1, "essences")
	check_eq(int(main.training_ranks.get(main.SHRINE.TRAININGS[0].id, 0)), 1, "training")
	check_eq(main.covenant, "blood", "covenant")
	check_near(player.stat("max_hp"), max_hp, 0.01, "max HP")
	check_near(float(Enemy.damage_log.get("Blade", 0.0)), 999.0, 0.01, "damage log")
	check_eq(main.best_rank, 4, "best style")
	check_eq(main.world.biome, "ruins", "the ruins from Day 10")
	check_eq(main.next_shrine_day(), 15, "Day 10's shrine is done")
	await end_run(main)


func test_a_busy_day_plays_without_errors() -> void:
	var main: Node = await start_run()
	var player: Player = main.player
	main.elapsed = 13 * main.SECONDS_PER_DAY + 70.0 - main.SECONDS_PER_DAY  # Day 13, events due
	main.loot._chest_timer = 0.0
	for i in 8:
		main.spawner.spawn_at(SpawnDirector.DREADLING, player.position + Vector2.from_angle(i) * 60.0)
	var until: float = main.elapsed + 6.0  # game seconds: headless frames run faster than real time
	var frames := 0
	while main.elapsed < until and frames < 20000:
		frames += 1
		player.set_invulnerable(1.0)
		if main.level_up.visible:
			main.level_up.pick(0)
		if main.shrine.visible:
			main.shrine.skip()
		await tree.physics_frame
	check(main.enemies.get_child_count() > 10, "the horde spawned")
	check(main.kills > 0, "and is being killed")
	check(not tree.get_nodes_in_group("chests").is_empty() or main.loot._revealing, "a chest appeared")
	await end_run(main)


func test_hunger_waits_for_the_first_devour() -> void:
	var main: Node = await start_run()
	check(not HUNGER in main.upgrade_pool(), "not offered before Devouring")
	main.player.add_essence(VEXCLAW_ESSENCE)
	check(HUNGER in main.upgrade_pool(), "offered after")
	await end_run(main)


func test_ambience_follows_the_area_and_loops() -> void:
	var main: Node = await start_run()
	main.music.update(0.1)
	var ambience: Ambience = main.music._ambience
	check_eq(ambience._bed, "forest", "forest bed on Day 1")
	var player: AudioStreamPlayer = ambience._players[ambience._current]
	check(player.playing, "playing")
	check_eq((player.stream as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD, "loops")
	main.world.biome = "ruins"
	main.music.update(0.1)
	check_eq(ambience._bed, "ruins", "ruins bed")
	for sound: String in ["warn_pounce", "warn_hex", "warn_glob", "warn_charge"]:
		check(not Game._streams.get(sound, []).is_empty(), "%s loaded" % sound)
	await end_run(main)
