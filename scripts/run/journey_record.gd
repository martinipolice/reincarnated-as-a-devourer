class_name JourneyRecord
extends RefCounted
## The journey on disk: the shrine checkpoint (snapshot / restore) and what
## the run adds to the Codex. Save.gd stores the dictionaries; this knows
## what goes in them.

## Enemy name -> kills since the last note_codex().
var kills_by := {}


func count_kill(enemy: Enemy) -> void:
	kills_by[enemy.data.display_name] = int(kills_by.get(enemy.data.display_name, 0)) + 1


## What this run has met and found, into the Codex (written with the next save).
func note_codex(player: Player) -> void:
	var upgrades := []
	for upgrade: Resource in player.upgrade_levels:
		upgrades.append(upgrade.resource_path)
	var essences := []
	for essence: EssenceData in player.essences:
		essences.append(essence.resource_path)
	Save.note_codex(kills_by, upgrades, essences, player.resonances)
	kills_by.clear()


## Everything needed to rebuild this hero at the shrine just visited.
static func snapshot(main: Node) -> Dictionary:
	var player: Player = main.player
	var upgrades := []
	for upgrade: Resource in player.upgrade_levels:
		upgrades.append([upgrade.resource_path, player.upgrade_levels[upgrade]])
	var essences := []
	for essence: EssenceData in player.essences:
		essences.append([essence.resource_path, player.essences[essence], player.mutations.get(essence, 0)])
	return {
		"day": main.day(), "level": player.level, "xp": player.xp,
		"hp_fraction": player.hp / player.stat("max_hp"), "gold": main.gold, "kills": main.kills,
		"revives": main.revives, "training": main.training_ranks.duplicate(), "upgrades": upgrades,
		"essences": essences, "seed": main.world.seed_value,
		"flask_max": player.flask_max, "flask_heal": player.flask_heal, "covenant": main.covenant,
		"damage": Enemy.damage_log.duplicate(), "best_rank": main.best_rank,
		"rerolls": main.rerolls, "banishes": main.banishes,
		"banished": main.banished.map(func(u: Resource) -> String:
			return (u as BranchData).key() if u is BranchData else u.resource_path),
		"branches": player.branches.keys().map(func(w: WeaponData) -> Array:
			return [w.resource_path, player.branches[w]]),
	}


## Continue from a shrine checkpoint: same hero, same world, start of that day.
## Returns the saved day.
static func restore(main: Node, journey: Dictionary) -> int:
	var player: Player = main.player
	main.world.set_seed(int(journey.seed))
	var saved_day := int(journey.day)
	main.elapsed = (saved_day - 1) * main.SECONDS_PER_DAY + 0.5
	main.gold = int(journey.gold)
	main.kills = int(journey.kills)
	Enemy.damage_log = (journey.get("damage", {}) as Dictionary).duplicate()
	main.best_rank = int(journey.get("best_rank", 0))
	main.revives = int(journey.revives)
	main.rerolls = int(journey.get("rerolls", main.START_REROLLS))
	main.banishes = int(journey.get("banishes", main.START_BANISHES))
	for path: String in journey.get("banished", []):
		main.banished.append(Branches.from_key(path) if "#" in path else load(path))
	player.level = int(journey.level)
	player.xp = int(journey.xp)
	var taken := {}
	for entry: Array in journey.get("branches", []):
		taken[entry[0]] = entry[1]
	for entry: Array in journey.upgrades:
		var upgrade: Resource = load(entry[0])
		for i in mini(int(entry[1]), upgrade.max_level):
			player.apply_upgrade(upgrade)
		for i in int(entry[1]) - upgrade.max_level:  # Lv 4-5: the branch it took
			player.apply_upgrade(Branches.get_branch(upgrade, taken[entry[0]]))
	for entry: Array in journey.essences:
		var alternatives := int(entry[2]) if entry.size() > 2 else 0
		for i in int(entry[1]):
			player.add_essence(load(entry[0]), i < alternatives)
	for training: TrainingData in main.SHRINE.TRAININGS:
		for i in int(journey.training.get(training.id, 0)):
			main.add_training(training)
	player.flask_max = int(journey.get("flask_max", player.flask_max))
	player.flask_heal = float(journey.get("flask_heal", player.flask_heal))
	player.refill_flask()
	var sealed := String(journey.get("covenant", ""))
	if sealed != "thirst":  # Thirst's price was paid at the shrine
		main.set_covenant(sealed)
	else:
		main.covenant = sealed
	player.hp = player.stat("max_hp") * float(journey.hp_fraction)
	return saved_day
