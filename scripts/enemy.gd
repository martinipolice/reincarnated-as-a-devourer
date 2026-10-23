class_name Enemy
extends Area2D
## A monster that walks straight at the player. Stats and art come from an
## EnemyData resource, so new monsters need a .tres file, not new code.
## Enemies don't push each other: cheap enough for hundreds on screen.

var data: EnemyData
var target: Node2D
var hp: float

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


## Call before add_child().
func setup(enemy_data: EnemyData, chase_target: Node2D) -> void:
	data = enemy_data
	target = chase_target
	hp = data.max_hp


func _ready() -> void:
	add_to_group("enemies")
	var shape := CircleShape2D.new()
	shape.radius = data.radius
	$CollisionShape2D.shape = shape
	if data.sprite_frames:
		sprite.sprite_frames = data.sprite_frames
		sprite.play()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var dir := global_position.direction_to(target.global_position)
	position += dir * data.move_speed * delta
	if data.sprite_frames:
		sprite.flip_h = dir.x < 0.0


func take_damage(atk: float) -> void:
	hp -= Game.damage(atk, data.defense)
	modulate = Color(2.5, 2.5, 2.5)
	create_tween().tween_property(self, "modulate", Color.WHITE, 0.1)
	if hp <= 0.0:
		Game.enemy_killed.emit(data, global_position)
		queue_free()


func _draw() -> void:
	if data.sprite_frames == null:
		draw_circle(Vector2.ZERO, data.radius, data.color)
