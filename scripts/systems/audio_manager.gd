class_name AudioManager
extends Node

@export var sfx_volume := -8.0

@onready var sfx_attack: AudioStreamPlayer = %AudioManager/AudioAttack
@onready var sfx_move: AudioStreamPlayer = %AudioManager/AudioMove
@onready var sfx_hit: AudioStreamPlayer = %AudioManager/AudioHit
@onready var sfx_death: AudioStreamPlayer = %AudioManager/AudioDeath
@onready var sfx_end_turn: AudioStreamPlayer = %AudioManager/AudioEndTurn
@onready var sfx_ui_hover: AudioStreamPlayer = %AudioManager/AudioUIHover
@onready var sfx_ui_click: AudioStreamPlayer = %AudioManager/AudioUIClick
@onready var sfx_turn_start: AudioStreamPlayer = %AudioManager/AudioTurnStart

# Skill SFX players
@onready var sfx_skill_buff: AudioStreamPlayer = %AudioManager/AudioSkillBuff
@onready var sfx_skill_debuff: AudioStreamPlayer = %AudioManager/AudioSkillDebuff
@onready var sfx_skill_heal: AudioStreamPlayer = %AudioManager/AudioSkillHeal
@onready var sfx_skill_damage: AudioStreamPlayer = %AudioManager/AudioSkillDamage
@onready var sfx_skill_turret: AudioStreamPlayer = %AudioManager/AudioSkillTurret
@onready var sfx_skill_taunt: AudioStreamPlayer = %AudioManager/AudioSkillTaunt
@onready var sfx_skill_grenade: AudioStreamPlayer = %AudioManager/AudioSkillGrenade
@onready var sfx_invalid: AudioStreamPlayer = %AudioManager/AudioInvalid

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

	_battle_flow.attack_executed.connect(_on_attack_executed)
	_battle_flow.target_hit.connect(_on_target_hit)
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


func play_ui_hover() -> void:
	_play(sfx_ui_hover)


func play_ui_click() -> void:
	_play(sfx_ui_click)


func play_turn_start() -> void:
	_play(sfx_turn_start)


func play_invalid() -> void:
	_play(sfx_invalid)


## Play a skill SFX based on skill_id.
func play_skill_sfx(skill_id: String) -> void:
	match skill_id:
		"fortify", "adrenaline_rush":
			_play(sfx_skill_buff)
		"turret_mode":
			_play(sfx_skill_turret)
		"taunt":
			_play(sfx_skill_taunt)
		"grenade":
			_play(sfx_skill_grenade)
		"suppression", "armor_piercer", "precision_shot":
			_play(sfx_skill_damage)
		"overwatch":
			_play(sfx_skill_turret)
		_:
			# Default: try to categorize by effect type
			_play(sfx_skill_buff)


func _play(player: AudioStreamPlayer) -> void:
	if not player:
		return

	if not player.stream:
		return

	if player.playing:
		player.stop()

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