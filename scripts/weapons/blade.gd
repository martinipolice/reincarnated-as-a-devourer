extends Weapon
## Strikes every enemy around you on a cooldown. Its levels are the old
## shop's weapon tiers: Dull Blade -> Standard Greatsword -> Mithril Warblade.
## Evolves into Vexclaw Rend after Devouring 3 Vexclaw essences at Lv 3.
## Each swing draws one clean swoosh: a single arc that sweeps once around
## you at the Blade's reach, bright at its leading edge and fading behind
## (red once evolved).

const DAMAGE := [34.0, 50.0, 70.0]
const RADIUS := [75.0, 90.0, 110.0]
const COOLDOWN := [0.9, 0.8, 0.65]  # divided by the player's haste
const EVOLVED_DAMAGE := 90.0
const EVOLVED_RADIUS := 120.0
const EVOLVED_COOLDOWN := 0.6
const KNOCKBACK := 140.0
const SWEEP_TIME := 0.2  # one full circle
const FADE_TIME := 0.08  # the tail catching up after the head finishes
const TRAIL := 2.2  # radians of trail behind the leading edge
const TRAIL_SEGMENTS := 24
const WIDTH := 13.0
const SHADOW := Color(0.1, 0.12, 0.05)  # keeps the white arc readable on grass
const COLOR := Color(1, 1, 1)
const EVOLVED_COLOR := Color(1, 0.35, 0.3)

var _hitbox: Area2D
var _timer := 0.0
var _sweep := -1.0  # seconds into the current swoosh; < 0 = none
var _start_angle := 0.0


func _ready() -> void:
	_hitbox = make_hitbox(_radius())


func _on_level_changed() -> void:
	set_hitbox_radius(_hitbox, _radius())


func _radius() -> float:
	return EVOLVED_RADIUS if evolved else per_level(RADIUS)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		var cooldown: float = EVOLVED_COOLDOWN if evolved else per_level(COOLDOWN)
		_timer = cooldown / player.stat("haste")
		_swing()
	if _sweep >= 0.0:
		_sweep += delta
		if _sweep > SWEEP_TIME + FADE_TIME:
			_sweep = -1.0
		queue_redraw()


func _swing() -> void:
	var amount: float = EVOLVED_DAMAGE if evolved else per_level(DAMAGE)
	var targets := enemies_in(_hitbox)
	if not targets.is_empty():
		Game.sfx("blade")
	for enemy in targets:
		var push := global_position.direction_to(enemy.global_position) * KNOCKBACK
		enemy.take_damage(damage(amount), push, "blade_hit", source())
	_sweep = 0.0
	_start_angle = randf() * TAU


func _draw() -> void:
	if _sweep < 0.0:
		return
	# Leading edge: eases out over one full turn, then holds while the tail
	# shrinks into it.
	var t := clampf(_sweep / SWEEP_TIME, 0.0, 1.0)
	var head := _start_angle + TAU * (1.0 - pow(1.0 - t, 2.0))
	var fade := clampf((_sweep - SWEEP_TIME) / FADE_TIME, 0.0, 1.0)
	var trail := minf(TRAIL * (1.0 - fade), head - _start_angle)
	if trail <= 0.01:
		return
	var radius := _radius()
	var color := EVOLVED_COLOR if evolved else COLOR
	var previous := Vector2.RIGHT.rotated(head - trail) * radius
	for i in range(1, TRAIL_SEGMENTS + 1):
		var k := float(i) / TRAIL_SEGMENTS  # 0 at the tail, 1 at the head
		var point := Vector2.RIGHT.rotated(head - trail * (1.0 - k)) * radius
		# A shadow, a soft wide glow and a crisp core, all tapering toward the tail.
		draw_line(previous + Vector2(0, 3), point + Vector2(0, 3), Color(SHADOW, 0.3 * k), WIDTH * k + 2.0)
		draw_line(previous, point, Color(color, 0.22 * k), WIDTH * 2.2 * k + 1.0)
		draw_line(previous, point, Color(color, 0.95 * k * k), WIDTH * k + 1.0)
		previous = point
