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

# Stats
var max_hp := 0
var current_hp := 0
var max_movement := 0
var current_movement := 0
var max_ap := 0
var current_ap := 0
var defense := 0

## Base attack power (from class). Added to active weapon power for total damage.
var attack_power := 0

var attack_range := 1

## Passive bonuses from class (applied on _ready).
var _passive_bonuses: Dictionary = {}

# Grid state
var current_tile: HexTile = null

# Runtime
var active_effects: Array[ActiveStatusEffect] = []
var skill_cooldowns := {}

# Equipment
@export var primary_weapon: WeaponData
@export var secondary_weapon: WeaponData

## Which weapon is currently active: "primary" or "secondary"
var active_weapon_slot := "primary"

@onready var _unit_visual: UnitSpriteVisual = $UnitVisual


func _ready() -> void:
	apply_class_data()
	_apply_team_visual()


func refresh_turn() -> void:
	_tick_effects()
	current_movement = get_effective_movement()
	current_ap = get_effective_max_ap()
	reduce_cooldowns()


## Applies a StatusEffect to this unit. Returns the ActiveStatusEffect instance.
## If the effect already exists, refreshes its duration (for buffs/debuffs).
func add_effect(effect_data: StatusEffect, source: String = "") -> ActiveStatusEffect:
	# Check if effect already exists — if so, refresh duration
	for e in active_effects:
		if e.effect.effect_id == effect_data.effect_id:
			e.turns_remaining = effect_data.duration
			return e
	var active := ActiveStatusEffect.new(effect_data, source)
	active_effects.append(active)
	# Immediately apply movement lock if effect has movement modifier <= -999
	if effect_data.modifiers.has("movement") and effect_data.modifiers["movement"] <= -999:
		current_movement = 0
	return active


## Removes all active instances of a given effect_id.
func remove_effect(effect_id: String) -> void:
	active_effects = active_effects.filter(func(e: ActiveStatusEffect): return e.effect.effect_id != effect_id)
	# Restore movement if turret mode was removed
	if effect_id == "turret":
		current_movement = get_effective_movement()


## Returns true if this unit currently has at least one instance of effect_id.
func has_effect(effect_id: String) -> bool:
	for e in active_effects:
		if e.effect.effect_id == effect_id:
			return true
	return false


func _tick_effects() -> void:
	var expired: Array[ActiveStatusEffect] = []
	for e in active_effects:
		if e.tick():
			expired.append(e)
	for e in expired:
		active_effects.erase(e)


## Returns total modifier for a stat from all active effects.
func get_effect_modifier(stat: String) -> int:
	var total := 0
	for e in active_effects:
		total += e.get_modifier(stat)
	return total


## Movement accounting for status effect modifiers.
## Special sentinel -999 forces movement to 0 (used by Turret Mode).
func get_effective_movement() -> int:
	var mod := get_effect_modifier("movement")
	if mod <= -999:
		return 0
	return maxi(1, max_movement + mod)


## Max AP accounting for status effect modifiers.
func get_effective_max_ap() -> int:
	return maxi(1, max_ap + get_effect_modifier("max_ap"))


## Range accounting for status effect modifiers.
## Only applies range bonuses if the active weapon has a matching tag
## from the effect's "allowed_tags" modifier list.
func get_effective_range() -> int:
	var range_mod := get_effect_modifier("range")
	
	# Check tag restrictions
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
					range_mod = 0  # weapon doesn't qualify
	
	return maxi(1, attack_range + range_mod)


## Returns list of allowed weapon tags for effects that modify a given stat.
func _get_allowed_tags_for_stat(stat: String) -> Array:
	for e in active_effects:
		var tag_list = e.effect.modifiers.get("allowed_tags", [])
		if not tag_list.is_empty() and e.effect.modifiers.has(stat):
			return tag_list
	return []


func get_active_weapon() -> WeaponData:
	if active_weapon_slot == "primary" and primary_weapon:
		return primary_weapon
	if active_weapon_slot == "secondary" and secondary_weapon:
		return secondary_weapon
	return primary_weapon


func switch_weapon() -> void:
	if secondary_weapon:
		active_weapon_slot = "secondary" if active_weapon_slot == "primary" else "primary"
		_apply_combat_stats()


func get_attack_ap_cost() -> int:
	var weapon := get_active_weapon()
	if weapon:
		return maxi(1, weapon.attack_ap_cost)
	return 1


func can_spend_movement(amount: int) -> bool:

	return amount > 0 and current_movement >= amount


func spend_movement(amount: int) -> bool:

	if not can_spend_movement(amount):
		return false

	current_movement -= amount
	return true


func can_spend_ap(amount: int) -> bool:
	return amount > 0 and current_ap >= amount


func spend_ap(amount: int) -> bool:
	if not can_spend_ap(amount):
		return false

	current_ap -= amount
	return true


func reduce_cooldowns() -> void:
	for skill_id in skill_cooldowns.keys():
		if skill_cooldowns[skill_id] > 0:
			skill_cooldowns[skill_id] -= 1


func take_damage(amount: int) -> void:
	var effective_defense := maxi(
		1,
		defense + get_effect_modifier("defense")
	)
	var final_damage = maxi(1, amount - effective_defense)
	current_hp -= final_damage

	if current_hp <= 0:
		die()


func heal(amount: int) -> void:
	current_hp = mini(max_hp, current_hp + amount)


func die() -> void:
	died.emit()
	queue_free()


func move_to_tile(tile: HexTile) -> void:
	if tile == null:
		push_error("move_to_tile: tile is null")
		return

	if current_tile:
		current_tile.occupying_unit = null

	current_tile = tile
	current_tile.occupying_unit = self
	
	# Anima suavemente para a nova posição
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", tile.global_position, movement_tween_duration)


func get_portrait() -> Texture2D:
	if portrait:
		return portrait
	if class_data and class_data.portrait:
		return class_data.portrait
	# Fallback: use the first frame of the idle animation from the overworld sprite
	if _unit_visual and _unit_visual.sprite_frames:
		var frames := _unit_visual.sprite_frames
		if frames.has_animation("idle") and frames.get_frame_count("idle") > 0:
			return frames.get_frame_texture("idle", 0)
	return null


func apply_team_data(p_team_data: TeamData) -> void:
	team_data = p_team_data
	_apply_team_visual()


func is_player_team() -> bool:
	if team_data:
		return team_data.is_player
	return team_id == "player"


func is_same_team(other: UnitBase) -> bool:
	return team_id == other.team_id


func apply_class_data() -> void:
	if not class_data:
		_apply_combat_stats()
		_apply_team_visual()
		return

	max_hp = class_data.max_hp
	max_movement = class_data.movement
	max_ap = class_data.max_ap
	defense = class_data.defense
	current_hp = max_hp
	current_movement = max_movement
	current_ap = max_ap

	# Load class default weapon only if no primary is set
	if not primary_weapon and class_data.primary_weapon:
		primary_weapon = class_data.primary_weapon

	_apply_combat_stats()
	_apply_passives()
	_apply_team_visual()


func _apply_passives() -> void:
	if not class_data:
		return
	_passive_bonuses.clear()
	for passive: PassiveEffect in class_data.passives:
		match passive.passive_type:
			PassiveEffect.PassiveType.FLAT_STAT_BONUS:
				_passive_bonuses[passive.stat_name] = passive.stat_value
				if passive.stat_name == "defense":
					defense += passive.stat_value
				elif passive.stat_name == "attack_range":
					# Only apply range bonus if condition allows current weapon
					if passive.condition == "ranged_only":
						var weapon := get_active_weapon()
						if weapon and _is_ranged_weapon(weapon):
							attack_range += passive.stat_value
					else:
						attack_range += passive.stat_value
			PassiveEffect.PassiveType.CONDITIONAL_BONUS:
				_passive_bonuses[passive.stat_name] = passive.stat_value
				_passive_bonuses["condition_%s" % passive.stat_name] = passive.condition


## Returns true if the weapon is ranged (has tag "ranged").
func _is_ranged_weapon(weapon: WeaponData) -> bool:
	return weapon.tags.has("ranged")


## Safely retrieves the hovered unit from SelectionState.
func _get_hovered_unit() -> UnitBase:
	var tree := get_tree()
	if not tree:
		return null
	var current_scene := tree.current_scene
	if not current_scene:
		return null
	# SelectionState is at BattleSession/SelectionState under the root scene
	var selection_state := current_scene.get_node_or_null("BattleSession/SelectionState")
	if not selection_state:
		# Fallback: try the root directly
		selection_state = current_scene.get_node_or_null("SelectionState")
	if not selection_state:
		return null
	return selection_state.get("hovered_unit") as UnitBase


func _apply_combat_stats() -> void:
	attack_power = class_data.base_attack if class_data else 0
	attack_range = 1

	var weapon := get_active_weapon()
	if weapon:
		attack_range = weapon.weapon_range


## Returns total attack power: base attack + weapon power + effects + passives.
func get_total_attack_power() -> int:
	var weapon := get_active_weapon()
	var wp := weapon.weapon_power if weapon else 1
	var mod := get_effect_modifier("attack_power")
	var total := attack_power + wp + mod
	
	# Apply conditional passives (e.g. Close Quarters: +1 at range <= 2)
	if _passive_bonuses.has("attack_power"):
		var condition: String = _passive_bonuses.get("condition_attack_power", "")
		if condition == "range_le_2":
			var target_unit: UnitBase = _get_hovered_unit()
			if target_unit and current_tile and target_unit.current_tile:
				var dist: int = HexMath.axial_distance_tiles(current_tile, target_unit.current_tile)
				if dist <= 2:
					total += _passive_bonuses["attack_power"]
	
	return maxi(1, total)


## Returns passive bonus value for a stat (0 if none).
func get_passive_bonus(stat: String) -> int:
	return _passive_bonuses.get(stat, 0)


func _apply_team_visual() -> void:
	if _unit_visual:
		_unit_visual.apply_team_data(team_data, team_id)


func get_visual_top_y() -> float:
	if _unit_visual:
		return _unit_visual.get_sprite_top_y()
	return 1.8


func configure_from_grid(grid_config: GridConfig) -> void:
	if _unit_visual:
		_unit_visual.configure_surface(grid_config)


func play_attack_visual() -> void:
	if _unit_visual:
		_unit_visual.play_attack()
