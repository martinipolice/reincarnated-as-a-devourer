class_name BossOrb
extends Area2D
## One orb of the Demon King's dark volley. Flies straight, hurts the player
## on touch (respecting their post-hit invulnerability), fades out at the end.
## Pillars, trees and rocks stop it: take cover.

const SPEED := 170.0
const LIFETIME := 4.5
const RADIUS := 9.0
const CORE := Color(0.25, 0.05, 0.3)
const RIM := Color(0.85, 0.3, 1.0)

var _dir := Vector2.RIGHT
var _damage := 0.0
var _life := LIFETIME


## Call before add_child().
func setup(dir: Vector2, amount: float) -> void:
	_dir = dir
	_damage = amount


func _ready() -> void:
	add_to_group("boss_orbs")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += _dir * SPEED * delta
	if Obstacles.blocked(global_position, RADIUS):
		Game.fx("spark", global_position, 1.2, RIM)
		queue_free()
		return
	_life -= delta
	modulate.a = clampf(_life / 0.5, 0.0, 1.0)
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).take_damage(_damage)
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS + 4.0, Color(RIM, 0.25))
	draw_circle(Vector2.ZERO, RADIUS, RIM)
	draw_circle(Vector2.ZERO, RADIUS - 3.0, CORE)
