class_name UnitBase
extends Node3D

signal died

# Identity
@export var unit_name := ""
@export var class_id := ""
@export var team := "player"

@export var portrait: Texture2D
@export var class_data: ClassData

# Movement animation
@export var movement_tween_duration := 0.3

# Stats
var max_hp := 0
var current_hp := 0
var max_movement := 0
var current_movement := 0
var max_ap := 0
var current_ap := 0
var defense := 0
var attack_damage := 1
var attack_range := 1

# Grid state
var current_tile: HexTile = null

# Runtime
var status_effects := []
var skill_cooldowns := {}

# Equipment
@export var primary_weapon: WeaponData
@export var primary_weapon_id := ""
@export var secondary_weapon_id := ""
@export var melee_weapon_id := ""

@onready var _unit_visual: UnitSpriteVisual = $UnitVisual


func _ready() -> void:
	apply_class_data()
	_apply_team_visual()


func refresh_turn() -> void:
	current_movement = max_movement
	current_ap = max_ap
	reduce_cooldowns()


func get_attack_ap_cost() -> int:

	if primary_weapon:
		return maxi(1, primary_weapon.attack_ap_cost)

	return 1


func can_spend_movement(amount: int) -> bool:

	return amount > 0 and current_movement >= amount


func spend_movement(amount: int) -> bool:

	if not can_spend_movement(amount):
		return false

	current_movement -= amount
	return true


func can_spend_ap(amount: int) -> bool:

	return amount > 0 and current_ap >= amount


func spend_ap(amount: int) -> bool:

	if not can_spend_ap(amount):
		return false

	current_ap -= amount
	return true


func reduce_cooldowns() -> void:
	for skill_id in skill_cooldowns.keys():
		if skill_cooldowns[skill_id] > 0:
			skill_cooldowns[skill_id] -= 1


func take_damage(amount: int) -> void:
	var final_damage = maxi(1, amount - defense)
	current_hp -= final_damage

	if current_hp <= 0:
		die()


func heal(amount: int) -> void:
	current_hp = mini(max_hp, current_hp + amount)


func die() -> void:
	died.emit()
	queue_free()


func move_to_tile(tile: HexTile) -> void:
	if tile == null:
		push_error("move_to_tile: tile is null")
		return

	if current_tile:
		current_tile.occupying_unit = null

	current_tile = tile
	current_tile.occupying_unit = self
	
	# Anima suavemente para a nova posição
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", tile.global_position, movement_tween_duration)


func get_portrait() -> Texture2D:
	if class_data and class_data.portrait:
		return class_data.portrait
	return portrait


func apply_class_data() -> void:
	if not class_data:
		_apply_combat_stats()
		_apply_team_visual()
		return

	max_hp = class_data.max_hp
	max_movement = class_data.movement
	max_ap = class_data.max_ap
	defense = class_data.defense
	current_hp = max_hp
	current_movement = max_movement
	current_ap = max_ap

	if class_data.primary_weapon:
		primary_weapon = class_data.primary_weapon

	_apply_combat_stats()
	_apply_team_visual()


func _apply_combat_stats() -> void:
	attack_damage = 1
	attack_range = 1

	if primary_weapon:
		attack_damage = primary_weapon.weapon_damage
		attack_range = primary_weapon.weapon_range


func _apply_team_visual() -> void:
	if _unit_visual:
		_unit_visual.apply_team(team)


func get_visual_top_y() -> float:
	if _unit_visual:
		return _unit_visual.get_sprite_top_y()
	return 1.8


func configure_from_grid(grid_config: GridConfig) -> void:
	if _unit_visual:
		_unit_visual.configure_surface(grid_config)


func play_attack_visual() -> void:
	if _unit_visual:
		_unit_visual.play_attack()
