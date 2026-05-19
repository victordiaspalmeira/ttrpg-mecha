class_name UnitSpawner
extends Node

@export var mech_unit_scene: PackedScene

@onready var units_container: Node3D = %Units


func spawn_unit(
	class_data: ClassData,
	tile: HexTile,
	team: String
) -> UnitBase:
	var unit: UnitBase = mech_unit_scene.instantiate() as UnitBase

	units_container.add_child(unit)

	unit.class_data = class_data
	unit.team = team

	unit.apply_class_data()

	unit.move_to_tile(tile)

	return unit
