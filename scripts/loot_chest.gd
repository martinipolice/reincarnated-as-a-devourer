class_name LootChest
extends Area2D
## A treasure chest lying in the world. Walk into it to open it; main.gd
## rolls the reward. Fades away a moment after opening.

signal opened(chest: LootChest)

const RADIUS := 16.0
const FADE_DELAY := 1.5
const GLOW := Color(1, 0.85, 0.35)

var is_open := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("chests")
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	sprite.frame = 0  # closed, until opened
	body_entered.connect(_on_body_entered)


func _process(_delta: float) -> void:
	if not is_open:
		queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if is_open or not body is Player:
		return
	is_open = true
	sprite.play("open")
	queue_redraw()
	opened.emit(self)
	var tween := create_tween()
	tween.tween_interval(FADE_DELAY)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


# A pulsing golden glow on the ground so closed chests catch the eye.
func _draw() -> void:
	if is_open:
		return
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
	draw_circle(Vector2(0, 10), 22.0, Color(GLOW, 0.12 + 0.12 * pulse))
	draw_arc(Vector2(0, 10), 22.0 + 3.0 * pulse, 0.0, TAU, 32, Color(GLOW, 0.6), 2.0)
