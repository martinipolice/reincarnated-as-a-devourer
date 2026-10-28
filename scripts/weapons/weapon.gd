class_name Weapon
extends Node2D
## Base for auto-firing weapons. A weapon is a child of the player's Weapons
## node; subclasses read `level` through per_level() and scale damage by the
## player's might. Set `data`, `player` and `level` before add_child().

var data: WeaponData
var player: Player
var level := 1
## Set by evolve() once the weapon is maxed and enough essences are Devoured.
var evolved := false
## The branch taken at Lv 3 ("a" or "b"; Branches), "" before.
var branch := ""


func set_level(value: int) -> void:
	level = value
	_on_level_changed()


func evolve() -> void:
	evolved = true
	_on_level_changed()


## Override to rebuild hitboxes, counts, etc. when the level or evolution changes.
func _on_level_changed() -> void:
	pass


## 1 at Lv 4 and 2 at Lv 5 on branch `id`, else 0.
func branch_rank(id: String) -> int:
	return level - data.max_level if branch == id else 0


## Picks this level's entry from a per-level table like [30, 42, 56].
func per_level(table: Array) -> Variant:
	return table[clampi(level, 1, table.size()) - 1]


## The name its damage is logged under (Enemy.damage_log).
func source() -> String:
	return data.display_name


func damage(amount: float) -> float:
	return amount * player.stat("might")


## A circular Area2D child that detects enemies (layer 2).
func make_hitbox(radius: float) -> Area2D:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitorable = false
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	area.add_child(shape)
	add_child(area)
	set_hitbox_radius(area, radius)
	return area


func set_hitbox_radius(area: Area2D, radius: float) -> void:
	((area.get_child(0) as CollisionShape2D).shape as CircleShape2D).radius = radius


func enemies_in(area: Area2D) -> Array[Enemy]:
	var found: Array[Enemy] = []
	for other in area.get_overlapping_areas():
		if other is Enemy:
			found.append(other)
	return found


func nearest_enemies(count: int, max_range: float) -> Array[Enemy]:
	var found: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.alive() and global_position.distance_to(enemy.global_position) <= max_range:
			found.append(enemy)
	found.sort_custom(func(a: Enemy, b: Enemy) -> bool:
		return global_position.distance_squared_to(a.global_position) \
			< global_position.distance_squared_to(b.global_position))
	found.resize(mini(count, found.size()))
	return found
