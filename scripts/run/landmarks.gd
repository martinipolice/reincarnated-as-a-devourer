class_name Landmarks
extends Node
## Points of interest: from Day 2, one or two Landmarks appear each day a
## little way off (an edge arrow points to each), so there is somewhere
## worth going besides the next chest. This places them and pays out:
## the altar's trial and reward pick, the well's gold, the cage's elite and
## the grave's boon.

const FIRST_DAY := 2
const TWO_FROM_DAY := 8
const MAX_ACTIVE := 3
const DISTANCE := Vector2(550.0, 900.0)
const KIND_WEIGHTS := {"altar": 3, "well": 2, "cage": 2, "grave": 3}
const SURGE_EVERY := 0.45  # seconds between monsters during an altar trial
const SURGE_RING := 420.0
const WELL_SHARE := 0.2  # of current HP
const WELL_GOLD_PER_DAY := 20
const HOARD_GOLD_PER_DAY := 30
## The altar's rewards: [id, name, description, icon]; three are offered.
const REWARDS := [
	["edge", "Altar's Edge", "+8% damage for the journey", preload("res://assets/ninja/images/icon_fury.png")],
	["ward", "Altar's Ward", "+12 defense for the journey", preload("res://assets/ninja/images/icon_guard.png")],
	["hoard", "Altar's Hoard", "%d gold", preload("res://assets/ninja/images/gold.png")],
	["insight", "Altar's Insight", "Level up now", preload("res://assets/ninja/images/blessing.png")],
	["thread", "Altar's Thread", "+1 reroll and +1 banish", preload("res://assets/ninja/images/icon_scroll.png")],
]
const BOONS := ["tears", "reroll", "banish", "heal", "chest"]

var _main: Node
var _player: Player
var _pick: CardPick
var _trial: Landmark
var _surge_timer := 0.0


func _init(main: Node) -> void:
	_main = main
	_player = main.player


func _ready() -> void:
	_pick = CardPick.new()
	add_child(_pick)
	_main.day_changed.connect(_on_day)


func update(delta: float) -> void:
	if not is_instance_valid(_trial) or _trial.spent:
		return
	_surge_timer -= delta
	if _surge_timer <= 0.0:
		_surge_timer = SURGE_EVERY
		var at: Vector2 = _trial.global_position + Vector2.from_angle(randf() * TAU) * SURGE_RING
		_main.spawner.spawn_at(_main.spawner.pick_enemy(), at)


## Puts a `kind` landmark at `at` (also how tests place one).
func place(kind: String, at: Vector2) -> Landmark:
	var landmarks := get_tree().get_nodes_in_group("landmarks")
	if landmarks.size() >= MAX_ACTIVE:
		landmarks[0].queue_free()  # the oldest gives way
	var landmark := Landmark.new()
	landmark.setup(kind, _player)
	landmark.position = Obstacles.push_out(at, 48.0)
	landmark.z_index = -2
	landmark.trial_started.connect(_on_trial_started)
	landmark.trial_won.connect(_on_trial_won)
	landmark.trial_failed.connect(_on_trial_failed)
	landmark.used.connect(_on_used)
	_main.pickups.add_child(landmark)
	return landmark


func _on_day(day: int, final_day: int, _next_shrine: int) -> void:
	if day < FIRST_DAY or day >= final_day:
		return
	for i in (2 if day >= TWO_FROM_DAY else 1):
		var distance := randf_range(DISTANCE.x, DISTANCE.y)
		place(_random_kind(), _player.position + Vector2.from_angle(randf() * TAU) * distance)
	Hints.show_hint("landmark", "A landmark appeared: follow its arrow. Altars test you for a reward, wells trade blood for gold, cages hold a strong elite, graves leave a gift.")


func _random_kind() -> String:
	var total := 0
	for kind: String in KIND_WEIGHTS:
		total += KIND_WEIGHTS[kind]
	var roll := randi_range(1, total)
	for kind: String in KIND_WEIGHTS:
		roll -= KIND_WEIGHTS[kind]
		if roll <= 0:
			return kind
	return "grave"


func _on_trial_started(landmark: Landmark) -> void:
	_trial = landmark
	_surge_timer = 0.0
	Game.sfx("doom", 0.0, 1.2)
	Game.shockwave(landmark.global_position, landmark.color(), Landmark.ALTAR_RADIUS, 0.6)
	_main.show_banner(tr("The altar wakes.\nSurvive %d seconds inside its circle.") % Landmark.ALTAR_TIME, 2.5)


func _on_trial_failed(_landmark: Landmark) -> void:
	_trial = null
	Game.sfx("denied", 0.0)
	_main.show_banner(tr("You left the circle. The altar falls silent."), 2.0)


func _on_trial_won(landmark: Landmark) -> void:
	_trial = null
	Game.sfx("rank_up", 0.0)
	Game.shockwave(landmark.global_position, landmark.color(), 220.0, 0.6)
	var offers := REWARDS.duplicate()
	offers.shuffle()
	offers.resize(3)
	var cards: Array[ChoiceCard] = []
	for i in offers.size():
		var entry: Array = offers[i]
		var body: String = tr(entry[2]) % (HOARD_GOLD_PER_DAY * _main.day()) if entry[0] == "hoard" else tr(entry[2])
		cards.append(ChoiceCard.new(entry[3], tr(entry[1]), tr("ALTAR"), "", body, landmark.color(), str(i + 1)))
	_pick.picked.connect(func(index: int) -> void: grant(offers[index][0]), CONNECT_ONE_SHOT)
	_pick.open(tr("The Altar Yields"), cards)


## Applies the altar reward `id` (also how tests grant one).
func grant(id: String) -> void:
	match id:
		"edge":
			_main.add_altar_bonus({"stat": "might", "add": 0.08})
		"ward":
			_main.add_altar_bonus({"stat": "defense", "add": 12.0})
		"hoard":
			_main.gold += HOARD_GOLD_PER_DAY * _main.day()
			Game.sfx("coins", 0.0)
		"insight":
			_player.gain_xp(_player.xp_to_next() - _player.xp)
		"thread":
			_main.rerolls += 1
			_main.banishes += 1
	Game.fx("spark", _player.global_position, 3.0, Color(0.8, 0.6, 1.0))


func _on_used(landmark: Landmark) -> void:
	var at := landmark.global_position
	match landmark.kind:
		"well":
			var cost := maxf(1.0, _player.hp * WELL_SHARE)
			_player.hp = maxf(1.0, _player.hp - cost)
			var gold: int = WELL_GOLD_PER_DAY * _main.day()
			_main.gold += gold
			Game.sfx("coins", 0.0)
			Game.splat(at, landmark.color(), 18.0)
			_main.show_banner(tr("Blood for gold: -%d HP, +%d gold") % [roundi(cost), gold], 2.0)
		"cage":
			var spawner: SpawnDirector = _main.spawner
			var affix: String = Enemy.TRAITS.keys().pick_random()
			spawner.spawn_elite_at.call_deferred(spawner.pick_enemy(true), at, affix)
			Game.sfx("boss_warn", 0.0)
			Game.burst(at, landmark.color(), 20, 220.0)
			_main.show_banner(tr("The cage breaks. Something strong is free."), 2.0)
		"grave":
			_main.show_banner(_boon(BOONS.pick_random(), at), 2.5)
			Game.sfx("loot", 0.0)


func _boon(id: String, at: Vector2) -> String:
	match id:
		"tears":
			_player.refill_flask()
			return tr("The hero's gift: your Tears are full")
		"reroll":
			_main.rerolls += 1
			return tr("The hero's gift: +1 reroll")
		"banish":
			_main.banishes += 1
			return tr("The hero's gift: +1 banish")
		"heal":
			_player.hp = minf(_player.stat("max_hp"), _player.hp + _player.stat("max_hp") * 0.5)
			return tr("The hero's gift: you are healed")
	_main.loot.place_chest.call_deferred(at + Vector2(40, 0), LootChest.Kind.GOLDEN)
	return tr("The hero's gift: a golden chest")
