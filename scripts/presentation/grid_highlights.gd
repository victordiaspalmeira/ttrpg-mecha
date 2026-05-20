class_name GridHighlights
extends Node

@onready var world: Node3D = %World
@onready var selection_state: SelectionState = %SelectionState

var grid_manager: GridManager = null
var _last_cache_key: String = ""


func _ready() -> void:
	grid_manager = world.get_node("GridManager") as GridManager

	selection_state.unit_selected.connect(_on_unit_selected)
	selection_state.action_mode_changed.connect(_on_action_mode_changed)


func _on_unit_selected(_unit: UnitBase) -> void:
	refresh_highlights()


func _on_action_mode_changed(_mode: SelectionState.ActionMode) -> void:
	refresh_highlights()


func refresh_highlights() -> void:
	var cache_key: String = _build_cache_key()
	if cache_key == _last_cache_key:
		return
	_last_cache_key = cache_key

	clear_all_tiles()

	if not selection_state.selected_unit:
		return

	match selection_state.current_action_mode:
		SelectionState.ActionMode.MOVE:
			show_move_tiles(selection_state.selected_unit)
		SelectionState.ActionMode.ATTACK:
			show_attack_tiles(selection_state.selected_unit)
		SelectionState.ActionMode.SKILL:
			show_skill_tiles(selection_state.selected_unit)


func invalidate_cache() -> void:
	_last_cache_key = ""


func clear_all_tiles() -> void:
	if not grid_manager:
		return

	invalidate_cache()

	for tile in grid_manager.tiles.values():
		var hex_tile := tile as HexTile
		if hex_tile:
			hex_tile.clear_move_range()
			hex_tile.clear_attack_range()
			hex_tile.clear_attack_reach()


func show_move_tiles(unit: UnitBase) -> void:
	if not unit or not unit.current_tile or unit.current_movement <= 0:
		return

	var move_tiles: Array[HexTile] = MovementRules.get_reachable_tiles(unit, grid_manager)

	for tile in move_tiles:
		if tile == unit.current_tile:
			continue
		tile.show_move_range()


func show_attack_tiles(unit: UnitBase) -> void:
	if not unit or not unit.current_tile:
		return

	if not unit.can_spend_ap(unit.get_attack_ap_cost()):
		return

	var attack_tiles: Array[HexTile] = grid_manager.get_tiles_in_range(
		unit.current_tile,
		unit.attack_range
	)

	for tile in attack_tiles:
		if tile == unit.current_tile:
			continue
		tile.show_attack_reach()

	for tile in attack_tiles:
		if not tile.occupying_unit:
			continue

		var target_unit: UnitBase = tile.occupying_unit
		if target_unit.team_id == unit.team_id:
			continue

		tile.show_attack_range()


func show_skill_tiles(unit: UnitBase) -> void:
	if not unit or not unit.current_tile:
		return

	# Get the pending skill from BattleHud
	var battle_hud: BattleHud = get_tree().current_scene.get_node_or_null("BattleSession/BattleHud")
	if not battle_hud or not battle_hud._pending_skill:
		return

	var skill: SkillData = battle_hud._pending_skill
	var center_tile: HexTile = unit.current_tile

	# For AOE skills, show all tiles in range
	if skill.target_mode == SkillData.TargetMode.AOE_CIRCLE:
		var skill_range: int = skill.aoe_radius
		if skill.skill_range > 0:
			skill_range = skill.skill_range
		var tiles_in_range: Array[HexTile] = grid_manager.get_tiles_in_range(center_tile, skill_range)
		for tile in tiles_in_range:
			if tile == center_tile:
				continue
			tile.show_attack_reach()
		# Highlight enemy units in range
		for tile in tiles_in_range:
			if tile.occupying_unit and not unit.is_same_team(tile.occupying_unit):
				tile.show_attack_range()
	# For single unit skills, show tiles in range
	elif skill.target_mode == SkillData.TargetMode.SINGLE_UNIT:
		var tiles_in_range: Array[HexTile] = grid_manager.get_tiles_in_range(center_tile, skill.skill_range)
		for tile in tiles_in_range:
			if tile == center_tile:
				continue
			tile.show_attack_reach()
		for tile in tiles_in_range:
			if tile.occupying_unit and not unit.is_same_team(tile.occupying_unit):
				tile.show_attack_range()
	# For SELF skills, no highlighting needed


func _build_cache_key() -> String:
	var unit_id: String = "none"
	var mode: int = int(selection_state.current_action_mode)
	var move: int = 0
	var ap: int = 0
	var range_val: int = 0
	var tile_key: String = "none"

	var unit: UnitBase = selection_state.selected_unit
	if unit:
		unit_id = str(unit.get_instance_id())
		move = unit.current_movement
		ap = unit.current_ap
		range_val = unit.attack_range
		if unit.current_tile:
			tile_key = "%d,%d" % [unit.current_tile.q, unit.current_tile.r]

	return "%s|%d|%d|%d|%d|%s" % [unit_id, mode, move, ap, range_val, tile_key]
