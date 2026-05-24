class_name DamagePopupManager
extends Node

## Manages floating damage/heal/buff/debuff popups above units.

var damage_popup_scene: PackedScene = null
var damage_popup_container = null
var _camera: Camera3D = null


func setup(p_scene: PackedScene, p_container, p_camera: Camera3D) -> void:
	damage_popup_scene = p_scene
	damage_popup_container = p_container
	_camera = p_camera


## Shows a popup at a unit's position or at a world position.
## position_source can be a UnitBase or a Vector3.
func show_popup(position_source, amount: int, popup_type: String = "damage") -> void:
	if not damage_popup_scene or not damage_popup_container or not _camera:
		return

	var popup = damage_popup_scene.instantiate()
	damage_popup_container.add_child(popup)

	var world_pos: Vector3
	if position_source is UnitBase:
		if not is_instance_valid(position_source):
			return
		world_pos = position_source.global_position + Vector3.UP * (position_source.get_visual_top_y() + 0.25)
	else:
		world_pos = position_source + Vector3.UP * 1.5

	var screen_position = _camera.unproject_position(world_pos)

	popup.position = Vector2(screen_position.x - 20, screen_position.y - 40)

	var label: Label = popup.get_node("Label")

	match popup_type:
		"heal":
			label.text = "+" + str(amount)
			label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4, 1.0))
		"buff":
			label.text = "+" + str(amount)
			label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
		"debuff":
			label.text = str(amount)
			label.add_theme_color_override("font_color", Color(0.8, 0.3, 1.0, 1.0))
		"death":
			label.text = "DEAD"
			label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.1, 1.0))
			label.add_theme_font_size_override("font_size", 16)
		_:
			label.text = "-" + str(amount)
			label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2, 1.0))

	popup.scale = Vector2(0.5, 0.5)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "scale", Vector2(1.3, 1.3), 0.15)
	tween.tween_property(popup, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_property(popup, "position", popup.position + Vector2(0, -40), 0.4)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.4)
	tween.finished.connect(popup.queue_free)