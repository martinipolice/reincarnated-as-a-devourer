extends Weapon
## Devourer's Maw: spectral jaws snap shut on the nearest enemies within
## reach, hard, and every kill they make feeds you a little HP.
## Evolves into the Abyssal Maw after Devouring 3 Dreadling essences at Lv 3:
## three bites at once, and every bite heals, kill or not.

const DAMAGE := [36.0, 50.0, 68.0]
const REACH := [115.0, 130.0, 145.0]
const COOLDOWN := [1.3, 1.15, 1.0]  # divided by the player's haste
const BITES := [1, 1, 2]
const KILL_HEAL := [1.0, 2.0, 3.0]  # HP per kill
const EVOLVED_DAMAGE := 85.0
const EVOLVED_BITES := 3
const EVOLVED_LIFESTEAL := 0.03  # of damage dealt, on every bite
const SNAP_TIME := 0.22
const JAW_SIZE := 22.0
const COLOR := Color(0.95, 0.9, 0.85)
const EVOLVED_COLOR := Color(0.7, 0.4, 1.0)

var _timer := 0.0
## Bites being drawn: [global position, seconds since the snap].
var _bites: Array = []


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		var frenzy := branch_rank("b")
		var reach: float = per_level(REACH) + 15.0 * frenzy
		var targets := nearest_enemies(EVOLVED_BITES if evolved else per_level(BITES), reach)
		if not targets.is_empty():
			_timer = per_level(COOLDOWN) * (1.0 - 0.15 * frenzy) / player.stat("haste")
			_bite(targets)
	for bite: Array in _bites:
		bite[1] += delta
	_bites = _bites.filter(func(bite: Array) -> bool: return bite[1] < SNAP_TIME)
	queue_redraw()


func _bite(targets: Array[Enemy]) -> void:
	var amount := damage(EVOLVED_DAMAGE if evolved else per_level(DAMAGE))
	var healed := 0.0
	Game.sfx("maw", 0.1)
	for enemy in targets:
		_bites.append([enemy.global_position, 0.0])
		enemy.take_damage(amount, Vector2.ZERO, "maw_hit", source())
		if evolved:
			healed += amount * EVOLVED_LIFESTEAL
		if not enemy.alive():
			healed += per_level(KILL_HEAL) * (1 + branch_rank("a"))  # Gorge
	if healed > 0.0 and player.hp > 0.0:
		player.hp = minf(player.stat("max_hp"), player.hp + healed)


# Two rows of fangs that slam together over the target.
func _draw() -> void:
	var color := EVOLVED_COLOR if evolved else COLOR
	for bite: Array in _bites:
		var t: float = bite[1] / SNAP_TIME
		var at := to_local(bite[0])
		var gap := JAW_SIZE * (1.0 - minf(t * 2.0, 1.0))  # closes in the first half
		var alpha := 1.0 - maxf(0.0, t - 0.5) * 2.0  # fades in the second
		for side in [-1.0, 1.0]:
			var y: float = at.y + side * (gap + 4.0)
			for i in 4:
				var x := at.x - JAW_SIZE * 0.75 + i * JAW_SIZE * 0.5
				var fang := PackedVector2Array([Vector2(x - 5, y), Vector2(x + 5, y), Vector2(x, y - side * 9.0)])
				draw_colored_polygon(fang, Color(color, alpha))
			draw_line(Vector2(at.x - JAW_SIZE, y), Vector2(at.x + JAW_SIZE, y), Color(0.3, 0.05, 0.1, alpha), 3.0)
