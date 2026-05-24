class_name TileFlashEffect
extends Node

## Flashes a tile red briefly to indicate invalid action.
func flash_tile_red(tile: HexTile) -> void:
	if not tile or not tile.highlight_overlay:
		return
	var overlay := tile.highlight_overlay
	overlay.visible = true
	
	# Create a red material for the flash
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.2, 0.6)
	mat.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA
	overlay.material_override = mat
	
	# Fade out by tweening material's albedo alpha
	var tween := create_tween()
	tween.tween_method(_fade_overlay.bind(overlay), 0.6, 0.0, 0.4)
	tween.tween_callback(_reset_overlay.bind(overlay))


## Tween callback: updates the overlay material alpha.
func _fade_overlay(alpha: float, overlay: Node) -> void:
	if not is_instance_valid(overlay):
		return
	var mat: Material = overlay.get("material_override")
	if mat:
		mat.albedo_color.a = alpha


## Tween callback: hides and cleans up the overlay.
func _reset_overlay(overlay: Node) -> void:
	if not is_instance_valid(overlay):
		return
	overlay.set("visible", false)
	overlay.set("material_override", null)