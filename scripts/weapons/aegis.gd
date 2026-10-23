extends Weapon
## Golden blades that orbit you, hitting and shoving away enemies they touch.

const BLADE_TEXTURE := preload("res://assets/weapons/weapon_golden_sword.png")
const SHIELDS := [1, 2, 3]
const DAMAGE := [14.0, 18.0, 24.0]
const ORBIT_RADIUS := 60.0
const SHIELD_RADIUS := 12.0  # hitbox; the sprite is drawn on top of it
const SPRITE_SCALE := 2.0
const SPIN := 3.0  # radians per second
const TICK := 0.35
const KNOCKBACK := 260.0

var _shields: Array[Area2D] = []
var _timer := 0.0


func _ready() -> void:
	_on_level_changed()


func _on_level_changed() -> void:
	for shield in _shields:
		shield.queue_free()
	_shields.clear()
	var count: int = per_level(SHIELDS)
	for i in count:
		var angle := TAU * i / count
		var shield := make_hitbox(SHIELD_RADIUS)
		shield.position = Vector2.RIGHT.rotated(angle) * ORBIT_RADIUS
		var blade := Sprite2D.new()
		blade.texture = BLADE_TEXTURE
		blade.scale = Vector2.ONE * SPRITE_SCALE
		blade.rotation = angle + PI / 2.0  # the art points up; aim it outward
		shield.add_child(blade)
		_shields.append(shield)


func _physics_process(delta: float) -> void:
	rotation += SPIN * delta
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = TICK
	for shield in _shields:
		for enemy in enemies_in(shield):
			var push := global_position.direction_to(enemy.global_position) * KNOCKBACK
			enemy.take_damage(damage(per_level(DAMAGE)), push)
