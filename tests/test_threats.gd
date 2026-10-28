extends "res://tests/test_case.gd"
## Tier 2 threats: the Necro-acolyte raising the fallen, the Burrower's
## underground strike, and plague puddles drying up.


func _frames(count: int, main: Node) -> void:
	for i in count:
		main.player.set_invulnerable(1.0)
		await tree.physics_frame


func test_acolyte_raises_the_fallen() -> void:
	var main: Node = await start_run()
	var player: Player = main.player
	var acolyte: Enemy = main.spawner.spawn_at(SpawnDirector.ACOLYTE, player.position + Vector2(260, 0))
	acolyte._cooldown = 0.0  # ready to channel at once
	var body := player.position + Vector2(200, 60)
	Enemy.fallen.append([body, SpawnDirector.DREADLING, Enemy.clock()])
	var before: int = main.enemies.get_child_count()
	await _frames(15, main)
	check_eq(acolyte.state, Enemy.State.WINDUP, "channels into the body")
	await _frames(int(Enemy.RAISE_CHANNEL * 60) + 5, main)
	var risen: Array = main.enemies.get_children().filter(func(e: Node) -> bool: return e is Enemy and e.risen)
	check_eq(risen.size(), 1, "one risen")
	check(main.enemies.get_child_count() > before, "it joined the fight")
	if not risen.is_empty():
		var gold: int = main.gold
		risen[0].take_damage(1e9)
		await tree.process_frame
		check_eq(main.gold, gold, "the risen pay no gold")
	await end_run(main)


func test_killing_the_acolyte_stops_the_raise() -> void:
	var main: Node = await start_run()
	var player: Player = main.player
	var acolyte: Enemy = main.spawner.spawn_at(SpawnDirector.ACOLYTE, player.position + Vector2(260, 0))
	acolyte._cooldown = 0.0  # ready to channel at once
	Enemy.fallen.append([player.position + Vector2(200, 60), SpawnDirector.DREADLING, Enemy.clock()])
	await _frames(15, main)
	acolyte.take_damage(1e9)
	await _frames(int(Enemy.RAISE_CHANNEL * 60) + 5, main)
	var risen: Array = main.enemies.get_children().filter(func(e: Node) -> bool: return e is Enemy and e.risen)
	check(risen.is_empty(), "nothing rises")
	await end_run(main)


func test_burrower_strikes_from_below() -> void:
	var main: Node = await start_run()
	var player: Player = main.player
	var burrower: Enemy = main.spawner.spawn_at(SpawnDirector.BURROWER, player.position + Vector2(200, 0))
	await _frames(3, main)
	check(not burrower.is_in_group("enemies") and burrower.collision_layer == 0, "untouchable underground")
	var frames := 0
	while burrower.state != Enemy.State.WINDUP and frames < 300:
		await _frames(1, main)
		frames += 1
	check_eq(burrower.state, Enemy.State.WINDUP, "cracks the ground under you")
	check(burrower.burrow_warning().distance_to(player.global_position) < Enemy.BURROW_STRIKE + 5.0, "under you")
	player.set_invulnerable(0.0)
	var hp := player.hp
	for i in int(Enemy.BURROW_WINDUP * 60) + 3:
		await tree.physics_frame
	check(burrower.is_in_group("enemies") and burrower.collision_layer == 2, "up and hittable")
	check(player.hp < hp, "erupting under you hurts")
	await _frames(int(Enemy.SURFACE_TIME * 60) + 5, main)
	check(not burrower.is_in_group("enemies"), "and back under")
	await end_run(main)


func test_puddles_dry_up() -> void:
	var puddle: PlaguePuddle = load("res://scenes/plague_puddle.tscn").instantiate()
	puddle.setup(10.0)
	var fresh := puddle.radius()
	puddle._life = 0.0
	check_near(puddle.radius(), fresh * 0.55, 0.01, "shrinks to 55%")
	puddle.free()
