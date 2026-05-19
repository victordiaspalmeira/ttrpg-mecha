class_name BattleHud
extends Node

@export var unit_hp_bar_scene: PackedScene
@export var turn_order_item_scene: PackedScene
@export var damage_popup_scene: PackedScene

@onready var selection_state: SelectionState = %SelectionState
@onready var turn_controller: TurnController = %TurnController
@onready var units_container: Node3D = %Units
@onready var turn_announce: TurnAnnounce = %TurnAnnounce

@onready var camera: Camera3D = (
	%World.get_node("CameraRig/CameraPitch/Camera3D")
)

@onready var action_panel: PanelContainer = %ActionPanel
@onready var action_label: Label = %ActionLabel
@onready var hint_label: Label = %HintLabel
@onready var movement_label: Label = %MovementLabel
@onready var ap_label: Label = %APLabel
@onready var move_button: Button = %MoveButton
@onready var attack_button: Button = %AttackButton
@onready var end_turn_button: Button = %EndTurnButton
@onready var unit_ui_container: Control = %UnitUIContainer
@onready var hover_info_panel: PanelContainer = %HoverInfoPanel
@onready var portrait_rect: TextureRect = %Portrait
@onready var name_label: Label = %NameLabel
@onready var hp_label: Label = %HPLabel
@onready var movement_hover_label: Label = %MovementHoverLabel
@onready var ap_hover_label: Label = %APHoverLabel
@onready var attack_label: Label = %AttackLabel
@onready var range_label: Label = %RangeLabel
@onready var turn_order_container: HBoxContainer = %HBoxContainer
@onready var damage_popup_container: Control = %DamagePopupContainer
@onready var camera_controller = (
	%CameraRig
)

const COLOR_MODE_ON := Color(0.55, 0.85, 1.0, 1.0)
const COLOR_MODE_OFF := Color(0.92, 0.94, 0.96, 1.0)
const COLOR_HINT_NORMAL := Color(0.78, 0.82, 0.88, 1.0)
const COLOR_HINT_ERROR := Color(1.0, 0.55, 0.42, 1.0)

var hp_bars := {}
var _turn_order_items := {}
var _display_unit: UnitBase = null
var _battle_finished := false
var _default_hint := "Move, attack, then end turn."
var _feedback_restore_timer: SceneTreeTimer = null


func _ready() -> void:
	selection_state.action_mode_changed.connect(_on_action_mode_changed)
	selection_state.hovered_unit_changed.connect(_on_hovered_unit_changed)

	update_action_label(selection_state.current_action_mode)
	_style_action_buttons(selection_state.current_action_mode)
	hint_label.add_theme_color_override("font_color", COLOR_HINT_NORMAL)

	await get_tree().process_frame
	call_deferred("_build_unit_ui")


func show_action_feedback(message: String, duration := 2.2) -> void:
	if message.is_empty():
		return

	if _feedback_restore_timer:
		_feedback_restore_timer.timeout.disconnect(_on_feedback_restore_timeout)

	hint_label.text = message
	hint_label.add_theme_color_override("font_color", COLOR_HINT_ERROR)
	_feedback_restore_timer = get_tree().create_timer(duration)
	_feedback_restore_timer.timeout.connect(
		_on_feedback_restore_timeout,
		CONNECT_ONE_SHOT
	)


func _on_feedback_restore_timeout() -> void:
	_feedback_restore_timer = null
	hint_label.add_theme_color_override("font_color", COLOR_HINT_NORMAL)
	_restore_default_hint()


func _restore_default_hint() -> void:
	if _battle_finished:
		return

	if _display_unit and _display_unit.team == "player":
		hint_label.text = _default_hint
	elif _display_unit:
		hint_label.text = "Enemy is acting..."
	else:
		hint_label.text = _default_hint


func _build_unit_ui() -> void:
	create_hp_bars()
	create_turn_order()

	if turn_controller.current_unit:
		update_resource_display(turn_controller.current_unit)


func _process(_delta: float) -> void:
	update_hp_bars()


func present_turn_start(unit: UnitBase) -> void:
	if _battle_finished or not unit:
		return

	_display_unit = unit
	camera_controller.focus_on_unit(unit)
	update_resource_display(unit)
	_highlight_turn_order(unit)
	_update_player_controls(unit)

	await turn_announce.play_for_unit(unit)


func _on_action_mode_changed(mode: SelectionState.ActionMode) -> void:
	update_action_label(mode)
	_style_action_buttons(mode)


func update_action_label(mode: SelectionState.ActionMode) -> void:
	var mode_text := "Idle"

	if mode == SelectionState.ActionMode.MOVE:
		mode_text = "Moving"
	elif mode == SelectionState.ActionMode.ATTACK:
		mode_text = "Attacking"

	action_label.text = "Mode · " + mode_text


func show_battle_result(message: String) -> void:
	_battle_finished = true
	_set_player_controls_enabled(false)

	var border := Color(0.4, 1.0, 0.55, 1.0)
	var title_color := Color(0.85, 1.0, 0.9, 1.0)

	if message.to_lower().contains("defeat"):
		border = Color(1.0, 0.4, 0.35, 1.0)
		title_color = Color(1.0, 0.75, 0.7, 1.0)

	await turn_announce.play_message(
		message,
		"Battle complete",
		border,
		title_color
	)


func update_resource_display(unit: UnitBase) -> void:
	if not unit:
		movement_label.text = "MOV  —"
		ap_label.text = "AP  —"
		return

	movement_label.text = "MOV  %d / %d" % [unit.current_movement, unit.max_movement]
	ap_label.text = "AP  %d / %d" % [unit.current_ap, unit.max_ap]


func create_hp_bars() -> void:

	for unit in units_container.get_children():

		var hp_bar = (
			unit_hp_bar_scene.instantiate()
		)

		var visual = (
			unit.get_node(
				"UnitVisual"
			)
		)

		visual.add_child(hp_bar)

		hp_bar.position = Vector3(
			0,
			1.8,
			0
		)

		hp_bars[unit] = hp_bar

func update_hp_bars() -> void:

	for unit in hp_bars.keys():
		if not is_instance_valid(unit):
			continue

		if unit.max_hp <= 0:
			continue

		var hp_bar = hp_bars[unit]
		hp_bar.set_hp(
			unit.current_hp,
			unit.max_hp
		)

func _on_hovered_unit_changed(unit: UnitBase) -> void:
	if not unit:
		hover_info_panel.visible = false
		return

	portrait_rect.texture = unit.get_portrait()
	hover_info_panel.visible = true

	var display_name := ""
	if unit.class_data and unit.class_data.display_name:
		display_name = unit.class_data.display_name
	else:
		display_name = unit.team.capitalize()

	name_label.text = display_name.to_upper()
	hp_label.text = "HP  %d / %d" % [unit.current_hp, unit.max_hp]
	movement_hover_label.text = "MOV  %d / %d" % [unit.current_movement, unit.max_movement]
	ap_hover_label.text = "AP  %d / %d" % [unit.current_ap, unit.max_ap]
	attack_label.text = "ATK  %d  ·  %d AP" % [unit.attack_damage, unit.get_attack_ap_cost()]
	range_label.text = "RNG  %d" % unit.attack_range


func create_turn_order() -> void:
	for unit in units_container.get_children():
		var item = turn_order_item_scene.instantiate()
		turn_order_container.add_child(item)

		if item.has_method("setup"):
			item.setup(unit)

		_turn_order_items[unit] = item


func _highlight_turn_order(active_unit: UnitBase) -> void:
	for unit in _turn_order_items.keys():
		if not is_instance_valid(unit):
			continue

		var item = _turn_order_items[unit]

		if not is_instance_valid(item):
			continue

		if item.has_method("set_active"):
			item.set_active(unit == active_unit)


func _update_player_controls(unit: UnitBase) -> void:
	var is_player := unit.team == "player"
	_set_player_controls_enabled(is_player and not _battle_finished)

	if is_player:
		_default_hint = "Move, attack, then end turn."
		_restore_default_hint()
	else:
		hint_label.text = "Enemy is acting..."


func _set_player_controls_enabled(enabled: bool) -> void:
	move_button.disabled = not enabled
	attack_button.disabled = not enabled
	end_turn_button.disabled = not enabled
	action_panel.modulate.a = 1.0 if enabled else 0.45


func _style_action_buttons(mode: SelectionState.ActionMode) -> void:

	_reset_button_style(move_button)
	_reset_button_style(attack_button)
	_reset_button_style(end_turn_button)

	match mode:
		SelectionState.ActionMode.MOVE:
			_highlight_button(move_button)
		SelectionState.ActionMode.ATTACK:
			_highlight_button(attack_button)


func _highlight_button(button: Button) -> void:
	button.add_theme_color_override("font_color", COLOR_MODE_ON)


func _reset_button_style(button: Button) -> void:
	button.add_theme_color_override("font_color", COLOR_MODE_OFF)


func show_damage_popup(unit: UnitBase, amount: int) -> void:
	var popup = damage_popup_scene.instantiate()
	damage_popup_container.add_child(popup)

	var screen_position = camera.unproject_position(
		unit.global_position + Vector3.UP * (unit.get_visual_top_y() + 0.25)
	)

	popup.position = Vector2(screen_position.x - 20, screen_position.y - 40)

	var label: Label = popup.get_node("Label")
	label.text = "-" + str(amount)

	var tween = create_tween()
	tween.tween_property(popup, "position", popup.position + Vector2(0, -40), 0.5)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.5)
	tween.finished.connect(popup.queue_free)
