class_name UnitDetailsPanel
extends PanelContainer

## Full-screen details panel showing complete unit stat breakdown.

@onready var portrait_rect: TextureRect = %Portrait
@onready var name_label: Label = %NameLabel
@onready var class_label: Label = %ClassLabel
@onready var hp_label: Label = %HPLabel
@onready var hp_bar: ProgressBar = %HPBar
@onready var hp_breakdown_label: RichTextLabel = %HPBreakdown
@onready var def_header: Label = %DEFHeaderLabel
@onready var def_breakdown_label: RichTextLabel = %DEFBreakdown
@onready var atk_header: Label = %ATKHeaderLabel
@onready var atk_breakdown_label: RichTextLabel = %ATKBreakdown
@onready var mov_header: Label = %MOVHeaderLabel
@onready var mov_breakdown_label: RichTextLabel = %MOVBreakdown
@onready var ap_header: Label = %APHeaderLabel
@onready var ap_breakdown_label: RichTextLabel = %APBreakdown
@onready var rng_header: Label = %RNGHeaderLabel
@onready var rng_header_container: HBoxContainer = %RNGHeader
@onready var rng_breakdown_label: RichTextLabel = %RNGBreakdown
@onready var sep_after_ap: HSeparator = %SepAfterAP
@onready var sep_after_rng: HSeparator = %SepAfterRNG
@onready var weapon_label: Label = %WeaponLabel
@onready var effects_container: HFlowContainer = %EffectsContainer
@onready var close_button: Button = %CloseButton
@onready var team_indicator: TextureRect = %TeamIndicator
@onready var passives_container: VBoxContainer = %PassivesContainer
@onready var scroll_container: ScrollContainer = %ScrollContainer

const COLOR_HP_HIGH := Color(0.3, 0.9, 0.4, 1.0)
const COLOR_HP_MID := Color(0.9, 0.8, 0.3, 1.0)
const COLOR_HP_LOW := Color(1.0, 0.3, 0.2, 1.0)
const COLOR_BUFF := Color(0.4, 1.0, 0.5, 1.0)
const COLOR_DEBUFF := Color(1.0, 0.4, 0.35, 1.0)

var _current_unit: UnitBase = null


func _ready() -> void:
	hide()
	close_button.pressed.connect(_on_close_pressed)
	
	# Auto-close when player changes action mode (Move, Attack, Skill)
	var sel_state := get_node_or_null("/root/BattleScene/BattleSession/SelectionState") as Node
	if sel_state and sel_state.has_signal("action_mode_changed"):
		sel_state.action_mode_changed.connect(func(_mode): hide())
	
	# Auto-close when an action is executed (move or attack)
	var battle_flow := get_node_or_null("/root/BattleScene/BattleSession/BattleFlow") as BattleFlow
	if battle_flow:
		if battle_flow.has_signal("move_executed"):
			battle_flow.move_executed.connect(func(_unit, _tile): hide())
		if battle_flow.has_signal("attack_executed"):
			battle_flow.attack_executed.connect(func(_attacker, _target): hide())


func show_for_unit(unit: UnitBase) -> void:
	if not unit:
		hide()
		return
	
	_current_unit = unit
	_refresh_all()
	show()
	# Reset scroll to top
	scroll_container.scroll_vertical = 0


func _refresh_all() -> void:
	var unit := _current_unit
	if not unit:
		return
	
	# Portrait
	portrait_rect.texture = unit.get_portrait()
	
	# Name & class
	var display_name := ""
	if unit.class_data and unit.class_data.display_name:
		display_name = unit.class_data.display_name
	else:
		display_name = unit.team_id.capitalize()
	name_label.text = display_name.to_upper()
	
	var cls_name := unit.class_data.class_id.capitalize() if unit.class_data else ""
	class_label.text = cls_name
	
	# Team indicator
	if unit.team_data:
		team_indicator.modulate = unit.team_data.hp_bar_full_color
	team_indicator.visible = true
	
	# Passives section
	_refresh_passives(unit)
	
	# HP
	var hp_b := unit.get_hp_breakdown()
	var total_hp := 0
	for m in hp_b:
		if m is StatModifier:
			total_hp = m.total_value
	hp_label.text = "%d / %d" % [unit.current_hp, total_hp]
	hp_bar.max_value = maxi(1, total_hp)
	hp_bar.value = maxi(0, unit.current_hp)
	var hp_ratio := float(unit.current_hp) / float(maxi(1, total_hp))
	if hp_ratio > 0.5:
		hp_bar.modulate = COLOR_HP_HIGH
	elif hp_ratio > 0.25:
		hp_bar.modulate = COLOR_HP_MID
	else:
		hp_bar.modulate = COLOR_HP_LOW
	hp_breakdown_label.text = _build_breakdown_text(hp_b)
	
	# DEF
	var def_b := unit.get_defense_breakdown()
	_set_stat_label_with_breakdown(def_header, def_breakdown_label, def_b)
	
	# ATK
	var atk_b := unit.get_attack_power_breakdown()
	_set_stat_label_with_breakdown(atk_header, atk_breakdown_label, atk_b)
	
	# MOV
	var mov_b := unit.get_movement_breakdown()
	_set_stat_label_with_breakdown(mov_header, mov_breakdown_label, mov_b)
	
	# AP
	var ap_b := unit.get_ap_breakdown()
	_set_stat_label_with_breakdown(ap_header, ap_breakdown_label, ap_b)
	
	# RNG — only show if modified by effects/passives (range is weapon-dependent)
	var rng_mod := unit.get_effect_modifier("range")
	var has_rng_mod := rng_mod != 0
	if has_rng_mod:
		var rng_b := unit.get_range_breakdown()
		rng_header_container.show()
		rng_breakdown_label.show()
		sep_after_ap.show()
		sep_after_rng.show()
		_set_stat_label_with_breakdown(rng_header, rng_breakdown_label, rng_b)
	else:
		rng_header_container.hide()
		rng_breakdown_label.hide()
		sep_after_ap.hide()
		sep_after_rng.hide()
	
	# Weapon info
	var weapon := unit.get_active_weapon()
	if weapon:
		var slot_name := "PRIMARY" if unit.active_weapon_slot == "primary" else "SEC."
		weapon_label.text = "%s  %s  ·  %d DMG  ·  %d AP  ·  RNG %d" % [
			slot_name, weapon.weapon_name,
			unit.get_total_attack_power(), unit.get_attack_ap_cost(),
			unit.get_effective_range()
		]
	else:
		weapon_label.text = "No weapon"
	
	# Effects
	_refresh_effect_icons(unit)


func _refresh_passives(unit: UnitBase) -> void:
	# Clear old entries
	for child in passives_container.get_children():
		child.queue_free()
	
	if not unit.class_data or unit.class_data.passives.is_empty():
		var empty_label := Label.new()
		empty_label.text = "None"
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 1))
		empty_label.add_theme_font_size_override("font_size", 11)
		passives_container.add_child(empty_label)
		return
	
	for p: PassiveEffect in unit.class_data.passives:
		var container := HBoxContainer.new()
		container.add_theme_constant_override("separation", 6)
		
		var name_lbl := Label.new()
		name_lbl.text = p.display_name
		name_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 1))
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.custom_minimum_size = Vector2(100, 0)
		container.add_child(name_lbl)
		
		var desc_lbl := Label.new()
		desc_lbl.text = p.description
		desc_lbl.add_theme_color_override("font_color", Color(0.55, 0.65, 0.78, 1))
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.size_flags_horizontal = 3
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		container.add_child(desc_lbl)
		
		# Add effect indicator
		var effect_lbl := Label.new()
		var effect_text := ""
		match p.passive_type:
			PassiveEffect.PassiveType.FLAT_STAT_BONUS:
				effect_text = "+%d %s" % [p.stat_value, p.stat_name.to_upper()]
			PassiveEffect.PassiveType.CONDITIONAL_BONUS:
				effect_text = "+%d %s (conditional)" % [p.stat_value, p.stat_name.to_upper()]
			PassiveEffect.PassiveType.RESISTANCE:
				effect_text = "Resistance"
			PassiveEffect.PassiveType.ON_KILL:
				effect_text = "On Kill"
			PassiveEffect.PassiveType.AOE_ON_DAMAGE:
				effect_text = "AoE on Damage"
			PassiveEffect.PassiveType.ON_ACTION:
				effect_text = "On Action"
		effect_lbl.text = effect_text
		effect_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5, 1))
		effect_lbl.add_theme_font_size_override("font_size", 10)
		effect_lbl.custom_minimum_size = Vector2(80, 0)
		effect_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		container.add_child(effect_lbl)
		
		passives_container.add_child(container)


func _set_stat_label_with_breakdown(header: Label, breakdown_label: RichTextLabel, breakdown: Array) -> void:
	if breakdown.is_empty():
		breakdown_label.text = ""
		return
	
	var total := 0
	var mod := 0
	for m in breakdown:
		if m is StatModifier:
			total = m.total_value
			mod += m.modifier_value
	
	if mod > 0:
		header.add_theme_color_override("font_color", COLOR_BUFF)
	elif mod < 0:
		header.add_theme_color_override("font_color", COLOR_DEBUFF)
	else:
		header.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 1))
	
	# Extract stat name from current header text (e.g., "DEF" from "DEF 12")
	var stat_name := header.text.split("  ")[0]
	header.text = "%s  %d" % [stat_name, total]
	breakdown_label.text = _build_breakdown_text(breakdown)


func _build_breakdown_text(breakdown: Array) -> String:
	var lines: Array[String] = []
	var total := 0
	var base_total := 0
	var has_conditional := false
	for m in breakdown:
		if m is StatModifier:
			var label: String
			if m.modifier_value > 0:
				label = "[color=#66ff80] %s%d  %s[/color]" % ["+", m.modifier_value, m.source_name]
			elif m.modifier_value < 0:
				label = "[color=#ff6658] %d  %s[/color]" % [m.modifier_value, m.source_name]
			else:
				label = "[color=#b3bccd]  %d  %s[/color]" % [m.base_value, m.source_name]
			lines.append(label)
			total = m.total_value
			if "Conditional" in m.source_name or "conditional" in m.source_name:
				has_conditional = true
			if not has_conditional:
				base_total = total
	var sep_color := "#5a6a80"
	if has_conditional:
		lines.append("[color=%s]  ─────[/color]" % sep_color)
		lines.append("[color=%s]  %d  Total (base)[/color]" % [sep_color, base_total])
		lines.append("[color=%s]  %d  Total (conditional)[/color]" % [sep_color, total])
	else:
		lines.append("[color=%s]  ─────[/color]" % sep_color)
		lines.append("[color=%s]  %d  Total[/color]" % [sep_color, total])
	return "\n".join(lines)


func _refresh_effect_icons(unit: UnitBase) -> void:
	for child in effects_container.get_children():
		child.queue_free()
	
	if unit.active_effects.is_empty():
		return
	
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
	
	for e: ActiveStatusEffect in buffs:
		_add_effect_icon(e, true)
	for e: ActiveStatusEffect in debuffs:
		_add_effect_icon(e, false)


func _add_effect_icon(e: ActiveStatusEffect, is_buff: bool) -> void:
	var container := VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 2)
	
	var tex_rect := TextureRect.new()
	tex_rect.texture = e.effect.get_icon()
	tex_rect.custom_minimum_size = Vector2(28, 28)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.tooltip_text = "%s\n%s" % [e.effect.display_name, e.effect.description]
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.add_child(tex_rect)
	
	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 9)
	if is_buff:
		name_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4, 1))
	else:
		name_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2, 1))
	name_label.text = e.effect.display_name
	container.add_child(name_label)
	
	var dur_label := Label.new()
	dur_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dur_label.add_theme_font_size_override("font_size", 10)
	dur_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4, 1))
	if e.effect.duration == -1:
		dur_label.text = "∞"
	else:
		dur_label.text = str(e.turns_remaining)
	container.add_child(dur_label)
	
	effects_container.add_child(container)


func _on_close_pressed() -> void:
	hide()