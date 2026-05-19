class_name TurnAnnounce
extends Control

signal announce_finished

@onready var _panel: PanelContainer = $Center/Panel
@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _dimmer: ColorRect = $Dimmer

const HOLD_TIME := 0.85
const FADE_TIME := 0.28

const PLAYER_BORDER := Color(0.35, 0.7, 1.0, 1.0)
const ENEMY_BORDER := Color(1.0, 0.45, 0.35, 1.0)
const PLAYER_TITLE := Color(0.75, 0.9, 1.0, 1.0)
const ENEMY_TITLE := Color(1.0, 0.8, 0.7, 1.0)

var _busy := false


func _ready() -> void:
	visible = false
	modulate.a = 0.0


func play_for_unit(unit: UnitBase) -> void:

	if not unit:
		return

	_busy = true
	visible = true
	_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP

	var is_player := unit.team == "player"

	if is_player:
		_title.text = "YOUR TURN"
		_title.add_theme_color_override("font_color", PLAYER_TITLE)
		_apply_border(PLAYER_BORDER)
	else:
		_title.text = "ENEMY TURN"
		_title.add_theme_color_override("font_color", ENEMY_TITLE)
		_apply_border(ENEMY_BORDER)

	_subtitle.text = _get_unit_display_name(unit)

	modulate.a = 0.0
	_dimmer.modulate.a = 0.0

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, FADE_TIME)
	tween.tween_property(_dimmer, "modulate:a", 1.0, FADE_TIME)

	await get_tree().create_timer(FADE_TIME + HOLD_TIME).timeout

	var fade_out = create_tween()
	fade_out.set_parallel(true)
	fade_out.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	fade_out.tween_property(_dimmer, "modulate:a", 0.0, FADE_TIME)

	await fade_out.finished

	visible = false
	_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	announce_finished.emit()


func is_busy() -> bool:
	return _busy


func play_message(
	title: String,
	subtitle: String,
	border_color: Color,
	title_color: Color = Color(1.0, 1.0, 1.0, 1.0)
) -> void:

	_busy = true
	visible = true
	_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_title.text = title
	_subtitle.text = subtitle
	_title.add_theme_color_override("font_color", title_color)
	_apply_border(border_color)

	modulate.a = 0.0
	_dimmer.modulate.a = 0.0

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, FADE_TIME)
	tween.tween_property(_dimmer, "modulate:a", 1.0, FADE_TIME)

	await get_tree().create_timer(FADE_TIME + HOLD_TIME + 0.35).timeout

	var fade_out = create_tween()
	fade_out.set_parallel(true)
	fade_out.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	fade_out.tween_property(_dimmer, "modulate:a", 0.0, FADE_TIME)

	await fade_out.finished

	visible = false
	_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	announce_finished.emit()


func _get_unit_display_name(unit: UnitBase) -> String:

	if unit.class_data and unit.class_data.display_name:
		return unit.class_data.display_name

	if unit.unit_name:
		return unit.unit_name

	return unit.team.capitalize()


func _apply_border(color: Color) -> void:

	var style := _panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat

	if style:
		style.border_color = color
		_panel.add_theme_stylebox_override("panel", style)
