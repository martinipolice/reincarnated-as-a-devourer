extends Control
## HUD overlay: an arrow at the screen edge for each thing worth finding
## that's off-screen, pointing the way to it:
## - golden: unopened chests
## - the essence's own color, smaller and quicker: an elite's essence to Devour
##   (they fade, so it matters to get there)
## - red: the Demon King, or a mini-boss
## - the landmark's own color, a diamond: a point of interest not yet used

const MARGIN := 36.0
const SIZE := 22.0
const CHEST_COLOR := Color(1, 0.85, 0.35)
const BOSS_COLOR := Color(0.95, 0.2, 0.2)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect()
	var center := view.size / 2.0
	var inner := view.grow(-MARGIN)
	var now := Time.get_ticks_msec()
	var pulse := 0.75 + 0.25 * sin(now / 180.0)
	for node in get_tree().get_nodes_in_group("chests"):
		var chest := node as LootChest
		if not chest.is_open:
			_arrow(chest, center, inner, Color(CHEST_COLOR, pulse), SIZE)
	var quick := 0.7 + 0.3 * sin(now / 90.0)
	for node in get_tree().get_nodes_in_group("corpses"):
		var corpse := node as DevourCorpse
		_arrow(corpse, center, inner, Color(corpse.essence.color.lightened(0.5), quick), SIZE * 0.8)
	for node in get_tree().get_nodes_in_group("landmarks"):
		var landmark := node as Landmark
		if not landmark.spent:
			_arrow(landmark, center, inner, Color(landmark.color().lightened(0.3), pulse), SIZE * 0.9)
	var main := owner as Node
	for key in ["boss", "mini_boss"]:
		if main and is_instance_valid(main.get(key)):
			_arrow(main.get(key), center, inner, Color(BOSS_COLOR, pulse), SIZE * 1.2)


func _arrow(target: Node2D, center: Vector2, inner: Rect2, color: Color, size: float) -> void:
	var on_screen := target.get_global_transform_with_canvas().origin
	if inner.has_point(on_screen):
		return
	var dir := (on_screen - center).normalized()
	# Push the arrow out from the center until it touches the margin box.
	var reach := minf(absf((inner.size.x / 2.0) / dir.x) if dir.x != 0.0 else INF,
		absf((inner.size.y / 2.0) / dir.y) if dir.y != 0.0 else INF)
	var tip := center + dir * reach
	var side := dir.orthogonal() * size * 0.6
	var points := PackedVector2Array([tip, tip - dir * size + side, tip - dir * size - side])
	draw_colored_polygon(points, color)
	draw_polyline(points + PackedVector2Array([tip]), Color(0, 0, 0, 0.6), 1.5)
