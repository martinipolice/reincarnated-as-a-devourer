extends Weapon
## Strikes every enemy around you on a cooldown. Its levels are the old
## shop's weapon tiers: Dull Blade -> Standard Greatsword -> Mithril Warblade.

const DAMAGE := [34.0, 46.0, 60.0]
const RADIUS := [75.0, 85.0, 100.0]
const COOLDOWN := [0.9, 0.8, 0.7]
const KNOCKBACK := 140.0
const FLASH_TIME := 0.15

var _hitbox: Area2D
var _timer := 0.0
var _flash := 0.0


func _ready() -> void:
	_hitbox = make_hitbox(per_level(RADIUS))


func _on_level_changed() -> void:
	set_hitbox_radius(_hitbox, per_level(RADIUS))


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = per_level(COOLDOWN)
		_swing()
	if _flash > 0.0:
		_flash -= delta
		queue_redraw()


func _swing() -> void:
	_flash = FLASH_TIME
	for enemy in enemies_in(_hitbox):
		var push := global_position.direction_to(enemy.global_position) * KNOCKBACK
		enemy.take_damage(damage(per_level(DAMAGE)), push)
	queue_redraw()


func _draw() -> void:
	if _flash > 0.0:
		var alpha := 0.5 * _flash / FLASH_TIME
		draw_arc(Vector2.ZERO, per_level(RADIUS), 0.0, TAU, 48, Color(1, 1, 1, alpha), 3.0)
