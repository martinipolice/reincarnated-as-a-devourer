class_name Player
extends CharacterBody2D
## The Devourer. `base` holds the only true stats; items, Devour essences and
## buffs are entries in `modifiers`, read through stat(). Never write to
## `base` for a temporary effect (the old Defend bug came from doing that).

signal died
signal leveled_up
signal devoured(essence: EssenceData)
signal weapon_evolved(weapon: Weapon)

const BODY_COLOR := Color(0.9, 0.82, 0.55)
const BODY_RADIUS := 12.0
const HIT_INVULN := 0.5
const MIN_MAX_HP := 10.0
## Holding Devour this long next to a corpse takes its essence.
const DEVOUR_TIME := 1.0
const DEVOUR_RANGE := 40.0
const DEVOUR_COLOR := Color(0.8, 0.45, 1.0)

var base := {
	"max_hp": 120.0,
	"might": 1.0,  # multiplies all weapon damage
	"defense": 10.0,
	"move_speed": 170.0,
	"pickup_radius": 90.0,
}
## Each entry: {"stat": "defense", "add": 10.0, "mult": 0.0}
var modifiers: Array[Dictionary] = []
var hp: float
var xp := 0
var level := 1
## Level-ups earned but not yet chosen on the level-up screen.
var pending_level_ups := 0
## WeaponData / ItemData -> how many times it has been picked.
var upgrade_levels := {}
## EssenceData -> how many have been Devoured this run.
var essences := {}

var _invuln := 0.0
var _devour_target: DevourCorpse
var _devour_progress := 0.0

@onready var hurtbox: Area2D = $Hurtbox
@onready var weapons: Node2D = $Weapons


func _ready() -> void:
	add_to_group("player")
	hp = stat("max_hp")


func stat(stat_name: String) -> float:
	var add := 0.0
	var mult := 1.0
	for mod in modifiers:
		if mod.stat == stat_name:
			add += mod.get("add", 0.0)
			mult += mod.get("mult", 0.0)
	var value: float = (base[stat_name] + add) * mult
	if stat_name == "max_hp":
		value = maxf(MIN_MAX_HP, value)
	return value


func _physics_process(delta: float) -> void:
	_update_devour(delta)
	# Channeling Devour roots you in place: that is its risk.
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = Vector2.ZERO if is_devouring() else input * stat("move_speed")
	move_and_slide()

	_invuln = maxf(0.0, _invuln - delta)
	if _invuln == 0.0:
		for area in hurtbox.get_overlapping_areas():
			if area is Enemy:
				take_damage((area as Enemy).atk)
				break
	queue_redraw()


func take_damage(atk: float) -> void:
	if hp <= 0.0:
		return
	hp -= Game.damage(atk, stat("defense"))
	_invuln = HIT_INVULN
	if hp <= 0.0:
		hp = 0.0
		set_physics_process(false)
		died.emit()


# Quadratic curve: early levels come fast, later ones take much longer.
func xp_to_next() -> int:
	return 5 + level * level


func gain_xp(amount: int) -> void:
	if hp <= 0.0:
		return
	xp += amount
	var gained := false
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		pending_level_ups += 1
		gained = true
	if gained:
		leveled_up.emit()


## Upgrades from `pool` that aren't at max level yet.
func available_upgrades(pool: Array) -> Array:
	return pool.filter(func(upgrade: Resource) -> bool:
		return upgrade_levels.get(upgrade, 0) < upgrade.max_level)


func upgrade_level(upgrade: Resource) -> int:
	return upgrade_levels.get(upgrade, 0)


func apply_upgrade(upgrade: Resource) -> void:
	var new_level := upgrade_level(upgrade) + 1
	upgrade_levels[upgrade] = new_level
	if upgrade is WeaponData:
		_level_weapon(upgrade, new_level)
	elif upgrade is ItemData:
		var item := upgrade as ItemData
		var old_max := stat("max_hp")
		if item.stat != "":
			modifiers.append({"stat": item.stat, "add": item.add_per_level, "mult": item.mult_per_level})
		hp += maxf(0.0, stat("max_hp") - old_max)
		hp = minf(stat("max_hp"), hp + stat("max_hp") * item.heal_fraction)
	_check_evolutions()


func _level_weapon(data: WeaponData, new_level: int) -> void:
	for weapon: Weapon in weapons.get_children():
		if weapon.data == data:
			weapon.set_level(new_level)
			return
	var weapon := data.scene.instantiate() as Weapon
	weapon.data = data
	weapon.player = self
	weapon.level = new_level
	weapons.add_child(weapon)


func is_devouring() -> bool:
	return _devour_target != null


func devour_progress() -> float:
	return _devour_progress / DEVOUR_TIME


## Total essences taken this run; the endings will read this.
func devour_count() -> int:
	var total := 0
	for count: int in essences.values():
		total += count
	return total


func devour(essence: EssenceData) -> void:
	essences[essence] = essences.get(essence, 0) + 1
	modifiers.append({"stat": essence.stat, "add": essence.add, "mult": essence.mult})
	modifiers.append({"stat": "max_hp", "add": -essence.max_hp_cost})
	hp = minf(hp, stat("max_hp"))
	devoured.emit(essence)
	_check_evolutions()


func _update_devour(delta: float) -> void:
	if not Input.is_action_pressed("devour"):
		_devour_target = null
		_devour_progress = 0.0
		return
	if not is_instance_valid(_devour_target):
		_devour_target = _nearest_corpse()
		_devour_progress = 0.0
		if _devour_target == null:
			return
	_devour_progress += delta
	if _devour_progress >= DEVOUR_TIME:
		devour(_devour_target.essence)
		_devour_target.queue_free()
		_devour_target = null
		_devour_progress = 0.0


func _nearest_corpse() -> DevourCorpse:
	var best: DevourCorpse = null
	var best_distance := DEVOUR_RANGE
	for node in get_tree().get_nodes_in_group("corpses"):
		var corpse := node as DevourCorpse
		var distance := global_position.distance_to(corpse.global_position)
		if distance <= best_distance and not corpse.is_queued_for_deletion():
			best = corpse
			best_distance = distance
	return best


func _check_evolutions() -> void:
	for weapon: Weapon in weapons.get_children():
		var data := weapon.data
		if weapon.evolved or data.evolve_with == null:
			continue
		if weapon.level >= data.max_level and essences.get(data.evolve_with, 0) >= data.evolve_count:
			weapon.evolve()
			weapon_evolved.emit(weapon)


func _draw() -> void:
	var body := BODY_COLOR if _invuln == 0.0 else Color(1, 0.4, 0.4)
	draw_circle(Vector2.ZERO, BODY_RADIUS, body)
	if is_devouring():
		var start := -PI / 2.0
		draw_arc(Vector2.ZERO, 22.0, start, start + TAU * devour_progress(), 32, DEVOUR_COLOR, 4.0)
