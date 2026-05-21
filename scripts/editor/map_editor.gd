class_name MapEditor
extends Node3D

## Editor de mapas — permite posicionar unidades no grid e salvar como EncounterData.

@export var grid_config: GridConfig
@export var hex_tile_scene: PackedScene
@export var unit_scene: PackedScene

@onready var grid_manager: GridManager = $World/GridManager
@onready var units_container: Node3D = $World/Units
@onready var camera_rig: Node3D = $World/CameraRig
@onready var cursor_visual: MeshInstance3D = $World/CursorVisual

# Estado
var _grid_radius: int = 5
var _cursor_tile: HexTile = null
var _placed_units: Array[Dictionary] = []  # [{template, q, r, team_id}]
var _selected_template: UnitTemplate = null
var _selected_team_id: String = "player"

# Referências de UI
var _ui_panel: Control = null
var _template_list: ItemList = null
var _team_option: OptionButton = null
var _radius_spin: SpinBox = null
var _status_label: Label = null


func _ready() -> void:
	_setup_default_resources()
	_setup_grid()
	_setup_cursor()
	_setup_ui()
	_load_templates()


func _setup_default_resources() -> void:
	if not grid_config:
		grid_config = load("res://data/grid/default_grid_config.tres") as GridConfig
	if not hex_tile_scene:
		hex_tile_scene = load("res://scenes/grid/HexTile3D.tscn") as PackedScene
	if not unit_scene:
		unit_scene = load("res://scenes/units/unit_base.tscn") as PackedScene


func _setup_grid() -> void:
	grid_manager.config = grid_config
	grid_manager.hex_tile_scene = hex_tile_scene
	# Set grid radius from editor state before initializing
	grid_manager.config.grid_radius = _grid_radius
	grid_manager.initialize()


func _setup_cursor() -> void:
	if cursor_visual:
		# Criar mesh hexagonal para o cursor
		var mesh := CylinderMesh.new()
		mesh.radial_segments = 6
		mesh.top_radius = grid_config.mesh_radius * 0.95
		mesh.bottom_radius = grid_config.mesh_radius * 0.95
		mesh.height = 0.05
		cursor_visual.mesh = mesh

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 0.8, 1.0, 0.6)
		mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		cursor_visual.material_override = mat
		cursor_visual.visible = false


func _setup_ui() -> void:
	_ui_panel = $UI/EditorPanel
	_template_list = $UI/EditorPanel/VBox/TemplateList as ItemList
	_team_option = $UI/EditorPanel/VBox/TeamRow/TeamOption as OptionButton
	_radius_spin = $UI/EditorPanel/VBox/RadiusRow/RadiusSpin as SpinBox
	_status_label = $UI/EditorPanel/VBox/StatusLabel as Label

	# Configurar controles
	_radius_spin.value = _grid_radius
	_radius_spin.min_value = 2
	_radius_spin.max_value = 12
	_radius_spin.value_changed.connect(_on_radius_changed)

	_team_option.clear()
	_team_option.add_item("Player", 0)
	_team_option.add_item("Enemy", 1)
	_team_option.item_selected.connect(_on_team_selected)

	# Botões
	var btn_save: Button = $UI/EditorPanel/VBox/ButtonRow/BtnSave as Button
	var btn_clear: Button = $UI/EditorPanel/VBox/ButtonRow/BtnClear as Button
	var btn_test: Button = $UI/EditorPanel/VBox/ButtonRow/BtnTest as Button
	var btn_load: Button = $UI/EditorPanel/VBox/ButtonRow/BtnLoad as Button

	btn_save.pressed.connect(_on_save_pressed)
	btn_clear.pressed.connect(_on_clear_pressed)
	btn_test.pressed.connect(_on_test_pressed)
	btn_load.pressed.connect(_on_load_pressed)

	_template_list.item_selected.connect(_on_template_selected)

	_update_status("Select a template and click on the grid to place units.")


func _load_templates() -> void:
	_template_list.clear()
	var dir := DirAccess.open("res://data/templates/")
	if not dir:
		push_error("MapEditor: Could not open templates directory.")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".remap"):
			var clean_name := file_name.trim_suffix(".remap")
			var path := "res://data/templates/" + clean_name
			var template := load(path) as UnitTemplate
			if template:
				_template_list.add_item(template.get_display_name())
				_template_list.set_item_metadata(_template_list.item_count - 1, path)
		file_name = dir.get_next()
	dir.list_dir_end()

	if _template_list.item_count > 0:
		_template_list.select(0)
		_on_template_selected(0)


func _on_template_selected(index: int) -> void:
	var path: String = _template_list.get_item_metadata(index)
	if path:
		_selected_template = load(path) as UnitTemplate
		_update_status("Selected: %s (%s)" % [_selected_template.get_display_name(), _selected_template.team_id])


func _on_team_selected(index: int) -> void:
	_selected_team_id = "player" if index == 0 else "enemy"


func _on_radius_changed(value: float) -> void:
	_grid_radius = int(value)
	_regenerate_grid()


func _regenerate_grid() -> void:
	grid_manager.initialize()
	# Recolocar unidades que ainda estão no grid
	var units_to_replay: Array[Dictionary] = []
	for entry in _placed_units:
		var q: int = entry.q
		var r: int = entry.r
		var tile := grid_manager.get_tile(q, r)
		if tile:
			units_to_replay.append(entry)

	_placed_units.clear()
	for child in units_container.get_children():
		if is_instance_valid(child):
			child.queue_free()

	for entry in units_to_replay:
		_spawn_unit_at(entry.template, entry.q, entry.r, entry.team_id)


func _spawn_unit_at(template: UnitTemplate, q: int, r: int, team_id: String) -> void:
	var tile := grid_manager.get_tile(q, r)
	if not tile:
		return

	var unit := unit_scene.instantiate() as UnitBase
	unit.class_data = template.class_data
	unit.team_id = team_id
	if template.primary_weapon:
		unit.primary_weapon = template.primary_weapon
	if template.secondary_weapon:
		unit.secondary_weapon = template.secondary_weapon
	if template.portrait:
		unit.portrait = template.portrait

	units_container.add_child(unit)
	unit.apply_class_data()
	unit.move_to_tile(tile)
	unit.configure_from_grid(grid_config)

	# Aplicar cor de time
	var team_data := _create_team_data(team_id)
	if team_data:
		unit.apply_team_data(team_data)

	_placed_units.append({
		"template": template,
		"q": q,
		"r": r,
		"team_id": team_id,
	})


func _create_team_data(team_id: String) -> TeamData:
	var td := TeamData.new()
	td.team_id = team_id
	td.is_player = (team_id == "player")
	td.display_name = "Player" if td.is_player else "Enemy"
	if not td.is_player:
		td.outline_color = Color(1, 0.32, 0.24, 1)
		td.hp_bar_full_color = Color(1, 0.32, 0.24, 1)
	return td


func _process(_delta: float) -> void:
	_update_cursor_position()


func _update_cursor_position() -> void:
	var camera := camera_rig.get_node("CameraPitch/Camera3D") as Camera3D
	if not camera:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	var ray_end := ray_origin + ray_dir * 1000.0

	var space_state := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var hit := space_state.intersect_ray(query)

	if not hit.is_empty():
		var collider := hit.collider as Node
		var found_tile: HexTile = null

		while collider:
			if collider is HexTile:
				found_tile = collider as HexTile
				break
			collider = collider.get_parent()

		if found_tile:
			_cursor_tile = found_tile
			cursor_visual.visible = true
			cursor_visual.global_position = found_tile.global_position + Vector3.UP * 0.03
			return

	cursor_visual.visible = false
	_cursor_tile = null


func _unhandled_input(event: InputEvent) -> void:
	# Only consume mouse clicks for editor actions
	# Let everything else (camera movement, zoom) pass through

	if event.is_action_pressed("left_click") and not event.is_echo():
		if _cursor_tile and _selected_template:
			# Check if tile is already occupied
			for entry in _placed_units:
				if entry.q == _cursor_tile.q and entry.r == _cursor_tile.r:
					_update_status("Tile (%d, %d) already occupied. Right-click to remove." % [_cursor_tile.q, _cursor_tile.r])
					return

			_spawn_unit_at(_selected_template, _cursor_tile.q, _cursor_tile.r, _selected_team_id)
			_update_status("Placed %s at (%d, %d)" % [_selected_template.get_display_name(), _cursor_tile.q, _cursor_tile.r])
			get_viewport().set_input_as_handled()

	elif event.is_action_pressed("right_click") and not event.is_echo():
		if _cursor_tile:
			_remove_unit_at(_cursor_tile.q, _cursor_tile.r)
			get_viewport().set_input_as_handled()


func _remove_unit_at(q: int, r: int) -> void:
	# Remove from placed_units
	for i in range(_placed_units.size() - 1, -1, -1):
		if _placed_units[i].q == q and _placed_units[i].r == r:
			_placed_units.remove_at(i)
			break

	# Remove unit node
	for child in units_container.get_children():
		var unit := child as UnitBase
		if unit and unit.current_tile and unit.current_tile.q == q and unit.current_tile.r == r:
			unit.queue_free()
			_update_status("Removed unit at (%d, %d)" % [q, r])
			return


func _on_save_pressed() -> void:
	var encounter := EncounterData.new()
	encounter.encounter_id = "custom_map"
	encounter.display_name = "Custom Map"
	encounter.grid_radius = _grid_radius

	# Coletar times únicos
	var teams_seen: Dictionary = {}
	for entry in _placed_units:
		if not teams_seen.has(entry.team_id):
			teams_seen[entry.team_id] = true
			var td := _create_team_data(entry.team_id)
			encounter.teams.append(td)

	# Criar spawns
	for entry in _placed_units:
		var spawn := EncounterSpawn.new()
		spawn.template = entry.template
		spawn.q = entry.q
		spawn.r = entry.r
		spawn.team_id = entry.team_id
		encounter.spawns.append(spawn)

	# Salvar — encounters dir already exists in project
	var path := "res://data/encounters/custom_map.tres"
	var err := ResourceSaver.save(encounter, path)
	if err == OK:
		_update_status("Saved to %s (%d units, %d teams)" % [path, encounter.spawns.size(), encounter.teams.size()])
	else:
		_update_status("Error saving: %s" % error_string(err))


func _on_clear_pressed() -> void:
	_placed_units.clear()
	for child in units_container.get_children():
		if is_instance_valid(child):
			child.queue_free()
	_update_status("Cleared all units.")


func _on_test_pressed() -> void:
	# Salvar temporariamente e carregar no battle scene
	_on_save_pressed()
	var encounter := load("res://data/encounters/custom_map.tres") as EncounterData
	if encounter:
		if GameManager:
			GameManager.selected_encounter = encounter
		get_tree().change_scene_to_file("res://scenes/battle/battle_scene.tscn")
	else:
		_update_status("Error: Could not load saved encounter.")


func _on_load_pressed() -> void:
	# Carregar um encounter existente
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.filters = ["*.tres"]
	dialog.current_dir = "res://data/encounters/"
	dialog.file_selected.connect(func(path: String):
		_load_encounter(path)
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2(600, 400))


func _load_encounter(path: String) -> void:
	var encounter := load(path) as EncounterData
	if not encounter:
		_update_status("Error: Could not load %s" % path)
		return

	# Limpar atual
	_on_clear_pressed()

	# Configurar grid
	_grid_radius = encounter.grid_radius if encounter.grid_radius > 0 else 5
	_radius_spin.value = _grid_radius
	_regenerate_grid()

	# Colocar unidades
	for spawn in encounter.spawns:
		if spawn.template:
			_spawn_unit_at(spawn.template, spawn.q, spawn.r, spawn.team_id)
		elif spawn.get_class_data():
			# Spawn sem template — criar template temporário
			var template := UnitTemplate.new()
			template.class_data = spawn.get_class_data()
			template.team_id = spawn.get_team_id()
			template.display_name = spawn.get_class_data().display_name
			_spawn_unit_at(template, spawn.q, spawn.r, spawn.get_team_id())

	_update_status("Loaded %s (%d units)" % [encounter.display_name, encounter.spawns.size()])


func _update_status(message: String) -> void:
	if _status_label:
		_status_label.text = message
	print("MapEditor: ", message)