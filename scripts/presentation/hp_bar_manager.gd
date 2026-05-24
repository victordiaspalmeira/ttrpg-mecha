class_name HpBarManager
extends Node

## Manages creation and updating of HP bars for all units.

var hp_bars := {}
var units_container: Node3D = null
var hp_bar_scene: PackedScene = null


func setup(p_units_container: Node3D, p_hp_bar_scene: PackedScene) -> void:
	units_container = p_units_container
	hp_bar_scene = p_hp_bar_scene


func create_all() -> void:
	if not units_container or not hp_bar_scene:
		return
	for unit in units_container.get_children():
		var hp_bar = hp_bar_scene.instantiate()
		var visual = unit.get_node("UnitVisual")
		visual.add_child(hp_bar)
		hp_bar.position = Vector3(0, 2.5, 0)
		if unit.team_data:
			hp_bar.set_colors(unit.team_data.hp_bar_full_color, unit.team_data.hp_bar_empty_color)
		hp_bars[unit] = hp_bar


func update_all() -> void:
	for unit in hp_bars.keys():
		if not is_instance_valid(unit):
			continue
		if unit.max_hp <= 0:
			continue
		var hp_bar = hp_bars[unit]
		hp_bar.set_hp(unit.current_hp, unit.max_hp)