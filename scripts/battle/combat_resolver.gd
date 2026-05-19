class_name CombatResolver
extends Node

signal attack_executed(attacker: UnitBase, target: UnitBase)
signal target_hit(target: UnitBase, damage: int)


func is_unit_in_attack_range(attacker: UnitBase, target: UnitBase) -> bool:
	if not attacker.current_tile or not target.current_tile:
		return false

	var distance: int = HexMath.axial_distance_tiles(
		attacker.current_tile,
		target.current_tile
	)
	return distance <= attacker.attack_range


func can_attack(attacker: UnitBase, target: UnitBase) -> bool:
	if not is_unit_in_attack_range(attacker, target):
		return false

	return attacker.can_spend_ap(attacker.get_attack_ap_cost())


func execute_attack(attacker: UnitBase, target: UnitBase) -> bool:
	if not attacker.current_tile or not target.current_tile:
		return false

	if not can_attack(attacker, target):
		return false

	var ap_cost: int = attacker.get_attack_ap_cost()

	if not attacker.spend_ap(ap_cost):
		return false

	target.take_damage(attacker.attack_damage)

	attack_executed.emit(attacker, target)
	target_hit.emit(target, attacker.attack_damage)

	return true
