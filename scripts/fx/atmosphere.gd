class_name Atmosphere
extends Node2D
## The dark-fantasy mood around the hero: a warm light that carries through
## the dusk (the world itself is darkened by main.gd's Mood), and ambient
## motes in the air that change with the area. A child of the player, so it
## follows them; the motes are emitted in world space, so they drift
## naturally as you move.
## - forest: a few fireflies, wandering and blinking
## - ruins: embers rising from the stone
## - temple: ash falling from a dark sky

const LIGHT_COLOR := Color(1.0, 0.9, 0.8)
const LIGHT_ENERGY := 0.42
const LIGHT_SCALE := 3.6
## Emission box around the hero: a bit larger than the screen at any zoom.
const FIELD := Vector2(900, 560)
const AREAS := {
	"forest": {"amount": 36, "color": Color(0.85, 1.0, 0.45), "gravity": Vector2(0, -2),
		"speed": Vector2(6, 22), "size": Vector2(1.5, 2.5), "life": 5.0},
	"ruins": {"amount": 70, "color": Color(1.0, 0.55, 0.2), "gravity": Vector2(4, -26),
		"speed": Vector2(8, 26), "size": Vector2(1.5, 3.0), "life": 4.0},
	"temple": {"amount": 110, "color": Color(0.55, 0.5, 0.55), "gravity": Vector2(10, 30),
		"speed": Vector2(4, 16), "size": Vector2(1.5, 3.5), "life": 5.0},
}

var light: PointLight2D
var _motes: CPUParticles2D
var _area := ""


func _ready() -> void:
	light = PointLight2D.new()
	light.texture = _light_texture()
	light.texture_scale = LIGHT_SCALE
	light.energy = LIGHT_ENERGY
	light.color = LIGHT_COLOR
	add_child(light)
	_motes = CPUParticles2D.new()
	_motes.local_coords = false  # left behind in the world as you move
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_motes.emission_rect_extents = FIELD
	_motes.direction = Vector2.UP
	_motes.spread = 180.0
	_motes.z_index = 6
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED  # they glow in the dark
	_motes.material = mat
	add_child(_motes)


## Switches the motes to `area` ("forest", "ruins" or "temple").
func set_area(area: String) -> void:
	if area == _area:
		return
	_area = area
	var spec: Dictionary = AREAS[area]
	_motes.amount = spec.amount
	_motes.lifetime = spec.life
	_motes.gravity = spec.gravity
	_motes.initial_velocity_min = spec.speed.x
	_motes.initial_velocity_max = spec.speed.y
	_motes.scale_amount_min = spec.size.x
	_motes.scale_amount_max = spec.size.y
	# Fade in and out over each mote's life; fireflies also blink.
	var ramp := Gradient.new()
	var color: Color = spec.color
	ramp.set_color(0, Color(color, 0.0))
	ramp.set_color(1, Color(color, 0.0))
	if area == "forest":
		for i in 4:
			ramp.add_point(0.15 + i * 0.22, Color(color, 0.9))
			ramp.add_point(0.25 + i * 0.22, Color(color, 0.15))
	else:
		ramp.add_point(0.2, Color(color, 0.8))
		ramp.add_point(0.75, Color(color, 0.6))
	_motes.color_ramp = ramp
	_motes.restart()


static func _light_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.45, Color(1, 1, 1, 0.55))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	return texture
