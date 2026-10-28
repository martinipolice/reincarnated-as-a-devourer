class_name PauseMenu
extends CanvasLayer
## Esc during a run: pauses, with pages for your build, how to play and the
## settings, plus quitting to the title. The title screen opens the same menu
## without the run pages. Keyboard and gamepad friendly: a page button always
## has focus, and Esc goes back.

signal closed

const TITLE_SCENE := "res://scenes/ui/title.tscn"

var _main: Node  # the run, or null on the title screen
var _nav: VBoxContainer
var _page: VBoxContainer
var _heading_label: Label
var _confirming := false


func _ready() -> void:
	layer = 16  # above the hints
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide()


## `main`: the run scene, or null for the title screen's version, which
## opens on `page` ("How to Play" or "Settings").
func open(main: Node = null, page := "How to Play") -> void:
	_main = main
	for child in _nav.get_children():
		_nav.remove_child(child)  # now, so get_child(0) below is a new button
		child.queue_free()
	var first: Button
	if _main:
		_heading_label.text = "Paused"
		first = _nav_button("Resume", close)
		_nav_button("Your Build", _show_build)
	else:
		_heading_label.text = "Menu"
	var help := _nav_button("How to Play", _show_how_to_play)
	var settings := _nav_button("Settings", _show_settings)
	if _main:
		_nav_button("Quit to Title", _quit)
	else:
		_nav_button("Back", close)
		first = settings if page == "Settings" else help
	show()
	Music.muffle(true)
	if _main:
		get_tree().paused = true
		_show_build()
	elif page == "Settings":
		_show_settings()
	else:
		_show_how_to_play()
	Game.sfx("open_menu", 0.0)
	first.grab_focus.call_deferred()


func close() -> void:
	hide()
	Music.muffle(false)
	if _main:
		get_tree().paused = false
	Game.sfx("close_menu", 0.0)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and not _confirming and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		close()


func _nav_button(text: String, action: Callable) -> Button:
	var button := UITheme.menu_item(text, action)
	button.custom_minimum_size = Vector2(230, 42)
	button.add_theme_font_size_override("font_size", 26)
	_nav.add_child(button)
	return button


func _clear_page() -> void:
	for child in _page.get_children():
		_page.remove_child(child)
		child.queue_free()


func _heading(text: String) -> Label:
	return HowToPlay.heading(text)


func _line(text: String, color := UITheme.BONE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	return label


func _show_how_to_play() -> void:
	_clear_page()
	_page.add_child(HowToPlay.build())


# Everything you've become on this journey, at a glance.
func _show_build() -> void:
	_clear_page()
	var player: Player = _main.player
	_page.add_child(_heading(tr("Level %d  ·  Day %d") % [player.level, _main.day()]))
	var stats := GridContainer.new()
	stats.columns = 4
	stats.add_theme_constant_override("h_separation", 24)
	var rows := [
		["HP", "%d / %d" % [ceili(player.hp), player.stat("max_hp")]],
		["Damage", "%d%%" % roundi(player.stat("might") * 100.0)],
		["Defense", "%d" % roundi(player.stat("defense"))],
		["Attack speed", "%d%%" % roundi(player.stat("haste") * 100.0)],
		["Move speed", "%d" % roundi(player.stat("move_speed"))],
		["Pickup range", "%d" % roundi(player.stat("pickup_radius"))],
		["Regen", tr("%.1f HP/s") % player.stat("regen")],
		["Tears", tr("%d / %d  ·  %d%% heal") % [player.flask_charges, player.flask_max, roundi(player.flask_heal * 100.0)]],
		["Fate", tr("%d rerolls  ·  %d banishes") % [_main.rerolls, _main.banishes]],
	]
	for row: Array in rows:
		stats.add_child(_line(row[0], UITheme.ASH))
		stats.add_child(_line(row[1]))
	_page.add_child(stats)

	_page.add_child(_heading("Weapons and Upgrades"))
	var items := GridContainer.new()
	items.columns = 2
	items.add_theme_constant_override("h_separation", 24)
	for upgrade: Resource in player.upgrade_levels:
		var row := HBoxContainer.new()
		var icon := TextureRect.new()
		icon.texture = upgrade.icon
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
		var level: int = player.upgrade_levels[upgrade]
		var text: String = upgrade.display_name
		if upgrade in player.branches:
			text += ": " + tr(Branches.get_branch(upgrade, player.branches[upgrade]).display_name)
		if upgrade.max_level < 100:
			var top: int = Branches.MAX_LEVEL if upgrade is WeaponData and Branches.has(upgrade) else upgrade.max_level
			text += tr("  Lv %d / %d") % [level, top]
		row.add_child(_line(text))
		items.add_child(row)
	_page.add_child(items)

	var extras := []
	for essence: EssenceData in player.essences:
		var mutated: int = player.mutations.get(essence, 0)
		var line := "%s x%d" % [tr(essence.display_name), player.essences[essence]]
		if mutated > 0:
			line += tr(" (%d %s)") % [mutated, tr(Mutations.of(essence)[0])]
		extras.append(line)
	_page.add_child(_heading(tr("Devoured  ·  Hunger: %s") % tr(Hunger.NAMES[player.hunger_tier()])))
	_page.add_child(_line(", ".join(extras) if extras else "Nothing yet. Elites drop essences.", UITheme.BONE if extras else UITheme.ASH))
	_page.add_child(_heading("Resonances"))
	if player.resonances.is_empty():
		_page.add_child(_line("None yet. Hold 2 of each of certain essence pairs.", UITheme.ASH))
	for entry: Array in Resonances.TABLE:
		if entry[0] in player.resonances:
			_page.add_child(_line("%s: %s" % [entry[0], entry[3]], UITheme.GOLD))
	var training := []
	for t: TrainingData in _main.SHRINE.TRAININGS:
		var rank := int(_main.training_ranks.get(t.id, 0))
		if rank > 0:
			training.append("%s %d" % [t.display_name.get_slice(" ", 0), rank])
	_page.add_child(_heading("Training"))
	_page.add_child(_line(", ".join(training) if training else "None yet. The goddess teaches it at her shrine.", UITheme.BONE if training else UITheme.ASH))


func _show_settings() -> void:
	_clear_page()
	_page.add_child(_heading("Settings"))
	_slider("Master volume", "volume")
	_slider("Music", "music")
	_slider("Sound effects", "sfx")
	_slider("Screen shake", "shake")
	_toggle("Damage numbers", "damage_numbers")
	_toggle("Reduce flashing", "reduce_flashing")
	_toggle("Show FPS", "show_fps")
	_toggle("Controller vibration", "vibration")
	_toggle("Fullscreen", "fullscreen")
	_toggle("Beginner hints", "hints")
	var reset := Button.new()
	reset.text = "Show all hints again"
	reset.custom_minimum_size = Vector2(260, 40)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.pressed.connect(func() -> void:
		Settings.set_value("seen_hints", [])
		Settings.set_value("hints", true)
		reset.text = "Hints will show again"
		Game.sfx("click", 0.0))
	_page.add_child(reset)


func _slider(text: String, key: String) -> void:
	var row := HBoxContainer.new()
	var label := _line(text)
	label.custom_minimum_size = Vector2(200, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.1
	slider.value = float(Settings.data[key])
	slider.custom_minimum_size = Vector2(260, 28)
	var value := _line("%d%%" % roundi(slider.value * 100.0), UITheme.GOLD)
	slider.value_changed.connect(func(v: float) -> void:
		value.text = "%d%%" % roundi(v * 100.0)
		Settings.set_value(key, v))
	row.add_child(slider)
	row.add_child(value)
	_page.add_child(row)


func _toggle(text: String, key: String) -> void:
	var check := CheckButton.new()
	check.text = text
	check.button_pressed = bool(Settings.data[key])
	check.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	check.toggled.connect(func(on: bool) -> void:
		Game.sfx("toggle", 0.0)
		Settings.set_value(key, on))
	_page.add_child(check)


# Quitting loses everything since the last shrine, so it asks first.
func _quit() -> void:
	# A journey saves at the goddess's shrines; before the first one,
	# quitting ends it.
	var message := "Quit to the title?
You'll resume on Day %d, at her last shrine." % int(Save.data.journey.day) 		if Save.has_journey() else "Quit to the title?
No shrine has saved you yet: this journey ends."
	_confirming = true
	var yes := await ConfirmDialog.ask(self, message, "Quit", "Stay")
	_confirming = false
	if not yes:
		(_nav.get_child(_nav.get_child_count() - 1) as Button).grab_focus()
		return
	if not Save.has_journey():
		Save.end_journey(_main.day(), false)  # counts in your records
	Music.muffle(false)
	Hints.clear()
	Game.change_scene(TITLE_SCENE)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.03, 0.88)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	margin.add_child(row)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	row.add_child(side)
	_heading_label = UITheme.title_label("Paused", 48, UITheme.GOLD)
	side.add_child(_heading_label)
	side.add_child(OrnateRule.new(200.0))
	_nav = VBoxContainer.new()
	_nav.add_theme_constant_override("separation", 2)
	side.add_child(_nav)
	var rule := ColorRect.new()
	rule.color = Color(UITheme.BRONZE, 0.6)
	rule.custom_minimum_size = Vector2(2, 0)
	row.add_child(rule)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 8)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_page)
