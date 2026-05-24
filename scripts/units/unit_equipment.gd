class_name UnitEquipment
extends RefCounted

## Manages weapon equipment for a unit.

var primary_weapon: WeaponData = null
var secondary_weapon: WeaponData = null
var active_weapon_slot := "primary"  # "primary" or "secondary"


func setup(p_primary: WeaponData, p_secondary: WeaponData = null) -> void:
	primary_weapon = p_primary
	secondary_weapon = p_secondary


func get_active_weapon() -> WeaponData:
	if active_weapon_slot == "primary" and primary_weapon:
		return primary_weapon
	if active_weapon_slot == "secondary" and secondary_weapon:
		return secondary_weapon
	return primary_weapon


func switch_weapon() -> void:
	if secondary_weapon:
		active_weapon_slot = "secondary" if active_weapon_slot == "primary" else "primary"


func get_attack_ap_cost() -> int:
	var weapon := get_active_weapon()
	return maxi(1, weapon.attack_ap_cost if weapon else 1)


func get_weapon_range() -> int:
	var weapon := get_active_weapon()
	return weapon.weapon_range if weapon else 1


func get_weapon_power() -> int:
	var weapon := get_active_weapon()
	return weapon.weapon_power if weapon else 0


func has_secondary_weapon() -> bool:
	return secondary_weapon != null


func is_weapon_tagged(tag: String) -> bool:
	var weapon := get_active_weapon()
	return weapon != null and weapon.tags.has(tag)