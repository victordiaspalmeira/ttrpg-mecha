class_name UnitSpawner
extends Node

@export var mech_unit_scene: PackedScene

@onready var units_container: Node3D = %Units

# Injected services (set via setup())
var audio_manager: AudioManager = null
var battle_hud: BattleHud = null
var selection_state: SelectionState = null


func setup(p_audio: AudioManager, p_hud: BattleHud, p_selection: SelectionState) -> void:
	audio_manager = p_audio
	battle_hud = p_hud
	selection_state = p_selection


func spawn_unit(
	class_data: ClassData,
	tile: HexTile,
	team_id: String,
	primary_weapon: WeaponData = null,
	secondary_weapon: WeaponData = null,
	portrait: Texture2D = null,
	team_data: TeamData = null
) -> UnitBase:
	var unit: UnitBase = mech_unit_scene.instantiate() as UnitBase

	# Set properties BEFORE adding to tree so _ready() gets correct values
	unit.class_data = class_data
	unit.team_id = team_id

	if portrait:
		unit.portrait = portrait

	# Add to tree — this triggers _ready() which calls apply_team_data
	units_container.add_child(unit)

	# Inject dependencies into the unit
	unit.setup(audio_manager, battle_hud, selection_state)

	# Apply team data (colors, etc.) after _ready()
	if team_data:
		unit.apply_team_data(team_data)

	# apply_class_data() sets weapons from class_data — call it first so base weapons are set
	unit.apply_class_data()

	# Override with custom weapons if provided (must happen AFTER apply_class_data
	# because the equipment setter only works when unit.equipment is ready)
	if primary_weapon:
		unit.equipment.primary_weapon = primary_weapon
	if secondary_weapon:
		unit.equipment.secondary_weapon = secondary_weapon

	unit.move_to_tile(tile)

	return unit


func spawn_from_template(template: UnitTemplate, tile: HexTile, team_data: TeamData = null) -> UnitBase:
	return spawn_unit(
		template.class_data,
		tile,
		template.team_id,
		template.primary_weapon,
		template.secondary_weapon,
		template.portrait,
		team_data
	)
