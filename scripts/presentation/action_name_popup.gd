class_name ActionNamePopup
extends Node

## Shows a centered popup with the action name, then fades out.

var _panel: PanelContainer = null
var _canvas_layer: CanvasLayer = null


func show_popup(action_name: String, duration := 1.2) -> void:
	# Clean up any previous popup
	_hide_popup()

	_panel = PanelContainer.new()

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.1, 0.85)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.55, 0.75, 1.0, 0.9)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = action_name
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(label)

	# Create a CanvasLayer as child of this node (already in scene tree)
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 10
	add_child(_canvas_layer)
	_canvas_layer.add_child(_panel)

	# Center the panel using viewport size
	var viewport := get_viewport()
	if viewport:
		var screen_size := viewport.get_visible_rect().size
		_panel.position = Vector2(screen_size.x / 2 - _panel.size.x / 2, 40)

	# Animate: fade in → wait → fade out → cleanup
	_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.15)
	tween.tween_interval(duration - 0.3)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.15)
	tween.finished.connect(_hide_popup)


func _hide_popup() -> void:
	if _panel and is_instance_valid(_panel):
		_panel.queue_free()
		_panel = null
	if _canvas_layer and is_instance_valid(_canvas_layer):
		_canvas_layer.queue_free()
		_canvas_layer = null