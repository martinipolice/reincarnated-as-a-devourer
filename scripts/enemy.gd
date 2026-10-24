class_name Enemy
extends Area2D
## A monster. Stats, art and behavior come from an EnemyData resource, so new
## monsters need a .tres file, not new code. Behaviors (EnemyData.behavior):
## - "chase":   walk straight at the player (the Demon King moves this way).
## - "swarm":   approach from a personal angle so the pack surrounds you.
## - "pounce":  close in, crouch with an aim line, then dash; recover after.
## - "spitter": creep in slowly, pausing to lob globs that leave puddles.
## Movement is steered (smooth acceleration) and Crowd keeps a little space
## between monsters. Elites are tougher, gold-ringed versions that leave a
## Devour corpse. From Day 3 an elite can carry a trait (TRAITS), named over
## its head and colored in its ring. Weapons can set enemies burning.

## For health bars that follow one enemy (the boss bar).
signal damaged(hp: float, max_hp: float)

enum State { MOVE, WINDUP, DASH, RECOVER }

const KNOCKBACK_DECAY := 900.0
const ACCEL := 900.0  # px/s^2 toward the desired velocity
const SEPARATION := 140.0  # px/s of push when fully overlapping a neighbor
const ELITE_HP_MULT := 4.0
const ELITE_ATK_MULT := 1.5
const ELITE_SIZE_MULT := 1.5
const ELITE_KNOCKBACK_MULT := 0.5
const ELITE_RING := Color(1, 0.85, 0.3)
const ELITE_TINT := Color(1.35, 1.15, 0.7)
const HIT_FLASH := Color(2.5, 2.5, 2.5)
## Elite traits: id -> [name, ring color].
## - swift: much faster. - armored: takes half damage.
## - splitting: bursts into three of its kind. - vampiric: heals on every hit.
const TRAITS := {
	"swift": ["Swift", Color(0.45, 0.85, 1.0)],
	"armored": ["Armored", Color(0.8, 0.85, 0.95)],
	"splitting": ["Splitting", Color(0.55, 1.0, 0.4)],
	"vampiric": ["Vampiric", Color(1.0, 0.25, 0.4)],
}
const SWIFT_SPEED := 1.3
const ARMORED_TAKEN := 0.5
const VAMPIRIC_HEAL := 0.2  # of max HP per hit landed
const BURN_TICK := 0.5
const BURN_COLOR := Color(1.0, 0.45, 0.1)

# swarm
const FLANK_ANGLE := 0.6  # max radians off the direct line
const FLANK_FADE := 220.0  # the angle fades to 0 within this distance
# pounce
const POUNCE_RANGE := 170.0
const POUNCE_WINDUP := 0.6
const POUNCE_DURATION := 0.35
const POUNCE_SPEED_MULT := 2.6
const POUNCE_RECOVER := 0.6
const POUNCE_COOLDOWN := 3.2
const POUNCE_LEAD := 0.2  # seconds of player movement to aim ahead
const AIM_COLOR := Color(1, 0.4, 0.3)
# spitter
const SPIT_RANGE := 300.0  # spits when this close
const SPIT_CREEP := 0.55  # speed fraction while in spitting range
const SPIT_WINDUP := 0.4
const SPIT_COOLDOWN := 5.0
const SPIT_TINT := Color(0.7, 1.6, 0.6)
const GLOB_SCENE := preload("res://scenes/plague_glob.tscn")

var data: EnemyData
var target: Node2D
var elite := false
var affix := ""
var hp: float
var max_hp: float
var atk: float
var radius: float
var state := State.MOVE

var _velocity := Vector2.ZERO
var _knockback := Vector2.ZERO
var _state_time := 0.0
var _cooldown := 0.0
var _flank := 0.0  # this swarm member's approach angle
var _dash_target := Vector2.ZERO
var _directional := false
var _next_number := 0
var _burn_dps := 0.0
var _burn_time := 0.0
var _burn_tick := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


## Call before add_child(). `toughness` scales HP fully and damage at 70%
## of that rate (main.gd raises it as the days pass).
func setup(enemy_data: EnemyData, chase_target: Node2D, is_elite := false, toughness := 1.0, elite_trait := "") -> void:
	data = enemy_data
	target = chase_target
	elite = is_elite
	affix = elite_trait if is_elite else ""
	max_hp = data.max_hp * (ELITE_HP_MULT if elite else 1.0) * toughness
	hp = max_hp
	atk = data.atk * (ELITE_ATK_MULT if elite else 1.0) * (1.0 + (toughness - 1.0) * 0.7) * Game.enemy_atk_mult
	radius = data.radius * (ELITE_SIZE_MULT if elite else 1.0)


func _ready() -> void:
	add_to_group("enemies")
	var shape := CircleShape2D.new()
	shape.radius = radius
	$CollisionShape2D.shape = shape
	_flank = randf_range(-FLANK_ANGLE, FLANK_ANGLE)
	_cooldown = randf_range(0.5, POUNCE_COOLDOWN)  # don't all pounce in sync
	if data.sprite_frames:
		sprite.sprite_frames = data.sprite_frames
		sprite.scale = Vector2.ONE * data.sprite_scale * radius / data.radius
		_directional = data.sprite_frames.has_animation("run_down")
		sprite.play("run_down" if _directional else "run")
		if elite:
			sprite.self_modulate = ELITE_TINT
	if affix != "":
		var tag := Label.new()
		tag.text = "%s %s" % [TRAITS[affix][0], data.display_name]
		tag.add_theme_font_size_override("font_size", 20)
		tag.add_theme_color_override("font_color", TRAITS[affix][1])
		tag.add_theme_constant_override("outline_size", 4)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.size = Vector2(200, 24)
		tag.position = Vector2(-100, -radius * 2.4 - 24)
		tag.z_index = 10
		add_child(tag)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	_state_time += delta
	_cooldown -= delta
	var desired: Vector2
	match data.behavior:
		"swarm":
			desired = _swarm()
		"pounce":
			desired = _pounce()
		"spitter":
			desired = _spitter()
		_:
			desired = global_position.direction_to(target.global_position) * move_speed()
	if state != State.DASH and not data.boss:
		desired += Crowd.separation(self) * SEPARATION
	_update_burn(delta)
	if not alive():
		return
	var accel := ACCEL * (4.0 if state == State.DASH else 1.0)
	_velocity = _velocity.move_toward(desired, accel * delta)
	position += (_velocity + _knockback) * delta
	position = Obstacles.push_out(position, radius * 0.8)
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	_animate()


func move_speed() -> float:
	return data.move_speed * (SWIFT_SPEED if affix == "swift" else 1.0)


## Sets it alight: `dps` for `duration` seconds (the stronger burn wins).
func burn(dps: float, duration: float) -> void:
	if not alive():
		return
	if _burn_time <= 0.0:
		_burn_tick = BURN_TICK
	_burn_dps = maxf(_burn_dps, dps)
	_burn_time = maxf(_burn_time, duration)
	queue_redraw()


func _update_burn(delta: float) -> void:
	if _burn_time <= 0.0:
		return
	_burn_time -= delta
	_burn_tick -= delta
	if _burn_tick <= 0.0:
		_burn_tick = BURN_TICK
		take_damage(_burn_dps * BURN_TICK, Vector2.ZERO, "")
	if _burn_time <= 0.0:
		_burn_dps = 0.0
	queue_redraw()


## Called when its touch damaged the player.
func on_hit_player() -> void:
	if affix == "vampiric" and alive():
		hp = minf(max_hp, hp + max_hp * VAMPIRIC_HEAL)
		damaged.emit(hp, max_hp)
		Game.burst(global_position, TRAITS.vampiric[1], 8)


# Four-direction sheets face where they're going; single strips (the boss,
# the Mimic) just flip.
func _animate() -> void:
	if data.sprite_frames == null or _velocity.length() < 5.0:
		return
	if _directional:
		sprite.play("run_" + Game.facing(_velocity))
	else:
		sprite.flip_h = _velocity.x < 0.0


func _set_state(next: State) -> void:
	state = next
	_state_time = 0.0
	queue_redraw()


# Head for a point beside the player, at this member's own angle; the angle
# fades as it closes in, so the pack ends up surrounding the player.
func _swarm() -> Vector2:
	var to_player := target.global_position - global_position
	var fade := clampf(to_player.length() / FLANK_FADE, 0.0, 1.0)
	return to_player.normalized().rotated(_flank * fade) * move_speed()


func _pounce() -> Vector2:
	var to_player := target.global_position - global_position
	match state:
		State.WINDUP:
			if _state_time >= POUNCE_WINDUP:
				_set_state(State.DASH)
			queue_redraw()
			return Vector2.ZERO
		State.DASH:
			if _state_time >= POUNCE_DURATION:
				_set_state(State.RECOVER)
			return global_position.direction_to(_dash_target) * move_speed() * POUNCE_SPEED_MULT
		State.RECOVER:
			if _state_time >= POUNCE_RECOVER:
				_cooldown = POUNCE_COOLDOWN * (0.6 if elite else 1.0)
				_set_state(State.MOVE)
			return Vector2.ZERO
	if _cooldown <= 0.0 and to_player.length() < POUNCE_RANGE:
		# Aim where the player is heading, then commit to it.
		var lead := Vector2.ZERO
		if target is CharacterBody2D:
			lead = (target as CharacterBody2D).velocity * POUNCE_LEAD
		var aim := target.global_position + lead
		_dash_target = global_position + global_position.direction_to(aim) * POUNCE_RANGE * 1.3
		_set_state(State.WINDUP)
		return Vector2.ZERO
	return to_player.normalized() * move_speed()


func _spitter() -> Vector2:
	var to_player := target.global_position - global_position
	var distance := to_player.length()
	if state == State.WINDUP:
		if _state_time >= SPIT_WINDUP:
			_spit()
			_cooldown = SPIT_COOLDOWN * (0.6 if elite else 1.0)
			_set_state(State.MOVE)
		return Vector2.ZERO
	if _cooldown <= 0.0 and distance < SPIT_RANGE:
		_set_state(State.WINDUP)
		return Vector2.ZERO
	# Always creeping closer (slower once in spitting range), so melee builds
	# can still reach it; hanging back made them pile up out of reach.
	var creep := SPIT_CREEP if distance < SPIT_RANGE else 1.0
	return to_player / maxf(distance, 0.01) * move_speed() * creep


func _spit() -> void:
	var glob := GLOB_SCENE.instantiate() as PlagueGlob
	glob.setup(target.global_position, atk * 0.4)
	glob.position = global_position
	get_parent().get_parent().add_child(glob)


func alive() -> bool:
	return hp > 0.0


func take_damage(amount: float, knockback := Vector2.ZERO, hit_sfx := "enemy_hit") -> void:
	if not alive():
		return
	var dealt := Game.damage(amount, data.defense) * (ARMORED_TAKEN if affix == "armored" else 1.0)
	hp -= dealt
	damaged.emit(hp, max_hp)
	# Throttled per enemy, so a swarm under the Blade doesn't drown the screen.
	var now := Time.get_ticks_msec()
	if now >= _next_number and hit_sfx != "":  # burn ticks ("") stay quiet
		_next_number = now + 250
		Game.damage_number(global_position, dealt, Color(1, 0.85, 0.4) if elite or data.boss else Color.WHITE)
	# A dashing pouncer is committed: hits don't knock it off course.
	if state != State.DASH:
		_knockback += knockback * data.knockback_scale * (ELITE_KNOCKBACK_MULT if elite else 1.0)
	# Flash the sprite (or our own drawing), never `modulate`, which would also
	# tint children like the boss telegraph.
	var flash_target: CanvasItem = sprite if data.sprite_frames else self
	var flash_property := "modulate" if data.sprite_frames else "self_modulate"
	flash_target.set(flash_property, HIT_FLASH)
	create_tween().tween_property(flash_target, flash_property, Color.WHITE, 0.1)
	if hit_sfx != "":
		Game.sfx(hit_sfx)
	if not alive():
		_die()


func _die() -> void:
	Game.sfx("elite_die" if elite else "enemy_die")
	Game.fx("smoke", global_position, 2.5 if elite else 1.5)
	Game.burst(global_position, data.color.lightened(0.2), 18 if elite else 8)
	if elite:
		Game.shake(0.25)
	Game.enemy_killed.emit(self)
	queue_free()


func _draw() -> void:
	if data.sprite_frames == null:
		draw_circle(Vector2.ZERO, radius, data.color)
	if elite:
		# Drawn under the sprite: a gold aura on the ground.
		var ring: Color = TRAITS[affix][1] if affix != "" else ELITE_RING
		draw_circle(Vector2(0, radius * 0.6), radius * 0.9, Color(ring, 0.25))
		draw_arc(Vector2(0, radius * 0.6), radius * 0.9, 0.0, TAU, 32, ring, 2.0 if affix == "" else 3.0)
	if _burn_time > 0.0:
		var flicker := 0.25 + 0.1 * sin(Time.get_ticks_msec() / 60.0)
		draw_circle(Vector2(0, -radius * 0.3), radius * 0.75, Color(BURN_COLOR, flicker))
	if state == State.WINDUP:
		if data.behavior == "pounce":
			# The aim line brightens as the pounce is about to fire.
			var t := clampf(_state_time / POUNCE_WINDUP, 0.0, 1.0)
			draw_line(Vector2.ZERO, to_local(_dash_target), Color(AIM_COLOR, 0.5 + 0.5 * t), 3.0 + 2.0 * t)
			draw_circle(Vector2.ZERO, radius + 4.0, Color(AIM_COLOR, 0.25 * t))
		elif data.behavior == "spitter":
			draw_circle(Vector2.ZERO, radius + 6.0, Color(SPIT_TINT, 0.3))
