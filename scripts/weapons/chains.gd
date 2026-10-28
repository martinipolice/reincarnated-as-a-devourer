extends Weapon
## Hellfire Chains: a burning chain lashes out in an arc where you're facing,
## hitting everything it sweeps through and setting it alight.
## Evolves into the Chains of the Damned after Devouring 3 Plaguewing
## essences at Lv 3: it lashes front and back at once, and burns twice as hot.

const DAMAGE := [20.0, 28.0, 38.0]
const LENGTH := [170.0, 190.0, 215.0]
const ARC := [1.9, 2.35, 2.8]  # radians swept
const COOLDOWN := [1.3, 1.15, 1.0]  # divided by the player's haste
const BURN_DPS := [6.0, 9.0, 12.0]
const BURN_TIME := 3.0
const EVOLVED_DAMAGE := 46.0
const EVOLVED_BURN_MULT := 2.0
const KNOCKBACK := 90.0
const LASH_TIME := 0.24
const LINKS := 9
const COLOR := Color(1.0, 0.55, 0.15)
const EVOLVED_COLOR := Color(0.6, 1.0, 0.3)

var _timer := 0.5
var _lash := -1.0  # seconds into the current lash; < 0 = none
var _aims: Array[Vector2] = []


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = per_level(COOLDOWN) / player.stat("haste")
		_strike()
	if _lash >= 0.0:
		_lash += delta
		if _lash > LASH_TIME:
			_lash = -1.0
		queue_redraw()


func _strike() -> void:
	var aim := player.aim
	_aims.assign([aim, -aim] if evolved else [aim])
	var length: float = per_level(LENGTH)
	var half: float = per_level(ARC) / 2.0
	var amount := damage(EVOLVED_DAMAGE if evolved else per_level(DAMAGE))
	var burn: float = per_level(BURN_DPS) * (EVOLVED_BURN_MULT if evolved else 1.0) * player.stat("might")
	var hit := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if not enemy.alive():
			continue
		var offset := enemy.global_position - global_position
		if offset.length() > length + enemy.radius:
			continue
		for dir: Vector2 in _aims:
			if absf(dir.angle_to(offset)) <= half:
				enemy.take_damage(amount, offset.normalized() * KNOCKBACK, "chains_hit", source())
				enemy.burn(burn, BURN_TIME)
				hit = true
				break
	Game.sfx("chains", 0.1)
	if hit:
		Game.shake(0.05)
	_lash = 0.0


# The chain swings across its arc: a line of glowing links whose head
# sweeps from one side to the other, the trail fading behind.
func _draw() -> void:
	if _lash < 0.0:
		return
	var t := clampf(_lash / LASH_TIME, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 3.0)
	var length: float = per_level(LENGTH)
	var half: float = per_level(ARC) / 2.0
	var color := EVOLVED_COLOR if evolved else COLOR
	var fade := 1.0 - maxf(0.0, t - 0.6) / 0.4
	for dir: Vector2 in _aims:
		var head := dir.angle() - half + 2.0 * half * eased
		for trail in 4:
			var angle := head - trail * 0.18
			if angle < dir.angle() - half:
				break
			var a := fade * (1.0 - trail * 0.25)
			for i in range(1, LINKS + 1):
				var p := Vector2.from_angle(angle) * length * i / LINKS
				draw_circle(p, 4.0, Color(0.15, 0.08, 0.05, a))
				draw_circle(p, 2.5, Color(color, a))
		draw_arc(Vector2.ZERO, length, head - 0.3, head, 8, Color(color.lightened(0.4), fade * 0.8), 3.0)
