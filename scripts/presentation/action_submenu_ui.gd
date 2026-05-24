class_name ActionSubmenuUI
extends Node

## Manages the weapon and skill action submenu.

var action_submenu = null
var action_submenu_container = null
var selection_state: SelectionState = null
var battle_hud: BattleHud = null  # Referência para callback


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
	populate_weapons(display_unit)
	populate_skills(display_unit)
	if action_submenu:
		action_submenu.visible = true


func hide() -> void:
	if action_submenu:
		action_submenu.visible = false


func populate_weapons(display_unit: UnitBase) -> void:
	if not action_submenu_container:
		return

	for child in action_submenu_container.get_children():
		child.queue_free()

	if not display_unit:
		return

	var weapons_added := false

	if display_unit.primary_weapon:
		weapons_added = true
		_add_weapon_button(display_unit, display_unit.primary_weapon, "PRIMARY",
			display_unit.active_weapon_slot == "primary")

	if display_unit.secondary_weapon:
		weapons_added = true
		_add_weapon_button(display_unit, display_unit.secondary_weapon, "SEC.",
			display_unit.active_weapon_slot == "secondary")

	if not weapons_added:
		var label := Label.new()
		label.text = "No weapons"
		label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68, 1))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		action_submenu_container.add_child(label)


func _add_weapon_button(display_unit: UnitBase, weapon: WeaponData, slot_name: String, is_active: bool) -> void:
	var btn := Button.new()
	btn.text = "%s  ·  %s\nDMG %d  RNG %d  %d AP" % [
		slot_name, weapon.weapon_name,
		weapon.weapon_power, weapon.weapon_range, weapon.attack_ap_cost
	]
	btn.custom_minimum_size = Vector2(0, 56)

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

	btn.pressed.connect(func():
		_on_weapon_selected(display_unit, weapon, is_active)
	)

	action_submenu_container.add_child(btn)
	action_submenu_container.move_child(btn, 0)


func _on_weapon_selected(display_unit: UnitBase, weapon: WeaponData, is_active: bool) -> void:
	if not is_active:
		display_unit.switch_weapon()
		if battle_hud:
			battle_hud.update_resource_display(display_unit)
	if selection_state:
		selection_state.set_action_mode(SelectionState.ActionMode.ATTACK)
	hide()


func populate_skills(display_unit: UnitBase) -> void:
	if not display_unit or not display_unit.class_data or not action_submenu_container:
		return
	for skill: SkillData in display_unit.class_data.skills:
		if skill.ap_cost > display_unit.current_ap:
			continue
		_add_skill_button(skill)


func _add_skill_button(skill: SkillData) -> void:
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
		_on_skill_selected(skill)
	)

	action_submenu_container.add_child(btn)


func _on_skill_selected(skill: SkillData) -> void:
	if battle_hud:
		battle_hud._enter_skill_mode(skill)
	hide()


func _on_visibility_changed() -> void:
	if action_submenu and not action_submenu.visible and action_submenu_container:
		for child in action_submenu_container.get_children():
			child.queue_free()