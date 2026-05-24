class_name ActionSubmenuUI
extends Node

## Manages the unified action submenu (weapon attacks + skills).

var action_submenu = null
var action_submenu_container = null
var selection_state: SelectionState = null
var battle_hud: BattleHud = null


func setup(p_submenu, p_container, p_selection: SelectionState, p_hud: BattleHud) -> void:
	action_submenu = p_submenu
	action_submenu_container = p_container
	selection_state = p_selection
	battle_hud = p_hud

	if action_submenu:
		action_submenu.visibility_changed.connect(_on_visibility_changed)


func is_visible() -> bool:
	return action_submenu and action_submenu.visible


func toggle(display_unit: UnitBase) -> void:
	if not display_unit:
		return
	if action_submenu and action_submenu.visible:
		action_submenu.visible = false
		return
	populate_actions(display_unit)
	if action_submenu:
		action_submenu.visible = true


func hide() -> void:
	if action_submenu:
		action_submenu.visible = false


## Populates the submenu with weapon attacks and class skills as unified actions.
func populate_actions(display_unit: UnitBase) -> void:
	if not action_submenu_container:
		return

	for child in action_submenu_container.get_children():
		child.queue_free()

	if not display_unit:
		return

	var actions: Array[SkillData] = []

	# Get weapon attacks
	if display_unit.equipment:
		actions.append_array(display_unit.equipment.get_all_weapon_attacks_as_skills())

	# Get class skills
	if display_unit.class_data:
		for skill: SkillData in display_unit.class_data.skills:
			if skill.ap_cost <= display_unit.current_ap:
				actions.append(skill)

	if actions.is_empty():
		var label := Label.new()
		label.text = "No actions available"
		label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68, 1))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		action_submenu_container.add_child(label)
		return

	for action in actions:
		_add_action_button(action)


func _add_action_button(action: SkillData) -> void:
	var btn := Button.new()
	
	# Determine if this is a weapon attack (for display purposes)
	var is_weapon_attack := action.skill_id.begins_with("weapon_attack_")
	
	if is_weapon_attack:
		btn.text = "%s\nDMG %d  ·  RNG %d  ·  %d AP" % [
			action.skill_name,
			action.effects[0].amount if action.effects.size() > 0 else 0,
			action.skill_range,
			action.ap_cost
		]
	else:
		btn.text = "%s\n%s  ·  %d AP  ·  RNG %d" % [
			action.skill_name, action.description, action.ap_cost, action.skill_range
		]
	
	btn.custom_minimum_size = Vector2(0, 56)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.94)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	
	if is_weapon_attack:
		style.border_color = Color(0.45, 0.75, 1.0, 1.0)
	else:
		style.border_color = Color(0.75, 0.55, 1.0, 1.0)
	
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	btn.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate()
	hover_style.border_color = Color(0.85, 0.85, 1.0, 1.0)
	hover_style.bg_color = Color(0.12, 0.15, 0.2, 0.94)
	btn.add_theme_stylebox_override("hover", hover_style)

	btn.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 1))
	btn.add_theme_font_size_override("font_size", 12)

	btn.pressed.connect(func():
		_on_action_selected(action)
	)

	action_submenu_container.add_child(btn)
	# Move weapon attacks to the top
	if is_weapon_attack:
		action_submenu_container.move_child(btn, 0)


func _on_action_selected(action: SkillData) -> void:
	if battle_hud:
		battle_hud._enter_action_mode(action)
	hide()


func _on_visibility_changed() -> void:
	if action_submenu and not action_submenu.visible and action_submenu_container:
		for child in action_submenu_container.get_children():
			child.queue_free()