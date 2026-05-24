class_name MovementRules
extends RefCounted


static func get_move_cost(unit: UnitBase, target_tile: HexTile, grid_manager: GridManager) -> int:
	if not unit or not unit.current_tile or not target_tile or not grid_manager:
		return 0

	if target_tile == unit.current_tile:
		return 0

	# Use A* path to calculate true cost with variable terrain costs
	var path: Array[HexTile] = grid_manager.find_path_astar(unit.current_tile, target_tile)
	if path.is_empty():
		return 999  # Unreachable

	# Sum the costs (don't count starting tile)
	var total_cost := 0
	for i in range(1, path.size()):
		total_cost += path[i].get_move_cost()

	return total_cost


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

	# Use A* pathfinder with movement budget as max_cost
	var move_budget: int = unit.current_movement
	return grid_manager.find_path_astar(unit.current_tile, target_tile, move_budget)
