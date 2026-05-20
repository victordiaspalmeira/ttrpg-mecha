class_name SkillEffect
extends Resource

## Type of effect this skill applies.
enum EffectType { DAMAGE, HEAL, APPLY_STATUS, REMOVE_STATUS, BUFF, DEBUFF }
@export var effect_type := EffectType.DAMAGE

## Base amount (damage, heal, etc).
@export var amount := 0

## Status effect to apply/remove (for APPLY_STATUS / REMOVE_STATUS).
@export var status_effect: StatusEffect = null

## Stat to modify and the modifier value (for BUFF / DEBUFF).
@export var stat_name := ""
@export var stat_modifier := 0

## Duration in turns for buffs/debuffs applied via this effect.
@export var duration := 1