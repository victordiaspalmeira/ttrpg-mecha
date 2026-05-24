class_name BattleInput
extends Node

var battle_flow: BattleFlow = null
var selection_state: SelectionState = null
var grid_manager: GridManager = null
var turn_controller: TurnController = null
var camera: Camera3D = null
var audio_manager: AudioManager = null

var move_button: Button = null
var end_turn_button: Button = null

var _last_hovered_tile: HexTile = null
var _last_action_frame: int = -1


func setup(
	p_battle_flow: BattleFlow,
	p_selection_state: SelectionState,
	p_grid_manager: GridManager,
	p_turn_controller: TurnController,
	p_audio_manager: AudioManager = null
) -> void:
	battle_flow = p_battle_flow
	selection_state = p_selection_state
	grid_manager = p_grid_manager
	turn_controller = p_turn_controller
	audio_manager = p_audio_manager

	var world: Node3D = %World
	var camera_rig: Node3D = world.get_node("CameraRig") as Node3D
	camera = camera_rig.get_node("CameraPitch/Camera3D") as Camera3D

	# Find UI buttons via absolute path (stable scene structure)
	var ui_layer := get_node("/root/BattleScene/UI/CanvasLayer") as CanvasLayer
	end_turn_button = ui_layer.get_node("ActionPanel/VBoxContainer/EndTurnButton")
	move_button = ui_layer.get_node("ActionPanel/VBoxContainer/MoveButton")

	move_button.pressed.connect(_on_move_button_pressed)
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)

	move_button.mouse_entered.connect(_on_button_hovered)
	end_turn_button.mouse_entered.connect(_on_button_hovered)

	move_button.pressed.connect(_on_button_clicked)
	end_turn_button.pressed.connect(_on_button_clicked)


func _on_button_hovered() -> void:
	if audio_manager:
		audio_manager.play_ui_hover()


func _on_button_clicked() -> void:
	if audio_manager:
		audio_manager.play_ui_click()


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

	# Z key closes the game
	if event.is_action_pressed("close_game") and not event.is_echo():
		get_tree().quit()
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
	return unit != null and unit.team_id == "player"


func _handle_click() -> bool:
	var pick: Variant = _pick_at_screen_position(get_viewport().get_mouse_position())
	var current_unit: UnitBase = turn_controller.current_unit

	match selection_state.current_action_mode:
		SelectionState.ActionMode.NONE:
			if pick == null:
				# Clicked on empty space — unpin info panel
				selection_state.unpin_unit()
				return false
			if pick.type == "unit" and pick.unit == current_unit:
				battle_flow.try_select_current_unit(pick.unit)
				# Pin the unit to show persistent info panel
				selection_state.pin_unit(pick.unit)
				return true
			# Clicking on another unit pins it (for inspection)
			if pick.type == "unit":
				selection_state.pin_unit(pick.unit)
				return true
			# Clicking on an empty tile — unpin info panel
			if pick.type == "tile" and pick.tile.occupying_unit == null:
				selection_state.unpin_unit()
				return false
			return false

		SelectionState.ActionMode.MOVE:
			if selection_state.hovered_tile == null:
				return false
			return battle_flow.try_move_to_hovered_tile()

		SelectionState.ActionMode.ATTACK:
			var target: UnitBase = _resolve_attack_target(pick, current_unit)
			if target == null:
				print("ATTACK: no target found, pick=%s" % str(pick))
				return false
			print("ATTACK: targeting %s" % target.unit_name)
			return battle_flow.try_attack_unit(target)

		SelectionState.ActionMode.SKILL:
			# Get the pending skill from BattleHud to check targeting mode
			var battle_hud: BattleHud = current_unit.get_tree().current_scene.get_node_or_null("BattleSession/BattleHud")
			if not battle_hud or not battle_hud._pending_skill:
				return false
			var skill: SkillData = battle_hud._pending_skill
			var target_unit: UnitBase = _resolve_attack_target(pick, current_unit)
			var target_tile: HexTile = selection_state.hovered_tile
			# For AOE skills centered on caster, use caster's tile
			if skill.target_mode == SkillData.TargetMode.AOE_CIRCLE and skill.skill_range <= 0:
				target_tile = current_unit.current_tile
			# For SELF skills, no target needed
			elif skill.target_mode == SkillData.TargetMode.SELF:
				pass
			elif not target_unit and not target_tile:
				print("SKILL: no target found, pick=%s" % str(pick))
				return false
			print("SKILL: targeting unit=%s tile=%s mode=%d" % [target_unit, target_tile, skill.target_mode])
			battle_hud._execute_skill_on_target(target_unit, target_tile)
			selection_state.set_action_mode(SelectionState.ActionMode.NONE)
			return true

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



func _can_use_action_mode(mode: SelectionState.ActionMode) -> bool:
	var unit: UnitBase = turn_controller.current_unit

	if not unit or unit.team_id != "player":
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
