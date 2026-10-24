class_name DevourCorpse
extends Node2D
## What an elite leaves behind. Stand on it and hold Devour to take its
## Essence. Blinks, then fades after LIFETIME seconds.

const LIFETIME := 12.0
const BLINK_TIME := 3.0
const WISP := preload("res://assets/ninja/wisp/sprite_frames.tres")

var essence: EssenceData

var _life := LIFETIME


## Call before add_child().
func setup(from_essence: EssenceData) -> void:
	essence = from_essence


func _ready() -> void:
	add_to_group("corpses")
	var wisp := AnimatedSprite2D.new()
	wisp.sprite_frames = WISP
	wisp.scale = Vector2(1.6, 1.6)
	wisp.modulate = essence.color.lightened(0.3)
	wisp.position = Vector2(0, -10)
	add_child(wisp)
	wisp.play("play")


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	visible = _life > BLINK_TIME or fmod(_life, 0.3) > 0.15
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
	# A glow on the ground under the wisp.
	draw_circle(Vector2(0, 6), 14.0, Color(essence.color, 0.25 + 0.2 * pulse))
	draw_arc(Vector2(0, 6), 18.0 + 4.0 * pulse, 0.0, TAU, 32, Color(essence.color.lightened(0.4), 0.8), 2.0)
