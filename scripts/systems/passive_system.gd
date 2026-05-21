class_name PassiveSystem
extends RefCounted

## Unified event system for passive evaluation.

## All passive event types.
enum PassiveEvent {
	BEFORE_ATTACK,      # Before dealing damage with an attack
	AFTER_ATTACK,       # After dealing damage with an attack
	BEFORE_SKILL,       # Before using a skill
	AFTER_SKILL,        # After using a skill
	ON_DAMAGE_DEALT,    # When dealing damage (any source)
	ON_DAMAGE_TAKEN,    # When taking damage
	ON_KILL,            # When killing another unit
	ON_DEATH,           # When dying
	ON_MOVE,            # When moving to a tile
	ON_TURN_START,      # At the start of the unit's turn
	ON_TURN_END,        # At the end of the unit's turn
}

## Called from PassiveSystem to display visual feedback.
static var feedback_callback: Callable = func(_unit: UnitBase, _text: String, _color: Color): pass

## Passive evaluation context.
class PassiveContext:
	var unit: UnitBase
	var target_unit: UnitBase = null
	var distance: int = -1

	func _init(p_unit: UnitBase, p_target: UnitBase = null, p_distance: int = -1) -> void:
		unit = p_unit
		target_unit = p_target
		distance = p_distance


## Gets all passives for a unit: from class + optionally from equipment.
## extra_passives can be used for weapon passives in the future.
static func _get_all_passives(unit: UnitBase, extra_passives: Array[PassiveEffect] = []) -> Array[PassiveEffect]:
	var result: Array[PassiveEffect] = []
	if unit.class_data:
		result.append_array(unit.class_data.passives)
	result.append_array(extra_passives)
	return result


## Triggers a passive event on a unit. Returns a dictionary of bonuses triggered.
static func trigger_event(
	event: PassiveEvent,
	unit: UnitBase,
	context: Dictionary = {},
	extra_passives: Array[PassiveEffect] = []
) -> Dictionary:
	var bonuses := {}
	var passives := _get_all_passives(unit, extra_passives)

	for passive in passives:
		match passive.passive_type:
			PassiveEffect.PassiveType.ON_ACTION:
				if event in [PassiveEvent.AFTER_ATTACK, PassiveEvent.AFTER_SKILL]:
					var fb := _apply_on_action(unit, passive)
					_merge_dict(bonuses, fb)
					if not fb.is_empty():
						_show_feedback(unit, passive.display_name, Color(0.3, 1.0, 0.8))

			PassiveEffect.PassiveType.ON_KILL:
				if event == PassiveEvent.ON_KILL:
					bonuses[passive.stat_name] = bonuses.get(passive.stat_name, 0) + passive.stat_value
					_show_feedback(unit, passive.display_name, Color(1.0, 0.8, 0.3))

			PassiveEffect.PassiveType.AOE_ON_DAMAGE:
				if event == PassiveEvent.ON_DAMAGE_DEALT:
					# AoE effect will be handled externally by the caller
					if context.has("damage") and context.has("target"):
						context["aoe_radius"] = float(passive.stat_value)
						context["aoe_damage"] = passive.stat_value
					_show_feedback(unit, passive.display_name, Color(1.0, 0.5, 0.2))

	return bonuses


## Applies FLAT_STAT_BONUS passives at unit creation time.
static func apply_flat_bonuses(unit: UnitBase, extra_passives: Array[PassiveEffect] = []) -> Dictionary:
	var bonuses := {}
	for passive in _get_all_passives(unit, extra_passives):
		if passive.passive_type != PassiveEffect.PassiveType.FLAT_STAT_BONUS:
			continue
		bonuses[passive.stat_name] = bonuses.get(passive.stat_name, 0) + passive.stat_value
	return bonuses


## Evaluates conditional bonuses for a given context.
static func evaluate_conditionals(unit: UnitBase, ctx: PassiveContext = null, extra_passives: Array[PassiveEffect] = []) -> Dictionary:
	var bonuses := {}
	for passive in _get_all_passives(unit, extra_passives):
		if passive.passive_type != PassiveEffect.PassiveType.CONDITIONAL_BONUS:
			continue
		if _check_condition(passive.condition, unit, ctx):
			bonuses[passive.stat_name] = bonuses.get(passive.stat_name, 0) + passive.stat_value
	return bonuses


## Computes total resistance to incoming damage.
static func get_damage_resistance(unit: UnitBase, _damage_type: String = "") -> int:
	var resistance := 0
	for passive in _get_all_passives(unit):
		if passive.passive_type != PassiveEffect.PassiveType.RESISTANCE:
			continue
		resistance += passive.stat_value
	return resistance


## Returns the total conditional attack_range bonus (e.g. Eagle Eye).
static func get_conditional_range(unit: UnitBase) -> int:
	var total := 0
	for passive in _get_all_passives(unit):
		if passive.passive_type != PassiveEffect.PassiveType.CONDITIONAL_BONUS:
			continue
		if passive.stat_name != "attack_range":
			continue
		if _check_condition(passive.condition, unit, null):
			total += passive.stat_value
	return total


## Returns the damage multiplier from Charge status effect stacks.
static func get_damage_multiplier(unit: UnitBase) -> int:
	var stacks := 0
	for e in unit.active_effects:
		if e.effect.effect_id == "charge":
			stacks += e.effect.modifiers.get("damage_multiplier", 0)
	return maxi(0, stacks)


## Consumes one stack of Charge on attack.
static func consume_damage_multiplier(unit: UnitBase) -> void:
	for e in unit.active_effects:
		if e.effect.effect_id == "charge":
			var current: int = e.effect.modifiers.get("damage_multiplier", 0)
			if current > 0:
				e.effect.modifiers["damage_multiplier"] = current - 1
			break


## Returns the total bonus for a given stat (flat + conditional).
static func get_total_bonus(unit: UnitBase, stat: String, ctx: PassiveContext = null) -> int:
	var total := 0
	var flat := apply_flat_bonuses(unit)
	total += flat.get(stat, 0)
	var conditional := evaluate_conditionals(unit, ctx)
	total += conditional.get(stat, 0)
	return total


## Shows visual feedback for a triggered passive.
static func _show_feedback(unit: UnitBase, text: String, color: Color) -> void:
	if feedback_callback.is_valid():
		feedback_callback.call(unit, text, color)


## Applies ON_ACTION bonus (e.g. Volt Charge).
static func _apply_on_action(unit: UnitBase, passive: PassiveEffect) -> Dictionary:
	var bonuses := {}
	var found := false
	for e in unit.active_effects:
		if e.effect.effect_id == "charge":
			var current: int = e.effect.modifiers.get("damage_multiplier", 0)
			e.effect.modifiers["damage_multiplier"] = current + passive.stat_value
			found = true
			break
	if not found:
		var charge_effect := StatusEffect.new()
		charge_effect.effect_id = "charge"
		charge_effect.display_name = "Charge"
		charge_effect.duration = -1
		charge_effect.modifiers["damage_multiplier"] = passive.stat_value
		unit.add_effect(charge_effect, "passive")
	bonuses[passive.stat_name] = bonuses.get(passive.stat_name, 0) + passive.stat_value
	return bonuses


static func _merge_dict(a: Dictionary, b: Dictionary) -> void:
	for key in b:
		a[key] = a.get(key, 0) + b[key]


static func _check_condition(condition: String, unit: UnitBase, ctx: PassiveContext = null) -> bool:
	match condition:
		"ranged_only":
			var weapon := unit.get_active_weapon()
			return weapon != null and weapon.tags.has("ranged")
		"melee_only":
			var weapon := unit.get_active_weapon()
			return weapon != null and not weapon.tags.has("ranged")
		"range_le_2":
			if ctx == null or ctx.distance < 0:
				return true
			return ctx.distance <= 2
		"range_gt_2":
			if ctx == null or ctx.distance < 0:
				return false
			return ctx.distance > 2
		"hp_full":
			return unit.current_hp >= unit.max_hp
		"hp_low":
			return float(unit.current_hp) / float(unit.max_hp) <= 0.5
		"ally_nearby":
			return true
		_:
			# Dynamic conditions: "has_status:charge", "weapon_tag:ranged", "enemy_count_gt:2", "turn_number_ge:3"
			if condition.begins_with("has_status:"):
				var status_id := condition.trim_prefix("has_status:")
				return unit.has_effect(status_id)
			if condition.begins_with("weapon_tag:"):
				var tag := condition.trim_prefix("weapon_tag:")
				var weapon := unit.get_active_weapon()
				return weapon != null and weapon.tags.has(tag)
			if condition.begins_with("enemy_count_gt:"):
				var count_str := condition.trim_prefix("enemy_count_gt:")
				var threshold := int(count_str)
				return _count_enemies_nearby(unit) > threshold
			if condition.begins_with("turn_number_ge:"):
				var turn_str := condition.trim_prefix("turn_number_ge:")
				var threshold := int(turn_str)
				# Requires injected turn number via context or global game state
				return ctx != null and ctx.distance >= threshold
			return false


## Counts enemies within 2 tiles of the unit.
static func _count_enemies_nearby(unit: UnitBase) -> int:
	if not unit.current_tile:
		return 0
	var grid := _get_grid_manager(unit)
	if not grid:
		return 0
	var nearby: Array = grid.get_tiles_in_range(unit.current_tile, 2)
	var count := 0
	for tile in nearby:
		if tile and tile.occupying_unit and not tile.occupying_unit.is_same_team(unit):
			count += 1
	return count


static func _get_grid_manager(unit: UnitBase) -> Node:
	var tree := unit.get_tree()
	if not tree:
		return null
	var scene := tree.current_scene
	if not scene:
		return null
	return scene.get_node_or_null("World/GridManager")