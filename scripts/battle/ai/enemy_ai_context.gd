class_name EnemyAIContext
extends RefCounted

var unit: UnitBase
var grid_manager: GridManager = null
var combat_resolver: CombatResolver = null
var all_units: Array[UnitBase] = []


static func create(
	p_unit: UnitBase,
	p_grid_manager: GridManager,
	p_combat_resolver: CombatResolver,
	p_all_units: Array[UnitBase]
) -> EnemyAIContext:
	var context := EnemyAIContext.new()
	context.unit = p_unit
	context.grid_manager = p_grid_manager
	context.combat_resolver = p_combat_resolver
	context.all_units = p_all_units
	return context


func get_opponents() -> Array[UnitBase]:
	var opponents: Array[UnitBase] = []

	for other in all_units:
		if not is_instance_valid(other):
			continue

		if other == unit or other.team_id == unit.team_id:
			continue

		opponents.append(other)

	return opponents


func find_nearest_opponent() -> UnitBase:
	var best: UnitBase = null
	var best_distance: int = 999999

	if not unit.current_tile:
		return null

	for other in get_opponents():
		if not other.current_tile:
			continue

		var distance: int = grid_manager.get_distance(
			unit.current_tile,
			other.current_tile
		)

		if distance < best_distance:
			best_distance = distance
			best = other

	return best


func can_attack(target: UnitBase) -> bool:
	if not is_instance_valid(target):
		return false

	return combat_resolver.can_attack(unit, target)


func find_best_move_tile_toward(target: UnitBase) -> HexTile:
	if not is_instance_valid(target) or not target.current_tile:
		return null

	var reachable: Array[HexTile] = MovementRules.get_reachable_tiles(unit, grid_manager)

	var best_tile: HexTile = null
	var best_distance: int = 999999

	for tile in reachable:
		if tile == unit.current_tile:
			continue

		var distance: int = grid_manager.get_distance(tile, target.current_tile)

		if distance < best_distance:
			best_distance = distance
			best_tile = tile

	return best_tile
