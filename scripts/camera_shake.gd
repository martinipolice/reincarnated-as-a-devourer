extends Camera2D
## The run's camera: smooth trauma-based shake (Game.shake), and zoom. It
## pulls back a little as you level up and the horde grows (set_base_zoom),
## and pushes in for big moments (punch), easing back out.

const MAX_OFFSET := 14.0
const MAX_ROLL := 0.025  # radians
const DECAY := 1.6  # trauma lost per second
const NOISE_SPEED := 40.0

var trauma := 0.0
var base_zoom := 1.0
var _punch := 0.0
var _zoom_tween: Tween
var _noise := FastNoiseLite.new()
var _t := 0.0


func _ready() -> void:
	add_to_group("camera")
	_noise.frequency = 0.5


func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


## Eases the resting zoom to `value` (< 1 shows more of the world).
func set_base_zoom(value: float, time := 1.5) -> void:
	if _zoom_tween:
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(self, "base_zoom", value, time).set_trans(Tween.TRANS_SINE)


## A quick push in by `amount` (0.1 = 10% closer) that eases back out.
func punch(amount: float, time := 0.8) -> void:
	_punch = maxf(_punch, amount)
	var tween := create_tween()
	tween.tween_property(self, "_punch", 0.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _process(delta: float) -> void:
	_t += delta * NOISE_SPEED
	trauma = maxf(0.0, trauma - DECAY * delta)
	var shake := trauma * trauma
	# Smooth noise, not a new random offset every frame (that just buzzes).
	offset = Vector2(_noise.get_noise_2d(_t, 0.0), _noise.get_noise_2d(0.0, _t)) * MAX_OFFSET * shake
	rotation = _noise.get_noise_2d(_t, _t) * MAX_ROLL * shake
	zoom = Vector2.ONE * base_zoom * (1.0 + _punch)
