extends Camera2D
## Trauma-based screen shake. Call Game.shake(amount) from anywhere; the
## offset scales with trauma squared so small hits stay subtle.

const MAX_OFFSET := 14.0
const DECAY := 1.6  # trauma lost per second

var trauma := 0.0


func _ready() -> void:
	add_to_group("camera")


func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


func _process(delta: float) -> void:
	trauma = maxf(0.0, trauma - DECAY * delta)
	var strength := trauma * trauma * MAX_OFFSET
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength
