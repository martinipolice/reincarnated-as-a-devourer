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

@export_group("Evolution")
## Devour this many of this essence with the weapon maxed to evolve it.
@export var evolve_with: EssenceData
@export var evolve_count := 3
@export var evolved_name := ""
