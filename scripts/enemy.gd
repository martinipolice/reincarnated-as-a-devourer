class_name Enemy
extends Area2D
## A monster that walks straight at the player. Stats and art come from an
## EnemyData resource, so new monsters need a .tres file, not new code.
## Enemies don't push each other: cheap enough for hundreds on screen.
## Elites are tougher, gold-ringed versions that leave a Devour corpse.

const KNOCKBACK_DECAY := 900.0
const ELITE_HP_MULT := 4.0
const ELITE_ATK_MULT := 1.5
const ELITE_SIZE_MULT := 1.5
const ELITE_KNOCKBACK_MULT := 0.5
const ELITE_RING := Color(1, 0.85, 0.3)
const ELITE_TINT := Color(1.35, 1.15, 0.7)
const HIT_FLASH := Color(2.5, 2.5, 2.5)

var data: EnemyData
var target: Node2D
var elite := false
var hp: float
var max_hp: float
var atk: float
var radius: float

var _knockback := Vector2.ZERO

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


## Call before add_child().
func setup(enemy_data: EnemyData, chase_target: Node2D, is_elite := false) -> void:
	data = enemy_data
	target = chase_target
	elite = is_elite
	max_hp = data.max_hp * (ELITE_HP_MULT if elite else 1.0)
	hp = max_hp
	atk = data.atk * (ELITE_ATK_MULT if elite else 1.0)
	radius = data.radius * (ELITE_SIZE_MULT if elite else 1.0)


func _ready() -> void:
	add_to_group("enemies")
	var shape := CircleShape2D.new()
	shape.radius = radius
	$CollisionShape2D.shape = shape
	if data.sprite_frames:
		sprite.sprite_frames = data.sprite_frames
		sprite.scale = Vector2.ONE * data.sprite_scale * radius / data.radius
		sprite.play("run")
		if elite:
			sprite.self_modulate = ELITE_TINT


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var dir := global_position.direction_to(target.global_position)
	position += (dir * move_speed() + _knockback) * delta
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	if data.sprite_frames:
		sprite.flip_h = dir.x < 0.0


func move_speed() -> float:
	return data.move_speed


func alive() -> bool:
	return hp > 0.0


func take_damage(amount: float, knockback := Vector2.ZERO, hit_sfx := "enemy_hit") -> void:
	if not alive():
		return
	hp -= Game.damage(amount, data.defense)
	_knockback += knockback * data.knockback_scale * (ELITE_KNOCKBACK_MULT if elite else 1.0)
	# Flash the sprite (or our own drawing), never `modulate`, which would also
	# tint children like the boss telegraph.
	var flash_target: CanvasItem = sprite if data.sprite_frames else self
	var flash_property := "modulate" if data.sprite_frames else "self_modulate"
	flash_target.set(flash_property, HIT_FLASH)
	create_tween().tween_property(flash_target, flash_property, Color.WHITE, 0.1)
	Game.sfx(hit_sfx)
	if not alive():
		_die()


func _die() -> void:
	Game.sfx("elite_die" if elite else "enemy_die")
	Game.burst(global_position, data.color.lightened(0.2), 18 if elite else 8)
	if elite:
		Game.shake(0.25)
	Game.enemy_killed.emit(self)
	queue_free()


func _draw() -> void:
	if data.sprite_frames == null:
		draw_circle(Vector2.ZERO, radius, data.color)
	if elite:
		# Drawn under the sprite: a gold aura on the ground.
		draw_circle(Vector2(0, radius * 0.6), radius * 0.9, Color(ELITE_RING, 0.25))
		draw_arc(Vector2(0, radius * 0.6), radius * 0.9, 0.0, TAU, 32, ELITE_RING, 2.0)
