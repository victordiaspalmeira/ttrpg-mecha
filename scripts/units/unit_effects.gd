class_name UnitEffects
extends RefCounted

## Manages active status effects on a unit.
var active_effects: Array[ActiveStatusEffect] = []


## Adds a StatusEffect. Refreshes duration if already present.
func add_effect(effect_data: StatusEffect, source: String = "") -> ActiveStatusEffect:
	for e in active_effects:
		if e.effect.effect_id == effect_data.effect_id:
			e.turns_remaining = effect_data.duration
			return e
	var active := ActiveStatusEffect.new(effect_data, source)
	active_effects.append(active)
	return active


## Removes all instances of a given effect_id.
func remove_effect(effect_id: String) -> void:
	active_effects = active_effects.filter(func(e: ActiveStatusEffect):
		return e.effect.effect_id != effect_id
	)


## Returns true if at least one instance of effect_id exists.
func has_effect(effect_id: String) -> bool:
	for e in active_effects:
		if e.effect.effect_id == effect_id:
			return true
	return false


## Ticks all effects, removing expired ones.
func tick_all() -> void:
	var expired: Array[ActiveStatusEffect] = []
	for e in active_effects:
		if e.tick():
			expired.append(e)
	for e in expired:
		active_effects.erase(e)


## Returns total modifier for a stat from all active effects.
func get_modifier(stat: String) -> int:
	var total := 0
	for e in active_effects:
		total += e.get_modifier(stat)
	return total


## Counts stacks of a specific effect (for multi-stack effects like Charge).
func get_stack_count(effect_id: String) -> int:
	var count := 0
	for e in active_effects:
		if e.effect.effect_id == effect_id:
			count += e.effect.modifiers.get("damage_multiplier", 0)
	return count


## Consumes one stack of damage multiplier (used by Charge).
func consume_damage_multiplier(effect_id: String) -> void:
	for e in active_effects:
		if e.effect.effect_id == effect_id:
			var current: int = e.effect.modifiers.get("damage_multiplier", 0)
			if current > 0:
				e.effect.modifiers["damage_multiplier"] = current - 1
			break