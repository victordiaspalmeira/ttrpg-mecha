class_name MovementRules
extends RefCounted


static func get_move_cost(unit: UnitBase, target_tile: HexTile, grid_manager: GridManager) -> int:
	if not unit or not unit.current_tile or not target_tile or not grid_manager:
		return 0

	if target_tile == unit.current_tile:
		return 0

	return grid_manager.get_distance(unit.current_tile, target_tile)


static func get_reachable_tiles(unit: UnitBase, grid_manager: GridManager) -> Array[HexTile]:
	if not unit or not unit.current_tile or not grid_manager:
		return []

	if unit.current_movement <= 0:
		return []

	return grid_manager.get_reachable_tiles(unit.current_tile, unit.current_movement)


static func can_move_to(unit: UnitBase, target_tile: HexTile, grid_manager: GridManager) -> bool:
	if not unit or not target_tile or not unit.current_tile:
		return false

	if target_tile.occupying_unit:
		return false

	var cost: int = get_move_cost(unit, target_tile, grid_manager)
	if cost <= 0:
		return false

	if not unit.can_spend_movement(cost):
		return false

	return target_tile in get_reachable_tiles(unit, grid_manager)


static func get_move_failure_reason(
	unit: UnitBase,
	target_tile: HexTile,
	grid_manager: GridManager
) -> String:
	if not unit or not unit.current_tile:
		return "No unit selected."

	if target_tile == null:
		return "Select a destination tile."

	if target_tile == unit.current_tile:
		return "Already on that tile."

	if target_tile.occupying_unit:
		return "That tile is occupied."

	var cost: int = get_move_cost(unit, target_tile, grid_manager)
	if cost <= 0:
		return "Invalid destination."

	if not unit.can_spend_movement(cost):
		return "Not enough movement (%d needed)." % cost

	if target_tile not in get_reachable_tiles(unit, grid_manager):
		return "Destination is out of range."

	return "Cannot move there."


static func find_path(unit: UnitBase, target_tile: HexTile, grid_manager: GridManager) -> Array[HexTile]:
	if not unit or not unit.current_tile or not target_tile or not grid_manager:
		return []

	if target_tile == unit.current_tile:
		return [unit.current_tile]

	if not can_move_to(unit, target_tile, grid_manager):
		return []

	var start_tile: HexTile = unit.current_tile
	var came_from: Dictionary = {start_tile: null}
	var frontier: Array[HexTile] = [start_tile]
	var move_budget: int = unit.current_movement
	var distance_from_start: Dictionary = {start_tile: 0}

	while not frontier.is_empty():
		var current: HexTile = frontier.pop_front()
		var current_distance: int = int(distance_from_start[current])

		if current == target_tile:
			return _reconstruct_path(came_from, target_tile)

		if current_distance >= move_budget:
			continue

		for neighbor in grid_manager.get_neighbors(current):
			var neighbor_tile: HexTile = neighbor as HexTile
			if neighbor_tile == null:
				continue

			if neighbor_tile.occupying_unit and neighbor_tile != start_tile:
				continue

			if distance_from_start.has(neighbor_tile):
				continue

			distance_from_start[neighbor_tile] = current_distance + 1
			came_from[neighbor_tile] = current
			frontier.append(neighbor_tile)

	return []


static func _reconstruct_path(came_from: Dictionary, goal: HexTile) -> Array[HexTile]:
	var path: Array[HexTile] = [goal]
	var current: HexTile = goal

	while came_from.has(current) and came_from[current] != null:
		current = came_from[current] as HexTile
		path.push_front(current)

	return path
