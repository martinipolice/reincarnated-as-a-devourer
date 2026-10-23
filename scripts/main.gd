extends Node2D
## Run controller: the day clock, the spawn director, level-ups, the HUD and
## game over.

const SECONDS_PER_DAY := 30.0  # MVP: 20 days in 10 minutes
const FINAL_DAY := 20
const SPAWN_RADIUS := 700.0
const GRACE_PERIOD := 2.0  # seconds before the first spawn
const GRID_SIZE := 64
const GRID_EXTENT := 4096

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const GEM_SCENE := preload("res://scenes/xp_gem.tscn")
const DREADLING := preload("res://data/enemies/dreadling.tres")
const VEXCLAW := preload("res://data/enemies/vexclaw.tres")
const PLAGUEWING := preload("res://data/enemies/plaguewing.tres")

const STARTING_WEAPON := preload("res://data/weapons/blade.tres")
## Offered when everything in the pool is maxed.
const FALLBACK_UPGRADE := preload("res://data/items/panacea.tres")
## Everything the level-up screen can offer.
const UPGRADE_POOL := [
	preload("res://data/weapons/blade.tres"),
	preload("res://data/weapons/goddess_light.tres"),
	preload("res://data/weapons/aegis.tres"),
	preload("res://data/items/wooden_guard.tres"),
	preload("res://data/items/leather_treads.tres"),
	preload("res://data/items/stamina.tres"),
]
const OFFERS_PER_LEVEL := 3

var elapsed := 0.0
var kills := 0
var gold := 0
var _spawn_timer := GRACE_PERIOD
var _over := false

@onready var player: Player = $Player
@onready var enemies: Node2D = $Enemies
@onready var pickups: Node2D = $Pickups
@onready var level_up: CanvasLayer = $LevelUp
@onready var info_label: Label = $HUD/Info
@onready var xp_bar: ProgressBar = $HUD/XPBar
@onready var center_label: Label = $HUD/Center


func _ready() -> void:
	Game.enemy_killed.connect(_on_enemy_killed)
	player.died.connect(_on_player_died)
	player.leveled_up.connect(_on_player_leveled_up)
	level_up.chosen.connect(_on_upgrade_chosen)
	player.apply_upgrade(STARTING_WEAPON)
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
		_spawn_timer = maxf(0.35, 1.3 - day() * 0.05)
		# Bigger packs as the days pass: 1 per spawn on Days 1-4, 2 on 5-9, ...
		for i in 1 + day() / 5:
			_spawn_enemy()

	_update_hud()


func _update_hud() -> void:
	info_label.text = "DAY %d / %d     Lv %d\nHP %d / %d\nKills %d   Gold %d" % [
		day(), FINAL_DAY, player.level, ceili(player.hp), player.stat("max_hp"), kills, gold]
	xp_bar.max_value = player.xp_to_next()
	xp_bar.value = player.xp


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


func _on_enemy_killed(data: EnemyData, at: Vector2) -> void:
	kills += 1
	gold += data.gold
	var gem := GEM_SCENE.instantiate() as XPGem
	gem.setup(data.xp, player)
	gem.position = at
	pickups.add_child.call_deferred(gem)


func _on_player_leveled_up() -> void:
	if not level_up.visible:
		_offer_next_level_up()


func _on_upgrade_chosen(upgrade: Resource) -> void:
	player.apply_upgrade(upgrade)
	_offer_next_level_up()


# Shows one level-up screen per pending level, one after another.
func _offer_next_level_up() -> void:
	if _over or player.pending_level_ups == 0:
		return
	player.pending_level_ups -= 1
	var offers := player.available_upgrades(UPGRADE_POOL)
	offers.shuffle()
	offers.resize(mini(OFFERS_PER_LEVEL, offers.size()))
	if offers.is_empty():
		offers = [FALLBACK_UPGRADE]
	_update_hud()  # the HUD freezes while paused, so show the new level now
	level_up.open(offers, player)


func _on_player_died() -> void:
	_end_run("You have fallen in battle...\nThe cycle remains unbroken.")


func _end_run(message: String) -> void:
	_over = true
	_update_hud()
	enemies.process_mode = Node.PROCESS_MODE_DISABLED
	center_label.text = "%s\n\nSurvived to Day %d  -  Level %d  -  %d kills\n\nPress R to try again" % [
		message, day(), player.level, kills]
	center_label.show()


func _draw() -> void:
	var color := Color(1, 1, 1, 0.04)
	for i in range(-GRID_EXTENT, GRID_EXTENT + 1, GRID_SIZE):
		draw_line(Vector2(i, -GRID_EXTENT), Vector2(i, GRID_EXTENT), color)
		draw_line(Vector2(-GRID_EXTENT, i), Vector2(GRID_EXTENT, i), color)
