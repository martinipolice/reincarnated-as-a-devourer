extends SceneTree
# Headless balance sim: plays a run with a bot and prints progress every
# other day. Not part of the game. From the project folder:
#   godot --headless --fixed-fps 60 -s res://tools/balance_sim.gd -- <afk|kite> <seed>
# Untyped on purpose: -s compiles this before autoloads exist.

var main: Node
var frame := 0
var mode := "kite"
var last_day := 0
var first_level_at := -1.0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: mode = args[0]
	if args.size() > 1: seed(int(args[1]))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

func _process(_delta: float) -> bool:
	frame += 1
	if main.level_up.visible:
		main.level_up._pick(randi() % main.level_up._offers.size())
		return false
	if mode == "kite":
		_steer()
	var p = main.player
	if first_level_at < 0 and p.level > 1:
		first_level_at = frame / 60.0
	if main.day() != last_day and main.day() % 2 == 1:
		last_day = main.day()
		print("  day %2d  t=%3ds hp=%3d/%3d lv=%2d kills=%4d alive=%3d  %s" % [
			main.day(), frame / 60, p.hp, p.stat("max_hp"), p.level, main.kills,
			main.enemies.get_child_count(), _loadout(p)])
	if main._over:
		print("END %s: day %d t=%ds lv %d kills %d first-level %.1fs" % [
			mode, main.day(), frame / 60, p.level, main.kills, first_level_at])
		return true
	return false

func _loadout(p) -> String:
	var parts := []
	for u in p.upgrade_levels:
		parts.append("%s%d" % [u.display_name.left(5), p.upgrade_levels[u]])
	return " ".join(parts)

func _steer() -> void:
	var p = main.player
	var push := Vector2.ZERO
	var nearest = null
	var nd := 1e9
	for e in main.enemies.get_children():
		var d: Vector2 = p.global_position - e.global_position
		var dist := d.length()
		if dist < nd:
			nd = dist
			nearest = e
		if dist < 60 and dist > 0.1:
			push += d / dist * (60 - dist) / 60 * 4.0
	var pull := Vector2.ZERO
	var best := 1e9
	for g in main.pickups.get_children():
		var dist: float = p.global_position.distance_to(g.global_position)
		if dist < best:
			best = dist
			pull = (g.global_position - p.global_position).normalized()
	var dir := push + pull * 0.8
	if nearest and nd > 70:
		dir += (nearest.global_position - p.global_position).normalized() * 0.5
	if dir.length() < 0.2:
		dir = Vector2.RIGHT.rotated(frame / 120.0)
	dir = dir.normalized()
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	if dir.x < 0: Input.action_press("move_left", -dir.x)
	if dir.x > 0: Input.action_press("move_right", dir.x)
	if dir.y < 0: Input.action_press("move_up", -dir.y)
	if dir.y > 0: Input.action_press("move_down", dir.y)
