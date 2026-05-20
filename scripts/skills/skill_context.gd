class_name SkillContext
extends RefCounted

## The unit using the skill.
var caster: UnitBase

## The targeted unit (null for SELF or SINGLE_TILE modes).
var target_unit: UnitBase

## The targeted tile (used for SINGLE_TILE and AOE modes).
var target_tile: HexTile

## The skill being used.
var skill: SkillData

## All units affected by this skill (filled by the executor).
var affected_units: Array[UnitBase] = []


func _init(p_caster: UnitBase, p_skill: SkillData, p_target_unit: UnitBase = null, p_target_tile: HexTile = null) -> void:
	caster = p_caster
	skill = p_skill
	target_unit = p_target_unit
	target_tile = p_target_tile


## Returns the skill's range.
func get_skill_range() -> int:
	return skill.skill_range if skill else 0
