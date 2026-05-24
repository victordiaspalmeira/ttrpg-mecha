extends Node

## Singleton que gerencia efeitos sonoros de UI (hover, confirmar, voltar).

var _hover: AudioStream
var _confirm: AudioStream
var _decline: AudioStream

var _player: AudioStreamPlayer


func _enter_tree() -> void:
	_hover = load("res://assets/audio/UI_Menu/001_Hover_01.wav")
	_confirm = load("res://assets/audio/UI_Menu/013_Confirm_03.wav")
	_decline = load("res://assets/audio/UI_Menu/029_Decline_09.wav")

	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	add_child(_player)


func play_hover() -> void:
	_player.stream = _hover
	_player.play()


func play_confirm() -> void:
	_player.stream = _confirm
	_player.play()


func play_decline() -> void:
	_player.stream = _decline
	_player.play()