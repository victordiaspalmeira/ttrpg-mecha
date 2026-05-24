class_name EncounterTileOverride
extends Resource

## Defines a custom tile override for a specific position in an encounter.

@export var q: int = 0
@export var r: int = 0
@export var terrain: TerrainType = null
@export var elevation: float = 0.0
@export var obstacle_id: String = ""       # "rock", "tree", "wall", etc.
@export var custom_move_cost: int = 0       # 0 = use terrain's default
@export var tags: Array[String] = []