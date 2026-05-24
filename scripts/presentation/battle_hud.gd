class_name BattleHud
extends Node

## Facade for all battle UI components.
## Coordinates sub-components and exposes a clean API for BattleFlow.

@export var unit_hp_bar_scene: PackedScene
@export var turn_order_item_scene: PackedScene
@export var damage_popup_scene: PackedScene

# Injected services (set via setup())
var selection_state: SelectionState = null
var turn_controller: TurnController = null
var units_container: Node3D = null
var audio_manager: AudioManager = null
var _camera: Camera3D = null

# UI node references (cached in _ready)
var turn_announce = null
var unit_info_panel = null
var action_panel = null
var move_button = null
var action_button = null
var end_turn_button = null

# Sub-components
var resource_display: ResourceDisplay
var hint_display: HintDisplay
var damage_popup_manager: DamagePopupManager
var action_submenu_ui: ActionSubmenuUI
var hp_bar_manager: HpBarManager
var turn_order_ui: TurnOrderUI
var action_name_popup: ActionNamePopup

var camera: Camera3D:
	get: return _camera

var camera_controller: Node3D:
	get:
		var rig := %World/CameraRig as Node3D
		return rig

var _display_unit: UnitBase = null
var _battle_finished := false
var _pending_skill: SkillData = null
var _setup_done := false


# ------------------------------------------------------------------------------
# Dependency injection
# ------------------------------------------------------------------------------

func setup(
	p_selection_state: SelectionState,
	p_turn_controller: TurnController,
	p_units_container: Node3D,
	p_audio_manager: AudioManager,
	p_camera: Camera3D
) -> void:
	selection_state = p_selection_state
	turn_controller = p_turn_controller
	units_container = p_units_container
	audio_manager = p_audio_manager
	_camera = p_camera
	_setup_done = true
	_on_setup_complete()


# ------------------------------------------------------------------------------
# Lifecycle
# ------------------------------------------------------------------------------

func _ready() -> void:
	var ui_layer: CanvasLayer = get_node("/root/BattleScene/UI/CanvasLayer")
	if not ui_layer:
		push_error("BattleHud: missing CanvasLayer")
		return

	turn_announce = ui_layer.get_node("TurnAnnounce")
	unit_info_panel = ui_layer.get_node("UnitInfoPanel")
	action_panel = ui_layer.get_node("ActionPanel")
	var hint_label = ui_layer.get_node("ActionPanel/VBoxContainer/HintLabel")
	var movement_label = ui_layer.get_node("ActionPanel/VBoxContainer/ResourcesHBox/MovementLabel")
	var ap_label = ui_layer.get_node("ActionPanel/VBoxContainer/ResourcesHBox/APLabel")
	move_button = ui_layer.get_node("ActionPanel/VBoxContainer/MoveButton")
	action_button = ui_layer.get_node("ActionPanel/VBoxContainer/ActionButton")
	end_turn_button = ui_layer.get_node("ActionPanel/VBoxContainer/EndTurnButton")
	var submenu = ui_layer.get_node("ActionSubmenu")
	var submenu_container = ui_layer.get_node("ActionSubmenu/ActionSubmenuContainer")
	var turn_order_container = ui_layer.get_node("TurnOrderBar/VBox/HBoxContainer")
	var damage_container = ui_layer.get_node("DamagePopupContainer")

	# Initialize sub-components
	resource_display = ResourceDisplay.new()
	resource_display.name = "ResourceDisplay"
	add_child(resource_display)
	resource_display.setup(movement_label, ap_label)

	hint_display = HintDisplay.new()
	hint_display.name = "HintDisplay"
	add_child(hint_display)
	hint_display.setup(hint_label)

	damage_popup_manager = DamagePopupManager.new()
	damage_popup_manager.name = "DamagePopupManager"
	add_child(damage_popup_manager)

	action_submenu_ui = ActionSubmenuUI.new()
	action_submenu_ui.name = "ActionSubmenuUI"
	add_child(action_submenu_ui)
	action_submenu_ui.setup(submenu, submenu_container, selection_state, self)

	hp_bar_manager = HpBarManager.new()
	hp_bar_manager.name = "HpBarManager"
	add_child(hp_bar_manager)

	turn_order_ui = TurnOrderUI.new()
	turn_order_ui.name = "TurnOrderUI"
	add_child(turn_order_ui)
	turn_order_ui.setup(turn_order_container, turn_order_item_scene)

	action_name_popup = ActionNamePopup.new()
	action_name_popup.name = "ActionNamePopup"
	add_child(action_name_popup)

	# Connect UI signals
	if action_button:
		action_button.pressed.connect(_on_action_button_pressed)

	await get_tree().process_frame
	call_deferred("_build_unit_ui")


func _on_setup_complete() -> void:
	if not selection_state:
		return
	selection_state.action_mode_changed.connect(_on_action_mode_changed)
	selection_state.hovered_unit_changed.connect(_on_hovered_unit_changed)
	selection_state.pinned_unit_changed.connect(_on_pinned_unit_changed)


func _build_unit_ui() -> void:
	hp_bar_manager.setup(units_container, unit_hp_bar_scene)
	hp_bar_manager.create_all()
	turn_order_ui.create_all(units_container)

	if turn_controller and turn_controller.current_unit:
		update_resource_display(turn_controller.current_unit)


func _process(_delta: float) -> void:
	hp_bar_manager.update_all()
	if unit_info_panel and unit_info_panel.visible and selection_state and selection_state.pinned_unit:
		unit_info_panel.refresh_current()


# ------------------------------------------------------------------------------
# Public API — used by BattleFlow
# ------------------------------------------------------------------------------

func present_turn_start(unit: UnitBase) -> void:
	if _battle_finished or not unit:
		return
	_display_unit = unit
	hint_display.set_display_unit(unit)

	var cam_rig := %World/CameraRig as Node3D
	if cam_rig:
		cam_rig.focus_on_unit(unit)

	update_resource_display(unit)
	turn_order_ui.highlight(unit)
	_update_player_controls(unit)

	if audio_manager:
		audio_manager.play_turn_start()

	await turn_announce.play_for_unit(unit)


func show_action_feedback(message: String, duration := 2.2) -> void:
	hint_display.show_error(message, duration)


func show_battle_result(message: String) -> void:
	_battle_finished = true
	hint_display.set_battle_finished(true)
	_set_player_controls_enabled(false)

	var border := Color(0.4, 1.0, 0.55, 1.0)
	var title_color := Color(0.85, 1.0, 0.9, 1.0)

	if message.to_lower().contains("defeat"):
		border = Color(1.0, 0.4, 0.35, 1.0)
		title_color = Color(1.0, 0.75, 0.7, 1.0)

	await turn_announce.play_message(message, "Battle complete", border, title_color)


func update_resource_display(unit: UnitBase) -> void:
	resource_display.update(unit)


func show_damage_popup(unit: UnitBase, amount: int, popup_type: String = "damage") -> void:
	if not damage_popup_manager:
		return
	damage_popup_manager.setup(damage_popup_scene, get_node("/root/BattleScene/UI/CanvasLayer/DamagePopupContainer"), _camera)
	damage_popup_manager.show_popup(unit, amount, popup_type)


func show_damage_popup_at_position(world_position: Vector3, amount: int, popup_type: String = "damage") -> void:
	if not damage_popup_manager:
		return
	damage_popup_manager.show_popup(world_position, amount, popup_type)


func show_action_name_popup(action_name: String, duration := 1.2) -> void:
	if action_name_popup:
		action_name_popup.show_popup(action_name, duration)


# ------------------------------------------------------------------------------
# Action mode UI
# ------------------------------------------------------------------------------

func _on_action_mode_changed(mode: SelectionState.ActionMode) -> void:
	_style_action_buttons(mode)
	action_submenu_ui.hide()
	if mode != SelectionState.ActionMode.SKILL:
		_pending_skill = null


func _on_action_button_pressed() -> void:
	action_submenu_ui.toggle(_display_unit)


func _style_action_buttons(mode: SelectionState.ActionMode) -> void:
	var color_on := Color(0.55, 0.85, 1.0, 1.0)
	var color_off := Color(0.92, 0.94, 0.96, 1.0)

	_reset_button_style(move_button, color_off)
	_reset_button_style(action_button, color_off)
	_reset_button_style(end_turn_button, color_off)

	match mode:
		SelectionState.ActionMode.MOVE:
			_highlight_button(move_button, color_on)
		SelectionState.ActionMode.ATTACK:
			_highlight_button(action_button, color_on)


func _highlight_button(button: Button, color: Color) -> void:
	if button:
		button.add_theme_color_override("font_color", color)


func _reset_button_style(button: Button, color: Color) -> void:
	if button:
		button.add_theme_color_override("font_color", color)


# ------------------------------------------------------------------------------
# Hover / Info panel
# ------------------------------------------------------------------------------

func _on_hovered_unit_changed(unit: UnitBase) -> void:
	if not unit_info_panel:
		return
	if selection_state and selection_state.pinned_unit:
		return
	if not unit:
		unit_info_panel.hide()
		return
	unit_info_panel.show_for_unit(unit, false)


func _on_pinned_unit_changed(unit: UnitBase) -> void:
	if not unit_info_panel:
		return
	if not unit:
		unit_info_panel.hide()
		return
	unit_info_panel.show_for_unit(unit, true)


# ------------------------------------------------------------------------------
# Player controls
# ------------------------------------------------------------------------------

func _update_player_controls(unit: UnitBase) -> void:
	var is_player := unit.is_player_team()
	_set_player_controls_enabled(is_player and not _battle_finished)

	if is_player:
		hint_display.set_default_hint("Move, use actions, then end turn.")
		hint_display.set_display_unit(unit)
	else:
		var hint_label = _get_hint_label()
		if hint_label:
			hint_label.text = "Enemy is acting..."


func _get_hint_label():
	var ui_layer = get_node_or_null("/root/BattleScene/UI/CanvasLayer")
	return ui_layer.get_node_or_null("ActionPanel/VBoxContainer/HintLabel") if ui_layer else null


func _set_player_controls_enabled(enabled: bool) -> void:
	if move_button:
		move_button.disabled = not enabled
	if action_button:
		action_button.disabled = not enabled
	if end_turn_button:
		end_turn_button.disabled = not enabled
	if not enabled:
		action_submenu_ui.hide()
	if action_panel:
		action_panel.modulate.a = 1.0 if enabled else 0.45


# ------------------------------------------------------------------------------
# Skill execution (called from BattleInput)
# ------------------------------------------------------------------------------

func _enter_skill_mode(skill: SkillData) -> void:
	_pending_skill = skill
	if selection_state:
		selection_state.set_action_mode(SelectionState.ActionMode.SKILL)


func _execute_skill_on_target(target_unit: UnitBase, target_tile: HexTile = null) -> void:
	if not _pending_skill or not _display_unit:
		return
	var scene_root: Node = _display_unit.get_tree().current_scene
	var executor: SkillExecutor = scene_root.get_node("BattleSession/SkillExecutor")
	var ctx := SkillContext.new(_display_unit, _pending_skill, target_unit, target_tile)
	if executor.execute(ctx):
		_display_unit.spend_ap(_pending_skill.ap_cost)
		update_resource_display(_display_unit)
	_pending_skill = null