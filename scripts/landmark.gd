class_name Landmark
extends Node2D
## A point of interest in the world, placed by Landmarks. Each one is used
## once, by walking to it:
## - altar: step into its circle to start a trial; survive the surge for
##   ALTAR_TIME without leaving for long, then pick a reward.
## - well: stand in it a moment to trade a fifth of your HP for gold.
## - cage: come close and it breaks, freeing an elite with a trait.
## - grave: touch it for a one-time boon.
## Landmarks (scripts/run/landmarks.gd) acts on the signals.

signal trial_started(landmark: Landmark)
signal trial_won(landmark: Landmark)
signal trial_failed(landmark: Landmark)
signal used(landmark: Landmark)

const KINDS := {
	"altar": ["Cursed Altar", "Stand in its circle to begin a trial", Color(0.7, 0.4, 1.0)],
	"well": ["Bloody Well", "Stand in it to trade blood for gold", Color(0.85, 0.15, 0.2)],
	"cage": ["Iron Cage", "Something strong waits inside", Color(0.85, 0.6, 0.3)],
	"grave": ["Fallen Hero's Grave", "Touch it for a parting gift", Color(0.75, 0.9, 1.0)],
}
const ALTAR_RADIUS := 130.0
const ALTAR_TIME := 15.0
const ALTAR_GRACE := 2.0  # seconds outside the circle before the trial fails
const WELL_RADIUS := 34.0
const WELL_TIME := 1.0
const CAGE_REACH := 140.0
const GRAVE_REACH := 40.0
const NAME_REACH := 260.0  # its name shows when you're this close
const FADE := 2.5

var kind := "grave"
var spent := false
var trial := -1.0  # seconds into the altar's trial; < 0 = not running
var _outside := 0.0
var _standing := 0.0
var _label: Label
var _player: Node2D


func setup(landmark_kind: String, player: Node2D) -> void:
	kind = landmark_kind
	_player = player


func _enter_tree() -> void:
	add_to_group("landmarks")


func color() -> Color:
	return KINDS[kind][2]


func title() -> String:
	return KINDS[kind][0]


func _process(delta: float) -> void:
	if spent or not is_instance_valid(_player):
		return
	var distance := global_position.distance_to(_player.global_position)
	_show_name(distance < NAME_REACH and trial < 0.0)
	match kind:
		"altar":
			_altar(delta, distance)
		"well":
			_standing = _standing + delta if distance < WELL_RADIUS else 0.0
			if _standing >= WELL_TIME:
				_use()
		"cage":
			if distance < CAGE_REACH:
				_use()
		"grave":
			if distance < GRAVE_REACH:
				_use()
	queue_redraw()


func _altar(delta: float, distance: float) -> void:
	if trial < 0.0:
		if distance < ALTAR_RADIUS * 0.6:
			trial = 0.0
			trial_started.emit(self)
		return
	trial += delta
	_outside = _outside + delta if distance > ALTAR_RADIUS else 0.0
	if _outside >= ALTAR_GRACE:
		spent = true
		trial_failed.emit(self)
		_fade()
	elif trial >= ALTAR_TIME:
		spent = true
		trial_won.emit(self)
		_fade()


func _use() -> void:
	spent = true
	used.emit(self)
	_fade()


func _fade() -> void:
	_show_name(false)
	var tween := create_tween()
	tween.tween_interval(FADE * 0.4)
	tween.tween_property(self, "modulate:a", 0.0, FADE * 0.6)
	tween.tween_callback(queue_free)


func _show_name(on: bool) -> void:
	if on and _label == null:
		_label = Label.new()
		_label.text = "%s\n%s" % [tr(title()), tr(KINDS[kind][1])]
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 18)
		_label.add_theme_color_override("font_color", color().lightened(0.4))
		_label.size = Vector2(320, 48)
		_label.position = Vector2(-160, -96)
		_label.z_index = 10
		add_child(_label)
	if _label:
		_label.visible = on


func _draw() -> void:
	var tint := color()
	match kind:
		"altar":
			var running := trial >= 0.0 and not spent
			draw_circle(Vector2.ZERO, ALTAR_RADIUS, Color(tint, 0.08 if not running else 0.16))
			draw_arc(Vector2.ZERO, ALTAR_RADIUS, 0.0, TAU, 48, Color(tint, 0.6), 2.0)
			if running:  # the trial's remaining time, as a closing ring
				var left := 1.0 - trial / ALTAR_TIME
				draw_arc(Vector2.ZERO, ALTAR_RADIUS + 6.0, -PI / 2.0, -PI / 2.0 + TAU * left, 48, tint.lightened(0.3), 4.0)
			for i in 5:
				var at := Vector2.from_angle(TAU * i / 5.0 - PI / 2.0) * 20.0
				draw_rect(Rect2(at - Vector2(5, 9), Vector2(10, 18)), Color(0.25, 0.22, 0.3))
			draw_circle(Vector2.ZERO, 8.0, tint)
		"well":
			draw_circle(Vector2.ZERO, WELL_RADIUS + 8.0, Color(0.3, 0.28, 0.32))
			draw_circle(Vector2.ZERO, WELL_RADIUS, Color(0.35, 0.02, 0.05))
			draw_arc(Vector2.ZERO, WELL_RADIUS * (0.5 + 0.5 * minf(_standing / WELL_TIME, 1.0)), 0.0, TAU, 32, tint, 2.0)
		"cage":
			draw_rect(Rect2(-22, -30, 44, 44), Color(0.1, 0.08, 0.06, 0.6))
			for i in 6:
				var x := -20.0 + i * 8.0
				draw_line(Vector2(x, -30), Vector2(x, 14), Color(0.55, 0.45, 0.35), 3.0)
			draw_line(Vector2(-22, -30), Vector2(22, -30), Color(0.55, 0.45, 0.35), 4.0)
			draw_line(Vector2(-22, 14), Vector2(22, 14), Color(0.55, 0.45, 0.35), 4.0)
			draw_circle(Vector2(0, -8), 6.0, Color(tint, 0.6))
		"grave":
			draw_rect(Rect2(-12, -28, 24, 32), Color(0.45, 0.45, 0.5))
			draw_circle(Vector2(0, -28), 12.0, Color(0.45, 0.45, 0.5))
			draw_line(Vector2(18, 6), Vector2(18, -26), Color(0.75, 0.75, 0.8), 3.0)
			draw_line(Vector2(12, -18), Vector2(24, -18), Color(0.75, 0.75, 0.8), 3.0)
			draw_rect(Rect2(-14, 4, 28, 6), Color(0.3, 0.25, 0.2))
