extends Node2D
## Run controller: the day clock, the spawn director, the HUD and game over.

const SECONDS_PER_DAY := 30.0  # MVP: 20 days in 10 minutes
const FINAL_DAY := 20
const SPAWN_RADIUS := 700.0
const GRID_SIZE := 64
const GRID_EXTENT := 4096

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const DREADLING := preload("res://data/enemies/dreadling.tres")
const VEXCLAW := preload("res://data/enemies/vexclaw.tres")
const PLAGUEWING := preload("res://data/enemies/plaguewing.tres")

var elapsed := 0.0
var kills := 0
var gold := 0
var _spawn_timer := 0.0
var _over := false

@onready var player: Player = $Player
@onready var enemies: Node2D = $Enemies
@onready var info_label: Label = $HUD/Info
@onready var center_label: Label = $HUD/Center


func _ready() -> void:
	Game.enemy_killed.connect(_on_enemy_killed)
	player.died.connect(_on_player_died)
	center_label.hide()


func day() -> int:
	return mini(int(elapsed / SECONDS_PER_DAY) + 1, FINAL_DAY)


func _process(delta: float) -> void:
	if _over:
		if Input.is_action_just_pressed("restart"):
			get_tree().reload_current_scene()
		return

	elapsed += delta
	if day() >= FINAL_DAY:
		_end_run("DAY 20\nThe Demon King awaits... (boss comes in Milestone 4)")
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = maxf(0.25, 1.2 - day() * 0.05)
		_spawn_enemy()

	info_label.text = "DAY %d / %d\nHP %d / %d\nKills %d   Gold %d" % [
		day(), FINAL_DAY, ceili(player.hp), player.stat("max_hp"), kills, gold]


# Weights ported from explore(), keyed by day instead of total stats.
# The original allowed 5% Plaguewings from the start; that is brutal in real
# time, so early days skip them. Tune freely.
func _pick_enemy() -> EnemyData:
	var weights: Array
	if day() < 6:
		weights = [90, 10, 0]
	elif day() < 12:
		weights = [45, 45, 10]
	else:
		weights = [35, 35, 30]
	var roll := randi_range(1, 100)
	if roll <= weights[0]:
		return DREADLING
	if roll <= weights[0] + weights[1]:
		return VEXCLAW
	return PLAGUEWING


func _spawn_enemy() -> void:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.setup(_pick_enemy(), player)
	enemy.position = player.position + Vector2.RIGHT.rotated(randf() * TAU) * SPAWN_RADIUS
	enemies.add_child(enemy)


func _on_enemy_killed(data: EnemyData, _at: Vector2) -> void:
	kills += 1
	gold += data.gold


func _on_player_died() -> void:
	_end_run("You have fallen in battle...\nThe cycle remains unbroken.")


func _end_run(message: String) -> void:
	_over = true
	enemies.process_mode = Node.PROCESS_MODE_DISABLED
	center_label.text = "%s\n\nSurvived to Day %d  -  %d kills\n\nPress R to try again" % [
		message, day(), kills]
	center_label.show()


func _draw() -> void:
	var color := Color(1, 1, 1, 0.04)
	for i in range(-GRID_EXTENT, GRID_EXTENT + 1, GRID_SIZE):
		draw_line(Vector2(i, -GRID_EXTENT), Vector2(i, GRID_EXTENT), color)
		draw_line(Vector2(-GRID_EXTENT, i), Vector2(GRID_EXTENT, i), color)
