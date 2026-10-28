class_name Unlocks
## Starting weapons, earned across journeys. A hero still lives once per
## journey; these only add variety to how the next one begins. Each entry:
## [weapon, how to earn it, test against the lifetime records in Save.data].

const STARTERS := [
	["res://data/weapons/blade.tres", "Always yours", "always"],
	["res://data/weapons/goddess_light.tres", "Reach Day 10", "day10"],
	["res://data/weapons/aegis.tres", "Reach the goddess's farewell (Day 19)", "day19"],
	["res://data/weapons/maw.tres", "Devour 15 essences, across journeys", "devour15"],
	["res://data/weapons/chains.tres", "Fell the Ruin Guardian", "guardian"],
	["res://data/weapons/doom_bell.tres", "Fell the Hollow Spirit", "spirit"],
]


static func earned(test: String, data: Dictionary) -> bool:
	match test:
		"always":
			return true
		"day10":
			return int(data.best_day) >= 10
		"day19":
			return int(data.best_day) >= 19
		"devour15":
			return int(data.get("devoured_total", 0)) >= 15
		"guardian":
			return "Ruin Guardian" in data.get("felled", [])
		"spirit":
			return "Hollow Spirit" in data.get("felled", [])
	return false


## Weapon paths unlocked by the records in `data`.
static func unlocked(data: Dictionary) -> Array[String]:
	var paths: Array[String] = []
	for entry: Array in STARTERS:
		if earned(entry[2], data):
			paths.append(entry[0])
	return paths
