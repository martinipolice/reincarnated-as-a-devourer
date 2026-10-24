class_name ChunkWorld
extends Node2D
## Endless procedural terrain, built in square chunks around the player from a
## per-run seed, like Minecraft's chunks: the same seed and chunk always give
## the same ground, so walking away and back finds things where you left them.
## Chunks off-screen are unloaded. The biome follows the story:
## - forest (Days 1-9): grass, tufts, bushes, flowers, trees and stumps
## - ruins (Day 10+): cracked earth, dead trees, rocks and boulders
## - temple: the Demon King's arena, a ring of stone (with four openings)
##   around dark cobbles
## Chunks already on screen keep their look; new ones (and old ones once out
## of view) use the current biome, so the world changes as you explore.
## Trees and rocks block movement (StaticBody2D for the player, Obstacles for
## enemies); bushes, flowers and patches are decoration.

const TILE := 16  # art pixels
const SCALE := 2.0  # the art is drawn at 2x
const CHUNK_TILES := 16
const CHUNK_PX := TILE * SCALE * CHUNK_TILES  # 512 world px
const VIEW_MARGIN := 1  # extra chunks loaded beyond the screen edge
const UNLOAD_MARGIN := 3
const SAFE_RADIUS := 240.0  # no obstacles this close to where the run starts
const OBSTACLE_LAYER := 4  # physics layer 3, "obstacles"
const CANDIDATE_STEP := 4  # tiles between obstacle candidate spots
const ARENA_PILLAR_GAP := 58.0
## Openings in the arena ring (fraction of the circle each), so the duel
## never corners you against the wall.
const ARENA_OPENINGS := 4
const ARENA_OPENING_SIZE := 0.06
const FLOOR_TEX := preload("res://assets/ninja/images/tiles_floor.png")
const NATURE_TEX := preload("res://assets/ninja/images/tiles_nature.png")
const INTERIOR_TEX := preload("res://assets/ninja/images/tiles_interior_floor.png")

enum Source { FLOOR, INTERIOR }

## Ground tiles per biome: [source, atlas coords, weight].
const GROUND := {
	"forest": [
		[Source.FLOOR, Vector2i(2, 11), 30], [Source.FLOOR, Vector2i(3, 11), 30],
		[Source.FLOOR, Vector2i(0, 12), 5], [Source.FLOOR, Vector2i(1, 12), 5],
		[Source.FLOOR, Vector2i(2, 12), 5], [Source.FLOOR, Vector2i(3, 12), 5],
		[Source.FLOOR, Vector2i(4, 12), 5],
	],
	"ruins": [
		[Source.FLOOR, Vector2i(11, 19), 24], [Source.FLOOR, Vector2i(12, 19), 8],
		[Source.FLOOR, Vector2i(13, 19), 8], [Source.FLOOR, Vector2i(14, 19), 8],
		[Source.FLOOR, Vector2i(15, 19), 8],
	],
	"temple": [
		[Source.INTERIOR, Vector2i(13, 13), 10], [Source.INTERIOR, Vector2i(14, 13), 10],
		[Source.INTERIOR, Vector2i(13, 14), 10], [Source.INTERIOR, Vector2i(14, 14), 10],
	],
}
## Decoration props from the nature sheet (regions in tiles), no collision.
const DECOR := {
	"forest": [Rect2i(0, 10, 1, 1), Rect2i(1, 10, 1, 1), Rect2i(2, 10, 1, 1), Rect2i(3, 10, 1, 1),
		Rect2i(4, 10, 1, 1), Rect2i(0, 11, 1, 1), Rect2i(1, 11, 1, 1), Rect2i(5, 11, 1, 1),
		Rect2i(4, 13, 1, 1)],
	"ruins": [Rect2i(16, 9, 1, 1), Rect2i(17, 9, 1, 1), Rect2i(12, 11, 1, 1),
		Rect2i(13, 11, 1, 1), Rect2i(16, 9, 1, 1)],
}
## Blocking props: [region in tiles, collision radius in world px, weight].
const BLOCKERS := {
	"forest": [[Rect2i(0, 0, 2, 2), 14.0, 4], [Rect2i(16, 0, 2, 2), 14.0, 4],
		[Rect2i(18, 0, 2, 2), 14.0, 3], [Rect2i(2, 8, 2, 2), 18.0, 1]],
	"ruins": [[Rect2i(4, 0, 2, 2), 14.0, 3], [Rect2i(16, 6, 2, 2), 24.0, 3],
		[Rect2i(12, 6, 2, 2), 24.0, 2], [Rect2i(2, 8, 2, 2), 18.0, 1]],
}
## How thick each biome's obstacles grow (noise threshold; lower = denser).
const DENSITY := {"forest": 0.2, "ruins": 0.15}
const PILLAR := [Rect2i(16, 6, 2, 2), 24.0]

var biome := "forest"
var seed_value := 0

var _noise := FastNoiseLite.new()
var _chunks := {}  # Vector2i -> {"node": Node2D, "obstacles": Array, "biome": String}
var _ground: TileMapLayer
var _props: Node2D
var _regions := {}  # cached AtlasTextures
var _arena_center := Vector2.ZERO
var _arena_radius := 0.0
var _origin := Vector2.ZERO


func _ready() -> void:
	seed_value = randi()
	_noise.seed = seed_value
	_noise.frequency = 0.06
	_ground = TileMapLayer.new()
	_ground.tile_set = _make_tile_set()
	_ground.scale = Vector2(SCALE, SCALE)
	_ground.z_index = -10
	add_child(_ground)
	_props = Node2D.new()
	_props.y_sort_enabled = true
	add_child(_props)
	y_sort_enabled = true


func _exit_tree() -> void:
	Obstacles.clear()


## Builds and drops chunks around `center` (the player); call every frame.
func update(center: Vector2, view_size: Vector2) -> void:
	var low := _chunk_of(center - view_size / 2.0) - Vector2i.ONE * VIEW_MARGIN
	var high := _chunk_of(center + view_size / 2.0) + Vector2i.ONE * VIEW_MARGIN
	var on_screen := Rect2i(_chunk_of(center - view_size / 2.0),
		_chunk_of(center + view_size / 2.0) - _chunk_of(center - view_size / 2.0) + Vector2i.ONE)
	var built := 0
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			var key := Vector2i(x, y)
			var stale: bool = _chunks.has(key) and _chunks[key].biome != _biome_for(key) \
				and not on_screen.has_point(key)
			if (not _chunks.has(key) or stale) and built < 2:  # spread work over frames
				if stale:
					_unload(key)
				_build(key)
				built += 1
	for key: Vector2i in _chunks.keys():
		if key.x < low.x - UNLOAD_MARGIN or key.x > high.x + UNLOAD_MARGIN \
				or key.y < low.y - UNLOAD_MARGIN or key.y > high.y + UNLOAD_MARGIN:
			_unload(key)


## Where the run starts: kept clear of obstacles.
func set_origin(at: Vector2) -> void:
	_origin = at


## Turns a circle of the world into the Demon King's temple: dark stone
## inside, a closed ring of stone pillars at the edge. Rebuilds at once.
func make_arena(center: Vector2, radius: float) -> void:
	_arena_center = center
	_arena_radius = radius
	for key: Vector2i in _chunks.keys():
		if _chunk_rect(key).grow(radius).has_point(center):
			_unload(key)
			_build(key)


func _biome_for(key: Vector2i) -> String:
	if _arena_radius > 0.0 and _chunk_rect(key).grow(_arena_radius + 80.0).has_point(_arena_center):
		return "arena"
	return biome


func _build(key: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, key.x, key.y])
	var chunk_biome := _biome_for(key)
	var node := Node2D.new()
	node.y_sort_enabled = true
	_props.add_child(node)
	var record := {"node": node, "obstacles": [], "biome": chunk_biome}
	_chunks[key] = record
	var base_tile := key * CHUNK_TILES
	var ground_biome := biome if chunk_biome == "arena" else chunk_biome
	# Ground.
	for tx in CHUNK_TILES:
		for ty in CHUNK_TILES:
			var cell := base_tile + Vector2i(tx, ty)
			var tile_biome := ground_biome
			if chunk_biome == "arena" and _in_arena(_cell_center(cell), 0.0):
				tile_biome = "temple"
			var pick: Array = _weighted(GROUND[tile_biome], rng)
			_ground.set_cell(cell, pick[0], pick[1])
	if not GROUND.has(ground_biome) or ground_biome == "temple":
		return
	var origin := Vector2(base_tile) * TILE * SCALE
	# Decoration.
	for i in 14:
		var spot := origin + Vector2(rng.randf(), rng.randf()) * CHUNK_PX
		if not _in_arena(spot, 20.0):
			node.add_child(_sprite(NATURE_TEX, DECOR[ground_biome][rng.randi() % DECOR[ground_biome].size()], spot, true))
	# Obstacles on a jittered grid, in noise-shaped clusters.
	for gx in range(0, CHUNK_TILES, CANDIDATE_STEP):
		for gy in range(0, CHUNK_TILES, CANDIDATE_STEP):
			var spot := origin + (Vector2(gx, gy) + Vector2(rng.randf(), rng.randf()) * CANDIDATE_STEP) * TILE * SCALE
			var density := _noise.get_noise_2dv(spot / (TILE * SCALE) * 0.5 + Vector2(500, 500))
			if density < DENSITY[ground_biome] or rng.randf() < 0.5:
				continue
			if spot.distance_to(_origin) < SAFE_RADIUS or _in_arena(spot, 90.0):
				continue
			var blocker: Array = _weighted(BLOCKERS[ground_biome], rng)
			_add_blocker(record, blocker[0], blocker[1], spot)
	if chunk_biome == "arena":
		_add_arena_ring(record, key)


# A closed ring of pillars on the arena's edge, the pieces that fall in this chunk.
func _add_arena_ring(record: Dictionary, key: Vector2i) -> void:
	var count := ceili(TAU * _arena_radius / ARENA_PILLAR_GAP)
	var rect := _chunk_rect(key)
	for i in count:
		var turn := float(i) / count
		if fmod(turn * ARENA_OPENINGS + 0.5, 1.0) < ARENA_OPENING_SIZE * ARENA_OPENINGS:
			continue  # leave a gap
		var spot := _arena_center + Vector2.RIGHT.rotated(TAU * turn) * _arena_radius
		if rect.has_point(spot):
			_add_blocker(record, PILLAR[0], PILLAR[1], spot)


func _add_blocker(record: Dictionary, region: Rect2i, radius: float, spot: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = OBSTACLE_LAYER
	body.collision_mask = 0
	body.position = spot
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	body.add_child(shape)
	body.add_child(_sprite(NATURE_TEX, region, Vector2(0, radius * 0.5), true))
	record.node.add_child(body)
	record.obstacles.append(Obstacles.add(spot, radius))


func _unload(key: Vector2i) -> void:
	var record: Dictionary = _chunks[key]
	for handle: Dictionary in record.obstacles:
		Obstacles.remove(handle)
	record.node.queue_free()
	var base_tile := key * CHUNK_TILES
	for tx in CHUNK_TILES:
		for ty in CHUNK_TILES:
			_ground.erase_cell(base_tile + Vector2i(tx, ty))
	_chunks.erase(key)


# A sprite cut from a sheet. Standing props are anchored at their base, so
# y-sorting puts you behind a tree's canopy and in front of its trunk.
func _sprite(sheet: Texture2D, region: Rect2i, at: Vector2, standing: bool) -> Sprite2D:
	var key := [sheet.resource_path, region]
	if not _regions.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(region.position * TILE, region.size * TILE)
		_regions[key] = atlas
	var sprite := Sprite2D.new()
	sprite.texture = _regions[key]
	sprite.scale = Vector2(SCALE, SCALE)
	sprite.position = at
	if standing:
		sprite.offset = Vector2(0, -region.size.y * TILE / 2.0)
	return sprite


func _make_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	for source: int in [Source.FLOOR, Source.INTERIOR]:
		var atlas := TileSetAtlasSource.new()
		atlas.texture = FLOOR_TEX if source == Source.FLOOR else INTERIOR_TEX
		atlas.texture_region_size = Vector2i(TILE, TILE)
		tile_set.add_source(atlas, source)
	for tiles: Array in GROUND.values():
		for entry: Array in tiles:
			var atlas: TileSetAtlasSource = tile_set.get_source(entry[0])
			if not atlas.has_tile(entry[1]):
				atlas.create_tile(entry[1])
	return tile_set


func _weighted(table: Array, rng: RandomNumberGenerator) -> Array:
	var total := 0
	for entry: Array in table:
		total += entry[entry.size() - 1]
	var pick := rng.randi_range(1, total)
	for entry: Array in table:
		pick -= entry[entry.size() - 1]
		if pick <= 0:
			return entry
	return table.back()


func _in_arena(at: Vector2, margin: float) -> bool:
	return _arena_radius > 0.0 and at.distance_to(_arena_center) < _arena_radius + margin


func _chunk_of(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / CHUNK_PX), floori(at.y / CHUNK_PX))


func _chunk_rect(key: Vector2i) -> Rect2:
	return Rect2(Vector2(key) * CHUNK_PX, Vector2(CHUNK_PX, CHUNK_PX))


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE * SCALE
