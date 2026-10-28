class_name OrnateRule
extends Control
## A thin divider that fades out at both ends, with a small gold diamond in
## the middle: under titles and between sections.

var color := UITheme.BRONZE


func _init(width := 360.0, rule_color := UITheme.BRONZE) -> void:
	color = rule_color
	custom_minimum_size = Vector2(width, 10)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var mid := (size / 2.0).floor()
	var steps := 24
	var half := size.x / 2.0
	for i in steps:  # each half: segments that fade toward the end
		var a := float(i) / steps
		var w := half / steps
		var c := Color(color, (1.0 - a) * 0.9)
		draw_rect(Rect2(mid.x + a * half, mid.y, ceilf(w), 1), c)
		draw_rect(Rect2(mid.x - a * half - w, mid.y, ceilf(w), 1), c)
	var diamond := PackedVector2Array([mid + Vector2(0, -4), mid + Vector2(4, 0), mid + Vector2(0, 4), mid + Vector2(-4, 0)])
	draw_colored_polygon(diamond, color.lerp(UITheme.GOLD, 0.6))
