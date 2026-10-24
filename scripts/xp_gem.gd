class_name XPGem
extends Node2D
## Dropped by enemies. Flies to the player once inside their pickup radius.

const ACCEL := 1400.0
const MAX_SPEED := 900.0
const COLLECT_DISTANCE := 14.0
const GEM_SMALL := preload("res://assets/ninja/images/gem_small.png")
const GEM_MEDIUM := preload("res://assets/ninja/images/gem_medium.png")
const GEM_LARGE := preload("res://assets/ninja/images/gem_large.png")

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


func _ready() -> void:
	var gem := Sprite2D.new()
	if value >= 10:
		gem.texture = GEM_LARGE
		gem.scale = Vector2.ONE * 2.0
	elif value >= 3:
		gem.texture = GEM_MEDIUM
		gem.scale = Vector2.ONE * 1.6
	else:
		gem.texture = GEM_SMALL
		gem.scale = Vector2.ONE * 1.3
	add_child(gem)
