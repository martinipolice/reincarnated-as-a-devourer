class_name BranchData
extends Resource
## One of a weapon's two paths past Lv 3 (Lv 4 and 5), offered as a level-up
## card like any upgrade. Built from Branches.TABLE, one shared instance per
## path, so it can be compared, banished and saved by `key`.

var weapon: WeaponData
var id := ""  # "a" or "b"
var display_name := ""
var description := ""
var icon: Texture2D
## Indexed by the level it brings, like WeaponData's: only 3 and 4 are set.
var level_descriptions := PackedStringArray()
var tier_names := PackedStringArray()
var max_level := 5


## "res://data/weapons/blade.tres#a": how a branch is saved.
func key() -> String:
	return "%s#%s" % [weapon.resource_path, id]
