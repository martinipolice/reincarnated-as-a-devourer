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
## What each level changes, shown on the level-up screen ("Damage 34 -> 50").
## Falls back to `description` for levels without an entry.
@export var level_descriptions: PackedStringArray
@export var icon: Texture2D

@export_group("Evolution")
## With the weapon maxed, it evolves once its requirements are met: Devour
## `evolve_count` of the `evolve_with` essence, and/or hold the
## `evolve_with_item` passive at its max level. Unset ones aren't required.
@export var evolve_with: EssenceData
@export var evolve_count := 3
@export var evolve_with_item: ItemData
@export var evolved_name := ""
