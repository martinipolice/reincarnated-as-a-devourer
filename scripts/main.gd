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
## Normal spawns slow down this much while the Demon King is alive.
const BOSS_SPAWN_SLOWDOWN := 2.0
const SANCTUARY_SCENE := "res://scenes/ui/sanctuary.tscn"
const SANCTUARY := preload("res://scripts/ui/sanctuary.gd")
## Ignore end-screen input briefly so a held key doesn't skip it.
const END_MENU_DELAY := 0.8

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const BOSS_SCENE := preload("res://scenes/boss.tscn")
const GEM_SCENE := preload("res://scenes/xp_gem.tscn")
const CORPSE_SCENE := preload("res://scenes/devour_corpse.tscn")
const DREADLING := preload("res://data/enemies/dreadling.tres")
const VEXCLAW := preload("res://data/enemies/vexclaw.tres")
const PLAGUEWING := preload("res://data/enemies/plaguewing.tres")
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
]
const OFFERS_PER_LEVEL := 3

var elapsed := 0.0
var kills := 0
var gold := 0
var boss: Boss
var _spawn_timer := GRACE_PERIOD
var _elite_timer := ELITE_INTERVAL
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
@onready var floor_sprite: Sprite2D = $Floor


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
	end_menu.hide()
	banner.hide()
	boss_label.hide()
	boss_bar.hide()


func day() -> int:
	return mini(int(elapsed / SECONDS_PER_DAY) + 1, FINAL_DAY)


func _process(delta: float) -> void:
	_follow_floor()
	if _over:
		if Input.is_action_just_pressed("restart") and not again_button.disabled:
			_play_again()
		return

	elapsed += delta
	if day() >= FINAL_DAY and not _boss_spawned:
		_spawn_boss()

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = maxf(0.45, 1.3 - day() * 0.05)
		if is_instance_valid(boss):
			_spawn_timer *= BOSS_SPAWN_SLOWDOWN
		# Bigger packs as the days pass: 1 per spawn on Days 1-4, 2 on 5-9, ...
		for i in 1 + day() / 5:
			_spawn_enemy()

	_elite_timer -= delta
	if _elite_timer <= 0.0:
		_elite_timer = ELITE_INTERVAL
		_spawn_enemy(true)

	_update_hud()


# The floor sprite follows the player so it looks endless, but only in jumps
# of one full texture repeat; any smaller step would slide the pattern.
func _follow_floor() -> void:
	var period := Vector2(floor_sprite.texture.get_size()) * floor_sprite.scale
	floor_sprite.position = (player.position / period).floor() * period


func _update_hud() -> void:
	var text := "DAY %d / %d     Lv %d\nHP %d / %d\nKills %d   Gold %d" % [
		day(), FINAL_DAY, player.level, ceili(player.hp), player.stat("max_hp"), kills, gold]
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
	enemy.setup(_pick_enemy(elite), player, elite)
	enemy.position = player.position + Vector2.RIGHT.rotated(randf() * TAU) * distance
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
	boss.slam_started.connect(func() -> void: show_banner("He gathers dark power...", 1.2))
	enemies.add_child(boss)
	boss_label.text = DEMON_KING.display_name.to_upper()
	boss_label.show()
	boss_bar.show()
	show_banner("DAY 20\nThe sky darkens... The Demon King descends.", 3.5)


func _on_enemy_killed(enemy: Enemy) -> void:
	kills += 1
	gold += enemy.data.gold * (5 if enemy.elite else 1)
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
