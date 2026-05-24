class_name HexTile
extends Node3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var highlight_overlay: MeshInstance3D = $HighlightOverlay
@onready var _collision_shape: CollisionShape3D = $StaticBody3D/CollisionShape3D

var q: int
var r: int
var occupying_unit: UnitBase = null

# Tile data
var terrain: TerrainType = null
var elevation: float = 0.0
var obstacle_id: String = ""          # "rock", "tree", "wall", "" = none
var custom_move_cost: int = 0          # 0 = use terrain's default
var tags: Array[String] = []           # Runtime tags

var _config: GridConfig
var _default_material: Material
var _hover_material: Material
var _selected_material: Material
var _move_overlay_material: Material
var _attack_overlay_material: Material
var _attack_reach_overlay_material: Material

var is_selected := false
var is_in_move_range := false
var is_in_attack_range := false
var is_in_attack_reach := false
var is_hovered := false

const DEFAULT_TERRAIN := preload("res://data/grid/default_grass_terrain.tres")


func configure(grid_config: GridConfig) -> void:
	_config = grid_config
	_config.ensure_materials()

	_default_material = _config.default_material
	_hover_material = _config.hover_material
	_selected_material = _config.selected_material
	_move_overlay_material = _config.move_overlay_material
	_attack_overlay_material = _config.attack_overlay_material
	_attack_reach_overlay_material = _config.attack_reach_overlay_material

	# Ensure terrain (default grass if none set)
	if not terrain:
		terrain = DEFAULT_TERRAIN

	_apply_mesh_dimensions()
	update_visual()


func _apply_mesh_dimensions() -> void:
	var body_mesh := CylinderMesh.new()
	body_mesh.radial_segments = 6
	body_mesh.top_radius = _config.mesh_radius
	body_mesh.bottom_radius = _config.mesh_radius
	body_mesh.height = _config.mesh_height
	mesh_instance.mesh = body_mesh

	var overlay_mesh := CylinderMesh.new()
	overlay_mesh.radial_segments = 6
	overlay_mesh.top_radius = _config.mesh_radius * 0.92
	overlay_mesh.bottom_radius = _config.mesh_radius * 0.92
	overlay_mesh.height = 0.04
	highlight_overlay.mesh = overlay_mesh

	var surface_y := _config.get_surface_y()
	highlight_overlay.position.y = surface_y + elevation + 0.02

	var cylinder := _collision_shape.shape as CylinderShape3D
	if cylinder:
		cylinder.radius = _config.mesh_radius
		cylinder.height = _config.mesh_height


# ------------------------------------------------------------------------------
# Movement / blocking queries
# ------------------------------------------------------------------------------

## Returns the move cost to enter this tile.
func get_move_cost() -> int:
	if custom_move_cost > 0:
		return custom_move_cost
	if terrain:
		return terrain.move_cost
	return 1


## Returns true if this tile blocks movement (terrain or occupied).
func is_blocking_tile() -> bool:
	if terrain and terrain.is_blocking:
		return true
	if occupying_unit != null:
		return true
	return false


## Returns true if this tile blocks line of sight.
func blocks_los() -> bool:
	if terrain and terrain.blocks_los:
		return true
	if obstacle_id != "":
		return true
	return false


## Returns the effective height of this tile.
func get_effective_height() -> float:
	var h := _config.get_surface_y() + elevation
	if terrain:
		h += terrain.height_offset
	return h


# ------------------------------------------------------------------------------
# Visual state
# ------------------------------------------------------------------------------

func set_hovered() -> void:
	is_hovered = true
	update_visual()

func clear_hover() -> void:
	is_hovered = false
	update_visual()

func show_move_range() -> void:
	if is_selected:
		return
	is_in_move_range = true
	update_visual()

func clear_move_range() -> void:
	is_in_move_range = false
	update_visual()

func show_attack_range() -> void:
	if is_selected:
		return
	is_in_attack_range = true
	is_in_attack_reach = false
	update_visual()

func clear_attack_range() -> void:
	is_in_attack_range = false
	update_visual()

func show_attack_reach() -> void:
	if is_selected:
		return
	if is_in_attack_range:
		return
	is_in_attack_reach = true
	update_visual()

func clear_attack_reach() -> void:
	is_in_attack_reach = false
	update_visual()

func select() -> void:
	is_selected = true
	update_visual()

func deselect() -> void:
	is_selected = false
	update_visual()

func update_visual() -> void:
	if not _config:
		return

	if is_selected:
		mesh_instance.material_override = _selected_material
	elif is_hovered:
		mesh_instance.material_override = _hover_material
	else:
		mesh_instance.material_override = _default_material

	if is_in_attack_range:
		highlight_overlay.visible = true
		highlight_overlay.material_override = _attack_overlay_material
	elif is_in_attack_reach:
		highlight_overlay.visible = true
		highlight_overlay.material_override = _attack_reach_overlay_material
	elif is_in_move_range:
		highlight_overlay.visible = true
		highlight_overlay.material_override = _move_overlay_material
	else:
		highlight_overlay.visible = false