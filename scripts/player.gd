class_name Player
extends CharacterBody2D
## The Devourer. `base` holds the only true stats; items, Devour essences and
## buffs are entries in `modifiers`, read through stat(). Never write to
## `base` for a temporary effect (the old Defend bug came from doing that).

signal died

const BODY_COLOR := Color(0.9, 0.82, 0.55)
const BODY_RADIUS := 12.0
const BLADE_RADIUS := 70.0
const HIT_INVULN := 0.5

var base := {
	"max_hp": 100.0,
	"atk": 20.0,
	"defense": 8.0,
	"move_speed": 160.0,
	"blade_cooldown": 1.0,
}
## Each entry: {"stat": "atk", "add": 10.0, "mult": 0.0}
var modifiers: Array[Dictionary] = []
var hp: float

var _invuln := 0.0
var _blade_timer := 0.0
var _blade_flash := 0.0

@onready var hurtbox: Area2D = $Hurtbox
@onready var blade_range: Area2D = $BladeRange


func _ready() -> void:
	add_to_group("player")
	($BladeRange/CollisionShape2D.shape as CircleShape2D).radius = BLADE_RADIUS
	hp = stat("max_hp")


func stat(stat_name: String) -> float:
	var add := 0.0
	var mult := 1.0
	for mod in modifiers:
		if mod.stat == stat_name:
			add += mod.get("add", 0.0)
			mult += mod.get("mult", 0.0)
	return (base[stat_name] + add) * mult


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input * stat("move_speed")
	move_and_slide()

	_invuln = maxf(0.0, _invuln - delta)
	if _invuln == 0.0:
		for area in hurtbox.get_overlapping_areas():
			if area is Enemy:
				take_damage((area as Enemy).data.atk)
				break

	_blade_timer -= delta
	if _blade_timer <= 0.0:
		_blade_timer = stat("blade_cooldown")
		_swing_blade()

	if _blade_flash > 0.0:
		_blade_flash -= delta
		queue_redraw()


func take_damage(atk: float) -> void:
	hp -= Game.damage(atk, stat("defense"))
	_invuln = HIT_INVULN
	if hp <= 0.0:
		hp = 0.0
		set_physics_process(false)
		died.emit()


# Placeholder weapon: hits every enemy in range on a cooldown.
func _swing_blade() -> void:
	_blade_flash = 0.15
	for area in blade_range.get_overlapping_areas():
		if area is Enemy:
			(area as Enemy).take_damage(stat("atk"))
	queue_redraw()


func _draw() -> void:
	if _blade_flash > 0.0:
		draw_arc(Vector2.ZERO, BLADE_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
	var body := BODY_COLOR if _invuln == 0.0 else Color(1, 0.4, 0.4)
	draw_circle(Vector2.ZERO, BODY_RADIUS, body)
