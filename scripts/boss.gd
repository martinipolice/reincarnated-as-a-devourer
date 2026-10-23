class_name Boss
extends Enemy
## The Demon King. Chases slowly, and every SLAM_INTERVAL seconds marks the
## ground under the player, then slams it for double damage. The terminal
## game's "charges every 5 turns" becomes a telegraph you dodge by moving.

signal slam_started

const FIRST_SLAM := 5.0
const SLAM_INTERVAL := 8.0
const SLAM_WINDUP := 2.25  # 1.5 felt too fast in playtesting
const SLAM_RADIUS := 150.0
const SLAM_DAMAGE_MULT := 2.0
const SLAM_FLASH := 0.25
const TELEGRAPH_COLOR := Color(1, 0.2, 0.2)
const OUTLINE_COLOR := Color(0.95, 0.8, 1.0)

var slam_at := Vector2.ZERO
var windup := 0.0

var _slam_timer := FIRST_SLAM
var _flash := 0.0
var _telegraph: Node2D


func _ready() -> void:
	super()
	# Drawn on its own top-level node: stays put while the boss moves, sits
	# under the enemies, and ignores the boss's hit flash.
	_telegraph = Node2D.new()
	_telegraph.top_level = true
	_telegraph.z_index = -1
	_telegraph.draw.connect(_draw_telegraph)
	add_child(_telegraph)


func _physics_process(delta: float) -> void:
	super(delta)
	if windup > 0.0:
		windup -= delta
		if windup <= 0.0:
			_slam()
	else:
		_slam_timer -= delta
		if _slam_timer <= 0.0 and is_instance_valid(target):
			_slam_timer = SLAM_INTERVAL
			windup = SLAM_WINDUP
			slam_at = target.global_position
			Game.sfx("boss_warn", 0.0)
			slam_started.emit()
	_flash = maxf(0.0, _flash - delta)
	_telegraph.queue_redraw()


func _slam() -> void:
	_flash = SLAM_FLASH
	Game.sfx("boss_slam")
	Game.shake(0.7)
	var player := target as Player
	if player and player.global_position.distance_to(slam_at) <= SLAM_RADIUS:
		player.take_damage(atk * SLAM_DAMAGE_MULT)


func _die() -> void:
	Game.burst(global_position, Color(1, 0.35, 0.3), 60, 320.0)
	Game.shake(1.0)
	super()


func _draw() -> void:
	super()
	# Placeholder only: the outline keeps the circle readable on his red telegraph.
	if data.sprite_frames == null:
		draw_arc(Vector2.ZERO, radius + 2.0, 0.0, TAU, 48, OUTLINE_COLOR, 3.0)


func _draw_telegraph() -> void:
	if windup > 0.0:
		var t := 1.0 - windup / SLAM_WINDUP
		_telegraph.draw_circle(slam_at, SLAM_RADIUS, Color(TELEGRAPH_COLOR, 0.1 + 0.2 * t))
		_telegraph.draw_arc(slam_at, SLAM_RADIUS * t, 0.0, TAU, 64, Color(TELEGRAPH_COLOR, 0.8), 3.0)
		_telegraph.draw_arc(slam_at, SLAM_RADIUS, 0.0, TAU, 64, Color(TELEGRAPH_COLOR, 0.9), 2.0)
	elif _flash > 0.0:
		_telegraph.draw_circle(slam_at, SLAM_RADIUS, Color(1, 0.5, 0.4, _flash / SLAM_FLASH * 0.6))
