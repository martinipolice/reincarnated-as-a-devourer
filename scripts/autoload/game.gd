extends Node
## Global signals and helpers, available everywhere as `Game`: damage math,
## input setup, and "juice" (sound, screen shake, hit stop, particle bursts).

## Emitted just before the enemy frees itself; read what you need right away.
signal enemy_killed(enemy: Enemy)

const SFX_VOICES := 16
## Same sound can't restart faster than this, so a 50-enemy Blade swing
## doesn't stack 50 copies.
const SFX_COOLDOWN := 0.05
const AUDIO := "res://assets/audio/"
## name -> [variations, volume dB]. A random variation plays each time.
const SFX := {
	"blade": [["kenney_rpg/knifeSlice.ogg", "kenney_rpg/knifeSlice2.ogg"], -12.0],
	"enemy_hit": [["kenney_impact/impactPunch_medium_000.ogg", "kenney_impact/impactPunch_medium_001.ogg",
		"kenney_impact/impactPunch_medium_002.ogg"], -16.0],
	"aegis_hit": [["kenney_impact/impactMetal_light_000.ogg", "kenney_impact/impactMetal_light_001.ogg",
		"kenney_impact/impactMetal_light_002.ogg"], -12.0],
	"enemy_die": [["kenney_impact/impactSoft_heavy_000.ogg", "kenney_impact/impactSoft_heavy_001.ogg",
		"kenney_impact/impactSoft_heavy_002.ogg"], -10.0],
	"elite_die": [["kenney_impact/impactBell_heavy_000.ogg"], -6.0],
	"player_hurt": [["kenney_impact/impactPlate_heavy_000.ogg", "kenney_impact/impactPlate_heavy_001.ogg"], -4.0],
	"gem": [["kenney_interface/glass_001.ogg", "kenney_interface/glass_002.ogg",
		"kenney_interface/glass_003.ogg"], -14.0],
	"level_up": [["kenney_digital/powerUp2.ogg"], -8.0],
	"pick": [["kenney_interface/confirmation_001.ogg"], -6.0],
	"click": [["kenney_interface/select_001.ogg"], -6.0],
	"denied": [["kenney_interface/error_006.ogg"], -6.0],
	"coins": [["kenney_rpg/handleCoins.ogg"], -4.0],
	"devour": [["kenney_digital/phaserDown2.ogg"], -6.0],
	"evolve": [["kenney_digital/powerUp10.ogg"], -4.0],
	"boss_warn": [["kenney_digital/lowThreeTone.ogg"], -6.0],
	"boss_slam": [["kenney_impact/impactPunch_heavy_000.ogg", "kenney_impact/impactMining_000.ogg"], -2.0],
	"boss_volley": [["kenney_digital/phaserUp3.ogg"], -8.0],
	"chest_open": [["kenney_rpg/metalLatch.ogg", "kenney_rpg/creak1.ogg"], -4.0],
	"loot": [["kenney_digital/powerUp4.ogg"], -6.0],
	"bomb": [["kenney_impact/impactMining_000.ogg", "kenney_impact/impactPunch_heavy_000.ogg"], 0.0],
	"victory": [["kenney_digital/threeTone2.ogg"], -4.0],
	"defeat": [["kenney_digital/lowDown.ogg"], -4.0],
}

var _streams := {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _last_played := {}
var _hit_stop_active := false
var _fx_frames := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # UI sounds play while paused
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("devour", [KEY_E, KEY_SPACE])
	_bind("restart", [KEY_R])
	for sfx_name in SFX:
		_streams[sfx_name] = SFX[sfx_name][0].map(func(file: String) -> AudioStream:
			return load(AUDIO + file))
	for i in SFX_VOICES:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)


## Ratio mitigation. The terminal game used max(0, ATK - DEF), which drops to
## zero once DEF >= ATK; that breaks when hits land many times per second.
static func damage(atk: float, defense: float) -> float:
	return atk * 100.0 / (100.0 + defense)


func sfx(sfx_name: String, pitch_variance := 0.08) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_played.get(sfx_name, -1.0) < SFX_COOLDOWN:
		return
	_last_played[sfx_name] = now
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = _streams[sfx_name].pick_random()
	voice.volume_db = SFX[sfx_name][1]
	voice.pitch_scale = randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	voice.play()


## Which way a sprite should face for a movement direction: the pack's
## sheets have "down", "up", "left" and "right" animations.
static func facing(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return "right" if direction.x > 0.0 else "left"
	return "down" if direction.y > 0.0 else "up"


## Trauma-based screen shake on the player's camera; 0..1, adds up.
func shake(amount: float) -> void:
	var camera := get_tree().get_first_node_in_group("camera")
	if camera:
		camera.add_trauma(amount)


## Nearly freezes gameplay for a moment so big hits land. Uses a real-time
## timer, so it still ends while time_scale is near zero.
func hit_stop(duration: float) -> void:
	if _hit_stop_active:
		return
	_hit_stop_active = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hit_stop_active = false


## One-shot particle burst, freed when done. Goes in the run's "effects"
## node so it never mixes with enemies or pickups.
func burst(at: Vector2, color: Color, amount := 10, speed := 140.0) -> void:
	var parent := get_tree().get_first_node_in_group("effects")
	if parent == null:
		return
	var particles := CPUParticles2D.new()
	particles.position = at
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = 0.45
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.damping_min = speed * 1.5
	particles.damping_max = speed * 2.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = color
	particles.finished.connect(particles.queue_free)
	parent.add_child(particles)
	particles.emitting = true


## Plays a one-shot sprite effect from assets/ninja (smoke, explosion,
## spark...) and frees it when the animation ends.
func fx(effect: String, at: Vector2, size := 2.0, tint := Color.WHITE) -> void:
	var parent := get_tree().get_first_node_in_group("effects")
	if parent == null:
		return
	if not _fx_frames.has(effect):
		_fx_frames[effect] = load("res://assets/ninja/%s/sprite_frames.tres" % effect)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = _fx_frames[effect]
	sprite.position = at
	sprite.scale = Vector2.ONE * size
	sprite.modulate = tint
	sprite.animation_finished.connect(sprite.queue_free)
	parent.add_child(sprite)
	sprite.play("play")


## A short line of text that floats up and fades, e.g. "+30 HP".
func float_text(at: Vector2, text: String, color: Color) -> void:
	var parent := get_tree().get_first_node_in_group("effects")
	if parent == null:
		return
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_size_override("font_size", 20)
	label.position = at + Vector2(-30, -60)
	label.z_index = 20
	parent.add_child(label)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 40.0, 0.9).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.5)
	tween.chain().tween_callback(label.queue_free)


# Actions are registered in code so they can be rebound later without
# hand-editing project.godot.
func _bind(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
