class_name Benchmark
extends Node
## The worst-case performance scene inside the game itself, so it also runs
## in exported builds, the web build included (tools/stress_test.gd only runs
## from the editor binary). Start it with:
##   desktop: ReincarnatedAsADevourer.exe -- --bench=500
##   web:     index.html?bench=500
## An unkillable hero on Day 15 with four maxed, evolved weapons, a horde
## kept at the requested size, 4 s of warm-up, then 12 s measured. Results
## go to the screen and to the console (one line starting with "BENCH").
## Options switch costs off to price them: --bench-opts=nolight,novignette
## on desktop, &opts=nolight,novignette in the web URL.

const WARMUP := 4.0
const MEASURE := 12.0
const WEAPONS := ["res://data/weapons/blade.tres", "res://data/weapons/goddess_light.tres",
	"res://data/weapons/maw.tres", "res://data/weapons/chains.tres"]

var count := 500
var _main: Node
var _samples: Array[float] = []
var _time := 0.0
var _label: Label


## How many enemies a benchmark was asked for: 0 when not benchmarking.
static func requested() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bench="):
			return int(arg.get_slice("=", 1))
	if OS.has_feature("web"):
		var value: Variant = JavaScriptBridge.eval("new URLSearchParams(location.search).get('bench') || ''")
		if value is String and (value as String).is_valid_int():
			return int(value)
	return 0


## Options given with the benchmark, e.g. ["nolight"].
static func options() -> PackedStringArray:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bench-opts="):
			return arg.get_slice("=", 1).split(",")
	if OS.has_feature("web"):
		var value: Variant = JavaScriptBridge.eval("new URLSearchParams(location.search).get('opts') || ''")
		if value is String and value != "":
			return (value as String).split(",")
	return PackedStringArray()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = get_parent()
	var opts := options()
	if "tick30" in opts:
		Engine.physics_ticks_per_second = 30
	if "interp" in opts:
		get_tree().physics_interpolation = true
	if "lowfx" in opts:
		Game.fx_ceiling = Game.FX_MIN
	if "nolight" in opts:
		_main.atmosphere.light.enabled = false
	if "novignette" in opts:
		for node in _main.get_node("HUD").get_children():
			if node is ColorRect and node.material is ShaderMaterial:
				node.hide()
	if "nomotes" in opts:
		for node in _main.atmosphere.get_children():
			if node is CPUParticles2D:
				node.emitting = false
	Settings.data.hints = false
	var player: Player = _main.player
	player.base.max_hp = 1e9
	player.hp = 1e9
	player.set_invulnerable(1e9)
	_main.elapsed = 14 * 60.0 + 5.0
	# A Day 15 hero is around level 32 (balance sims); at level 1 a horde
	# would level them every few frames and the benchmark would measure
	# level-up screens instead of combat.
	player.level = 32
	for path in WEAPONS:
		for i in 3:
			player.apply_upgrade(load(path))
	for weapon: Weapon in player.weapons.get_children():
		weapon.evolve()
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(20, 120)
	_label.add_theme_font_size_override("font_size", 30)
	layer.add_child(_label)


func _process(delta: float) -> void:
	if _main.level_up.visible:
		_main.level_up.pick(0)
	if _main.shrine.visible:
		_main.shrine.skip()
	if "hide" in options():
		for enemy in _main.enemies.get_children():
			enemy.visible = false
	var alive: int = _main.enemies.get_child_count()
	for i in mini(count - alive, 8):  # about the game's own spawn rate
		_main.spawner.spawn_enemy(randf() < 0.02, randf_range(250.0, 650.0))
	_time += delta
	if _time < WARMUP:
		_label.text = "Benchmark: warming up with %d enemies..." % count
		return
	if _time < WARMUP + MEASURE:
		_samples.append(delta * 1000.0)
		_label.text = "Benchmark: measuring (%d s left)" % ceili(WARMUP + MEASURE - _time)
		return
	if _samples.is_empty():
		return
	var sorted := _samples.duplicate()
	sorted.sort()
	var total := 0.0
	for s in sorted:
		total += s
	var n := sorted.size()
	var line := "BENCH %s %s enemies=%d avg %.1f fps (%.2f ms)  p99 %.1f ms  worst %.1f ms" % [
		OS.get_name(), ",".join(options()) if not options().is_empty() else "full", alive, n / (total / 1000.0), total / n, sorted[int(n * 0.99)], sorted[n - 1]]
	print(line)
	_label.text = line
	_samples.clear()
	set_process(false)
	if not OS.has_feature("web"):  # desktop runs end on their own; the web page stays
		await get_tree().create_timer(2.0, true).timeout
		get_tree().quit()
