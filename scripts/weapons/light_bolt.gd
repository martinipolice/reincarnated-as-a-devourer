class_name LightBolt
extends Area2D
## One Goddess Light projectile. Flies straight and expires after LIFETIME.
## A Goddess's Grace bolt (evolved) is whiter and reports each hit back to
## the weapon, which heals the hero.

const ARROW_TEXTURE := preload("res://assets/ninja/images/arrow.png")
const ARROW_TINT := Color(1.0, 0.92, 0.55)  # goddess gold
const GRACE_TINT := Color(1.3, 1.25, 1.0)
const SPEED := 420.0
const LIFETIME := 1.5
const RADIUS := 6.0
const KNOCKBACK := 60.0

var _dir := Vector2.RIGHT
var _damage := 0.0
var _pierce := 0
var _life := LIFETIME
var _grace: Node  # the evolved weapon to report hits to, or null


## Call before add_child().
func setup(dir: Vector2, amount: float, pierce: int, grace: Node = null) -> void:
	_dir = dir
	_damage = amount
	_pierce = pierce
	_grace = grace


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	var arrow := Sprite2D.new()
	arrow.texture = ARROW_TEXTURE
	arrow.scale = Vector2(2, 2)
	arrow.modulate = GRACE_TINT if _grace else ARROW_TINT
	arrow.material = Game.unshaded  # light shines in the dark
	add_child(arrow)
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
	(area as Enemy).take_damage(_damage, _dir * KNOCKBACK, "light_hit")
	if is_instance_valid(_grace):
		_grace.on_bolt_hit()
	_pierce -= 1
	if _pierce < 0:
		queue_free()


# A soft trail of light behind the arrow sprite.
func _draw() -> void:
	draw_line(Vector2(-34, 0), Vector2(-8, 0), Color(1, 0.9, 0.5, 0.35), 6.0)
