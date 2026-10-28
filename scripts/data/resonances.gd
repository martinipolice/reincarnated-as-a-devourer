class_name Resonances
## Essence synergies: holding at least NEEDED of each of two essences
## awakens a Resonance, a lasting bonus on top of the essences themselves.
## Player._check_resonances() applies them; the build screen and codex list
## them. Each entry: [name, essence A, essence B, description, modifiers].

const NEEDED := 2
const TABLE := [
	["Predator's Pace", "res://data/essences/vexclaw_essence.tres", "res://data/essences/dreadling_essence.tres",
		"+10% damage and +8% move speed",
		[{"stat": "might", "add": 0.1}, {"stat": "move_speed", "mult": 0.08}]],
	["Iron Rot", "res://data/essences/plaguewing_essence.tres", "res://data/essences/warden_essence.tres",
		"+20 defense",
		[{"stat": "defense", "add": 20.0}]],
	["Hunter's Eye", "res://data/essences/hexeye_essence.tres", "res://data/essences/vexclaw_essence.tres",
		"+10% attack speed and +30 pickup range",
		[{"stat": "haste", "add": 0.1}, {"stat": "pickup_radius", "add": 30.0}]],
	["Phantom Veil", "res://data/essences/dreadling_essence.tres", "res://data/essences/hexeye_essence.tres",
		"+12% move speed and +1 HP regeneration",
		[{"stat": "move_speed", "mult": 0.12}, {"stat": "regen", "add": 1.0}]],
	["Bulwark Heart", "res://data/essences/warden_essence.tres", "res://data/essences/vexclaw_essence.tres",
		"+25 max HP and +10 defense",
		[{"stat": "max_hp", "add": 25.0}, {"stat": "defense", "add": 10.0}]],
]
