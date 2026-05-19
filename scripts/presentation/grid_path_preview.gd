class_name GridPathPreview
extends Node3D

const LINE_Y_OFFSET := 0.16
const LINE_COLOR := Color(0.85, 0.95, 1.0, 0.9)

var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	_mesh_instance = MeshInstance3D.new()
	add_child(_mesh_instance)

	_material = StandardMaterial3D.new()
	_material.albedo_color = LINE_COLOR
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh_instance.material_override = _material
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func clear() -> void:
	_mesh_instance.mesh = null


func show_path(tiles: Array) -> void:
	if tiles.size() < 2:
		clear()
		return

	var points := PackedVector3Array()
	for tile in tiles:
		if tile is HexTile:
			var pos: Vector3 = tile.global_position
			points.append(Vector3(pos.x, LINE_Y_OFFSET, pos.z))

	_mesh_instance.mesh = _build_line_strip(points)


func _build_line_strip(points: PackedVector3Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
	return mesh
