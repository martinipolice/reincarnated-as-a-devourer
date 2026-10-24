class_name Crowd
## A spatial hash of enemy positions, rebuilt once per physics frame by
## main.gd. Lets each enemy find its neighbors by looking at 9 grid cells
## instead of every enemy on the map, so crowd separation stays cheap with
## hundreds on screen.

const CELL := 48.0

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
	var center := _key(enemy.global_position)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for other: Enemy in _cells.get(center + Vector2i(dx, dy), []):
				if other == enemy or not is_instance_valid(other):
					continue
				var away := enemy.global_position - other.global_position
				var reach := enemy.radius + other.radius
				var distance := away.length()
				if distance < reach and distance > 0.01:
					push += away / distance * (1.0 - distance / reach)
	return push


static func _key(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / CELL), floori(at.y / CELL))
