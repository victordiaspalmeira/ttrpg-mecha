extends Control

## Main menu — simple hub screen.
## PLAY navigates to mission selection, other buttons go to their respective screens.

@onready var play_button: Button = %PlayButton
@onready var editor_button: Button = %EditorButton
@onready var test_button: Button = %TestButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	editor_button.pressed.connect(_on_editor_pressed)
	test_button.pressed.connect(_on_test_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Hover sounds
	play_button.mouse_entered.connect(_on_hover)
	editor_button.mouse_entered.connect(_on_hover)
	test_button.mouse_entered.connect(_on_hover)
	quit_button.mouse_entered.connect(_on_hover)
	
	# Confirm sounds
	play_button.pressed.connect(_on_confirm)
	editor_button.pressed.connect(_on_confirm)
	test_button.pressed.connect(_on_confirm)
	quit_button.pressed.connect(_on_confirm)
	
	# Fade in
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)


func _on_hover() -> void:
	SoundManager.play_hover()


func _on_confirm() -> void:
	SoundManager.play_confirm()


func _on_play_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/ui/mission_select.tscn")


func _on_editor_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/editor/map_editor.tscn")


func _on_test_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/ui/test_scene.tscn")


func _on_quit_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	GameManager.quit_game()