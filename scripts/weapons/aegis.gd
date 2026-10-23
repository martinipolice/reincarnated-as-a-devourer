extends Weapon
## Golden blades that orbit you, hitting and shoving away enemies they touch.
## Each blade's hitbox is a capsule matching its sprite, and a blade hits as
## soon as it touches an enemy; HIT_COOLDOWN stops it hitting the same enemy
## every frame while they overlap.

const BLADE_TEXTURE := preload("res://assets/weapons/weapon_golden_sword.png")
const SHIELDS := [1, 2, 3]
const DAMAGE := [14.0, 20.0, 28.0]
const ORBIT_RADIUS := 60.0
const SPRITE_SCALE := 2.0
## Capsule around the blade art (10x22 px at 2x), slightly narrower than the
## sprite so grazing the empty corners doesn't count.
const BLADE_HALF_WIDTH := 8.0
const SPIN := 3.0  # radians per second, times the player's haste
const HIT_COOLDOWN := 0.35  # per enemy
const KNOCKBACK := 260.0

var _shields: Array[Area2D] = []
## Enemy instance id -> time it can next be hit.
var _next_hit := {}
var _time := 0.0


func _ready() -> void:
	_on_level_changed()


func _on_level_changed() -> void:
	for shield in _shields:
		shield.queue_free()
	_shields.clear()
	var count: int = per_level(SHIELDS)
	for i in count:
		var angle := TAU * i / count
		var shield := _make_blade()
		shield.position = Vector2.RIGHT.rotated(angle) * ORBIT_RADIUS
		shield.rotation = angle + PI / 2.0  # the art points up; aim it outward
		_shields.append(shield)


func _make_blade() -> Area2D:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitorable = false
	var capsule := CapsuleShape2D.new()
	capsule.radius = BLADE_HALF_WIDTH
	capsule.height = BLADE_TEXTURE.get_height() * SPRITE_SCALE
	var shape := CollisionShape2D.new()
	shape.shape = capsule
	area.add_child(shape)
	var blade := Sprite2D.new()
	blade.texture = BLADE_TEXTURE
	blade.scale = Vector2.ONE * SPRITE_SCALE
	area.add_child(blade)
	add_child(area)
	return area


func _physics_process(delta: float) -> void:
	rotation += SPIN * player.stat("haste") * delta
	_time += delta
	for shield in _shields:
		for enemy in enemies_in(shield):
			var id := enemy.get_instance_id()
			if _time < _next_hit.get(id, 0.0):
				continue
			_next_hit[id] = _time + HIT_COOLDOWN
			var push := global_position.direction_to(enemy.global_position) * KNOCKBACK
			enemy.take_damage(damage(per_level(DAMAGE)), push, "aegis_hit")
	if _next_hit.size() > 256:
		_forget_expired()


func _forget_expired() -> void:
	for id in _next_hit.keys():
		if _next_hit[id] < _time:
			_next_hit.erase(id)
