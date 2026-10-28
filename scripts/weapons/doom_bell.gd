extends Weapon
## Doom Bell: a spectral bell drops over the nearest enemy, hangs there for a
## beat (its ring marks the blast), then tolls: damage to everything inside,
## and they're slowed for a moment. The only weapon that controls space.
## Evolves into the Death Knell after Devouring 3 Hexeye essences at Lv 3:
## three bells at once, a wider toll and a heavier slow.

const DAMAGE := [40.0, 58.0, 80.0]
const RADIUS := [80.0, 95.0, 110.0]
const BELLS := [1, 1, 2]
const COOLDOWN := [2.4, 2.1, 1.8]  # divided by the player's haste
const RANGE := 380.0
const DELAY := 0.6  # from the bell appearing to its toll
const SLOW := 0.45  # enemies move at this fraction of their speed...
const SLOW_TIME := 1.5  # ...for this long
const EVOLVED_DAMAGE := 95.0
const EVOLVED_RADIUS := 130.0
const EVOLVED_BELLS := 3
const EVOLVED_SLOW := 0.3
const COLOR := Color(0.75, 0.55, 1.0)
const EVOLVED_COLOR := Color(1.0, 0.4, 0.55)

var _timer := 0.8
## Bells hanging: [global position, seconds until the toll].
var _bells: Array = []


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		var targets := nearest_enemies(EVOLVED_BELLS if evolved else per_level(BELLS), RANGE)
		if not targets.is_empty():
			_timer = per_level(COOLDOWN) / player.stat("haste")
			for enemy in targets:
				_bells.append([enemy.global_position, DELAY])
	for bell: Array in _bells:
		bell[1] -= delta
		if bell[1] <= 0.0:
			_toll(bell[0])
	_bells = _bells.filter(func(bell: Array) -> bool: return bell[1] > 0.0)
	queue_redraw()


func _toll(at: Vector2) -> void:
	var radius: float = EVOLVED_RADIUS if evolved else per_level(RADIUS)
	var amount := damage(EVOLVED_DAMAGE if evolved else per_level(DAMAGE))
	var slow := EVOLVED_SLOW if evolved else SLOW
	Game.sfx("bell", 0.1)
	Game.shockwave(at, EVOLVED_COLOR if evolved else COLOR, radius, 0.35)
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy.alive() and enemy.global_position.distance_squared_to(at) <= radius * radius:
			enemy.take_damage(amount, Vector2.ZERO, "", source())
			enemy.slow(slow, SLOW_TIME)


# Each bell: a ring on the ground (where it will toll) and the bell above it.
func _draw() -> void:
	var color := EVOLVED_COLOR if evolved else COLOR
	var radius: float = EVOLVED_RADIUS if evolved else per_level(RADIUS)
	for bell: Array in _bells:
		var at := to_local(bell[0])
		var t: float = 1.0 - bell[1] / DELAY
		draw_arc(at, radius, 0.0, TAU, 32, Color(color, 0.25 + 0.4 * t), 2.0)
		draw_circle(at, radius * t, Color(color, 0.08))
		# The bell: a dome and a rim, dropping into place.
		var top := at + Vector2(0, -40.0 * (1.0 - t) - 18.0)
		var dome := PackedVector2Array()
		for i in 9:
			var a := PI + PI * i / 8.0
			dome.append(top + Vector2(cos(a) * 11.0, sin(a) * 13.0 + 13.0))
		dome.append(top + Vector2(13, 16))
		dome.append(top + Vector2(-13, 16))
		draw_colored_polygon(dome, Color(color.lightened(0.3), 0.85))
		draw_circle(top + Vector2(0, 18), 3.0, Color(color.darkened(0.4), 0.9))
