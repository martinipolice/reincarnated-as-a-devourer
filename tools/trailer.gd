extends SceneTree
# Records a ~50 s trailer with Godot's Movie Maker. Not part of the game:
#   godot --path . --resolution 1280x720 --fixed-fps 30 \
#     --write-movie build/trailer/trailer.avi -s res://tools/trailer.gd
# The AVI (MJPEG + audio) uploads to YouTube or itch as is. A scripted tour:
# the title, a forest swarm, a Devour, level-up cards, the goddess, the
# Ruin Guardian, the Demon King, and an end card, with captions between.
# Untyped on purpose: -s compiles this before autoloads exist. Never saves.

const FPS := 30
const CAPTION_LAYER := 50
const MOVES := ["move_right", "move_down", "move_left", "move_up"]

var main
var player
var _caption_layer: CanvasLayer
var _caption: Label
var _move := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.get_node("Settings").data.hints = false
	root.get_node("Settings").data.damage_numbers = true
	_build_caption()
	await _title()
	await _swarm()
	await _devour()
	await _level_up()
	await _shrine()
	await _guardian()
	await _demon_king()
	await _end_card()
	quit()


# Waits `seconds` of game time while the hero walks a slow square, unhurt.
func _play(seconds: float, walk := true) -> void:
	for frame in int(seconds * FPS):
		if main and is_instance_valid(main):
			player.set_invulnerable(1.0)
			player.hp = player.stat("max_hp")
			if main.level_up.visible:
				main.level_up.pick(0)
			if main.shrine.visible:
				main.shrine.skip()
			if walk and frame % (FPS * 2) == 0:
				_walk()
		await process_frame
	_stop_walking()


func _walk() -> void:
	_stop_walking()
	Input.action_press(MOVES[_move % MOVES.size()])
	_move += 1


func _stop_walking() -> void:
	for action in MOVES:
		Input.action_release(action)


func _caption_card(text: String, seconds := 2.2) -> void:
	_caption.text = text
	var tween := _caption_layer.create_tween()
	tween.tween_property(_caption, "modulate:a", 1.0, 0.4)
	tween.tween_interval(seconds)
	tween.tween_property(_caption, "modulate:a", 0.0, 0.4)


func _start_run(day: int) -> void:
	root.get_node("Save").resume = false
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	main = current_scene
	player = main.player
	main.elapsed = (day - 1) * 60.0 + 1.0
	for shrine_day in main.SHRINE_DAYS:
		if shrine_day <= day:
			main._shrines_done.append(shrine_day)  # the goddess has her own shot


func _title() -> void:
	root.get_node("Save").data.journey = {"day": 10, "level": 21}
	change_scene_to_file("res://scenes/ui/title.tscn")
	await _play(4.5, false)
	current_scene._show_menu(true)
	await _play(2.5, false)


func _swarm() -> void:
	await _start_run(4)
	for path in ["res://data/weapons/goddess_light.tres", "res://data/weapons/chains.tres"]:
		for i in 2:
			player.apply_upgrade(load(path))
	player.apply_upgrade(load("res://data/weapons/blade.tres"))
	_caption_card("You get one life.")
	for i in 30:
		main.spawner.spawn_at(load("res://data/enemies/dreadling.tres"), player.position + Vector2.from_angle(i * 0.21) * randf_range(260, 420))
	await _play(6.0)


func _devour() -> void:
	_caption_card("Grow by devouring what you kill.")
	main.spawner.spawn_enemy(true, 140.0)
	var elite = main.enemies.get_child(main.enemies.get_child_count() - 1)
	await _play(0.6, false)
	elite.take_damage(1e9)
	await _play(0.4, false)
	for corpse in get_nodes_in_group("corpses"):
		player.global_position = corpse.global_position
	Input.action_press("devour")
	await _play(1.6, false)
	Input.action_release("devour")
	await _play(1.5)


func _level_up() -> void:
	player.level = 9
	main.level_up.open(player.available_upgrades(main.UPGRADE_POOL).slice(0, 3), player)
	for frame in int(2.6 * FPS):
		await process_frame
	main.level_up.pick(1)
	await _play(1.0)


func _shrine() -> void:
	_caption_card("The goddess watches over you.")
	main.gold = 1400
	main.shrine.open(5, main)
	for frame in int(3.0 * FPS):
		await process_frame
	main.shrine.blessing_choices()[0].emit_signal("pressed")
	for frame in int(1.2 * FPS):
		await process_frame
	main.shrine.close()
	await _play(0.8)


func _guardian() -> void:
	await _start_run(10)
	for path in ["res://data/weapons/goddess_light.tres", "res://data/weapons/chains.tres", "res://data/weapons/doom_bell.tres"]:
		for i in 3:
			player.apply_upgrade(load(path))
	for i in 2:
		player.apply_upgrade(load("res://data/weapons/blade.tres"))
	player.level = 22
	main.elapsed = 9 * 60.0 + main.spawner.MINI_BOSS_DELAY - 0.5
	_caption_card("Twenty days to grow strong.")
	await _play(7.0)


func _demon_king() -> void:
	main.elapsed = 19 * 60.0 + 0.5
	await _play(1.0)
	_caption_card("Then the Demon King comes for you.", 2.6)
	await _play(7.5)


func _end_card() -> void:
	load("res://scripts/ui/title.gd")._greeted = false  # the crest, not the menu
	change_scene_to_file("res://scenes/ui/title.tscn")
	main = null
	await process_frame
	await process_frame
	current_scene._press.hide()
	_caption.add_theme_font_size_override("font_size", 40)
	_caption_card("Free on itch.io", 4.0)
	await _play(5.5, false)


func _build_caption() -> void:
	_caption_layer = CanvasLayer.new()
	_caption_layer.layer = CAPTION_LAYER
	root.add_child(_caption_layer)
	_caption = load("res://scripts/ui/ui_theme.gd").title_label("", 56, Color(0.92, 0.89, 0.82))
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.add_theme_constant_override("outline_size", 12)
	_caption_layer.add_child(_caption)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.offset_top = -170
	_caption.offset_bottom = -90
	_caption.offset_left = -640
	_caption.offset_right = 640
	_caption.modulate.a = 0.0
