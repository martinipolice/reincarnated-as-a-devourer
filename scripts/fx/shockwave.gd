class_name Shockwave
extends Node2D
## An expanding ring that fades as it grows: level-ups, a boss's arrival,
## a chest's reward. Draws outside the lighting so it reads in the dark.

var color := Color.WHITE
var radius := 120.0
var duration := 0.45
var width := 4.0
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / duration
	var eased := 1.0 - pow(1.0 - k, 3.0)
	draw_arc(Vector2.ZERO, radius * eased, 0.0, TAU, 48, Color(color, 1.0 - k), width * (1.0 - k * 0.6))
