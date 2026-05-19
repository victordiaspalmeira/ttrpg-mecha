class_name BattleInput
extends Node

var battle_flow: BattleFlow = null
var selection_state: SelectionState = null
var grid_manager: GridManager = null
var turn_controller: TurnController = null
var camera: Camera3D = null

var move_button: Button = null
var attack_button: Button = null
var end_turn_button: Button = null

var _last_hovered_tile: HexTile = null
var _last_action_frame: int = -1


func setup(
	p_battle_flow: BattleFlow,
	p_selection_state: SelectionState,
	p_grid_manager: GridManager,
	p_turn_controller: TurnController
) -> void:
	battle_flow = p_battle_flow
	selection_state = p_selection_state
	grid_manager = p_grid_manager
	turn_controller = p_turn_controller

	var world: Node3D = %World
	var camera_rig: Node3D = world.get_node("CameraRig") as Node3D
	camera = camera_rig.get_node("CameraPitch/Camera3D") as Camera3D

	move_button = %MoveButton
	attack_button = %AttackButton
	end_turn_button = %EndTurnButton

	move_button.pressed.connect(_on_move_button_pressed)
	attack_button.pressed.connect(_on_attack_button_pressed)
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)


func _process(_delta: float) -> void:
	if not battle_flow:
		return

	if not _is_player_turn():
		_clear_hover()
		battle_flow.update_path_preview()
		return

	_update_hover_from_mouse()
	battle_flow.update_path_preview()


func _unhandled_input(event: InputEvent) -> void:
	if not battle_flow:
		return

	if not event.is_action_pressed("left_click") or event.is_echo():
		return

	if not _is_player_turn():
		return

	var frame: int = Engine.get_process_frames()
	if frame == _last_action_frame:
		return

	if _handle_click():
		_last_action_frame = frame
		get_viewport().set_input_as_handled()


func _is_player_turn() -> bool:
	if battle_flow.is_battle_over():
		return false

	var unit: UnitBase = turn_controller.current_unit
	return unit != null and unit.team == "player"


func _handle_click() -> bool:
	var pick: Variant = _pick_at_screen_position(get_viewport().get_mouse_position())
	var current_unit: UnitBase = turn_controller.current_unit

	match selection_state.current_action_mode:
		SelectionState.ActionMode.NONE:
			if pick == null:
				return false
			if pick.type == "unit" and pick.unit == current_unit:
				battle_flow.try_select_current_unit(pick.unit)
				return true
			return false

		SelectionState.ActionMode.MOVE:
			if selection_state.hovered_tile == null:
				return false
			return battle_flow.try_move_to_hovered_tile()

		SelectionState.ActionMode.ATTACK:
			var target: UnitBase = _resolve_attack_target(pick, current_unit)
			if target == null:
				return false
			return battle_flow.try_attack_unit(target)

	return false


func _resolve_attack_target(pick: Variant, current_unit: UnitBase) -> UnitBase:
	if selection_state.hovered_unit and selection_state.hovered_unit != current_unit:
		return selection_state.hovered_unit

	if pick == null:
		return null

	if pick.type == "unit" and pick.unit != current_unit:
		return pick.unit as UnitBase

	if pick.type == "tile" and pick.tile.occupying_unit:
		var occupant: UnitBase = pick.tile.occupying_unit
		if occupant != current_unit:
			return occupant

	return null


func _on_move_button_pressed() -> void:
	if not _can_use_action_mode(SelectionState.ActionMode.MOVE):
		var unit: UnitBase = turn_controller.current_unit
		if unit and unit.current_movement <= 0:
			battle_flow.battle_hud.show_action_feedback("No movement left.")
		return

	selection_state.set_action_mode(SelectionState.ActionMode.MOVE)
	battle_flow.update_path_preview()


func _on_attack_button_pressed() -> void:
	if not _can_use_action_mode(SelectionState.ActionMode.ATTACK):
		var unit: UnitBase = turn_controller.current_unit
		if unit and not unit.can_spend_ap(unit.get_attack_ap_cost()):
			battle_flow.battle_hud.show_action_feedback("Not enough AP to attack.")
		return

	selection_state.set_action_mode(SelectionState.ActionMode.ATTACK)
	battle_flow.update_path_preview()


func _can_use_action_mode(mode: SelectionState.ActionMode) -> bool:
	var unit: UnitBase = turn_controller.current_unit

	if not unit or unit.team != "player":
		return false

	if mode == SelectionState.ActionMode.MOVE:
		return unit.current_movement > 0

	if mode == SelectionState.ActionMode.ATTACK:
		return unit.can_spend_ap(unit.get_attack_ap_cost())

	return true


func _on_end_turn_button_pressed() -> void:
	battle_flow.end_turn()


func _update_hover_from_mouse() -> void:
	var pick: Variant = _pick_at_screen_position(get_viewport().get_mouse_position())

	_clear_hover()

	if pick == null:
		selection_state.hovered_tile = null
		selection_state.set_hovered_unit(null)
		return

	if pick.type == "tile":
		var tile: HexTile = pick.tile as HexTile
		selection_state.hovered_tile = tile
		tile.set_hovered()
		_last_hovered_tile = tile

		if tile.occupying_unit:
			selection_state.set_hovered_unit(tile.occupying_unit)
		else:
			selection_state.set_hovered_unit(null)

	elif pick.type == "unit":
		var unit: UnitBase = pick.unit as UnitBase
		selection_state.set_hovered_unit(unit)

		if unit.current_tile:
			selection_state.hovered_tile = unit.current_tile
			unit.current_tile.set_hovered()
			_last_hovered_tile = unit.current_tile


func _clear_hover() -> void:
	if _last_hovered_tile:
		_last_hovered_tile.clear_hover()
		_last_hovered_tile = null

	selection_state.clear_tile_hover()
	selection_state.set_hovered_unit(null)


func _pick_at_screen_position(screen_position: Vector2) -> Variant:
	var ray_origin: Vector3 = camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = camera.project_ray_normal(screen_position)
	var ray_end: Vector3 = ray_origin + ray_direction * 1000.0

	var space_state: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)

	var hit: Dictionary = space_state.intersect_ray(query)

	if hit.is_empty():
		return null

	var node: Node = hit.collider as Node

	while node:
		if node is UnitBase:
			return {
				"type": "unit",
				"unit": node,
			}

		if node is HexTile:
			var tile := node as HexTile
			if tile.occupying_unit:
				return {
					"type": "unit",
					"unit": tile.occupying_unit,
				}
			return {
				"type": "tile",
				"tile": tile,
			}

		node = node.get_parent()

	return null
