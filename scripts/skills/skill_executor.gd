class_name SkillExecutor
extends Node

var cinematic_player: CinematicPlayer = null


func _ready() -> void:
	var session := get_parent()
	if session:
		cinematic_player = session.get_node_or_null("CinematicPlayer") as CinematicPlayer


## Executes a skill given a context. Returns true on success.
func execute(ctx: SkillContext) -> bool:
	if not _validate_targeting(ctx):
		return false

	# Resolve affected units based on target mode
	_resolve_targets(ctx)

	# Handle toggle skills (e.g., Turret Mode — if already active, remove it)
	if _is_toggle_skill(ctx):
		if _toggle_off(ctx):
			# Play toggle-off particle effect
			_play_skill_particles(ctx, true)
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

	# Trigger AFTER_SKILL event (Volt Charge: +1 Charge stack on any action)
	PassiveSystem.trigger_event(PassiveSystem.PassiveEvent.AFTER_SKILL, ctx.caster, {"skill": ctx.skill})

	# Play skill cinematic + particles
	if cinematic_player and not ctx.affected_units.is_empty():
		var primary_effect := _determine_particle_effect(ctx, false)
		cinematic_player.play_skill_cinematic(ctx.caster, ctx.affected_units, primary_effect, func():
			# Show action name popup after cinematic
			var battle_hud := _get_battle_hud(ctx.caster)
			if battle_hud:
				battle_hud.show_action_name_popup(ctx.skill.skill_name)
		, _get_particle_manager(ctx.caster))
	else:
		# Fallback: just play particles
		_play_skill_particles(ctx, false)

	# Play skill SFX
	var audio_manager := _get_audio_manager(ctx.caster)
	if audio_manager:
		audio_manager.play_skill_sfx(ctx.skill.skill_id)

	# Show action name popup
	var battle_hud := _get_battle_hud(ctx.caster)
	if battle_hud:
		battle_hud.show_action_name_popup(ctx.skill.skill_name)

	return true


## Play particle effects based on skill type and effects
func _play_skill_particles(ctx: SkillContext, is_toggle_off: bool) -> void:
	var particle_manager := _get_particle_manager(ctx.caster)
	if not particle_manager:
		return
	
	# Determine particle effect based on skill effects
	var primary_effect := _determine_particle_effect(ctx, is_toggle_off)
	
	# Play AOE ring for AOE skills
	if ctx.skill.target_mode == SkillData.TargetMode.AOE_CIRCLE and ctx.skill.aoe_radius > 0:
		var center_pos := ctx.caster.global_position + Vector3.UP * 0.1
		if ctx.target_tile:
			center_pos = ctx.target_tile.global_position + Vector3.UP * 0.1
		particle_manager.play_aoe_ring(center_pos, ctx.skill.aoe_radius)
	
	# Play effect on each affected unit
	for unit: UnitBase in ctx.affected_units:
		var effect_pos := unit.global_position + Vector3.UP * 0.5
		particle_manager.play_effect(primary_effect, effect_pos)
		
		# Play additional status-specific particles
		for status: StatusEffect in ctx.skill.status_effects:
			var status_particle := _get_status_particle(status.effect_id)
			if status_particle != -1:
				particle_manager.play_effect(status_particle, unit.global_position + Vector3.UP * 0.8)


## Determine the primary particle effect for a skill
func _determine_particle_effect(ctx: SkillContext, is_toggle_off: bool) -> int:
	if is_toggle_off:
		return ParticleConfig.EffectType.SKILL_TELEPORT
	
	# Check skill ID for specific effects
	match ctx.skill.skill_id:
		"grenade":
			return ParticleConfig.EffectType.SKILL_DAMAGE_FIRE
		"suppression":
			return ParticleConfig.EffectType.SKILL_DAMAGE_GENERIC
		"adrenaline_rush":
			return ParticleConfig.EffectType.SKILL_BUFF_UP
		"fortify":
			return ParticleConfig.EffectType.SKILL_SHIELD
		"shield_bash":
			return ParticleConfig.EffectType.ATTACK_SLASH
		"taunt":
			return ParticleConfig.EffectType.SKILL_TAUNT
		"precision_shot":
			return ParticleConfig.EffectType.ATTACK_BULLET
		"armor_piercer":
			return ParticleConfig.EffectType.ATTACK_BULLET
		"turret_mode":
			return ParticleConfig.EffectType.SKILL_TURRET_DEPLOY
		"shock_trooper":
			return ParticleConfig.EffectType.SKILL_DAMAGE_ELECTRIC
		"energize":
			return ParticleConfig.EffectType.SKILL_BUFF_UP
		"thunder":
			return ParticleConfig.EffectType.SKILL_DAMAGE_ELECTRIC
		"healing_wave":
			return ParticleConfig.EffectType.SKILL_HEAL
		"regen_shield":
			return ParticleConfig.EffectType.SKILL_HEAL
		"combat_stim":
			return ParticleConfig.EffectType.SKILL_BUFF_UP
		"accusation":
			return ParticleConfig.EffectType.SKILL_DEBUFF_DOWN
		"judgement":
			return ParticleConfig.EffectType.SKILL_DAMAGE_GENERIC
		"execution":
			return ParticleConfig.EffectType.SKILL_DAMAGE_GENERIC
		_:
			pass
	
	# Determine from effect types
	for effect: SkillEffect in ctx.skill.effects:
		match effect.effect_type:
			SkillEffect.EffectType.DAMAGE:
				return ParticleConfig.EffectType.SKILL_DAMAGE_GENERIC
			SkillEffect.EffectType.HEAL:
				return ParticleConfig.EffectType.SKILL_HEAL
			SkillEffect.EffectType.BUFF:
				return ParticleConfig.EffectType.SKILL_BUFF_UP
			SkillEffect.EffectType.DEBUFF:
				return ParticleConfig.EffectType.SKILL_DEBUFF_DOWN
			_:
				pass
	
	# Check self-effects
	for status: StatusEffect in ctx.skill.self_effects:
		var status_particle := _get_status_particle(status.effect_id)
		if status_particle != -1:
			return status_particle
	
	return ParticleConfig.EffectType.SKILL_DAMAGE_GENERIC


## Get particle effect type for a status effect ID
func _get_status_particle(status_id: String) -> int:
	match status_id:
		"slow":
			return ParticleConfig.EffectType.STATUS_SLOW
		"shatter":
			return ParticleConfig.EffectType.STATUS_SHATTER
		"weaken":
			return ParticleConfig.EffectType.STATUS_WEAKEN
		"haste":
			return ParticleConfig.EffectType.STATUS_HASTE
		"power_up":
			return ParticleConfig.EffectType.STATUS_POWER_UP
		"fortify":
			return ParticleConfig.EffectType.STATUS_FORTIFY
		"energize":
			return ParticleConfig.EffectType.STATUS_HASTE
		_:
			return -1


## Get the particle manager from the scene
func _get_particle_manager(unit: UnitBase) -> ParticleManager:
	var scene_root: Node = unit.get_tree().current_scene
	var session := scene_root.get_node_or_null("BattleSession")
	if not session:
		return null
	return session.get_node_or_null("ParticleManager") as ParticleManager


func _get_battle_hud(unit: UnitBase) -> BattleHud:
	var scene_root: Node = unit.get_tree().current_scene
	return scene_root.get_node_or_null("BattleSession/BattleHud") as BattleHud


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


