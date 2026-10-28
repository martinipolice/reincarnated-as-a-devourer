extends Control
## The title screen, souls style: the name over a dark sky with rising
## embers and "Press any button"; then a plain menu list. Continue the
## journey in progress (saved at the last goddess shrine) or begin a new one
## (a hero only reincarnates once, so that abandons the old one, after a
## confirm). Once a second starting weapon is unlocked (Unlocks), beginning
## a journey first deals the starting weapons as cards.

const RUN_SCENE := "res://scenes/main.tscn"
const ENDING := preload("res://scripts/ui/ending.gd")
const GODDESS_FRAMES := preload("res://assets/ninja/goddess/sprite_frames.tres")
const VIGNETTE := preload("res://scripts/ui/vignette.gd")
const SKY_TOP := Color(0.02, 0.015, 0.04)
const SKY_LOW := Color(0.11, 0.05, 0.08)

## Shown once per session: coming back from a journey goes straight to the menu.
static var _greeted := false

var _menu: PauseMenu
var _list: VBoxContainer
var _press: Label
var _press_tween: Tween
var _footer: Label
var _waiting := true  # for "any button"
var _overlay: CanvasLayer  # the starting-weapon pick, while open


func _ready() -> void:
	if Benchmark.requested() > 0:  # performance test: straight into a run
		Save.resume = false
		get_tree().change_scene_to_file.call_deferred(RUN_SCENE)
		return
	Music.muffle(false)
	Music.set_intensity(1.0)
	Music.play("title", 2.0)
	_build()
	_menu = PauseMenu.new()
	add_child(_menu)
	_menu.closed.connect(_focus_list)
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
	_list.add_child(UITheme.menu_item("How to Play", _menu.open.bind(null, "How to Play")))
	_list.add_child(UITheme.menu_item("Settings", _menu.open.bind(null, "Settings")))
	if not OS.has_feature("web"):
		_list.add_child(UITheme.menu_item("Quit", get_tree().quit, "back"))


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
	var sky := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, SKY_TOP)
	gradient.set_color(1, SKY_LOW)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	sky.texture = texture
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(sky)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# The goddess, faint, high behind the name: watching from afar.
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	stage.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	var glow := Game.make_glow(Color(1.0, 0.85, 0.55, 0.3), 230.0)
	glow.position = Vector2(0, 190)
	stage.add_child(glow)
	var goddess := AnimatedSprite2D.new()
	goddess.sprite_frames = GODDESS_FRAMES
	goddess.play("run_down")
	goddess.position = Vector2(0, 180)
	goddess.scale = Vector2(10, 10)
	goddess.modulate = Color(1, 1, 1, 0.14)
	stage.add_child(goddess)
	var embers := CPUParticles2D.new()
	embers.amount = 60
	embers.lifetime = 7.0
	embers.preprocess = 7.0
	embers.position = Vector2(0, 760)
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(760, 10)
	embers.direction = Vector2(0, -1)
	embers.spread = 18.0
	embers.gravity = Vector2(6, -4)
	embers.initial_velocity_min = 30.0
	embers.initial_velocity_max = 80.0
	embers.scale_amount_min = 2.0
	embers.scale_amount_max = 4.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.55, 0.2, 0.0))
	fade.set_color(1, Color(0.8, 0.2, 0.1, 0.0))
	fade.add_point(0.2, Color(1.0, 0.6, 0.25, 0.9))
	embers.color_ramp = fade
	stage.add_child(embers)

	var vignette := ColorRect.new()
	vignette.set_script(VIGNETTE)
	add_child(vignette)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_top = 150
	var name_label := UITheme.title_label("Reincarnated as a Devourer", 84, UITheme.BONE)
	column.add_child(name_label)
	column.add_child(OrnateRule.new(520.0))
	var quote := Label.new()
	quote.text = "Hero from another world... survive, grow, and face your fate."
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote.add_theme_color_override("font_color", Color(0.75, 0.7, 0.85))
	column.add_child(quote)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
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
