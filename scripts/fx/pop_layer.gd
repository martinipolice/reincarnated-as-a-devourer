class_name PopLayer
extends Node2D
## Short-lived effects that happen on almost every hit or kill, pooled so a
## big fight creates no new nodes: kill pops (a dying monster's last frame
## swelling and flashing out) and damage numbers. Each is a reused sprite or
## label, animated here instead of by a tween of its own.

const POP_TIME := 0.16
const POP_GROWTH := 0.4
const MAX_POPS := 50
const NUMBER_TIME := 0.45
const NUMBER_RISE := 18.0
const MAX_NUMBERS := 40

var _pops: Array[Sprite2D] = []
var _pop_age := PackedFloat32Array()
var _pop_scale := PackedVector2Array()
var _pop_flash := PackedFloat32Array()
var _numbers: Array[Label] = []
var _number_age := PackedFloat32Array()
var _number_y := PackedFloat32Array()


func _ready() -> void:
	add_to_group("pop_layer")
	z_index = 20
	for i in MAX_POPS:
		var pop := Sprite2D.new()
		pop.material = Game.unshaded
		pop.hide()
		add_child(pop)
		_pops.append(pop)
	_pop_age.resize(MAX_POPS)
	_pop_age.fill(POP_TIME)
	_pop_scale.resize(MAX_POPS)
	_pop_flash.resize(MAX_POPS)
	for i in MAX_NUMBERS:
		var label := Label.new()
		label.material = Game.unshaded
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		label.hide()
		add_child(label)
		_numbers.append(label)
	_number_age.resize(MAX_NUMBERS)
	_number_age.fill(NUMBER_TIME)
	_number_y.resize(MAX_NUMBERS)


## Returns false when every pop is busy (the effect is just skipped).
func pop(texture: Texture2D, at: Vector2, scale_from: Vector2, flip: bool, flash: float) -> bool:
	var i := _free_slot(_pop_age, POP_TIME)
	if i < 0:
		return false
	var sprite := _pops[i]
	sprite.texture = texture
	sprite.global_position = at
	sprite.flip_h = flip
	sprite.modulate = Color(flash, flash, flash, 0.9)
	_pop_scale[i] = scale_from
	_pop_flash[i] = flash
	sprite.scale = scale_from
	_pop_age[i] = 0.0
	sprite.show()
	return true


func number(at: Vector2, text: String, color: Color) -> bool:
	var i := _free_slot(_number_age, NUMBER_TIME)
	if i < 0:
		return false
	var label := _numbers[i]
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.position = at + Vector2(randf_range(-12, 4), -28)
	label.modulate.a = 1.0
	_number_y[i] = label.position.y
	_number_age[i] = 0.0
	label.show()
	return true


func _process(delta: float) -> void:
	for i in MAX_POPS:
		if _pop_age[i] >= POP_TIME:
			continue
		_pop_age[i] += delta
		var t := minf(_pop_age[i] / POP_TIME, 1.0)
		var sprite := _pops[i]
		sprite.scale = _pop_scale[i] * (1.0 + POP_GROWTH * (1.0 - pow(1.0 - t, 2.0)))
		var flash := lerpf(_pop_flash[i], 1.0, t)
		sprite.modulate = Color(flash, flash, flash, 0.9 * (1.0 - t))
		if t >= 1.0:
			sprite.hide()
	for i in MAX_NUMBERS:
		if _number_age[i] >= NUMBER_TIME:
			continue
		_number_age[i] += delta
		var t := minf(_number_age[i] / NUMBER_TIME, 1.0)
		var label := _numbers[i]
		label.position.y = _number_y[i] - NUMBER_RISE * (1.0 - pow(1.0 - t, 2.0))
		label.modulate.a = 1.0 - clampf((t - 0.66) / 0.34, 0.0, 1.0)
		if t >= 1.0:
			label.hide()


func _free_slot(ages: PackedFloat32Array, done: float) -> int:
	for i in ages.size():
		if ages[i] >= done:
			return i
	return -1
