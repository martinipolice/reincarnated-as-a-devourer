extends SceneTree
# Repeatable worst-case performance test. Not part of the game.
#   godot --path . --resolution 1280x720 -s res://tools/stress_test.gd -- [count] [options]
# An unkillable hero on Day 15 with four weapons maxed and evolved, burning
# and biting, and the horde topped up to `count` enemies (default 500) as
# they die. Vsync is off, so it measures real frame time. After a warm-up
# it records 12 seconds and prints:
#   avg fps, the 99th-percentile and worst frame, script and physics time
#   per frame, draw calls and node count.
# Options switch things off to see what each one costs:
#   noweapons  the hero carries nothing      freeze  enemies stop thinking
#   hide       enemies aren't drawn          nolight no hero light
#   hidefx / hidepickups / hideweapons / hideworld   hide that layer
#   nogems     gems vanish                   noshapes enemy collision shapes off
#   onestep    one physics step per frame: the true cost of a frame, without
#              Godot's catch-up steps blurring it
# Budget (60 fps): avg >= 60 fps and p99 frame <= 20 ms at 500 enemies.
# Last measured (Oct 2026, v0.2.0): editor ~94-102 fps avg, p99 ~19 ms;
# release Windows build (scripts/debug/benchmark.gd, -- --bench=500)
# ~120 fps, p99 ~17 ms. Web build: see README (Performance).
# Untyped on purpose: -s compiles this before autoloads exist.

const WARMUP := 4.0
const MEASURE := 12.0
const WEAPONS := ["res://data/weapons/blade.tres", "res://data/weapons/goddess_light.tres",
	"res://data/weapons/maw.tres", "res://data/weapons/chains.tres"]

var count := 500
var options := []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.is_valid_int():
			count = int(arg)
		else:
			options.append(arg)
	seed(1234)
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if "onestep" in options:
		Engine.max_physics_steps_per_frame = 1  # one step per frame: the true cost of a frame
	root.get_node("Settings").data.hints = false
	root.get_node("Save").resume = false
	change_scene_to_file("res://scenes/main.tscn")
	for i in 20:
		await process_frame
	var main = current_scene
	var p = main.player
	p.base.max_hp = 1e9
	p.hp = 1e9
	p.set_invulnerable(1e9)
	main.elapsed = 14 * 60.0 + 5.0
	p.level = 32  # a Day 15 hero; at level 1 the horde would trigger a level-up screen every few frames
	if "nolight" in options:
		main.atmosphere.light.enabled = false
	if not "noweapons" in options:
		for path in WEAPONS:
			for i in 3:
				p.apply_upgrade(load(path))
		for w in p.weapons.get_children():
			w.evolve()
	else:
		for w in p.weapons.get_children():
			w.queue_free()
	# Markers that run first and last in each physics step and each frame,
	# so callbacks can be told apart from the engine's own work.
	var marks := {"phys": 0, "proc": 0}
	var first := Node.new()
	first.process_physics_priority = -100000
	first.process_priority = -100000
	var last_node := Node.new()
	last_node.process_physics_priority = 100000
	last_node.process_priority = 100000
	var gd := GDScript.new()
	gd.source_code = "extends Node
var marks
var is_first := false
var t := 0
var other
func _physics_process(_d):
	if is_first: t = Time.get_ticks_usec()
	else: marks.phys += Time.get_ticks_usec() - other.t
func _process(_d):
	if is_first: set_meta('pt', Time.get_ticks_usec())
	else: marks.proc += Time.get_ticks_usec() - other.get_meta('pt')
"
	gd.reload()
	first.set_script(gd)
	last_node.set_script(gd)
	first.marks = marks
	first.is_first = true
	last_node.marks = marks
	last_node.other = first
	main.add_child(first)
	main.add_child(last_node)
	var vp_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	var render_cpu := 0.0
	var render_gpu := 0.0
	var samples: Array[float] = []
	var slow := {}
	var was_leveled := false
	var last_kills := 0
	var proc := 0.0
	var phys := 0.0
	var draws := 0.0
	var nodes := 0.0
	var t0 := Time.get_ticks_msec()
	var last := Time.get_ticks_usec()
	while true:
		await process_frame
		var now := Time.get_ticks_usec()
		var frame_ms := (now - last) / 1000.0
		last = now
		var leveled := false
		if main.level_up.visible:
			main.level_up.pick(0)
			leveled = true
		if main.shrine.visible:
			main.shrine.skip()
		var alive: int = main.enemies.get_child_count()
		for i in mini(count - alive, 8):  # top up at about the game's own spawn rate
			main.spawner.spawn_enemy(randf() < 0.02, randf_range(250.0, 650.0))
		if "hidefx" in options:
			main.get_node("Effects").visible = false
			for layer in main.get_children():
				if layer is CanvasItem and (layer.is_in_group("pop_layer") or layer.is_in_group("splat_layer")):
					layer.visible = false
		if "hidepickups" in options:
			main.pickups.visible = false
		if "hideweapons" in options:
			p.weapons.visible = false
		if "hideworld" in options:
			main.world.visible = false
		if "nogems" in options:
			for g in main.pickups.get_children():
				if g.has_method("magnetize"):
					g.queue_free()
		for e in main.enemies.get_children():
			if "noshapes" in options:
				e.get_node("CollisionShape2D").disabled = true
			if "freeze" in options:
				e.set_physics_process(false)
			if "hide" in options:
				e.visible = false
		var elapsed := (Time.get_ticks_msec() - t0) / 1000.0
		if elapsed < WARMUP:
			continue
		if elapsed > WARMUP + MEASURE:
			break
		samples.append(frame_ms)
		if frame_ms > 20.0:
			var why := "level-up" if leveled or was_leveled else ("kills+%d" % (main.kills - last_kills))
			slow[why] = slow.get(why, 0) + 1
		was_leveled = leveled
		last_kills = main.kills
		proc += Performance.get_monitor(Performance.TIME_PROCESS)
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		nodes += Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		render_cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp_rid) + RenderingServer.get_frame_setup_time_cpu()
		render_gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
	var gems := 0
	for g in main.pickups.get_children():
		if g.has_method("magnetize"):
			gems += 1
	print("  pickups=%d (gems %d)  effects=%d" % [main.pickups.get_child_count(), gems, main.get_node("Effects").get_child_count()])
	print("  callbacks per frame: physics %.2f ms, process %.2f ms" % [marks.phys / 1000.0 / maxf(samples.size(), 1), marks.proc / 1000.0 / maxf(samples.size(), 1)])
	print("  render cpu %.2f ms  gpu %.2f ms per frame" % [render_cpu / maxf(samples.size(), 1), render_gpu / maxf(samples.size(), 1)])
	print("  slow frames (>20 ms) by what happened: ", slow, "  kills/s ", "%.0f" % (main.kills / (WARMUP + MEASURE)))
	var n := samples.size()
	var total := 0.0
	for s in samples:
		total += s
	samples.sort()
	print("STRESS %s enemies=%d  avg %.1f fps (%.2f ms)  p99 %.1f ms  worst %.1f ms  script %.2f ms  physics %.2f ms  draws %d  nodes %d" % [
		" ".join(options) if options else "full", main.enemies.get_child_count(), n / (total / 1000.0), total / n,
		samples[int(n * 0.99)], samples[n - 1], proc / n * 1000.0, phys / n * 1000.0, draws / n, nodes / n])
	quit()
