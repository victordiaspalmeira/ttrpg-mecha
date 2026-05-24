class_name CombatResolver
extends Node

signal attack_executed(attacker: UnitBase, target: UnitBase)
signal target_hit(target: UnitBase, damage: int)


func is_unit_in_range(attacker: UnitBase, target: UnitBase, range_val: int) -> bool:
	if not attacker.current_tile or not target.current_tile:
		return false
	var distance: int = HexMath.axial_distance_tiles(
		attacker.current_tile,
		target.current_tile
	)
	return distance <= range_val

func is_unit_in_attack_range(attacker: UnitBase, target: UnitBase) -> bool:
	return is_unit_in_range(attacker, target, attacker.get_effective_range())


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

	# Trigger BEFORE_ATTACK event
	PassiveSystem.trigger_event(PassiveSystem.PassiveEvent.BEFORE_ATTACK, attacker, {"target": target})

	# Damage formula: (attack_power + weapon_power) - target.defense
	var total_damage: int = attacker.get_total_attack_power()
	target.take_damage(total_damage)

	# Trigger AFTER_ATTACK + ON_DAMAGE_DEALT events
	PassiveSystem.trigger_event(PassiveSystem.PassiveEvent.AFTER_ATTACK, attacker, {"target": target, "damage": total_damage})
	PassiveSystem.trigger_event(PassiveSystem.PassiveEvent.ON_DAMAGE_DEALT, attacker, {"target": target, "damage": total_damage})

	# Trigger ON_KILL if target died
	if target.current_hp <= 0:
		PassiveSystem.trigger_event(PassiveSystem.PassiveEvent.ON_KILL, attacker, {"victim": target})

	attack_executed.emit(attacker, target)
	target_hit.emit(target, total_damage)

	return true
