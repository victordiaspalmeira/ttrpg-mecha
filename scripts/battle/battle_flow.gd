class_name BattleFlow
extends Node

signal move_executed(unit: UnitBase, target_tile: HexTile)

@export var encounter: EncounterData

@onready var _world: Node3D = %World
@onready var _units_container: Node3D = %Units

var grid_manager: GridManager = null
var selection_state: SelectionState = null
var grid_highlights: GridHighlights = null
var combat_resolver: CombatResolver = null
var turn_controller: TurnController = null
var battle_hud: BattleHud = null
var unit_spawner: UnitSpawner = null
var battle_input: BattleInput = null
var enemy_brain: EnemyBrain = null
var audio_manager: AudioManager = null
var path_preview: GridPathPreview = null

var _battle_over: bool = false
var _winner_team: String = ""


func setup(
	p_grid_manager: GridManager,
	p_selection_state: SelectionState,
	p_grid_highlights: GridHighlights,
	p_combat_resolver: CombatResolver,
	p_turn_controller: TurnController,
	p_battle_hud: BattleHud,
	p_unit_spawner: UnitSpawner,
	p_battle_input: BattleInput,
	p_enemy_brain: EnemyBrain,
	p_audio_manager: AudioManager = null
) -> void:
	grid_manager = p_grid_manager
	selection_state = p_selection_state
	grid_highlights = p_grid_highlights
	combat_resolver = p_combat_resolver
	turn_controller = p_turn_controller
	battle_hud = p_battle_hud
	unit_spawner = p_unit_spawner
	battle_input = p_battle_input
	enemy_brain = p_enemy_brain
	audio_manager = p_audio_manager
	path_preview = _world.get_node_or_null("GridPathPreview") as GridPathPreview

	turn_controller.current_unit_changed.connect(_on_current_unit_changed)
	selection_state.action_mode_changed.connect(func(_mode: SelectionState.ActionMode) -> void: update_path_preview())

	battle_input.setup(self, selection_state, grid_manager, turn_controller, audio_manager)
	enemy_brain.setup(self, grid_manager, combat_resolver, turn_controller)

	if audio_manager:
		audio_manager.setup(combat_resolver, turn_controller, self)


func start_battle() -> void:
	grid_manager.initialize(encounter)
	_spawn_encounter()
	turn_controller.build_turn_queue()
	turn_controller.start_first_turn()


func is_battle_over() -> bool:
	return _battle_over


func get_winner_team() -> String:
	return _winner_team


func _spawn_encounter() -> void:
	if not encounter:
		push_warning("BattleFlow: no encounter assigned.")
		return

	for spawn in encounter.spawns:
		if not spawn or not spawn.get_class_data():
			continue

		var tile: HexTile = grid_manager.get_tile(spawn.q, spawn.r)

		if not tile:
			push_warning("BattleFlow: no tile at (%d, %d)." % [spawn.q, spawn.r])
			continue

		# Try template-first spawning
		var team_data: TeamData = encounter.get_team_data(spawn.get_team_id())
		var unit: UnitBase
		if spawn.template:
			unit = unit_spawner.spawn_from_template(spawn.template, tile, team_data)
		else:
			unit = unit_spawner.spawn_unit(
				spawn.get_class_data(),
				tile,
				spawn.get_team_id(),
				spawn.get_primary_weapon(),
				spawn.get_secondary_weapon(),
				null,
				team_data
			)

		unit.configure_from_grid(grid_manager.config)

		if audio_manager:
			audio_manager.register_unit(unit)

		unit.tree_exiting.connect(_on_unit_removed.bind(unit))


func _on_unit_removed(_unit: UnitBase) -> void:
	turn_controller.prune_invalid_units()
	_check_battle_end()


func _on_current_unit_changed(unit: UnitBase) -> void:
	if _battle_over:
		return

	_clear_path_preview()
	await battle_hud.present_turn_start(unit)

	if not is_instance_valid(unit):
		return

	if selection_state.selected_tile:
		selection_state.selected_tile.deselect()

	selection_state.select_unit(unit)
	selection_state.selected_tile.select()
	selection_state.set_action_mode(SelectionState.ActionMode.NONE)


func try_select_current_unit(unit: UnitBase) -> void:
	if _battle_over:
		return

	if unit != turn_controller.current_unit:
		return

	if not unit.is_player_team():
		return

	if selection_state.selected_tile:
		selection_state.selected_tile.deselect()

	selection_state.select_unit(unit)
	selection_state.selected_tile.select()


func try_move_to_hovered_tile() -> bool:
	if _battle_over:
		return false

	var unit: UnitBase = selection_state.selected_unit

	if not unit or unit != turn_controller.current_unit:
		return false

	var target_tile: HexTile = selection_state.hovered_tile

	if target_tile == null:
		battle_hud.show_action_feedback("Select a destination tile.")
		return false

	if not MovementRules.can_move_to(unit, target_tile, grid_manager):
		battle_hud.show_action_feedback(
			MovementRules.get_move_failure_reason(unit, target_tile, grid_manager)
		)
		# Flash tile red for invalid move feedback
		_flash_tile_red(target_tile)
		return false

	var moved: bool = execute_move(unit, target_tile)
	if moved:
		selection_state.set_action_mode(SelectionState.ActionMode.NONE)
		_clear_path_preview()

	_refresh_action_highlights()
	return moved


func execute_move(unit: UnitBase, target_tile: HexTile) -> bool:
	if not MovementRules.can_move_to(unit, target_tile, grid_manager):
		return false

	var move_cost: int = MovementRules.get_move_cost(unit, target_tile, grid_manager)

	if not unit.spend_movement(move_cost):
		return false

	if selection_state.selected_unit == unit and selection_state.selected_tile:
		selection_state.selected_tile.deselect()

	unit.move_to_tile(target_tile)
	move_executed.emit(unit, target_tile)

	if selection_state.selected_unit == unit:
		selection_state.selected_tile = target_tile
		selection_state.selected_tile.select()

	battle_hud.update_resource_display(unit)
	return true


func try_attack_unit(target_unit: UnitBase) -> bool:
	if _battle_over:
		return false

	var attacker: UnitBase = selection_state.selected_unit

	if not attacker or attacker != turn_controller.current_unit:
		return false

	if not is_instance_valid(target_unit):
		battle_hud.show_action_feedback("No valid target.")
		return false

	if target_unit.is_same_team(attacker):
		battle_hud.show_action_feedback("Cannot attack allies.")
		return false

	if not combat_resolver.is_unit_in_attack_range(attacker, target_unit):
		battle_hud.show_action_feedback("Target is out of range.")
		return false

	if not attacker.can_spend_ap(attacker.get_attack_ap_cost()):
		battle_hud.show_action_feedback("Not enough AP to attack.")
		return false

	var attacked: bool = execute_attack(attacker, target_unit)
	if attacked:
		selection_state.set_action_mode(SelectionState.ActionMode.NONE)

	_refresh_action_highlights()
	return attacked


func execute_attack(attacker: UnitBase, target: UnitBase) -> bool:
	var damage: int = attacker.get_total_attack_power()

	if not combat_resolver.execute_attack(attacker, target):
		return false

	attacker.play_attack_visual()
	_show_attack_line(attacker, target)
	battle_hud.show_damage_popup(target, damage)
	battle_hud.update_resource_display(attacker)
	return true


## Shows a brief attack line between attacker and target.
func _show_attack_line(attacker: UnitBase, target: UnitBase) -> void:
	var line := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 4
	mesh.top_radius = 0.02
	mesh.bottom_radius = 0.02
	mesh.height = 1.0  # will be scaled
	line.mesh = mesh
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.2, 0.8)
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	line.material_override = mat
	
	_world.add_child(line)
	
	var start_pos := attacker.global_position + Vector3.UP * 0.5
	var end_pos := target.global_position + Vector3.UP * 0.5
	var mid_point := (start_pos + end_pos) / 2.0
	var direction := (end_pos - start_pos)
	var length := direction.length()
	
	line.global_position = mid_point
	line.look_at(end_pos, Vector3.UP)
	line.scale = Vector3(1, 1, length)
	
	# Fade out
	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.3)
	tween.tween_callback(line.queue_free)


func end_turn() -> void:
	if _battle_over:
		return

	turn_controller.end_turn()
	grid_highlights.clear_all_tiles()
	_clear_path_preview()
	selection_state.set_action_mode(SelectionState.ActionMode.NONE)


func update_path_preview() -> void:
	if not path_preview or not grid_manager:
		return

	if selection_state.current_action_mode != SelectionState.ActionMode.MOVE:
		path_preview.clear()
		return

	var unit: UnitBase = selection_state.selected_unit
	var target_tile: HexTile = selection_state.hovered_tile

	if not unit or not target_tile or not unit.current_tile:
		path_preview.clear()
		return

	if target_tile == unit.current_tile:
		path_preview.clear()
		return

	var path: Array[HexTile] = MovementRules.find_path(unit, target_tile, grid_manager)
	path_preview.show_path(path)


func _clear_path_preview() -> void:
	if path_preview:
		path_preview.clear()


func _check_battle_end() -> void:
	if _battle_over:
		return

	var player_team_alive := false
	var enemy_teams_alive: Array[String] = []
	for child in _units_container.get_children():
		var unit := child as UnitBase
		if unit and is_instance_valid(unit) and unit.current_hp > 0:
			if unit.is_player_team():
				player_team_alive = true
			else:
				if not enemy_teams_alive.has(unit.team_id):
					enemy_teams_alive.append(unit.team_id)

	if not player_team_alive:
		_finish_battle("enemy")
	elif enemy_teams_alive.is_empty():
		var player_team := encounter.get_player_team()
		_finish_battle(player_team.team_id if player_team else "player")


func _has_team_alive(team_id: String) -> bool:
	for child in _units_container.get_children():
		var unit := child as UnitBase
		if unit and is_instance_valid(unit) and unit.team_id == team_id and unit.current_hp > 0:
			return true

	return false


func _finish_battle(winner_team_id: String) -> void:
	_battle_over = true
	_winner_team = winner_team_id

	grid_highlights.clear_all_tiles()
	_clear_path_preview()
	selection_state.set_action_mode(SelectionState.ActionMode.NONE)

	var winner_team := encounter.get_team_data(winner_team_id)
	var is_player_win := winner_team.is_player if winner_team else (winner_team_id == "player")
	var message: String = "VICTORY" if is_player_win else "DEFEAT"
	call_deferred("_show_result_banner", message)


func _show_result_banner(message: String) -> void:
	await battle_hud.show_battle_result(message)


## Flashes a tile red briefly to indicate invalid action.
func _flash_tile_red(tile: HexTile) -> void:
	if not tile or not tile.highlight_overlay:
		return
	var overlay := tile.highlight_overlay
	overlay.visible = true
	# Create a red material for the flash
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.2, 0.6)
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	overlay.material_override = mat
	# Fade out
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func():
		overlay.visible = false
		overlay.modulate.a = 1.0
	)


func _refresh_action_highlights() -> void:
	grid_highlights.invalidate_cache()
	grid_highlights.clear_all_tiles()

	if selection_state.current_action_mode == SelectionState.ActionMode.NONE:
		return

	grid_highlights.refresh_highlights()


func _ready() -> void:
	call_deferred("_bootstrap")


func _bootstrap() -> void:
	var session: Node = get_parent()

	# Usa o encontro selecionado do GameManager, se disponível
	if GameManager and GameManager.selected_encounter:
		encounter = GameManager.selected_encounter

	setup(
		_world.get_node("GridManager") as GridManager,
		session.get_node("SelectionState") as SelectionState,
		session.get_node("GridHighlights") as GridHighlights,
		session.get_node("CombatResolver") as CombatResolver,
		session.get_node("TurnController") as TurnController,
		session.get_node("BattleHud") as BattleHud,
		session.get_node("UnitSpawner") as UnitSpawner,
		session.get_node("BattleInput") as BattleInput,
		session.get_node("EnemyBrain") as EnemyBrain,
		session.get_node("AudioManager") as AudioManager,
	)

	start_battle()
