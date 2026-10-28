class_name HexBolt
extends Area2D
## A Hexeye's bolt: flies straight along the line the Hexeye aimed (shown
## before it fires), hurts on contact, and fizzles after LIFETIME. In the
## "enemy_shots" group, so the Bulwark of Dawn can cut it down too.

const SPEED := 300.0
const LIFETIME := 2.2
const RADIUS := 7.0
const COLOR := Color(0.45, 0.85, 1.0)

var _dir := Vector2.RIGHT
var _damage := 0.0
var _life := LIFETIME


## Call before add_child().
func setup(dir: Vector2, amount: float) -> void:
	_dir = dir
	_damage = amount


func _ready() -> void:
	add_to_group("enemy_shots")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	material = Game.unshaded  # glows in the dark
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += _dir * SPEED * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).take_damage(_damage)
		queue_free()


func _draw() -> void:
	draw_line(-_dir * 18.0, Vector2.ZERO, Color(COLOR, 0.35), 5.0)
	draw_circle(Vector2.ZERO, RADIUS + 3.0, Color(COLOR, 0.35))
	draw_circle(Vector2.ZERO, RADIUS, COLOR)
	draw_circle(Vector2.ZERO, 3.0, Color(0.9, 1.0, 1.0))
