class_name SkillExecutor
extends Node

## Executes a skill given a context. Returns true on success.
func execute(ctx: SkillContext) -> bool:
	if not _validate_targeting(ctx):
		return false

	# Resolve affected units based on target mode
	_resolve_targets(ctx)

	# Handle toggle skills (e.g., Turret Mode — if already active, remove it)
	if _is_toggle_skill(ctx):
		if _toggle_off(ctx):
			return true

	# Apply skill effects to all affected units
	for effect: SkillEffect in ctx.skill.effects:
		for unit: UnitBase in ctx.affected_units:
			_apply_effect(effect, ctx.caster, unit)

	# Apply status effects to targets
	for status: StatusEffect in ctx.skill.status_effects:
		for unit: UnitBase in ctx.affected_units:
			unit.add_effect(status, ctx.caster.unit_name)

	# Apply self-effects to caster
	for status: StatusEffect in ctx.skill.self_effects:
		ctx.caster.add_effect(status, ctx.caster.unit_name)

	# Play skill SFX
	var audio_manager := _get_audio_manager(ctx.caster)
	if audio_manager:
		audio_manager.play_skill_sfx(ctx.skill.skill_id)

	return true


## Returns true if this is a toggle skill (SELF target + has self-effects with duration -1).
func _is_toggle_skill(ctx: SkillContext) -> bool:
	if ctx.skill.target_mode != SkillData.TargetMode.SELF:
		return false
	# Check if any self-effect has duration -1 (permanent/toggle)
	for status: StatusEffect in ctx.skill.self_effects:
		if status.duration == -1:
			return true
	# Also check regular effects for toggle behavior
	for effect: SkillEffect in ctx.skill.effects:
		if effect.effect_type == SkillEffect.EffectType.APPLY_STATUS:
			if effect.status_effect and effect.status_effect.duration == -1:
				return true
	return false


## If the caster already has the toggle effect, remove it (toggle off). Returns true if toggled off.
func _toggle_off(ctx: SkillContext) -> bool:
	# Check self-effects for toggle
	for status: StatusEffect in ctx.skill.self_effects:
		if status.duration == -1 and ctx.caster.has_effect(status.effect_id):
			ctx.caster.remove_effect(status.effect_id)
			return true
	# Check regular effects for toggle
	for effect: SkillEffect in ctx.skill.effects:
		if effect.effect_type == SkillEffect.EffectType.APPLY_STATUS:
			if effect.status_effect and effect.status_effect.duration == -1:
				if ctx.caster.has_effect(effect.status_effect.effect_id):
					ctx.caster.remove_effect(effect.status_effect.effect_id)
					return true
	return false


func _validate_targeting(ctx: SkillContext) -> bool:
	var mode: SkillData.TargetMode = ctx.skill.target_mode
	match mode:
		SkillData.TargetMode.SELF:
			return true
		SkillData.TargetMode.SINGLE_UNIT:
			if not ctx.target_unit:
				return false
			return _is_valid_target(ctx.caster, ctx.target_unit, ctx.skill.team_filter)
		SkillData.TargetMode.AOE_CIRCLE:
			# AOE skills centered on caster (range 0) always valid
			if ctx.skill.skill_range <= 0:
				return true
			return ctx.target_tile != null
		SkillData.TargetMode.SINGLE_TILE:
			return ctx.target_tile != null
	return false


func _is_valid_target(caster: UnitBase, target: UnitBase, filter: SkillData.TeamFilter) -> bool:
	match filter:
		SkillData.TeamFilter.SELF_ONLY:
			return target == caster
		SkillData.TeamFilter.ALLY:
			return caster.is_same_team(target)
		SkillData.TeamFilter.ENEMY:
			return not caster.is_same_team(target)
		SkillData.TeamFilter.BOTH:
			return true
	return false


func _resolve_targets(ctx: SkillContext) -> void:
	ctx.affected_units.clear()
	var mode: SkillData.TargetMode = ctx.skill.target_mode
	match mode:
		SkillData.TargetMode.SELF:
			ctx.affected_units.append(ctx.caster)
		SkillData.TargetMode.SINGLE_UNIT:
			if ctx.target_unit:
				ctx.affected_units.append(ctx.target_unit)
		SkillData.TargetMode.SINGLE_TILE:
			if ctx.target_tile and ctx.target_tile.occupying_unit:
				ctx.affected_units.append(ctx.target_tile.occupying_unit)
		SkillData.TargetMode.AOE_CIRCLE:
			_resolve_aoe(ctx)


func _resolve_aoe(ctx: SkillContext) -> void:
	# For AOE skills with range 0, center on caster's tile
	var center_tile: HexTile = ctx.target_tile
	if not center_tile:
		center_tile = ctx.caster.current_tile
	if not center_tile:
		return
	var grid: GridManager = ctx.caster.get_tree().current_scene.get_node("World/GridManager")
	var tiles_in_range := grid.get_tiles_in_range(center_tile, ctx.skill.aoe_radius)
	for tile: HexTile in tiles_in_range:
		if tile.occupying_unit:
			ctx.affected_units.append(tile.occupying_unit)


func _apply_effect(effect: SkillEffect, caster: UnitBase, target: UnitBase) -> void:
	match effect.effect_type:
		SkillEffect.EffectType.DAMAGE:
			target.take_damage(effect.amount)
		SkillEffect.EffectType.HEAL:
			target.heal(effect.amount)
		SkillEffect.EffectType.APPLY_STATUS:
			if effect.status_effect:
				target.add_effect(effect.status_effect, caster.unit_name)
		SkillEffect.EffectType.REMOVE_STATUS:
			if effect.status_effect:
				target.remove_effect(effect.status_effect.effect_id)
		SkillEffect.EffectType.BUFF, SkillEffect.EffectType.DEBUFF:
			_apply_stat_modifier(effect, target)


func _apply_stat_modifier(effect: SkillEffect, target: UnitBase) -> void:
	# Create a temporary status effect for the buff/debuff
	var status := StatusEffect.new()
	status.effect_id = "skill_%s_%s" % [effect.stat_name, "buff" if effect.effect_type == SkillEffect.EffectType.BUFF else "debuff"]
	status.display_name = "%s %s" % ["+" if effect.stat_modifier > 0 else "", effect.stat_modifier]
	status.duration = effect.duration
	status.modifiers[effect.stat_name] = effect.stat_modifier
	target.add_effect(status, target.unit_name)


func _get_audio_manager(unit: UnitBase) -> AudioManager:
	var scene_root: Node = unit.get_tree().current_scene
	return scene_root.get_node_or_null("BattleSession/AudioManager") as AudioManager
