class_name WeaponData
extends Resource
## An auto-firing weapon offered on level-up. Its behaviour lives in the
## script on `scene` (a Weapon); this holds what the level-up screen shows.

@export var display_name := ""
@export_multiline var description := ""
@export var scene: PackedScene
@export var max_level := 3
## Optional name for each level, e.g. the old shop tiers for the Blade.
@export var tier_names: PackedStringArray
@export var icon: Texture2D
