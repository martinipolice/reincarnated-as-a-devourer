extends CanvasLayer
## The chest ceremony. Opening a chest pauses the run; a reel of loot icons
## spins, slows down and slams onto the reward, one reel per reward (golden
## chests have two). Any key or click skips straight to the result. main.gd
## awaits reveal() and only then grants the loot.

const SPIN_TIME := 1.1  # seconds per reel
const START_GAP := 0.04  # seconds between icons at full speed
const END_GAP := 0.22
const HOLD := 0.45  # after the slam, before the next reel or closing

var _band: ColorRect
var _row: HBoxContainer
var _title: Label
var _skip := false


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_band = ColorRect.new()
	_band.color = Color(0.02, 0.015, 0.03, 0.8)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band)
	_band.set_anchors_and_offsets_preset(Control.PRESET_HCENTER_WIDE)
	_band.offset_top = -110
	_band.offset_bottom = 110
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_band.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title = UITheme.title_label("", 36, UITheme.GOLD)
	column.add_child(_title)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 40)
	column.add_child(_row)
	hide()


## Spins one reel per entry in `rewards` (Loot table entries), landing on
## each in turn. Returns once the ceremony is over.
func reveal(rewards: Array, golden: bool) -> void:
	_skip = false
	for child in _row.get_children():
		child.queue_free()
	_title.text = "Golden Chest" if golden else "Treasure"
	_title.add_theme_color_override("font_color", UITheme.GOLD if golden else UITheme.BONE)
	var slots: Array[TextureRect] = []
	var captions: Array[Label] = []
	for i in rewards.size():
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		_row.add_child(cell)
		var slot := TextureRect.new()
		slot.custom_minimum_size = Vector2(72, 72)
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot.pivot_offset = Vector2(36, 36)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(slot)
		slots.append(slot)
		var caption := Label.new()
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.custom_minimum_size = Vector2(200, 0)
		cell.add_child(caption)
		captions.append(caption)
	show()
	var all_icons := Loot.TABLE.map(func(entry: Dictionary) -> Texture2D: return Loot.icon(entry))
	for i in rewards.size():
		await _spin(slots[i], all_icons, Loot.icon(rewards[i]))
		captions[i].text = rewards[i].name
	if not _skip:
		await get_tree().create_timer(HOLD, true, false, true).timeout
	hide()


func _spin(slot: TextureRect, icons: Array, result: Texture2D) -> void:
	var elapsed := 0.0
	var index := randi() % icons.size()
	while elapsed < SPIN_TIME and not _skip:
		var t := elapsed / SPIN_TIME
		var gap := lerpf(START_GAP, END_GAP, t * t)  # slows to a stop
		index = (index + 1) % icons.size()
		slot.texture = icons[index]
		slot.modulate = Color(1, 1, 1, 0.6)
		Game.sfx("tick", 0.0)
		await get_tree().create_timer(gap, true, false, true).timeout
		elapsed += gap
	# The slam: the reward lands big and settles.
	slot.texture = result
	slot.modulate = Color.WHITE
	slot.scale = Vector2(1.6, 1.6)
	create_tween().tween_property(slot, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Game.sfx("loot", 0.0)
	Game.shake(0.15)
	Game.rumble(0.15, 0.3, 0.12)
	if not _skip:
		await get_tree().create_timer(HOLD * 0.6, true, false, true).timeout


func _input(event: InputEvent) -> void:
	if visible and event.is_pressed() and not event.is_echo() \
			and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		_skip = true
		get_viewport().set_input_as_handled()
