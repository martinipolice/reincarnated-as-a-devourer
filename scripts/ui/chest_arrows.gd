extends Control
## HUD overlay: a golden arrow at the screen edge for each unopened chest
## that's off-screen, pointing the way to it.

const MARGIN := 36.0
const SIZE := 22.0
const COLOR := Color(1, 0.85, 0.35)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect()
	var center := view.size / 2.0
	var inner := view.grow(-MARGIN)
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 180.0)
	for node in get_tree().get_nodes_in_group("chests"):
		var chest := node as LootChest
		if chest.is_open:
			continue
		var on_screen := chest.get_global_transform_with_canvas().origin
		if inner.has_point(on_screen):
			continue
		var dir := (on_screen - center).normalized()
		# Push the arrow out from the center until it touches the margin box.
		var reach := minf(absf((inner.size.x / 2.0) / dir.x) if dir.x != 0.0 else INF,
			absf((inner.size.y / 2.0) / dir.y) if dir.y != 0.0 else INF)
		var tip := center + dir * reach
		var side := dir.orthogonal() * SIZE * 0.6
		var points := PackedVector2Array([tip, tip - dir * SIZE + side, tip - dir * SIZE - side])
		draw_colored_polygon(points, Color(COLOR, pulse))
		draw_polyline(points + PackedVector2Array([tip]), Color(0, 0, 0, 0.6), 1.5)
