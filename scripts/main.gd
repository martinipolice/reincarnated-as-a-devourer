extends Node2D
## The journey controller: one life, twenty days. Runs the day clock, the
## areas, level-ups, kills and rewards, the goddess's shrines (checkpointing
## the journey there), the Demon King's arrival, and on death a revive for
## gold or the end of the journey. The horde is SpawnDirector's, chests are
## LootDirector's, the music RunMusic's, and the save JourneyRecord's.

## For the HUD, which listens instead of reading the run every frame.
signal gold_changed(gold: int, revive_cost: int)
signal day_changed(day: int, final_day: int, next_shrine: int)

const SECONDS_PER_DAY := 60.0  # 20 days in 20 minutes
const FINAL_DAY := 20
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
const ENDING := preload("res://scripts/ui/ending.gd")
const VIGNETTE := preload("res://scripts/ui/vignette.gd")
## The camera pulls back from 1.0 toward this as you level (30 levels).
const MIN_ZOOM := 0.86
## The goddess finds you on the original game's lore days.
const SHRINE_DAYS := [5, 10, 15, 19]
const SHRINE_SCENE := preload("res://scenes/ui/shrine.tscn")
const SHRINE := preload("res://scripts/ui/shrine.gd")
const PAUSE_MENU := preload("res://scripts/ui/pause_menu.gd")
## After a level-up, gems this close fly to you, so none are left behind.
const LEVEL_UP_MAGNET := 700.0
const TRAIT_GOLD_MULT := 2.0
const MINI_BOSS_GOLD_PER_DAY := 15
const MINI_BOSS_STYLE := 40.0
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
## Reviving costs gold, doubling each time: 800, 1600, 3200...
const REVIVE_BASE_COST := 800
const REVIVE_HP := 0.5  # fraction of max HP you come back with
const REVIVE_CLEAR_RADIUS := 450.0
const REVIVE_INVULN := 2.5
const TITLE_SCENE := "res://scenes/ui/title.tscn"
## Ignore end-screen input briefly so a held key doesn't skip it.
const END_MENU_DELAY := 0.8

const GEM_SCENE := preload("res://scenes/xp_gem.tscn")
const CORPSE_SCENE := preload("res://scenes/devour_corpse.tscn")
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
	preload("res://data/weapons/doom_bell.tres"),
	preload("res://data/items/hunger.tres"),
	preload("res://data/items/wooden_guard.tres"),
	preload("res://data/items/leather_treads.tres"),
	preload("res://data/items/stamina.tres"),
	preload("res://data/items/fury.tres"),
	preload("res://data/items/magnet_charm.tres"),
	preload("res://data/items/vigor.tres"),
]
const OFFERS_PER_LEVEL := 3
## Level-up control: rerolls and banishes to start a journey with (the
## goddess sells more), and the gold a skipped level-up pays per day.
const START_REROLLS := 2
const START_BANISHES := 1
const SKIP_GOLD_PER_DAY := 10
const HUNGER := preload("res://data/items/hunger.tres")

var elapsed := 0.0
var kills := 0
var gold := 0:
	set(value):
		gold = value
		gold_changed.emit(gold, revive_cost())
var revives := 0
var best_rank := 0  # the style meter's best this journey
var rerolls := START_REROLLS
var banishes := START_BANISHES
## Upgrades banished at a level-up: never offered again this journey.
var banished: Array[Resource] = []
var covenant := ""
## TrainingData.id -> ranks bought at the goddess's shrines this journey.
var training_ranks := {}
## The journey is over (won, or the hero accepted their fate).
var over := false
## The hero has fallen and the goddess's offer is open.
var awaiting_revive := false
var boss_spawned := false
var boss: Boss:
	get:
		return spawner.boss
var mini_boss: Boss:
	get:
		return spawner.mini_boss

var spawner: SpawnDirector
var loot: LootDirector
var music: RunMusic
var record := JourneyRecord.new()
var style: StyleMeter
var atmosphere: Atmosphere
var shrine: CanvasLayer
var pause_menu: CanvasLayer
var ending: CanvasLayer
var results: Results
var devour_choice: DevourChoice
var _unlocked_at_start: Array[String] = []  # starting weapons, to spot new ones
var _shrines_done := []
var _restoring := false
var _last_day := 0
var _banner_tween: Tween

@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera2D
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
	Enemy.damage_log.clear()
	spawner = SpawnDirector.new(self)
	add_child(spawner)
	spawner.mini_boss_arrived.connect(_on_mini_boss_arrived)
	loot = LootDirector.new(self)
	add_child(loot)
	music = RunMusic.new(self)
	add_child(music)
	Game.enemy_killed.connect(_on_enemy_killed)
	player.died.connect(_on_player_died)
	player.leveled_up.connect(_on_player_leveled_up)
	player.devoured.connect(_on_player_devoured)
	player.weapon_evolved.connect(_on_weapon_evolved)
	player.resonated.connect(_on_resonated)
	player.hunger_rose.connect(_on_hunger_rose)
	devour_choice = DevourChoice.new()
	add_child(devour_choice)
	player.essence_taken.connect(func(essence: EssenceData) -> void:
		devour_choice.chosen.connect(func(alt: bool) -> void: player.devour(essence, alt), CONNECT_ONE_SHOT)
		devour_choice.open(essence, player))
	level_up.chosen.connect(_on_upgrade_chosen)
	level_up.rerolled.connect(_on_rerolled)
	level_up.banished.connect(_on_banished)
	level_up.skipped.connect(_on_level_up_skipped)
	primary_button.pressed.connect(_on_primary)
	secondary_button.pressed.connect(_on_secondary)
	shrine = SHRINE_SCENE.instantiate()
	add_child(shrine)
	shrine.closed.connect(_on_shrine_closed)
	pause_menu = PAUSE_MENU.new()
	add_child(pause_menu)
	results = Results.new()
	add_child(results)
	results.again.connect(_on_primary)
	results.to_title.connect(_on_secondary)
	_unlocked_at_start = Unlocks.unlocked(Save.data)
	for button: Button in [primary_button, secondary_button]:
		button.theme_type_variation = &"MenuItem"
		button.add_theme_font_size_override("font_size", 26)
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
		player.apply_upgrade(_starting_weapon())
	Save.resume = false
	end_menu.hide()
	banner.hide()
	Music.muffle(false)
	atmosphere.set_area("ruins" if world.biome == "ruins" else "forest")
	camera.set_base_zoom(_zoom_for_level(), 0.0)
	style = StyleMeter.new()
	add_child(style)
	style.rank_changed.connect(_on_rank_changed)
	style.rank_changed.connect(func(rank: int, _rising: bool) -> void: best_rank = maxi(best_rank, rank))
	player.hurt.connect(style.on_hurt)
	hud.bind_style(style)
	if covenant == "":
		set_covenant("")  # clears a multiplier left from a previous run
	hud.bind(player, self)
	if Benchmark.requested() > 0:
		var bench := Benchmark.new()
		bench.count = Benchmark.requested()
		add_child(bench)
	gold = gold  # announce the starting gold and revive price
	_last_day = 0
	moments.area_card("The Fallen Ruins" if day() >= RUINS_FROM_DAY else "The Whispering Forest")
	Hints.show_hint("move", "Move with {move}. Your weapons attack on their own: focus on staying alive.")
	Hints.show_hint("pause", "Press {pause} any time to pause, check your build, read how to play, or change settings.")


func day() -> int:
	return mini(int(elapsed / SECONDS_PER_DAY) + 1, FINAL_DAY)


func toughness() -> float:
	return spawner.toughness()


func _process(delta: float) -> void:
	world.update(player.position, get_viewport_rect().size)
	if over:
		return  # the results screen takes it from here

	elapsed += delta
	if day() != _last_day:
		_last_day = day()
		day_changed.emit(day(), FINAL_DAY, next_shrine_day())
		style.scale = 1.0 + StyleMeter.DAY_SCALE * (day() - 1)
		if next_shrine_day() == day() + 1:
			Hints.show_hint("shrine_soon", "The goddess finds you tomorrow. At her shrine, gold buys training. Gold also pays for a revive if you fall, so don't spend it all.")
	if player.hp < player.stat("max_hp") * FLASK_HINT_HP and player.flask_charges > 0:
		Hints.show_hint("flask", "You're hurt! Press {flask} to drink the Goddess's Tears. She refills them at every shrine, so use them.")
	if day() in SHRINE_DAYS and not day() in _shrines_done and not level_up.visible:
		_shrines_done.append(day())
		shrine.open(day(), self)
	if day() >= RUINS_FROM_DAY and world.biome == "forest":
		world.biome = "ruins"
		create_tween().tween_property(mood, "color", MOOD.ruins, 4.0)
		atmosphere.set_area("ruins")
		moments.area_card("The Fallen Ruins")
	if day() >= FINAL_DAY and not boss_spawned:
		_spawn_boss()
	if not boss_spawned:
		spawner.update(delta)
	loot.update(delta)
	_update_status()
	music.update(delta)


func _physics_process(_delta: float) -> void:
	Crowd.rebuild(enemies.get_children())


func _exit_tree() -> void:
	Crowd.clear()
	Hints.clear()  # however the run is left: quit, title or a new journey


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


# The weapon chosen on the title screen, if it's unlocked; else the Blade.
func _starting_weapon() -> WeaponData:
	var path := String(Save.data.get("start_weapon", ""))
	if path in Unlocks.unlocked(Save.data):
		return load(path)
	return STARTING_WEAPON


## The next day the goddess will appear, or 0 if she won't again.
func next_shrine_day() -> int:
	for shrine_day: int in SHRINE_DAYS:
		if shrine_day > day() or (shrine_day == day() and not shrine_day in _shrines_done):
			return shrine_day
	return 0


# The HUD's status line: timed buffs and what you've devoured.
func _update_status() -> void:
	var parts := []
	var hunger := player.hunger_tier()
	if hunger > 0:
		parts.append(tr("Hunger: %s") % tr(Hunger.NAMES[hunger]))
	if covenant != "":
		parts.append(COVENANTS[covenant][0])
	if elapsed < loot.fervor_until:
		parts.append(tr("Goddess's Fervor  %ds") % ceili(loot.fervor_until - elapsed))
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


# Testing shortcuts. Only active in debug builds (running from the editor),
# never in an exported game.
func _unhandled_input(event: InputEvent) -> void:
	# Esc pauses, unless a screen (level-up, shrine, death) already has.
	if event.is_action_pressed("pause") and not over and not get_tree().paused:
		get_viewport().set_input_as_handled()
		pause_menu.open(self)
		return
	if not OS.is_debug_build() or over or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_F1:
			spawner.spawn_enemy(true, 250.0)
			show_banner("[debug] Elite spawned", 1.0)
		KEY_F2:
			player.gain_xp(player.xp_to_next() - player.xp)
		KEY_F3:
			if not boss_spawned:
				elapsed = (FINAL_DAY - 1) * SECONDS_PER_DAY
		KEY_F4:
			player.hp = player.stat("max_hp")
			show_banner("[debug] Healed", 1.0)


# A mid-journey guardian: its own attack cycle, a bar and a title card.
func _on_mini_boss_arrived(guardian: Boss, data: EnemyData) -> void:
	guardian.enraged.connect(func() -> void: show_banner(tr("%s is enraged!") % data.display_name, 2.0))
	hud.show_boss(guardian, data.display_name)
	moments.area_card(data.display_name)
	Game.sfx("doom", 0.0)
	Game.sfx("boss_warn", 0.0)
	Game.shockwave(guardian.global_position, Color(0.9, 0.3, 0.3), 220.0, 0.7)
	camera.punch(0.08, 1.0)
	Hints.show_hint("mini_boss", "A guardian of this land! Red markings show where it will strike: step out of them, then hit back. Waves thin out while it lives.")


# A guardian's reward: a golden chest, a purse, an essence to Devour.
func _on_mini_boss_killed(enemy: Enemy) -> void:
	var at := enemy.global_position
	Save.count_felled(enemy.data.display_name)
	gold += roundi(MINI_BOSS_GOLD_PER_DAY * day() * gold_mult())
	style.add(MINI_BOSS_STYLE)
	loot.place_chest.call_deferred(at, LootChest.Kind.GOLDEN)
	var corpse := CORPSE_SCENE.instantiate() as DevourCorpse
	corpse.setup((SpawnDirector.KINDS.pick_random() as EnemyData).essence)
	corpse.position = at + Vector2(40, 0)
	pickups.add_child.call_deferred(corpse)
	moments.felled(tr("%s Felled") % enemy.data.display_name)
	get_tree().create_timer(2.5).timeout.connect(moments.clear)
	camera.punch(0.1, 0.9)
	show_banner("A golden chest, gold, and an essence remain.", 2.5)


func _spawn_boss() -> void:
	boss_spawned = true
	var king := spawner.spawn_boss()
	king.enraged.connect(func() -> void:
		show_banner("The Demon King is enraged!", 2.0)
		Game.sfx("toll", 0.0)
		Music.play("boss_enraged", 1.0))
	# His arrival: a doom hit and a toll under the boss track's own opening.
	Game.sfx("doom", 0.0)
	Game.sfx("toll", 0.0)
	Music.play("boss_opening", 0.4, "boss")
	spawner.clear_swarm()
	world.make_arena(player.position, ARENA_RADIUS)
	# The goddess's last gift: the duel starts at full strength.
	var healed := player.stat("max_hp") - player.hp
	player.hp = player.stat("max_hp")
	Game.fx("spark", player.global_position, 3.0, Color(1, 0.95, 0.6))
	if healed >= 1.0:
		Game.float_text(player.global_position, tr("+%d HP") % roundi(healed), Color(1, 0.95, 0.6))
	create_tween().tween_property(mood, "color", MOOD.temple, 2.0)
	atmosphere.set_area("temple")
	camera.punch(0.15, 1.6)
	Game.shockwave(king.global_position, Color(0.9, 0.2, 0.3), 260.0, 0.8)
	enemies.add_child(king)
	hud.show_boss(king, king.data.display_name)
	moments.area_card("Temple of the Demon King")
	show_banner("The sky darkens... The Demon King descends.", 3.5)
	Hints.show_hint("boss", "A red mark on the ground shows where he will slam: step out of it. Dodge his rings of dark orbs, and drink your Tears when low.")


func _on_enemy_killed(enemy: Enemy) -> void:
	kills += 1
	record.count_kill(enemy)
	style.add_kill(enemy.elite)
	var bounty := enemy.data.gold * (5 if enemy.elite else 1) * (TRAIT_GOLD_MULT if enemy.affix != "" else 1.0)
	gold += roundi(bounty * gold_mult())
	if enemy.affix == "splitting":
		spawner.split(enemy)
	if enemy.data.drops_golden_chest:
		loot.place_chest.call_deferred(enemy.global_position, LootChest.Kind.GOLDEN)
	if enemy.data.final:
		_end_run("VICTORY", true)
		return
	if enemy == mini_boss:
		_on_mini_boss_killed(enemy)
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
	Save.count_devour()
	style.add(StyleMeter.DEVOUR_POINTS)
	show_banner(tr("Devoured %s\n%s   -%d max HP") % [
		essence.display_name, essence.description, essence.max_hp_cost])


func _on_resonated(resonance: String, description: String) -> void:
	if over or _restoring:
		return
	Game.sfx("evolve", 0.0, 0.8)
	Game.shockwave(player.global_position, Color(0.6, 0.9, 1.0), 200.0, 0.6)
	show_banner(tr("Resonance: %s\n%s") % [resonance, description], 3.0)
	style.add(StyleMeter.DEVOUR_POINTS)
	Hints.show_hint("resonance", "Two essences resonated! Holding 2 or more of certain pairs awakens a lasting bonus. Your build screen (pause) lists them.")


func _on_hunger_rose(tier: int) -> void:
	if _restoring:
		return
	Game.sfx("doom", 0.0, 1.3)
	Game.shockwave(player.global_position, Hunger.COLORS[tier], 180.0, 0.5)
	show_banner(tr("Your Hunger grows: %s
%s") % [tr(Hunger.NAMES[tier]), tr(Hunger.WARNINGS[tier])], 3.0)
	Hints.show_hint("hunger", "Each Devour feeds your Hunger. It makes you stronger, but Devours heal less, elites come more often, and the goddess gives less.")


func _on_weapon_evolved(weapon: Weapon) -> void:
	Game.sfx("evolve", 0.0)
	Game.rumble(0.3, 0.6, 0.35)
	Game.shake(0.5)
	camera.punch(0.1, 0.9)
	Game.shockwave(player.global_position, Color(0.8, 0.5, 1.0), 220.0, 0.6)
	show_banner(tr("%s EVOLVED\n%s") % [weapon.data.display_name.to_upper(), weapon.data.evolved_name], 3.0)


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
		title += tr("  ·  Lv %d") % level
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
	if over or player.pending_level_ups == 0:
		return
	player.pending_level_ups -= 1
	level_up.open(_deal_offers(), player, rerolls, banishes)


func _deal_offers(keep: Array = []) -> Array:
	var offers := keep.duplicate()
	var fresh := player.available_upgrades(upgrade_pool()).filter(func(u: Resource) -> bool:
		return not u in keep and not u in banished)
	fresh.shuffle()
	offers.append_array(fresh.slice(0, OFFERS_PER_LEVEL - offers.size()))
	if offers.is_empty():
		offers = [FALLBACK_UPGRADE]
	return offers


func _on_rerolled() -> void:
	if rerolls <= 0:
		return
	rerolls -= 1
	Game.sfx("chest_open", 0.0, 1.4)
	level_up.open(_deal_offers(), player, rerolls, banishes)


# The banished card is gone for the journey; a fresh one takes its place.
func _on_banished(upgrade: Resource) -> void:
	if banishes <= 0 or upgrade == FALLBACK_UPGRADE:
		return
	banishes -= 1
	banished.append(upgrade)
	var keep: Array = level_up.offers.filter(func(u: Resource) -> bool: return u != upgrade)
	level_up.open(_deal_offers(keep), player, rerolls, banishes)


func _on_level_up_skipped() -> void:
	var amount := SKIP_GOLD_PER_DAY * day()
	gold += amount
	Game.sfx("coins", 0.0)
	show_banner(tr("Skipped: +%d gold") % amount, 1.2)
	if player.pending_level_ups == 0:
		_gather_gems()
	_offer_next_level_up()


## What level-ups and blessings can offer now. Hunger only speeds Devouring,
## so it waits until the hero has Devoured once.
func upgrade_pool() -> Array:
	return UPGRADE_POOL.filter(func(upgrade: Resource) -> bool:
		return not upgrade in banished and (upgrade != HUNGER or player.devour_count() > 0))


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
	record.note_codex(player)
	Save.save_journey(JourneyRecord.snapshot(self))
	if day() == 19:
		show_banner("Tomorrow, the Demon King.", 2.5)
	else:
		show_banner("Your journey continues... (saved)", 2.0)


func _restore(journey: Dictionary) -> void:
	_restoring = true  # replaying the hero: no banners for old Resonances
	var saved_day := JourneyRecord.restore(self, journey)
	_restoring = false
	for shrine_day: int in SHRINE_DAYS:
		if shrine_day <= saved_day:
			_shrines_done.append(shrine_day)
	if saved_day >= RUINS_FROM_DAY:
		world.biome = "ruins"
		mood.color = MOOD.ruins
	spawner.grace()
	show_banner(tr("Day %d. Your journey continues.") % saved_day, 2.5)


func _on_player_died() -> void:
	# The goddess can pull you back, for a price that doubles every time.
	awaiting_revive = true
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
	if not awaiting_revive:
		return
	var cost := revive_cost()
	var can_pay := gold >= cost
	end_text.text = tr("The goddess reaches for you. She can pull you back,\nbut her light grows weaker each time.\n\nRevive: %d gold   (you have %d)") % [cost, gold]
	primary_button.text = tr("Revive  (%dg)") % cost
	secondary_button.text = "Accept your fate"
	secondary_button.show()
	_show_end_menu(primary_button if can_pay else secondary_button)
	primary_button.disabled = not can_pay


## True once the revive offer is on screen and the hero can still choose.
func revive_offer_open() -> bool:
	return awaiting_revive and not secondary_button.disabled


## Pays for a revive; false if the gold isn't there.
func revive() -> bool:
	var cost := revive_cost()
	if not awaiting_revive or gold < cost:
		return false
	awaiting_revive = false
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
	return true


## Declines the revive: the journey ends here.
func accept_fate() -> void:
	if not awaiting_revive:
		return
	awaiting_revive = false
	_end_run("You have fallen in battle...\nThe cycle remains unbroken.")


func _end_run(message: String, won := false) -> void:
	over = true
	awaiting_revive = false
	get_tree().paused = false
	Game.sfx("victory" if won else "defeat", 0.0)
	if won:
		Game.sfx("toll", 0.0)
	Music.stop(4.0 if won else 3.0)
	record.note_codex(player)
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
	moments.clear()
	var title := "Victory" if won else "Your Journey Ends"
	var unlocked := Unlocks.unlocked(Save.data).filter(func(path: String) -> bool:
		return not path in _unlocked_at_start)
	results.open(self, won, title, message, unlocked)


func _show_end_menu(focus: Button) -> void:
	end_menu.show()
	primary_button.disabled = true
	secondary_button.disabled = true
	await get_tree().create_timer(END_MENU_DELAY).timeout
	primary_button.disabled = awaiting_revive and gold < revive_cost()
	secondary_button.disabled = false
	focus.grab_focus()


func _on_primary() -> void:
	if awaiting_revive:
		revive()
	else:
		Game.sfx("click", 0.0)
		Save.resume = false
		Game.change_scene()


func _on_secondary() -> void:
	if awaiting_revive:
		accept_fate()
	else:
		Game.sfx("click", 0.0)
		Game.change_scene(TITLE_SCENE)
