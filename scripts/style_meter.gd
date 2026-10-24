class_name StyleMeter
extends Node
## A Devil May Cry-style rank for how well you're fighting. Kills raise it,
## idling lets it drain, and every hit you take knocks it down two ranks.
## Higher ranks pay more gold and XP, and push the music to full blast.
## main.gd owns it, so it pauses with the run.

signal rank_changed(rank: int, rising: bool)
## For the HUD gauge: the rank and how far into it (0..1).
signal changed(rank: int, progress: float)

const LETTERS := ["D", "C", "B", "A", "S", "SS", "SSS"]
const NAMES := ["Dull", "Cruel", "Brutal", "Atrocious", "Savage", "Sinful", "Soul Devourer"]
const COLORS := [Color(0.6, 0.58, 0.65), Color(0.55, 0.75, 1.0), Color(0.5, 1.0, 0.6),
	Color(1.0, 0.85, 0.35), Color(1.0, 0.55, 0.2), Color(1.0, 0.3, 0.25), Color(1.0, 0.2, 0.6)]
## Points needed for each rank on Day 1. Later days have far more enemies,
## so the bar rises with them (DAY_SCALE per day).
const THRESHOLDS := [0.0, 12.0, 30.0, 60.0, 100.0, 150.0, 220.0]
const DAY_SCALE := 0.12
const GOLD_MULT := [1.0, 1.05, 1.1, 1.2, 1.3, 1.45, 1.6]
const XP_MULT := [1.0, 1.03, 1.06, 1.1, 1.15, 1.2, 1.25]
const KILL_POINTS := 1.0
const ELITE_POINTS := 8.0
const DEVOUR_POINTS := 15.0
## After the last kill, style holds this long, then drains: a fixed amount
## plus a share of what you have, so high ranks need steady killing.
const GRACE := 2.0
const DRAIN_BASE := 2.0
const DRAIN_SHARE := 0.15
const RANKS_LOST_ON_HIT := 2

var points := 0.0
var rank := 0
var scale := 1.0  # main.gd sets it from the day
var _since_kill := 99.0


func add_kill(elite: bool) -> void:
	add(ELITE_POINTS if elite else KILL_POINTS)


func add(amount: float) -> void:
	_since_kill = 0.0
	points = minf(points + amount, threshold(LETTERS.size() - 1) * 1.3)
	_update()


## A hit drops you two ranks, to the start of that rank.
func on_hurt() -> void:
	var new_rank := maxi(rank - RANKS_LOST_ON_HIT, 0)
	points = minf(points, threshold(new_rank))
	_update()


func threshold(r: int) -> float:
	return THRESHOLDS[r] * scale


func gold_mult() -> float:
	return GOLD_MULT[rank]


func xp_mult() -> float:
	return XP_MULT[rank]


## 0..1, for the music.
func intensity() -> float:
	return float(rank) / (LETTERS.size() - 1)


func _physics_process(delta: float) -> void:
	_since_kill += delta
	if _since_kill > GRACE and points > 0.0:
		points = maxf(0.0, points - (DRAIN_BASE * scale + points * DRAIN_SHARE) * delta)
		_update()


func _update() -> void:
	var new_rank := 0
	for r in LETTERS.size():
		if points >= threshold(r):
			new_rank = r
	if new_rank != rank:
		var rising := new_rank > rank
		rank = new_rank
		rank_changed.emit(rank, rising)
	var top := rank == LETTERS.size() - 1
	var span := threshold(rank + 1) - threshold(rank) if not top else threshold(rank) * 0.3
	changed.emit(rank, clampf((points - threshold(rank)) / span, 0.0, 1.0))
