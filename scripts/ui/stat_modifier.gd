class_name StatModifier
extends RefCounted

## Represents a single stat modifier with source info for tooltip breakdown.
var source_name: String
var base_value: int
var modifier_value: int
var total_value: int
var is_buff: bool  # true = buff (green), false = debuff (red)


func _init(p_source: String, p_base: int, p_modifier: int, p_total: int) -> void:
	source_name = p_source
	base_value = p_base
	modifier_value = p_modifier
	total_value = p_total
	is_buff = modifier_value >= 0


## Returns a user-readable breakdown string for tooltips.
func get_breakdown_text() -> String:
	var lines: Array[String] = []
	lines.append("Base: %d" % base_value)
	if modifier_value != 0:
		var sign := "+" if modifier_value > 0 else ""
		lines.append("%s %s: %s%d" % [sign, source_name, sign, modifier_value])
	lines.append("Total: %d" % total_value)
	return "\n".join(lines)