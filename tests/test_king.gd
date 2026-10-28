extends "res://tests/test_case.gd"
## The Demon King: three phases, the mirror, pillars and cover.


func _king(main: Node) -> Boss:
	main.elapsed = 19 * main.SECONDS_PER_DAY + 0.5
	await tree.process_frame
	await tree.process_frame
	return main.boss


func test_three_phases() -> void:
	var main: Node = await start_run()
	var king: Boss = await _king(main)
	check(king != null and king.king, "the Demon King is crowned")
	var phases := []
	king.phase_changed.connect(func(p: int) -> void: phases.append(p))
	king.hp = king.max_hp * 0.6
	for i in 4:
		await tree.physics_frame
	check_eq(king.phase, 1, "fury below two thirds")
	check(Boss.Attack.CHARGE in king.attacks, "he charges now")
	king.hp = king.max_hp * 0.3
	for i in 4:
		await tree.physics_frame
	check_eq(king.phase, 2, "the mirror below one third")
	check(Boss.Attack.MIRROR in king.attacks, "and mirrors")
	check_eq(phases, [1, 2], "each announced once")
	await end_run(main)


func test_the_mirror_wears_your_hunger() -> void:
	var main: Node = await start_run()
	var hexeye: EssenceData = load("res://data/essences/hexeye_essence.tres")
	for i in 5:
		main.player.add_essence(hexeye)
	main.player.add_essence(load("res://data/essences/vexclaw_essence.tres"))
	var king: Boss = await _king(main)
	check_eq(king.mirror, hexeye, "your most-Devoured essence")
	var atk := king.atk
	king.hp = king.max_hp * 0.3
	for i in 6:
		await tree.physics_frame
	check_near(king.atk, atk * 1.18, 0.5, "stronger by 3% per Devour")
	var bolts := tree.get_nodes_in_group("enemy_shots").size()
	king._mirror_attack()
	check(tree.get_nodes_in_group("enemy_shots").size() >= bolts + 5, "a fan of hexes")
	await end_run(main)


func test_cover_and_crumbling_pillars() -> void:
	var main: Node = await start_run()
	var king: Boss = await _king(main)
	await tree.process_frame
	var pillar: Dictionary = {}
	for i in 20:
		await tree.process_frame
	for key: Vector2i in main.world._chunks:
		for handle: Dictionary in main.world._chunks[key].obstacles:
			if handle.get("pillar", false):
				pillar = handle
				break
	check(not pillar.is_empty(), "the arena has pillars")
	if pillar.is_empty():
		await end_run(main)
		return
	var orb: BossOrb = load("res://scenes/boss_orb.tscn").instantiate()
	orb.setup(Vector2.RIGHT, 10.0)
	orb.position = pillar.center - Vector2(30, 0)
	main.add_child(orb)
	for i in 20:
		await tree.physics_frame
	check(not is_instance_valid(orb), "a pillar stops an orb")
	check(main.world.crumble(pillar.center, 40.0) >= 1, "a slam breaks it")
	check(not Obstacles.blocked(pillar.center, 1.0), "and it no longer blocks")
	await end_run(main)
