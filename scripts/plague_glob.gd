class_name PlagueGlob
extends Area2D
## A Plaguewing's lobbed glob. Flies to where the player was standing when it
## was spat (so moving dodges it), hurts on a direct hit, and leaves a poison
## puddle where it lands either way. A ring on the ground marks the landing
## spot, closing in as the glob arrives.

const SPEED := 260.0
const RADIUS := 7.0
const COLOR := Color(0.55, 0.9, 0.3)
const PUDDLE_SCENE := preload("res://scenes/plague_puddle.tscn")

var _target := Vector2.ZERO
var _damage := 0.0


## Call before add_child().
func setup(land_at: Vector2, amount: float) -> void:
	_target = land_at
	_damage = amount


func _ready() -> void:
	add_to_group("enemy_shots")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


var _start_distance := 0.0


func _physics_process(delta: float) -> void:
	if _start_distance <= 0.0:
		_start_distance = maxf(global_position.distance_to(_target), 1.0)
	queue_redraw()
	var step := SPEED * delta
	if global_position.distance_to(_target) <= step:
		_land()
		return
	position += global_position.direction_to(_target) * step


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		(body as Player).take_damage(_damage)
		_land()


func _land() -> void:
	var puddle := PUDDLE_SCENE.instantiate() as PlaguePuddle
	puddle.setup(_damage * 0.18)
	puddle.position = global_position
	get_parent().add_child.call_deferred(puddle)
	queue_free()


func _draw() -> void:
	# Landing marker, drawn where the glob will land.
	if _start_distance > 0.0:
		var spot := to_local(_target)
		var left := clampf(global_position.distance_to(_target) / _start_distance, 0.0, 1.0)
		draw_arc(spot, PlaguePuddle.RADIUS * (0.5 + 0.5 * left), 0.0, TAU, 24, Color(COLOR, 0.25 + 0.35 * (1.0 - left)), 2.0)
	draw_circle(Vector2.ZERO, RADIUS + 3.0, Color(COLOR, 0.3))
	draw_circle(Vector2.ZERO, RADIUS, COLOR)
	draw_circle(Vector2(-2, -2), 2.5, Color(0.85, 1, 0.7))
