extends Weapon
## Fires bolts of light at the nearest enemies. More bolts and pierce per level.
## Evolves into Goddess's Grace at Lv 3 with Vigor at Lv 3: a wider volley,
## and every hit returns a little of her light to you as health (capped per
## second, so it sustains without making you immortal).

const BOLT_SCENE := preload("res://scenes/weapons/light_bolt.tscn")
const DAMAGE := [22.0, 30.0, 40.0]
const BOLTS := [1, 2, 4]
const PIERCE := [0, 1, 3]
const COOLDOWN := [1.3, 1.1, 0.9]  # divided by the player's haste
const RANGE := 450.0
const EVOLVED_DAMAGE := 48.0
const EVOLVED_BOLTS := 6
const EVOLVED_PIERCE := 4
const EVOLVED_COOLDOWN := 0.8
const HEAL_PER_HIT := 0.6
const MAX_HEAL_PER_SECOND := 3.0

var _timer := 0.0
var _healed := 0.0  # this second
var _heal_window := 0.0


func _physics_process(delta: float) -> void:
	_heal_window -= delta
	if _heal_window <= 0.0:
		_heal_window = 1.0
		_healed = 0.0
	_timer -= delta
	if _timer > 0.0:
		return
	var targets := nearest_enemies(EVOLVED_BOLTS if evolved else per_level(BOLTS), RANGE)
	if targets.is_empty():
		return  # stay ready; fire as soon as something is in range
	_timer = (EVOLVED_COOLDOWN if evolved else per_level(COOLDOWN)) / player.stat("haste")
	var amount := damage(EVOLVED_DAMAGE if evolved else per_level(DAMAGE))
	var pierce: int = EVOLVED_PIERCE if evolved else per_level(PIERCE)
	for enemy in targets:
		Game.sfx("light_cast", 0.12)
		var bolt := BOLT_SCENE.instantiate() as LightBolt
		bolt.setup(global_position.direction_to(enemy.global_position), amount, pierce,
			self if evolved else null)
		bolt.position = global_position
		player.get_parent().add_child(bolt)


## A Grace bolt hit something: heal, within this second's cap.
func on_bolt_hit() -> void:
	var heal := minf(HEAL_PER_HIT, MAX_HEAL_PER_SECOND - _healed)
	if heal <= 0.0 or player.hp <= 0.0:
		return
	_healed += heal
	player.hp = minf(player.stat("max_hp"), player.hp + heal)
