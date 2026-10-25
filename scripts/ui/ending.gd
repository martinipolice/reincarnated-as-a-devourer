extends CanvasLayer
## The end of a journey won. The Demon King kneels and says his last words,
## closing the story the goddess told at her shrines (the red sky, "Forgive
## me", the carvings of the two of them). Then the hero chooses:
## - Spare him: the goddess comes for him at last. "Reunion"; the cycle breaks.
## - Devour him: the hero takes his power and his place. "The New Demon
##   King"; the cycle goes on, as it did for every hero before.
## main.gd awaits play() and gets back "spare" or "devour".

signal _advanced
signal _chosen(id: String)

const KING_FRAMES := preload("res://assets/ninja/demon_king/sprite_frames.tres")
const GODDESS_FRAMES := preload("res://assets/ninja/goddess/sprite_frames.tres")
const HERO_FRAMES := preload("res://assets/ninja/player/sprite_frames.tres")
const LINE_FADE := 0.6
const MIN_LINE_TIME := 0.5  # a line can't be skipped before this
## The king's last words, then the choice.
const LAST_WORDS := [
	"The Demon King sinks to his knees. The red sky dims above him.",
	"\"So she sent another... the way she sent the ones before you.\"",
	"\"We were bound once, she and I, before the sky turned red.\"",
	"\"She asked me to end this world's hunger. I became it instead.\"",
	"\"Finally... Tell her... I waited.\"",
]
const ENDINGS := {
	"spare": {
		"title": "Reunion",
		"subtitle": "The cycle is broken.",
		"music": "shrine",
		"lines": [
			"You stay your hunger.",
			"Light spills through the broken sky. The goddess kneels beside him.",
			"Goddess: \"I came. Forgive me for taking so long.\"",
			"Together they fade into the dawn, and the red sky breaks.",
		],
	},
	"devour": {
		"title": "The New Demon King",
		"subtitle": "The cycle continues.",
		"music": "title",
		"lines": [
			"You Devour the Demon King.",
			"His power floods you: endless, and starving.",
			"Goddess, from very far away: \"No... not you too.\"",
			"The sky stays red. Somewhere, a new hero is reincarnated.",
		],
	},
}

var _waiting := false
var _shown_at := 0
var _root: Control  # everything, so the scene can fade as one
var _dim: ColorRect
var _veil: ColorRect
var _king: TextureRect
var _other: TextureRect
var _text: Label
var _prompt: Label
var _choices: HBoxContainer
var _title: Label
var _subtitle: Label


func _ready() -> void:
	layer = 14
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide()


## Plays the whole ending; returns "spare" or "devour".
func play() -> String:
	_title.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	_other.modulate.a = 0.0
	_king.modulate = Color.WHITE
	_veil.color = Color(0, 0, 0, 0)
	_choices.hide()
	_root.modulate.a = 0.0
	show()
	await create_tween().tween_property(_root, "modulate:a", 1.0, 1.0).finished
	for line: String in LAST_WORDS:
		await _say(line)
	var choice := await _choose()
	var ending: Dictionary = ENDINGS[choice]
	Music.play(ending.music, 2.0)
	if choice == "spare":
		await _spare_scene(ending.lines)
	else:
		await _devour_scene(ending.lines)
	_text.text = ""
	_prompt.text = ""
	_title.text = ending.title
	_subtitle.text = ending.subtitle
	var reveal := create_tween()
	reveal.tween_property(_title, "modulate:a", 1.0, 1.2)
	reveal.tween_property(_subtitle, "modulate:a", 1.0, 0.8)
	await reveal.finished
	await _wait_for_advance()
	await create_tween().tween_property(_root, "modulate:a", 0.0, 0.8).finished
	hide()
	return choice


func _spare_scene(lines: Array) -> void:
	await _say(lines[0])
	_other.texture = _frame(GODDESS_FRAMES)
	Game.sfx("shrine", 0.0)
	create_tween().tween_property(_other, "modulate:a", 1.0, 1.5)
	await _say(lines[1])
	await _say(lines[2])
	# Both fade into a warm dawn.
	var dawn := create_tween().set_parallel()
	dawn.tween_property(_veil, "color", Color(1.0, 0.86, 0.5, 0.22), 2.0)
	dawn.tween_property(_king, "modulate:a", 0.0, 2.0)
	dawn.tween_property(_other, "modulate:a", 0.0, 2.0)
	Game.sfx("level_up", 0.0)
	await _say(lines[3])


func _devour_scene(lines: Array) -> void:
	_other.texture = _frame(HERO_FRAMES)
	_other.modulate = Color(1, 1, 1, 1)
	Game.sfx("devour", 0.0)
	Game.sfx("doom", 0.0)
	Game.shake(0.6)
	Game.rumble(0.6, 1.0, 0.8)
	var feed := create_tween().set_parallel()
	feed.tween_property(_king, "modulate", Color(0.6, 0.1, 0.2, 0.0), 1.6)
	feed.tween_property(_other, "modulate", Color(1.8, 0.35, 0.4), 1.6)
	feed.tween_property(_veil, "color", Color(0.45, 0.0, 0.05, 0.5), 1.6)
	await _say(lines[0])
	await _say(lines[1])
	await _say(lines[2])
	Game.sfx("toll", 0.0)
	await _say(lines[3])


# Shows one line and waits for the player to go on.
func _say(line: String) -> void:
	_text.text = line
	_text.modulate.a = 0.0
	create_tween().tween_property(_text, "modulate:a", 1.0, LINE_FADE)
	await _wait_for_advance()


func _wait_for_advance() -> void:
	_prompt.text = Game.prompts("{accept} to continue")
	_shown_at = Time.get_ticks_msec()
	_waiting = true
	await _advanced
	_waiting = false
	_prompt.text = ""


func _choose() -> String:
	_text.text = "His essence flickers before you. What will you do?"
	_choices.show()
	(_choices.get_child(0) as Button).grab_focus()
	var choice: String = await _chosen
	_choices.hide()
	Game.sfx("pick", 0.0)
	return choice


func _input(event: InputEvent) -> void:
	if not visible or not _waiting:
		return
	var accept: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("devour") \
		or (event is InputEventMouseButton and event.pressed)
	if accept and Time.get_ticks_msec() - _shown_at >= MIN_LINE_TIME * 1000.0:
		get_viewport().set_input_as_handled()
		_advanced.emit()


static func _frame(frames: SpriteFrames) -> Texture2D:
	var animation: StringName = &"idle_down" if frames.has_animation(&"idle_down") else frames.get_animation_names()[0]
	return frames.get_frame_texture(animation, 0)


func _build() -> void:
	_root = Control.new()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.01, 0.03, 0.94)
	_root.add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil = ColorRect.new()
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_veil)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	_root.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stage := HBoxContainer.new()
	stage.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.add_theme_constant_override("separation", 60)
	column.add_child(stage)
	_king = _portrait(_frame(KING_FRAMES), Vector2(300, 220))
	stage.add_child(_king)
	_other = _portrait(null, Vector2(160, 220))
	stage.add_child(_other)

	_text = Label.new()
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(820, 64)
	_text.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_text.add_theme_font_size_override("font_size", 30)
	_text.add_theme_color_override("font_color", UITheme.BONE)
	column.add_child(_text)
	_choices = HBoxContainer.new()
	_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	_choices.add_theme_constant_override("separation", 30)
	column.add_child(_choices)
	for entry: Array in [["spare", "Spare him"], ["devour", "Devour him"]]:
		var button := Button.new()
		button.text = entry[1]
		button.custom_minimum_size = Vector2(260, 52)
		button.add_theme_font_size_override("font_size", 30)
		button.pressed.connect(func() -> void: _chosen.emit(entry[0]))
		_choices.add_child(button)
	_title = UITheme.title_label("", 72, UITheme.GOLD)
	column.add_child(_title)
	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 30)
	_subtitle.add_theme_color_override("font_color", UITheme.ASH)
	column.add_child(_subtitle)
	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_color", UITheme.ASH)
	column.add_child(_prompt)


func _portrait(texture: Texture2D, size: Vector2) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.texture = texture
	portrait.custom_minimum_size = size
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return portrait
