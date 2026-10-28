extends Control
## The title screen, souls style: the name in a crest over the game's own
## world at night (TitleBackdrop) and "Press any button"; then a plain menu
## list. Continue the
## journey in progress (saved at the last goddess shrine) or begin a new one
## (a hero only reincarnates once, so that abandons the old one, after a
## confirm). Once a second starting weapon is unlocked (Unlocks), beginning
## a journey first deals the starting weapons as cards. Also: the Codex,
## how to play, settings and the credits.

const RUN_SCENE := "res://scenes/main.tscn"
const ENDING := preload("res://scripts/ui/ending.gd")
const VIGNETTE := preload("res://scripts/ui/vignette.gd")
const EMBER := Color(0.85, 0.16, 0.12)  # the crest's accent: hunger, blood
## The light that sweeps across the name every few seconds.
const SHINE_EVERY := 6.0

## Shown once per session: coming back from a journey goes straight to the menu.
static var _greeted := false

var _menu: PauseMenu
var _codex: Codex
var _credits: Credits
var _list: VBoxContainer
var _press: Label
var _press_tween: Tween
var _footer: Label
var _waiting := true  # for "any button"
var _overlay: CanvasLayer  # the starting-weapon pick, while open
var _crest: Control
var _glow: Sprite2D
var _shine: TextureRect
var _name: Label


func _ready() -> void:
	if Benchmark.requested() > 0:  # performance test: straight into a run
		Save.resume = false
		get_tree().change_scene_to_file.call_deferred(RUN_SCENE)
		return
	Music.muffle(false)
	Music.set_intensity(1.0)
	Music.play("title", 2.0)
	var ambience := Ambience.new()
	ambience.offset_db = -6.0
	add_child(ambience)
	ambience.play("forest", 4.0)
	_build()
	_menu = PauseMenu.new()
	add_child(_menu)
	_menu.closed.connect(_focus_list)
	_codex = Codex.new()
	add_child(_codex)
	_codex.closed.connect(_focus_list)
	_credits = Credits.new()
	add_child(_credits)
	_credits.closed.connect(_focus_list)
	if _greeted:
		_show_menu(false)


func _input(event: InputEvent) -> void:
	if not _waiting:
		return
	var any := event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton
	if any and event.is_pressed():
		get_viewport().set_input_as_handled()
		Game.sfx("pick", 0.0)
		_show_menu(true)


func _unhandled_input(event: InputEvent) -> void:
	if _overlay and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Game.sfx("back", 0.0)
		_close_pick()


func _show_menu(animate: bool) -> void:
	_waiting = false
	_greeted = true
	if _press_tween:
		_press_tween.kill()
	_press.hide()
	_fill_list()
	_list.show()
	_footer.show()
	if animate:
		for node: CanvasItem in [_list, _footer]:
			node.modulate.a = 0.0
			create_tween().tween_property(node, "modulate:a", 1.0, 0.5)
	_focus_list()


func _fill_list() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if Save.has_journey():
		var journey: Dictionary = Save.data.journey
		_list.add_child(UITheme.menu_item("Continue", _continue, "pick"))
		var where := Label.new()
		where.text = "Day %d  ·  Level %d" % [int(journey.day), int(journey.level)]
		where.add_theme_color_override("font_color", UITheme.ASH)
		where.add_theme_font_size_override("font_size", 18)
		where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(where)
	_list.add_child(UITheme.menu_item("New Journey", _new_journey, "pick"))
	_list.add_child(UITheme.menu_item("Codex", _codex.open))
	_list.add_child(UITheme.menu_item("How to Play", _menu.open.bind(null, "How to Play")))
	_list.add_child(UITheme.menu_item("Settings", _menu.open.bind(null, "Settings")))
	_list.add_child(UITheme.menu_item("Credits", _credits.open))
	if not OS.has_feature("web"):
		_list.add_child(UITheme.menu_item("Quit", get_tree().quit, "back"))
	for child in _list.get_children():
		if child is Button:
			child.custom_minimum_size.y = 36


func _focus_list() -> void:
	for child in _list.get_children():
		if child is Button:
			(child as Button).grab_focus()
			return


func _continue() -> void:
	Save.resume = true
	Game.change_scene(RUN_SCENE)


func _new_journey() -> void:
	if Save.has_journey():
		var message := "A hero reincarnates only once.\nBeginning anew abandons your journey on Day %d." % int(Save.data.journey.day)
		if not await ConfirmDialog.ask(self, message, "Abandon it", "Keep it"):
			_focus_list()
			return
	if Unlocks.unlocked(Save.data).size() > 1:
		_open_pick()
	else:
		_begin(Unlocks.STARTERS[0][0])


func _begin(weapon_path: String) -> void:
	Save.data.journey = null
	Save.data.start_weapon = weapon_path
	Save.save_game()
	Save.resume = false
	Game.change_scene(RUN_SCENE)


# The starting weapons as cards: locked ones say how to earn them.
func _open_pick() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 20
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.005, 0.02, 0.96)
	_overlay.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	center.add_child(column)
	column.add_child(UITheme.title_label("Your First Weapon", 52, UITheme.GOLD))
	column.add_child(OrnateRule.new(420.0))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 14)
	column.add_child(grid)
	var unlocked := Unlocks.unlocked(Save.data)
	var focus: ChoiceCard
	for i in Unlocks.STARTERS.size():
		var entry: Array = Unlocks.STARTERS[i]
		var weapon: WeaponData = load(entry[0])
		var last: bool = entry[0] == String(Save.data.get("start_weapon", ""))
		var card := ChoiceCard.new(weapon.icon, weapon.display_name, "LAST" if last else "",
			"", weapon.description, UITheme.NEW_WEAPON, "", true)
		grid.add_child(card)
		card.deal(0.05 * i)
		if entry[0] in unlocked:
			card.pressed.connect(func() -> void:
				Game.sfx("pick", 0.0)
				_begin(entry[0]))
			if focus == null or last:
				focus = card
		else:
			card.lock("Locked\n" + entry[1])
	var hint := Label.new()
	hint.text = Game.prompts("Earn more by going further  ·  {back} to return")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", UITheme.ASH)
	column.add_child(hint)
	Game.sfx("open_menu", 0.0)
	focus.grab_focus.call_deferred()


func _close_pick() -> void:
	_overlay.queue_free()
	_overlay = null
	_focus_list()


func _build() -> void:
	add_child(TitleBackdrop.new())
	var fog := TitleBackdrop.make_fog()
	add_child(fog)
	fog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vignette := ColorRect.new()
	vignette.set_script(VIGNETTE)
	add_child(vignette)
	# A dark pool under the crest and the menu, so they read over the world.
	var shade := TextureRect.new()
	shade.texture = _radial(Color(0.01, 0.0, 0.02, 0.9), Color(0.01, 0.0, 0.02, 0.0))
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	shade.offset_left = -820
	shade.offset_right = 820
	shade.offset_top = -480
	shade.offset_bottom = 420

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_top = 40
	_crest = _build_crest()
	column.add_child(_crest)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	column.add_child(gap)

	_press = Label.new()
	_press.text = "Press any button"
	_press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_press.add_theme_font_size_override("font_size", 30)
	column.add_child(_press)
	_press_tween = create_tween().set_loops()
	_press_tween.tween_property(_press, "modulate:a", 0.25, 1.1).set_trans(Tween.TRANS_SINE)
	_press_tween.tween_property(_press, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_list.hide()
	column.add_child(_list)

	_footer = Label.new()
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.add_theme_color_override("font_color", UITheme.ASH)
	_footer.add_theme_font_size_override("font_size", 18)
	add_child(_footer)
	_footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_footer.offset_top = -60
	_footer.offset_bottom = -12
	var seen := []
	for id: String in ["spare", "devour"]:
		seen.append(ENDING.ENDINGS[id].title if id in Save.data.endings else "???")
	_footer.text = "Journeys %d   ·   Victories %d   ·   Best day %d   ·   Endings: %s\nv%s" % [
		int(Save.data.journeys), int(Save.data.wins), int(Save.data.best_day),
		"  ·  ".join(seen), ProjectSettings.get_setting("application/config/version", "dev")]
	_footer.hide()


# The name as the screen's centerpiece: a small spaced line, the great word
# in gothic with an ember glow behind it and a light that sweeps across it,
# then a red rule and the tagline.
func _build_crest() -> Control:
	var crest := VBoxContainer.new()
	crest.add_theme_constant_override("separation", 0)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 14)
	top.add_child(OrnateRule.new(150.0, UITheme.GOLD.darkened(0.2)))
	var small := Label.new()
	small.text = "REINCARNATED  AS  A"
	small.add_theme_font_size_override("font_size", 30)
	small.add_theme_color_override("font_color", UITheme.GOLD)
	top.add_child(small)
	top.add_child(OrnateRule.new(150.0, UITheme.GOLD.darkened(0.2)))
	crest.add_child(top)

	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 150)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crest.add_child(stage)
	_glow = Game.make_glow(Color(EMBER, 0.55), 300.0)
	_glow.scale = Vector2(14.0, 3.2)  # a wide ember haze behind the word
	stage.add_child(_glow)
	_name = UITheme.title_label("Devourer", 156, UITheme.BONE)
	_name.add_theme_color_override("font_shadow_color", Color(EMBER.darkened(0.55), 0.9))
	_name.add_theme_constant_override("shadow_offset_y", 6)
	_name.add_theme_constant_override("shadow_offset_x", 0)
	_name.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW  # the shine shows only on the letters
	stage.add_child(_name)
	_name.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_name.offset_top = -18
	_shine = TextureRect.new()
	_shine.texture = _band()
	_shine.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shine.size = Vector2(90, 260)
	_shine.rotation = 0.35
	_shine.position = Vector2(-400, -40)
	_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.add_child(_shine)
	stage.resized.connect(func() -> void: _glow.position = stage.size / 2.0 + Vector2(0, 10))

	crest.add_child(OrnateRule.new(560.0, EMBER))
	var tagline := Label.new()
	tagline.text = "One life. Twenty days. Devour, or be devoured."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 22)
	tagline.add_theme_color_override("font_color", Color(0.78, 0.74, 0.86))
	crest.add_child(tagline)
	_animate_crest(crest)
	return crest


# The crest rises out of the dark once, then breathes; the shine sweeps by.
func _animate_crest(crest: Control) -> void:
	crest.modulate.a = 0.0
	var reveal := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal.tween_property(crest, "modulate:a", 1.0, 0.4 if _greeted else 1.6)
	var breathe := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	breathe.tween_property(_glow, "modulate:a", 0.32, 2.6)
	breathe.tween_property(_glow, "modulate:a", 0.6, 2.6)
	var sweep := create_tween().set_loops()
	sweep.tween_interval(SHINE_EVERY - 1.2)
	sweep.tween_property(_shine, "position:x", 1200.0, 1.2).from(-300.0).set_trans(Tween.TRANS_SINE)


func _radial(inner: Color, outer: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, inner)
	gradient.set_color(1, outer)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.42)
	texture.fill_to = Vector2(1.0, 0.42)
	return texture


func _band() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([Color(1, 0.72, 0.3, 0.0), Color(1, 0.78, 0.38, 0.85), Color(1, 0.72, 0.3, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 8
	return texture
