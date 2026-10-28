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
## How it moves and attacks; see enemy.gd.
@export_enum("chase", "swarm", "pounce", "spitter", "caster", "warden", "raiser", "burrower") var behavior := "chase"
## Wardens: damage their shield soaks before it breaks (it takes most of
## every hit meanwhile). 0 = no shield.
@export var shield := 0.0
## Granted when an elite of this type is Devoured. Empty = can't be Devoured.
@export var essence: EssenceData
## Bosses (and mini-bosses) are never Devoured and don't jostle in crowds.
@export var boss := false
## Killing it wins the journey (the Demon King).
@export var final := false
## Leaves a golden treasure chest when killed (the Mimic).
@export var drops_golden_chest := false
## 1 = full knockback from hits, 0 = immovable.
@export var knockback_scale := 1.0

@export_group("Visuals")
@export var radius := 10.0
@export var color := Color.WHITE
## Leave empty to draw a placeholder circle. Needs a "run" animation.
@export var sprite_frames: SpriteFrames
## The 16x16 pack sprites are tiny at 1280x720; this scales them up.
@export var sprite_scale := 2.0
