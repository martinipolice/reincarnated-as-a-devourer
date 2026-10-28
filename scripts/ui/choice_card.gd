class_name ChoiceCard
extends Button
## A tall choice card, Hades-boon style, in the souls frame: the accent color
## says what kind of choice it is (UITheme.NEW_WEAPON and friends). The focused
## or hovered card lifts and lights its frame. Used by the level-up, the
## goddess's blessing and the starting-weapon pick.

const SIZE := Vector2(250, 330)
const COMPACT_SIZE := Vector2(220, 236)
const LIFT := 1.05

var accent: Color
var _dim_box: OrnateBox
var _lit_box: OrnateBox
var _tween: Tween


## `tag`: top-right corner (e.g. "NEW WEAPON"); `subtitle`: under the name;
## `hotkey`: top-left (e.g. "1"). `compact` fits three on the shrine.
func _init(icon_texture: Texture2D, title: String, tag: String, subtitle: String, body: String,
		accent_color: Color, hotkey := "", compact := false) -> void:
	accent = accent_color
	custom_minimum_size = COMPACT_SIZE if compact else SIZE
	_dim_box = OrnateBox.new(UITheme.INK, accent.darkened(0.45))
	_lit_box = OrnateBox.new(UITheme.INK_LIGHT, accent)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(state, _dim_box)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4 if compact else 8)
	add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		column.set("offset_" + side, 14.0 if side == "left" else -14.0)
	column.offset_top = 10.0
	column.offset_bottom = -12.0

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_text(hotkey, 18, UITheme.ASH))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	top.add_child(_text(tag, 18, accent))
	column.add_child(top)

	var art := TextureRect.new()
	art.texture = icon_texture
	art.custom_minimum_size = Vector2(48, 48) if compact else Vector2(72, 72)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(art)

	var name_label := UITheme.title_label(title, 30 if compact else 36, UITheme.BONE)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)
	if subtitle != "":
		var sub := _text(subtitle, 20, accent.lightened(0.15))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(sub)
	column.add_child(OrnateRule.new(120.0, accent.darkened(0.2)))
	var text := _text(body, 18 if compact else 20, UITheme.BONE)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(text)

	focus_entered.connect(_light.bind(true))
	focus_exited.connect(_light.bind(false))
	mouse_entered.connect(func() -> void:
		if not disabled:
			grab_focus())
	resized.connect(func() -> void: pivot_offset = size / 2.0)


func _ready() -> void:
	pivot_offset = size / 2.0


func _light(on: bool) -> void:
	if disabled:
		on = false
	for state: String in ["normal", "hover", "pressed"]:
		add_theme_stylebox_override(state, _lit_box if on else _dim_box)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE * (LIFT if on else 1.0), 0.16)
	if on:
		Game.sfx("tick", 0.05, 1.2)


## Greyed out, with `why` replacing the body (a locked starting weapon).
func lock(why: String) -> void:
	disabled = true
	modulate = Color(0.55, 0.52, 0.6)
	var column := get_child(0)
	(column.get_child(column.get_child_count() - 1) as Label).text = why


## Deals the card in: a short rise and fade, `delay` seconds from now.
func deal(delay: float) -> void:
	modulate.a = 0.0
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(delay)
	tween.tween_property(self, "modulate:a", 1.0, 0.22)


func _text(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
