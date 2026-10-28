class_name LevelUp
extends CanvasLayer
## Pauses the run and deals up to three upgrade cards (ChoiceCard). Pick with
## a click, the number keys 1-3, or arrows / d-pad + Enter / A. A card's color
## says what it is: gold a new weapon, blue a new passive, bronze a level,
## violet a weapon's last level (its evolution comes next).

signal chosen(upgrade: Resource)

## The upgrades on the cards now showing.
var offers: Array = []

@onready var title: Label = %Title
@onready var options: HBoxContainer = %Options
@onready var prompt: Label = %Prompt


func _ready() -> void:
	title.add_theme_font_override("font", UITheme.title_font())
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_color", UITheme.GOLD)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 8)
	$Center/VBox.add_child(OrnateRule.new(420.0))
	$Center/VBox.move_child($Center/VBox.get_child(-1), 1)
	prompt.add_theme_color_override("font_color", UITheme.ASH)


func open(choices: Array, player: Player) -> void:
	offers = choices
	for child in options.get_children():
		options.remove_child(child)
		child.queue_free()
	for i in offers.size():
		var card := card_for(offers[i], player, str(i + 1))
		card.pressed.connect(pick.bind(i))
		options.add_child(card)
		card.deal(0.06 * i)
	title.text = tr("Level %d") % player.level
	prompt.text = Game.prompts("Choose one  ·  {pause} shows your build")
	Game.sfx("level_up", 0.0)
	show()
	get_tree().paused = true
	(options.get_child(0) as Button).grab_focus()
	Hints.show_hint("level_up", "Pick one with {pick}. {pause} shows your current build.")


func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	var index: int = (event as InputEventKey).keycode - KEY_1
	if index >= 0 and index < offers.size():
		get_viewport().set_input_as_handled()
		pick(index)


## Takes the card at `index` (also how the test bots choose).
func pick(index: int) -> void:
	Game.sfx("pick", 0.0)
	hide()
	get_tree().paused = false
	chosen.emit(offers[index])


## The card for taking `upgrade` next (also the goddess's blessings).
static func card_for(upgrade: Resource, player: Player, hotkey := "", compact := false) -> ChoiceCard:
	var next_level := player.upgrade_level(upgrade) + 1
	var is_weapon := upgrade is WeaponData
	var subtitle := ""
	var tiers: PackedStringArray = upgrade.tier_names
	if next_level <= tiers.size():
		subtitle = tiers[next_level - 1]
	var accent := UITheme.UPGRADE
	var tag := TranslationServer.translate("LV %d") % next_level
	if upgrade.max_level > 100:  # the endless fallback
		accent = UITheme.BONE
		tag = ""
	elif next_level == 1:
		accent = UITheme.NEW_WEAPON if is_weapon else UITheme.NEW_PASSIVE
		tag = "NEW WEAPON" if is_weapon else "NEW"
	elif next_level == upgrade.max_level:
		tag = "MAX"
		if is_weapon and (upgrade.evolve_with or upgrade.evolve_with_item):
			accent = UITheme.FINAL
	var details: String = upgrade.description
	var per_level: PackedStringArray = upgrade.level_descriptions
	if next_level <= per_level.size() and per_level[next_level - 1] != "":
		details = per_level[next_level - 1]
	return ChoiceCard.new(upgrade.icon, upgrade.display_name, tag, subtitle, details, accent, hotkey, compact)
