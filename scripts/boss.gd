class_name Boss
extends Enemy
## The Demon King: a one-on-one duel (main.gd clears the swarm when he
## arrives). He chases slowly and alternates two telegraphed attacks:
## - Slam: marks the ground under you, then hits it for double damage
##   (the terminal game's "charges every 5 turns").
## - Dark volley: stops, gathers power, then fires a ring of orbs to dodge.
## He also summons a few minions now and then (XP and a little chaos).
## He fights in three phases (PHASE_AT): at two thirds of his HP he rises in
## fury (faster, bigger slams, denser volleys, and charges); at one third he
## wears your hunger: a mirror attack drawn from the essence you Devoured
## most, and his strength grows with every Devour you took. His slams
## crumble the arena's pillars, and pillars (and any obstacle) stop orbs.
## The mini-bosses (Days 10 and 15) are Bosses too, set up with configure():
## their own attack cycle, with or without summons and an enrage at half HP. Two more
## attacks are theirs:
## - Charge: a line marks the path, then it rushes along it.
## - Blink: it fades, reappears beside you, and fires a ring of orbs.

signal slam_started
signal enraged
## The Demon King entered phase 1 (fury) or 2 (the mirror).
signal phase_changed(phase: int)
## A slam landed at `at`, `radius` wide (the arena's pillars crumble).
signal slammed(at: Vector2, radius: float)
## Asks the run to spawn `count` minions around `at`; true in phase 2.
signal summon(at: Vector2, count: int, phase_two: bool)

enum Attack { SLAM, VOLLEY, CHARGE, BLINK, MIRROR }

const ORB_SCENE := preload("res://scenes/boss_orb.tscn")
const FIRST_ATTACK := 4.0
const ATTACK_GAP := [3.5, 2.9, 2.6]  # seconds between attacks, by phase
const SLAM_WINDUP := 2.25  # 1.5 felt too fast in playtesting
const SLAM_RADIUS := [150.0, 185.0, 200.0]
const SLAM_DAMAGE_MULT := 1.6  # 2.0 felt too punishing in playtesting
const SLAM_FLASH := 0.25
const VOLLEY_WINDUP := [0.9, 0.7, 0.65]
const VOLLEY_ORBS := [12, 14, 16]
const VOLLEY_WAVES := [1, 2, 2]  # later phases fire a second, offset ring
const VOLLEY_WAVE_GAP := 0.35
const ORB_DAMAGE_MULT := 0.6
const SUMMON_INTERVAL := [12.0, 9.0, 9.0]
const SUMMON_COUNT := 4
const ENRAGE_AT := 0.5  # fraction of max HP (mini-bosses)
const PHASE_AT := [0.66, 0.33]  # the Demon King's phases begin below these
## Phase 3: his attack grows by this much per essence you Devoured, up to the cap.
const MIRROR_PER_DEVOUR := 0.03
const MIRROR_CAP := 0.45
const MIRROR_SHIELD := 0.15  # of max HP, when he mirrors a Warden
const PILLAR_COLOR := Color(0.55, 0.5, 0.55)
const ENRAGED_SPEED_MULT := 1.35
const TELEGRAPH_COLOR := Color(1, 0.2, 0.2)
const VOLLEY_COLOR := Color(0.75, 0.35, 1.0)
const OUTLINE_COLOR := Color(0.95, 0.8, 1.0)
const CHARGE_WINDUP := 0.9
const CHARGE_TIME := 0.55
const CHARGE_SPEED := 560.0
const CHARGE_LENGTH := CHARGE_SPEED * CHARGE_TIME
const BLINK_FADE := 0.35
const BLINK_DISTANCE := 170.0

## Slam target and remaining wind-up; read by tools/balance_sim.gd's bot too.
var slam_at := Vector2.ZERO
var slam_radius: float = SLAM_RADIUS[0]
var windup := 0.0
var phase := 0  # 0 = normal, 1 = enraged (or fury), 2 = the mirror
## The Demon King's three phases; mini-bosses only enrage.
var king := false
## The essence the Demon King mirrors in phase 2 (null: none Devoured).
var mirror: EssenceData
var _devours := 0

var _next_attack := FIRST_ATTACK
var _next_summon: float = SUMMON_INTERVAL[0]
## The attack cycle, in order; mini-bosses get their own via configure().
var attacks: Array = [Attack.SLAM, Attack.VOLLEY]
var summons := true
var can_enrage := true
var _attack_index := 0
var _charge_windup := 0.0
var _charge_time := 0.0
var _charge_dir := Vector2.ZERO
var _blink := 0.0
var _volley_windup := 0.0
var _flash := 0.0
var _telegraph: Node2D


## Makes this the Demon King, mirroring `player`'s most-Devoured essence.
func crown(player: Player) -> void:
	king = true
	_devours = player.devour_count()
	var most := 0
	for essence: EssenceData in player.essences:
		if int(player.essences[essence]) > most:
			most = player.essences[essence]
			mirror = essence


## Sets a mini-boss's attack cycle; call before add_child().
func configure(attack_cycle: Array, with_summons: bool, with_enrage: bool) -> void:
	attacks = attack_cycle
	summons = with_summons
	can_enrage = with_enrage


func _ready() -> void:
	super()
	# Drawn on its own top-level node: stays put while the boss moves, sits
	# under the enemies, and ignores the boss's hit flash.
	_telegraph = Node2D.new()
	_telegraph.top_level = true
	_telegraph.z_index = -1
	_telegraph.draw.connect(_draw_telegraph)
	add_child(_telegraph)


func _physics_process(delta: float) -> void:
	# He plants his feet while gathering a volley or a charge, and moves on
	# his own during a charge or a blink.
	if _charge_time > 0.0:
		_charge_time -= delta
		position += _charge_dir * CHARGE_SPEED * delta
		position = Obstacles.push_out(position, radius * 0.8)
	elif _volley_windup <= 0.0 and _charge_windup <= 0.0 and _blink <= 0.0:
		super(delta)
	_update_phase()
	_update_slam(delta)
	_update_volley(delta)
	_update_charge(delta)
	_update_blink(delta)
	if windup <= 0.0 and _volley_windup <= 0.0 and _charge_windup <= 0.0 and _charge_time <= 0.0 and _blink <= 0.0:
		_next_attack -= delta
		if _next_attack <= 0.0 and is_instance_valid(target):
			_start_attack()
	_next_summon -= delta
	if summons and _next_summon <= 0.0:
		_next_summon = SUMMON_INTERVAL[phase]
		summon.emit(global_position, SUMMON_COUNT, phase == 1)
	_flash = maxf(0.0, _flash - delta)
	_telegraph.queue_redraw()


func _update_phase() -> void:
	if king:
		if phase < 2 and hp <= max_hp * PHASE_AT[phase]:
			_enter_phase(phase + 1)
		return
	if can_enrage and phase == 0 and hp <= max_hp * ENRAGE_AT:
		phase = 1
		slam_radius = SLAM_RADIUS[1]
		Game.shake(0.6)
		Game.sfx("boss_warn", 0.0)
		enraged.emit()


func _enter_phase(next: int) -> void:
	phase = next
	slam_radius = SLAM_RADIUS[phase]
	Game.shake(0.8)
	Game.sfx("toll", 0.0)
	Game.shockwave(global_position, TELEGRAPH_COLOR if phase == 1 else VOLLEY_COLOR, 280.0, 0.8)
	if phase == 1:
		attacks.append(Attack.CHARGE)
		enraged.emit()
	else:
		attacks.append(Attack.MIRROR)
		atk *= 1.0 + minf(MIRROR_PER_DEVOUR * _devours, MIRROR_CAP)
	phase_changed.emit(phase)


func move_speed() -> float:
	return data.move_speed * (ENRAGED_SPEED_MULT if phase >= 1 else 1.0)


func _start_attack() -> void:
	_next_attack = ATTACK_GAP[phase]
	var kind: Attack = attacks[_attack_index % attacks.size()]
	_attack_index += 1
	match kind:
		Attack.SLAM:
			windup = SLAM_WINDUP
			slam_at = target.global_position
			Game.sfx("boss_warn", 0.0)
			slam_started.emit()
		Attack.VOLLEY:
			_volley_windup = VOLLEY_WINDUP[phase]
		Attack.CHARGE:
			_charge_windup = CHARGE_WINDUP
			_charge_dir = global_position.direction_to(target.global_position)
			Game.sfx("warn_charge", 0.0)
		Attack.BLINK:
			_blink = BLINK_FADE * 2.0
			Game.sfx("devour", 0.0, 1.4)
			Game.sfx("warn_hex", 0.0, 0.6)
		Attack.MIRROR:
			_mirror_attack()


# Phase 2: he turns your favorite essence against you.
func _mirror_attack() -> void:
	var kind := mirror.resource_path.get_file().get_basename().trim_suffix("_essence") if mirror else ""
	Game.sfx("devour", 0.0, 0.7)
	match kind:
		"vexclaw":
			_charge_windup = CHARGE_WINDUP * 0.7
			_charge_dir = global_position.direction_to(target.global_position)
			Game.sfx("warn_charge", 0.0)
		"hexeye":
			for i in 5:
				var bolt := BOLT_SCENE.instantiate() as HexBolt
				bolt.setup(global_position.direction_to(target.global_position).rotated((i - 2) * 0.22), atk * 0.5)
				bolt.position = global_position
				get_parent().get_parent().add_child(bolt)
			Game.sfx("warn_hex", 0.0, 0.8)
		"plaguewing":
			for i in 4:
				var glob := GLOB_SCENE.instantiate() as PlagueGlob
				glob.setup(target.global_position + Vector2.from_angle(TAU * i / 4.0) * 70.0, atk * 0.5)
				glob.position = global_position
				get_parent().get_parent().add_child(glob)
		"warden":
			shield_hp = max_hp * MIRROR_SHIELD
			queue_redraw()
		"dreadling", "acolyte":
			summon.emit(global_position, SUMMON_COUNT * 2, kind == "acolyte")
		_:
			_blink = BLINK_FADE * 2.0  # Burrower, or nothing Devoured: he vanishes and reappears


func _update_charge(delta: float) -> void:
	if _charge_windup <= 0.0:
		return
	_charge_windup -= delta
	if _charge_windup <= 0.0:
		_charge_time = CHARGE_TIME
		Game.sfx("boss_slam")
		Game.shake(0.3)


# Fade out, reappear beside the hero, fade in, then a ring of orbs.
func _update_blink(delta: float) -> void:
	if _blink <= 0.0:
		return
	var before := _blink
	_blink -= delta
	if before > BLINK_FADE and _blink <= BLINK_FADE and is_instance_valid(target):
		position = target.global_position + Vector2.from_angle(randf() * TAU) * BLINK_DISTANCE
		Game.fx("smoke", global_position, 3.0, Color(0.7, 0.9, 1.0))
	modulate.a = clampf(absf(_blink - BLINK_FADE) / BLINK_FADE, 0.15, 1.0)
	if _blink <= 0.0:
		modulate.a = 1.0
		_volley_windup = VOLLEY_WINDUP[phase]


func _update_slam(delta: float) -> void:
	if windup <= 0.0:
		return
	windup -= delta
	if windup > 0.0:
		return
	_flash = SLAM_FLASH
	Game.sfx("boss_slam")
	Game.rumble(0.5, 0.9, 0.35)
	Game.shake(0.7)
	var player := target as Player
	if player and player.global_position.distance_to(slam_at) <= slam_radius:
		player.take_damage(atk * SLAM_DAMAGE_MULT, true)
	slammed.emit(slam_at, slam_radius)


func _update_volley(delta: float) -> void:
	if _volley_windup <= 0.0:
		return
	_volley_windup -= delta
	if _volley_windup > 0.0:
		return
	for wave in VOLLEY_WAVES[phase]:
		if wave > 0:
			await get_tree().create_timer(VOLLEY_WAVE_GAP, false).timeout
			if not is_inside_tree():
				return
		_fire_ring(VOLLEY_ORBS[phase], wave * 0.5)


func _fire_ring(count: int, offset: float) -> void:
	Game.sfx("boss_volley", 0.0)
	var start := randf() * TAU
	for i in count:
		var orb := ORB_SCENE.instantiate() as BossOrb
		orb.setup(Vector2.RIGHT.rotated(start + TAU * (i + offset) / count), atk * ORB_DAMAGE_MULT)
		orb.position = global_position
		get_parent().get_parent().add_child(orb)


func _die() -> void:
	Game.fx("explosion", global_position, 5.0)
	Game.burst(global_position, Color(1, 0.35, 0.3), 60, 320.0)
	Game.shake(1.0)
	super()


func _draw() -> void:
	super()
	# Placeholder only: the outline keeps the circle readable on his red telegraph.
	if data.sprite_frames == null:
		draw_arc(Vector2.ZERO, radius + 2.0, 0.0, TAU, 48, OUTLINE_COLOR, 3.0)


func _draw_telegraph() -> void:
	if windup > 0.0:
		var t := 1.0 - windup / SLAM_WINDUP
		_telegraph.draw_circle(slam_at, slam_radius, Color(TELEGRAPH_COLOR, 0.1 + 0.2 * t))
		_telegraph.draw_arc(slam_at, slam_radius * t, 0.0, TAU, 64, Color(TELEGRAPH_COLOR, 0.8), 3.0)
		_telegraph.draw_arc(slam_at, slam_radius, 0.0, TAU, 64, Color(TELEGRAPH_COLOR, 0.9), 2.0)
	elif _flash > 0.0:
		_telegraph.draw_circle(slam_at, slam_radius, Color(1, 0.5, 0.4, _flash / SLAM_FLASH * 0.6))
	if _charge_windup > 0.0:
		# The path of the coming charge, brightening.
		var t := 1.0 - _charge_windup / CHARGE_WINDUP
		var end := global_position + _charge_dir * CHARGE_LENGTH
		_telegraph.draw_line(global_position, end, Color(TELEGRAPH_COLOR, 0.15 + 0.3 * t), radius * 2.0)
		_telegraph.draw_line(global_position, end, Color(TELEGRAPH_COLOR, 0.8), 2.0)
	if _volley_windup > 0.0:
		# Dark power gathering around him: a shrinking purple ring.
		var t: float = 1.0 - _volley_windup / VOLLEY_WINDUP[phase]
		_telegraph.draw_circle(global_position, radius * 2.2, Color(VOLLEY_COLOR, 0.15 + 0.2 * t))
		_telegraph.draw_arc(global_position, radius * (3.0 - 1.6 * t), 0.0, TAU, 48, Color(VOLLEY_COLOR, 0.9), 3.0)


## Where a charge is about to go, while it winds up; else zero.
func charge_warning() -> Vector2:
	return _charge_dir if _charge_windup > 0.0 else Vector2.ZERO
