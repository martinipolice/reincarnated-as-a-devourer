class_name Boss
extends Enemy
## The Demon King: a one-on-one duel (main.gd clears the swarm when he
## arrives). He chases slowly and alternates two telegraphed attacks:
## - Slam: marks the ground under you, then hits it for double damage
##   (the terminal game's "charges every 5 turns").
## - Dark volley: stops, gathers power, then fires a ring of orbs to dodge.
## He also summons a few minions now and then (XP and a little chaos).
## Below half HP he enrages: faster, bigger slams, denser volleys.

signal slam_started
signal enraged
## Asks the run to spawn `count` minions around `at`; true in phase 2.
signal summon(at: Vector2, count: int, phase_two: bool)

enum Attack { SLAM, VOLLEY }

const ORB_SCENE := preload("res://scenes/boss_orb.tscn")
const FIRST_ATTACK := 4.0
const ATTACK_GAP := [3.5, 2.9]  # seconds between attacks, by phase
const SLAM_WINDUP := 2.25  # 1.5 felt too fast in playtesting
const SLAM_RADIUS := [150.0, 185.0]
const SLAM_DAMAGE_MULT := 1.6  # 2.0 felt too punishing in playtesting
const SLAM_FLASH := 0.25
const VOLLEY_WINDUP := [0.9, 0.7]
const VOLLEY_ORBS := [12, 14]
const VOLLEY_WAVES := [1, 2]  # phase 2 fires a second, offset ring
const VOLLEY_WAVE_GAP := 0.35
const ORB_DAMAGE_MULT := 0.6
const SUMMON_INTERVAL := [12.0, 9.0]
const SUMMON_COUNT := 4
const ENRAGE_AT := 0.5  # fraction of max HP
const ENRAGED_SPEED_MULT := 1.35
const TELEGRAPH_COLOR := Color(1, 0.2, 0.2)
const VOLLEY_COLOR := Color(0.75, 0.35, 1.0)
const OUTLINE_COLOR := Color(0.95, 0.8, 1.0)

## Slam target and remaining wind-up; read by tools/balance_sim.gd's bot too.
var slam_at := Vector2.ZERO
var slam_radius: float = SLAM_RADIUS[0]
var windup := 0.0
var phase := 0  # 0 = normal, 1 = enraged

var _next_attack := FIRST_ATTACK
var _next_summon: float = SUMMON_INTERVAL[0]
var _next_kind := Attack.SLAM
var _volley_windup := 0.0
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
	# He plants his feet while gathering a volley.
	if _volley_windup <= 0.0:
		super(delta)
	_update_phase()
	_update_slam(delta)
	_update_volley(delta)
	if windup <= 0.0 and _volley_windup <= 0.0:
		_next_attack -= delta
		if _next_attack <= 0.0 and is_instance_valid(target):
			_start_attack()
	_next_summon -= delta
	if _next_summon <= 0.0:
		_next_summon = SUMMON_INTERVAL[phase]
		summon.emit(global_position, SUMMON_COUNT, phase == 1)
	_flash = maxf(0.0, _flash - delta)
	_telegraph.queue_redraw()


func _update_phase() -> void:
	if phase == 0 and hp <= max_hp * ENRAGE_AT:
		phase = 1
		slam_radius = SLAM_RADIUS[1]
		Game.shake(0.6)
		Game.sfx("boss_warn", 0.0)
		enraged.emit()


func move_speed() -> float:
	return data.move_speed * (ENRAGED_SPEED_MULT if phase == 1 else 1.0)


func _start_attack() -> void:
	_next_attack = ATTACK_GAP[phase]
	if _next_kind == Attack.SLAM:
		windup = SLAM_WINDUP
		slam_at = target.global_position
		Game.sfx("boss_warn", 0.0)
		slam_started.emit()
		_next_kind = Attack.VOLLEY
	else:
		_volley_windup = VOLLEY_WINDUP[phase]
		_next_kind = Attack.SLAM


func _update_slam(delta: float) -> void:
	if windup <= 0.0:
		return
	windup -= delta
	if windup > 0.0:
		return
	_flash = SLAM_FLASH
	Game.sfx("boss_slam")
	Game.rumble(0.5, 0.9, 0.35)
	Game.shake(0.7)
	var player := target as Player
	if player and player.global_position.distance_to(slam_at) <= slam_radius:
		player.take_damage(atk * SLAM_DAMAGE_MULT, true)


func _update_volley(delta: float) -> void:
	if _volley_windup <= 0.0:
		return
	_volley_windup -= delta
	if _volley_windup > 0.0:
		return
	for wave in VOLLEY_WAVES[phase]:
		if wave > 0:
			await get_tree().create_timer(VOLLEY_WAVE_GAP, false).timeout
			if not is_inside_tree():
				return
		_fire_ring(VOLLEY_ORBS[phase], wave * 0.5)


func _fire_ring(count: int, offset: float) -> void:
	Game.sfx("boss_volley", 0.0)
	var start := randf() * TAU
	for i in count:
		var orb := ORB_SCENE.instantiate() as BossOrb
		orb.setup(Vector2.RIGHT.rotated(start + TAU * (i + offset) / count), atk * ORB_DAMAGE_MULT)
		orb.position = global_position
		get_parent().get_parent().add_child(orb)


func _die() -> void:
	Game.fx("explosion", global_position, 5.0)
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
		_telegraph.draw_circle(slam_at, slam_radius, Color(TELEGRAPH_COLOR, 0.1 + 0.2 * t))
		_telegraph.draw_arc(slam_at, slam_radius * t, 0.0, TAU, 64, Color(TELEGRAPH_COLOR, 0.8), 3.0)
		_telegraph.draw_arc(slam_at, slam_radius, 0.0, TAU, 64, Color(TELEGRAPH_COLOR, 0.9), 2.0)
	elif _flash > 0.0:
		_telegraph.draw_circle(slam_at, slam_radius, Color(1, 0.5, 0.4, _flash / SLAM_FLASH * 0.6))
	if _volley_windup > 0.0:
		# Dark power gathering around him: a shrinking purple ring.
		var t: float = 1.0 - _volley_windup / VOLLEY_WINDUP[phase]
		_telegraph.draw_circle(global_position, radius * 2.2, Color(VOLLEY_COLOR, 0.15 + 0.2 * t))
		_telegraph.draw_arc(global_position, radius * (3.0 - 1.6 * t), 0.0, TAU, 48, Color(VOLLEY_COLOR, 0.9), 3.0)
