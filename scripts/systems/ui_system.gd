class_name UISystem
extends Node

@export var unit_hp_bar_scene: PackedScene
@export var turn_order_item_scene: PackedScene
@export var damage_popup_scene: PackedScene

@onready var systems = %Systems
@onready var world = %World

@onready var selection_manager := (
	systems.get_node("SelectionManager")
	as SelectionManager
)

@onready var units_container = (
	world.get_node("Units")
)

@onready var camera_rig = (
	world.get_node("CameraRig")
)

@onready var camera: Camera3D = (
	camera_rig.get_node("CameraPitch/Camera3D")
)

@onready var action_label = %ActionLabel
@onready var unit_ui_container = %UnitUIContainer

@onready var hover_info_panel = %HoverInfoPanel

@onready var portrait_rect = %Portrait
@onready var name_label = %NameLabel
@onready var hp_label = %HPLabel
@onready var attack_label = %AttackLabel
@onready var range_label = %RangeLabel

@onready var turn_order_container = (
	%HBoxContainer
)

@onready var damage_popup_container = (
	%DamagePopupContainer
)

var hp_bars := {}

func _ready():

	selection_manager.action_mode_changed.connect(
		_on_action_mode_changed
	)

	selection_manager.hovered_unit_changed.connect(
		_on_hovered_unit_changed
	)

	update_action_label(
		selection_manager.current_action_mode
	)

	await get_tree().process_frame

	create_hp_bars()

	create_turn_order()

func _process(_delta):

	update_hp_bars()

func _on_action_mode_changed(mode):

	update_action_label(mode)

func update_action_label(mode):

	var mode_text = "NONE"

	if mode == selection_manager.ActionMode.MOVE:
		mode_text = "MOVE"

	elif mode == selection_manager.ActionMode.ATTACK:
		mode_text = "ATTACK"

	action_label.text = (
		"Mode: " + mode_text
	)

func create_hp_bars():

	for unit in units_container.get_children():

		var hp_bar = (
			unit_hp_bar_scene.instantiate()
		)

		unit_ui_container.add_child(hp_bar)

		hp_bars[unit] = hp_bar

func update_hp_bars():

	for unit in hp_bars.keys():

		if not is_instance_valid(unit):
			continue

		var hp_bar = hp_bars[unit]

		var screen_position = (
			camera.unproject_position(
				unit.global_position
				+
				Vector3.UP * 2.5
			)
		)

		hp_bar.global_position = (
			screen_position
			-
			Vector2(30, -15)
		)

		var progress_bar = (
			hp_bar.get_node("HPBar")
		)

		progress_bar.max_value = unit.max_hp
		progress_bar.value = unit.hp

func _on_hovered_unit_changed(unit):
	if not unit:
		hover_info_panel.visible = false
		return

	portrait_rect.texture = unit.portrait

	hover_info_panel.visible = true
	name_label.text = unit.team_id.to_upper()

	hp_label.text = (
		"HP: "
		+ str(unit.hp)
		+ "/"
		+ str(unit.max_hp)
	)

	attack_label.text = (
		"ATK: "
		+ str(unit.attack_damage)
	)

	range_label.text = (
		"RANGE: "
		+ str(unit.attack_range)
	)

func create_turn_order():

	for unit in units_container.get_children():

		var item = (
			turn_order_item_scene.instantiate()
		)

		turn_order_container.add_child(item)

		var label = item.get_node("Label")

		if unit.team_id == "player":
			label.text = "P"
		else:
			label.text = "E"

func show_damage_popup(unit, amount):
	print("POPUP FUNCIONOU")
	var popup = (
		damage_popup_scene.instantiate()
	)

	damage_popup_container.add_child(popup)

	var screen_position = (
		camera.unproject_position(
			unit.global_position
			+
			Vector3.UP * 3.0
		)
	)

	popup.position = Vector2(
		screen_position.x - 20,
		screen_position.y - 40
	)

	var label = popup.get_node("Label")

	label.text = "-" + str(amount)

	var tween = create_tween()

	tween.tween_property(
		popup,
		"position",
		popup.position + Vector2(0, -40),
		0.5
	)

	tween.parallel().tween_property(
		popup,
		"modulate:a",
		0.0,
		0.5
	)

	tween.finished.connect(
		popup.queue_free
	)
