## Runtime instance of a StatusEffect applied to a unit.
## Tracks remaining duration and the source effect data.
class_name ActiveStatusEffect

var effect: StatusEffect
var turns_remaining: int
var instance_id: int
var source: String = ""


func _init(p_effect: StatusEffect, p_source: String = "") -> void:
	effect = p_effect
	turns_remaining = p_effect.duration
	instance_id = randi()
	source = p_source


## Returns true if this effect expired and should be removed.
func tick() -> bool:
	if effect.duration < 0:
		return false  # permanent
	turns_remaining -= 1
	return turns_remaining <= 0


func get_modifier(stat: String) -> int:
	return effect.get_modifier(stat)