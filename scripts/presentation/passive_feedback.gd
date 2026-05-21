class_name PassiveFeedback
extends Node

## Displays floating text feedback when passives trigger (e.g. "Charge +1!", "Close Quarters!")

## Node3D used as anchor for the floating label.
var _floating_root: Node3D = null


func setup(root: Node3D) -> void:
	_floating_root = root


## Shows a floating label above a unit that fades out.
static func show(unit: UnitBase, text: String, color: Color = Color.WHITE) -> void:
	if not is_instance_valid(unit):
		return

	# Create a Billboard label in 3D space
	var label := Label3D.new()
	label.text = text
	label.font_size = 24
	label.outline_size = 4
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.004

	# Position above the unit
	var world_pos := unit.global_position + Vector3(0, 2.5, 0)
	label.global_position = world_pos

	# Add to the world
	var world := _get_world(unit)
	if not world:
		return
	world.add_child(label)

	# Animate: float up + fade out
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", world_pos + Vector3(0, 1.0, 0), 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func():
		if is_instance_valid(label):
			label.queue_free()
	)


static func _get_world(unit: UnitBase) -> Node3D:
	var tree := unit.get_tree()
	if not tree:
		return null
	var scene := tree.current_scene
	if not scene:
		return null
	return scene.get_node_or_null("World") as Node3D