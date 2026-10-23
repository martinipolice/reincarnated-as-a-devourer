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
		sprite.scale = Vector2.ONE * radius / data.radius
		sprite.play()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var dir := global_position.direction_to(target.global_position)
	position += (dir * data.move_speed + _knockback) * delta
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	if data.sprite_frames:
		sprite.flip_h = dir.x < 0.0


func alive() -> bool:
	return hp > 0.0


func take_damage(amount: float, knockback := Vector2.ZERO) -> void:
	if not alive():
		return
	hp -= Game.damage(amount, data.defense)
	_knockback += knockback * data.knockback_scale * (ELITE_KNOCKBACK_MULT if elite else 1.0)
	# self_modulate so the flash doesn't tint children (e.g. the boss telegraph)
	self_modulate = Color(2.5, 2.5, 2.5)
	create_tween().tween_property(self, "self_modulate", Color.WHITE, 0.1)
	if not alive():
		Game.enemy_killed.emit(self)
		queue_free()


func _draw() -> void:
	if data.sprite_frames == null:
		draw_circle(Vector2.ZERO, radius, data.color)
	if elite:
		draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 32, ELITE_RING, 2.5)
