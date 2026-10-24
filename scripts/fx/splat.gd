class_name Splat
extends Node2D
## A splash of dark ichor on the ground where a monster died, in its own
## color, fading after a few seconds. Game.splat() places them and keeps
## only the newest MAX_SPLATS.

const LIFE := 6.0
const FADE := 1.5

var color := Color.BLACK
var size := 14.0
var _blobs: Array = []  # [offset, radius]


func _ready() -> void:
	z_as_relative = false
	z_index = -5  # on the ground, under pickups and bodies
	for i in randi_range(4, 7):
		var offset := Vector2.from_angle(randf() * TAU) * randf_range(0.0, size * 0.9)
		_blobs.append([offset * Vector2(1.0, 0.6), randf_range(size * 0.25, size * 0.6)])
	var tween := create_tween()
	tween.tween_interval(LIFE - FADE)
	tween.tween_property(self, "modulate:a", 0.0, FADE)
	tween.tween_callback(queue_free)


func _draw() -> void:
	for blob: Array in _blobs:
		draw_circle(blob[0], blob[1], color)
