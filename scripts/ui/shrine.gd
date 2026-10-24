extends CanvasLayer
## The goddess's shrine, on the lore days of the original game (5, 10, 15 and
## her farewell on 19). The run pauses; she speaks her story beat, grants a
## free blessing (pick one of three upgrades), and her shrine sells training
## (the old Train menu) and potions (the old shop's) for this journey's gold.
## Gold is also what buys revives, so every purchase is a gamble.

signal closed

const TRAININGS := [
	preload("res://data/training/stamina.tres"),
	preload("res://data/training/strength.tres"),
	preload("res://data/training/resilience.tres"),
	preload("res://data/training/dexterity.tres"),
	preload("res://data/training/guts.tres"),
]
## [name, fraction of max HP restored, price, icon]
const POTIONS := [
	["Common Potion", 0.3, 60, preload("res://assets/ninja/images/common_potion.png")],
	["High Potion", 0.6, 110, preload("res://assets/ninja/images/high_potion.png")],
	["Flask of Rejuvenation", 1.0, 180, preload("res://assets/ninja/images/rejuvenation.png")],
]
## The goddess's words on each shrine day, from the terminal game's lore.
const STORY := {
	5: ["You dream of the goddess watching from afar.",
		"Goddess: \"Do not fear this world. This is just the beginning.\""],
	10: ["A vision fills your mind. You see the goddess beside a shadow under a red sky.",
		"Her voice trembles: \"Forgive me.\""],
	15: ["Carvings in the ruins show a goddess and a dark figure side by side.",
		"Ghostly voice: \"They once loved each other. Love turned to ruin.\"",
		"Goddess: \"Do not question fate. Finish what was started.\""],
	19: ["The goddess appears, fading fast.",
		"Goddess: \"He waits for me still... End his suffering, please.\""],
}
const GODDESS_FRAMES := preload("res://assets/ninja/goddess/sprite_frames.tres")

var _main: Node
var _day := 0
var _blessed := false
var _title: Label
var _story: Label
var _gold_label: Label
var _blessing_box: HBoxContainer
var _blessing_title: Label
var _training_box: VBoxContainer
var _potion_box: HBoxContainer
var _revive_label: Label
var _continue: Button


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


## Pauses the run and opens the shrine for `day`. `main` is the run scene.
func open(day: int, main: Node) -> void:
	_main = main
	_day = day
	_blessed = false
	_story.text = "\n".join(STORY.get(day, []))
	_title.text ="THE GODDESS  ·  DAY %d" % day if day != 19 else "THE GODDESS'S FAREWELL  ·  DAY 19"
	_build_blessings()
	_refresh()
	visible = true
	get_tree().paused = true
	Game.sfx("level_up", 0.0)


func _close() -> void:
	if not _blessed:
		return
	Game.sfx("click", 0.0)
	visible = false
	get_tree().paused = false
	closed.emit()


func _refresh() -> void:
	var player: Player = _main.player
	_gold_label.text = "Gold: %d" % _main.gold
	_revive_label.text = "Your next revive costs %d gold." % _main.revive_cost()
	_blessing_title.text = "Her blessing: choose one" if not _blessed else "Her blessing is with you."
	for child in _blessing_box.get_children():
		(child as Button).disabled = _blessed
	for child in _training_box.get_children():
		_training_box.remove_child(child)
		child.queue_free()
	for training: TrainingData in TRAININGS:
		_training_box.add_child(_training_row(training))
	for child in _potion_box.get_children():
		_potion_box.remove_child(child)
		child.queue_free()
	for potion: Array in POTIONS:
		var buy := Button.new()
		buy.text = "%s\n%dg" % [potion[0], potion[2]]
		buy.icon = potion[3]
		buy.expand_icon = true
		buy.add_theme_constant_override("icon_max_width", 28)
		buy.custom_minimum_size = Vector2(190, 56)
		buy.disabled = _main.gold < potion[2] or player.hp >= player.stat("max_hp")
		buy.pressed.connect(_buy_potion.bind(potion))
		_potion_box.add_child(buy)
	_continue.disabled = not _blessed
	_continue.text = "Continue your journey" if _blessed else "Choose her blessing first"


func _training_row(training: TrainingData) -> Control:
	var rank: int = _main.training_ranks.get(training.id, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var info := Label.new()
	info.text = "%s  ·  %s" % [training.display_name, training.description]
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var pips := Label.new()
	pips.text = "■".repeat(rank) + "□".repeat(training.max_rank - rank)
	pips.custom_minimum_size = Vector2(80, 0)
	row.add_child(pips)
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(130, 34)
	if rank >= training.max_rank:
		buy.text = "Mastered"
		buy.disabled = true
	else:
		var cost := training.cost(rank)
		buy.text = "Train  %dg" % cost
		buy.disabled = _main.gold < cost
		buy.pressed.connect(_buy_training.bind(training))
	row.add_child(buy)
	return row


func _build_blessings() -> void:
	for child in _blessing_box.get_children():
		_blessing_box.remove_child(child)
		child.queue_free()
	var player: Player = _main.player
	var offers: Array = player.available_upgrades(_main.UPGRADE_POOL)
	offers.shuffle()
	offers.resize(mini(3, offers.size()))
	if offers.is_empty():
		offers = [_main.FALLBACK_UPGRADE]
	for upgrade: Resource in offers:
		var level := player.upgrade_level(upgrade) + 1
		var button := Button.new()
		var tag := "NEW" if level == 1 else "Lv %d" % level
		button.text = "%s  %s" % [upgrade.display_name, tag if upgrade.max_level < 100 else ""]
		button.tooltip_text = upgrade.description
		button.icon = upgrade.icon
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 36)
		button.custom_minimum_size = Vector2(190, 56)
		button.pressed.connect(_bless.bind(upgrade))
		_blessing_box.add_child(button)


func _bless(upgrade: Resource) -> void:
	_blessed = true
	_main.player.apply_upgrade(upgrade)
	Game.sfx("pick", 0.0)
	_refresh()
	_continue.grab_focus()


func _buy_training(training: TrainingData) -> void:
	var rank: int = _main.training_ranks.get(training.id, 0)
	if _main.gold < training.cost(rank) or rank >= training.max_rank:
		Game.sfx("denied", 0.0)
		return
	_main.gold -= training.cost(rank)
	_main.add_training(training)
	Game.sfx("coins", 0.0)
	_refresh()


func _buy_potion(potion: Array) -> void:
	var player: Player = _main.player
	if _main.gold < potion[2]:
		Game.sfx("denied", 0.0)
		return
	_main.gold -= potion[2]
	player.hp = minf(player.stat("max_hp"), player.hp + player.stat("max_hp") * potion[1])
	Game.sfx("loot", 0.0)
	_refresh()


# The whole screen is built in code: a dimmed backdrop, the goddess on the
# left, and her words, blessing and shop on the right.
func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.09, 0.88)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var goddess := AnimatedSprite2D.new()
	goddess.sprite_frames = GODDESS_FRAMES
	goddess.position = Vector2(170, 330)
	goddess.scale = Vector2(9, 9)
	goddess.play("run_down")
	add_child(goddess)
	var glow := Game.make_glow(Color(1, 0.9, 0.6, 0.6), 150.0)
	glow.position = Vector2(170, 330)
	add_child(glow)
	move_child(glow, 1)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 330)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	_title = _label("", 30, Color(1, 0.9, 0.65))
	column.add_child(_title)
	_story = _label("", 18, Color(0.85, 0.82, 0.95))
	_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_story)
	_gold_label = _label("", 22, Color(1, 0.85, 0.35))
	column.add_child(_gold_label)

	_blessing_title = _label("", 18, Color.WHITE)
	column.add_child(_blessing_title)
	_blessing_box = HBoxContainer.new()
	_blessing_box.add_theme_constant_override("separation", 10)
	column.add_child(_blessing_box)

	column.add_child(_label("Training (lasts the whole journey)", 18, Color.WHITE))
	_training_box = VBoxContainer.new()
	column.add_child(_training_box)

	column.add_child(_label("Potions", 18, Color.WHITE))
	_potion_box = HBoxContainer.new()
	_potion_box.add_theme_constant_override("separation", 10)
	column.add_child(_potion_box)

	_revive_label = _label("", 15, Color(0.75, 0.7, 0.8))
	column.add_child(_revive_label)
	_continue = Button.new()
	_continue.custom_minimum_size = Vector2(0, 46)
	_continue.add_theme_font_size_override("font_size", 20)
	_continue.pressed.connect(_close)
	column.add_child(_continue)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
