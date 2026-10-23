class_name XPGem
extends Node2D
## Dropped by enemies. Flies to the player once inside their pickup radius.

const ACCEL := 1400.0
const MAX_SPEED := 900.0
const COLLECT_DISTANCE := 14.0

var value := 1
var player: Player

var _magnet := false
var _speed := 0.0


## Call before add_child().
func setup(xp: int, collector: Player) -> void:
	value = xp
	player = collector


## Fly to the player no matter how far (Flask of Attraction).
func magnetize() -> void:
	_magnet = true


func _physics_process(delta: float) -> void:
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	if not _magnet and distance < player.stat("pickup_radius"):
		_magnet = true
	if not _magnet:
		return
	_speed = minf(_speed + ACCEL * delta, MAX_SPEED)
	if distance < COLLECT_DISTANCE or distance < _speed * delta:
		Game.sfx("gem", 0.15)
		player.gain_xp(value)
		queue_free()
		return
	position += to_player / distance * _speed * delta


func _draw() -> void:
	var color := Color(0.4, 0.7, 1.0)
	var size := 5.0
	if value >= 10:
		color = Color(1.0, 0.4, 0.45)
		size = 8.0
	elif value >= 3:
		color = Color(0.45, 1.0, 0.55)
		size = 6.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -size), Vector2(size * 0.7, 0), Vector2(0, size), Vector2(-size * 0.7, 0)
	]), color)
