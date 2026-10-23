class_name EssenceData
extends Resource
## What Devouring an elite grants. Each monster's essence boosts the stat it
## gave in the terminal game (Dreadling SPD, Vexclaw ATK, Plaguewing DEF) and
## costs max HP for the rest of the run, using the original formula:
## 30% of the monster's ATK + DEF + SPD.

@export var display_name := ""
## Shown on the banner, e.g. "+15% might".
@export var description := ""
## Key into the player's `base` stats.
@export var stat := ""
@export var add := 0.0
@export var mult := 0.0
@export var max_hp_cost := 0.0
@export var color := Color.WHITE
