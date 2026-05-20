class_name PassiveEffect
extends Resource

## Type of passive effect.
enum PassiveType {
	FLAT_STAT_BONUS,      # Permanent stat bonus (e.g. +1 DEF)
	CONDITIONAL_BONUS,    # Bonus under condition (e.g. +1 dmg at close range)
	ON_KILL,              # Trigger on kill (e.g. +1 AP)
	AOE_ON_DAMAGE,        # AoE effect when dealing damage
	RESISTANCE            # Damage resistance (e.g. -1 damage taken)
}

@export var passive_type := PassiveType.FLAT_STAT_BONUS
@export var display_name := ""
@export var description := ""

## Stat to modify (for FLAT_STAT_BONUS, CONDITIONAL_BONUS).
@export var stat_name := ""
@export var stat_value := 0

## Condition for CONDITIONAL_BONUS (e.g. "range_le_2").
@export var condition := ""