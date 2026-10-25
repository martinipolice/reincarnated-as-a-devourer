extends CanvasLayer
## Beginner hints, available everywhere as `Hints`. Each hint shows once,
## ever (remembered in Settings), the first time its situation comes up,
## in a small framed box above the bottom of the screen. Several in a row
## queue up. They can be turned off, or reset, in Settings.

const SHOW_TIME := 5.5
const FADE := 0.35

var _queue: Array[String] = []
var _box: PanelContainer
var _label: Label
var _busy := false
var _tween: Tween


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS  # also over the shrine and level-up
	_box = PanelContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_stylebox_override("panel", UITheme.frame(Color(UITheme.INK, 0.92), UITheme.GOLD.darkened(0.25), 2))
	add_child(_box)
	_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_box.offset_bottom = -96
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_box.add_child(row)
	var mark := UITheme.title_label("?", 36, UITheme.GOLD)
	row.add_child(mark)
	_label = Label.new()
	_label.custom_minimum_size = Vector2(520, 0)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_label)
	_box.modulate.a = 0.0
	_box.hide()


## Shows `text` unless hint `id` was shown before or hints are off.
func show_hint(id: String, text: String) -> void:
	var seen: Array = Settings.data.seen_hints
	if not Settings.data.hints or id in seen:
		return
	seen.append(id)
	Settings.save()
	_queue.append(text)  # "{action}" prompts are filled in when shown
	if not _busy:
		_next()


## Drops queued hints and hides the one showing (e.g. when leaving a run).
func clear() -> void:
	_queue.clear()
	if _tween:
		_tween.kill()
	_busy = false
	_box.hide()
	_box.modulate.a = 0.0


func _next() -> void:
	if _queue.is_empty():
		_busy = false
		_box.hide()
		return
	_busy = true
	_label.text = Game.prompts(_queue.pop_front())
	_box.reset_size()
	_box.show()
	_tween = create_tween()
	_tween.tween_property(_box, "modulate:a", 1.0, FADE)
	_tween.tween_interval(SHOW_TIME)
	_tween.tween_property(_box, "modulate:a", 0.0, FADE)
	_tween.tween_callback(_next)
