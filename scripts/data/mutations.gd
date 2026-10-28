class_name Mutations
## What Devouring an essence can become. Each essence offers its classic boost
## (EssenceData: stat, add/mult, max_hp_cost) or this alternative, picked on
## a card the moment it's Devoured. Both count as that essence for
## evolutions and Resonances.
## essence -> [name, description, modifiers, max HP cost]

const TABLE := {
	"res://data/essences/dreadling_essence.tres": ["Phantom Hide", "+15 defense",
		[{"stat": "defense", "add": 15.0}], 5.0],
	"res://data/essences/vexclaw_essence.tres": ["Feral Reflexes", "+15% attack speed, +6% move speed",
		[{"stat": "haste", "add": 0.15}, {"stat": "move_speed", "mult": 0.06}], 10.0],
	"res://data/essences/plaguewing_essence.tres": ["Plague Blood", "+1.2 HP regeneration",
		[{"stat": "regen", "add": 1.2}], 18.0],
	"res://data/essences/hexeye_essence.tres": ["Third Eye", "+60 pickup range, +8% damage",
		[{"stat": "pickup_radius", "add": 60.0}, {"stat": "might", "add": 0.08}], 6.0],
	"res://data/essences/warden_essence.tres": ["Iron Hide", "+20 defense",
		[{"stat": "defense", "add": 20.0}], 8.0],
}


## [name, description, modifiers, max HP cost] for `essence`'s alternative.
static func of(essence: EssenceData) -> Array:
	return TABLE[essence.resource_path]
