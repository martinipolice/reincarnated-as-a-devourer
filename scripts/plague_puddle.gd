class_name PlaguePuddle
extends Node2D
## A pool of plague left by a Plaguewing glob. Hurts the player every TICK
## while they stand in it, then fades. Checked by distance: one puddle, one
## player, no physics needed.

const RADIUS := 32.0
const LIFETIME := 2.0
const TICK := 0.5
const COLOR := Color(0.45, 0.8, 0.25)

var _damage := 0.0
var _life := LIFETIME
var _tick := 0.0


## Call before add_child().
func setup(amount: float) -> void:
	_damage = amount


func _ready() -> void:
	add_to_group("enemy_shots")
	z_index = -5  # on the floor, under everyone


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	_tick -= delta
	var player := get_tree().get_first_node_in_group("player") as Player
	if player and _tick <= 0.0 and global_position.distance_to(player.global_position) < RADIUS:
		_tick = TICK
		player.take_damage(_damage)
	queue_redraw()


func radius() -> float:
	return RADIUS


func _draw() -> void:
	var fade := clampf(_life / 0.6, 0.0, 1.0)  # fades out over its last 0.6 s
	var grow := clampf((LIFETIME - _life) / 0.2, 0.0, 1.0)  # splashes in
	draw_circle(Vector2.ZERO, RADIUS * grow, Color(COLOR, 0.28 * fade))
	draw_arc(Vector2.ZERO, RADIUS * grow, 0.0, TAU, 32, Color(COLOR, 0.6 * fade), 2.0)
