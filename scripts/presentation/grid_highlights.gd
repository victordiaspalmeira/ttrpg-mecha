class_name GridHighlights
extends Node

var world: Node3D = null
var selection_state: SelectionState = null

var grid_manager: GridManager = null
var _last_cache_key: String = ""


func _ready() -> void:
	# Find nodes by absolute path
	world = get_node("/root/BattleScene/World") as Node3D
	selection_state = get_node("/root/BattleScene/BattleSession/SelectionState") as SelectionState

	if not world or not selection_state:
		push_error("GridHighlights: missing required scene nodes")
		return

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
		SelectionState.ActionMode.ACTION:
			show_action_tiles(selection_state.selected_unit)


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


## Unified action tile highlighting. Uses the pending action's SkillData to determine
## range and targeting (replaces old show_attack_tiles and show_skill_tiles).
func show_action_tiles(unit: UnitBase) -> void:
	if not unit or not unit.current_tile:
		return

	# Get the pending action from BattleHud
	var battle_hud: BattleHud = get_tree().current_scene.get_node_or_null("BattleSession/BattleHud")
	if not battle_hud or not battle_hud._pending_action:
		return

	var action: SkillData = battle_hud._pending_action

	# Check AP
	if action.ap_cost > unit.current_ap:
		return

	var center_tile: HexTile = unit.current_tile

	# For SELF actions, no range highlighting needed
	if action.target_mode == SkillData.TargetMode.SELF:
		return

	# Handle AOE centered on caster (range 0)
	if action.target_mode == SkillData.TargetMode.AOE_CIRCLE and action.skill_range <= 0:
		var tiles_in_range: Array[HexTile] = grid_manager.get_tiles_in_range(center_tile, action.aoe_radius)
		for tile in tiles_in_range:
			if tile == center_tile:
				continue
			tile.show_attack_reach()
		# Highlight enemies in range
		for tile in tiles_in_range:
			if tile.occupying_unit:
				_highlight_target_tile(tile, unit, action)
		return

	# Standard range-based actions
	var tiles_in_range: Array[HexTile] = grid_manager.get_tiles_in_range(center_tile, action.skill_range)
	for tile in tiles_in_range:
		if tile == center_tile:
			continue
		tile.show_attack_reach()

	# Highlight valid targets based on team filter
	for tile in tiles_in_range:
		if tile.occupying_unit:
			_highlight_target_tile(tile, unit, action)


## Highlights specific target tiles based on the action's team filter.
func _highlight_target_tile(tile: HexTile, caster: UnitBase, action: SkillData) -> void:
	var target := tile.occupying_unit
	if not target:
		return

	match action.team_filter:
		SkillData.TeamFilter.ENEMY:
			if not caster.is_same_team(target):
				tile.show_attack_range()
		SkillData.TeamFilter.ALLY:
			if caster.is_same_team(target):
				tile.show_attack_range()
		SkillData.TeamFilter.BOTH:
			tile.show_attack_range()
		SkillData.TeamFilter.SELF_ONLY:
			if target == caster:
				tile.show_attack_range()


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