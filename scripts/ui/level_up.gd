extends CanvasLayer
## Pauses the run and offers up to three upgrades. Pick with a click, the
## number keys 1-3, or arrow keys + Enter.

signal chosen(upgrade: Resource)

var _offers: Array = []

@onready var title: Label = %Title
@onready var options: VBoxContainer = %Options


func _ready() -> void:
	title.add_theme_font_override("font", UITheme.title_font())
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", UITheme.GOLD)


func open(offers: Array, player: Player) -> void:
	_offers = offers
	for child in options.get_children():
		options.remove_child(child)
		child.queue_free()
	for i in offers.size():
		var button := Button.new()
		button.text = "%d.  %s" % [i + 1, _describe(offers[i], player)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(560, 76)
		button.icon = offers[i].icon
		button.expand_icon = true  # the 24 px icons, scaled up to 48 px
		button.add_theme_constant_override("icon_max_width", 48)
		button.add_theme_constant_override("h_separation", 14)
		button.pressed.connect(_pick.bind(i))
		options.add_child(button)
	title.text = "Level %d" % player.level
	Game.sfx("level_up", 0.0)
	show()
	get_tree().paused = true
	(options.get_child(0) as Button).grab_focus()
	Hints.show_hint("level_up", "Pick one with {pick}. {pause} shows your current build.")


func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	var index: int = (event as InputEventKey).keycode - KEY_1
	if index >= 0 and index < _offers.size():
		get_viewport().set_input_as_handled()
		_pick(index)


func _pick(index: int) -> void:
	Game.sfx("pick", 0.0)
	hide()
	get_tree().paused = false
	chosen.emit(_offers[index])


func _describe(upgrade: Resource, player: Player) -> String:
	var next_level := player.upgrade_level(upgrade) + 1
	var name: String = upgrade.display_name
	var tiers: PackedStringArray = upgrade.tier_names
	if next_level <= tiers.size():
		name = "%s: %s" % [name, tiers[next_level - 1]]
	var tag := "NEW" if next_level == 1 else "Lv %d" % next_level
	if upgrade.max_level > 100:
		tag = ""
	var details: String = upgrade.description
	var per_level: PackedStringArray = upgrade.level_descriptions
	if next_level <= per_level.size() and per_level[next_level - 1] != "":
		details = per_level[next_level - 1]
	return "%s   %s\n      %s" % [name, tag, details]
