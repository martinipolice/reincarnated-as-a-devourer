extends Node
## Global signals and helpers, available everywhere as `Game`: damage math,
## input setup, and "juice" (sound, screen shake, hit stop, particle bursts).

## Emitted just before the enemy frees itself; read what you need right away.
signal enemy_killed(enemy: Enemy)

## Two voice pools: combat sounds (hits, swings, gems, steps) can fill
## theirs completely without ever cutting off a level-up, a toll or a click.
const COMBAT_VOICES := 14
const MAIN_VOICES := 10
## Same sound can't restart faster than this, so a 50-enemy Blade swing
## doesn't stack 50 copies.
const SFX_COOLDOWN := 0.05
const AUDIO := "res://assets/audio/"
## name -> [variations, volume dB, base pitch, combat?]. A random variation
## plays each time; "{0-4}" in a name expands to _000.._004 style numbering
## as the file names use it. All Kenney (CC0).
const SFX := {
	# Weapons. The Blade swing layers drawn-steel and slice takes, pitched
	# down for weight; each weapon has its own hit so fights read by ear.
	"blade": [["kenney_rpg/drawKnife{1-3}.ogg", "kenney_rpg/knifeSlice.ogg", "kenney_rpg/knifeSlice2.ogg"], -11.0, 0.82, true],
	"blade_hit": [["kenney_impact/impactPunch_medium_00{0-4}.ogg", "kenney_impact/impactSoft_medium_00{0-4}.ogg"], -15.0, 0.9, true],
	"light_cast": [["kenney_digital/laser{4-6}.ogg"], -24.0, 1.5, true],
	"light_hit": [["kenney_impact/impactGlass_light_00{0-4}.ogg"], -17.0, 1.2, true],
	"aegis_hit": [["kenney_impact/impactMetal_light_00{0-4}.ogg", "kenney_impact/impactMetal_medium_00{0-4}.ogg"], -12.0, 1.0, true],
	"enemy_hit": [["kenney_impact/impactPunch_medium_00{0-4}.ogg"], -16.0, 1.0, true],
	"enemy_die": [["kenney_impact/impactSoft_heavy_00{0-4}.ogg"], -11.0, 0.85, true],
	"gem": [["kenney_interface/glass_00{1-6}.ogg"], -16.0, 1.0, true],
	"footstep_grass": [["kenney_impact/footstep_grass_00{0-4}.ogg"], -21.0, 1.0, true],
	"footstep_stone": [["kenney_impact/footstep_concrete_00{0-4}.ogg"], -21.0, 1.0, true],
	# The hero and the world.
	"elite_die": [["kenney_impact/impactBell_heavy_00{0-4}.ogg"], -6.0, 0.8, false],
	"player_hurt": [["kenney_impact/impactPlate_heavy_00{0-4}.ogg"], -5.0, 1.0, false],
	"flask": [["kenney_interface/drop_00{1-4}.ogg"], -4.0, 0.7, false],
	"flask_heal": [["kenney_digital/powerUp7.ogg"], -12.0, 1.2, false],
	"devour": [["kenney_digital/phaserDown{1-3}.ogg"], -6.0, 0.7, false],
	"level_up": [["kenney_digital/powerUp2.ogg"], -8.0, 1.0, false],
	"coins": [["kenney_rpg/handleCoins.ogg", "kenney_rpg/handleCoins2.ogg"], -4.0, 1.0, false],
	"evolve": [["kenney_digital/powerUp10.ogg"], -4.0, 1.0, false],
	"chest_open": [["kenney_rpg/metalLatch.ogg", "kenney_rpg/creak1.ogg"], -4.0, 1.0, false],
	"loot": [["kenney_digital/powerUp4.ogg"], -6.0, 1.0, false],
	"bomb": [["kenney_impact/impactMining_00{0-4}.ogg"], 0.0, 0.7, false],
	"shrine": [["kenney_interface/bong_001.ogg"], -6.0, 0.6, false],
	# The Demon King.
	"boss_warn": [["kenney_digital/lowThreeTone.ogg"], -6.0, 1.0, false],
	"boss_slam": [["kenney_impact/impactPunch_heavy_00{0-4}.ogg", "kenney_impact/impactMetal_heavy_00{0-4}.ogg"], -2.0, 0.7, false],
	"boss_volley": [["kenney_digital/phaserUp{1-3}.ogg"], -8.0, 0.8, false],
	# Stings: a doom hit and a bell toll, pitched far down; layered with
	# the music's own cues at death, victory and the boss's arrival.
	"doom": [["kenney_impact/impactMining_00{0-4}.ogg"], -1.0, 0.45, false],
	"toll": [["kenney_impact/impactBell_heavy_00{0-4}.ogg"], -3.0, 0.5, false],
	"victory": [["kenney_digital/threeTone2.ogg"], -4.0, 1.0, false],
	"defeat": [["kenney_digital/lowDown.ogg"], -4.0, 1.0, false],
	# Menus.
	"pick": [["kenney_interface/confirmation_00{1-4}.ogg"], -6.0, 1.0, false],
	"click": [["kenney_interface/select_00{1-3}.ogg"], -8.0, 1.0, false],
	"back": [["kenney_interface/back_00{1-4}.ogg"], -8.0, 1.0, false],
	"toggle": [["kenney_interface/switch_00{1-4}.ogg"], -10.0, 1.0, false],
	"open_menu": [["kenney_interface/maximize_004.ogg"], -8.0, 1.0, false],
	"close_menu": [["kenney_interface/minimize_004.ogg"], -8.0, 1.0, false],
	"denied": [["kenney_interface/error_006.ogg"], -6.0, 1.0, false],
}

var _streams := {}
var _pools := {true: [], false: []}  # combat? -> voices
var _next_voice := {true: 0, false: 0}
## Which footstep set the ground calls for; main.gd switches it by area.
var footstep := "footstep_grass"
var _last_played := {}
var _hit_stop_active := false
var _fx_frames := {}
const MAX_DAMAGE_NUMBERS := 40
var _damage_numbers := 0
var _glow_texture: GradientTexture2D
var _glow_material: CanvasItemMaterial


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # UI sounds play while paused
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("devour", [KEY_E, KEY_SPACE])
	_bind("flask", [KEY_Q])
	# Into the default theme too: controls under a CanvasLayer don't inherit
	# the root window's theme, and the HUD and overlays all live in one.
	var theme := UITheme.build()
	get_tree().root.theme = theme
	ThemeDB.get_default_theme().merge_with(theme)
	_bind("restart", [KEY_R])
	_bind("pause", [KEY_ESCAPE, KEY_P])
	for sfx_name in SFX:
		var streams := []
		for file: String in expand(SFX[sfx_name][0]):
			streams.append(load(AUDIO + file))
		_streams[sfx_name] = streams
	for combat in [true, false]:
		for i in (COMBAT_VOICES if combat else MAIN_VOICES):
			var voice := AudioStreamPlayer.new()
			voice.bus = "SFX"
			add_child(voice)
			_pools[combat].append(voice)


## Ratio mitigation. The terminal game used max(0, ATK - DEF), which drops to
## zero once DEF >= ATK; that breaks when hits land many times per second.
static func damage(atk: float, defense: float) -> float:
	return atk * 100.0 / (100.0 + defense)


func sfx(sfx_name: String, pitch_variance := 0.08) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_played.get(sfx_name, -1.0) < SFX_COOLDOWN:
		return
	_last_played[sfx_name] = now
	var entry: Array = SFX[sfx_name]
	var pool: Array = _pools[entry[3]]
	var voice: AudioStreamPlayer = pool[_next_voice[entry[3]]]
	_next_voice[entry[3]] = (_next_voice[entry[3]] + 1) % pool.size()
	voice.stream = _streams[sfx_name].pick_random()
	voice.volume_db = entry[1]
	voice.pitch_scale = entry[2] * randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
	voice.play()


## "name{1-3}.ogg" -> name1.ogg, name2.ogg, name3.ogg. Static so tools can
## list the files the table needs.
static func expand(files: Array) -> Array[String]:
	var out: Array[String] = []
	for file: String in files:
		var open := file.find("{")
		if open < 0:
			out.append(file)
			continue
		var close := file.find("}")
		var bounds := file.substr(open + 1, close - open - 1).split("-")
		for n in range(int(bounds[0]), int(bounds[1]) + 1):
			out.append(file.substr(0, open) + str(n) + file.substr(close + 1))
	return out


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
		camera.add_trauma(amount * float(Settings.data.shake))


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


## A soft additive halo (a radial gradient that brightens what's under it),
## used to make pickups glow like Minecraft XP orbs. Add it as the first
## child so the item's sprite draws on top.
func make_glow(color: Color, radius: float) -> Sprite2D:
	if _glow_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		gradient.add_point(0.35, Color(1, 1, 1, 0.55))
		_glow_texture = GradientTexture2D.new()
		_glow_texture.gradient = gradient
		_glow_texture.fill = GradientTexture2D.FILL_RADIAL
		_glow_texture.fill_from = Vector2(0.5, 0.5)
		_glow_texture.fill_to = Vector2(1.0, 0.5)
		_glow_texture.width = 64
		_glow_texture.height = 64
		_glow_material = CanvasItemMaterial.new()
		_glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var glow := Sprite2D.new()
	glow.texture = _glow_texture
	glow.material = _glow_material
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # smooth, unlike the pixel art
	glow.modulate = color
	glow.scale = Vector2.ONE * radius / 32.0
	return glow


## A small pixel number popping off a hit enemy. Capped, since a swarm can
## take hundreds of hits a second; main sources skip tiny hits.
func damage_number(at: Vector2, amount: float, color := Color.WHITE) -> void:
	if _damage_numbers >= MAX_DAMAGE_NUMBERS or not Settings.data.damage_numbers:
		return
	var parent := get_tree().get_first_node_in_group("effects")
	if parent == null:
		return
	_damage_numbers += 1
	var label := Label.new()
	label.text = str(roundi(amount))
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.position = at + Vector2(randf_range(-12, 4), -28)
	label.z_index = 20
	parent.add_child(label)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 18.0, 0.45).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.2).set_delay(0.3)
	tween.chain().tween_callback(func() -> void:
		_damage_numbers -= 1
		label.queue_free())


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
