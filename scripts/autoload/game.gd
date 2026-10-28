extends Node
## Global signals and helpers, available everywhere as `Game`: damage math,
## input setup, and "juice" (sound, screen shake, hit stop, particle bursts).

## Emitted just before the enemy frees itself; read what you need right away.
signal enemy_killed(enemy: Enemy)
## The player switched between keyboard/mouse and a controller; prompts
## (HUD, hints, menus) listen and relabel themselves.
signal device_changed(gamepad: bool)

## What to call each action's controls, per device: [keyboard, controller].
## Text anywhere can name an action as "{action}" and go through prompts().
const PROMPTS := {
	"move": ["WASD or the arrow keys", "the left stick"],
	"devour": ["E or Space", "A"],
	"flask": ["Q", "X"],
	"pause": ["Esc", "Start"],
	"restart": ["R", "Y"],
	"pick": ["a click, the number keys 1-3, or the arrow keys and Enter", "the d-pad and A"],
	"menus": ["Arrows / Tab + Enter, Esc to go back", "D-pad or stick + A, B to go back"],
	"accept": ["Enter", "A"],
	"back": ["Esc", "B"],
}
## Below this, stick movement is ignored (worn sticks drift).
const STICK_DEADZONE := 0.25

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
	"bell": [["kenney_impact/impactBell_heavy_00{0-4}.ogg"], -13.0, 1.15, true],
	"enemy_hit": [["kenney_impact/impactPunch_medium_00{0-4}.ogg"], -16.0, 1.0, true],
	"enemy_die": [["kenney_impact/impactSoft_heavy_00{0-4}.ogg"], -11.0, 0.85, true],
	"gem": [["kenney_interface/glass_00{1-6}.ogg"], -16.0, 1.0, true],
	"footstep_grass": [["kenney_impact/footstep_grass_00{0-4}.ogg"], -21.0, 1.0, true],
	"footstep_stone": [["kenney_impact/footstep_concrete_00{0-4}.ogg"], -21.0, 1.0, true],
	"maw": [["kenney_impact/impactSoft_heavy_00{0-4}.ogg"], -9.0, 0.6, true],
	"maw_hit": [["kenney_impact/impactPunch_heavy_00{0-4}.ogg"], -14.0, 0.8, true],
	"chains": [["kenney_rpg/beltHandle{1-2}.ogg", "kenney_rpg/metalClick.ogg"], -8.0, 0.7, true],
	"chains_hit": [["kenney_impact/impactMetal_medium_00{0-4}.ogg"], -15.0, 0.75, true],
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
	"covenant": [["kenney_digital/lowRandom.ogg"], -4.0, 0.7, false],
	"rank_up": [["kenney_impact/impactMetal_heavy_00{0-4}.ogg"], -9.0, 1.3, false],
	# The Demon King.
	# Telegraph cues, synthesized by tools/synth_audio.py.
	"warn_pounce": [["synth/warn_pounce.wav"], -10.0, 1.0, true],
	"warn_hex": [["synth/warn_hex.wav"], -13.0, 1.0, true],
	"warn_glob": [["synth/warn_glob.wav"], -12.0, 1.0, true],
	"warn_charge": [["synth/warn_charge.wav"], -3.0, 1.0, false],
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
	"tick": [["kenney_interface/tick_00{1-2}.ogg"], -14.0, 1.0, false],
	"heartbeat": [["kenney_impact/impactSoft_medium_00{0-4}.ogg"], -8.0, 0.45, false],
}

var _streams := {}
var _pools := {true: [], false: []}  # combat? -> voices
var _next_voice := {true: 0, false: 0}
## Which footstep set the ground calls for; main.gd switches it by area.
var footstep := "footstep_grass"
## Multiplies every new enemy's damage (a shrine covenant raises it).
var enemy_atk_mult := 1.0
## For things that should glow in the dark world (gems, flashes, numbers):
## they skip the lighting, so the darkened Mood doesn't dim them.
var unshaded: CanvasItemMaterial
## Gem pickups chime up a pentatonic scale while you keep collecting.
const CHIME_STEPS := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]
const CHIME_RESET := 0.6  # seconds without a gem before the scale restarts
var _chime_step := 0
## True while the player is using a controller (the last device touched).
var gamepad := false
var _joy_device := 0
## Adaptive effects: when frames run slow (a weaker PC, a huge pile-up),
## purely cosmetic extras (kill pops, splats, damage numbers, particle
## bursts) thin out, and come back once it's smooth. 1 = everything.
## Measured against the display's own frame: with vsync a healthy game's
## frame time *is* the refresh interval (16.7 ms at 60 Hz), so thresholds
## below it would thin effects on a game running perfectly.
const FX_FULL := 1.15  # frame time up to this x the refresh interval: all effects
const FX_LEAN := 1.8  # at or above this: FX_MIN of them
const FX_MIN := 0.25
const SLOWEST_BASE_MS := 1000.0 / 60.0  # never stricter than a 60 Hz frame
var fx_quality := 1.0
## Upper limit for fx_quality (lowered on web builds and by benchmarks).
var fx_ceiling := 1.0
var frame_ms := 16.7  # smoothed frame time
var _refresh_ms := SLOWEST_BASE_MS
var _chime_last := 0.0
var _last_played := {}
var _hit_stop_active := false
var _fx_frames := {}
var _glow_texture: GradientTexture2D
var _glow_material: CanvasItemMaterial
## Scene changes fade through black (change_scene).
const FADE_OUT := 0.35
const FADE_IN := 0.5
var _fade: ColorRect
var _fading := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # UI sounds play while paused
	var hz := DisplayServer.screen_get_refresh_rate()  # -1 when unknown (web)
	_refresh_ms = maxf(1000.0 / hz, SLOWEST_BASE_MS) if hz > 0.0 else SLOWEST_BASE_MS
	unshaded = CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("devour", [KEY_E, KEY_SPACE])
	_bind("flask", [KEY_Q])
	# Controllers: left stick and d-pad move; A Devours, X drinks, Start
	# pauses, Y restarts after a journey. Menus use Godot's built-in ui_*
	# actions: those include the d-pad and stick, but not A/B, so add them.
	_bind_pad("move_left", [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_bind_pad("move_right", [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_bind_pad("move_up", [JOY_BUTTON_DPAD_UP], JOY_AXIS_LEFT_Y, -1.0)
	_bind_pad("move_down", [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_bind_pad("devour", [JOY_BUTTON_A])
	_bind_pad("flask", [JOY_BUTTON_X])
	_bind_pad("ui_accept", [JOY_BUTTON_A])
	_bind_pad("ui_cancel", [JOY_BUTTON_B])
	# Into the default theme too: controls under a CanvasLayer don't inherit
	# the root window's theme, and the HUD and overlays all live in one.
	var theme := UITheme.build()
	get_tree().root.theme = theme
	ThemeDB.get_default_theme().merge_with(theme)
	_bind("restart", [KEY_R])
	_bind("pause", [KEY_ESCAPE, KEY_P])
	_bind_pad("pause", [JOY_BUTTON_START])
	_bind_pad("restart", [JOY_BUTTON_Y])
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


## Fades to black, changes to `path` (or reloads the current scene when it's
## empty), and fades back in. The tree is unpaused on the way.
func change_scene(path := "") -> void:
	if _fading:
		return
	_fading = true
	if _fade == null:
		var layer := CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		_fade = ColorRect.new()
		_fade.color = Color(0.0, 0.0, 0.0, 0.0)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_fade)
		_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP  # no clicks mid-fade
	var out := create_tween()
	out.tween_property(_fade, "color:a", 1.0, FADE_OUT)
	await out.finished
	get_tree().paused = false
	if path == "":
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fading = false
	var back := create_tween()
	back.tween_property(_fade, "color:a", 0.0, FADE_IN)


## Ratio mitigation. The terminal game used max(0, ATK - DEF), which drops to
## zero once DEF >= ATK; that breaks when hits land many times per second.
static func damage(atk: float, defense: float) -> float:
	return atk * 100.0 / (100.0 + defense)


func sfx(sfx_name: String, pitch_variance := 0.08, pitch := 1.0) -> void:
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
	voice.pitch_scale = entry[2] * pitch * randf_range(1.0 - pitch_variance, 1.0 + pitch_variance)
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


func _process(delta: float) -> void:
	frame_ms = lerpf(frame_ms, delta * 1000.0, 0.05)
	var full := _refresh_ms * FX_FULL
	var lean := _refresh_ms * FX_LEAN
	fx_quality = minf(remap(clampf(frame_ms, full, lean), full, lean, 1.0, FX_MIN), fx_ceiling)


## Whether to spawn one optional cosmetic effect right now (see fx_quality).
func fx_allowed() -> bool:
	return fx_quality >= 1.0 or randf() < fx_quality


## A gem collected: each one in a quick chain rings a note higher.
func gem_chime() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _chime_last > CHIME_RESET:
		_chime_step = 0
	_chime_last = now
	var semitones: int = CHIME_STEPS[mini(_chime_step, CHIME_STEPS.size() - 1)]
	_chime_step += 1
	sfx("gem", 0.02, pow(2.0, semitones / 12.0))


## An expanding ring at `at` (level-ups, the boss's arrival, rewards).
func shockwave(at: Vector2, color: Color, radius := 140.0, duration := 0.45) -> void:
	var parent := get_tree().get_first_node_in_group("effects")
	if parent == null:
		return
	var ring := Shockwave.new()
	ring.position = at
	ring.color = color
	ring.radius = radius
	ring.duration = duration
	ring.material = unshaded
	parent.add_child(ring)


## Dark ichor on the ground, in the monster's color (SplatLayer keeps the
## newest few hundred and draws them all as one node).
func splat(at: Vector2, color: Color, size := 14.0) -> void:
	if not fx_allowed():
		return
	var layer := get_tree().get_first_node_in_group("splat_layer") as SplatLayer
	if layer:
		layer.add(at, Color(color.darkened(0.45), 0.75), size)


## A dying monster's last frame swells and flashes out as it bursts
## (pooled in PopLayer; skipped when every pop is busy).
func kill_pop(sprite: AnimatedSprite2D) -> void:
	var layer := get_tree().get_first_node_in_group("pop_layer") as PopLayer
	if layer == null or sprite.sprite_frames == null or not fx_allowed():
		return
	var flash := 1.6 if Settings.data.get("reduce_flashing", false) else 3.0
	layer.pop(sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame),
		sprite.global_position, sprite.global_scale, sprite.flip_h, flash)


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
	particles.material = unshaded
	particles.position = at
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = maxi(2, roundi(amount * fx_quality))
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
	sprite.material = unshaded
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
		_glow_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED  # glows in the dark
	var glow := Sprite2D.new()
	glow.texture = _glow_texture
	glow.material = _glow_material
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # smooth, unlike the pixel art
	glow.modulate = color
	glow.scale = Vector2.ONE * radius / 32.0
	return glow


## A small pixel number popping off a hit enemy. Pooled in PopLayer (at
## most 40 at once); main sources skip tiny hits.
func damage_number(at: Vector2, amount: float, color := Color.WHITE) -> void:
	if not Settings.data.damage_numbers or not fx_allowed():
		return
	var layer := get_tree().get_first_node_in_group("pop_layer") as PopLayer
	if layer:
		layer.number(at, str(roundi(amount)), color)


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
# Adds controller buttons (and optionally one stick direction) to an action.
func _bind_pad(action: StringName, buttons: Array, axis := -1, direction := 0.0) -> void:
	for button: int in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		InputMap.action_add_event(action, event)
	if axis >= 0:
		var motion := InputEventJoypadMotion.new()
		motion.axis = axis
		motion.axis_value = direction
		InputMap.action_add_event(action, motion)
		InputMap.action_set_deadzone(action, STICK_DEADZONE)


## Whichever device the player last touched decides the prompts.
func _input(event: InputEvent) -> void:
	var pad := gamepad
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		pad = true
		_joy_device = event.device
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false
	if pad != gamepad:
		gamepad = pad
		device_changed.emit(gamepad)


## How to do `action` on the current device, e.g. "E or Space" or "A".
func prompt(action: String) -> String:
	return tr(PROMPTS[action][1 if gamepad else 0])


## `text` with every "{action}" replaced by its current prompt.
func prompts(text: String) -> String:
	text = tr(text)  # the template first, with its {action} marks intact
	for action: String in PROMPTS:
		text = text.replace("{%s}" % action, prompt(action))
	return text


## Controller rumble, only while one is in use and Vibration is on.
func rumble(weak: float, strong: float, seconds: float) -> void:
	if gamepad and Settings.data.get("vibration", true):
		Input.start_joy_vibration(_joy_device, weak, strong, seconds)


func _bind(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
