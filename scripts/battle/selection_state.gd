class_name SelectionState
extends Node

signal unit_selected(unit: UnitBase)
signal action_mode_changed(mode: ActionMode)
signal hovered_unit_changed(unit: UnitBase)

enum ActionMode {
	NONE,
	MOVE,
	ATTACK,
}

var hovered_tile: HexTile = null
var hovered_unit: UnitBase = null
var selected_tile: HexTile = null
var selected_unit: UnitBase = null
var current_action_mode: ActionMode = ActionMode.NONE


func select_unit(unit: UnitBase) -> void:
	selected_unit = unit
	selected_tile = unit.current_tile
	unit_selected.emit(unit)


func set_action_mode(mode: ActionMode) -> void:
	current_action_mode = mode
	action_mode_changed.emit(mode)


func set_hovered_unit(unit: UnitBase) -> void:
	if hovered_unit == unit:
		return

	hovered_unit = unit
	hovered_unit_changed.emit(unit)


func clear_tile_hover() -> void:
	if hovered_tile:
		hovered_tile.clear_hover()

	hovered_tile = null
