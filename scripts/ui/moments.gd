extends CanvasLayer
## The big, souls-like moments, in the gothic title font over everything:
## - area title cards ("The Whispering Forest") when you enter a place
## - "YOU DIED", slowly, in blood red, before the goddess offers a revive
## - "DEMON KING FELLED" in gold on victory
## Each runs in real time, so it plays while the game is paused too.

const CARD_FADE := 1.0
const CARD_HOLD := 2.2
const DEATH_FADE := 1.6

var _card: Control
var _card_title: Label
var _card_tween: Tween
var _veil: ColorRect
var _big: Label


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Area card: the name between two thin rules, near the top.
	_card = VBoxContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.offset_top = 120
	_card.add_child(_rule())
	_card_title = UITheme.title_label("", 60, UITheme.BONE)
	_card.add_child(_card_title)
	_card.add_child(_rule())
	_card.modulate.a = 0.0
	# Death and victory: a dark band across the middle, a huge word on it.
	_veil = ColorRect.new()
	_veil.color = Color(0, 0, 0, 0.75)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_HCENTER_WIDE)
	_veil.offset_top = -200  # above the end panel
	_veil.offset_bottom = -40
	_big = UITheme.title_label("", 96, UITheme.BLOOD)
	_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_veil.add_child(_big)
	_big.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.modulate.a = 0.0
	_veil.hide()


func _process(_delta: float) -> void:
	# Menus (level-up, shrine) pause the run: don't let the card sit on top.
	_card.visible = not get_tree().paused


## A place's name fades in under the HUD, holds, and fades away.
func area_card(title: String) -> void:
	_card_title.text = title
	if _card_tween:
		_card_tween.kill()
	_card_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)  # resumes after
	_card_tween.tween_property(_card, "modulate:a", 1.0, CARD_FADE)
	_card_tween.tween_interval(CARD_HOLD)
	_card_tween.tween_property(_card, "modulate:a", 0.0, CARD_FADE)


## "YOU DIED", slowly. Awaitable: returns once it has fully faded in.
func you_died() -> void:
	await _big_word("You Died", UITheme.BLOOD)


func felled(text: String) -> void:
	await _big_word(text, UITheme.GOLD)


func clear() -> void:
	_veil.hide()
	_veil.modulate.a = 0.0


func _big_word(text: String, color: Color) -> void:
	_big.text = text
	_big.add_theme_color_override("font_color", color)
	_veil.show()
	_veil.modulate.a = 0.0
	_big.scale = Vector2.ONE
	var tween := create_tween().set_parallel()
	tween.tween_property(_veil, "modulate:a", 1.0, DEATH_FADE).set_ease(Tween.EASE_IN)
	await tween.finished


func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = Color(UITheme.BRONZE, 0.8)
	rule.custom_minimum_size = Vector2(520, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return rule
