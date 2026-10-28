class_name RunMusic
extends Node
## Which track the moment calls for, and how hard it should hit. Waves swell
## the music, a crowd around you pushes it to full, lulls muffle it, and in
## the ruins a long peak brings in the faster track.

## Enemies this close count as pressure; this many is full.
const PRESSURE_RADIUS := 320.0
const PRESSURE_FULL := 30.0
## In the ruins, intensity this high brings in the faster track for at least
## PEAK_HOLD seconds, until things calm below PEAK_RELEASE.
const PEAK_AT := 0.9
const PEAK_RELEASE := 0.6
const PEAK_HOLD := 20.0

var _pressure := 0.0
var _pressure_timer := 0.0
var _peak_hold := 0.0
var _main: Node


func _init(main: Node) -> void:
	_main = main


func update(delta: float) -> void:
	if _main.awaiting_revive:
		return
	var forest: bool = _main.world.biome == "forest"
	Game.footstep = "footstep_grass" if forest and not _main.boss_spawned else "footstep_stone"
	if _main.boss_spawned:
		Music.set_intensity(1.0)
		return
	if is_instance_valid(_main.mini_boss):
		Music.set_intensity(1.0)
		Music.play("ruins_peak", 1.5)
		return
	_pressure_timer -= delta
	if _pressure_timer <= 0.0:
		_pressure_timer = 0.5
		var near := 0
		var at: Vector2 = _main.player.global_position
		for node in _main.enemies.get_children():
			if (node as Node2D).global_position.distance_squared_to(at) < PRESSURE_RADIUS * PRESSURE_RADIUS:
				near += 1
		_pressure = clampf(near / PRESSURE_FULL, 0.0, 1.0)
	var spawner: SpawnDirector = _main.spawner
	var wave := clampf((spawner.wave_intensity() - SpawnDirector.WAVE_LULL)
		/ (SpawnDirector.WAVE_HIGH - SpawnDirector.WAVE_LULL), 0.0, 1.0)
	var intensity := maxf(maxf(0.3 + 0.7 * wave, _pressure), _main.style.intensity())
	Music.set_intensity(intensity)
	if forest:
		Music.play("forest", 2.5)
		return
	if intensity >= PEAK_AT:
		_peak_hold = PEAK_HOLD
	elif intensity < PEAK_RELEASE:
		_peak_hold -= delta
	Music.play("ruins_peak" if _peak_hold > 0.0 else "ruins", 2.5)
