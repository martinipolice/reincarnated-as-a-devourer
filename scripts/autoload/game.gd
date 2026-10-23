extends Node
## Global signals and helpers, available everywhere as `Game`.

signal enemy_killed(data: EnemyData, at: Vector2)


func _ready() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("restart", [KEY_R])


## Ratio mitigation. The terminal game used max(0, ATK - DEF), which drops to
## zero once DEF >= ATK; that breaks when hits land many times per second.
static func damage(atk: float, defense: float) -> float:
	return atk * 100.0 / (100.0 + defense)


# Actions are registered in code so they can be rebound later without
# hand-editing project.godot.
func _bind(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
