extends Weapon
## Shields that orbit you, hitting and shoving away enemies they touch.

const SHIELDS := [1, 2, 3]
const DAMAGE := [14.0, 18.0, 24.0]
const ORBIT_RADIUS := 60.0
const SHIELD_RADIUS := 12.0
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
		var shield := make_hitbox(SHIELD_RADIUS)
		shield.position = Vector2.RIGHT.rotated(TAU * i / count) * ORBIT_RADIUS
		_shields.append(shield)
	queue_redraw()


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


func _draw() -> void:
	for shield in _shields:
		draw_circle(shield.position, SHIELD_RADIUS, Color(0.55, 0.7, 1.0))
		draw_arc(shield.position, SHIELD_RADIUS, 0.0, TAU, 24, Color.WHITE, 2.0)
