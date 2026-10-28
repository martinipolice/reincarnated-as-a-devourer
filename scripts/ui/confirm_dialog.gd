class_name ConfirmDialog
extends CanvasLayer
## "Are you sure?" for choices that can't be undone (abandoning a journey,
## quitting a run). The safe answer has focus, and Esc means no.
## Usage: if await ConfirmDialog.ask(self, "Abandon it?", "Abandon"): ...

signal answered(yes: bool)


static func ask(parent: Node, message: String, yes_text := "Yes", no_text := "No") -> bool:
	var dialog := ConfirmDialog.new()
	parent.add_child(dialog)
	dialog._build(message, yes_text, no_text)
	var yes: bool = await dialog.answered
	dialog.queue_free()
	return yes


func _build(message: String, yes_text: String, no_text: String) -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", OrnateBox.new(UITheme.INK, UITheme.BRONZE, 26.0))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(420, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 24)
	column.add_child(label)
	column.add_child(OrnateRule.new(260.0))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	var yes := UITheme.menu_item(yes_text, func() -> void: answered.emit(true))
	var no := UITheme.menu_item(no_text, func() -> void: answered.emit(false), "back")
	for button: Button in [yes, no]:
		button.custom_minimum_size = Vector2(180, 44)
		row.add_child(button)
	no.grab_focus.call_deferred()
	Game.sfx("open_menu", 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		Game.sfx("back", 0.0)
		answered.emit(false)
