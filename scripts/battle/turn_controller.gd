class_name TurnController
extends Node

signal current_unit_changed(unit: UnitBase)
signal turn_ended(unit: UnitBase)

@onready var units_container: Node3D = %World/Units

var turn_queue: Array[UnitBase] = []
var current_turn_index: int = 0
var current_unit: UnitBase = null


func build_turn_queue() -> void:
	turn_queue.clear()

	for child in units_container.get_children():
		var unit := child as UnitBase
		if unit:
			turn_queue.append(unit)


func prune_invalid_units() -> void:
	var valid_queue: Array[UnitBase] = []

	for unit in turn_queue:
		if is_instance_valid(unit):
			valid_queue.append(unit)

	turn_queue = valid_queue

	if current_unit and not is_instance_valid(current_unit):
		current_unit = null


func start_first_turn() -> void:
	if turn_queue.is_empty():
		return

	current_turn_index = 0
	start_turn(turn_queue[current_turn_index])


func start_turn(unit: UnitBase) -> void:
	current_unit = unit
	unit.refresh_turn()
	current_unit_changed.emit(unit)


func end_turn() -> void:
	prune_invalid_units()

	if turn_queue.is_empty():
		return

	turn_ended.emit(current_unit)

	current_turn_index += 1

	if current_turn_index >= turn_queue.size():
		current_turn_index = 0

	start_turn(turn_queue[current_turn_index])
