class_name Codex
extends CanvasLayer
## The Codex, from the title screen: every monster, weapon, passive, essence
## and Resonance, filled in as you meet or find them (Save.data.codex, written
## by main.gd at each shrine and at a journey's end). Unfound entries show as
## "???". Facts only, no lore: stats, how a monster fights, how a weapon
## evolves, how a starting weapon is earned.

signal closed

const ENEMIES := [
	"res://data/enemies/dreadling.tres", "res://data/enemies/vexclaw.tres",
	"res://data/enemies/plaguewing.tres", "res://data/enemies/mimic.tres",
	"res://data/enemies/hexeye.tres", "res://data/enemies/warden.tres",
	"res://data/enemies/acolyte.tres", "res://data/enemies/burrower.tres",
	"res://data/enemies/ruin_guardian.tres", "res://data/enemies/hollow_spirit.tres",
	"res://data/enemies/demon_king.tres",
]
const WEAPONS := [
	"res://data/weapons/blade.tres", "res://data/weapons/goddess_light.tres",
	"res://data/weapons/aegis.tres", "res://data/weapons/maw.tres",
	"res://data/weapons/chains.tres", "res://data/weapons/doom_bell.tres",
]
const PASSIVES := [
	"res://data/items/stamina.tres", "res://data/items/fury.tres",
	"res://data/items/vigor.tres", "res://data/items/wooden_guard.tres",
	"res://data/items/leather_treads.tres", "res://data/items/magnet_charm.tres",
	"res://data/items/hunger.tres",
]
const ESSENCES := [
	"res://data/essences/dreadling_essence.tres", "res://data/essences/vexclaw_essence.tres",
	"res://data/essences/plaguewing_essence.tres", "res://data/essences/hexeye_essence.tres",
	"res://data/essences/warden_essence.tres", "res://data/essences/acolyte_essence.tres",
	"res://data/essences/burrower_essence.tres",
]
## How each kind of monster fights.
const BEHAVIOR := {
	"chase": "Walks you down.",
	"swarm": "Comes in packs, and fast.",
	"pounce": "Crouches, then leaps at you. Step aside.",
	"spitter": "Keeps its distance and lobs plague where you stand.",
	"caster": "Keeps its distance and fires hexes along a line it shows first.",
	"warden": "Shielded: the shield soaks most of each hit until it breaks.",
	"raiser": "Keeps away and raises the freshly fallen with a beam. Kill it first.",
	"burrower": "Travels underground, cracks the ground under you, then erupts. Hit it while it is up.",
}
const BOSS_NOTES := {
	"Ruin Guardian": "Mini-boss of Day 10. Charges in a straight line after a wind-up, and slams.",
	"Hollow Spirit": "Mini-boss of Day 15. Blinks beside you, slams, and fires volleys.",
	"Demon King": "Day 20. Slams, fires volleys, summons, and grows enraged.",
}
const PAGES := ["Bestiary", "Arsenal", "Essences", "Resonances"]

var _nav: VBoxContainer
var _page: VBoxContainer
var _scroll: ScrollContainer
var _count: Label


func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide()


func open() -> void:
	_count.text = tr("%d of %d found") % _progress()
	show()
	Game.sfx("open_menu", 0.0)
	_show(PAGES[0])
	(_nav.get_child(0) as Button).grab_focus.call_deferred()


func close() -> void:
	hide()
	Game.sfx("close_menu", 0.0)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close()


# A page longer than the screen scrolls with the right stick or Page Up/Down
# (and the mouse wheel), while the menu list keeps focus.
func _process(delta: float) -> void:
	if not visible:
		return
	var push := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(push) < 0.2:
		push = 0.0
	if Input.is_key_pressed(KEY_PAGEDOWN):
		push = 1.0
	elif Input.is_key_pressed(KEY_PAGEUP):
		push = -1.0
	if push != 0.0:
		_scroll.scroll_vertical += roundi(push * 900.0 * delta)


func _codex() -> Dictionary:
	return Save.data.get("codex", {})


func _knows_enemy(path: String) -> bool:
	return int(_codex().get("enemies", {}).get((load(path) as EnemyData).display_name, 0)) > 0


func _knows(key: String, value: String) -> bool:
	return value in _codex().get(key, [])


func _progress() -> Array:
	var found := 0
	var total := 0
	for path: String in ENEMIES:
		total += 1
		found += int(_knows_enemy(path))
	for path: String in WEAPONS + PASSIVES:
		total += 1
		found += int(_knows("upgrades", path))
	for path: String in ESSENCES:
		total += 1
		found += int(_knows("essences", path))
	for entry: Array in Resonances.TABLE:
		total += 1
		found += int(_knows("resonances", entry[0]))
	return [found, total]


func _show(page: String) -> void:
	for child in _page.get_children():
		_page.remove_child(child)
		child.queue_free()
	_scroll.scroll_vertical = 0
	for item: Button in _nav.get_children():
		item.add_theme_color_override("font_color", UITheme.BONE if item.text == page else UITheme.ASH.lightened(0.2))
	match page:
		"Bestiary":
			_bestiary()
		"Arsenal":
			_arsenal()
		"Essences":
			_essences()
		"Resonances":
			_resonances()


func _bestiary() -> void:
	var kills: Dictionary = _codex().get("enemies", {})
	for path: String in ENEMIES:
		var data: EnemyData = load(path)
		if not _knows_enemy(path):
			_entry(_enemy_texture(data), "???", "Not yet met.", true)
			continue
		var facts := tr("HP %d  ·  Attack %d  ·  Defense %d") % [data.max_hp, data.atk, data.defense]
		if data.shield > 0.0:
			facts += tr("  ·  Shield %d") % data.shield
		var how: String = BOSS_NOTES.get(data.display_name, BEHAVIOR.get(data.behavior, ""))
		var drop := (tr("\nElites leave a %s.") % data.essence.display_name) if data.essence else ""
		_entry(_enemy_texture(data), data.display_name, tr("%s\n%s%s\nSlain: %d") % [
			facts, how, drop, int(kills[data.display_name])], false)


func _arsenal() -> void:
	_page.add_child(HowToPlay.heading("Weapons"))
	var unlocked := Unlocks.unlocked(Save.data)
	for i in WEAPONS.size():
		var weapon: WeaponData = load(WEAPONS[i])
		var how: String = Unlocks.STARTERS[i][1]
		var start := "Starting weapon" if WEAPONS[i] in unlocked else tr("Start with it: %s") % how
		if not _knows("upgrades", WEAPONS[i]):
			_entry(weapon.icon, "???", tr("Not yet wielded.  ·  %s") % start, true)
			continue
		var evolve := ""
		if weapon.evolve_with:
			evolve = tr("Evolves into %s: Lv %d and %d %s essences Devoured.") % [
				weapon.evolved_name, weapon.max_level, weapon.evolve_count, weapon.evolve_with.display_name.trim_suffix(" Essence")]
		elif weapon.evolve_with_item:
			evolve = tr("Evolves into %s: Lv %d with %s at its max level.") % [
				weapon.evolved_name, weapon.max_level, weapon.evolve_with_item.display_name]
		_entry(weapon.icon, weapon.display_name, "%s\n%s\n%s" % [weapon.description, evolve, start], false)
	_page.add_child(HowToPlay.heading("Passives"))
	for path: String in PASSIVES:
		var item: ItemData = load(path)
		if _knows("upgrades", path):
			_entry(item.icon, item.display_name, tr("%s  (max Lv %d)") % [item.description, item.max_level], false)
		else:
			_entry(item.icon, "???", "Not yet found.", true)


func _essences() -> void:
	for path: String in ESSENCES:
		var essence: EssenceData = load(path)
		if _knows("essences", path):
			var mutation := Mutations.of(essence)
			_entry(null, essence.display_name, tr("Classic: %s, costs %d max HP.\nMutation, %s: %s, costs %d max HP.") % [
				tr(essence.description), essence.max_hp_cost, tr(mutation[0]), tr(mutation[1]), mutation[3]],
				false, essence.color)
		else:
			_entry(null, "???", "Not yet Devoured.", true, essence.color)


func _resonances() -> void:
	var note := Label.new()
	note.text = tr("Hold %d or more of each of two essences and they resonate.") % Resonances.NEEDED
	note.add_theme_color_override("font_color", UITheme.ASH)
	_page.add_child(note)
	for entry: Array in Resonances.TABLE:
		var a: EssenceData = load(entry[1])
		var b: EssenceData = load(entry[2])
		var pair := "%s + %s" % [a.display_name if _knows("essences", entry[1]) else "???",
			b.display_name if _knows("essences", entry[2]) else "???"]
		if _knows("resonances", entry[0]):
			_entry(null, entry[0], "%s\n%s" % [pair, entry[3]], false, a.color.lerp(b.color, 0.5))
		else:
			_entry(null, "???", pair, true, a.color.lerp(b.color, 0.5))


func _enemy_texture(data: EnemyData) -> Texture2D:
	var frames := data.sprite_frames
	if frames == null:
		return null
	var anim: StringName = &"run_down" if frames.has_animation(&"run_down") else frames.get_animation_names()[0]
	return frames.get_frame_texture(anim, 0)


# One row: a picture (an icon, a sprite, or a swatch of `swatch`), the name,
# and the facts under it. Unknown rows are shadowed.
func _entry(texture: Texture2D, title: String, body: String, unknown: bool, swatch := Color.TRANSPARENT) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(60, 60)
	frame.add_theme_stylebox_override("panel", UITheme.frame(UITheme.INK, UITheme.BRONZE.darkened(0.3), 1))
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(frame)
	if texture:
		var art := TextureRect.new()
		art.texture = texture
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.modulate = Color(0.05, 0.04, 0.07) if unknown else Color.WHITE
		frame.add_child(art)
	elif swatch.a > 0.0:
		var gem := ColorRect.new()
		gem.color = Color(0.1, 0.09, 0.12) if unknown else swatch
		gem.custom_minimum_size = Vector2(22, 22)
		gem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		gem.rotation = PI / 4.0
		gem.pivot_offset = Vector2(11, 11)
		frame.add_child(gem)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var name_label := UITheme.title_label(title, 30, UITheme.ASH if unknown else UITheme.GOLD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(name_label)
	var text := Label.new()
	text.text = body
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 18)
	text.add_theme_color_override("font_color", UITheme.ASH if unknown else UITheme.BONE)
	column.add_child(text)
	_page.add_child(row)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.015, 0.03, 0.97)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", OrnateBox.new(UITheme.INK, UITheme.BRONZE, 22.0))
	center.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	row.add_child(side)
	side.add_child(UITheme.title_label("Codex", 52, UITheme.GOLD))
	side.add_child(OrnateRule.new(200.0))
	_count = Label.new()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.add_theme_color_override("font_color", UITheme.ASH)
	side.add_child(_count)
	_nav = VBoxContainer.new()
	_nav.add_theme_constant_override("separation", 2)
	side.add_child(_nav)
	for page: String in PAGES:
		var item := UITheme.menu_item(page, _show.bind(page))
		item.custom_minimum_size = Vector2(230, 42)
		item.add_theme_font_size_override("font_size", 26)
		item.focus_entered.connect(_show.bind(page))
		_nav.add_child(item)
	var back := UITheme.menu_item("Back", close, "back")
	back.custom_minimum_size = Vector2(230, 42)
	back.add_theme_font_size_override("font_size", 26)
	_nav.add_child(back)
	var rule := ColorRect.new()
	rule.color = Color(UITheme.BRONZE, 0.5)
	rule.custom_minimum_size = Vector2(2, 0)
	row.add_child(rule)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(700, 560)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(_scroll)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 12)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_page)
