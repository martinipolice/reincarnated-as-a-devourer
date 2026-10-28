class_name Credits
extends CanvasLayer
## The credits roll, from the title screen: slow upward scroll over black,
## held keys (accept) speed it up, back / Esc leaves. CREDITS.md has the
## full table with links and licenses.

signal closed

const SPEED := 40.0  # pixels per second
const FAST := 6.0  # while accept is held
## [kind, text]: "title" gold gothic, "head" a section, "line" plain, "gap".
const ROLL := [
	["title", "Reincarnated as a Devourer"],
	["gap", ""],
	["head", "Design and Programming"],
	["line", "Charles Santos"],
	["gap", ""],
	["head", "Art"],
	["line", "Ninja Adventure Asset Pack: Pixel-Boy and AAA (CC0)"],
	["gap", ""],
	["head", "Music"],
	["line", "Evil temple Ambiance loop: Brandon Morris (CC0)"],
	["line", "Heavy Battle 2, Heavy Dungeon, Heavy Boss Battle 1: MintoDog (CC0)"],
	["line", "Boss Battle #9 [Metal], Boss Battle #2 [Symphonic Metal]: nene (CC0)"],
	["line", "Heavenly Loop: isaiah658 (CC0)"],
	["gap", ""],
	["head", "Sound"],
	["line", "RPG, Impact, Interface and Digital Audio: Kenney (CC0)"],
	["gap", ""],
	["head", "Fonts"],
	["line", "Jacquard 12 and Jersey 10: Sarah Cadigan-Fried (SIL OFL 1.1)"],
	["gap", ""],
	["head", "Engine"],
	["line", "Godot Engine (MIT)"],
	["gap", ""],
	["gap", ""],
	["line", "Thank you for playing."],
]

var _roll: VBoxContainer
var _started := false


func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	var black := ColorRect.new()
	black.color = Color(0.01, 0.005, 0.02, 1.0)
	add_child(black)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_roll = VBoxContainer.new()
	_roll.add_theme_constant_override("separation", 6)
	add_child(_roll)
	for entry: Array in ROLL:
		match entry[0]:
			"title":
				_roll.add_child(UITheme.title_label(entry[1], 72, UITheme.BONE))
				_roll.add_child(OrnateRule.new(480.0))
			"head":
				_roll.add_child(UITheme.title_label(entry[1], 36, UITheme.GOLD))
			"line":
				var label := Label.new()
				label.text = entry[1]
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				label.add_theme_font_size_override("font_size", 22)
				_roll.add_child(label)
			"gap":
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(0, 36)
				_roll.add_child(gap)
	var hint := Label.new()
	hint.text = Game.prompts("{back} to return")
	hint.add_theme_color_override("font_color", UITheme.ASH)
	add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -200
	hint.offset_top = -40
	hide()


func open() -> void:
	var view := get_viewport().get_visible_rect().size
	_roll.size = Vector2(view.x, 0)
	_roll.position = Vector2(0, view.y * 0.45)  # the title is up at once
	_started = true
	show()
	Game.sfx("open_menu", 0.0)


func close() -> void:
	_started = false
	hide()
	Game.sfx("close_menu", 0.0)
	closed.emit()


func _process(delta: float) -> void:
	if not _started:
		return
	var speed := SPEED * (FAST if Input.is_action_pressed("ui_accept") else 1.0)
	_roll.position.y -= speed * delta
	if _roll.position.y + _roll.size.y < 0.0:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close()
