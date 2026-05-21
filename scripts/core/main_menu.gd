extends Control

@onready var encounter_list: VBoxContainer = %EncounterList
@onready var title_label: Label = %TitleLabel
@onready var quit_button: Button = %QuitButton
@onready var editor_button: Button = %EditorButton


func _ready() -> void:
	_populate_encounter_list()
	quit_button.pressed.connect(_on_quit_pressed)
	editor_button.pressed.connect(_on_editor_pressed)
	
	# Efeito de fade in
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)


func _populate_encounter_list() -> void:
	var encounters = GameManager.encounters
	
	if encounters.is_empty():
		var label := Label.new()
		label.text = "No encounters found."
		label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68, 1))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		encounter_list.add_child(label)
		return
	
	for encounter in encounters:
		var button := Button.new()
		button.text = encounter.display_name
		button.custom_minimum_size = Vector2(0, 48)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		
		# Estilo do botão
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.12, 0.16, 0.94)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.28, 0.38, 0.52, 1)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_right = 8
		style.corner_radius_bottom_left = 8
		button.add_theme_stylebox_override("normal", style)
		
		var hover_style = style.duplicate()
		hover_style.border_color = Color(0.45, 0.75, 1.0, 1.0)
		hover_style.bg_color = Color(0.12, 0.15, 0.2, 0.94)
		button.add_theme_stylebox_override("hover", hover_style)
		
		button.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 1))
		button.add_theme_font_size_override("font_size", 16)
		
		# Conectar sinais
		button.pressed.connect(_on_encounter_selected.bind(encounter))
		button.mouse_entered.connect(_on_button_hovered)
		
		encounter_list.add_child(button)


func _on_encounter_selected(encounter: Resource) -> void:
	# Fade out antes de mudar de cena
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	
	GameManager.start_encounter(encounter)


func _on_button_hovered() -> void:
	pass

func _on_editor_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/editor/map_editor.tscn")


func _on_quit_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	GameManager.quit_game()
