class_name Loot
## What a treasure chest can hold. The potions are the terminal game's shop
## items; weights are relative chances. main.gd applies the effects.

const TABLE := [
	{"id": "common_potion", "name": "Common Potion", "text": "Restored 30% HP",
		"icon": "flask_red", "weight": 26},
	{"id": "high_potion", "name": "High Potion", "text": "Restored 60% HP",
		"icon": "flask_big_red", "weight": 14},
	{"id": "rejuvenation", "name": "Flask of Rejuvenation", "text": "Fully healed",
		"icon": "flask_big_yellow", "weight": 6},
	{"id": "attraction", "name": "Flask of Attraction", "text": "All XP flies to you",
		"icon": "flask_big_blue", "weight": 14},
	{"id": "blessing", "name": "Goddess's Blessing", "text": "Level up!",
		"icon": "flask_big_green", "weight": 8},
	{"id": "fervor", "name": "Goddess's Fervor", "text": "Weapons 50% faster for 15 s",
		"icon": "flask_yellow", "weight": 12},
	{"id": "gold", "name": "Gold Pouch", "text": "+%d gold",
		"icon": "coin_anim_f0", "weight": 20},
	{"id": "bomb", "name": "Bomb", "text": "Everything nearby is blasted",
		"icon": "bomb_f0", "weight": 12},
]
## Not offered while you're near full HP, so a chest is never wasted.
const HEALS := ["common_potion", "high_potion", "rejuvenation"]


## `exclude`: an id not to roll again (a golden chest's second reward).
static func roll(hurt: bool, exclude := "") -> Dictionary:
	var options := TABLE.filter(func(entry: Dictionary) -> bool:
		return (hurt or not entry.id in HEALS) and entry.id != exclude)
	var total := 0
	for entry: Dictionary in options:
		total += entry.weight
	var pick := randi_range(1, total)
	for entry: Dictionary in options:
		pick -= entry.weight
		if pick <= 0:
			return entry
	return options.back()


static func icon(entry: Dictionary) -> Texture2D:
	return load("res://assets/loot/%s.png" % entry.icon)
