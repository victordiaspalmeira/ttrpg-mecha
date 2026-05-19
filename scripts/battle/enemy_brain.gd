class_name EnemyBrain
extends Node

@export var default_behavior: EnemyBehavior
@export var think_delay: float = 0.35
@export var action_delay: float = 0.4

var battle_flow: BattleFlow = null
var grid_manager: GridManager = null
var combat_resolver: CombatResolver = null
var turn_controller: TurnController = null

var _running: bool = false


func setup(
	p_battle_flow: BattleFlow,
	p_grid_manager: GridManager,
	p_combat_resolver: CombatResolver,
	p_turn_controller: TurnController
) -> void:
	battle_flow = p_battle_flow
	grid_manager = p_grid_manager
	combat_resolver = p_combat_resolver
	turn_controller = p_turn_controller

	turn_controller.current_unit_changed.connect(_on_current_unit_changed)

	if not default_behavior:
		default_behavior = SimpleChaseBehavior.new()


func _on_current_unit_changed(unit: UnitBase) -> void:
	if not unit or unit.team != "enemy":
		return

	if _running:
		return

	call_deferred("_run_enemy_turn", unit)


func _run_enemy_turn(unit: UnitBase) -> void:
	if not is_instance_valid(unit):
		return

	_running = true

	if battle_flow.battle_hud.turn_announce.is_busy():
		await battle_flow.battle_hud.turn_announce.announce_finished

	await get_tree().create_timer(think_delay).timeout

	if not is_instance_valid(unit):
		_finish_enemy_turn()
		return

	var behavior: EnemyBehavior = _resolve_behavior(unit)
	var context: EnemyAIContext = EnemyAIContext.create(
		unit,
		grid_manager,
		combat_resolver,
		_get_all_units()
	)
	var intents: Array = behavior.plan(context)

	await _execute_intents(unit, intents)

	_finish_enemy_turn()


func _resolve_behavior(unit: UnitBase) -> EnemyBehavior:
	if unit.class_data and unit.class_data.enemy_behavior:
		return unit.class_data.enemy_behavior

	if default_behavior:
		return default_behavior

	return SimpleChaseBehavior.new()


func _execute_intents(unit: UnitBase, intents: Array) -> void:
	for intent in intents:
		if not is_instance_valid(unit):
			return

		if battle_flow.is_battle_over():
			return

		match intent.type:
			AIIntent.Type.ATTACK:
				_execute_attack(unit, intent.target_unit)

			AIIntent.Type.MOVE:
				battle_flow.execute_move(unit, intent.target_tile)

			AIIntent.Type.WAIT:
				await get_tree().create_timer(intent.wait_seconds).timeout
				continue

			AIIntent.Type.END_TURN:
				return

		await get_tree().create_timer(action_delay).timeout


func _execute_attack(attacker: UnitBase, target: UnitBase) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return

	if not combat_resolver.can_attack(attacker, target):
		return

	battle_flow.execute_attack(attacker, target)


func _finish_enemy_turn() -> void:
	_running = false

	if battle_flow and not battle_flow.is_battle_over():
		battle_flow.end_turn()


func _get_all_units() -> Array[UnitBase]:
	var units: Array[UnitBase] = []
	for child in %Units.get_children():
		var unit := child as UnitBase
		if unit:
			units.append(unit)
	return units
