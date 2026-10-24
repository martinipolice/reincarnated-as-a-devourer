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

	theme.set_stylebox("panel", "PanelContainer", frame(INK, BRONZE, 2))
	theme.set_stylebox("panel", "Panel", frame(INK, BRONZE, 2))

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

	theme.set_stylebox("background", "ProgressBar", frame(Color(0.04, 0.03, 0.05, 0.9), BRONZE.darkened(0.2), 1))
	theme.set_stylebox("fill", "ProgressBar", frame(BLOOD, Color(0, 0, 0, 0), 0))
	return theme


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
