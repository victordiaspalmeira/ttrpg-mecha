class_name TerrainType
extends Resource

## Defines a terrain type with movement cost and blocking properties.

@export var terrain_id: String = "grass"
@export var display_name: String = "Grass"
@export var move_cost: int = 1          # AP cost to enter this tile
@export var is_blocking: bool = false    # Blocks pathfinding/movement entirely
@export var is_walkable: bool = true     # Can units stand on it
@export var blocks_los: bool = false     # Blocks line of sight
@export var tile_color: Color = Color(0.2, 0.24, 0.3)  # Color hint for editor
@export var height_offset: float = 0.0   # Visual height offset
@export var tags: Array[String] = []     # "cover", "water", "high_ground"