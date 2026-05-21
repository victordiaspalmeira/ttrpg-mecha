class_name CinematicPlayer
extends Node

## Default duration for the whole cinematic sequence in seconds.
const DEFAULT_TOTAL_DURATION := 1.2

var _original_camera_pos: Vector3
var _camera: Camera3D = null
var _camera_rig: Node3D = null


## Plays a combat cinematic: zooms smoothly on target, triggers particles/animation,
## then returns to the current turn unit.
func play_attack_cinematic(
	attacker: UnitBase,
	target: UnitBase,
	on_impact: Callable,
	particle_manager: ParticleManager,
) -> void:
	var battle_hud := _get_battle_hud(attacker)
	if not battle_hud:
		on_impact.call()
		return

	_camera = battle_hud.camera
	_camera_rig = battle_hud.camera_controller

	# Store original camera position for later restore
	if _camera_rig:
		_original_camera_pos = _camera_rig.global_position
	else:
		_original_camera_pos = _camera.global_position if _camera else Vector3.ZERO

	# Cache target position at start of cinematic (target may die during the sequence)
	var target_cached_pos: Vector3 = target.global_position
	var attacker_cached_pos: Vector3 = attacker.global_position

	# Run the cinematic sequence
	var tween := create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.set_parallel(false)

	# Phase 1: Smooth zoom to target (0.35s)
	if _camera_rig:
		var target_pos := target_cached_pos + Vector3(0, 1.2, 0)
		tween.tween_property(_camera_rig, "global_position", target_pos, 0.35)

	# Phase 2: Particles + unit animation (0.45s)
	tween.tween_callback(func():
		if particle_manager:
			var start_pos := attacker_cached_pos + Vector3.UP * 0.5
			var end_pos := target_cached_pos + Vector3.UP * 0.5
			particle_manager.play_projectile(ParticleConfig.EffectType.ATTACK_BULLET, start_pos, end_pos)
		attacker.play_attack_visual()
	)

	# Phase 3: Impact - particles + damage application (0.35s after phase 2)
	tween.tween_interval(0.35)
	tween.tween_callback(func():
		if particle_manager:
			var impact_pos := target_cached_pos + Vector3.UP * 0.5
			particle_manager.play_effect(ParticleConfig.EffectType.ATTACK_SPARK, impact_pos)
		# Apply damage and show popup (on_impact calls _apply_attack_damage + show_damage_popup)
		on_impact.call()
	)

	# Phase 4: Wait for death animation / feedback to finish, then restore camera
	tween.tween_interval(0.7)
	if _camera_rig:
		# Return to the current turn unit instead of original position
		var restore_pos := _original_camera_pos
		var turn_unit := _get_current_turn_unit(battle_hud)
		if turn_unit and is_instance_valid(turn_unit):
			restore_pos = turn_unit.global_position + Vector3(0, 1.2, 0)
		tween.tween_property(_camera_rig, "global_position", restore_pos, 0.35)


## Plays a skill cinematic: zooms on caster or target area.
func play_skill_cinematic(
	caster: UnitBase,
	targets: Array[UnitBase],
	primary_effect: int,
	on_impact: Callable,
	particle_manager: ParticleManager,
) -> void:
	var battle_hud := _get_battle_hud(caster)
	if not battle_hud:
		on_impact.call()
		return

	_camera = battle_hud.camera
	_camera_rig = battle_hud.camera_controller

	# Store original camera position
	if _camera_rig:
		_original_camera_pos = _camera_rig.global_position
	else:
		_original_camera_pos = _camera.global_position if _camera else Vector3.ZERO

	# Determine focus: if self-only (caster is the only target), zoom on caster
	var focus_pos: Vector3
	var is_self_target := targets.size() == 1 and targets[0] == caster
	if is_self_target:
		focus_pos = caster.global_position + Vector3(0, 1.2, 0)
	else:
		focus_pos = caster.global_position
		if not targets.is_empty():
			focus_pos = Vector3.ZERO
			for t in targets:
				focus_pos += t.global_position
			focus_pos /= targets.size()
		focus_pos.y = 0.5

	# Run cinematic sequence
	var tween := create_tween()
	tween.set_parallel(false)

	# Phase 1: Zoom (0.3s)
	if _camera_rig:
		tween.tween_property(_camera_rig, "global_position", focus_pos, 0.3)

	# Phase 2: Particles on each target (0.35s)
	tween.tween_callback(func():
		caster.play_attack_visual()
		for unit in targets:
			if particle_manager:
				var pos := unit.global_position + Vector3.UP * 0.5
				particle_manager.play_effect(primary_effect, pos)
	)

	# Phase 3: Show results (0.2s)
	tween.tween_interval(0.2)
	tween.tween_callback(func():
		on_impact.call()
	)

	# Phase 4: Wait for animations, then restore camera
	tween.tween_interval(0.5)
	if _camera_rig:
		# Return to the current turn unit instead of original position
		var restore_pos := _original_camera_pos
		var turn_unit := _get_current_turn_unit(battle_hud)
		if turn_unit and is_instance_valid(turn_unit):
			restore_pos = turn_unit.global_position + Vector3(0, 1.2, 0)
		tween.tween_property(_camera_rig, "global_position", restore_pos, 0.35)


## Returns the unit currently taking its turn.
func _get_current_turn_unit(battle_hud: BattleHud) -> UnitBase:
	if not battle_hud:
		return null
	var tc = battle_hud.get("turn_controller")
	if tc:
		return tc.get("current_unit") as UnitBase
	return null


func _get_battle_hud(unit: UnitBase) -> BattleHud:
	var scene_root: Node = unit.get_tree().current_scene
	return scene_root.get_node_or_null("BattleSession/BattleHud") as BattleHud
