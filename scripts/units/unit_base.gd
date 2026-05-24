class_name UnitBase
extends Node3D

signal died

# Identity
@export var unit_name := ""
@export var class_id := ""
@export var team_id := "player"

@export var portrait: Texture2D
@export var class_data: ClassData

## Team data with colors and properties
var team_data: TeamData = null

# Movement animation
@export var movement_tween_duration := 0.3

# --- Composed modules ---
var stats: UnitStats
var effects: UnitEffects
var equipment: UnitEquipment

# Passive bonuses from class
var _passive_bonuses: Dictionary = {}

# Grid state
var current_tile: HexTile = null

# Runtime
var skill_cooldowns := {}

@onready var _unit_visual: UnitSpriteVisual = $UnitVisual

# Injected services (set via setup())
var audio_manager: AudioManager = null
var battle_hud: BattleHud = null
var selection_state: SelectionState = null


# ------------------------------------------------------------------------------
# Dependency injection
# ------------------------------------------------------------------------------

func setup(p_audio: AudioManager, p_hud: BattleHud, p_selection: SelectionState) -> void:
	audio_manager = p_audio
	battle_hud = p_hud
	selection_state = p_selection


func _ready() -> void:
	# Initialize composed modules
	stats = UnitStats.new()
	effects = UnitEffects.new()
	equipment = UnitEquipment.new()

	apply_class_data()
	_apply_team_visual()


# ------------------------------------------------------------------------------
# Turn lifecycle
# ------------------------------------------------------------------------------

func refresh_turn() -> void:
	effects.tick_all()
	current_movement = get_effective_movement()
	current_ap = get_effective_max_ap()
	reduce_cooldowns()


# ------------------------------------------------------------------------------
# Stats delegation
# ------------------------------------------------------------------------------

var max_hp: int:
	get: return stats.max_hp if stats else 0
var current_hp: int:
	get: return stats.current_hp if stats else 0
	set(v): stats.current_hp = v if stats else v
var max_movement: int:
	get: return stats.max_movement if stats else 0
var current_movement: int:
	get: return stats.current_movement if stats else 0
	set(v): stats.current_movement = v if stats else v
var max_ap: int:
	get: return stats.max_ap if stats else 0
var current_ap: int:
	get: return stats.current_ap if stats else 0
	set(v): stats.current_ap = v if stats else v
var defense: int:
	get: return stats.defense if stats else 0
var attack_power: int:
	get: return stats.attack_power if stats else 0
var attack_range: int:
	get: return equipment.get_weapon_range() if equipment else 1


func can_spend_ap(amount: int) -> bool:
	return stats and stats.can_spend_ap(amount)

func spend_ap(amount: int) -> bool:
	return stats and stats.spend_ap(amount)

func can_spend_movement(amount: int) -> bool:
	return stats and stats.can_spend_movement(amount)

func spend_movement(amount: int) -> bool:
	return stats and stats.spend_movement(amount)

func take_damage(amount: int) -> void:
	if not stats:
		return
	var resistance := PassiveSystem.get_damage_resistance(self)
	var effective_defense := maxi(1, defense + effects.get_modifier("defense") + resistance)
	var final_damage = stats.take_damage(amount, effective_defense)

	# Trigger ON_DAMAGE_TAKEN event
	PassiveSystem.trigger_event(PassiveSystem.PassiveEvent.ON_DAMAGE_TAKEN, self, {"damage": final_damage})

	# Visual feedback
	if _unit_visual:
		_unit_visual.flash_white()
		_unit_visual.shake()

	if stats.current_hp <= 0:
		die()

func heal(amount: int) -> void:
	if stats:
		stats.heal(amount)


# ------------------------------------------------------------------------------
# Effects delegation
# ------------------------------------------------------------------------------

var active_effects: Array:
	get: return effects.active_effects if effects else []

func add_effect(effect_data: StatusEffect, source: String = "") -> ActiveStatusEffect:
	if not effects:
		return null
	var active := effects.add_effect(effect_data, source)
	# Immediately apply movement lock if effect has movement modifier <= -999
	if effect_data.modifiers.has("movement") and effect_data.modifiers["movement"] <= -999:
		current_movement = 0
	return active

func remove_effect(effect_id: String) -> void:
	if effects:
		effects.remove_effect(effect_id)
		# Restore movement if turret mode was removed
		if effect_id == "turret":
			current_movement = get_effective_movement()

func has_effect(effect_id: String) -> bool:
	return effects and effects.has_effect(effect_id)

func get_effect_modifier(stat: String) -> int:
	return effects.get_modifier(stat) if effects else 0


# ------------------------------------------------------------------------------
# Equipment delegation
# ------------------------------------------------------------------------------

@export var primary_weapon: WeaponData:
	get: return equipment.primary_weapon if equipment else null
	set(v):
		if equipment:
			equipment.primary_weapon = v

@export var secondary_weapon: WeaponData:
	get: return equipment.secondary_weapon if equipment else null
	set(v):
		if equipment:
			equipment.secondary_weapon = v

var active_weapon_slot: String:
	get: return equipment.active_weapon_slot if equipment else "primary"

func get_active_weapon() -> WeaponData:
	return equipment.get_active_weapon() if equipment else null

func switch_weapon() -> void:
	if equipment:
		equipment.switch_weapon()
		_apply_combat_stats()

func get_attack_ap_cost() -> int:
	return equipment.get_attack_ap_cost() if equipment else 1


# ------------------------------------------------------------------------------
# Combat calculations
# ------------------------------------------------------------------------------

## Movement accounting for status effect modifiers.
func get_effective_movement() -> int:
	var mod := get_effect_modifier("movement")
	if mod <= -999:
		return 0
	return maxi(1, max_movement + mod)

## Max AP accounting for status effect modifiers.
func get_effective_max_ap() -> int:
	return maxi(1, max_ap + get_effect_modifier("max_ap"))

## Range accounting for status effect modifiers.
func get_effective_range() -> int:
	var range_mod := get_effect_modifier("range")
	if range_mod > 0:
		var weapon := get_active_weapon()
		if weapon and not weapon.tags.is_empty():
			var allowed = _get_allowed_tags_for_stat("range")
			if not allowed.is_empty():
				var has_tag := false
				for t in weapon.tags:
					if t in allowed:
						has_tag = true
						break
				if not has_tag:
					range_mod = 0
	var conditional_range := PassiveSystem.get_conditional_range(self)
	var base_range: int = equipment.get_weapon_range() if equipment else 1
	return maxi(1, base_range + range_mod + conditional_range)

func _get_allowed_tags_for_stat(stat: String) -> Array:
	for e in active_effects:
		var tag_list = e.effect.modifiers.get("allowed_tags", [])
		if not tag_list.is_empty() and e.effect.modifiers.has(stat):
			return tag_list
	return []

## Returns total attack power: base attack + weapon power + effects + passives.
func get_total_attack_power(p_target_distance: int = -1) -> int:
	var weapon := get_active_weapon()
	var wp := weapon.weapon_power if weapon else 1
	var mod := get_effect_modifier("attack_power")
	var total := attack_power + wp + mod

	PassiveSystem.trigger_event(PassiveSystem.PassiveEvent.AFTER_ATTACK, self, {})

	var dist: int = p_target_distance
	if dist < 0:
		var target_unit: UnitBase = _get_hovered_unit()
		if target_unit and current_tile and target_unit.current_tile:
			dist = HexMath.axial_distance_tiles(current_tile, target_unit.current_tile)

	var ctx := PassiveSystem.PassiveContext.new(self, null, dist)
	var conditional_bonus := PassiveSystem.get_total_bonus(self, "attack_power", ctx)
	total += conditional_bonus

	var charge_stacks := PassiveSystem.get_damage_multiplier(self)
	if charge_stacks > 0:
		total += charge_stacks
		PassiveSystem.consume_damage_multiplier(self)

	return maxi(1, total)

func reduce_cooldowns() -> void:
	for skill_id in skill_cooldowns.keys():
		if skill_cooldowns[skill_id] > 0:
			skill_cooldowns[skill_id] -= 1


# ------------------------------------------------------------------------------
# Death
# ------------------------------------------------------------------------------

func die() -> void:
	died.emit()
	if _unit_visual:
		var tween := _unit_visual.play_death()
		if audio_manager:
			audio_manager.play_death()
		if battle_hud:
			battle_hud.show_damage_popup(self, 0, "death")
		if tween:
			await tween.finished
	queue_free()


# ------------------------------------------------------------------------------
# Movement
# ------------------------------------------------------------------------------

func move_to_tile(tile: HexTile) -> void:
	if tile == null:
		push_error("move_to_tile: tile is null")
		return
	if current_tile:
		current_tile.occupying_unit = null
	current_tile = tile
	current_tile.occupying_unit = self
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", tile.global_position, movement_tween_duration)


# ------------------------------------------------------------------------------
# Visual / Portrait
# ------------------------------------------------------------------------------

func get_portrait() -> Texture2D:
	if portrait:
		return portrait
	if class_data and class_data.portrait:
		return class_data.portrait
	if _unit_visual and _unit_visual.sprite_frames:
		var frames := _unit_visual.sprite_frames
		if frames.has_animation("idle") and frames.get_frame_count("idle") > 0:
			return frames.get_frame_texture("idle", 0)
	return null

func get_visual_top_y() -> float:
	return _unit_visual.get_sprite_top_y() if _unit_visual else 1.8

func configure_from_grid(grid_config: GridConfig) -> void:
	if _unit_visual:
		_unit_visual.configure_surface(grid_config)

func play_attack_visual() -> void:
	if _unit_visual:
		_unit_visual.play_attack()


# ------------------------------------------------------------------------------
# Team
# ------------------------------------------------------------------------------

func apply_team_data(p_team_data: TeamData) -> void:
	team_data = p_team_data
	_apply_team_visual()

func is_player_team() -> bool:
	if team_data:
		return team_data.is_player
	return team_id == "player"

func is_same_team(other: UnitBase) -> bool:
	return team_id == other.team_id


# ------------------------------------------------------------------------------
# Class data application
# ------------------------------------------------------------------------------

func apply_class_data() -> void:
	if not class_data:
		_apply_combat_stats()
		_apply_team_visual()
		return

	stats.setup(
		class_data.max_hp,
		class_data.movement,
		class_data.max_ap,
		class_data.defense,
		class_data.base_attack
	)

	equipment.setup(class_data.primary_weapon, class_data.secondary_weapon)

	_apply_combat_stats()
	_apply_passives()
	_apply_team_visual()

func _apply_passives() -> void:
	if not class_data:
		return
	_passive_bonuses.clear()
	var flat_bonuses := PassiveSystem.apply_flat_bonuses(self)
	for stat: String in flat_bonuses:
		var value: int = flat_bonuses[stat]
		_passive_bonuses[stat] = _passive_bonuses.get(stat, 0) + value
		if stat == "defense" and stats:
			stats.defense += value

func _apply_combat_stats() -> void:
	if stats:
		stats.attack_power = class_data.base_attack if class_data else 0

func get_passive_bonus(stat: String) -> int:
	return _passive_bonuses.get(stat, 0)

func _apply_team_visual() -> void:
	if _unit_visual:
		_unit_visual.apply_team_data(team_data, team_id)


# ------------------------------------------------------------------------------
# Helper (fallback)
# ------------------------------------------------------------------------------

func _get_hovered_unit() -> UnitBase:
	if selection_state:
		return selection_state.get("hovered_unit") as UnitBase
	var tree := get_tree()
	if not tree:
		return null
	var current_scene := tree.current_scene
	if not current_scene:
		return null
	var ss := current_scene.get_node_or_null("BattleSession/SelectionState")
	if not ss:
		ss = current_scene.get_node_or_null("SelectionState")
	if not ss:
		return null
	return ss.get("hovered_unit") as UnitBase


# ------------------------------------------------------------------------------
# Stat breakdown methods (for UI panels)
# ------------------------------------------------------------------------------

func get_defense_breakdown() -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	var base := class_data.defense if class_data else 0
	var total := base
	var passive_def := get_passive_bonus("defense")
	if passive_def != 0:
		result.append(StatModifier.new("Passives", total, passive_def, total + passive_def))
		total += passive_def
	for e in active_effects:
		var mod: int = e.get_modifier("defense")
		if mod != 0:
			result.append(StatModifier.new(e.effect.display_name, total, mod, total + mod))
			total += mod
	if result.is_empty():
		result.append(StatModifier.new("Base", total, 0, total))
	return result

func get_attack_power_breakdown(p_target_distance: int = -1) -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	var base := class_data.base_attack if class_data else 0
	var weapon := get_active_weapon()
	var wp := weapon.weapon_power if weapon else 1
	var total := base + wp
	result.append(StatModifier.new("Base ATK", base, 0, base))
	result.append(StatModifier.new("Weapon (%s)" % (weapon.weapon_name if weapon else "None"), total, wp, total))
	var effect_mod := get_effect_modifier("attack_power")
	if effect_mod != 0:
		for e in active_effects:
			var mod: int = e.get_modifier("attack_power")
			if mod != 0:
				result.append(StatModifier.new(e.effect.display_name, total, mod, total + mod))
				total += mod
	var dist: int = p_target_distance
	if dist < 0:
		var target_unit: UnitBase = _get_hovered_unit()
		if target_unit and current_tile and target_unit.current_tile:
			dist = HexMath.axial_distance_tiles(current_tile, target_unit.current_tile)
	var ctx := PassiveSystem.PassiveContext.new(self, null, dist)
	var conditional_bonus := PassiveSystem.get_total_bonus(self, "attack_power", ctx)
	if conditional_bonus != 0:
		result.append(StatModifier.new("Passives (Conditional)", total, conditional_bonus, total + conditional_bonus))
		total += conditional_bonus
	return result

func get_movement_breakdown() -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	var base := max_movement
	var total := base
	var movement_mod := get_effect_modifier("movement")
	if movement_mod <= -999:
		result.append(StatModifier.new("Locked", base, -base, 0))
		return result
	for e in active_effects:
		var mod: int = e.get_modifier("movement")
		if mod != 0:
			result.append(StatModifier.new(e.effect.display_name, total, mod, total + mod))
			total += mod
	if result.is_empty():
		result.append(StatModifier.new("Base", total, 0, total))
	return result

func get_ap_breakdown() -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	var base := max_ap
	var total := base
	for e in active_effects:
		var mod: int = e.get_modifier("max_ap")
		if mod != 0:
			result.append(StatModifier.new(e.effect.display_name, total, mod, total + mod))
			total += mod
	if result.is_empty():
		result.append(StatModifier.new("Base", total, 0, total))
	return result

func get_range_breakdown() -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	var weapon := get_active_weapon()
	var base := weapon.weapon_range if weapon else 1
	var total := base
	result.append(StatModifier.new("Weapon (%s)" % (weapon.weapon_name if weapon else "None"), base, 0, base))
	var range_mod := get_effect_modifier("range")
	if range_mod > 0:
		if weapon and not weapon.tags.is_empty():
			var allowed = _get_allowed_tags_for_stat("range")
			if not allowed.is_empty():
				var has_tag := false
				for t in weapon.tags:
					if t in allowed:
						has_tag = true
						break
				if not has_tag:
					range_mod = 0
	if range_mod != 0:
		for e in active_effects:
			var mod: int = e.get_modifier("range")
			if mod != 0:
				result.append(StatModifier.new(e.effect.display_name, total, mod, total + mod))
				total += mod
	var conditional_range := PassiveSystem.get_conditional_range(self)
	if conditional_range != 0:
		result.append(StatModifier.new("Passives (Conditional)", total, conditional_range, total + conditional_range))
		total += conditional_range
	return result

func get_hp_breakdown() -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	result.append(StatModifier.new("Base HP", max_hp, 0, max_hp))
	return result