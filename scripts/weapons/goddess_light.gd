extends Weapon
## Fires bolts of light at the nearest enemies. More bolts and pierce per level.

const BOLT_SCENE := preload("res://scenes/weapons/light_bolt.tscn")
const DAMAGE := [22.0, 30.0, 40.0]
const BOLTS := [1, 2, 4]
const PIERCE := [0, 1, 3]
const COOLDOWN := [1.3, 1.1, 0.9]  # divided by the player's haste
const RANGE := 450.0

var _timer := 0.0


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	var targets := nearest_enemies(per_level(BOLTS), RANGE)
	if targets.is_empty():
		return  # stay ready; fire as soon as something is in range
	_timer = per_level(COOLDOWN) / player.stat("haste")
	for enemy in targets:
		Game.sfx("light_cast", 0.12)
		var bolt := BOLT_SCENE.instantiate() as LightBolt
		bolt.setup(global_position.direction_to(enemy.global_position),
			damage(per_level(DAMAGE)), per_level(PIERCE))
		bolt.position = global_position
		player.get_parent().add_child(bolt)
