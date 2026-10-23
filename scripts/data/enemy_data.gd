class_name EnemyData
extends Resource
## One monster type. Ported from the m_stats dicts in the terminal game's
## explore(). Edit the .tres files in data/enemies/ to tune or re-skin.

@export var display_name := ""
@export var max_hp := 40.0
@export var atk := 10.0
@export var defense := 8.0
@export var move_speed := 80.0
@export var gold := 10
## Value of the XP gem it drops.
@export var xp := 1

@export_group("Visuals")
@export var radius := 10.0
@export var color := Color.WHITE
## Leave empty to draw a placeholder circle. Assign a free asset pack's
## SpriteFrames here later; no code changes needed.
@export var sprite_frames: SpriteFrames
