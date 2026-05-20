class_name BattleHud
extends Node

@export var unit_hp_bar_scene: PackedScene
@export var turn_order_item_scene: PackedScene
@export var damage_popup_scene: PackedScene

@onready var selection_state: SelectionState = %SelectionState
@onready var turn_controller: TurnController = %TurnController
@onready var units_container: Node3D = %Units
@onready var turn_announce: TurnAnnounce = %TurnAnnounce
@onready var audio_manager: AudioManager = %AudioManager

@onready var camera: Camera3D = (
	%World.get_node("CameraRig/CameraPitch/Camera3D")
)

@onready var action_panel: PanelContainer = %ActionPanel
@onready var hint_label: Label = %HintLabel
@onready var movement_label: Label = %MovementLabel
@onready var ap_label: Label = %APLabel
@onready var move_button: Button = %MoveButton
@onready var action_button: Button = %ActionButton
@onready var end_turn_button: Button = %EndTurnButton
@onready var action_submenu: PanelContainer = %ActionSubmenu
@onready var action_submenu_container: VBoxContainer = %ActionSubmenuContainer
@onready var unit_ui_container: Control = %UnitUIContainer
@onready var hover_info_panel: PanelContainer = %HoverInfoPanel
@onready var portrait_rect: TextureRect = %Portrait
@onready var name_label: Label = %NameLabel
@onready var hp_label: Label = %HPLabel
@onready var movement_hover_label: Label = %MovementHoverLabel
@onready var ap_hover_label: Label = %APHoverLabel
@onready var attack_label: Label = %AttackLabel
@onready var range_label: Label = %RangeLabel
@onready var effects_container: HFlowContainer = %EffectsContainer
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
var _default_hint := "Move, use actions, then end turn."
var _feedback_restore_timer: SceneTreeTimer = null
var _pending_skill: SkillData = null
var _action_name_popup: PanelContainer = null


func _ready() -> void:
	selection_state.action_mode_changed.connect(_on_action_mode_changed)
	selection_state.hovered_unit_changed.connect(_on_hovered_unit_changed)

	_style_action_buttons(selection_state.current_action_mode)
	hint_label.add_theme_color_override("font_color", COLOR_HINT_NORMAL)

	action_button.pressed.connect(_on_action_button_pressed)
	action_submenu.visibility_changed.connect(_on_submenu_visibility_changed)

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

	if _display_unit and _display_unit.team_id == "player":
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

	if audio_manager:
		audio_manager.play_turn_start()

	await turn_announce.play_for_unit(unit)


func _on_action_mode_changed(mode: SelectionState.ActionMode) -> void:
	_style_action_buttons(mode)
	_close_submenu()
	if mode != SelectionState.ActionMode.SKILL:
		_pending_skill = null

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
		var hp_bar = unit_hp_bar_scene.instantiate()
		var visual = unit.get_node("UnitVisual")
		visual.add_child(hp_bar)
		hp_bar.position = Vector3(0, 2.5, 0)
		
		# Apply team colors
		if unit.team_data:
			hp_bar.set_colors(unit.team_data.hp_bar_full_color, unit.team_data.hp_bar_empty_color)
		
		hp_bars[unit] = hp_bar


func update_hp_bars() -> void:
	for unit in hp_bars.keys():
		if not is_instance_valid(unit):
			continue
		if unit.max_hp <= 0:
			continue
		var hp_bar = hp_bars[unit]
		hp_bar.set_hp(unit.current_hp, unit.max_hp)


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
		display_name = unit.team_id.capitalize()

	name_label.text = display_name.to_upper()
	hp_label.text = "HP  %d / %d" % [unit.current_hp, unit.max_hp]
	movement_hover_label.text = "MOV  %d / %d" % [unit.current_movement, unit.max_movement]
	ap_hover_label.text = "AP  %d / %d" % [unit.current_ap, unit.max_ap]
	
	var weapon := unit.get_active_weapon()
	if weapon:
		attack_label.text = "%s  ·  %d DMG  ·  %d AP" % [weapon.weapon_name, unit.get_total_attack_power(), unit.get_attack_ap_cost()]
		range_label.text = "RNG  %d" % unit.get_effective_range()
	else:
		attack_label.text = "ATK  %d  ·  %d AP" % [unit.get_total_attack_power(), unit.get_attack_ap_cost()]
		range_label.text = "RNG  %d" % unit.get_effective_range()

	# Display buff/debuff icons
	_refresh_effect_icons(unit)


func _refresh_effect_icons(unit: UnitBase) -> void:
	# Clear old icons
	for child in effects_container.get_children():
		child.queue_free()
	if unit.active_effects.is_empty():
		return
	# Separate buffs and debuffs
	var buffs: Array[ActiveStatusEffect] = []
	var debuffs: Array[ActiveStatusEffect] = []
	for e: ActiveStatusEffect in unit.active_effects:
		var is_buff := true
		for stat: String in e.effect.modifiers:
			if e.effect.modifiers[stat] < 0:
				is_buff = false
				break
		if is_buff:
			buffs.append(e)
		else:
			debuffs.append(e)
	# Show buffs first, then debuffs
	for e: ActiveStatusEffect in buffs:
		_add_effect_icon(e)
	for e: ActiveStatusEffect in debuffs:
		_add_effect_icon(e)


func _add_effect_icon(e: ActiveStatusEffect) -> void:
	# Container for icon + duration label
	var container := VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 2)
	
	# Icon — larger and sharp (no filter)
	var tex_rect := TextureRect.new()
	tex_rect.texture = e.effect.get_icon()
	tex_rect.custom_minimum_size = Vector2(32, 32)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.tooltip_text = "%s\n%s" % [e.effect.display_name, e.effect.description]
	# Disable texture filtering for crisp pixel art
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.add_child(tex_rect)
	
	# Duration label (bottom-left of icon)
	var dur_label := Label.new()
	dur_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dur_label.add_theme_font_size_override("font_size", 10)
	dur_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4, 1))
	if e.effect.duration == -1:
		dur_label.text = "∞"
	else:
		dur_label.text = str(e.turns_remaining)
	container.add_child(dur_label)
	
	# Pop animation: scale up then bounce back
	container.scale = Vector2(0.1, 0.1)
	var pop_tween := create_tween()
	pop_tween.set_trans(Tween.TRANS_BACK)
	pop_tween.set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(container, "scale", Vector2(1, 1), 0.25)
	
	effects_container.add_child(container)


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
	var is_player := unit.is_player_team()
	_set_player_controls_enabled(is_player and not _battle_finished)

	if is_player:
		_default_hint = "Move, use actions, then end turn."
		_restore_default_hint()
	else:
		hint_label.text = "Enemy is acting..."


func _set_player_controls_enabled(enabled: bool) -> void:
	move_button.disabled = not enabled
	action_button.disabled = not enabled
	end_turn_button.disabled = not enabled
	if not enabled:
		_close_submenu()
	action_panel.modulate.a = 1.0 if enabled else 0.45


func _style_action_buttons(mode: SelectionState.ActionMode) -> void:
	_reset_button_style(move_button)
	_reset_button_style(action_button)
	_reset_button_style(end_turn_button)

	match mode:
		SelectionState.ActionMode.MOVE:
			_highlight_button(move_button)
		SelectionState.ActionMode.ATTACK:
			_highlight_button(action_button)


func _highlight_button(button: Button) -> void:
	button.add_theme_color_override("font_color", COLOR_MODE_ON)


func _reset_button_style(button: Button) -> void:
	button.add_theme_color_override("font_color", COLOR_MODE_OFF)


func _on_action_button_pressed() -> void:
	if not _display_unit:
		return
	
	if action_submenu.visible:
		_close_submenu()
		return
	
	# Build weapon + skill action list for the current unit
	_populate_weapon_actions()
	_populate_skill_actions()
	action_submenu.visible = true


func _populate_weapon_actions() -> void:
	# Clear existing items
	for child in action_submenu_container.get_children():
		child.queue_free()
	
	if not _display_unit:
		return
	
	var weapons_added := false
	
	# Primary weapon action
	if _display_unit.primary_weapon:
		weapons_added = true
		_add_weapon_action_button(
			_display_unit.primary_weapon,
			"PRIMARY",
			_display_unit.active_weapon_slot == "primary"
		)
	
	# Secondary weapon action
	if _display_unit.secondary_weapon:
		weapons_added = true
		_add_weapon_action_button(
			_display_unit.secondary_weapon,
			"SEC.",
			_display_unit.active_weapon_slot == "secondary"
		)
	
	if not weapons_added:
		var label := Label.new()
		label.text = "No weapons"
		label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68, 1))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		action_submenu_container.add_child(label)


func _add_weapon_action_button(weapon: WeaponData, slot_name: String, is_active: bool) -> void:
	var btn := Button.new()
	btn.text = "%s  ·  %s\nDMG %d  RNG %d  %d AP" % [
		slot_name, weapon.weapon_name,
		weapon.weapon_power, weapon.weapon_range, weapon.attack_ap_cost
	]
	btn.custom_minimum_size = Vector2(0, 56)
	
	# Style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.94)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.45, 0.75, 1.0, 1.0) if is_active else Color(0.28, 0.38, 0.52, 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style := style.duplicate()
	hover_style.border_color = Color(0.55, 0.85, 1.0, 1.0)
	hover_style.bg_color = Color(0.12, 0.15, 0.2, 0.94)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	btn.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 1))
	btn.add_theme_font_size_override("font_size", 12)
	
	# If it's the active weapon, clicking sets ATTACK mode directly
	# If it's inactive, clicking switches to that weapon first
	if is_active:
		btn.pressed.connect(func():
			selection_state.set_action_mode(SelectionState.ActionMode.ATTACK)
			_close_submenu()
		)
	else:
		btn.pressed.connect(func():
			_display_unit.switch_weapon()
			update_resource_display(_display_unit)
			selection_state.set_action_mode(SelectionState.ActionMode.ATTACK)
			_close_submenu()
		)
	
	action_submenu_container.add_child(btn)
	action_submenu_container.move_child(btn, 0)


func _populate_skill_actions() -> void:
	if not _display_unit or not _display_unit.class_data:
		return
	for skill: SkillData in _display_unit.class_data.skills:
		if skill.ap_cost > _display_unit.current_ap:
			continue
		_add_skill_action_button(skill)


func _add_skill_action_button(skill: SkillData) -> void:
	var btn := Button.new()
	btn.text = "%s\n%s  ·  %d AP  ·  RNG %d" % [
		skill.skill_name, skill.description, skill.ap_cost, skill.skill_range
	]
	btn.custom_minimum_size = Vector2(0, 56)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.94)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.75, 0.55, 1.0, 1.0)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style := style.duplicate()
	hover_style.border_color = Color(0.85, 0.65, 1.0, 1.0)
	hover_style.bg_color = Color(0.12, 0.15, 0.2, 0.94)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	btn.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 1))
	btn.add_theme_font_size_override("font_size", 12)
	
	btn.pressed.connect(func():
		_enter_skill_mode(skill)
		_close_submenu()
	)
	
	action_submenu_container.add_child(btn)


## Enters skill targeting mode — the next click on a valid target will execute the skill.
func _enter_skill_mode(skill: SkillData) -> void:
	_pending_skill = skill
	selection_state.set_action_mode(SelectionState.ActionMode.SKILL)


## Executes the pending skill on the given target.
func _execute_skill_on_target(target_unit: UnitBase, target_tile: HexTile = null) -> void:
	if not _pending_skill:
		return
	var scene_root: Node = _display_unit.get_tree().current_scene
	var executor: SkillExecutor = scene_root.get_node("BattleSession/SkillExecutor")
	var ctx := SkillContext.new(_display_unit, _pending_skill, target_unit, target_tile)
	if executor.execute(ctx):
		_display_unit.spend_ap(_pending_skill.ap_cost)
		update_resource_display(_display_unit)
	_pending_skill = null


func _close_submenu() -> void:
	action_submenu.visible = false


func _on_submenu_visibility_changed() -> void:
	if not action_submenu.visible:
		# Clear children when hidden to keep it fresh
		for child in action_submenu_container.get_children():
			child.queue_free()


## Shows a centered action name banner at the top of the screen.
func show_action_name_popup(action_name: String, duration := 1.2) -> void:
	# Remove existing popup if any
	if _action_name_popup and is_instance_valid(_action_name_popup):
		_action_name_popup.queue_free()
		_action_name_popup = null
	
	# Create panel
	var panel := PanelContainer.new()
	_action_name_popup = panel
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.1, 0.85)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.55, 0.75, 1.0, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	
	var label := Label.new()
	label.text = action_name
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	
	# Add to tree, position at top center
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 10
	add_child(canvas_layer)
	canvas_layer.add_child(panel)
	
	# Position at top center of screen
	var screen_size := get_viewport().get_visible_rect().size
	panel.position = Vector2(screen_size.x / 2 - panel.size.x / 2, 40)
	
	# Animate: fade in, hold, fade out
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.15)
	tween.tween_interval(duration - 0.3)
	tween.tween_property(panel, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		if is_instance_valid(panel):
			panel.queue_free()
		_action_name_popup = null
	)


## Shows a floating damage/heal/buff popup above a unit.
## popup_type: "damage" (red), "heal" (green), "buff" (yellow)
func show_damage_popup(unit: UnitBase, amount: int, popup_type: String = "damage") -> void:
	var popup = damage_popup_scene.instantiate()
	damage_popup_container.add_child(popup)

	var screen_position = camera.unproject_position(
		unit.global_position + Vector3.UP * (unit.get_visual_top_y() + 0.25)
	)

	popup.position = Vector2(screen_position.x - 20, screen_position.y - 40)

	var label: Label = popup.get_node("Label")
	
	# Set text and color based on popup type
	match popup_type:
		"heal":
			label.text = "+" + str(amount)
			label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4, 1.0))
		"buff":
			label.text = "+" + str(amount)
			label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
		"debuff":
			label.text = str(amount)
			label.add_theme_color_override("font_color", Color(0.8, 0.3, 1.0, 1.0))
		_:  # damage
			label.text = "-" + str(amount)
			label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2, 1.0))

	var tween = create_tween()
	tween.tween_property(popup, "position", popup.position + Vector2(0, -40), 0.5)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.5)
	tween.finished.connect(popup.queue_free)
