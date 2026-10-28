class_name OrnateBox
extends StyleBox
## The souls frame: a near-black panel inside a thin bronze edge, a fainter
## inner line a few pixels in, and small gold studs at the corners. Drawn on
## whole pixels so it stays crisp at any UI scale.

var fill := UITheme.INK
var edge := UITheme.BRONZE
var stud := UITheme.GOLD
var inset := 5.0  # from the edge to the inner line


func _init(fill_color := UITheme.INK, edge_color := UITheme.BRONZE, margin := 14.0) -> void:
	fill = fill_color
	edge = edge_color
	stud = edge_color.lerp(UITheme.GOLD, 0.6)
	content_margin_left = margin
	content_margin_right = margin
	content_margin_top = margin * 0.8
	content_margin_bottom = margin * 0.8


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var rs := RenderingServer
	rect = Rect2(rect.position.floor(), rect.size.floor())
	rs.canvas_item_add_rect(to_canvas_item, rect, fill)
	_outline(to_canvas_item, rect, edge, 2.0)
	_outline(to_canvas_item, rect.grow(-inset), Color(edge, 0.35), 1.0)
	# Corner studs: a 6 px diamond-ish square, two shades.
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y),
			Vector2(rect.position.x, rect.end.y), rect.end]:
		rs.canvas_item_add_rect(to_canvas_item, Rect2(corner - Vector2(4, 4), Vector2(8, 8)), Color(0.04, 0.03, 0.05))
		rs.canvas_item_add_rect(to_canvas_item, Rect2(corner - Vector2(3, 3), Vector2(6, 6)), stud)
		rs.canvas_item_add_rect(to_canvas_item, Rect2(corner - Vector2(1, 1), Vector2(2, 2)), stud.darkened(0.5))


func _outline(item: RID, rect: Rect2, color: Color, width: float) -> void:
	var rs := RenderingServer
	rs.canvas_item_add_rect(item, Rect2(rect.position, Vector2(rect.size.x, width)), color)
	rs.canvas_item_add_rect(item, Rect2(rect.position.x, rect.end.y - width, rect.size.x, width), color)
	rs.canvas_item_add_rect(item, Rect2(rect.position, Vector2(width, rect.size.y)), color)
	rs.canvas_item_add_rect(item, Rect2(rect.end.x - width, rect.position.y, width, rect.size.y), color)
