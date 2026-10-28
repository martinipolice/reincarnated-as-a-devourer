class_name UITheme
## The game's one UI look: souls-like (near-black panels, thin bronze frames,
## bone-white text, gold for focus and value, blood red for danger) drawn in
## crisp pixel style. Game.gd applies build() to the root window, so every
## Control in every scene inherits it. Fonts are OFL pixel fonts (see
## assets/fonts): Jersey 10 for text, Jacquard 12 for big titles.

const BODY_FONT_PATH := "res://assets/fonts/Jersey10-Regular.ttf"
const TITLE_FONT_PATH := "res://assets/fonts/Jacquard12-Regular.ttf"

const INK := Color(0.06, 0.05, 0.08, 0.94)  # panel fill
const INK_LIGHT := Color(0.12, 0.1, 0.14, 0.96)  # hovered / raised fill
const BRONZE := Color(0.55, 0.44, 0.3)  # frames
const GOLD := Color(1.0, 0.82, 0.4)  # focus, value, titles
const BONE := Color(0.92, 0.89, 0.82)  # text
const ASH := Color(0.55, 0.53, 0.58)  # secondary and disabled text
const BLOOD := Color(0.62, 0.08, 0.08)  # HP, death
const BODY_SIZE := 20  # Jersey 10 is drawn on a 10 px grid: stay at 2x
## Card accents, by what a choice is (level-up, blessings, starting weapons).
const NEW_WEAPON := Color(1.0, 0.78, 0.35)
const NEW_PASSIVE := Color(0.45, 0.78, 1.0)
const UPGRADE := Color(0.82, 0.58, 0.36)
const FINAL := Color(0.78, 0.55, 1.0)  # a weapon's last level: evolution next

static var _body: FontFile
static var _title: FontFile


## Pixel fonts must not be smoothed, or they blur.
static func body_font() -> FontFile:
	if _body == null:
		_body = _crisp(load(BODY_FONT_PATH))
	return _body


static func title_font() -> FontFile:
	if _title == null:
		_title = _crisp(load(TITLE_FONT_PATH))
	return _title


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = body_font()
	theme.default_font_size = BODY_SIZE

	theme.set_stylebox("panel", "PanelContainer", OrnateBox.new())
	theme.set_stylebox("panel", "Panel", OrnateBox.new())

	var normal := frame(INK, BRONZE.darkened(0.25), 2)
	var hover := frame(INK_LIGHT, BRONZE, 2)
	var pressed := frame(Color(0.03, 0.02, 0.04, 0.96), GOLD.darkened(0.3), 2)
	var focus := frame(Color(0, 0, 0, 0), GOLD, 3)  # drawn over the normal box
	var disabled := frame(Color(0.05, 0.04, 0.06, 0.8), Color(0.25, 0.23, 0.27), 2)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box: StyleBoxFlat = {"normal": normal, "hover": hover, "pressed": pressed,
			"focus": focus, "disabled": disabled}[state]
		theme.set_stylebox(state, "Button", box)
	theme.set_color("font_color", "Button", BONE)
	theme.set_color("font_hover_color", "Button", GOLD)
	theme.set_color("font_focus_color", "Button", GOLD)
	theme.set_color("font_pressed_color", "Button", GOLD.darkened(0.2))
	theme.set_color("font_disabled_color", "Button", ASH.darkened(0.2))
	theme.set_color("font_color", "Label", BONE)
	theme.set_color("font_outline_color", "Label", INK)
	theme.set_constant("outline_size", "Label", 4)  # readable over grass

	_menu_item(theme)

	theme.set_stylebox("background", "ProgressBar", frame(Color(0.04, 0.03, 0.05, 0.9), BRONZE.darkened(0.2), 1))
	theme.set_stylebox("fill", "ProgressBar", frame(BLOOD, Color(0, 0, 0, 0), 0))
	return theme


# "MenuItem": the souls menu list. Plain words; the focused one is gold on
# a band of light that fades out at both ends. Set a Button's
# theme_type_variation to &"MenuItem" to use it.
static func _menu_item(theme: Theme) -> void:
	theme.add_type("MenuItem")
	theme.set_type_variation("MenuItem", "Button")
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([Color(GOLD, 0.0), Color(GOLD, 0.2), Color(GOLD, 0.0)])
	var band := GradientTexture2D.new()
	band.gradient = gradient
	band.width = 256
	band.height = 4
	var lit := StyleBoxTexture.new()
	lit.texture = band
	var quiet := StyleBoxEmpty.new()
	for box: StyleBox in [lit, quiet]:
		box.content_margin_left = 24
		box.content_margin_right = 24
		box.content_margin_top = 4
		box.content_margin_bottom = 4
	theme.set_stylebox("normal", "MenuItem", quiet)
	theme.set_stylebox("disabled", "MenuItem", quiet)
	theme.set_stylebox("hover", "MenuItem", lit)
	theme.set_stylebox("pressed", "MenuItem", lit)
	theme.set_stylebox("focus", "MenuItem", lit)
	theme.set_color("font_color", "MenuItem", ASH.lightened(0.2))
	theme.set_color("font_hover_color", "MenuItem", BONE)
	theme.set_color("font_focus_color", "MenuItem", GOLD)
	theme.set_color("font_hover_pressed_color", "MenuItem", GOLD)
	theme.set_color("font_pressed_color", "MenuItem", GOLD)
	theme.set_color("font_disabled_color", "MenuItem", Color(ASH, 0.45))
	theme.set_color("font_outline_color", "MenuItem", Color.BLACK)
	theme.set_constant("outline_size", "MenuItem", 4)
	theme.set_font_size("font_size", "MenuItem", 30)


## A souls menu entry (see _menu_item); `sfx` plays on press.
static func menu_item(text: String, action: Callable, sfx := "click") -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = &"MenuItem"
	button.custom_minimum_size = Vector2(320, 44)
	button.focus_entered.connect(func() -> void: Game.sfx("tick", 0.05, 1.3))
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			button.grab_focus())
	button.pressed.connect(func() -> void:
		Game.sfx(sfx, 0.0)
		action.call())
	return button


## A square-cornered pixel frame: `fill` inside a `border`-px edge.
static func frame(fill: Color, edge: Color, border: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(border)
	box.set_corner_radius_all(0)
	box.anti_aliasing = false
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


## A Label in the title font, e.g. for "YOU DIED" or an area's name.
static func title_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", title_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", maxi(4, size / 8))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


static func _crisp(font: FontFile) -> FontFile:
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.generate_mipmaps = false
	return font
