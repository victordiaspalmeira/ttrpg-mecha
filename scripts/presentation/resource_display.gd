class_name ResourceDisplay
extends Node

## Displays MOV and AP labels for the selected unit.

var movement_label = null
var ap_label = null


func setup(p_movement_label, p_ap_label) -> void:
	movement_label = p_movement_label
	ap_label = p_ap_label


func update(unit: UnitBase) -> void:
	if not unit:
		if movement_label:
			movement_label.text = "MOV  —"
		if ap_label:
			ap_label.text = "AP  —"
		return

	if movement_label:
		movement_label.text = "MOV  %d / %d" % [unit.current_movement, unit.max_movement]
	if ap_label:
		ap_label.text = "AP  %d / %d" % [unit.current_ap, unit.max_ap]