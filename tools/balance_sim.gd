extends SceneTree
# Headless balance sim: plays a run with a bot and prints progress every
# other day. Not part of the game. From the project folder:
#   godot --headless --fixed-fps 60 -s res://tools/balance_sim.gd -- <mode> <seed>
# Modes: afk (stands still), kite (dodges, collects gems, never Devours),
#        devour (kite, plus Devours nearby corpses above 60% HP when the area is
#               clear, stopping once max HP drops below 80),
#        greedy (kite, plus Devours every corpse it can reach, no matter what).
# Untyped on purpose: -s compiles this before autoloads exist.

const DODGE_RADIUS := 60.0
const CORPSE_SEEK_RANGE := 250.0

var main: Node
var frame := 0
var mode := "kite"
var last_day := 0
var first_level_at := -1.0
var boss_at := -1.0
var last_boss_report := 0
var last_hp := -1.0
## Damage taken by apparent source, printed at the end of the run.
var damage_by := {}

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
	if mode != "afk":
		_steer()
	var p = main.player
	var t := frame / 60.0
	if last_hp >= 0.0 and p.hp < last_hp:
		var source := _damage_source(p)
		damage_by[source] = damage_by.get(source, 0.0) + (last_hp - p.hp)
	last_hp = p.hp
	if first_level_at < 0 and p.level > 1:
		first_level_at = t
	if main.day() != last_day and main.day() % 2 == 1:
		last_day = main.day()
		print("  day %2d  t=%3ds hp=%3d/%3d lv=%2d kills=%4d alive=%3d  %s" % [
			main.day(), t, p.hp, p.stat("max_hp"), p.level, main.kills,
			main.enemies.get_child_count(), _loadout(p)])
	if is_instance_valid(main.boss):
		if boss_at < 0:
			boss_at = t
		if int(t - boss_at) / 15 > last_boss_report:
			last_boss_report = int(t - boss_at) / 15
			print("    boss +%3ds: boss hp=%5d  player hp=%3d" % [t - boss_at, main.boss.hp, p.hp])
	if main._over:
		var result := "WON" if not is_instance_valid(main.boss) and boss_at >= 0 and p.hp > 0 else "DIED"
		var fight := "boss fight %ds" % (t - boss_at) if boss_at >= 0 else "no boss"
		print("END %s %s: day %d t=%ds lv %d kills %d gold %d devoured %d max_hp %d, %s, first level %.1fs" % [
			mode, result, main.day(), t, p.level, main.kills, main.gold, p.devour_count(),
			p.stat("max_hp"), fight, first_level_at])
		var parts := []
		for k in damage_by:
			parts.append("%s %d" % [k, damage_by[k]])
		print("    damage taken: ", ", ".join(parts))
		return true
	return false

# Best guess at what just hurt the player: whatever touching thing is nearest.
func _damage_source(p) -> String:
	for shot in main.get_tree().get_nodes_in_group("enemy_shots"):
		if shot.global_position.distance_to(p.global_position) < 55.0:
			return "plague"
	var best = null
	var nd := 1e9
	for e in main.enemies.get_children():
		var d: float = e.global_position.distance_to(p.global_position)
		if d < nd:
			nd = d
			best = e
	if best == null:
		return "other"
	if best.data.boss:
		return "boss"
	var kind: String = best.data.display_name
	if best.elite:
		kind = "elite " + kind
	if best.state == 2:  # DASH
		kind += " pounce"
	return kind

func _loadout(p) -> String:
	var parts := []
	for u in p.upgrade_levels:
		parts.append("%s%d" % [u.display_name.left(5), p.upgrade_levels[u]])
	for w in p.weapons.get_children():
		if w.evolved:
			parts.append("EVOLVED:" + w.data.evolved_name)
	for e in p.essences:
		parts.append("%s*%d" % [e.display_name.left(4), p.essences[e]])
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
		var danger: float = DODGE_RADIUS + e.radius
		if dist < danger and dist > 0.1:
			push += d / dist * (danger - dist) / danger * 4.0
	var boss = main.boss
	if is_instance_valid(boss) and boss.windup > 0.0:
		var away: Vector2 = p.global_position - boss.slam_at
		if away.length() < boss.slam_radius + 30.0:
			push += away.normalized() * 6.0

	for shot in main.get_tree().get_nodes_in_group("enemy_shots"):
		var d: Vector2 = p.global_position - shot.global_position
		var reach: float = (shot.radius() if shot.has_method("radius") else 20.0) + 40.0
		if d.length() < reach and d.length() > 0.1:
			push += d.normalized() * (reach - d.length()) / reach * 5.0
	for orb in main.get_tree().get_nodes_in_group("boss_orbs"):
		var d: Vector2 = p.global_position - orb.global_position
		if d.length() < 90.0 and d.length() > 0.1:
			push += d.normalized() * (90.0 - d.length()) / 90.0 * 5.0
	var pull := Vector2.ZERO
	var best := 1e9
	var corpse_target = null
	for g in main.pickups.get_children():
		var dist: float = p.global_position.distance_to(g.global_position)
		var is_corpse: bool = g.is_in_group("corpses")
		if is_corpse and (not _wants_corpse(g) or dist > CORPSE_SEEK_RANGE):
			continue
		if is_corpse:
			dist *= 0.3  # corpses win over gems
		if dist < best:
			best = dist
			pull = (g.global_position - p.global_position).normalized()
			corpse_target = g if is_corpse else null
	if corpse_target and p.global_position.distance_to(corpse_target.global_position) < 25.0:
		Input.action_press("devour")
	else:
		Input.action_release("devour")

	var dir: Vector2 = push + pull * (1.5 if corpse_target else 0.8)
	if nearest and nd > 70 and not corpse_target:
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

func _wants_corpse(corpse) -> bool:
	if mode == "greedy":
		return true
	if mode != "devour":
		return false
	var p = main.player
	if p.hp < p.stat("max_hp") * 0.6 or p.stat("max_hp") < 80.0:
		return false
	for e in main.enemies.get_children():
		if e.global_position.distance_to(corpse.global_position) < 120.0:
			return false
	return true
