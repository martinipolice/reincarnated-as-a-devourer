class_name TitleBackdrop
extends SubViewportContainer
## Behind the title: the game's own world at night, seen from a camera that
## drifts slowly across the forest, with fireflies (and make_fog() over it).
## It lives in a SubViewport so its camera never moves the menu.

const DRIFT := Vector2(14.0, -3.0)  # pixels per second
const NIGHT := Color(0.2, 0.21, 0.36)
const FOG_SHADER := preload("res://shaders/fog.gdshader")

var _world: ChunkWorld
var _camera: Camera2D
var _viewport: SubViewport


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport = SubViewport.new()
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_viewport)
	var night := CanvasModulate.new()
	night.color = NIGHT
	_viewport.add_child(night)
	_world = ChunkWorld.new()
	_viewport.add_child(_world)
	_camera = Camera2D.new()
	_camera.position = Vector2(randf_range(-4000, 4000), randf_range(-4000, 4000))
	_viewport.add_child(_camera)
	_world.set_origin(_camera.position + Vector2(9999, 9999))  # no clearing in view
	var motes := Atmosphere.new()
	_camera.add_child(motes)
	motes.set_area("forest")
	motes.light.enabled = false  # no hero here: the night stays even


func _process(delta: float) -> void:
	_camera.position += DRIFT * delta
	_world.update(_camera.position, Vector2(_viewport.size))


func _exit_tree() -> void:
	Obstacles.clear()


## Low drifting fog, to lay over the backdrop (a container can't hold it).
static func make_fog() -> TextureRect:
	var fog := TextureRect.new()
	var noise := NoiseTexture2D.new()
	noise.seamless = true
	noise.width = 256
	noise.height = 256
	noise.noise = FastNoiseLite.new()
	noise.noise.frequency = 0.012
	var material := ShaderMaterial.new()
	material.shader = FOG_SHADER
	material.set_shader_parameter("noise", noise)
	fog.material = material
	fog.texture = PlaceholderTexture2D.new()
	fog.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return fog
