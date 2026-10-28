class_name Player
extends CharacterBody2D
## The Devourer. `base` holds the only true stats; items, Devour essences and
## buffs are entries in `modifiers`, read through stat(). Never write to
## `base` for a temporary effect (the old Defend bug came from doing that).

signal died
## Every hit taken (the style meter drops on it).
signal hurt
signal leveled_up
## For the HUD: it listens instead of reading the player every frame.
signal hp_changed(hp: float, max_hp: float)
signal stats_changed
signal xp_changed(xp: int, needed: int, level: int)
signal flask_changed(charges: int, max_charges: int)
signal devoured(essence: EssenceData)
signal weapon_evolved(weapon: Weapon)
## Two essences resonated (see Resonances): its name and what it grants.
signal resonated(name: String, description: String)

const BODY_COLOR := Color(0.9, 0.82, 0.55)
const BODY_RADIUS := 12.0
const HIT_INVULN := 0.5
const MIN_MAX_HP := 10.0
## Holding Devour this long next to a corpse takes its essence.
const DEVOUR_TIME := 1.0
const DEVOUR_RANGE := 40.0
## Fraction of (the new) max HP healed by each successful Devour.
const DEVOUR_HEAL := 0.25
const DEVOUR_COLOR := Color(0.8, 0.45, 1.0)
## Goddess's Tears: a flask with a few charges (Q to drink), refilled at
## every goddess shrine. Drinking slows you for a moment, like Estus.
const FLASK_START_CHARGES := 3
const FLASK_START_HEAL := 0.35  # fraction of max HP per sip
const DRINK_TIME := 0.6
const DRINK_SLOW := 0.35  # move speed multiplier while drinking
const TEARS_COLOR := Color(1, 0.9, 0.55)
const STEP_TIME := 0.3
## Weapons carried at once (of five), so each build has to choose.
const MAX_WEAPONS := 4  # seconds between footsteps at base speed

var base := {
	"max_hp": 120.0,
	"might": 1.0,  # multiplies all weapon damage
	"defense": 10.0,
	"move_speed": 170.0,
	"pickup_radius": 120.0,
	"haste": 1.0,  # weapon attack speed multiplier
	"regen": 0.0,  # HP per second
	"devour_speed": 1.0,  # Hunger: Devour channels faster and heals more
}
## Each entry: {"stat": "defense", "add": 10.0, "mult": 0.0}
var modifiers: Array[Dictionary] = []
var hp: float:
	set(value):
		hp = value
		hp_changed.emit(hp, stat("max_hp"))
var xp := 0
var level := 1
var flask_max := FLASK_START_CHARGES
var flask_charges := FLASK_START_CHARGES
var flask_heal := FLASK_START_HEAL
var _drinking := 0.0
## Level-ups earned but not yet chosen on the level-up screen.
var pending_level_ups := 0
## WeaponData / ItemData -> how many times it has been picked.
var upgrade_levels := {}
## WeaponData -> the branch it took at Lv 3 ("a" or "b"; Branches).
var branches := {}
## EssenceData -> how many have been Devoured this run.
var essences := {}
## Resonances awakened this run, by name.
var resonances: Array[String] = []

var _invuln := 0.0
var _facing := "down"
var _devour_target: DevourCorpse
var _devour_progress := 0.0
var _step := 0.0
## The last direction you moved: where facing weapons (the Chains) strike.
var aim := Vector2.DOWN

@onready var hurtbox: Area2D = $Hurtbox
@onready var weapons: Node2D = $Weapons
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


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
	_update_flask(delta)
	# Channeling Devour roots you in place: that is its risk.
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input != Vector2.ZERO:
		aim = input.normalized()
	var speed := stat("move_speed") * (DRINK_SLOW if _drinking > 0.0 else 1.0)
	velocity = Vector2.ZERO if is_devouring() else input * speed
	move_and_slide()
	_animate(input)

	hp = minf(stat("max_hp"), hp + stat("regen") * delta)
	_invuln = maxf(0.0, _invuln - delta)
	if _invuln == 0.0:
		for area in hurtbox.get_overlapping_areas():
			if area is Enemy:
				take_damage((area as Enemy).atk)
				(area as Enemy).on_hit_player()
				break
	queue_redraw()


## Ignores hits for `seconds` (benchmarks and tests hold it up).
func set_invulnerable(seconds: float) -> void:
	_invuln = seconds


## Respects the brief invulnerability after a hit unless `ignore_invuln`
## (the boss slam, a big telegraphed attack, always lands).
func take_damage(atk: float, ignore_invuln := false) -> void:
	if hp <= 0.0 or (_invuln > 0.0 and not ignore_invuln):
		return
	hp -= Game.damage(atk, stat("defense"))
	_invuln = HIT_INVULN
	hurt.emit()
	Game.rumble(0.25, 0.45, 0.15)
	Game.sfx("player_hurt")
	Game.shake(0.35)
	Game.hit_stop(0.06)
	sprite.modulate = Color(1, 0.35, 0.35)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.25)
	if hp <= 0.0:
		hp = 0.0
		set_physics_process(false)
		died.emit()


# Quadratic curve: early levels come fast, later ones take much longer.
# (Full strength again since journeys became 20 one-minute days.)
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
	xp_changed.emit(xp, xp_to_next(), level)
	if gained:
		leveled_up.emit()


## Tells the HUD about every stat at once (after loading, or big changes).
func announce() -> void:
	stats_changed.emit()
	hp_changed.emit(hp, stat("max_hp"))
	xp_changed.emit(xp, xp_to_next(), level)
	flask_changed.emit(flask_charges, flask_max)


func is_drinking() -> bool:
	return _drinking > 0.0


## Refill (at a shrine) or upgrade the flask.
func refill_flask() -> void:
	flask_charges = flask_max
	flask_changed.emit(flask_charges, flask_max)


func _update_flask(delta: float) -> void:
	if _drinking > 0.0:
		_drinking -= delta
		if _drinking <= 0.0:
			var healed := minf(stat("max_hp"), hp + stat("max_hp") * flask_heal) - hp
			hp += healed
			Game.sfx("flask_heal", 0.0)
			Game.fx("spark", global_position, 2.5, TEARS_COLOR)
			Game.float_text(global_position, tr("+%d HP") % roundi(healed), TEARS_COLOR)
		return
	if Input.is_action_just_pressed("flask") and flask_charges > 0 and hp > 0.0:
		flask_charges -= 1
		_drinking = DRINK_TIME
		Game.sfx("flask", 0.05)
		flask_changed.emit(flask_charges, flask_max)


## Upgrades from `pool` that aren't at max level yet. A new weapon is only
## offered while you carry fewer than MAX_WEAPONS; a weapon at Lv 3 offers
## both its branches, then the one it took until Lv 5.
func available_upgrades(pool: Array) -> Array:
	var weapons_held := upgrade_levels.keys().filter(func(u: Resource) -> bool: return u is WeaponData).size()
	var offers := []
	for upgrade: Resource in pool:
		var level: int = upgrade_levels.get(upgrade, 0)
		if upgrade is WeaponData and level == 0 and weapons_held >= MAX_WEAPONS:
			continue
		if level < upgrade.max_level:
			offers.append(upgrade)
		elif upgrade is WeaponData and Branches.has(upgrade) and level < Branches.MAX_LEVEL:
			if branches.has(upgrade):
				offers.append(Branches.get_branch(upgrade, branches[upgrade]))
			else:
				offers.append_array(Branches.of(upgrade))
	return offers


func upgrade_level(upgrade: Resource) -> int:
	if upgrade is BranchData:
		return upgrade_levels.get((upgrade as BranchData).weapon, 0)
	return upgrade_levels.get(upgrade, 0)


func apply_upgrade(upgrade: Resource) -> void:
	if upgrade is BranchData:
		_take_branch(upgrade)
		return
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
	stats_changed.emit()


func _take_branch(branch: BranchData) -> void:
	var new_level := upgrade_level(branch) + 1
	upgrade_levels[branch.weapon] = new_level
	branches[branch.weapon] = branch.id
	for weapon: Weapon in weapons.get_children():
		if weapon.data == branch.weapon:
			weapon.branch = branch.id
			weapon.set_level(new_level)
	stats_changed.emit()


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


## A modifier that removes itself after `duration` seconds of gameplay.
func add_timed_modifier(mod: Dictionary, duration: float) -> void:
	modifiers.append(mod)
	stats_changed.emit()
	await get_tree().create_timer(duration, false).timeout
	modifiers.erase(mod)
	stats_changed.emit()


func is_devouring() -> bool:
	return _devour_target != null


func devour_progress() -> float:
	return _devour_progress / _devour_time()


func _devour_time() -> float:
	return DEVOUR_TIME / stat("devour_speed")


# Two essences held together awaken a Resonance (scripts/data/resonances.gd).
func _check_resonances() -> void:
	for entry: Array in Resonances.TABLE:
		if entry[0] in resonances:
			continue
		var a := essences.get(load(entry[1]), 0) as int
		var b := essences.get(load(entry[2]), 0) as int
		if a >= Resonances.NEEDED and b >= Resonances.NEEDED:
			resonances.append(entry[0])
			for mod: Dictionary in entry[4]:
				modifiers.append(mod.duplicate())
			resonated.emit(entry[0], entry[3])


## Total essences taken this run; the endings will read this.
func devour_count() -> int:
	var total := 0
	for count: int in essences.values():
		total += count
	return total


## An essence's stat boost and max-HP cost, with no fanfare (also used to
## rebuild a saved journey).
func add_essence(essence: EssenceData) -> void:
	essences[essence] = essences.get(essence, 0) + 1
	modifiers.append({"stat": essence.stat, "add": essence.add, "mult": essence.mult})
	modifiers.append({"stat": "max_hp", "add": -essence.max_hp_cost})
	hp = minf(hp, stat("max_hp"))
	_check_evolutions()
	_check_resonances()
	stats_changed.emit()


## Back from death (a goddess revive): some HP and a moment of safety.
func revive(hp_fraction: float, invulnerable_for: float) -> void:
	hp = stat("max_hp") * hp_fraction
	_invuln = invulnerable_for
	set_physics_process(true)


func devour(essence: EssenceData) -> void:
	add_essence(essence)
	# Feeding restores you, which pays for standing still to channel.
	var heal_share := DEVOUR_HEAL * (1.0 + (stat("devour_speed") - 1.0) / 3.0)  # Hunger: +10% per level
	var healed := minf(stat("max_hp"), hp + stat("max_hp") * heal_share) - hp
	hp += healed
	Game.fx("spark", global_position, 2.5, Color(0.5, 1, 0.5))
	if healed >= 1.0:
		Game.float_text(global_position, tr("+%d HP") % roundi(healed), Color(0.5, 1, 0.5))
	Game.sfx("devour")
	Game.shake(0.3)
	devoured.emit(essence)


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
	if _devour_progress >= _devour_time():
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
		if weapon.evolved or (data.evolve_with == null and data.evolve_with_item == null):
			continue
		if weapon.level < data.max_level:
			continue
		if data.evolve_with and essences.get(data.evolve_with, 0) < data.evolve_count:
			continue
		if data.evolve_with_item and upgrade_level(data.evolve_with_item) < data.evolve_with_item.max_level:
			continue
		weapon.evolve()
		weapon_evolved.emit(weapon)


func _animate(input: Vector2) -> void:
	if input != Vector2.ZERO:
		_facing = Game.facing(input)
	# Blink while invulnerable after a hit.
	sprite.visible = _invuln == 0.0 or fmod(_invuln, 0.1) > 0.05
	sprite.play(("run_" if velocity != Vector2.ZERO else "idle_") + _facing)
	# Footsteps, faster as you get faster.
	if velocity == Vector2.ZERO:
		_step = 0.0
		return
	_step -= get_physics_process_delta_time() * velocity.length() / 170.0
	if _step <= 0.0:
		_step = STEP_TIME
		Game.sfx(Game.footstep, 0.1)


func _draw() -> void:
	if sprite.sprite_frames == null:
		var body := BODY_COLOR if _invuln == 0.0 else Color(1, 0.4, 0.4)
		draw_circle(Vector2.ZERO, BODY_RADIUS, body)
	if is_devouring():
		var start := -PI / 2.0
		draw_arc(Vector2.ZERO, 22.0, start, start + TAU * devour_progress(), 32, DEVOUR_COLOR, 4.0)
