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


## Generates a SkillData representing the active weapon's basic attack.
## This unifies weapon attacks with the skill system.
func get_attack_as_skill() -> SkillData:
	var weapon := get_active_weapon()
	if not weapon:
		return null
	var skill := SkillData.new()
	skill.skill_id = "weapon_attack_" + weapon.weapon_id
	skill.skill_name = weapon.weapon_name
	skill.description = "Attack with %s" % weapon.weapon_name
	skill.ap_cost = weapon.attack_ap_cost
	skill.skill_range = weapon.weapon_range
	skill.target_mode = SkillData.TargetMode.SINGLE_UNIT
	skill.team_filter = SkillData.TeamFilter.ENEMY
	
	var dmg_effect := SkillEffect.new()
	dmg_effect.effect_type = SkillEffect.EffectType.DAMAGE
	dmg_effect.amount = weapon.weapon_power
	skill.effects = [dmg_effect]
	
	return skill


## Returns an array of SkillData representing ALL attacks from all weapon slots.
func get_all_weapon_attacks_as_skills() -> Array[SkillData]:
	var result: Array[SkillData] = []
	if primary_weapon:
		var saved_slot := active_weapon_slot
		active_weapon_slot = "primary"
		result.append(get_attack_as_skill())
		active_weapon_slot = saved_slot
	if secondary_weapon:
		var saved_slot := active_weapon_slot
		active_weapon_slot = "secondary"
		result.append(get_attack_as_skill())
		active_weapon_slot = saved_slot
	return result


func has_secondary_weapon() -> bool:
	return secondary_weapon != null


func is_weapon_tagged(tag: String) -> bool:
	var weapon := get_active_weapon()
	return weapon != null and weapon.tags.has(tag)