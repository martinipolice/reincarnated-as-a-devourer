extends Node
## Music, available everywhere as `Music`. Plays on the "Music" bus with
## two players, so tracks crossfade. Free tracks come as one finished mix,
## not stems, so "intensity" works on the whole mix instead of layers: low
## intensity muffles it (a low-pass filter on the Music bus) and lowers it a
## little; a big wave, an event or the boss opens it to full blast.
## A track can have an opening that plays once, then hands over to its loop.

const DIR := "res://assets/audio/music/"
## id -> [file, gain dB]. Gains level every track to about the same loudness
## (measured RMS); the ambient pieces sit a few dB under the metal.
const TRACKS := {
	"title": ["title_evil_temple.ogg", 3.0],
	"forest": ["forest_heavy_battle_2.ogg", -1.0],
	"ruins": ["ruins_heavy_dungeon.ogg", -1.0],
	"ruins_peak": ["ruins_peak_heavy_boss_battle_1.ogg", -1.5],
	"boss_opening": ["boss_9_opening.ogg", -5.0],
	"boss": ["boss_9_loop.ogg", -6.0],
	"boss_enraged": ["boss_2_loop.ogg", 2.0],
	"shrine": ["shrine_heavenly_loop.ogg", 5.0],
}
const SILENT_DB := -50.0
## Low-pass cutoff at intensity 0 and 1; interpolated on a log scale.
const CALM_CUTOFF := 500.0
const FULL_CUTOFF := 20000.0
const CALM_DB := -5.0  # extra gain at intensity 0
## How fast intensity follows its target (per second): quick to rise, slow
## to settle, so the music swells with a wave and doesn't flicker.
const RISE := 1.2
const FALL := 0.35
## When muffled (pause menu, death), the filter closes this far.
const MUFFLED_CUTOFF := 350.0
const MUFFLED_DB := -9.0

var _players: Array[AudioStreamPlayer] = []
var _current := 0
var _track := ""
var _then := ""
var _target := 1.0
var _intensity := 1.0
var _muffled := false
var _muffle := 0.0  # 0..1, eased
var _filter: AudioEffectLowPassFilter
var _bus := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps playing through pauses
	_bus = AudioServer.get_bus_index("Music")
	if _bus >= 0 and AudioServer.get_bus_effect_count(_bus) > 0:
		_filter = AudioServer.get_bus_effect(_bus, 0) as AudioEffectLowPassFilter
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		player.volume_db = SILENT_DB
		player.finished.connect(_on_finished.bind(player))
		add_child(player)
		_players.append(player)


# Let go of the streams on quit, or Godot reports the playback as leaked.
func _exit_tree() -> void:
	for player in _players:
		player.stop()
		player.stream = null


## Crossfades to track `id` over `fade` seconds. With `then`, `id` plays once
## (an opening) and `then` loops after it. Asking for the playing track does
## nothing, so callers can ask every frame.
func play(id: String, fade := 1.5, then := "") -> void:
	if id == _track or (then != "" and then == _track):
		return
	_track = id
	_then = then
	var old := _players[_current]
	_current = 1 - _current
	var player := _players[_current]
	player.stream = _stream(id, then == "")
	player.volume_db = SILENT_DB if fade > 0.0 else TRACKS[id][1]
	player.play()
	var tween := create_tween().set_parallel()
	tween.tween_property(player, "volume_db", TRACKS[id][1], maxf(fade, 0.01)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if old.playing:
		tween.tween_property(old, "volume_db", SILENT_DB, maxf(fade, 0.01))
		tween.chain().tween_callback(old.stop)


func stop(fade := 2.0) -> void:
	_track = ""
	_then = ""
	var player := _players[_current]
	if player.playing:
		var tween := create_tween()
		tween.tween_property(player, "volume_db", SILENT_DB, fade)
		tween.tween_callback(player.stop)


func current() -> String:
	return _then if _then != "" else _track


## 0 = a lull (muffled, a bit quieter), 1 = full blast.
func set_intensity(value: float) -> void:
	_target = clampf(value, 0.0, 1.0)


## Muffles the music heavily (paused, dying), or lifts that again.
func muffle(on: bool) -> void:
	_muffled = on


func _process(delta: float) -> void:
	var rate := RISE if _target > _intensity else FALL
	_intensity = move_toward(_intensity, _target, rate * delta)
	_muffle = move_toward(_muffle, 1.0 if _muffled else 0.0, delta * 2.5)
	var cutoff := exp(lerpf(log(CALM_CUTOFF), log(FULL_CUTOFF), _intensity))
	cutoff = exp(lerpf(log(cutoff), log(MUFFLED_CUTOFF), _muffle))
	if _filter:
		_filter.cutoff_hz = cutoff
	if _bus >= 0:
		AudioServer.set_bus_volume_db(_bus, Settings.bus_db("music")
			+ lerpf(CALM_DB, 0.0, _intensity) + MUFFLED_DB * _muffle)


func _stream(id: String, loop: bool) -> AudioStream:
	var stream := load(DIR + TRACKS[id][0]) as AudioStreamOggVorbis
	stream.loop = loop
	return stream


# An opening ended: its loop takes over on the same player, without a fade.
func _on_finished(player: AudioStreamPlayer) -> void:
	if player != _players[_current] or _then == "":
		return
	var loop_id := _then
	_track = loop_id
	_then = ""
	player.stream = _stream(loop_id, true)
	player.volume_db = TRACKS[loop_id][1]
	player.play()
