class_name ParticleManager
extends Node

## Centralized particle effect manager for attacks and skills.
## Attach this script to a Node in the battle scene.

## Active particle instances being tracked
var _active_particles: Array[Node3D] = []

## Pre-configured effect presets
var _presets: Dictionary = {}


func _ready() -> void:
	_setup_presets()


## Setup default particle presets
func _setup_presets() -> void:
	_presets[ParticleConfig.EffectType.ATTACK_BULLET] = ParticleConfig.new(
		ParticleConfig.EffectType.ATTACK_BULLET, Color(1.0, 0.9, 0.3), 1.0, 0.3, 1.0
	)
	_presets[ParticleConfig.EffectType.ATTACK_EXPLOSION] = ParticleConfig.new(
		ParticleConfig.EffectType.ATTACK_EXPLOSION, Color(1.0, 0.6, 0.1), 1.5, 0.4, 1.0
	)
	_presets[ParticleConfig.EffectType.ATTACK_SPARK] = ParticleConfig.new(
		ParticleConfig.EffectType.ATTACK_SPARK, Color(1.0, 1.0, 0.8), 0.8, 0.25, 1.0
	)
	_presets[ParticleConfig.EffectType.ATTACK_SLASH] = ParticleConfig.new(
		ParticleConfig.EffectType.ATTACK_SLASH, Color(0.9, 0.9, 1.0), 1.2, 0.2, 1.0
	)
	_presets[ParticleConfig.EffectType.SKILL_DAMAGE_GENERIC] = ParticleConfig.new(
		ParticleConfig.EffectType.SKILL_DAMAGE_GENERIC, Color(1.0, 0.3, 0.3), 1.0, 0.4, 1.0
	)
	_presets[ParticleConfig.EffectType.SKILL_DAMAGE_FIRE] = ParticleConfig.new(
		ParticleConfig.EffectType.SKILL_DAMAGE_FIRE, Color(1.0, 0.4, 0.1), 1.3, 0.5, 1.2
	)
	_presets[ParticleConfig.EffectType.SKILL_DAMAGE_ICE] = ParticleConfig.new(
		ParticleConfig.EffectType.SKILL_DAMAGE_ICE, Color(0.5, 0.8, 1.0), 1.2, 0.5, 1.0
	)
	_presets[ParticleConfig.EffectType.SKILL_DAMAGE_ELECTRIC] = ParticleConfig.new(
		ParticleConfig.EffectType.SKILL_DAMAGE_ELECTRIC, Color(0.8, 0.9, 1.0), 1.1, 0.35, 1.3
	)
	_presets[ParticleConfig.EffectType.SKILL_BUFF_UP] = ParticleConfig.new(
		ParticleConfig.EffectType.SKILL_BUFF_UP, Color(0.3, 1.0, 0.3), 1.0, 0.6, 1.0
	)
	_presets[ParticleConfig.EffectType.SKILL_DEBUFF_DOWN] = ParticleConfig.new(
		ParticleConfig.EffectType.SKILL_DEBUFF_DOWN, Color(0.8, 0.2, 0.8), 1.0, 0.6, 1.0
	)
	_presets[ParticleConfig.EffectType.SKILL_SHIELD] = ParticleConfig.new(
		ParticleConfig.EffectType.SKILL_SHIELD, Color(0.3, 0.6, 1.0), 1.4, 0.8, 1.0
	)
	_presets[ParticleConfig.EffectType.SKILL_HEAL] = ParticleConfig.new(
		ParticleConfig.EffectType.SKILL_HEAL, Color(0.3, 1.0, 0.5), 1.2, 0.7, 1.0
	)
	_presets[ParticleConfig.EffectType.SKILL_AOE_RING] = ParticleConfig.new(
		ParticleConfig.EffectType.SKILL_AOE_RING, Color(1.0, 0.5, 0.2), 2.0, 0.5, 1.0
	)
	_presets[ParticleConfig.EffectType.SKILL_TELEPORT] = ParticleConfig.new(
		ParticleConfig.EffectType.SKILL_TELEPORT, Color(0.5, 0.8, 1.0), 1.5, 0.6, 1.0
	)
	_presets[ParticleConfig.EffectType.SKILL_TURRET_DEPLOY] = ParticleConfig.new(
		ParticleConfig.EffectType.SKILL_TURRET_DEPLOY, Color(0.6, 0.8, 0.6), 1.0, 0.8, 1.0
	)
	_presets[ParticleConfig.EffectType.SKILL_TAUNT] = ParticleConfig.new(
		ParticleConfig.EffectType.SKILL_TAUNT, Color(1.0, 0.3, 0.3), 1.2, 0.5, 1.0
	)
	_presets[ParticleConfig.EffectType.STATUS_SLOW] = ParticleConfig.new(
		ParticleConfig.EffectType.STATUS_SLOW, Color(0.5, 0.7, 0.9), 0.8, 0.5, 0.7
	)
	_presets[ParticleConfig.EffectType.STATUS_SHATTER] = ParticleConfig.new(
		ParticleConfig.EffectType.STATUS_SHATTER, Color(0.8, 0.8, 0.9), 1.0, 0.4, 1.0
	)
	_presets[ParticleConfig.EffectType.STATUS_WEAKEN] = ParticleConfig.new(
		ParticleConfig.EffectType.STATUS_WEAKEN, Color(0.7, 0.5, 0.7), 0.8, 0.5, 0.7
	)
	_presets[ParticleConfig.EffectType.STATUS_HASTE] = ParticleConfig.new(
		ParticleConfig.EffectType.STATUS_HASTE, Color(0.3, 1.0, 0.8), 0.8, 0.5, 0.8
	)
	_presets[ParticleConfig.EffectType.STATUS_POWER_UP] = ParticleConfig.new(
		ParticleConfig.EffectType.STATUS_POWER_UP, Color(1.0, 0.8, 0.2), 1.0, 0.6, 1.0
	)
	_presets[ParticleConfig.EffectType.STATUS_FORTIFY] = ParticleConfig.new(
		ParticleConfig.EffectType.STATUS_FORTIFY, Color(0.6, 0.8, 1.0), 1.0, 0.6, 0.9
	)


## Play a particle effect at a position
func play_effect(effect_type: int, world_position: Vector3, custom_config: ParticleConfig = null) -> void:
	var config: ParticleConfig = custom_config if custom_config else _get_preset(effect_type)
	if not config:
		return
	var particle_node := _create_particle_node(config)
	add_child(particle_node)
	particle_node.global_position = world_position
	_active_particles.append(particle_node)
	_animate_and_cleanup(particle_node, config)


## Play a particle effect attached to a unit
func play_effect_on_unit(effect_type: int, unit: Node3D, offset: Vector3 = Vector3.ZERO, custom_config: ParticleConfig = null) -> void:
	var config: ParticleConfig = custom_config if custom_config else _get_preset(effect_type)
	if not config:
		return
	var particle_node := _create_particle_node(config)
	add_child(particle_node)
	var world_pos := unit.global_position + offset
	particle_node.global_position = world_pos
	_active_particles.append(particle_node)
	_animate_and_cleanup(particle_node, config)


## Play a projectile effect from start to end position
func play_projectile(effect_type: int, start_pos: Vector3, end_pos: Vector3, custom_config: ParticleConfig = null) -> void:
	var config: ParticleConfig = custom_config if custom_config else _get_preset(effect_type)
	if not config:
		return
	var projectile := _create_projectile_node(config)
	add_child(projectile)
	projectile.global_position = start_pos
	_active_particles.append(projectile)
	_animate_projectile(projectile, config, start_pos, end_pos)


## Play an AOE ring effect at a position
func play_aoe_ring(world_position: Vector3, radius: float = 1.0, custom_config: ParticleConfig = null) -> void:
	var config: ParticleConfig = custom_config if custom_config else _get_preset(ParticleConfig.EffectType.SKILL_AOE_RING)
	if not config:
		return
	var ring := _create_aoe_ring_node(config, radius)
	add_child(ring)
	ring.global_position = world_position
	_active_particles.append(ring)
	_animate_aoe_ring(ring, config, radius)


## Get a preset configuration
func _get_preset(effect_type: int) -> ParticleConfig:
	if _presets.has(effect_type):
		return _presets[effect_type]
	return null


## Create a particle node based on effect type
func _create_particle_node(config: ParticleConfig) -> Node3D:
	var container := Node3D.new()
	container.name = "Particle_%s" % str(config.effect_type)
	
	var et: int = config.effect_type
	
	if et == ParticleConfig.EffectType.ATTACK_BULLET:
		_create_bullet_trail(container, config)
	elif et == ParticleConfig.EffectType.ATTACK_EXPLOSION:
		_create_explosion(container, config)
	elif et == ParticleConfig.EffectType.ATTACK_SPARK:
		_create_spark(container, config)
	elif et == ParticleConfig.EffectType.ATTACK_SLASH:
		_create_slash(container, config)
	elif et == ParticleConfig.EffectType.SKILL_DAMAGE_GENERIC or et == ParticleConfig.EffectType.SKILL_DAMAGE_FIRE or et == ParticleConfig.EffectType.SKILL_DAMAGE_ICE or et == ParticleConfig.EffectType.SKILL_DAMAGE_ELECTRIC:
		_create_damage_burst(container, config)
	elif et == ParticleConfig.EffectType.SKILL_BUFF_UP:
		_create_burst_up(container, config)
	elif et == ParticleConfig.EffectType.SKILL_DEBUFF_DOWN:
		_create_burst_down(container, config)
	elif et == ParticleConfig.EffectType.SKILL_SHIELD:
		_create_shield(container, config)
	elif et == ParticleConfig.EffectType.SKILL_HEAL:
		_create_heal(container, config)
	elif et == ParticleConfig.EffectType.SKILL_AOE_RING:
		_create_aoe_ring_mesh(container, config)
	elif et == ParticleConfig.EffectType.SKILL_TELEPORT:
		_create_teleport(container, config)
	elif et == ParticleConfig.EffectType.SKILL_TURRET_DEPLOY:
		_create_turret_deploy(container, config)
	elif et == ParticleConfig.EffectType.SKILL_TAUNT:
		_create_taunt(container, config)
	elif et == ParticleConfig.EffectType.STATUS_SLOW:
		_create_status_indicator(container, config)
	elif et == ParticleConfig.EffectType.STATUS_SHATTER:
		_create_status_indicator(container, config)
	elif et == ParticleConfig.EffectType.STATUS_WEAKEN:
		_create_status_indicator(container, config)
	elif et == ParticleConfig.EffectType.STATUS_HASTE:
		_create_status_indicator(container, config)
	elif et == ParticleConfig.EffectType.STATUS_POWER_UP:
		_create_status_indicator(container, config)
	elif et == ParticleConfig.EffectType.STATUS_FORTIFY:
		_create_status_indicator(container, config)
	else:
		_create_default_burst(container, config)
	
	return container


## Create bullet trail effect
func _create_bullet_trail(container: Node3D, config: ParticleConfig) -> void:
	var line := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 4
	mesh.top_radius = 0.015 * config.scale
	mesh.bottom_radius = 0.015 * config.scale
	mesh.height = 0.3
	line.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = config.color
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = config.color
	mat.emission_energy_multiplier = 2.0 * config.intensity
	line.material_override = mat
	line.rotation = Vector3(0, 0, PI / 2)
	container.add_child(line)


## Create explosion effect
func _create_explosion(container: Node3D, config: ParticleConfig) -> void:
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.15 * config.scale
	core_mesh.height = 0.3 * config.scale
	core_mesh.radial_segments = 12
	core_mesh.rings = 6
	core.mesh = core_mesh
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = config.color
	core_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	core_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	core_mat.emission_enabled = true
	core_mat.emission = config.color
	core_mat.emission_energy_multiplier = 3.0 * config.intensity
	core.material_override = core_mat
	container.add_child(core)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.2 * config.scale
	ring_mesh.outer_radius = 0.3 * config.scale
	ring_mesh.ring_segments = 8
	ring_mesh.sides = 16
	ring.mesh = ring_mesh
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = config.color.lightened(0.3)
	ring_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.emission_enabled = true
	ring_mat.emission = config.color
	ring_mat.emission_energy_multiplier = 1.5 * config.intensity
	ring.material_override = ring_mat
	container.add_child(ring)


## Create spark effect
func _create_spark(container: Node3D, config: ParticleConfig) -> void:
	for i in range(6):
		var spark := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.03 * config.scale
		mesh.height = 0.06 * config.scale
		mesh.radial_segments = 6
		mesh.rings = 3
		spark.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = config.color
		mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = config.color
		mat.emission_energy_multiplier = 2.5 * config.intensity
		spark.material_override = mat
		var angle := (i / 6.0) * TAU
		spark.position = Vector3(cos(angle), sin(angle), 0) * 0.1
		container.add_child(spark)


## Create slash effect
func _create_slash(container: Node3D, config: ParticleConfig) -> void:
	var slash := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.6 * config.scale, 0.08 * config.scale)
	slash.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = config.color
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = config.color
	mat.emission_energy_multiplier = 2.0 * config.intensity
	mat.billboard_mode = StandardMaterial3D.BILLBOARD_ENABLED
	slash.material_override = mat
	container.add_child(slash)


## Create damage burst effect
func _create_damage_burst(container: Node3D, config: ParticleConfig) -> void:
	var flash := MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.1 * config.scale
	flash_mesh.height = 0.2 * config.scale
	flash_mesh.radial_segments = 8
	flash_mesh.rings = 4
	flash.mesh = flash_mesh
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = config.color
	flash_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.emission_enabled = true
	flash_mat.emission = config.color
	flash_mat.emission_energy_multiplier = 3.0 * config.intensity
	flash.material_override = flash_mat
	container.add_child(flash)
	for i in range(4):
		var spike := MeshInstance3D.new()
		var spike_mesh := CylinderMesh.new()
		spike_mesh.radial_segments = 3
		spike_mesh.top_radius = 0.0
		spike_mesh.bottom_radius = 0.03 * config.scale
		spike_mesh.height = 0.2 * config.scale
		spike.mesh = spike_mesh
		var spike_mat := StandardMaterial3D.new()
		spike_mat.albedo_color = config.color.lightened(0.2)
		spike_mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
		spike_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		spike_mat.emission_enabled = true
		spike_mat.emission = config.color
		spike_mat.emission_energy_multiplier = 2.0 * config.intensity
		spike.material_override = spike_mat
		var angle := (i / 4.0) * TAU
		spike.position = Vector3(cos(angle), sin(angle), 0) * 0.15
		spike.rotation = Vector3(0, 0, angle)
		container.add_child(spike)


## Create upward burst (buff)
func _create_burst_up(container: Node3D, config: ParticleConfig) -> void:
	for i in range(5):
		var particle := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.04 * config.scale
		mesh.height = 0.08 * config.scale
		mesh.radial_segments = 6
		mesh.rings = 3
		particle.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = config.color
		mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = config.color
		mat.emission_energy_multiplier = 2.0 * config.intensity
		particle.material_override = mat
		var offset := Vector3(randf_range(-0.15, 0.15), 0.0, randf_range(-0.15, 0.15))
		particle.position = offset
		container.add_child(particle)


## Create downward burst (debuff)
func _create_burst_down(container: Node3D, config: ParticleConfig) -> void:
	for i in range(5):
		var particle := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.04 * config.scale
		mesh.height = 0.08 * config.scale
		mesh.radial_segments = 6
		mesh.rings = 3
		particle.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = config.color
		mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = config.color
		mat.emission_energy_multiplier = 2.0 * config.intensity
		particle.material_override = mat
		var offset := Vector3(randf_range(-0.15, 0.15), 0.0, randf_range(-0.15, 0.15))
		particle.position = offset
		container.add_child(particle)


## Create shield effect
func _create_shield(container: Node3D, config: ParticleConfig) -> void:
	var shield := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.4 * config.scale
	mesh.height = 0.8 * config.scale
	mesh.radial_segments = 16
	mesh.rings = 8
	shield.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = config.color
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = config.color
	mat.emission_energy_multiplier = 1.0 * config.intensity
	mat.cull_mode = StandardMaterial3D.CULL_FRONT
	shield.material_override = mat
	container.add_child(shield)


## Create heal effect
func _create_heal(container: Node3D, config: ParticleConfig) -> void:
	for i in range(2):
		var bar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		if i == 0:
			mesh.size = Vector3(0.3 * config.scale, 0.08 * config.scale, 0.05 * config.scale)
		else:
			mesh.size = Vector3(0.08 * config.scale, 0.3 * config.scale, 0.05 * config.scale)
		bar.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = config.color
		mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = config.color
		mat.emission_energy_multiplier = 2.0 * config.intensity
		bar.material_override = mat
		container.add_child(bar)


## Create AOE ring mesh
func _create_aoe_ring_mesh(container: Node3D, config: ParticleConfig) -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.3 * config.scale
	mesh.outer_radius = 0.4 * config.scale
	mesh.ring_segments = 8
	mesh.sides = 24
	ring.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = config.color
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = config.color
	mat.emission_energy_multiplier = 1.5 * config.intensity
	ring.material_override = mat
	container.add_child(ring)


## Create teleport effect
func _create_teleport(container: Node3D, config: ParticleConfig) -> void:
	for i in range(8):
		var particle := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.03 * config.scale
		mesh.height = 0.06 * config.scale
		mesh.radial_segments = 6
		mesh.rings = 3
		particle.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = config.color
		mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = config.color
		mat.emission_energy_multiplier = 2.0 * config.intensity
		particle.material_override = mat
		var angle := (i / 8.0) * TAU
		particle.position = Vector3(cos(angle), 0, sin(angle)) * 0.2
		container.add_child(particle)


## Create turret deploy effect
func _create_turret_deploy(container: Node3D, config: ParticleConfig) -> void:
	var base := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 8
	mesh.top_radius = 0.15 * config.scale
	mesh.bottom_radius = 0.2 * config.scale
	mesh.height = 0.05 * config.scale
	base.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = config.color
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = config.color
	mat.emission_energy_multiplier = 1.5 * config.intensity
	base.material_override = mat
	container.add_child(base)


## Create taunt effect
func _create_taunt(container: Node3D, config: ParticleConfig) -> void:
	var vertical := MeshInstance3D.new()
	var v_mesh := BoxMesh.new()
	v_mesh.size = Vector3(0.06 * config.scale, 0.25 * config.scale, 0.03 * config.scale)
	vertical.mesh = v_mesh
	vertical.position.y = 0.15
	var mat := StandardMaterial3D.new()
	mat.albedo_color = config.color
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = config.color
	mat.emission_energy_multiplier = 2.0 * config.intensity
	vertical.material_override = mat
	container.add_child(vertical)
	var dot := MeshInstance3D.new()
	var d_mesh := SphereMesh.new()
	d_mesh.radius = 0.04 * config.scale
	d_mesh.height = 0.08 * config.scale
	d_mesh.radial_segments = 6
	d_mesh.rings = 3
	dot.mesh = d_mesh
	dot.position.y = -0.05
	dot.material_override = mat
	container.add_child(dot)


## Create status indicator
func _create_status_indicator(container: Node3D, config: ParticleConfig) -> void:
	var indicator := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.06 * config.scale
	mesh.height = 0.12 * config.scale
	mesh.radial_segments = 8
	mesh.rings = 4
	indicator.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = config.color
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = config.color
	mat.emission_energy_multiplier = 1.5 * config.intensity
	indicator.material_override = mat
	container.add_child(indicator)


## Create default burst
func _create_default_burst(container: Node3D, config: ParticleConfig) -> void:
	var burst := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.1 * config.scale
	mesh.height = 0.2 * config.scale
	mesh.radial_segments = 8
	mesh.rings = 4
	burst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = config.color
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = config.color
	mat.emission_energy_multiplier = 2.0 * config.intensity
	burst.material_override = mat
	container.add_child(burst)


## Create a projectile node
func _create_projectile_node(config: ParticleConfig) -> Node3D:
	var container := Node3D.new()
	container.name = "Projectile"
	var projectile := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.04 * config.scale
	mesh.height = 0.08 * config.scale
	mesh.radial_segments = 6
	mesh.rings = 3
	projectile.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = config.color
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = config.color
	mat.emission_energy_multiplier = 3.0 * config.intensity
	projectile.material_override = mat
	container.add_child(projectile)
	return container


## Create AOE ring node
func _create_aoe_ring_node(config: ParticleConfig, radius: float) -> Node3D:
	var container := Node3D.new()
	container.name = "AOE_Ring"
	var ring := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 24
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.02
	ring.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = config.color
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = config.color
	mat.emission_energy_multiplier = 1.5 * config.intensity
	ring.material_override = mat
	container.add_child(ring)
	return container


## Animate particle and clean up
func _animate_and_cleanup(particle_node: Node3D, config: ParticleConfig) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	for child in particle_node.get_children():
		if child is MeshInstance3D:
			var mesh_instance: MeshInstance3D = child
			tween.tween_property(mesh_instance, "scale", Vector3.ONE * 1.5, config.duration * 0.3)
			tween.tween_property(mesh_instance, "scale", Vector3.ONE * 0.1, config.duration * 0.7)
	tween.tween_property(particle_node, "scale", Vector3.ZERO, config.duration)
	tween.tween_callback(func():
		_active_particles.erase(particle_node)
		if is_instance_valid(particle_node):
			particle_node.queue_free()
	)


## Animate projectile from start to end
func _animate_projectile(projectile: Node3D, config: ParticleConfig, start_pos: Vector3, end_pos: Vector3) -> void:
	var tween := create_tween()
	var travel_duration: float = config.duration * 0.6
	tween.tween_property(projectile, "global_position", end_pos, travel_duration)
	tween.tween_callback(func():
		if is_instance_valid(projectile):
			var fade_tween := create_tween()
			fade_tween.tween_property(projectile, "scale", Vector3.ZERO, config.duration * 0.4)
			fade_tween.tween_callback(func():
				_active_particles.erase(projectile)
				if is_instance_valid(projectile):
					projectile.queue_free()
			)
	)


## Animate AOE ring
func _animate_aoe_ring(ring: Node3D, config: ParticleConfig, target_radius: float) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(target_radius, 1, target_radius), config.duration * 0.5)
	tween.tween_property(ring, "scale", Vector3.ZERO, config.duration)
	tween.tween_callback(func():
		_active_particles.erase(ring)
		if is_instance_valid(ring):
			ring.queue_free()
	)


## Clear all active particles
func clear_all() -> void:
	for particle in _active_particles:
		if is_instance_valid(particle):
			particle.queue_free()
	_active_particles.clear()


## Get count of active particles (for debugging)
func get_active_count() -> int:
	return _active_particles.size()