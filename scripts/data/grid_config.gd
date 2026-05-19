class_name GridConfig
extends Resource

@export var hex_size := 1.2
@export var mesh_radius := 1.0
@export var mesh_height := 0.2
@export var grid_radius := 5

@export_group("Tile Colors")
@export var default_color := Color(0.2, 0.24, 0.3, 1.0)
@export var hover_color := Color(0.95, 0.82, 0.2, 1.0)
@export var selected_color := Color(0.35, 0.9, 0.45, 1.0)
@export var move_overlay_color := Color(0.35, 0.55, 0.95, 0.55)
@export var attack_overlay_color := Color(0.95, 0.28, 0.22, 0.65)
@export var attack_reach_overlay_color := Color(0.3, 0.85, 0.45, 0.4)

var default_material: StandardMaterial3D
var hover_material: StandardMaterial3D
var selected_material: StandardMaterial3D
var move_overlay_material: StandardMaterial3D
var attack_overlay_material: StandardMaterial3D
var attack_reach_overlay_material: StandardMaterial3D

var _materials_ready := false


func ensure_materials() -> void:
	if _materials_ready:
		return

	default_material = _make_opaque_material(default_color)
	hover_material = _make_opaque_material(hover_color)
	selected_material = _make_opaque_material(selected_color)
	move_overlay_material = _make_overlay_material(move_overlay_color)
	attack_overlay_material = _make_overlay_material(attack_overlay_color)
	attack_reach_overlay_material = _make_overlay_material(attack_reach_overlay_color)
	_materials_ready = true


func get_surface_y() -> float:
	return mesh_height * 0.5


static func _make_opaque_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material


static func _make_overlay_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.7
	return material
