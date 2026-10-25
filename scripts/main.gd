extends Node2D
## The journey controller: one life, twenty days. Runs the day clock, the
## spawn director, elites and the boss, level-ups and the HUD; opens the
## goddess's shrine on the lore days (checkpointing the journey there); and on
## death offers a revive for gold, or ends the journey for good.

## For the HUD, which listens instead of reading the run every frame.
signal gold_changed(gold: int, revive_cost: int)
signal day_changed(day: int, final_day: int, next_shrine: int)

const SECONDS_PER_DAY := 60.0  # 20 days in 20 minutes
const FINAL_DAY := 20
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
## Treasure chests: one appears every CHEST_INTERVAL s (up to MAX_CHESTS at
## once) somewhere just off-screen; a HUD arrow points the way. Some are
## golden (two rewards); from MIMIC_FROM_DAY some are Mimics that fight back.
const CHEST_FIRST := 20.0
const CHEST_INTERVAL := 30.0
const GOLDEN_CHANCE := 0.15
const MIMIC_CHANCE := 0.15
const MIMIC_FROM_DAY := 3
const FERVOR_DURATION := 15.0
const FERVOR_HASTE := 0.5
const MAX_CHESTS := 3
const CHEST_DISTANCE := Vector2(450.0, 850.0)
const BOMB_RADIUS := 450.0
const BOMB_DAMAGE := 150.0
const GOLD_POUCH_PER_DAY := 12
## How far from the Demon King his summoned minions appear.
const SUMMON_RING := 80.0
## Biomes by day; the Demon King's temple arena has this radius.
const RUINS_FROM_DAY := 10
const ARENA_RADIUS := 650.0
## The world's light by area: dusk in the forest, gloom in the ruins, a
## blood-dark temple. The hero's own light (Atmosphere) carries through it.
const MOOD := {
	"forest": Color(0.5, 0.48, 0.64),
	"ruins": Color(0.48, 0.4, 0.5),
	"temple": Color(0.42, 0.28, 0.34),
}
const CHEST_REEL := preload("res://scripts/ui/chest_reel.gd")
const ENDING := preload("res://scripts/ui/ending.gd")
const VIGNETTE := preload("res://scripts/ui/vignette.gd")
## The camera pulls back from 1.0 toward this as you level (30 levels).
const MIN_ZOOM := 0.86
## The goddess finds you on the original game's lore days.
const SHRINE_DAYS := [5, 10, 15, 19]
const SHRINE_SCENE := preload("res://scenes/ui/shrine.tscn")
const PAUSE_MENU := preload("res://scripts/ui/pause_menu.gd")
## After a level-up, gems this close fly to you, so none are left behind.
const LEVEL_UP_MAGNET := 700.0
## Music intensity: enemies this close count as pressure; this many is full.
const PRESSURE_RADIUS := 320.0
const PRESSURE_FULL := 30.0
## In the ruins, intensity this high brings in the faster track for at least
## PEAK_HOLD seconds, until things calm below PEAK_RELEASE.
const PEAK_AT := 0.9
const PEAK_RELEASE := 0.6
const PEAK_HOLD := 20.0
## Elites can carry a trait from this day: some of the time, then always.
const TRAITS_FROM_DAY := 5  # after the goddess's first visit
const TRAIT_CHANCE := 0.6
const TRAITS_ALWAYS_FROM_DAY := 10
const TRAIT_GOLD_MULT := 2.0
const SPLIT_COUNT := 3
## Shrine covenants: a curse until the next shrine, for a reward.
## id -> [name, curse, boon]. Effects live in set_covenant() and the
## *_mult() functions below.
const COVENANTS := {
	"blood": ["Covenant of Blood", "Enemies hit 35% harder", "Gold x1.5"],
	"horde": ["Covenant of the Horde", "40% more enemies", "XP and gold x1.3"],
	"frailty": ["Covenant of Frailty", "Max HP -30%", "Damage +40%"],
	"thirst": ["Covenant of Thirst", "Your Tears are emptied", "A second blessing, now"],
}
## Below this HP fraction, the first time, the game suggests the flask.
const FLASK_HINT_HP := 0.5
const SHRINE := preload("res://scripts/ui/shrine.gd")
## Reviving costs gold, doubling each time: 800, 1600, 3200...
const REVIVE_BASE_COST := 800
const REVIVE_HP := 0.5  # fraction of max HP you come back with
const REVIVE_CLEAR_RADIUS := 450.0
const REVIVE_INVULN := 2.5
const TITLE_SCENE := "res://scenes/ui/title.tscn"
## Ignore end-screen input briefly so a held key doesn't skip it.
const END_MENU_DELAY := 0.8

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const BOSS_SCENE := preload("res://scenes/boss.tscn")
const GEM_SCENE := preload("res://scenes/xp_gem.tscn")
const CORPSE_SCENE := preload("res://scenes/devour_corpse.tscn")
const CHEST_SCENE := preload("res://scenes/loot_chest.tscn")
const DREADLING := preload("res://data/enemies/dreadling.tres")
const VEXCLAW := preload("res://data/enemies/vexclaw.tres")
const PLAGUEWING := preload("res://data/enemies/plaguewing.tres")
const MIMIC := preload("res://data/enemies/mimic.tres")
const DEMON_KING := preload("res://data/enemies/demon_king.tres")

const STARTING_WEAPON := preload("res://data/weapons/blade.tres")
## Offered when everything in the pool is maxed.
const FALLBACK_UPGRADE := preload("res://data/items/panacea.tres")
## Everything the level-up screen can offer.
const UPGRADE_POOL := [
	preload("res://data/weapons/blade.tres"),
	preload("res://data/weapons/goddess_light.tres"),
	preload("res://data/weapons/aegis.tres"),
	preload("res://data/weapons/maw.tres"),
	preload("res://data/weapons/chains.tres"),
	preload("res://data/items/wooden_guard.tres"),
	preload("res://data/items/leather_treads.tres"),
	preload("res://data/items/stamina.tres"),
	preload("res://data/items/fury.tres"),
	preload("res://data/items/magnet_charm.tres"),
	preload("res://data/items/vigor.tres"),
]
const OFFERS_PER_LEVEL := 3

var elapsed := 0.0
var kills := 0
var gold := 0:
	set(value):
		gold = value
		gold_changed.emit(gold, revive_cost())
var boss: Boss
var revives := 0
## TrainingData.id -> ranks bought at the goddess's shrines this journey.
var training_ranks := {}
var shrine: CanvasLayer
var pause_menu: CanvasLayer
var chest_reel: CanvasLayer
var ending: CanvasLayer
## Chests waiting for their ceremony, [rewards, golden, at]: two can be
## opened in one frame (a Mimic's golden chest beside another).
var _chest_queue: Array = []
var _revealing := false
var atmosphere: Atmosphere
@onready var camera: Camera2D = $Player/Camera2D
var _shrines_done := []
var _awaiting_revive := false
var _last_day := 0
var style: StyleMeter
var covenant := ""
var _pressure := 0.0
var _pressure_timer := 0.0
var _peak_hold := 0.0
var _spawn_timer := GRACE_PERIOD
var _elite_timer := ELITE_INTERVAL
var _chest_timer := CHEST_FIRST
var _event_timer := EVENT_FIRST
var _fervor_until := 0.0
var _boss_spawned := false
var _over := false
var _banner_tween: Tween

@onready var player: Player = $Player
@onready var enemies: Node2D = $Enemies
@onready var pickups: Node2D = $Pickups
@onready var level_up: CanvasLayer = $LevelUp
@onready var hud: Control = $HUD/SoulsHUD
@onready var moments: CanvasLayer = $Moments
@onready var banner: Label = $HUD/Banner
@onready var end_menu: Control = $EndLayer/EndMenu
@onready var end_text: Label = %EndText
@onready var primary_button: Button = %Primary
@onready var secondary_button: Button = %Secondary
@onready var world: ChunkWorld = $World
@onready var mood: CanvasModulate = $Mood


func _ready() -> void:
	Game.enemy_killed.connect(_on_enemy_killed)
	player.died.connect(_on_player_died)
	player.leveled_up.connect(_on_player_leveled_up)
	player.devoured.connect(_on_player_devoured)
	player.weapon_evolved.connect(_on_weapon_evolved)
	level_up.chosen.connect(_on_upgrade_chosen)
	primary_button.pressed.connect(_on_primary)
	secondary_button.pressed.connect(_on_secondary)
	shrine = SHRINE_SCENE.instantiate()
	add_child(shrine)
	shrine.closed.connect(_on_shrine_closed)
	pause_menu = PAUSE_MENU.new()
	add_child(pause_menu)
	chest_reel = CHEST_REEL.new()
	add_child(chest_reel)
	ending = ENDING.new()
	add_child(ending)
	add_child(SplatLayer.new())
	add_child(PopLayer.new())
	atmosphere = Atmosphere.new()
	player.add_child(atmosphere)
	var vignette := VIGNETTE.new()
	$HUD.add_child(vignette)
	$HUD.move_child(vignette, 0)  # under the HUD
	vignette.bind(player)
	world.set_origin(player.position)
	mood.color = MOOD.forest
	if Save.resume and Save.has_journey():
		_restore(Save.data.journey)
	else:
		player.apply_upgrade(STARTING_WEAPON)
	Save.resume = false
	end_menu.hide()
	banner.hide()
	Music.muffle(false)
	atmosphere.set_area("ruins" if world.biome == "ruins" else "forest")
	camera.set_base_zoom(_zoom_for_level(), 0.0)
	style = StyleMeter.new()
	add_child(style)
	style.rank_changed.connect(_on_rank_changed)
	player.hurt.connect(style.on_hurt)
	hud.bind_style(style)
	if covenant == "":
		set_covenant("")  # clears a multiplier left from a previous run
	hud.bind(player, self)
	gold = gold  # announce the starting gold and revive price
	_last_day = 0
	moments.area_card("The Fallen Ruins" if day() >= RUINS_FROM_DAY else "The Whispering Forest")
	Hints.show_hint("move", "Move with {move}. Your weapons attack on their own: focus on staying alive.")
	Hints.show_hint("pause", "Press {pause} any time to pause, check your build, read how to play, or change settings.")


func day() -> int:
	return mini(int(elapsed / SECONDS_PER_DAY) + 1, FINAL_DAY)


func toughness() -> float:
	return 1.0 + TOUGHNESS_PER_DAY * (day() - 1)


func _process(delta: float) -> void:
	world.update(player.position, get_viewport_rect().size)
	if _over:
		if Input.is_action_just_pressed("restart") and not primary_button.disabled:
			_on_primary()
		return

	elapsed += delta
	if day() != _last_day:
		_last_day = day()
		day_changed.emit(day(), FINAL_DAY, next_shrine_day())
		style.scale = 1.0 + StyleMeter.DAY_SCALE * (day() - 1)
		if next_shrine_day() == day() + 1:
			Hints.show_hint("shrine_soon", "The goddess finds you tomorrow. At her shrine, gold buys training. Gold also pays for a revive if you fall, so don't spend it all.")
	if not _over and player.hp < player.stat("max_hp") * FLASK_HINT_HP and player.flask_charges > 0:
		Hints.show_hint("flask", "You're hurt! Press {flask} to drink the Goddess's Tears. She refills them at every shrine, so use them.")
	if day() in SHRINE_DAYS and not day() in _shrines_done and not level_up.visible:
		_shrines_done.append(day())
		shrine.open(day(), self)
	if day() >= RUINS_FROM_DAY and world.biome == "forest":
		world.biome = "ruins"
		create_tween().tween_property(mood, "color", MOOD.ruins, 4.0)
		atmosphere.set_area("ruins")
		moments.area_card("The Fallen Ruins")
	if day() >= FINAL_DAY and not _boss_spawned:
		_spawn_boss()

	# The waves stop once the Demon King arrives: Day 20 is a duel.
	if not _boss_spawned:
		_spawn_waves(delta)
	_chest_timer -= delta
	if _chest_timer <= 0.0:
		_chest_timer = CHEST_INTERVAL
		_spawn_chest()

	_update_status()
	_update_music(delta)


func _physics_process(_delta: float) -> void:
	Crowd.rebuild(enemies.get_children())


func _exit_tree() -> void:
	Crowd.clear()
	Hints.clear()  # however the run is left: quit, title or a new journey


func _spawn_waves(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = maxf(0.45, 1.3 - day() * 0.05) / wave_intensity() / (1.4 if covenant == "horde" else 1.0)
		# Bigger packs as the days pass: 1 per spawn on Days 1-4, 2 on 5-9, ...
		for i in 1 + day() / 5:
			_spawn_enemy()
	_elite_timer -= delta
	if _elite_timer <= 0.0:
		_elite_timer = ELITE_INTERVAL
		_spawn_enemy(true)
	if day() >= EVENT_FROM_DAY:
		_event_timer -= delta
		if _event_timer <= 0.0:
			_event_timer = randf_range(EVENT_GAP.x, EVENT_GAP.y)
			_start_event()


## How hard the current wave is pushing: builds up, then a short breather.
func wave_intensity() -> float:
	var t := fmod(elapsed, WAVE_CYCLE) / WAVE_CYCLE
	if t > WAVE_BUILD:
		return WAVE_LULL
	return lerpf(WAVE_LOW, WAVE_HIGH, t / WAVE_BUILD)


# Where a new enemy appears: mostly ahead of a running player, so fleeing in
# a straight line runs into the next pack.
func _spawn_point(distance: float) -> Vector2:
	var angle := randf() * TAU
	if player.velocity.length() > 10.0 and randf() < AHEAD_CHANCE:
		angle = player.velocity.angle() + randf_range(-AHEAD_SPREAD, AHEAD_SPREAD)
	return player.position + Vector2.RIGHT.rotated(angle) * distance


func _start_event() -> void:
	var events := ["encircle", "ambush"]
	if day() >= 8:
		events.append("plague")
	var event: String = events.pick_random()
	var warnings := {
		"encircle": "They're surrounding you!",
		"ambush": "A Vexclaw pack is hunting you!",
		"plague": "A plague tide rises...",
	}
	show_banner(warnings[event], 2.0)
	Game.sfx("boss_warn", 0.0)
	await get_tree().create_timer(EVENT_WARNING, false).timeout
	if _over or _boss_spawned:
		return
	match event:
		"encircle":
			# A closing ring of Dreadlings, all the way around.
			var count := 12 + day()
			for i in count:
				var angle := TAU * i / count + randf_range(-0.05, 0.05)
				_spawn_at(DREADLING, player.position + Vector2.RIGHT.rotated(angle) * 520.0)
		"ambush":
			# A Vexclaw pack from one side.
			var side := randf() * TAU
			for i in 3 + day() / 4:
				_spawn_at(VEXCLAW, player.position + Vector2.RIGHT.rotated(side + randf_range(-0.4, 0.4)) * 600.0)
		"plague":
			var side := randf() * TAU
			for i in 2 + day() / 8:
				_spawn_at(PLAGUEWING, player.position + Vector2.RIGHT.rotated(side + randf_range(-0.5, 0.5)) * 600.0)
			for i in 6:
				_spawn_at(DREADLING, player.position + Vector2.RIGHT.rotated(side + randf_range(-0.6, 0.6)) * 560.0)


func _spawn_at(data: EnemyData, at: Vector2) -> void:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.setup(data, player, false, toughness())
	enemy.position = at
	enemies.add_child(enemy)


# Which track the moment calls for, and how hard it should hit. Waves swell
# the music, a crowd around you pushes it to full, lulls muffle it.
func _update_music(delta: float) -> void:
	if _awaiting_revive:
		return
	Game.footstep = "footstep_grass" if world.biome == "forest" and not _boss_spawned else "footstep_stone"
	if _boss_spawned:
		Music.set_intensity(1.0)
		return
	_pressure_timer -= delta
	if _pressure_timer <= 0.0:
		_pressure_timer = 0.5
		var near := 0
		for node in enemies.get_children():
			if (node as Node2D).global_position.distance_squared_to(player.global_position) < PRESSURE_RADIUS * PRESSURE_RADIUS:
				near += 1
		_pressure = clampf(near / PRESSURE_FULL, 0.0, 1.0)
	var wave := clampf((wave_intensity() - WAVE_LULL) / (WAVE_HIGH - WAVE_LULL), 0.0, 1.0)
	var intensity := maxf(maxf(0.3 + 0.7 * wave, _pressure), style.intensity())
	Music.set_intensity(intensity)
	if world.biome == "forest":
		Music.play("forest", 2.5)
		return
	if intensity >= PEAK_AT:
		_peak_hold = PEAK_HOLD
	elif intensity < PEAK_RELEASE:
		_peak_hold -= delta
	Music.play("ruins_peak" if _peak_hold > 0.0 else "ruins", 2.5)


func _on_rank_changed(rank: int, rising: bool) -> void:
	if rising and rank >= 2:
		Game.sfx("rank_up", 0.0)
		if rank == StyleMeter.LETTERS.size() - 1:
			Game.sfx("toll", 0.0)
		Hints.show_hint("style", "Your style rank (D to SSS) climbs as you kill and drops when you're hit. Higher ranks pay more gold and XP.")


## Gold and XP rewards: the style rank times any covenant's boon.
func gold_mult() -> float:
	return style.gold_mult() * {"blood": 1.5, "horde": 1.3}.get(covenant, 1.0)


func xp_mult() -> float:
	return style.xp_mult() * (1.3 if covenant == "horde" else 1.0)


## Seals a covenant ("" lifts it): it lasts until the next shrine.
func set_covenant(id: String) -> void:
	for i in range(player.modifiers.size() - 1, -1, -1):
		if player.modifiers[i].get("source", "") == "covenant":
			player.modifiers.remove_at(i)
	covenant = id
	Game.enemy_atk_mult = 1.35 if id == "blood" else 1.0
	if id == "frailty":
		player.modifiers.append({"stat": "max_hp", "add": 0.0, "mult": -0.3, "source": "covenant"})
		player.modifiers.append({"stat": "might", "add": 0.0, "mult": 0.4, "source": "covenant"})
		player.hp = minf(player.hp, player.stat("max_hp"))
	elif id == "thirst":
		player.flask_charges = 0
		player.flask_changed.emit(0, player.flask_max)
	player.stats_changed.emit()


## The next day the goddess will appear, or 0 if she won't again.
func next_shrine_day() -> int:
	for shrine_day: int in SHRINE_DAYS:
		if shrine_day > day() or (shrine_day == day() and not shrine_day in _shrines_done):
			return shrine_day
	return 0


# The HUD's status line: timed buffs and what you've devoured.
func _update_status() -> void:
	var parts := []
	if covenant != "":
		parts.append(COVENANTS[covenant][0])
	if elapsed < _fervor_until:
		parts.append("Goddess's Fervor  %ds" % ceili(_fervor_until - elapsed))
	for essence: EssenceData in player.essences:
		parts.append("%s x%d" % [essence.display_name.get_slice(" ", 0), player.essences[essence]])
	hud.set_status("   ".join(parts))


func show_banner(text: String, duration := 2.5) -> void:
	if _banner_tween:
		_banner_tween.kill()
	banner.text = text
	banner.modulate.a = 1.0
	banner.show()
	_banner_tween = create_tween()
	_banner_tween.tween_interval(duration)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.5)
	_banner_tween.tween_callback(banner.hide)


# Weights ported from explore(), keyed by day instead of total stats.
# The original allowed 5% Plaguewings from the start; that is brutal in real
# time, so early days skip them. Elites lean toward stronger monsters so
# Vexclaw essences (the Blade evolution) are reachable. Tune freely.
func _pick_enemy(elite := false) -> EnemyData:
	var weights: Array
	if day() < 6:
		weights = [60, 40, 0] if elite else [90, 10, 0]
	elif day() < 12:
		weights = [30, 50, 20] if elite else [45, 45, 10]
	else:
		weights = [20, 45, 35] if elite else [35, 35, 30]
	var roll := randi_range(1, 100)
	if roll <= weights[0]:
		return DREADLING
	if roll <= weights[0] + weights[1]:
		return VEXCLAW
	return PLAGUEWING


func _spawn_enemy(elite := false, distance := SPAWN_RADIUS) -> void:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	var affix := ""
	if elite and day() >= TRAITS_FROM_DAY and (day() >= TRAITS_ALWAYS_FROM_DAY or randf() < TRAIT_CHANCE):
		affix = Enemy.TRAITS.keys().pick_random()
	enemy.setup(_pick_enemy(elite), player, elite, toughness(), affix)
	enemy.position = _spawn_point(distance)
	enemies.add_child(enemy)
	if affix != "":
		Hints.show_hint("affix", "Elites can carry a affix, named over their head: Swift, Armored, Splitting (bursts into three) or Vampiric (heals when it hits you). They pay double gold.")
	if elite:
		Hints.show_hint("elite", "An elite is coming: bigger and tougher. Kill it and it drops an essence you can Devour.")


# Testing shortcuts. Only active in debug builds (running from the editor),
# never in an exported game.
func _unhandled_input(event: InputEvent) -> void:
	# Esc pauses, unless a screen (level-up, shrine, death) already has.
	if event.is_action_pressed("pause") and not _over and not get_tree().paused:
		get_viewport().set_input_as_handled()
		pause_menu.open(self)
		return
	if not OS.is_debug_build() or _over or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F1:
			_spawn_enemy(true, 250.0)
			show_banner("[debug] Elite spawned", 1.0)
		KEY_F2:
			player.gain_xp(player.xp_to_next() - player.xp)
		KEY_F3:
			if not _boss_spawned:
				elapsed = (FINAL_DAY - 1) * SECONDS_PER_DAY
		KEY_F4:
			player.hp = player.stat("max_hp")
			show_banner("[debug] Healed", 1.0)


func _spawn_boss() -> void:
	_boss_spawned = true
	boss = BOSS_SCENE.instantiate() as Boss
	boss.setup(DEMON_KING, player)
	boss.position = player.position + Vector2.RIGHT.rotated(randf() * TAU) * BOSS_SPAWN_DISTANCE
	boss.summon.connect(_on_boss_summon)
	boss.enraged.connect(func() -> void:
		show_banner("The Demon King is enraged!", 2.0)
		Game.sfx("toll", 0.0)
		Music.play("boss_enraged", 1.0))
	# His arrival: a doom hit and a toll under the boss track's own opening.
	Game.sfx("doom", 0.0)
	Game.sfx("toll", 0.0)
	Music.play("boss_opening", 0.4, "boss")
	_clear_swarm()
	world.make_arena(player.position, ARENA_RADIUS)
	# The goddess's last gift: the duel starts at full strength.
	var healed := player.stat("max_hp") - player.hp
	player.hp = player.stat("max_hp")
	Game.fx("spark", player.global_position, 3.0, Color(1, 0.95, 0.6))
	if healed >= 1.0:
		Game.float_text(player.global_position, "+%d HP" % roundi(healed), Color(1, 0.95, 0.6))
	create_tween().tween_property(mood, "color", MOOD.temple, 2.0)
	atmosphere.set_area("temple")
	camera.punch(0.15, 1.6)
	Game.shockwave(boss.global_position, Color(0.9, 0.2, 0.3), 260.0, 0.8)
	enemies.add_child(boss)
	hud.show_boss(boss, DEMON_KING.display_name)
	moments.area_card("Temple of the Demon King")
	show_banner("The sky darkens... The Demon King descends.", 3.5)
	Hints.show_hint("boss", "A red mark on the ground shows where he will slam: step out of it. Dodge his rings of dark orbs, and drink your Tears when low.")


func _spawn_chest() -> void:
	if get_tree().get_nodes_in_group("chests").size() >= MAX_CHESTS:
		return
	var distance := randf_range(CHEST_DISTANCE.x, CHEST_DISTANCE.y)
	var roll := randf()
	var kind := LootChest.Kind.NORMAL
	if roll < GOLDEN_CHANCE:
		kind = LootChest.Kind.GOLDEN
	elif roll < GOLDEN_CHANCE + MIMIC_CHANCE and day() >= MIMIC_FROM_DAY:
		kind = LootChest.Kind.MIMIC
	_place_chest(player.position + Vector2.RIGHT.rotated(randf() * TAU) * distance, kind)
	Hints.show_hint("chest", "A chest appeared! Follow the golden arrow at the edge of the screen to find it.")


func _place_chest(at: Vector2, kind: LootChest.Kind) -> void:
	var chest := CHEST_SCENE.instantiate() as LootChest
	chest.kind = kind
	chest.position = Obstacles.push_out(at, 24.0)
	chest.opened.connect(_on_chest_opened)
	pickups.add_child(chest)


func _on_chest_opened(chest: LootChest) -> void:
	if chest.kind == LootChest.Kind.MIMIC:
		_spring_mimic(chest.global_position)
		return
	var golden := chest.kind == LootChest.Kind.GOLDEN
	var at := chest.global_position
	Game.sfx("chest_open", 0.0)
	Game.fx("spark", at, 3.0 if golden else 2.0, Color(1, 0.9, 0.5))
	Game.shake(0.35 if golden else 0.2)
	var hurt := player.hp < player.stat("max_hp") * 0.9
	var rewards := [Loot.roll(hurt)]
	if golden:
		rewards.append(Loot.roll(hurt, rewards[0].id))
	_chest_queue.append([rewards, golden, at])
	if not _revealing:
		_reveal_chests()


# The ceremony: the run pauses while the reel spins, then the loot lands.
# Chests opened together take turns.
func _reveal_chests() -> void:
	_revealing = true
	while not _chest_queue.is_empty():
		var entry: Array = _chest_queue.pop_front()
		var rewards: Array = entry[0]
		var golden: bool = entry[1]
		var at: Vector2 = entry[2]
		get_tree().paused = true
		await chest_reel.reveal(rewards, golden)
		if _over or _awaiting_revive:
			break
		get_tree().paused = false
		Game.burst(at, Color(1, 0.85, 0.35), 50 if golden else 25, 260.0)
		Game.shockwave(at, Color(1, 0.85, 0.35), 120.0 if golden else 90.0)
		var lines := []
		for i in rewards.size():
			lines.append(_grant_loot(rewards[i], at + Vector2(24 * i, 0)))
		var title := "GOLDEN CHEST\n" if golden else ""
		show_banner(title + "\n".join(lines), 2.5 if golden else 2.0)
	_chest_queue.clear()
	_revealing = false


func _spring_mimic(at: Vector2) -> void:
	var mimic := ENEMY_SCENE.instantiate() as Enemy
	mimic.setup(MIMIC, player, false, toughness())
	mimic.position = at
	enemies.add_child.call_deferred(mimic)
	Game.sfx("boss_warn", 0.0)
	Game.shake(0.4)
	show_banner("It was a Mimic!\nKill it for its treasure.", 2.0)


# Applies one reward and returns its banner line.
func _grant_loot(entry: Dictionary, at: Vector2) -> String:
	var text: String = entry.text
	match entry.id:
		"common_potion":
			player.hp = minf(player.stat("max_hp"), player.hp + player.stat("max_hp") * 0.3)
		"high_potion":
			player.hp = minf(player.stat("max_hp"), player.hp + player.stat("max_hp") * 0.6)
		"rejuvenation":
			player.hp = player.stat("max_hp")
		"attraction":
			for node in pickups.get_children():
				if node is XPGem:
					(node as XPGem).magnetize()
		"blessing":
			player.gain_xp(player.xp_to_next() - player.xp)
		"gold":
			var amount := GOLD_POUCH_PER_DAY * day()
			gold += amount
			text = text % amount
			Game.sfx("coins", 0.0)
		"fervor":
			_fervor_until = elapsed + FERVOR_DURATION
			player.add_timed_modifier({"stat": "haste", "add": FERVOR_HASTE}, FERVOR_DURATION)
		"bomb":
			Game.sfx("bomb", 0.0)
			Game.rumble(0.5, 0.8, 0.4)
			Game.shake(0.6)
			Game.fx("explosion", player.global_position, 4.0)
			Game.burst(player.global_position, Color(1, 0.6, 0.2), 60, 450.0)
			for node in enemies.get_children():
				var enemy := node as Enemy
				if enemy and player.global_position.distance_to(enemy.global_position) <= BOMB_RADIUS:
					var push := player.global_position.direction_to(enemy.global_position) * 300.0
					enemy.take_damage(BOMB_DAMAGE, push)
	if entry.id != "gold" and entry.id != "bomb":
		Game.sfx("loot", 0.0)
	_pop_loot_icon(at, Loot.icon(entry))
	return "%s: %s" % [entry.name, text]


# The reward's sprite floats up out of the chest and fades.
func _pop_loot_icon(at: Vector2, texture: Texture2D) -> void:
	var icon := Sprite2D.new()
	icon.texture = texture
	icon.scale = Vector2(2.5, 2.5)
	icon.position = at + Vector2(0, -10)
	get_tree().get_first_node_in_group("effects").add_child(icon)
	var tween := icon.create_tween().set_parallel()
	tween.tween_property(icon, "position:y", at.y - 60.0, 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(icon, "modulate:a", 0.0, 0.5).set_delay(0.8)
	tween.chain().tween_callback(icon.queue_free)


# His arrival scatters the horde: no kills, no drops, just a puff of smoke.
func _clear_swarm() -> void:
	for node in enemies.get_children():
		var enemy := node as Enemy
		if enemy and enemy.alive():
			Game.burst(enemy.global_position, Color(0.4, 0.3, 0.5), 6)
			enemy.queue_free()
	Game.shake(0.5)


func _on_boss_summon(at: Vector2, count: int, phase_two: bool) -> void:
	var start := randf() * TAU
	for i in count:
		var minion := ENEMY_SCENE.instantiate() as Enemy
		minion.setup(VEXCLAW if phase_two else DREADLING, player, false, toughness())
		minion.position = at + Vector2.RIGHT.rotated(start + TAU * i / count) * SUMMON_RING
		enemies.add_child(minion)
	Game.burst(at, Color(0.75, 0.35, 1.0), 16, 220.0)


func _on_enemy_killed(enemy: Enemy) -> void:
	kills += 1
	style.add_kill(enemy.elite)
	var bounty := enemy.data.gold * (5 if enemy.elite else 1) * (TRAIT_GOLD_MULT if enemy.affix != "" else 1.0)
	gold += roundi(bounty * gold_mult())
	if enemy.affix == "splitting":
		for i in SPLIT_COUNT:
			var at := enemy.global_position + Vector2.RIGHT.rotated(TAU * i / SPLIT_COUNT) * 30.0
			_spawn_at.call_deferred(enemy.data, at)
	if enemy.data.drops_golden_chest:
		_place_chest.call_deferred(enemy.global_position, LootChest.Kind.GOLDEN)
	if enemy.data.boss:
		_end_run("VICTORY", true)
		return
	Hints.show_hint("gems", "Walk near the green gems to collect XP. Each level lets you pick a new weapon or upgrade.")
	var gem := GEM_SCENE.instantiate() as XPGem
	gem.setup(ceili(enemy.data.xp * (5 if enemy.elite else 1) * xp_mult()), player)
	gem.position = enemy.global_position
	pickups.add_child.call_deferred(gem)
	if enemy.elite and enemy.data.essence:
		var corpse := CORPSE_SCENE.instantiate() as DevourCorpse
		corpse.setup(enemy.data.essence)
		corpse.position = enemy.global_position
		pickups.add_child.call_deferred(corpse)
		Hints.show_hint("devour", "An elite has fallen! Follow the colored arrow, stand on its glowing essence and hold {devour} to Devour it: a lasting power that costs a little max HP.")


func _on_player_devoured(essence: EssenceData) -> void:
	style.add(StyleMeter.DEVOUR_POINTS)
	show_banner("Devoured %s\n%s   -%d max HP" % [
		essence.display_name, essence.description, essence.max_hp_cost])


func _on_weapon_evolved(weapon: Weapon) -> void:
	Game.sfx("evolve", 0.0)
	Game.rumble(0.3, 0.6, 0.35)
	Game.shake(0.5)
	camera.punch(0.1, 0.9)
	Game.shockwave(player.global_position, Color(0.8, 0.5, 1.0), 220.0, 0.6)
	show_banner("%s EVOLVED\n%s" % [weapon.data.display_name.to_upper(), weapon.data.evolved_name], 3.0)


func _on_player_leveled_up() -> void:
	Game.shockwave(player.global_position, Color(1.0, 0.9, 0.5), 170.0)
	camera.set_base_zoom(_zoom_for_level())
	if not level_up.visible:
		_offer_next_level_up()


func _on_upgrade_chosen(upgrade: Resource) -> void:
	player.apply_upgrade(upgrade)
	# Make the pick land: a golden burst, a nudge, and its name on screen.
	var level := player.upgrade_level(upgrade)
	var tiers: PackedStringArray = upgrade.tier_names
	var title: String = tiers[level - 1] if level <= tiers.size() else upgrade.display_name
	if upgrade.max_level < 100:
		title += "  ·  Lv %d" % level
	show_banner(title, 1.2)
	Game.fx("spark", player.global_position, 2.5, Color(1, 0.9, 0.5))
	Game.burst(player.global_position, Color(1, 0.85, 0.35), 24, 220.0)
	Game.shake(0.15)
	if player.pending_level_ups == 0:
		_gather_gems()
	_offer_next_level_up()


# After the level-up screen, nearby gems fly in on their own.
func _gather_gems() -> void:
	for node in pickups.get_children():
		var gem := node as XPGem
		if gem and gem.global_position.distance_to(player.global_position) < LEVEL_UP_MAGNET:
			gem.magnetize()


# Shows one level-up screen per pending level, one after another.
func _offer_next_level_up() -> void:
	if _over or player.pending_level_ups == 0:
		return
	player.pending_level_ups -= 1
	var offers := player.available_upgrades(UPGRADE_POOL)
	offers.shuffle()
	offers.resize(mini(OFFERS_PER_LEVEL, offers.size()))
	if offers.is_empty():
		offers = [FALLBACK_UPGRADE]
	level_up.open(offers, player)


# More of the world comes into view as you grow.
func _zoom_for_level() -> float:
	return lerpf(1.0, MIN_ZOOM, clampf((player.level - 1) / 30.0, 0.0, 1.0))


func revive_cost() -> int:
	return REVIVE_BASE_COST * (1 << revives)


## Training bought at a shrine: its modifiers last the rest of the journey.
func add_training(training: TrainingData) -> void:
	training_ranks[training.id] = int(training_ranks.get(training.id, 0)) + 1
	var old_max := player.stat("max_hp")
	for mod: Dictionary in training.per_rank:
		player.modifiers.append(mod.duplicate())
	player.hp += maxf(0.0, player.stat("max_hp") - old_max)


func _on_shrine_closed() -> void:
	Save.save_journey(_snapshot())
	if day() == 19:
		show_banner("Tomorrow, the Demon King.", 2.5)
	else:
		show_banner("Your journey continues... (saved)", 2.0)


# Everything needed to rebuild this hero at the shrine just visited.
func _snapshot() -> Dictionary:
	var upgrades := []
	for upgrade: Resource in player.upgrade_levels:
		upgrades.append([upgrade.resource_path, player.upgrade_levels[upgrade]])
	var essences := []
	for essence: EssenceData in player.essences:
		essences.append([essence.resource_path, player.essences[essence]])
	return {
		"day": day(), "level": player.level, "xp": player.xp,
		"hp_fraction": player.hp / player.stat("max_hp"), "gold": gold, "kills": kills,
		"revives": revives, "training": training_ranks.duplicate(), "upgrades": upgrades,
		"essences": essences, "seed": world.seed_value,
		"flask_max": player.flask_max, "flask_heal": player.flask_heal, "covenant": covenant,
	}


# Continue from a shrine checkpoint: same hero, same world, start of that day.
func _restore(journey: Dictionary) -> void:
	world.set_seed(int(journey.seed))
	var saved_day := int(journey.day)
	elapsed = (saved_day - 1) * SECONDS_PER_DAY + 0.5
	for shrine_day: int in SHRINE_DAYS:
		if shrine_day <= saved_day:
			_shrines_done.append(shrine_day)
	gold = int(journey.gold)
	kills = int(journey.kills)
	revives = int(journey.revives)
	player.level = int(journey.level)
	player.xp = int(journey.xp)
	for entry: Array in journey.upgrades:
		for i in int(entry[1]):
			player.apply_upgrade(load(entry[0]))
	for entry: Array in journey.essences:
		for i in int(entry[1]):
			player.add_essence(load(entry[0]))
	for training: TrainingData in SHRINE.TRAININGS:
		for i in int(journey.training.get(training.id, 0)):
			add_training(training)
	player.flask_max = int(journey.get("flask_max", player.flask_max))
	player.flask_heal = float(journey.get("flask_heal", player.flask_heal))
	player.refill_flask()
	var sealed := String(journey.get("covenant", ""))
	if sealed != "thirst":  # Thirst's price was paid at the shrine
		set_covenant(sealed)
	else:
		covenant = sealed
	player.hp = player.stat("max_hp") * float(journey.hp_fraction)
	if saved_day >= RUINS_FROM_DAY:
		world.biome = "ruins"
		mood.color = MOOD.ruins
	_spawn_timer = GRACE_PERIOD
	show_banner("Day %d. Your journey continues." % saved_day, 2.5)


func _on_player_died() -> void:
	# The goddess can pull you back, for a price that doubles every time.
	_awaiting_revive = true
	Save.mark_fallen(day())  # closing the game now can't undo it
	primary_button.disabled = true  # until the offer is on screen
	secondary_button.disabled = true
	get_tree().paused = true
	Game.rumble(0.6, 1.0, 0.6)
	Game.sfx("defeat", 0.0)
	Game.sfx("doom", 0.0)
	Game.sfx("toll", 0.0)
	Music.muffle(true)
	banner.hide()
	await moments.you_died()
	if not _awaiting_revive:
		return
	var cost := revive_cost()
	var can_pay := gold >= cost
	end_text.text = "The goddess reaches for you. She can pull you back,\nbut her light grows weaker each time.\n\nRevive: %d gold   (you have %d)" % [cost, gold]
	primary_button.text = "Revive  (%dg)" % cost
	secondary_button.text = "Accept your fate"
	secondary_button.show()
	_show_end_menu(primary_button if can_pay else secondary_button)
	primary_button.disabled = not can_pay


func _revive() -> void:
	var cost := revive_cost()
	if gold < cost:
		return
	_awaiting_revive = false
	Save.clear_fallen()
	revives += 1
	gold -= cost  # after revives changes, so the HUD shows the next price
	end_menu.hide()
	moments.clear()
	Music.muffle(false)
	get_tree().paused = false
	player.revive(REVIVE_HP, REVIVE_INVULN)
	# She clears a little room around you; the Demon King is untouched.
	for node in enemies.get_children():
		var enemy := node as Enemy
		if enemy and not enemy.data.boss and enemy.alive() \
				and enemy.global_position.distance_to(player.global_position) < REVIVE_CLEAR_RADIUS:
			Game.burst(enemy.global_position, Color(1, 0.95, 0.7), 6)
			enemy.queue_free()
	Game.fx("spark", player.global_position, 4.0, Color(1, 0.95, 0.6))
	Game.shake(0.4)
	Game.sfx("level_up", 0.0)
	show_banner("The goddess pulls you back...\nher light grows weaker.", 2.5)


func _end_run(message: String, won := false) -> void:
	_over = true
	_awaiting_revive = false
	get_tree().paused = false
	Game.sfx("victory" if won else "defeat", 0.0)
	if won:
		Game.sfx("toll", 0.0)
	Music.stop(4.0 if won else 3.0)
	Save.end_journey(day(), won)
	enemies.process_mode = Node.PROCESS_MODE_DISABLED
	banner.hide()
	end_menu.hide()
	if won:
		await moments.felled("Demon King Felled")
		await get_tree().create_timer(1.2).timeout
		moments.clear()
		var choice: String = await ending.play()
		Save.record_ending(choice)
		var chosen: Dictionary = ending.ENDINGS[choice]
		message = "%s\n%s" % [chosen.title, chosen.subtitle]
	end_text.text = "%s\n\nDay %d  ·  Level %d  ·  %d kills  ·  %d devoured  ·  %d revives" % [
		message, day(), player.level, kills, player.devour_count(), revives]
	primary_button.text = Game.prompts("Begin a new journey  ({restart})")
	secondary_button.text = "Title screen"
	secondary_button.show()
	_show_end_menu(primary_button)


func _show_end_menu(focus: Button) -> void:
	end_menu.show()
	primary_button.disabled = true
	secondary_button.disabled = true
	await get_tree().create_timer(END_MENU_DELAY).timeout
	primary_button.disabled = _awaiting_revive and gold < revive_cost()
	secondary_button.disabled = false
	focus.grab_focus()


func _on_primary() -> void:
	if _awaiting_revive:
		_revive()
	else:
		Game.sfx("click", 0.0)
		Save.resume = false
		get_tree().reload_current_scene()


func _on_secondary() -> void:
	if _awaiting_revive:
		_awaiting_revive = false
		_end_run("You have fallen in battle...\nThe cycle remains unbroken.")
	else:
		Game.sfx("click", 0.0)
		get_tree().change_scene_to_file(TITLE_SCENE)
