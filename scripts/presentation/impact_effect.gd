class_name ImpactEffect
extends Node3D

## Shows a brief expanding ring effect at the target position.
func play_impact(at: Vector3, world: Node3D) -> void:
	if not world:
		return
	# Create a simple expanding ring effect
	var ring := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 16
	mesh.top_radius = 0.3
	mesh.bottom_radius = 0.3
	mesh.height = 0.02
	ring.mesh = mesh
	ring.global_position = at + Vector3.UP * 0.1
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.2, 0.7)
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	
	world.add_child(ring)
	
	# Expand and fade
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector3(2.5, 1, 2.5), 0.3)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.3)
	tween.tween_callback(ring.queue_free)