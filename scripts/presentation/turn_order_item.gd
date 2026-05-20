extends PanelContainer

@onready var _label: Label = $Label

var _style_idle: StyleBoxFlat
var _style_active: StyleBoxFlat
var _team := ""


func _ready() -> void:
	_cache_styles()


func setup(unit: UnitBase) -> void:

	_cache_styles()

	_team = unit.team_id

	if unit.class_data and unit.class_data.display_name:
		_label.text = unit.class_data.display_name.substr(0, 1).to_upper()
	elif unit.team_id == "player":
		_label.text = "P"
	else:
		_label.text = "E"

	if unit.team_id == "enemy":
		_style_idle.border_color = Color(0.55, 0.32, 0.28, 1.0)
		_style_active.bg_color = Color(0.42, 0.18, 0.16, 1.0)
		_style_active.border_color = Color(1.0, 0.5, 0.35, 1.0)

	set_active(false)


func _cache_styles() -> void:

	if _style_idle:
		return

	_style_idle = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	_style_active = _style_idle.duplicate() as StyleBoxFlat
	_style_active.bg_color = Color(0.18, 0.28, 0.42, 1.0)
	_style_active.border_color = Color(0.45, 0.75, 1.0, 1.0)


func set_active(active: bool) -> void:

	if not _style_idle:
		_cache_styles()

	if active:
		add_theme_stylebox_override("panel", _style_active)
		_label.add_theme_color_override(
			"font_color",
			Color(1.0, 1.0, 1.0, 1.0)
		)
	else:
		add_theme_stylebox_override("panel", _style_idle)
		_label.add_theme_color_override(
			"font_color",
			Color(0.75, 0.78, 0.82, 1.0)
		)
