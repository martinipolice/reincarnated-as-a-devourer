class_name CardPick
extends CanvasLayer
## A pause and a row of ChoiceCards to pick from, for one-off rewards (the
## cursed altar). Pick with a click, the number keys, or focus + accept.

signal picked(index: int)

var _cards: HBoxContainer
var _title: Label
var _count := 0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.04, 0.75)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	center.add_child(column)
	_title = UITheme.title_label("", 56, UITheme.GOLD)
	column.add_child(_title)
	column.add_child(OrnateRule.new(420.0))
	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 22)
	column.add_child(_cards)
	hide()


func open(title: String, cards: Array[ChoiceCard]) -> void:
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	_title.text = title
	_count = cards.size()
	for i in cards.size():
		cards[i].pressed.connect(pick.bind(i))
		_cards.add_child(cards[i])
		cards[i].deal(0.08 * i)
	show()
	get_tree().paused = true
	cards[0].grab_focus()


func pick(index: int) -> void:
	Game.sfx("pick", 0.0)
	hide()
	get_tree().paused = false
	picked.emit(index)


func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	var index: int = (event as InputEventKey).keycode - KEY_1
	if index >= 0 and index < _count:
		get_viewport().set_input_as_handled()
		pick(index)
