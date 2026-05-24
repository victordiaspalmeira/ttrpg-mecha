extends Control

var missions: Array = []
var selected = null
var buttons: Array = []

@onready var list: VBoxContainer = $VMain/BodyPanel/HBody/LeftPanel/LeftVBox/ScrollContainer/List
@onready var title_lbl: Label = $VMain/BodyPanel/HBody/RightPanel/RightVBox/Title
@onready var thumb: TextureRect = $VMain/BodyPanel/HBody/RightPanel/RightVBox/Thumbnail
@onready var desc_lbl: Label = $VMain/BodyPanel/HBody/RightPanel/RightVBox/Description
@onready var start_btn: Button = $VMain/BottomBar/StartButton
@onready var back_btn: Button = $VMain/TopBar/HBox/BackButton


func _ready() -> void:
	_build_ui()
	_load()
	_fade_in()


func _build_ui() -> void:
	# Style thumbnail (falls back to dark tint when no texture)
	thumb.custom_minimum_size = Vector2(0, 160)
	thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thumb.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.modulate = Color(0.12, 0.15, 0.2)

	# Style description
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.72, 0.82))
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Style title
	title_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	title_lbl.add_theme_font_size_override("font_size", 16)

	# Style start button
	start_btn.add_theme_color_override("font_color", Color(0.45, 0.9, 0.55))
	start_btn.add_theme_font_size_override("font_size", 16)
	start_btn.custom_minimum_size = Vector2(200, 40)

	# Hover sounds
	back_btn.mouse_entered.connect(_on_hover)
	start_btn.mouse_entered.connect(_on_hover)

	# Connect signals
	back_btn.pressed.connect(_back)
	start_btn.pressed.connect(_go)
	back_btn.pressed.connect(_on_confirm)
	start_btn.pressed.connect(_on_confirm)


func _on_hover() -> void:
	SoundManager.play_hover()


func _on_confirm() -> void:
	SoundManager.play_confirm()


func _load() -> void:
	missions = GameManager.encounters.duplicate()
	if missions.is_empty():
		var lbl := Label.new()
		lbl.text = "No missions found"
		lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(lbl)
		_show(null)
		return

	for m in missions:
		var btn := Button.new()
		btn.text = m.display_name
		btn.custom_minimum_size = Vector2(0, 40)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.1, 0.12, 0.16, 0.94)
		s.border_width_left = 2
		s.border_width_top = 2
		s.border_width_right = 2
		s.border_width_bottom = 2
		s.border_color = Color(0.28, 0.38, 0.52)
		s.corner_radius_top_left = 6
		s.corner_radius_top_right = 6
		s.corner_radius_bottom_right = 6
		s.corner_radius_bottom_left = 6
		btn.add_theme_stylebox_override("normal", s)
		var hs := s.duplicate()
		hs.border_color = Color(0.45, 0.75, 1.0)
		hs.bg_color = Color(0.12, 0.15, 0.2, 0.94)
		btn.add_theme_stylebox_override("hover", hs)
		btn.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(_pick.bind(m))
		btn.mouse_entered.connect(_on_hover)
		btn.pressed.connect(_on_confirm)
		buttons.append(btn)
		list.add_child(btn)

	_pick(missions[0])


func _pick(m) -> void:
	selected = m
	_show(m)
	for btn in buttons:
		var st = btn.get_theme_stylebox("normal") as StyleBoxFlat
		if st:
			st.border_color = Color(0.55, 0.85, 1.0) if btn.text == m.display_name else Color(0.28, 0.38, 0.52)


func _show(m) -> void:
	if m == null:
		title_lbl.text = ""
		desc_lbl.text = ""
		thumb.texture = null
		start_btn.disabled = true
		return
	title_lbl.text = m.display_name
	desc_lbl.text = m.description if m.description else ""
	start_btn.disabled = false
	if m.thumbnail:
		thumb.texture = m.thumbnail
		thumb.modulate = Color.WHITE
	else:
		thumb.texture = null
		thumb.modulate = Color(0.12, 0.15, 0.2)


func _go() -> void:
	if selected == null:
		return
	_fade_out()
	await get_tree().create_timer(0.3).timeout
	GameManager.start_encounter(selected)


func _back() -> void:
	_fade_out()
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _fade_in() -> void:
	modulate.a = 0.0
	var t = create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.3)


func _fade_out() -> void:
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)