class_name Crowd
## A spatial hash of enemy positions, rebuilt once per physics frame by
## main.gd. Lets each enemy find its neighbors by looking at 9 grid cells
## instead of every enemy on the map, so crowd separation stays cheap with
## hundreds on screen. In a dense pile-up a cell can hold dozens, so a check
## stops after MAX_CHECKS candidates, and enemies refresh their push only
## every few steps (enemy.gd SEPARATION_EVERY).

const CELL := 40.0  # at least two radii of the larger monsters, so no pushing pair is missed
const MAX_CHECKS := 20
const EMPTY := []  # shared, so a miss doesn't allocate a new array

static var _cells := {}


static func rebuild(enemies: Array[Node]) -> void:
	_cells.clear()
	for node in enemies:
		var enemy := node as Enemy
		if enemy == null or enemy.data.boss:
			continue
		var key := _key(enemy.global_position)
		if _cells.has(key):
			_cells[key].append(enemy)
		else:
			_cells[key] = [enemy]


## Drops every reference; main.gd calls it when the run scene closes.
static func clear() -> void:
	_cells.clear()


## A push away from nearby enemies, stronger the more they overlap.
static func separation(enemy: Enemy) -> Vector2:
	var push := Vector2.ZERO
	var at := enemy.global_position
	var center := _key(at)
	var checks := 0
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for other: Enemy in _cells.get(center + Vector2i(dx, dy), EMPTY):
				if other == enemy:
					continue
				checks += 1
				if checks > MAX_CHECKS:
					return push
				var away := at - other.global_position
				var reach := enemy.radius + other.radius
				var distance_sq := away.length_squared()
				if distance_sq < reach * reach and distance_sq > 0.0001:
					var distance := sqrt(distance_sq)
					push += away / distance * (1.0 - distance / reach)
	return push


static func _key(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / CELL), floori(at.y / CELL))
