class_name XPGem
extends Node2D
## Dropped by enemies. Flies to the player once inside their pickup radius.
## Glows like a Minecraft XP orb: a pulsing green-yellow halo and a gentle bob,
## so it reads against the bright ground.

const ACCEL := 1400.0
const MAX_SPEED := 900.0
const COLLECT_DISTANCE := 14.0
const GEM_SMALL := preload("res://assets/ninja/images/gem_small.png")
const GEM_MEDIUM := preload("res://assets/ninja/images/gem_medium.png")
const GEM_LARGE := preload("res://assets/ninja/images/gem_large.png")
const GLOW_A := Color(0.55, 1.0, 0.2)
const GLOW_B := Color(1.0, 0.95, 0.25)
const BOB := 3.0

var value := 1
var player: Player

var _magnet := false
var _speed := 0.0
var _gem: Sprite2D
var _glow: Sprite2D
var _phase := randf() * TAU


## Call before add_child().
func setup(xp: int, collector: Player) -> void:
	value = xp
	player = collector


## Fly to the player no matter how far (Flask of Attraction).
func magnetize() -> void:
	_magnet = true


func _ready() -> void:
	var size := 1.3
	var texture := GEM_SMALL
	if value >= 10:
		texture = GEM_LARGE
		size = 2.0
	elif value >= 3:
		texture = GEM_MEDIUM
		size = 1.6
	_glow = Game.make_glow(GLOW_A, 14.0 * size)
	add_child(_glow)
	_gem = Sprite2D.new()
	_gem.texture = texture
	_gem.scale = Vector2.ONE * size
	add_child(_gem)


func _process(delta: float) -> void:
	_phase += delta * 4.0
	var wave := 0.5 + 0.5 * sin(_phase)
	_gem.position.y = -BOB * wave
	_glow.modulate = GLOW_A.lerp(GLOW_B, 0.5 + 0.5 * sin(_phase * 0.7))
	_glow.modulate.a = 0.55 + 0.45 * wave


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
