extends Control
## The in-run HUD, souls-like and minimal, kept to the corners so the
## middle of the screen stays clear:
## - top-left: level, a framed HP bar with its numbers, a thin XP bar, and a
##   status line (buffs, devoured essences)
## - top-right: the day, and when the goddess comes next
## - bottom-left: Goddess's Tears (the flask) and its key
## - bottom-right: gold, and what the next revive costs
## - right edge: the style rank (D to SSS), its name and a gauge
## - bottom-center: the Demon King's name and a long health bar
## Everything updates from signals (player, run and boss), never by reading
## game state every frame.

const MARGIN := 22
const HP_WIDTH := 300
const COIN := preload("res://assets/ninja/images/gold.png")
const FLASK := preload("res://assets/ninja/images/common_potion.png")

var _level: Label
var _hp_bar: ProgressBar
var _hp_text: Label
var _xp_bar: ProgressBar
var _status: Label
var _day: Label
var _next_shrine: Label
var _gold: Label
var _revive: Label
var _flask: Label
var _boss_box: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _player: Player
var _style_box: VBoxContainer
var _style_letter: Label
var _style_name: Label
var _style_bar: ProgressBar


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


## Connects to the player and the run; call once both exist.
func bind(player: Player, run: Node) -> void:
	_player = player
	player.hp_changed.connect(_on_hp_changed)
	player.stats_changed.connect(func() -> void: _on_hp_changed(player.hp, player.stat("max_hp")))
	player.xp_changed.connect(_on_xp_changed)
	player.flask_changed.connect(_on_flask_changed)
	run.gold_changed.connect(_on_gold_changed)
	run.day_changed.connect(_on_day_changed)
	player.announce()


## Shows the style rank; hidden while there's no style at all.
func bind_style(style: StyleMeter) -> void:
	style.changed.connect(_on_style_changed)
	style.rank_changed.connect(_on_rank_changed)


func _on_style_changed(rank: int, progress: float) -> void:
	_style_box.visible = rank > 0 or progress > 0.0
	_style_bar.value = progress
	_style_letter.text = StyleMeter.LETTERS[rank]
	_style_name.text = StyleMeter.NAMES[rank]
	var color: Color = StyleMeter.COLORS[rank]
	_style_letter.add_theme_color_override("font_color", color)
	_style_bar.get_theme_stylebox("fill").bg_color = color


# A rank-up pops the letter; a drop shakes it.
func _on_rank_changed(_rank: int, rising: bool) -> void:
	_style_letter.pivot_offset = _style_letter.size / 2.0
	var tween := create_tween()
	if rising:
		_style_letter.scale = Vector2(1.6, 1.6)
		tween.tween_property(_style_letter, "scale", Vector2.ONE, 0.25) 			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_style_letter.scale = Vector2(0.7, 0.7)
		tween.tween_property(_style_letter, "scale", Vector2.ONE, 0.2)


func set_status(text: String) -> void:
	if _status.text != text:
		_status.text = text


func show_boss(boss: Enemy, title: String) -> void:
	_boss_name.text = title
	_boss_bar.max_value = boss.max_hp
	_boss_bar.value = boss.hp
	boss.damaged.connect(_on_boss_damaged)
	_boss_box.show()


func _on_boss_damaged(hp: float, _max_hp: float) -> void:
	_boss_bar.value = hp
	_boss_box.visible = hp > 0.0  # felled: make room for the victory panel


func _on_hp_changed(hp: float, max_hp: float) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_text.text = "%d / %d" % [ceili(hp), roundi(max_hp)]


func _on_xp_changed(xp: int, needed: int, level: int) -> void:
	var leveled := _level.text != "Lv %d" % level and _level.text != ""
	_xp_bar.max_value = needed
	_xp_bar.value = xp
	_level.text = "Lv %d" % level
	# Every gem makes the bar breathe; a level-up flares it and pops the level.
	var flare := 2.4 if leveled else 1.5
	_xp_bar.modulate = Color(flare, flare, flare * 0.8)
	create_tween().tween_property(_xp_bar, "modulate", Color.WHITE, 0.35 if leveled else 0.15)
	if leveled:
		_level.pivot_offset = _level.size / 2.0
		_level.scale = Vector2(1.6, 1.6)
		create_tween().tween_property(_level, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_flask_changed(charges: int, max_charges: int) -> void:
	_flask.text = "%d / %d" % [charges, max_charges]
	_flask.add_theme_color_override("font_color", UITheme.BONE if charges > 0 else UITheme.ASH)


func _on_gold_changed(gold: int, revive_cost: int) -> void:
	_gold.text = str(gold)
	_revive.text = "Revive  %d" % revive_cost
	_revive.add_theme_color_override("font_color", UITheme.ASH if gold >= revive_cost else UITheme.BLOOD.lightened(0.3))


func _on_day_changed(day: int, final_day: int, next_shrine: int) -> void:
	_day.text = "Day %d" % day
	if next_shrine > 0:
		_next_shrine.text = "of %d   ·   the goddess on Day %d" % [final_day, next_shrine]
	else:
		_next_shrine.text = "of %d" % final_day


func _build() -> void:
	# Top-left: level, HP, XP, status.
	var top_left := _corner(Control.PRESET_TOP_LEFT)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	top_left.add_child(stack)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 10)
	stack.add_child(hp_row)
	_level = _label("Lv 1", 20, UITheme.GOLD)
	_level.custom_minimum_size = Vector2(44, 0)
	hp_row.add_child(_level)
	_hp_bar = _bar(Vector2(HP_WIDTH, 16), UITheme.BLOOD)
	hp_row.add_child(_hp_bar)
	_hp_text = _label("", 20, UITheme.BONE)
	hp_row.add_child(_hp_text)
	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 10)
	stack.add_child(xp_row)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(44, 0)
	xp_row.add_child(spacer)
	_xp_bar = _bar(Vector2(HP_WIDTH, 6), Color(0.75, 0.68, 0.45))
	xp_row.add_child(_xp_bar)
	_status = _label("", 20, UITheme.ASH)
	stack.add_child(_status)

	# Top-right: the day.
	var top_right := _corner(Control.PRESET_TOP_RIGHT)
	var day_box := VBoxContainer.new()
	day_box.alignment = BoxContainer.ALIGNMENT_END
	top_right.add_child(day_box)
	_day = UITheme.title_label("Day 1", 48, UITheme.BONE)
	_day.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	day_box.add_child(_day)
	_next_shrine = _label("", 20, UITheme.ASH)
	_next_shrine.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	day_box.add_child(_next_shrine)

	# Right edge, under the day: the style rank.
	_style_box = VBoxContainer.new()
	_style_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_style_box.add_theme_constant_override("separation", 0)
	_style_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_style_box)
	_style_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_style_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_style_box.offset_right = -MARGIN
	_style_box.offset_top = -150
	_style_letter = UITheme.title_label("D", 96, UITheme.BONE)
	_style_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_box.add_child(_style_letter)
	_style_name = _label("", 20, UITheme.BONE)
	_style_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_box.add_child(_style_name)
	_style_bar = _bar(Vector2(150, 6), UITheme.GOLD)
	_style_bar.max_value = 1.0
	_style_bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	_style_box.add_child(_style_bar)
	_style_box.hide()

	# Bottom-left: the flask.
	var bottom_left := _corner(Control.PRESET_BOTTOM_LEFT)
	var flask_row := HBoxContainer.new()
	flask_row.add_theme_constant_override("separation", 8)
	bottom_left.add_child(flask_row)
	flask_row.add_child(_icon(FLASK, 3.5))
	var flask_text := VBoxContainer.new()
	flask_row.add_child(flask_text)
	_flask = _label("", 30, UITheme.BONE)
	flask_text.add_child(_flask)
	flask_text.add_child(_label("Goddess's Tears  [Q]", 20, UITheme.ASH))

	# Bottom-right: gold and the next revive.
	var bottom_right := _corner(Control.PRESET_BOTTOM_RIGHT)
	var gold_box := VBoxContainer.new()
	bottom_right.add_child(gold_box)
	var gold_row := HBoxContainer.new()
	gold_row.alignment = BoxContainer.ALIGNMENT_END
	gold_row.add_theme_constant_override("separation", 8)
	gold_box.add_child(gold_row)
	gold_row.add_child(_icon(COIN, 3.0))
	_gold = _label("0", 30, UITheme.GOLD)
	gold_row.add_child(_gold)
	_revive = _label("", 20, UITheme.ASH)
	_revive.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_box.add_child(_revive)

	# Bottom-center: the boss.
	_boss_box = VBoxContainer.new()
	_boss_box.add_theme_constant_override("separation", 2)
	add_child(_boss_box)
	_boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_boss_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_boss_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_boss_box.offset_bottom = -MARGIN - 8
	_boss_name = UITheme.title_label("", 36, UITheme.BONE)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_boss_box.add_child(_boss_name)
	_boss_bar = _bar(Vector2(640, 10), Color(0.7, 0.1, 0.12))
	_boss_box.add_child(_boss_bar)
	_boss_box.hide()


# A margin container pinned to one corner of the screen, growing inward.
func _corner(preset: Control.LayoutPreset) -> MarginContainer:
	var corner := MarginContainer.new()
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		corner.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(corner)
	corner.set_anchors_and_offsets_preset(preset)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN if preset in [Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT] else Control.GROW_DIRECTION_END
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN if preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT] else Control.GROW_DIRECTION_END
	return corner


func _bar(size: Vector2, fill: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = size
	bar.show_percentage = false
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("fill", UITheme.frame(fill, Color(0, 0, 0, 0), 0))
	var back := UITheme.frame(Color(0.04, 0.03, 0.05, 0.85), UITheme.BRONZE.darkened(0.2), 1)
	back.set_content_margin_all(0)
	bar.add_theme_stylebox_override("background", back)
	return bar


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 4)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _icon(texture: Texture2D, size: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = texture.get_size() * size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return icon
