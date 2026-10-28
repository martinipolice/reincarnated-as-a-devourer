class_name Ambience
extends Node
## The world's sound under the music: crickets and wind in the forest, gusts
## and drips in the ruins, a low drone in the temple. Beds crossfade when the
## area changes. They're synthesized by tools/synth_audio.py and play on the
## SFX bus, so the sound-effects slider sets their level too.

const BEDS := {
	"forest": ["res://assets/audio/synth/amb_forest.wav", -4.0],
	"ruins": ["res://assets/audio/synth/amb_ruins.wav", -4.0],
	"temple": ["res://assets/audio/synth/amb_temple.wav", -3.0],
}
const SILENT_DB := -60.0

## Added to every bed's level (the title screen sits it lower).
var offset_db := 0.0
var _players: Array[AudioStreamPlayer] = []
var _current := 0
var _bed := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)


## Crossfades to `bed` ("forest", "ruins" or "temple") over `fade` seconds.
func play(bed: String, fade := 3.0) -> void:
	if bed == _bed:
		return
	_bed = bed
	var old := _players[_current]
	_current = 1 - _current
	var new := _players[_current]
	new.stream = _looped(BEDS[bed][0])
	new.volume_db = SILENT_DB
	new.play(randf() * new.stream.get_length())  # beds don't all start on the same owl
	var tween := create_tween().set_parallel()
	tween.tween_property(new, "volume_db", float(BEDS[bed][1]) + offset_db, fade)
	tween.tween_property(old, "volume_db", SILENT_DB, fade)
	tween.chain().tween_callback(old.stop)


static func _looped(path: String) -> AudioStreamWAV:
	var stream := (load(path) as AudioStreamWAV).duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream
