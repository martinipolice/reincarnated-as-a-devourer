extends "res://tests/test_case.gd"
## Damage math, shields, the damage log, slows and burns, on real enemies.

var _main: Node


func before_each() -> void:
	super()
	_main = await start_run()


func after_each() -> void:
	await end_run(_main)
	super()


func _enemy(data: EnemyData) -> Enemy:
	var enemy: Enemy = _main.spawner.spawn_at(data, _main.player.position + Vector2(400, 0))
	enemy.process_mode = Node.PROCESS_MODE_DISABLED  # holds still for the test
	return enemy


func test_mitigation_formula() -> void:
	check_near(Game.damage(100.0, 0.0), 100.0, 0.001, "no defense")
	check_near(Game.damage(100.0, 100.0), 50.0, 0.001, "100 defense halves")
	check(Game.damage(10.0, 500.0) > 0.0, "never zero, unlike ATK - DEF")


func test_damage_is_logged_by_source() -> void:
	Enemy.damage_log.clear()
	var enemy := _enemy(SpawnDirector.DREADLING)
	var hp := enemy.hp
	enemy.take_damage(10.0, Vector2.ZERO, "", "Blade")
	var dealt := Game.damage(10.0, enemy.data.defense)
	check_near(hp - enemy.hp, dealt, 0.01, "hp lost")
	check_near(float(Enemy.damage_log.Blade), dealt, 0.01, "logged")
	enemy.take_damage(1e6, Vector2.ZERO, "", "Bomb")
	check_near(float(Enemy.damage_log.Bomb), hp - dealt, 0.01, "overkill logs only the hp left")


func test_warden_shield_soaks_most_of_a_hit() -> void:
	var enemy := _enemy(SpawnDirector.WARDEN)
	var shield := enemy.shield_hp
	var hp := enemy.hp
	check(shield > 0.0, "spawns shielded")
	enemy.take_damage(40.0)
	var dealt := Game.damage(40.0, enemy.data.defense)
	check_near(shield - enemy.shield_hp, dealt * Enemy.SHIELD_SOAK, 0.01, "shield soaks")
	check_near(hp - enemy.hp, dealt * (1.0 - Enemy.SHIELD_SOAK), 0.01, "the rest gets through")


func test_slow_keeps_the_strongest() -> void:
	var enemy := _enemy(SpawnDirector.DREADLING)
	var speed := enemy.move_speed()
	enemy.slow(0.5, 1.0)
	enemy.slow(0.8, 2.0)
	check_near(enemy.move_speed(), speed * 0.5, 0.01, "the stronger slow wins")


func test_toughness_grows_by_day() -> void:
	check_near(_main.toughness(), 1.0, 0.001, "Day 1")
	_main.elapsed = 19 * _main.SECONDS_PER_DAY
	check_near(_main.toughness(), 1.0 + 19 * SpawnDirector.TOUGHNESS_PER_DAY, 0.001, "Day 20")
