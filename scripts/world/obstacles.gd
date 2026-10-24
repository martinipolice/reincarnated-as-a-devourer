class_name Obstacles
## Every blocking prop in the world (trees, rocks, arena pillars) as a circle
## in a spatial grid. The player collides with their StaticBody2D, but enemies
## are Areas moved by code, so they ask this registry to push them back out of
## any obstacle they walk into; with their steering, that makes them slide
## around trees instead of through them.

const CELL := 96.0

static var _cells := {}


## Registers a circle; keep the returned handle to remove it later.
static func add(center: Vector2, radius: float) -> Dictionary:
	var handle := {"center": center, "radius": radius, "keys": _keys_for(center, radius)}
	for key: Vector2i in handle.keys:
		if _cells.has(key):
			_cells[key].append(handle)
		else:
			_cells[key] = [handle]
	return handle


static func remove(handle: Dictionary) -> void:
	for key: Vector2i in handle.keys:
		if _cells.has(key):
			_cells[key].erase(handle)
			if _cells[key].is_empty():
				_cells.erase(key)


static func clear() -> void:
	_cells.clear()


## `at` moved out of any obstacle a circle of `radius` would overlap.
static func push_out(at: Vector2, radius: float) -> Vector2:
	for handle: Dictionary in _cells.get(_key(at), []):
		var away: Vector2 = at - handle.center
		var reach: float = handle.radius + radius
		var distance := away.length()
		if distance < reach:
			if distance < 0.01:
				away = Vector2.RIGHT
				distance = 1.0
			at = handle.center + away / distance * reach
	return at


## True when a circle at `at` would overlap an obstacle.
static func blocked(at: Vector2, radius: float) -> bool:
	for handle: Dictionary in _cells.get(_key(at), []):
		if at.distance_to(handle.center) < handle.radius + radius:
			return true
	return false


## Obstacle circles near `at` (for the balance-sim bot).
static func near(at: Vector2) -> Array:
	return _cells.get(_key(at), [])


static func _key(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / CELL), floori(at.y / CELL))


# Every cell the circle touches, so lookups only need the caller's own cell.
static func _keys_for(center: Vector2, radius: float) -> Array:
	var keys := []
	var reach := radius + 40.0  # covers the largest enemy that might overlap it
	var low := _key(center - Vector2(reach, reach))
	var high := _key(center + Vector2(reach, reach))
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			keys.append(Vector2i(x, y))
	return keys
