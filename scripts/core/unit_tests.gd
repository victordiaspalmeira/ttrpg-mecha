extends Node

## Quick unit tests for the refactored modules.
## Run from the Godot console:  unit_tests.gd   (attach to any scene)

func _ready() -> void:
	print("\n=== UnitStats Tests ===")
	_test_stats_creation()
	_test_stats_damage()
	_test_stats_heal()
	_test_stats_spend_ap()
	_test_stats_spend_movement()
	
	print("\n=== UnitEffects Tests ===")
	_test_effects_add()
	_test_effects_remove()
	_test_effects_tick()
	_test_effects_modifier()
	
	print("\n=== UnitEquipment Tests ===")
	_test_equipment_creation()
	_test_equipment_switch()
	_test_equipment_tags()
	
	print("\n✅ All tests passed!")


# ------------------------------------------------------------------------------
# UnitStats Tests
# ------------------------------------------------------------------------------

func _test_stats_creation() -> void:
	var s := UnitStats.new()
	s.setup(10, 5, 4, 2, 3)
	assert_eq(s.max_hp, 10, "max_hp")
	assert_eq(s.current_hp, 10, "current_hp initial")
	assert_eq(s.max_movement, 5, "max_movement")
	assert_eq(s.current_movement, 5, "current_movement initial")
	assert_eq(s.max_ap, 4, "max_ap")
	assert_eq(s.current_ap, 4, "current_ap initial")
	assert_eq(s.defense, 2, "defense")
	assert_eq(s.attack_power, 3, "attack_power")
	print("  ✅ stats_creation")


func _test_stats_damage() -> void:
	var s := UnitStats.new()
	s.setup(10, 5, 4, 2, 3)
	var dmg := s.take_damage(5, 2)  # 5 - 2 = 3
	assert_eq(dmg, 3, "damage after defense")
	assert_eq(s.current_hp, 7, "hp after damage")
	
	# Test minimum damage 1
	var s2 := UnitStats.new()
	s2.setup(1, 1, 1, 10, 1)
	var dmg2 := s2.take_damage(5, 10)  # max(1, 5-10) = 1
	assert_eq(dmg2, 1, "minimum damage")
	assert_eq(s2.current_hp, 0, "hp after min damage")
	print("  ✅ stats_damage")


func _test_stats_heal() -> void:
	var s := UnitStats.new()
	s.setup(10, 5, 4, 2, 3)
	s.take_damage(8, 2)  # -6 HP → 4 HP
	s.heal(3)
	assert_eq(s.current_hp, 7, "hp after heal")
	s.heal(10)
	assert_eq(s.current_hp, 10, "hp capped at max")
	print("  ✅ stats_heal")


func _test_stats_spend_ap() -> void:
	var s := UnitStats.new()
	s.setup(10, 5, 4, 2, 3)
	assert_eq(s.can_spend_ap(3), true, "can spend 3")
	assert_eq(s.spend_ap(3), true, "spend 3")
	assert_eq(s.current_ap, 1, "ap after spend")
	assert_eq(s.can_spend_ap(3), false, "cannot spend 3")
	assert_eq(s.spend_ap(3), false, "spend 3 fails")
	print("  ✅ stats_spend_ap")


func _test_stats_spend_movement() -> void:
	var s := UnitStats.new()
	s.setup(10, 5, 4, 2, 3)
	assert_eq(s.can_spend_movement(3), true, "can move 3")
	assert_eq(s.spend_movement(3), true, "move 3")
	assert_eq(s.current_movement, 2, "mov after spend")
	assert_eq(s.can_spend_movement(3), false, "cannot move 3")
	print("  ✅ stats_spend_movement")


# ------------------------------------------------------------------------------
# UnitEffects Tests
# ------------------------------------------------------------------------------

func _test_effects_add() -> void:
	var e := UnitEffects.new()
	var effect := StatusEffect.new()
	effect.effect_id = "test_slow"
	effect.display_name = "Slow"
	effect.duration = 2
	effect.modifiers["movement"] = -2
	
	var active := e.add_effect(effect, "test_source")
	assert_eq(active.effect.effect_id, "test_slow", "effect id")
	assert_eq(active.turns_remaining, 2, "duration")
	assert_eq(e.active_effects.size(), 1, "one effect")
	
	# Adding same effect refreshes duration
	var active2 := e.add_effect(effect, "test_source")
	assert_eq(e.active_effects.size(), 1, "still one effect (refresh)")
	assert_eq(active2.turns_remaining, 2, "refreshed duration")
	print("  ✅ effects_add")


func _test_effects_remove() -> void:
	var e := UnitEffects.new()
	var effect := StatusEffect.new()
	effect.effect_id = "test_haste"
	effect.duration = 3
	e.add_effect(effect, "source")
	assert_eq(e.active_effects.size(), 1, "has effect before remove")
	
	e.remove_effect("test_haste")
	assert_eq(e.active_effects.size(), 0, "effect removed")
	assert_eq(e.has_effect("test_haste"), false, "has_effect false")
	print("  ✅ effects_remove")


func _test_effects_tick() -> void:
	var e := UnitEffects.new()
	var effect := StatusEffect.new()
	effect.effect_id = "test_short"
	effect.duration = 2
	e.add_effect(effect, "source")
	
	e.tick_all()
	assert_eq(e.active_effects.size(), 1, "still active after 1 tick")
	
	e.tick_all()
	assert_eq(e.active_effects.size(), 0, "expired after 2 ticks")
	print("  ✅ effects_tick")


func _test_effects_modifier() -> void:
	var e := UnitEffects.new()
	
	var slow := StatusEffect.new()
	slow.effect_id = "slow"
	slow.modifiers["movement"] = -2
	e.add_effect(slow, "source")
	
	var haste := StatusEffect.new()
	haste.effect_id = "haste"
	haste.modifiers["movement"] = 2
	e.add_effect(haste, "source")
	
	assert_eq(e.get_modifier("movement"), 0, "movement mod combined (-2 + 2 = 0)")
	assert_eq(e.get_modifier("attack_power"), 0, "unmodified stat = 0")
	print("  ✅ effects_modifier")


# ------------------------------------------------------------------------------
# UnitEquipment Tests
# ------------------------------------------------------------------------------

func _test_equipment_creation() -> void:
	var eq := UnitEquipment.new()
	var rifle := WeaponData.new()
	rifle.weapon_id = "rifle"
	rifle.weapon_range = 3
	rifle.attack_ap_cost = 2
	rifle.weapon_power = 3
	rifle.tags = ["rifle", "ranged"]
	
	eq.setup(rifle)
	assert_eq(eq.get_active_weapon().weapon_id, "rifle", "primary weapon")
	assert_eq(eq.get_weapon_range(), 3, "range")
	assert_eq(eq.get_attack_ap_cost(), 2, "ap cost")
	assert_eq(eq.get_weapon_power(), 3, "weapon power")
	assert_eq(eq.is_weapon_tagged("ranged"), true, "ranged tag")
	assert_eq(eq.has_secondary_weapon(), false, "no secondary")
	print("  ✅ equipment_creation")


func _test_equipment_switch() -> void:
	var eq := UnitEquipment.new()
	var rifle := WeaponData.new()
	rifle.weapon_id = "rifle"
	rifle.weapon_range = 3
	var shotgun := WeaponData.new()
	shotgun.weapon_id = "shotgun"
	shotgun.weapon_range = 1
	
	eq.setup(rifle, shotgun)
	assert_eq(eq.get_active_weapon().weapon_id, "rifle", "starts with primary")
	
	eq.switch_weapon()
	assert_eq(eq.get_active_weapon().weapon_id, "shotgun", "switched to secondary")
	
	eq.switch_weapon()
	assert_eq(eq.get_active_weapon().weapon_id, "rifle", "switched back to primary")
	print("  ✅ equipment_switch")


func _test_equipment_tags() -> void:
	var eq := UnitEquipment.new()
	var rifle := WeaponData.new()
	rifle.weapon_id = "rifle"
	rifle.weapon_range = 3
	rifle.tags = ["rifle", "ranged"]
	
	eq.setup(rifle)
	assert_eq(eq.is_weapon_tagged("rifle"), true, "tag: rifle")
	assert_eq(eq.is_weapon_tagged("ranged"), true, "tag: ranged")
	assert_eq(eq.is_weapon_tagged("melee"), false, "tag: melee (absent)")
	print("  ✅ equipment_tags")


# ------------------------------------------------------------------------------
# Test helper
# ------------------------------------------------------------------------------

func assert_eq(actual, expected, label: String) -> void:
	if actual != expected:
		push_error("❌ FAIL: %s — expected %s, got %s" % [label, str(expected), str(actual)])