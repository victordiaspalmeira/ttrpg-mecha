class_name GridManager
extends Node3D

const HEX_DIRECTIONS := [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
]

const DEFAULT_CONFIG := preload("res://data/grid/default_grid_config.tres")

var tiles: Dictionary = {}

@export var config: GridConfig
@export var hex_tile_scene: PackedScene

var _grid_radius: int = 0


func _ready() -> void:
	if config == null:
		config = DEFAULT_CONFIG


func initialize(encounter: EncounterData = null) -> void:
	if config == null:
		config = DEFAULT_CONFIG

	var radius: int = config.grid_radius
	if encounter != null and encounter.grid_radius > 0:
		radius = encounter.grid_radius

	if not tiles.is_empty() and radius == _grid_radius:
		return

	clear_grid()
	_grid_radius = radius
	generate_grid(radius)


func clear_grid() -> void:
	for tile in tiles.values():
		if is_instance_valid(tile):
			tile.queue_free()
	tiles.clear()


func generate_grid(radius: int) -> void:
	for q in range(-radius, radius + 1):
		var r1: int = maxi(-radius, -q - radius)
		var r2: int = mini(radius, -q + radius)

		for r in range(r1, r2 + 1):
			var tile: HexTile = hex_tile_scene.instantiate() as HexTile
			tile.q = q
			tile.r = r
			tile.position = axial_to_world(q, r)
			add_child(tile)
			tile.configure(config)
			tiles[Vector2i(q, r)] = tile


func axial_to_world(q: int, r: int) -> Vector3:
	return HexMath.axial_to_world(q, r, config.hex_size)


func world_to_axial(world: Vector3) -> Vector2i:
	return HexMath.world_to_axial(world, config.hex_size)


func get_tile(q: int, r: int) -> HexTile:
	return tiles.get(Vector2i(q, r)) as HexTile


func get_tile_at_world(world: Vector3) -> HexTile:
	var axial: Vector2i = world_to_axial(world)
	return get_tile(axial.x, axial.y)


func get_distance(tile_a: HexTile, tile_b: HexTile) -> int:
	return HexMath.axial_distance_tiles(tile_a, tile_b)


func get_neighbors(tile: HexTile) -> Array[HexTile]:
	var neighbors: Array[HexTile] = []

	for direction in HEX_DIRECTIONS:
		var neighbor: HexTile = get_tile(tile.q + direction.x, tile.r + direction.y)
		if neighbor:
			neighbors.append(neighbor)

	return neighbors


func get_tiles_in_range(center_tile: HexTile, tile_range: int) -> Array[HexTile]:
	if center_tile == null or tile_range < 0:
		return []

	var tiles_in_range: Array[HexTile] = []
	var visited: Dictionary = {Vector2i(center_tile.q, center_tile.r): true}
	var frontier: Array[HexTile] = [center_tile]

	for _distance in tile_range + 1:
		var next_frontier: Array[HexTile] = []

		for tile in frontier:
			tiles_in_range.append(tile)

			if _distance == tile_range:
				continue

			for neighbor in get_neighbors(tile):
				var key: Vector2i = Vector2i(neighbor.q, neighbor.r)
				if visited.has(key):
					continue
				visited[key] = true
				next_frontier.append(neighbor)

		frontier = next_frontier

	return tiles_in_range


func get_reachable_tiles(start_tile: HexTile, move_range: int) -> Array[HexTile]:
	if start_tile == null or move_range <= 0:
		return []

	var reachable_tiles: Array[HexTile] = []
	var visited: Dictionary = {start_tile: true}
	var frontier: Array[Dictionary] = [{"tile": start_tile, "distance": 0}]

	while not frontier.is_empty():
		var current: Dictionary = frontier.pop_front()
		var current_tile: HexTile = current.tile as HexTile
		var current_distance: int = int(current.distance)

		reachable_tiles.append(current_tile)

		if current_distance >= move_range:
			continue

		for neighbor in get_neighbors(current_tile):
			if visited.has(neighbor):
				continue

			if neighbor.occupying_unit and neighbor != start_tile:
				continue

			visited[neighbor] = true
			frontier.append({
				"tile": neighbor,
				"distance": current_distance + 1,
			})

	return reachable_tiles
