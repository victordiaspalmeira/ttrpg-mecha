extends Node

## Visual test runner for unit tests.
## Open test_scene.tscn and click "Run All Tests".

@onready var result_list: VBoxContainer = %ResultList
@onready var summary_label: Label = %Summary
@onready var run_button: Button = %RunButton

var _total := 0
var _passed := 0
var _failed_msgs: Array[String] = []


func _ready() -> void:
	if run_button:
		run_button.pressed.connect(_run_all)


func _run_all() -> void:
	for child in result_list.get_children():
		child.queue_free()
	_total = 0
	_passed = 0
	_failed_msgs.clear()

	_add("header", "Running all tests...\n", Color(0.85, 0.9, 1.0))

	_run_group("UnitStats", [
		["creation", _test_stats_creation],
		["damage", _test_stats_damage],
		["heal", _test_stats_heal],
		["spend_ap", _test_stats_spend_ap],
		["spend_movement", _test_stats_spend_movement],
	])

	_run_group("UnitEffects", [
		["add", _test_effects_add],
		["remove", _test_effects_remove],
		["tick", _test_effects_tick],
		["modifier", _test_effects_modifier],
	])

	_run_group("UnitEquipment", [
		["creation", _test_equipment_creation],
		["switch", _test_equipment_switch],
		["tags", _test_equipment_tags],
	])

	var color := Color(0.3, 1.0, 0.4) if _passed == _total else Color(1.0, 0.4, 0.3)
	var text := "%d/%d passed" % [_passed, _total]
	if _passed < _total:
		text = "%d/%d passed — %d FAILED" % [_passed, _total, _total - _passed]
		for msg in _failed_msgs:
			text += "\n  • " + msg
	_add("summary", text, color)
	summary_label.text = text


func _run_group(name: String, tests: Array) -> void:
	_add("group", "\n--- %s ---" % name, Color(0.6, 0.8, 1.0))
	for test in tests:
		_run_single(test[0], test[1])


func _run_single(name: String, fn: Callable) -> void:
	_total += 1
	var ok: bool = fn.call()
	if ok:
		_passed += 1
		_add("pass", "  %s" % name, Color(0.3, 1.0, 0.4))
	else:
		_failed_msgs.append("%s failed" % name)
		_add("fail", "  %s — FAILED" % name, Color(1.0, 0.4, 0.3))


func _add(_type: String, text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 13)
	result_list.add_child(label)


# ==============================================================================
# UnitStats tests
# ==============================================================================

func _test_stats_creation() -> bool:
	var s := UnitStats.new()
	s.setup(10, 5, 4, 2, 3)
	return (
		s.max_hp == 10 and s.current_hp == 10 and
		s.max_movement == 5 and s.current_movement == 5 and
		s.max_ap == 4 and s.current_ap == 4 and
		s.defense == 2 and s.attack_power == 3
	)


func _test_stats_damage() -> bool:
	var s := UnitStats.new()
	s.setup(10, 5, 4, 2, 3)
	var dmg := s.take_damage(5, 2)
	if dmg != 3 or s.current_hp != 7:
		return false
	var s2 := UnitStats.new()
	s2.setup(1, 1, 1, 10, 1)
	var dmg2 := s2.take_damage(5, 10)
	return dmg2 == 1 and s2.current_hp == 0


func _test_stats_heal() -> bool:
	var s := UnitStats.new()
	s.setup(10, 5, 4, 2, 3)
	s.take_damage(8, 2)  # -6 → 4 HP
	s.heal(3)
	if s.current_hp != 7:
		return false
	s.heal(10)
	return s.current_hp == 10  # capped


func _test_stats_spend_ap() -> bool:
	var s := UnitStats.new()
	s.setup(10, 5, 4, 2, 3)
	if not s.can_spend_ap(3) or not s.spend_ap(3) or s.current_ap != 1:
		return false
	if s.can_spend_ap(3) or s.spend_ap(3):
		return false
	return true


func _test_stats_spend_movement() -> bool:
	var s := UnitStats.new()
	s.setup(10, 5, 4, 2, 3)
	if not s.can_spend_movement(3) or not s.spend_movement(3) or s.current_movement != 2:
		return false
	if s.can_spend_movement(3):
		return false
	return true


# ==============================================================================
# UnitEffects tests
# ==============================================================================

func _test_effects_add() -> bool:
	var e := UnitEffects.new()
	var effect := StatusEffect.new()
	effect.effect_id = "test_slow"
	effect.duration = 2
	effect.modifiers["movement"] = -2
	var active := e.add_effect(effect, "src")
	if active.effect.effect_id != "test_slow" or active.turns_remaining != 2:
		return false
	if e.active_effects.size() != 1:
		return false
	# Refresh should keep one effect
	e.add_effect(effect, "src")
	return e.active_effects.size() == 1


func _test_effects_remove() -> bool:
	var e := UnitEffects.new()
	var effect := StatusEffect.new()
	effect.effect_id = "test_h"
	effect.duration = 3
	e.add_effect(effect, "src")
	if e.active_effects.size() != 1:
		return false
	e.remove_effect("test_h")
	return e.active_effects.is_empty() and not e.has_effect("test_h")


func _test_effects_tick() -> bool:
	var e := UnitEffects.new()
	var effect := StatusEffect.new()
	effect.effect_id = "test_s"
	effect.duration = 2
	e.add_effect(effect, "src")
	e.tick_all()
	if e.active_effects.size() != 1:
		return false
	e.tick_all()
	return e.active_effects.is_empty()


func _test_effects_modifier() -> bool:
	var e := UnitEffects.new()
	var slow := StatusEffect.new()
	slow.effect_id = "slow"
	slow.modifiers["movement"] = -2
	e.add_effect(slow, "src")
	var haste := StatusEffect.new()
	haste.effect_id = "haste"
	haste.modifiers["movement"] = 2
	e.add_effect(haste, "src")
	return e.get_modifier("movement") == 0 and e.get_modifier("attack_power") == 0


# ==============================================================================
# UnitEquipment tests
# ==============================================================================

func _test_equipment_creation() -> bool:
	var eq := UnitEquipment.new()
	var rifle := WeaponData.new()
	rifle.weapon_id = "rifle"
	rifle.weapon_range = 3
	rifle.attack_ap_cost = 2
	rifle.weapon_power = 3
	rifle.tags = ["rifle", "ranged"]
	eq.setup(rifle)
	return (
		eq.get_active_weapon().weapon_id == "rifle" and
		eq.get_weapon_range() == 3 and
		eq.get_attack_ap_cost() == 2 and
		eq.get_weapon_power() == 3 and
		eq.is_weapon_tagged("ranged") and
		not eq.has_secondary_weapon()
	)


func _test_equipment_switch() -> bool:
	var eq := UnitEquipment.new()
	var r := WeaponData.new()
	r.weapon_id = "rifle"
	var s := WeaponData.new()
	s.weapon_id = "shotgun"
	eq.setup(r, s)
	if eq.get_active_weapon().weapon_id != "rifle":
		return false
	eq.switch_weapon()
	if eq.get_active_weapon().weapon_id != "shotgun":
		return false
	eq.switch_weapon()
	return eq.get_active_weapon().weapon_id == "rifle"


func _test_equipment_tags() -> bool:
	var eq := UnitEquipment.new()
	var r := WeaponData.new()
	r.weapon_id = "rifle"
	r.tags = ["rifle", "ranged"]
	eq.setup(r)
	return eq.is_weapon_tagged("rifle") and eq.is_weapon_tagged("ranged") and not eq.is_weapon_tagged("melee")