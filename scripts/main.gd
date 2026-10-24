extends Node2D
## Run controller: the day clock, the spawn director, elites and the boss,
## level-ups, the HUD and the end of the run (which banks gold for the
## Goddess's Sanctuary).

const SECONDS_PER_DAY := 30.0  # MVP: 20 days in 10 minutes
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
const TOUGHNESS_PER_DAY := 0.125
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
const GOLD_POUCH_PER_DAY := 20
## How far from the Demon King his summoned minions appear.
const SUMMON_RING := 80.0
## Biomes by day; the Demon King's temple arena has this radius.
const RUINS_FROM_DAY := 10
const ARENA_RADIUS := 650.0
const MOOD := {
	"forest": Color(1.0, 0.98, 0.94),
	"ruins": Color(0.86, 0.8, 0.9),
	"temple": Color(0.78, 0.62, 0.66),
}
const SANCTUARY_SCENE := "res://scenes/ui/sanctuary.tscn"
const SANCTUARY := preload("res://scripts/ui/sanctuary.gd")
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
var gold := 0
var boss: Boss
var _spawn_timer := GRACE_PERIOD
var _elite_timer := ELITE_INTERVAL
var _chest_timer := CHEST_FIRST
var _event_timer := EVENT_FIRST
var _fervor_until := 0.0
var _boss_spawned := false
var _devour_hint_shown := false
var _over := false
var _banner_tween: Tween

@onready var player: Player = $Player
@onready var enemies: Node2D = $Enemies
@onready var pickups: Node2D = $Pickups
@onready var level_up: CanvasLayer = $LevelUp
@onready var info_label: Label = $HUD/Info
@onready var xp_bar: ProgressBar = $HUD/XPBar
@onready var boss_label: Label = $HUD/BossLabel
@onready var boss_bar: ProgressBar = $HUD/BossBar
@onready var banner: Label = $HUD/Banner
@onready var end_menu: Control = $HUD/EndMenu
@onready var end_text: Label = %EndText
@onready var again_button: Button = %Again
@onready var sanctuary_button: Button = %ToSanctuary
@onready var world: ChunkWorld = $World
@onready var mood: CanvasModulate = $Mood


func _ready() -> void:
	Game.enemy_killed.connect(_on_enemy_killed)
	player.died.connect(_on_player_died)
	player.leveled_up.connect(_on_player_leveled_up)
	player.devoured.connect(_on_player_devoured)
	player.weapon_evolved.connect(_on_weapon_evolved)
	level_up.chosen.connect(_on_upgrade_chosen)
	again_button.pressed.connect(_play_again)
	sanctuary_button.pressed.connect(_go_to_sanctuary)
	_apply_training()
	player.apply_upgrade(STARTING_WEAPON)
	world.set_origin(player.position)
	mood.color = MOOD.forest
	end_menu.hide()
	banner.hide()
	boss_label.hide()
	boss_bar.hide()


func day() -> int:
	return mini(int(elapsed / SECONDS_PER_DAY) + 1, FINAL_DAY)


func toughness() -> float:
	return 1.0 + TOUGHNESS_PER_DAY * (day() - 1)


func _process(delta: float) -> void:
	world.update(player.position, get_viewport_rect().size)
	if _over:
		if Input.is_action_just_pressed("restart") and not again_button.disabled:
			_play_again()
		return

	elapsed += delta
	if day() >= RUINS_FROM_DAY and world.biome == "forest":
		world.biome = "ruins"
		create_tween().tween_property(mood, "color", MOOD.ruins, 4.0)
		show_banner("The forest withers into ancient ruins...", 3.0)
	if day() >= FINAL_DAY and not _boss_spawned:
		_spawn_boss()

	# The waves stop once the Demon King arrives: Day 20 is a duel.
	if not _boss_spawned:
		_spawn_waves(delta)
	_chest_timer -= delta
	if _chest_timer <= 0.0:
		_chest_timer = CHEST_INTERVAL
		_spawn_chest()

	_update_hud()


func _physics_process(_delta: float) -> void:
	Crowd.rebuild(enemies.get_children())


func _exit_tree() -> void:
	Crowd.clear()


func _spawn_waves(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = maxf(0.45, 1.3 - day() * 0.05) / wave_intensity()
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


func _update_hud() -> void:
	var text := "DAY %d / %d     Lv %d\nHP %d / %d\nKills %d   Gold %d" % [
		day(), FINAL_DAY, player.level, ceili(player.hp), player.stat("max_hp"), kills, gold]
	if elapsed < _fervor_until:
		text += "\nGoddess's Fervor: %ds" % ceili(_fervor_until - elapsed)
	if player.devour_count() > 0:
		var parts := []
		for essence: EssenceData in player.essences:
			parts.append("%s x%d" % [essence.display_name.get_slice(" ", 0), player.essences[essence]])
		text += "\nDevoured: " + ", ".join(parts)
	info_label.text = text
	xp_bar.max_value = player.xp_to_next()
	xp_bar.value = player.xp
	if is_instance_valid(boss):
		boss_bar.max_value = boss.max_hp
		boss_bar.value = boss.hp


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
	enemy.setup(_pick_enemy(elite), player, elite, toughness())
	enemy.position = _spawn_point(distance)
	enemies.add_child(enemy)


# Testing shortcuts. Only active in debug builds (running from the editor),
# never in an exported game.
func _unhandled_input(event: InputEvent) -> void:
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
	boss.enraged.connect(func() -> void: show_banner("The Demon King is enraged!", 2.0))
	_clear_swarm()
	world.make_arena(player.position, ARENA_RADIUS)
	# The goddess's last gift: the duel starts at full strength.
	var healed := player.stat("max_hp") - player.hp
	player.hp = player.stat("max_hp")
	Game.fx("spark", player.global_position, 3.0, Color(1, 0.95, 0.6))
	if healed >= 1.0:
		Game.float_text(player.global_position, "+%d HP" % roundi(healed), Color(1, 0.95, 0.6))
	create_tween().tween_property(mood, "color", MOOD.temple, 2.0)
	enemies.add_child(boss)
	boss_label.text = DEMON_KING.display_name.to_upper()
	boss_label.show()
	boss_bar.show()
	show_banner("DAY 20\nThe sky darkens... The Demon King descends.", 3.5)


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
	Game.sfx("chest_open", 0.0)
	Game.fx("spark", chest.global_position, 3.0 if golden else 2.0, Color(1, 0.9, 0.5))
	Game.shake(0.35 if golden else 0.2)
	Game.burst(chest.global_position, Color(1, 0.85, 0.35), 50 if golden else 25, 260.0)
	var hurt := player.hp < player.stat("max_hp") * 0.9
	var first := Loot.roll(hurt)
	var lines := [_grant_loot(first, chest.global_position)]
	if golden:
		var second := Loot.roll(hurt, first.id)
		lines.append(_grant_loot(second, chest.global_position + Vector2(24, 0)))
	var title := "GOLDEN CHEST\n" if golden else ""
	show_banner(title + "\n".join(lines), 2.5 if golden else 2.0)


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
	gold += enemy.data.gold * (5 if enemy.elite else 1)
	if enemy.data.drops_golden_chest:
		_place_chest.call_deferred(enemy.global_position, LootChest.Kind.GOLDEN)
	if enemy.data.boss:
		_end_run("VICTORY\n\nThe Demon King falls to his knees...\n\"Finally... Tell her... I waited.\"", true)
		return
	var gem := GEM_SCENE.instantiate() as XPGem
	gem.setup(enemy.data.xp * (5 if enemy.elite else 1), player)
	gem.position = enemy.global_position
	pickups.add_child.call_deferred(gem)
	if enemy.elite and enemy.data.essence:
		var corpse := CORPSE_SCENE.instantiate() as DevourCorpse
		corpse.setup(enemy.data.essence)
		corpse.position = enemy.global_position
		pickups.add_child.call_deferred(corpse)
		if not _devour_hint_shown:
			_devour_hint_shown = true
			show_banner("An elite has fallen.\nStand on its essence and hold E or Space to Devour.", 4.0)


func _on_player_devoured(essence: EssenceData) -> void:
	show_banner("Devoured %s\n%s   -%d max HP" % [
		essence.display_name, essence.description, essence.max_hp_cost])


func _on_weapon_evolved(weapon: Weapon) -> void:
	Game.sfx("evolve", 0.0)
	Game.shake(0.5)
	show_banner("%s EVOLVED\n%s" % [weapon.data.display_name.to_upper(), weapon.data.evolved_name], 3.0)


func _on_player_leveled_up() -> void:
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
	_offer_next_level_up()


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
	_update_hud()  # the HUD freezes while paused, so show the new level now
	level_up.open(offers, player)


func _on_player_died() -> void:
	_end_run("You have fallen in battle...\nThe cycle remains unbroken.")


# Sanctuary training ranks become modifiers, like any other bonus.
func _apply_training() -> void:
	for training: TrainingData in SANCTUARY.TRAININGS:
		for rank in Save.training_rank(training):
			for mod: Dictionary in training.per_rank:
				player.modifiers.append(mod.duplicate())
	player.hp = player.stat("max_hp")


func _end_run(message: String, won := false) -> void:
	_over = true
	Game.sfx("victory" if won else "defeat", 0.0)
	Save.add_gold(gold)
	Save.record_run(day(), won)
	Save.save_game()
	_update_hud()
	enemies.process_mode = Node.PROCESS_MODE_DISABLED
	banner.hide()
	end_text.text = "%s\n\nDay %d  ·  Level %d  ·  %d kills  ·  %d devoured\n+%d gold  (%d banked)" % [
		message, day(), player.level, kills, player.devour_count(), gold, Save.gold()]
	end_menu.show()
	again_button.disabled = true
	sanctuary_button.disabled = true
	await get_tree().create_timer(END_MENU_DELAY).timeout
	again_button.disabled = false
	sanctuary_button.disabled = false
	sanctuary_button.grab_focus()


func _play_again() -> void:
	get_tree().reload_current_scene()


func _go_to_sanctuary() -> void:
	Game.sfx("click", 0.0)
	get_tree().change_scene_to_file(SANCTUARY_SCENE)
