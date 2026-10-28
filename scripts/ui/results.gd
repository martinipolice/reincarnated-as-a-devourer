class_name Results
extends CanvasLayer
## The end of a journey, won or lost: how far you got, what you became, and
## each weapon's share of the damage (Enemy.damage_log), plus any starting
## weapons this journey unlocked. Then a new journey or the title.

signal again
signal to_title

const BOMB_ICON := preload("res://assets/ninja/images/bomb.png")
const BAR_WIDTH := 220.0
const MENU_DELAY := 1.0  # so a held attack key doesn't skip it

var _buttons: Array[Button] = []
var _ready_for_input := false


func _ready() -> void:
	layer = 14
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()


## `main`: the run that ended. `unlocked`: starting weapons it earned.
func open(main: Node, won: bool, title: String, subtitle: String, unlocked: Array) -> void:
	for child in get_children():
		child.queue_free()
	_buttons.clear()
	var player: Player = main.player
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.005, 0.02, 0.96)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	center.add_child(column)

	column.add_child(UITheme.title_label(title, 72, UITheme.GOLD if won else UITheme.BLOOD))
	var sub := Label.new()
	sub.text = subtitle
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	column.add_child(sub)
	column.add_child(OrnateRule.new(520.0, UITheme.GOLD if won else UITheme.BRONZE))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	row.add_child(_panel("The Journey", _journey_stats(main, player), Vector2(360, 300)))
	row.add_child(_panel("Damage Dealt", _damage_bars(player), Vector2(500, 300)))

	for path: String in unlocked:
		var weapon: WeaponData = load(path)
		var line := Label.new()
		line.text = "New starting weapon: %s" % weapon.display_name
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_theme_color_override("font_color", UITheme.GOLD)
		column.add_child(line)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(buttons)
	for entry: Array in [[Game.prompts("New Journey  ({restart})"), again], ["Title Screen", to_title]]:
		var signal_to: Signal = entry[1]
		var button := UITheme.menu_item(entry[0], func() -> void: _choose(signal_to))
		button.custom_minimum_size = Vector2(300, 44)
		button.disabled = true
		buttons.add_child(button)
		_buttons.append(button)

	show()
	column.modulate.a = 0.0
	create_tween().tween_property(column, "modulate:a", 1.0, 0.6)
	_ready_for_input = false
	await get_tree().create_timer(MENU_DELAY, true, false, true).timeout
	_ready_for_input = true
	for button in _buttons:
		button.disabled = false
	_buttons[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and _ready_for_input and event.is_action_pressed("restart"):
		get_viewport().set_input_as_handled()
		Game.sfx("pick", 0.0)
		_choose(again)


func _choose(which: Signal) -> void:
	if not _ready_for_input:
		return
	_ready_for_input = false
	which.emit()


func _journey_stats(main: Node, player: Player) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 2)
	var rank: int = main.best_rank
	var rows := [
		["Day reached", "%d of 20" % main.day()],
		["Level", str(player.level)],
		["Kills", str(main.kills)],
		["Essences devoured", str(player.devour_count())],
		["Resonances", str(player.resonances.size())],
		["Gold left", str(main.gold)],
		["Revives", str(main.revives)],
		["Best style", "%s  %s" % [StyleMeter.LETTERS[rank], StyleMeter.NAMES[rank]]],
	]
	for entry: Array in rows:
		var key := Label.new()
		key.text = entry[0]
		key.add_theme_color_override("font_color", UITheme.ASH)
		grid.add_child(key)
		var value := Label.new()
		value.text = entry[1]
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if entry[0] == "Best style":
			value.add_theme_color_override("font_color", StyleMeter.COLORS[rank])
		grid.add_child(value)
	return grid


# One row per damage source, biggest first: icon, name, a bar, the number.
func _damage_bars(player: Player) -> Control:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	var log: Dictionary = Enemy.damage_log
	var total := 0.0
	for source: String in log:
		total += float(log[source])
	if total <= 0.0:
		var none := Label.new()
		none.text = "Nothing fell to your hand."
		none.add_theme_color_override("font_color", UITheme.ASH)
		list.add_child(none)
		return list
	var sources := log.keys()
	sources.sort_custom(func(a: String, b: String) -> bool: return float(log[a]) > float(log[b]))
	var top := float(log[sources[0]])
	for source: String in sources.slice(0, 7):
		var amount := float(log[source])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var name_text := source
		for upgrade: Resource in player.upgrade_levels:
			if upgrade.display_name == source:
				icon.texture = upgrade.icon
				name_text = _weapon_name(player, upgrade)
		if source == "Bomb":
			icon.texture = BOMB_ICON
		row.add_child(icon)
		var label := Label.new()
		label.text = name_text
		label.custom_minimum_size = Vector2(150, 0)
		label.clip_text = true
		row.add_child(label)
		var bar := ColorRect.new()
		bar.color = UITheme.GOLD.darkened(0.25) if source == sources[0] else UITheme.BRONZE
		bar.custom_minimum_size = Vector2(maxf(2.0, BAR_WIDTH * amount / top), 10)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var lane := Control.new()
		lane.custom_minimum_size = Vector2(BAR_WIDTH, 24)
		lane.add_child(bar)
		bar.position = Vector2(0, 7)
		row.add_child(lane)
		var number := Label.new()
		number.text = "%s  %d%%" % [_short(amount), roundi(100.0 * amount / total)]
		number.add_theme_color_override("font_color", UITheme.ASH)
		row.add_child(number)
		list.add_child(row)
	return list


func _weapon_name(player: Player, upgrade: Resource) -> String:
	if upgrade is WeaponData:
		for weapon: Weapon in player.weapons.get_children():
			if weapon.data == upgrade and weapon.evolved:
				return upgrade.evolved_name
	return upgrade.display_name


func _short(amount: float) -> String:
	if amount >= 1000000.0:
		return "%.1fM" % (amount / 1000000.0)
	if amount >= 1000.0:
		return "%.1fk" % (amount / 1000.0)
	return str(roundi(amount))


func _panel(heading: String, body: Control, min_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	column.add_child(HowToPlay.heading(heading))
	column.add_child(body)
	return panel
