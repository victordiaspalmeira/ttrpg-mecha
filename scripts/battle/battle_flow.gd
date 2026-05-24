class_name BattleFlow
extends Node

signal move_executed(unit: UnitBase, target_tile: HexTile)
signal attack_executed(attacker: UnitBase, target: UnitBase)
signal target_hit(target: UnitBase, damage: int)

@export var encounter: EncounterData

var _world: Node3D = null
var _units_container: Node3D = null

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
var particle_manager: ParticleManager = null
var cinematic_player: CinematicPlayer = null

# Services
var attack_line_effect: AttackLineEffect = null
var impact_effect: ImpactEffect = null
var tile_flash: TileFlashEffect = null
var camera_service: CameraService = null
var passive_service: PassiveService = null

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
	path_preview = %World/GridPathPreview as GridPathPreview

	turn_controller.current_unit_changed.connect(_on_current_unit_changed)
	selection_state.action_mode_changed.connect(func(_mode: SelectionState.ActionMode) -> void: update_path_preview())

	battle_input.setup(self, selection_state, grid_manager, turn_controller, audio_manager)
	enemy_brain.setup(self, grid_manager, combat_resolver, turn_controller)

	if audio_manager:
		audio_manager.setup(combat_resolver, turn_controller, self)

	# Inject dependencies into BattleHud
	if battle_hud:
		var camera: Camera3D = %World/CameraRig/CameraPitch/Camera3D as Camera3D
		var units_container := %World/Units as Node3D
		battle_hud.setup(selection_state, turn_controller, units_container, audio_manager, camera)

	# Inject dependencies into UnitSpawner (so spawned units get their refs)
	if unit_spawner:
		unit_spawner.setup(audio_manager, battle_hud, selection_state)

	# Inject dependencies into SkillExecutor
	var skill_executor_node := %SkillExecutor as SkillExecutor
	if skill_executor_node:
		skill_executor_node.setup(particle_manager, battle_hud, audio_manager, grid_manager, passive_service)


func start_battle() -> void:
	# If GameManager has a selected encounter (e.g. from MapEditor), use it
	if GameManager and GameManager.selected_encounter:
		encounter = GameManager.selected_encounter as EncounterData
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
		if tile_flash:
			tile_flash.flash_tile_red(target_tile)
		return false

	var moved: bool = execute_move(unit, target_tile)
	if moved:
		battle_hud.show_action_name_popup("Move")
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


func execute_attack(attacker: UnitBase, target: UnitBase) -> bool:
	var damage: int = attacker.get_total_attack_power()

	# Validate attack (range, AP) without applying damage yet
	if not combat_resolver.can_attack(attacker, target):
		return false

	# Spend AP upfront
	var ap_cost: int = attacker.get_attack_ap_cost()
	if not attacker.spend_ap(ap_cost):
		return false

	# Trigger BEFORE_ATTACK event
	PassiveSystem.trigger_event(PassiveSystem.PassiveEvent.BEFORE_ATTACK, attacker, {"target": target})

	# Show action name popup
	var weapon := attacker.get_active_weapon()
	var action_name := weapon.weapon_name if weapon else "Attack"
	battle_hud.show_action_name_popup(action_name)

	# Cache data before cinematic
	var target_pos_cached: Vector3 = target.global_position
	var target_ref: WeakRef = weakref(target)

	if cinematic_player:
		# Cinematic controls when damage is applied
		cinematic_player.play_attack_cinematic(attacker, target, func():
			# Apply actual damage at impact moment
			_apply_attack_damage(attacker, target, damage)
			# Show damage popup
			var target_unit: UnitBase = target_ref.get_ref() as UnitBase
			if target_unit and is_instance_valid(target_unit):
				battle_hud.show_damage_popup(target_unit, damage)
			else:
				battle_hud.show_damage_popup_at_position(target_pos_cached, damage)
			battle_hud.update_resource_display(attacker)
		, particle_manager)
	else:
		# Fallback without cinematic - apply damage immediately
		attacker.play_attack_visual()
		if particle_manager:
			var start_pos := attacker.global_position + Vector3.UP * 0.5
			var end_pos := target.global_position + Vector3.UP * 0.5
			particle_manager.play_projectile(ParticleConfig.EffectType.ATTACK_BULLET, start_pos, end_pos)
		_apply_attack_damage(attacker, target, damage)
		battle_hud.show_damage_popup(target, damage)
		battle_hud.update_resource_display(attacker)
	
	return true


## Applies the actual damage and triggers post-attack events
func _apply_attack_damage(attacker: UnitBase, target: UnitBase, damage: int) -> void:
	if not is_instance_valid(target):
		return
	target.take_damage(damage)
	# Trigger AFTER_ATTACK + ON_DAMAGE_DEALT events
	PassiveSystem.trigger_event(PassiveSystem.PassiveEvent.AFTER_ATTACK, attacker, {"target": target, "damage": damage})
	PassiveSystem.trigger_event(PassiveSystem.PassiveEvent.ON_DAMAGE_DEALT, attacker, {"target": target, "damage": damage})
	# Trigger ON_KILL if target died
	if is_instance_valid(target) and target.current_hp <= 0:
		PassiveSystem.trigger_event(PassiveSystem.PassiveEvent.ON_KILL, attacker, {"victim": target})
	attack_executed.emit(attacker, target)
	target_hit.emit(target, damage)




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
	# Wait for the popup to finish, then quit
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()



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
		encounter = GameManager.selected_encounter as EncounterData

	setup(
		%World/GridManager as GridManager,
		%SelectionState as SelectionState,
		%GridHighlights as GridHighlights,
		%CombatResolver as CombatResolver,
		%TurnController as TurnController,
		%BattleHud as BattleHud,
		%UnitSpawner as UnitSpawner,
		%BattleInput as BattleInput,
		%EnemyBrain as EnemyBrain,
		%AudioManager as AudioManager,
	)

	_world = %World as Node3D
	_units_container = %World/Units as Node3D

	# Initialize particle manager
	particle_manager = %ParticleManager as ParticleManager
	if not particle_manager:
		particle_manager = ParticleManager.new()
		particle_manager.name = "ParticleManager"
		session.add_child(particle_manager)

	# Initialize cinematic player
	cinematic_player = %CinematicPlayer as CinematicPlayer
	if not cinematic_player:
		cinematic_player = CinematicPlayer.new()
		cinematic_player.name = "CinematicPlayer"
		session.add_child(cinematic_player)

	# Create visual effect services (not in the scene, always created at runtime)
	attack_line_effect = AttackLineEffect.new()
	attack_line_effect.name = "AttackLineEffect"
	session.add_child(attack_line_effect)

	impact_effect = ImpactEffect.new()
	impact_effect.name = "ImpactEffect"
	session.add_child(impact_effect)

	tile_flash = TileFlashEffect.new()
	tile_flash.name = "TileFlashEffect"
	session.add_child(tile_flash)

	camera_service = CameraService.new()
	camera_service.name = "CameraService"
	session.add_child(camera_service)

	# Initialize passive service
	passive_service = session.get_node_or_null("PassiveService") as PassiveService
	if not passive_service:
		passive_service = PassiveService.new()
		passive_service.name = "PassiveService"
		session.add_child(passive_service)
	passive_service.setup(grid_manager)
	passive_service.passive_triggered.connect(func(unit: UnitBase, text: String, color: Color):
		PassiveFeedback.show(unit, text, color)
	)

	start_battle()
