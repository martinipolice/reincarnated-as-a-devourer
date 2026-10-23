class_name LightBolt
extends Area2D
## One Goddess Light projectile. Flies straight and expires after LIFETIME.

const SPEED := 420.0
const LIFETIME := 1.5
const RADIUS := 6.0
const KNOCKBACK := 60.0

var _dir := Vector2.RIGHT
var _damage := 0.0
var _pierce := 0
var _life := LIFETIME


## Call before add_child().
func setup(dir: Vector2, amount: float, pierce: int) -> void:
	_dir = dir
	_damage = amount
	_pierce = pierce


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	rotation = _dir.angle()
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position += _dir * SPEED * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if _pierce < 0 or not area is Enemy:
		return
	(area as Enemy).take_damage(_damage, _dir * KNOCKBACK)
	_pierce -= 1
	if _pierce < 0:
		queue_free()


func _draw() -> void:
	draw_line(Vector2(-10, 0), Vector2(4, 0), Color(1, 0.9, 0.5, 0.7), 4.0)
	draw_circle(Vector2(4, 0), 4.0, Color(1, 1, 0.85))
