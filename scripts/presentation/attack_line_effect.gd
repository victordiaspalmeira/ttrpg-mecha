class_name AttackLineEffect
extends Node3D

## Shows a brief attack line between attacker and target positions.
func show_attack_line(from: Vector3, to: Vector3, world: Node3D) -> void:
	var line := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 4
	mesh.top_radius = 0.02
	mesh.bottom_radius = 0.02
	mesh.height = 1.0  # will be scaled
	line.mesh = mesh
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.2, 0.8)
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	line.material_override = mat
	
	world.add_child(line)
	
	var start_pos := from
	var end_pos := to
	var mid_point := (start_pos + end_pos) / 2.0
	var direction := (end_pos - start_pos)
	var length := direction.length()
	
	line.global_position = mid_point
	line.look_at(end_pos, Vector3.UP)
	line.scale = Vector3(1, 1, length)
	
	# Fade out
	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.3)
	tween.tween_callback(line.queue_free)