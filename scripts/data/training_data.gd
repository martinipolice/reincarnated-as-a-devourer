class_name TrainingData
extends Resource
## A permanent upgrade bought with gold at the Goddess's Sanctuary between
## runs. Ported from the terminal game's Train menu; each rank adds the
## `per_rank` modifiers to the player at the start of every run.

## Stable key in the save file. Don't rename it once players have saves.
@export var id := ""
@export var display_name := ""
@export var description := ""
## Each entry: {"stat": "max_hp", "add": 10.0} or {"stat": "move_speed", "mult": 0.04}
@export var per_rank: Array = []
@export var max_rank := 5
@export var base_cost := 100
## Each rank costs this much more than the last.
@export var cost_growth := 1.5


func cost(rank: int) -> int:
	return roundi(base_cost * pow(cost_growth, rank))
