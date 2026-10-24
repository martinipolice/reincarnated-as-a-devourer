extends CanvasLayer
## The goddess's shrine, on the lore days of the original game (5, 10, 15 and
## her farewell on 19). The run pauses; she speaks her story beat, grants a
## free blessing (pick one of three upgrades), and her shrine sells training
## (the old Train menu) and upgrades to her Tears for this journey's gold.
## Gold is also what buys revives, so every purchase is a gamble. She also
## offers two covenants (main.gd COVENANTS): seal one, if you dare, and its
## curse and reward last until the next shrine.

signal closed

const TRAININGS := [
	preload("res://data/training/stamina.tres"),
	preload("res://data/training/strength.tres"),
	preload("res://data/training/resilience.tres"),
	preload("res://data/training/dexterity.tres"),
	preload("res://data/training/guts.tres"),
]
## Goddess's Tears upgrades: [id, name, description, base price, max rank].
## Prices double with each rank.
const TEARS := [
	["vessel", "Tear Vessel", "+1 flask charge", 300, 3],
	["blessed", "Blessed Tears", "Each sip heals 10% more", 250, 3],
]
const TEARS_ICON := preload("res://assets/ninja/images/common_potion.png")
const COVENANT_ICON := preload("res://assets/ninja/images/icon_covenant.png")
const COVENANT_COLOR := Color(0.75, 0.55, 1.0)
const COVENANTS_OFFERED := 2
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
var _covenant_box: HBoxContainer
var _offered: Array = []
var _sealed := false
var _blessings_left := 1
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
	_blessings_left = 1
	_sealed = false
	_main.set_covenant("")  # the last covenant ends here
	_offered = _main.COVENANTS.keys()
	_offered.shuffle()
	_offered.resize(COVENANTS_OFFERED)
	_main.player.refill_flask()  # the goddess refills her tears
	Game.sfx("shrine", 0.0)
	Music.set_intensity(1.0)
	Music.play("shrine", 1.5)
	Hints.show_hint("shrine", "Her blessing is free: pick one first. Then spend gold on training, which lasts all journey. Keep enough gold for a revive.")
	_story.text = "\n".join(STORY.get(day, []))
	_title.text = "The Goddess  ·  Day %d" % day if day != 19 else "The Goddess's Farewell  ·  Day 19"
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
	_revive_label.text = "Next revive: %d gold" % _main.revive_cost()
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
	for upgrade: Array in TEARS:
		var rank := _tears_rank(upgrade[0])
		var buy := Button.new()
		buy.icon = TEARS_ICON
		buy.expand_icon = true
		buy.add_theme_constant_override("icon_max_width", 26)
		buy.custom_minimum_size = Vector2(290, 46)
		if rank >= upgrade[4]:
			buy.text = "%s  ·  mastered" % upgrade[1]
			buy.disabled = true
		else:
			var cost: int = upgrade[3] << rank
			buy.text = "%s  %dg\n%s" % [upgrade[1], cost, upgrade[2]]
			buy.disabled = _main.gold < cost
			buy.pressed.connect(_buy_tears.bind(upgrade))
		_potion_box.add_child(buy)
	for child in _covenant_box.get_children():
		_covenant_box.remove_child(child)
		child.queue_free()
	for id: String in _offered:
		var entry: Array = _main.COVENANTS[id]
		var seal := Button.new()
		seal.icon = COVENANT_ICON
		seal.expand_icon = true
		seal.add_theme_constant_override("icon_max_width", 26)
		seal.custom_minimum_size = Vector2(290, 46)
		seal.add_theme_color_override("font_color", COVENANT_COLOR)
		var sealed_this: bool = _main.covenant == id
		seal.text = "%s%s\n%s  ·  %s" % [entry[0], "  (sealed)" if sealed_this else "", entry[1], entry[2]]
		seal.disabled = _sealed
		seal.pressed.connect(_seal.bind(id))
		_covenant_box.add_child(seal)
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
	_blessings_left -= 1
	_blessed = _blessings_left <= 0
	_main.player.apply_upgrade(upgrade)
	Game.sfx("pick", 0.0)
	if not _blessed:
		_build_blessings()  # Thirst: pick again from a fresh three
	_refresh()
	if _blessed:
		_continue.grab_focus()


# A covenant is for good: once sealed, it can't be undone at this shrine.
func _seal(id: String) -> void:
	if _sealed:
		return
	_sealed = true
	_main.set_covenant(id)
	Game.sfx("covenant", 0.0)
	Game.shake(0.2)
	if id == "thirst":
		_blessings_left += 1  # its reward: a second blessing
		if _blessed:
			_blessed = false
			_build_blessings()
	_refresh()


func _buy_training(training: TrainingData) -> void:
	var rank: int = _main.training_ranks.get(training.id, 0)
	if _main.gold < training.cost(rank) or rank >= training.max_rank:
		Game.sfx("denied", 0.0)
		return
	_main.gold -= training.cost(rank)
	_main.add_training(training)
	Game.sfx("coins", 0.0)
	_refresh()


func _tears_rank(id: String) -> int:
	var player: Player = _main.player
	if id == "vessel":
		return player.flask_max - Player.FLASK_START_CHARGES
	return roundi((player.flask_heal - Player.FLASK_START_HEAL) / 0.1)


func _buy_tears(upgrade: Array) -> void:
	var player: Player = _main.player
	var cost: int = upgrade[3] << _tears_rank(upgrade[0])
	if _main.gold < cost:
		Game.sfx("denied", 0.0)
		return
	_main.gold -= cost
	if upgrade[0] == "vessel":
		player.flask_max += 1
	else:
		player.flask_heal += 0.1
	player.refill_flask()
	Game.sfx("loot", 0.0)
	_refresh()


# The whole screen is built in code: a dimmed backdrop, the goddess on the
# left, and her words, blessing and shop on the right.
func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.03, 0.93)
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
	margin.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	margin.offset_right = 1280  # keep the 720p layout on wider screens
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)

	_title = UITheme.title_label("", 48, UITheme.GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_title)
	_story = _label("", 20, Color(0.85, 0.82, 0.95))
	_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_story)
	var money := HBoxContainer.new()
	money.add_theme_constant_override("separation", 24)
	column.add_child(money)
	_gold_label = _label("", 30, Color(1, 0.85, 0.35))
	money.add_child(_gold_label)
	_revive_label = _label("", 20, Color(0.75, 0.7, 0.8))
	money.add_child(_revive_label)

	_blessing_title = _label("", 20, Color.WHITE)
	column.add_child(_blessing_title)
	_blessing_box = HBoxContainer.new()
	_blessing_box.add_theme_constant_override("separation", 10)
	column.add_child(_blessing_box)

	column.add_child(_label("Training (lasts the whole journey)", 20, Color.WHITE))
	_training_box = VBoxContainer.new()
	column.add_child(_training_box)

	column.add_child(_label("Goddess's Tears (refilled at every shrine)", 20, Color.WHITE))
	_potion_box = HBoxContainer.new()
	_potion_box.add_theme_constant_override("separation", 10)
	column.add_child(_potion_box)

	column.add_child(_label("A covenant until her next shrine (optional, and final)", 20, COVENANT_COLOR))
	_covenant_box = HBoxContainer.new()
	_covenant_box.add_theme_constant_override("separation", 10)
	column.add_child(_covenant_box)
	_continue = Button.new()
	_continue.custom_minimum_size = Vector2(0, 44)
	_continue.add_theme_font_size_override("font_size", 20)
	_continue.pressed.connect(_close)
	column.add_child(_continue)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
