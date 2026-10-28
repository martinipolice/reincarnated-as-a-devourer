class_name Branches
## Every weapon's two branches, Hades-hammer style: at Lv 3 the level-up
## offers both, the first one taken locks the other out, and Lv 5 deepens it.
## Each weapon script reads its rank with Weapon.branch_rank(id).
## weapon -> [[id, name, Lv 4 text, Lv 5 text], ...]

const MAX_LEVEL := 5
const TABLE := {
	"res://data/weapons/blade.tres": [
		["a", "Whirlwind", "Reach +20%", "Reach +40%"],
		["b", "Rending Edge", "Hits make enemies bleed 25% of the hit each second for 2 s", "Bleed 50% of the hit each second"]],
	"res://data/weapons/goddess_light.tres": [
		["a", "Volley", "+1 bolt", "+2 bolts"],
		["b", "Lance", "Damage +25%, pierces 2 more", "Damage +50%, pierces 4 more"]],
	"res://data/weapons/aegis.tres": [
		["a", "Phalanx", "+1 blade", "+2 blades"],
		["b", "Retribution", "Damage +30%, knockback +50%", "Damage +60%, knockback doubled"]],
	"res://data/weapons/maw.tres": [
		["a", "Gorge", "Kills heal twice as much", "Kills heal three times as much"],
		["b", "Frenzy", "Bites 15% faster, reach +15", "Bites 30% faster, reach +30"]],
	"res://data/weapons/chains.tres": [
		["a", "Inferno", "Burns 50% hotter and 1 s longer", "Burns twice as hot and 2 s longer"],
		["b", "Long Lash", "Lash 20% longer and wider", "Lash 40% longer and wider"]],
	"res://data/weapons/doom_bell.tres": [
		["a", "Peal", "+1 bell", "+2 bells"],
		["b", "Knell", "Toll 15% wider, slows harder", "Toll 30% wider, slows hardest"]],
}

static var _cache := {}


static func has(weapon: WeaponData) -> bool:
	return TABLE.has(weapon.resource_path)


## Both of `weapon`'s branches.
static func of(weapon: WeaponData) -> Array[BranchData]:
	var found: Array[BranchData] = []
	for entry: Array in TABLE.get(weapon.resource_path, []):
		found.append(get_branch(weapon, entry[0]))
	return found


static func get_branch(weapon: WeaponData, id: String) -> BranchData:
	var key := "%s#%s" % [weapon.resource_path, id]
	if not _cache.has(key):
		for entry: Array in TABLE[weapon.resource_path]:
			if entry[0] == id:
				var branch := BranchData.new()
				branch.weapon = weapon
				branch.id = id
				branch.display_name = entry[1]
				branch.description = entry[2]
				branch.icon = weapon.icon
				branch.level_descriptions = PackedStringArray(["", "", "", entry[2], entry[3]])
				_cache[key] = branch
	return _cache[key]


## The branch saved as `key` ("weapon path#id").
static func from_key(key: String) -> BranchData:
	return get_branch(load(key.get_slice("#", 0)), key.get_slice("#", 1))
