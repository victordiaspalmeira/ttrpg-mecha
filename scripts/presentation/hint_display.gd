class_name HintDisplay
extends Node

## Manages the hint label with error feedback and auto-restore.

const COLOR_HINT_NORMAL := Color(0.78, 0.82, 0.88, 1.0)
const COLOR_HINT_ERROR := Color(1.0, 0.55, 0.42, 1.0)

var hint_label = null
var _default_hint := "Move, use actions, then end turn."
var _battle_finished := false
var _feedback_restore_timer: SceneTreeTimer = null
var _display_unit: UnitBase = null


func setup(p_hint_label) -> void:
	hint_label = p_hint_label
	if hint_label:
		hint_label.add_theme_color_override("font_color", COLOR_HINT_NORMAL)


func set_default_hint(text: String) -> void:
	_default_hint = text


func set_battle_finished(finished: bool) -> void:
	_battle_finished = finished


func set_display_unit(unit: UnitBase) -> void:
	_display_unit = unit


func show_error(message: String, duration := 2.2) -> void:
	if message.is_empty() or not hint_label:
		return

	if _feedback_restore_timer:
		_feedback_restore_timer.timeout.disconnect(_restore)
	hint_label.text = message
	hint_label.add_theme_color_override("font_color", COLOR_HINT_ERROR)
	_feedback_restore_timer = get_tree().create_timer(duration)
	_feedback_restore_timer.timeout.connect(_restore, CONNECT_ONE_SHOT)


func _restore() -> void:
	_feedback_restore_timer = null
	if hint_label:
		hint_label.add_theme_color_override("font_color", COLOR_HINT_NORMAL)
		_restore_default()


func _restore_default() -> void:
	if _battle_finished or not hint_label:
		return

	if _display_unit and _display_unit.team_id == "player":
		hint_label.text = _default_hint
	elif _display_unit:
		hint_label.text = "Enemy is acting..."
	else:
		hint_label.text = _default_hint