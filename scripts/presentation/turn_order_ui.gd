class_name TurnOrderUI
extends Node

## Manages the turn order display bar.

var _turn_order_items := {}
var turn_order_container = null
var turn_order_item_scene: PackedScene = null


func setup(p_container, p_scene: PackedScene) -> void:
	turn_order_container = p_container
	turn_order_item_scene = p_scene


func create_all(units_container: Node3D) -> void:
	if not turn_order_container or not turn_order_item_scene:
		return
	for unit in units_container.get_children():
		var item = turn_order_item_scene.instantiate()
		turn_order_container.add_child(item)
		if item.has_method("setup"):
			item.setup(unit)
		_turn_order_items[unit] = item


func highlight(active_unit: UnitBase) -> void:
	for unit in _turn_order_items.keys():
		if not is_instance_valid(unit):
			continue
		var item = _turn_order_items[unit]
		if not is_instance_valid(item):
			continue
		if item.has_method("set_active"):
			item.set_active(unit == active_unit)