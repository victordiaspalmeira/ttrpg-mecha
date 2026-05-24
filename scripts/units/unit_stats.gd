class_name UnitStats
extends RefCounted

## Core stats for a unit. This is a data container with stat operations.

var max_hp: int = 0
var current_hp: int = 0
var max_movement: int = 0
var current_movement: int = 0
var max_ap: int = 0
var current_ap: int = 0
var defense: int = 0
var attack_power: int = 0


func setup(p_max_hp: int, p_movement: int, p_max_ap: int, p_defense: int, p_attack: int) -> void:
	max_hp = p_max_hp
	current_hp = p_max_hp
	max_movement = p_movement
	current_movement = p_movement
	max_ap = p_max_ap
	current_ap = p_max_ap
	defense = p_defense
	attack_power = p_attack


func take_damage(amount: int, effective_defense: int) -> int:
	var final_damage = maxi(1, amount - effective_defense)
	current_hp -= final_damage
	return final_damage


func heal(amount: int) -> void:
	current_hp = mini(max_hp, current_hp + amount)


func can_spend_ap(amount: int) -> bool:
	return amount > 0 and current_ap >= amount


func spend_ap(amount: int) -> bool:
	if not can_spend_ap(amount):
		return false
	current_ap -= amount
	return true


func can_spend_movement(amount: int) -> bool:
	return amount > 0 and current_movement >= amount


func spend_movement(amount: int) -> bool:
	if not can_spend_movement(amount):
		return false
	current_movement -= amount
	return true


func is_alive() -> bool:
	return current_hp > 0


func get_hp_percent() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)