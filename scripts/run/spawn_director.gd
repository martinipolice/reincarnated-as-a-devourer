class_name SpawnDirector
extends Node
## Everything that puts monsters on the field: the wave rhythm, elites,
## announced events, the spawn table by day, splitting elites, Mimics, the
## mini-bosses and the Demon King himself (main.gd stages their arrival).

## A mini-boss has arrived; main.gd shows its bar and title card.
signal mini_boss_arrived(boss: Boss, data: EnemyData)

const SPAWN_RADIUS := 700.0
const BOSS_SPAWN_DISTANCE := 450.0
const GRACE_PERIOD := 2.0  # seconds before the first spawn
const ELITE_INTERVAL := 30.0
## Waves: spawning builds over WAVE_BUILD of each WAVE_CYCLE seconds from
## WAVE_LOW to WAVE_HIGH times the base rate, then eases to WAVE_LULL.
const WAVE_CYCLE := 24.0
const WAVE_BUILD := 0.7  # fraction of the cycle spent building
const WAVE_LOW := 1.0
const WAVE_HIGH := 1.4
const WAVE_LULL := 0.3
## Share of spawns placed ahead of where the player is running.
const AHEAD_CHANCE := 0.45
const AHEAD_SPREAD := 1.1  # radians either side of the running direction
## Announced events (encirclement, Vexclaw ambush, plague tide).
const EVENT_FROM_DAY := 3
const EVENT_FIRST := 75.0
const EVENT_GAP := Vector2(40.0, 55.0)
const EVENT_WARNING := 1.5
## Enemies get this much tougher each day after the first (HP fully, damage
## at 70%; see Enemy.setup). Day 20 is 1 + 19 * this.
const TOUGHNESS_PER_DAY := 0.2
## How far from a boss its summoned minions appear.
const SUMMON_RING := 80.0
## Elites can carry a trait from this day: some of the time, then always.
const TRAITS_FROM_DAY := 5  # after the goddess's first visit
const TRAIT_CHANCE := 0.6
const TRAITS_ALWAYS_FROM_DAY := 10
const SPLIT_COUNT := 3

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const BOSS_SCENE := preload("res://scenes/boss.tscn")
const DREADLING := preload("res://data/enemies/dreadling.tres")
const VEXCLAW := preload("res://data/enemies/vexclaw.tres")
const PLAGUEWING := preload("res://data/enemies/plaguewing.tres")
const MIMIC := preload("res://data/enemies/mimic.tres")
const DEMON_KING := preload("res://data/enemies/demon_king.tres")
const HEXEYE := preload("res://data/enemies/hexeye.tres")
const WARDEN := preload("res://data/enemies/warden.tres")
## Mid-journey peaks: day -> [enemy, attack cycle, summons?, enrage?]. Each
## arrives MINI_BOSS_DELAY seconds into its day (after that day's shrine).
const MINI_BOSSES := {
	10: [preload("res://data/enemies/ruin_guardian.tres"), [Boss.Attack.CHARGE, Boss.Attack.SLAM], false, true],
	15: [preload("res://data/enemies/hollow_spirit.tres"), [Boss.Attack.BLINK, Boss.Attack.SLAM, Boss.Attack.VOLLEY], true, true],
}
const MINI_BOSS_DELAY := 25.0
## While a mini-boss lives the waves thin out, so the duel stays readable.
const MINI_BOSS_WAVES := 0.5
## The kinds in SPAWN_TABLE's weight columns, in order.
const KINDS := [DREADLING, VEXCLAW, PLAGUEWING, HEXEYE, WARDEN]
## Monsters by day: [before day, normal weights, elite weights]. The original
## allowed 5% Plaguewings from the start, brutal in real time, so early days
## skip them; elites lean stronger so Vexclaw essences are reachable.
const SPAWN_TABLE := [
	[6, [90, 10, 0, 0, 0], [60, 40, 0, 0, 0]],
	[10, [45, 40, 8, 7, 0], [30, 45, 15, 10, 0]],
	[14, [38, 30, 14, 10, 8], [20, 35, 20, 15, 10]],
	[99, [30, 28, 18, 12, 12], [15, 33, 22, 15, 15]],
]

var boss: Boss
var mini_boss: Boss
var _minis_done := []
var _spawn_timer := GRACE_PERIOD
var _elite_timer := ELITE_INTERVAL
var _event_timer := EVENT_FIRST
var _main: Node
var _player: Player
var _enemies: Node2D


func _init(main: Node) -> void:
	_main = main
	_player = main.player
	_enemies = main.enemies


func toughness() -> float:
	return 1.0 + TOUGHNESS_PER_DAY * (_main.day() - 1)


## A short calm before the first spawn (a new or restored journey).
func grace() -> void:
	_spawn_timer = GRACE_PERIOD


## One frame of the horde, until the Demon King arrives: Day 20 is a duel.
func update(delta: float) -> void:
	var day: int = _main.day()
	if day in MINI_BOSSES and not day in _minis_done \
			and _main.elapsed >= (day - 1) * _main.SECONDS_PER_DAY + MINI_BOSS_DELAY:
		_minis_done.append(day)
		_spawn_mini_boss(day)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = maxf(0.45, 1.3 - day * 0.05) / wave_intensity() / (1.4 if _main.covenant == "horde" else 1.0)
		if is_instance_valid(mini_boss):
			_spawn_timer /= MINI_BOSS_WAVES
		# Bigger packs as the days pass: 1 per spawn on Days 1-4, 2 on 5-9, ...
		for i in 1 + day / 5:
			spawn_enemy()
	_elite_timer -= delta
	if _elite_timer <= 0.0:
		_elite_timer = ELITE_INTERVAL
		spawn_enemy(true)
	if day >= EVENT_FROM_DAY:
		_event_timer -= delta
		if _event_timer <= 0.0:
			_event_timer = randf_range(EVENT_GAP.x, EVENT_GAP.y)
			_start_event()


## How hard the current wave is pushing: builds up, then a short breather.
func wave_intensity() -> float:
	var t := fmod(_main.elapsed, WAVE_CYCLE) / WAVE_CYCLE
	if t > WAVE_BUILD:
		return WAVE_LULL
	return lerpf(WAVE_LOW, WAVE_HIGH, t / WAVE_BUILD)


## A monster from today's row of the spawn table.
func pick_enemy(elite := false) -> EnemyData:
	var weights: Array = SPAWN_TABLE.back()[2 if elite else 1]
	for row: Array in SPAWN_TABLE:
		if _main.day() < row[0]:
			weights = row[2 if elite else 1]
			break
	var total := 0
	for w: int in weights:
		total += w
	var roll := randi_range(1, total)
	for i in KINDS.size():
		roll -= weights[i]
		if roll <= 0:
			return KINDS[i]
	return DREADLING


func spawn_enemy(elite := false, distance := SPAWN_RADIUS) -> void:
	var day: int = _main.day()
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	var affix := ""
	if elite and day >= TRAITS_FROM_DAY and (day >= TRAITS_ALWAYS_FROM_DAY or randf() < TRAIT_CHANCE):
		affix = Enemy.TRAITS.keys().pick_random()
	enemy.setup(pick_enemy(elite), _player, elite, toughness(), affix)
	enemy.position = _spawn_point(distance)
	_enemies.add_child(enemy)
	if enemy.data == HEXEYE:
		Hints.show_hint("hexeye", "A Hexeye: it keeps its distance and aims a blue line before it fires. Step off the line.")
	elif enemy.data == WARDEN:
		Hints.show_hint("warden", "A Warden: its shield soaks most of your damage until it breaks. Burns and bites wear it down too.")
	if affix != "":
		Hints.show_hint("trait", "Elites can carry a trait, named over their head: Swift, Armored, Splitting (bursts into three) or Vampiric (heals when it hits you). They pay double gold.")
	if elite:
		Hints.show_hint("elite", "An elite is coming: bigger and tougher. Kill it and it drops an essence you can Devour.")


func spawn_at(data: EnemyData, at: Vector2) -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.setup(data, _player, false, toughness())
	enemy.position = at
	_enemies.add_child(enemy)
	return enemy


## A Splitting elite bursts into three of its kind.
func split(enemy: Enemy) -> void:
	for i in SPLIT_COUNT:
		var at := enemy.global_position + Vector2.RIGHT.rotated(TAU * i / SPLIT_COUNT) * 30.0
		spawn_at.call_deferred(enemy.data, at)


## A chest that was a Mimic all along.
func spring_mimic(at: Vector2) -> void:
	var mimic := ENEMY_SCENE.instantiate() as Enemy
	mimic.setup(MIMIC, _player, false, toughness())
	mimic.position = at
	_enemies.add_child.call_deferred(mimic)


## The Demon King, placed near the player; main.gd stages his arrival.
func spawn_boss() -> Boss:
	boss = BOSS_SCENE.instantiate() as Boss
	boss.setup(DEMON_KING, _player)
	boss.position = _player.position + Vector2.RIGHT.rotated(randf() * TAU) * BOSS_SPAWN_DISTANCE
	boss.summon.connect(_on_boss_summon)
	return boss


## His arrival scatters the horde: no kills, no drops, just a puff of smoke.
func clear_swarm() -> void:
	for node in _enemies.get_children():
		var enemy := node as Enemy
		if enemy and enemy.alive():
			Game.burst(enemy.global_position, Color(0.4, 0.3, 0.5), 6)
			enemy.queue_free()
	Game.shake(0.5)


# Where a new enemy appears: mostly ahead of a running player, so fleeing in
# a straight line runs into the next pack.
func _spawn_point(distance: float) -> Vector2:
	var angle := randf() * TAU
	if _player.velocity.length() > 10.0 and randf() < AHEAD_CHANCE:
		angle = _player.velocity.angle() + randf_range(-AHEAD_SPREAD, AHEAD_SPREAD)
	return _player.position + Vector2.RIGHT.rotated(angle) * distance


func _start_event() -> void:
	var day: int = _main.day()
	var events := ["encircle", "ambush"]
	if day >= 8:
		events.append("plague")
	var event: String = events.pick_random()
	var warnings := {
		"encircle": "They're surrounding you!",
		"ambush": "A Vexclaw pack is hunting you!",
		"plague": "A plague tide rises...",
	}
	_main.show_banner(warnings[event], 2.0)
	Game.sfx("boss_warn", 0.0)
	await get_tree().create_timer(EVENT_WARNING, false).timeout
	if _main.over or _main.boss_spawned:
		return
	var origin := _player.position
	match event:
		"encircle":
			# A closing ring of Dreadlings, all the way around.
			var count := 12 + day
			for i in count:
				var angle := TAU * i / count + randf_range(-0.05, 0.05)
				spawn_at(DREADLING, origin + Vector2.RIGHT.rotated(angle) * 520.0)
		"ambush":
			var side := randf() * TAU
			for i in 3 + day / 4:
				spawn_at(VEXCLAW, origin + Vector2.RIGHT.rotated(side + randf_range(-0.4, 0.4)) * 600.0)
		"plague":
			var side := randf() * TAU
			for i in 2 + day / 8:
				spawn_at(PLAGUEWING, origin + Vector2.RIGHT.rotated(side + randf_range(-0.5, 0.5)) * 600.0)
			for i in 6:
				spawn_at(DREADLING, origin + Vector2.RIGHT.rotated(side + randf_range(-0.6, 0.6)) * 560.0)


func _spawn_mini_boss(on_day: int) -> void:
	var entry: Array = MINI_BOSSES[on_day]
	mini_boss = BOSS_SCENE.instantiate() as Boss
	mini_boss.setup(entry[0], _player)
	mini_boss.configure(entry[1], entry[2], entry[3])
	mini_boss.position = _player.position + Vector2.RIGHT.rotated(randf() * TAU) * BOSS_SPAWN_DISTANCE
	mini_boss.summon.connect(_on_boss_summon)
	_enemies.add_child(mini_boss)
	mini_boss_arrived.emit(mini_boss, entry[0])


func _on_boss_summon(at: Vector2, count: int, phase_two: bool) -> void:
	var start := randf() * TAU
	for i in count:
		spawn_at(VEXCLAW if phase_two else DREADLING, at + Vector2.RIGHT.rotated(start + TAU * i / count) * SUMMON_RING)
	Game.burst(at, Color(0.75, 0.35, 1.0), 16, 220.0)
