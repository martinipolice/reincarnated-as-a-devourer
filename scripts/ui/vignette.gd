extends ColorRect
## The screen's dark frame, and the danger it shows: the edges flash red when
## you're hit, and below LOW_HP they pulse red with a heartbeat. "Reduce
## flashing" in Settings softens the flash and the pulse.

const SHADER := preload("res://shaders/vignette.gdshader")
const LOW_HP := 0.3
const HURT_DECAY := 2.2  # per second
const HEARTBEAT := 0.85  # seconds per beat at the lowest HP

var _hurt := 0.0
var _danger := 0.0  # 0..1, how far under LOW_HP
var _beat := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	(material as ShaderMaterial).shader = SHADER


func bind(player: Player) -> void:
	player.hurt.connect(func() -> void: _hurt = 1.0)
	player.hp_changed.connect(func(hp: float, max_hp: float) -> void:
		_danger = clampf(1.0 - hp / (max_hp * LOW_HP), 0.0, 1.0) if hp > 0.0 else 0.0)


func _process(delta: float) -> void:
	var soft := 0.4 if Settings.data.get("reduce_flashing", false) else 1.0
	_hurt = maxf(0.0, _hurt - HURT_DECAY * delta)
	var pulse := 0.0
	if _danger > 0.0 and not get_tree().paused:
		_beat += delta / lerpf(HEARTBEAT * 1.4, HEARTBEAT, _danger)
		if _beat >= 1.0:
			_beat -= 1.0
			Game.sfx("heartbeat", 0.0)
		# Two quick swells per beat, like a heart.
		pulse = maxf(sin(_beat * TAU * 2.0), 0.0) * (0.25 + 0.35 * _danger)
	var shader := material as ShaderMaterial
	shader.set_shader_parameter("hurt", _hurt * 0.8 * soft)
	shader.set_shader_parameter("danger", pulse * soft)
	shader.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
