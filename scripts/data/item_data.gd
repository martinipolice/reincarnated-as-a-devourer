class_name ItemData
extends Resource
## A passive item offered on level-up. Ported from the terminal game's shop
## tiers: each tier there becomes one level here (Wooden Guard -> Steel
## Shield -> Aegis Guard). Applied as a player modifier, never to base stats.

@export var display_name := ""
@export_multiline var description := ""
## Key into the player's `base` stats, e.g. "might", "defense", "move_speed".
## Leave empty for items that only heal.
@export var stat := ""
@export var add_per_level := 0.0
@export var mult_per_level := 0.0
## Fraction of max HP restored when picked (1.0 = full heal).
@export var heal_fraction := 0.0
@export var max_level := 3
## Optional name for each level, e.g. the old shop tiers.
@export var tier_names: PackedStringArray
## What each level changes, shown on the level-up screen ("Damage 34 -> 50").
## Falls back to `description` for levels without an entry.
@export var level_descriptions: PackedStringArray
@export var icon: Texture2D
