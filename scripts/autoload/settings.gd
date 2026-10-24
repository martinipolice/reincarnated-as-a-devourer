extends Node
## Player preferences, available everywhere as `Settings`, stored in
## user://settings.json apart from the journey save, so starting over never
## resets them. Also remembers which beginner hints have been shown.

const PATH := "user://settings.json"

var data := defaults()


static func defaults() -> Dictionary:
	return {
		"volume": 0.8,  # 0..1, the master bus
		"shake": 1.0,  # 0..1, scales every screen shake
		"damage_numbers": true,
		"fullscreen": false,
		"hints": true,
		"seen_hints": [],
	}


func _ready() -> void:
	if persistent() and FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			data.merge(parsed, true)
	_apply()


## Headless tools run under their own MainLoop: they never touch the file.
func persistent() -> bool:
	return get_tree().get_script() == null


func set_value(key: String, value: Variant) -> void:
	data[key] = value
	_apply()
	save()


func save() -> void:
	if not persistent():
		return
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


func _apply() -> void:
	var volume := float(data.volume)
	AudioServer.set_bus_mute(0, volume <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if data.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
