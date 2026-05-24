class_name CameraService
extends Node

## Briefly focuses the camera on a target unit's position.
func focus_on_unit(unit: UnitBase, camera_rig: Node3D) -> void:
	if not unit or not camera_rig:
		return
	if camera_rig.has_method("focus_on_unit"):
		camera_rig.focus_on_unit(unit)