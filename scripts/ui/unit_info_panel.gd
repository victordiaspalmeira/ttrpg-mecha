class_name UnitInfoPanel
extends PanelContainer

## Reusable panel that shows detailed unit info with stat breakdown.
## Supports both hover mode (temporary) and pinned mode (persistent).

@onready var portrait_rect: TextureRect = %Portrait
@onready var name_label: Label = %NameLabel
@onready var class_label: Label = %ClassLabel
@onready var hp_label: Label = %HPLabel
@onready var hp_bar: ProgressBar = %HPBar
@onready var def_label: Label = %DEFLabel
@onready var atk_label: Label = %ATKLabel
@onready var mov_label: Label = %MOVLabel
@onready var ap_label: Label = %APLabel
@onready var rng_label: Label = %RNGLabel
@onready var weapon_label: Label = %WeaponLabel
@onready var effects_container: HFlowContainer = %EffectsContainer
@onready var team_indicator: TextureRect = %TeamIndicator
@onready var details_button: Button = %DetailsButton

const COLOR_VALUE_NEUTRAL := Color(0.85, 0.9, 0.95, 1.0)
const COLOR_BUFF := Color(0.4, 1.0, 0.5, 1.0)
const COLOR_DEBUFF := Color(1.0, 0.4, 0.35, 1.0)
const COLOR_HP_HIGH := Color(0.3, 0.9, 0.4, 1.0)
const COLOR_HP_MID := Color(0.9, 0.8, 0.3, 1.0)
const COLOR_HP_LOW := Color(1.0, 0.3, 0.2, 1.0)

var _current_unit: UnitBase = null
var _is_pinned := false


func _ready() -> void:
	hide()
	details_button.pressed.connect(_on_details_pressed)


func _on_details_pressed() -> void:
	if not _current_unit or not is_instance_valid(_current_unit):
		return
	var scene_root := get_tree().current_scene
	var details_panel = scene_root.get_node_or_null("UI/CanvasLayer/UnitDetailsPanel")
	if details_panel and details_panel.has_method("show_for_unit"):
		details_panel.show_for_unit(_current_unit)


## Shows the panel with data from the given unit.
func show_for_unit(unit: UnitBase, pinned: bool = false) -> void:
	if not unit:
		hide()
		return
	
	_current_unit = unit
	_is_pinned = pinned
	
	_refresh_all()
	show()


## Refreshes all displayed stats from the current unit.
func refresh_current() -> void:
	if _current_unit and is_instance_valid(_current_unit):
		_refresh_all()
	else:
		hide()


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
	
	# Team indicator (simple colored rect)
	if unit.team_data:
		team_indicator.modulate = unit.team_data.hp_bar_full_color
	team_indicator.visible = true
	
	# HP
	var hp_breakdown := unit.get_hp_breakdown()
	var total_hp := 0
	for m in hp_breakdown:
		total_hp = m.total_value
	hp_label.text = "HP  %d / %d" % [unit.current_hp, total_hp]
	# HP bar
	hp_bar.max_value = maxi(1, total_hp)
	hp_bar.value = maxi(0, unit.current_hp)
	var hp_ratio := float(unit.current_hp) / float(maxi(1, total_hp))
	if hp_ratio > 0.5:
		hp_bar.modulate = COLOR_HP_HIGH
	elif hp_ratio > 0.25:
		hp_bar.modulate = COLOR_HP_MID
	else:
		hp_bar.modulate = COLOR_HP_LOW
	
	# DEF
	var def_breakdown := unit.get_defense_breakdown()
	var def_total := 0
	var def_mod := 0
	for m in def_breakdown:
		def_total = m.total_value
		def_mod += m.modifier_value
	_set_stat_label(def_label, "DEF", def_total, def_mod, def_breakdown)
	
	# ATK
	var atk_breakdown := unit.get_attack_power_breakdown()
	var atk_total := 0
	var atk_mod := 0
	for m in atk_breakdown:
		atk_total = m.total_value
		atk_mod += m.modifier_value
	var atk_nonbase_mod := atk_mod - (atk_breakdown[0].modifier_value if atk_breakdown.size() > 0 else 0)
	_set_stat_label(atk_label, "ATK", atk_total, atk_nonbase_mod, atk_breakdown)
	
	# MOV
	var mov_breakdown := unit.get_movement_breakdown()
	var mov_total := 0
	var mov_mod := 0
	for m in mov_breakdown:
		mov_total = m.total_value
		mov_mod += m.modifier_value
	_set_stat_label(mov_label, "MOV", mov_total, mov_mod, mov_breakdown)
	
	# AP
	var ap_breakdown := unit.get_ap_breakdown()
	var ap_total := 0
	var ap_mod := 0
	for m in ap_breakdown:
		ap_total = m.total_value
		ap_mod += m.modifier_value
	_set_stat_label(ap_label, "AP", ap_total, ap_mod, ap_breakdown)
	
	# RNG
	var rng_breakdown := unit.get_range_breakdown()
	var rng_total := 0
	var rng_mod := 0
	for m in rng_breakdown:
		rng_total = m.total_value
		rng_mod += m.modifier_value
	_set_stat_label(rng_label, "RNG", rng_total, rng_mod, rng_breakdown)
	
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
	
	# Effects (buffs/debuffs)
	_refresh_effect_icons(unit)


func _set_stat_label(label: Label, stat_name: String, total: int, modifier: int, breakdown: Array) -> void:
	label.text = "%s  %d" % [stat_name, total]
	
	if modifier > 0:
		label.add_theme_color_override("font_color", COLOR_BUFF)
	elif modifier < 0:
		label.add_theme_color_override("font_color", COLOR_DEBUFF)
	else:
		label.add_theme_color_override("font_color", COLOR_VALUE_NEUTRAL)
	
	label.tooltip_text = _build_breakdown_tooltip(breakdown)


func _build_breakdown_tooltip(breakdown: Array[StatModifier]) -> String:
	var lines: Array[String] = []
	for m: StatModifier in breakdown:
		lines.append(m.get_breakdown_text())
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
		_add_effect_icon(e)
	for e: ActiveStatusEffect in debuffs:
		_add_effect_icon(e)


func _add_effect_icon(e: ActiveStatusEffect) -> void:
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