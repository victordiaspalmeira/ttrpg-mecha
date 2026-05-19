class_name AudioManager
extends Node

@export var sfx_volume := -5.0

@onready var sfx_attack: AudioStreamPlayer = %AudioAttack
@onready var sfx_move: AudioStreamPlayer = %AudioMove
@onready var sfx_hit: AudioStreamPlayer = %AudioHit
@onready var sfx_death: AudioStreamPlayer = %AudioDeath
@onready var sfx_end_turn: AudioStreamPlayer = %AudioEndTurn

var _combat_resolver: CombatResolver = null
var _turn_controller: TurnController = null
var _battle_flow: BattleFlow = null


func setup(
	p_combat_resolver: CombatResolver,
	p_turn_controller: TurnController,
	p_battle_flow: BattleFlow
) -> void:

	_combat_resolver = p_combat_resolver
	_turn_controller = p_turn_controller
	_battle_flow = p_battle_flow

	_combat_resolver.attack_executed.connect(_on_attack_executed)
	_combat_resolver.target_hit.connect(_on_target_hit)
	_turn_controller.turn_ended.connect(_on_turn_ended)
	_battle_flow.move_executed.connect(_on_move_executed)


func register_unit(unit: UnitBase) -> void:

	if not unit.died.is_connected(_on_unit_died):
		unit.died.connect(_on_unit_died)


func play_attack() -> void:
	_play(sfx_attack)


func play_move() -> void:
	_play(sfx_move)


func play_hit() -> void:
	_play(sfx_hit)


func play_death() -> void:
	_play(sfx_death)


func play_end_turn() -> void:
	_play(sfx_end_turn)


func _play(player: AudioStreamPlayer) -> void:

	if player and player.stream:
		player.volume_db = sfx_volume
		player.play()


func _on_attack_executed(_attacker: UnitBase, _target: UnitBase) -> void:
	play_attack()


func _on_target_hit(_target: UnitBase, _damage: int) -> void:
	play_hit()


func _on_turn_ended(_unit: UnitBase) -> void:
	play_end_turn()


func _on_move_executed(_unit: UnitBase, _target_tile: HexTile) -> void:
	play_move()


func _on_unit_died() -> void:
	play_death()
