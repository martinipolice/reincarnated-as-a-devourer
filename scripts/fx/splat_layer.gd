class_name SplatLayer
extends Node2D
## Every ichor splat on the ground, drawn by this one node instead of one
## node per splat: a ring buffer of the newest MAX splats, redrawn a few
## times a second as they fade. Game.splat() adds to it. Each blob is a quad
## of one shared round texture, so they batch into a few draw calls (an
## untextured circle per blob was a draw call each, ~800 a frame).

const MAX := 160
const LIFE := 6.0
const FADE := 1.5
const REDRAW_EVERY := 0.15  # seconds; fading needs no more than this
const BLOBS := 5

var _blob_texture: GradientTexture2D
var _time := 0.0
var _redraw := 0.0
var _next := 0
var _born := PackedFloat32Array()
var _colors := PackedColorArray()
## BLOBS circles per splat: xy = center, z = radius (unused slots: radius 0).
var _blobs := PackedVector3Array()


func _ready() -> void:
	add_to_group("splat_layer")
	z_as_relative = false
	z_index = -5  # on the ground, under pickups and bodies
	_born.resize(MAX)
	_born.fill(-1000.0)
	_colors.resize(MAX)
	_blobs.resize(MAX * BLOBS)
	# A hard-edged disc, so blobs keep the flat, pixel-art look.
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.92, Color.WHITE)
	gradient.add_point(0.97, Color(1, 1, 1, 0))
	_blob_texture = GradientTexture2D.new()
	_blob_texture.gradient = gradient
	_blob_texture.fill = GradientTexture2D.FILL_RADIAL
	_blob_texture.fill_from = Vector2(0.5, 0.5)
	_blob_texture.fill_to = Vector2(1.0, 0.5)
	_blob_texture.width = 32
	_blob_texture.height = 32


func add(at: Vector2, color: Color, size: float) -> void:
	var i := _next
	_next = (_next + 1) % MAX  # overwrite the oldest
	_born[i] = _time
	_colors[i] = color
	for b in BLOBS:
		var offset := Vector2.from_angle(randf() * TAU) * randf_range(0.0, size * 0.9) * Vector2(1.0, 0.6)
		_blobs[i * BLOBS + b] = Vector3(at.x + offset.x, at.y + offset.y, randf_range(size * 0.25, size * 0.6))
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	_redraw -= delta
	if _redraw <= 0.0:
		_redraw = REDRAW_EVERY
		queue_redraw()


func _draw() -> void:
	for i in MAX:
		var age := _time - _born[i]
		if age >= LIFE:
			continue
		var color := _colors[i]
		color.a *= clampf((LIFE - age) / FADE, 0.0, 1.0)
		for b in BLOBS:
			var blob := _blobs[i * BLOBS + b]
			draw_texture_rect(_blob_texture, Rect2(blob.x - blob.z, blob.y - blob.z, blob.z * 2.0, blob.z * 2.0), false, color)
