class_name DevourChoice
extends CanvasLayer
## The moment an essence is Devoured, the run pauses on two cards: its
## classic boost, or its alternative mutation (Mutations), each with its max
## HP cost. Below them, the Hunger: where it stands and what the next tier
## will cost you.

signal chosen(alternative: bool)

var _cards: HBoxContainer
var _title: Label
var _hunger: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.0, 0.04, 0.75)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	center.add_child(column)
	_title = UITheme.title_label("", 56, UITheme.FINAL)
	column.add_child(_title)
	column.add_child(OrnateRule.new(420.0, UITheme.FINAL))
	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 22)
	column.add_child(_cards)
	_hunger = Label.new()
	_hunger.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hunger.add_theme_font_size_override("font_size", 22)
	column.add_child(_hunger)
	hide()


func open(essence: EssenceData, player: Player) -> void:
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	var mutation := Mutations.of(essence)
	_title.text = tr("Devour: %s") % tr(essence.display_name)
	var classic := ChoiceCard.new(essence_icon(essence), tr(essence.display_name).trim_suffix(tr(" Essence")),
		tr("CLASSIC"), tr(essence.description), tr("Costs %d max HP") % essence.max_hp_cost, essence.color, "1")
	var alternative := ChoiceCard.new(essence_icon(essence), tr(mutation[0]), tr("MUTATION"),
		tr(mutation[1]), tr("Costs %d max HP") % mutation[3], essence.color.lerp(UITheme.FINAL, 0.5), "2")
	for i in 2:
		var card: ChoiceCard = [classic, alternative][i]
		card.pressed.connect(pick.bind(i))
		_cards.add_child(card)
		card.deal(0.08 * i)
	var tier := player.hunger_tier()
	var next := Hunger.tier(player.devour_count() + 1)
	_hunger.text = tr("Hunger: %s") % tr(Hunger.NAMES[tier])
	if next > tier:
		_hunger.text += "  →  %s\n%s" % [tr(Hunger.NAMES[next]), tr(Hunger.WARNINGS[next])]
	_hunger.add_theme_color_override("font_color", Hunger.COLORS[next])
	show()
	get_tree().paused = true
	classic.grab_focus()


## 0 takes the classic boost, 1 the mutation (also how the bots choose).
func pick(index: int) -> void:
	Game.sfx("pick", 0.0)
	hide()
	get_tree().paused = false
	chosen.emit(index == 1)


func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	var index: int = (event as InputEventKey).keycode - KEY_1
	if index == 0 or index == 1:
		get_viewport().set_input_as_handled()
		pick(index)


## The essence's glow, as a small texture for its cards.
static func essence_icon(essence: EssenceData) -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, essence.color.lightened(0.3))
	gradient.set_color(1, Color(essence.color, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 24
	texture.height = 24
	return texture
