class_name LootDirector
extends Node
## Treasure chests: one appears every CHEST_INTERVAL s (up to MAX_CHESTS at
## once) somewhere just off-screen, and a HUD arrow points the way. Some are
## golden (two rewards); from MIMIC_FROM_DAY some are Mimics that fight back.
## Opening one pauses the run for the reel (ChestReel), then grants the loot.

const CHEST_SCENE := preload("res://scenes/loot_chest.tscn")
const CHEST_REEL := preload("res://scripts/ui/chest_reel.gd")
const CHEST_FIRST := 20.0
const CHEST_INTERVAL := 30.0
const GOLDEN_CHANCE := 0.15
const MIMIC_CHANCE := 0.15
const MIMIC_FROM_DAY := 3
const MAX_CHESTS := 3
const CHEST_DISTANCE := Vector2(450.0, 850.0)
const FERVOR_DURATION := 15.0
const FERVOR_HASTE := 0.5
const BOMB_RADIUS := 450.0
const BOMB_DAMAGE := 150.0
const GOLD_POUCH_PER_DAY := 12

## Run time when Goddess's Fervor wears off (the HUD counts it down).
var fervor_until := 0.0
var _chest_timer := CHEST_FIRST
## Chests waiting for their ceremony, [rewards, golden, at]: two can be
## opened in one frame (a Mimic's golden chest beside another).
var _chest_queue: Array = []
var _revealing := false
var _reel: CanvasLayer
var _main: Node
var _player: Player


func _init(main: Node) -> void:
	_main = main
	_player = main.player


func _ready() -> void:
	_reel = CHEST_REEL.new()
	add_child(_reel)


func update(delta: float) -> void:
	_chest_timer -= delta
	if _chest_timer <= 0.0:
		_chest_timer = CHEST_INTERVAL
		_spawn_chest()


func place_chest(at: Vector2, kind: LootChest.Kind) -> void:
	var chest := CHEST_SCENE.instantiate() as LootChest
	chest.kind = kind
	chest.position = Obstacles.push_out(at, 24.0)
	chest.opened.connect(_on_chest_opened)
	_main.pickups.add_child(chest)


func _spawn_chest() -> void:
	if get_tree().get_nodes_in_group("chests").size() >= MAX_CHESTS:
		return
	var distance := randf_range(CHEST_DISTANCE.x, CHEST_DISTANCE.y)
	var roll := randf()
	var kind := LootChest.Kind.NORMAL
	if roll < GOLDEN_CHANCE:
		kind = LootChest.Kind.GOLDEN
	elif roll < GOLDEN_CHANCE + MIMIC_CHANCE and _main.day() >= MIMIC_FROM_DAY:
		kind = LootChest.Kind.MIMIC
	place_chest(_player.position + Vector2.RIGHT.rotated(randf() * TAU) * distance, kind)
	Hints.show_hint("chest", "A chest appeared! Follow the golden arrow at the edge of the screen to find it.")


func _on_chest_opened(chest: LootChest) -> void:
	if chest.kind == LootChest.Kind.MIMIC:
		_main.spawner.spring_mimic(chest.global_position)
		Game.sfx("boss_warn", 0.0)
		Game.shake(0.4)
		_main.show_banner("It was a Mimic!\nKill it for its treasure.", 2.0)
		return
	var golden := chest.kind == LootChest.Kind.GOLDEN
	var at := chest.global_position
	Game.sfx("chest_open", 0.0)
	Game.fx("spark", at, 3.0 if golden else 2.0, Color(1, 0.9, 0.5))
	Game.shake(0.35 if golden else 0.2)
	var hurt := _player.hp < _player.stat("max_hp") * 0.9
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
		await _reel.reveal(rewards, golden)
		if _main.over or _main.awaiting_revive:
			break
		get_tree().paused = false
		Game.burst(at, Color(1, 0.85, 0.35), 50 if golden else 25, 260.0)
		Game.shockwave(at, Color(1, 0.85, 0.35), 120.0 if golden else 90.0)
		var lines := []
		for i in rewards.size():
			lines.append(_grant(rewards[i], at + Vector2(24 * i, 0)))
		var title := "GOLDEN CHEST\n" if golden else ""
		_main.show_banner(title + "\n".join(lines), 2.5 if golden else 2.0)
	_chest_queue.clear()
	_revealing = false


# Applies one reward and returns its banner line.
func _grant(entry: Dictionary, at: Vector2) -> String:
	var text: String = entry.text
	var max_hp := _player.stat("max_hp")
	match entry.id:
		"common_potion":
			_player.hp = minf(max_hp, _player.hp + max_hp * 0.3)
		"high_potion":
			_player.hp = minf(max_hp, _player.hp + max_hp * 0.6)
		"rejuvenation":
			_player.hp = max_hp
		"attraction":
			for node in _main.pickups.get_children():
				if node is XPGem:
					(node as XPGem).magnetize()
		"blessing":
			_player.gain_xp(_player.xp_to_next() - _player.xp)
		"gold":
			var amount: int = GOLD_POUCH_PER_DAY * _main.day()
			_main.gold += amount
			text = text % amount
			Game.sfx("coins", 0.0)
		"fervor":
			fervor_until = _main.elapsed + FERVOR_DURATION
			_player.add_timed_modifier({"stat": "haste", "add": FERVOR_HASTE}, FERVOR_DURATION)
		"bomb":
			Game.sfx("bomb", 0.0)
			Game.rumble(0.5, 0.8, 0.4)
			Game.shake(0.6)
			Game.fx("explosion", _player.global_position, 4.0)
			Game.burst(_player.global_position, Color(1, 0.6, 0.2), 60, 450.0)
			for node in _main.enemies.get_children():
				var enemy := node as Enemy
				if enemy and _player.global_position.distance_to(enemy.global_position) <= BOMB_RADIUS:
					var push := _player.global_position.direction_to(enemy.global_position) * 300.0
					enemy.take_damage(BOMB_DAMAGE, push, "enemy_hit", "Bomb")
	if entry.id != "gold" and entry.id != "bomb":
		Game.sfx("loot", 0.0)
	_pop_icon(at, Loot.icon(entry))
	return "%s: %s" % [entry.name, text]


# The reward's sprite floats up out of the chest and fades.
func _pop_icon(at: Vector2, texture: Texture2D) -> void:
	var icon := Sprite2D.new()
	icon.texture = texture
	icon.scale = Vector2(2.5, 2.5)
	icon.position = at + Vector2(0, -10)
	get_tree().get_first_node_in_group("effects").add_child(icon)
	var tween := icon.create_tween().set_parallel()
	tween.tween_property(icon, "position:y", at.y - 60.0, 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(icon, "modulate:a", 0.0, 0.5).set_delay(0.8)
	tween.chain().tween_callback(icon.queue_free)
