class_name UnitSpriteVisual
extends Node3D

const TEAM_OUTLINE_COLORS := {
	"player": Color(0.35, 0.72, 1.0, 1.0),
	"enemy": Color(1.0, 0.32, 0.24, 1.0),
}

const DEFAULT_OUTLINE := Color(0.85, 0.88, 0.92, 1.0)
const FRAME_HEIGHT_PX := 80
const FRAME_FOOT_OFFSET_Y := float(FRAME_HEIGHT_PX) / 2.0
const SURFACE_CLEARANCE := 0.03
const STAND_UP_ROTATION_X := PI / 2.0
const IDLE_ANIMATION := "idle"
const ATTACK_ANIMATION := "transform"

@export var sprite_frames: SpriteFrames
@export var default_animation := IDLE_ANIMATION
@export var pixel_size := 0.022
@export var outline_width := 2.5
@export var y_offset := 0.0
@export var use_placeholder_sheets := true
@export var use_outline_shader := true

@onready var _sprite_anchor: Node3D = $SpriteAnchor
@onready var _sprite: Sprite3D = $SpriteAnchor/Sprite3D

var _shader_material: ShaderMaterial = null
var _current_anim := ""
var _current_frame := 0
var _frame_time := 0.0
var _return_animation := ""
var _surface_y := 0.13
var _using_placeholder := false


func _ready() -> void:
	if sprite_frames == null and use_placeholder_sheets:
		sprite_frames = Gr1PlaceholderFrames.build()
		_using_placeholder = true

	_setup_sprite()

	if sprite_frames == null or sprite_frames.get_frame_count(default_animation) == 0:
		push_error("UnitSpriteVisual: placeholder frames failed to build; using idle sheet fallback")
		_sprite.texture = Gr1PlaceholderFrames.TEX_IDLE
		_apply_frame()
		return

	if sprite_frames.has_animation(default_animation):
		play(default_animation)
	else:
		push_warning("UnitSpriteVisual: no animation '%s' in sprite_frames" % default_animation)


func configure_surface(grid_config: GridConfig) -> void:
	if grid_config == null:
		return

	_surface_y = grid_config.get_surface_y() + SURFACE_CLEARANCE + y_offset

	if is_node_ready() and _sprite_anchor:
		_sprite_anchor.position.y = _surface_y


func get_sprite_top_y() -> float:
	var sprite_height := FRAME_HEIGHT_PX * pixel_size
	return _surface_y + sprite_height


func play(animation_name: String) -> void:
	if not sprite_frames or not sprite_frames.has_animation(animation_name):
		return

	_current_anim = animation_name
	_current_frame = 0
	_frame_time = 0.0
	_apply_frame()


func play_attack() -> void:
	if sprite_frames and sprite_frames.has_animation(ATTACK_ANIMATION):
		play_one_shot(ATTACK_ANIMATION, default_animation)
	else:
		play(default_animation)


func play_one_shot(animation_name: String, return_animation: String) -> void:
	if not sprite_frames or not sprite_frames.has_animation(animation_name):
		play(return_animation)
		return

	_return_animation = return_animation
	play(animation_name)


func apply_team(team: String) -> void:
	if not use_outline_shader or not _shader_material:
		return

	var color: Color = TEAM_OUTLINE_COLORS.get(team, DEFAULT_OUTLINE)
	_shader_material.set_shader_parameter("outline_color", color)


func _setup_sprite() -> void:
	if not _sprite_anchor or not _sprite:
		return

	_sprite_anchor.rotation = Vector3(STAND_UP_ROTATION_X, 0.0, 0.0)
	_sprite_anchor.position = Vector3(0.0, _surface_y, 0.0)
	_sprite.rotation = Vector3.ZERO
	_sprite.position = Vector3.ZERO
	_sprite.offset = Vector2(0.0, FRAME_FOOT_OFFSET_Y)
	_sprite.centered = true
	_sprite.pixel_size = pixel_size
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.axis = Vector3.AXIS_Y
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.render_priority = 1

	if not use_outline_shader or _using_placeholder:
		_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		return

	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED

	var shader := load("res://shaders/unit_sprite.gdshader") as Shader
	if shader == null:
		push_error("UnitSpriteVisual: failed to load unit_sprite.gdshader")
		use_outline_shader = false
		_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		return

	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	_shader_material.set_shader_parameter("outline_width", outline_width)


func _process(delta: float) -> void:
	if not sprite_frames or _current_anim.is_empty():
		return

	var speed := sprite_frames.get_animation_speed(_current_anim)
	if speed <= 0.0:
		return

	var frame_count := sprite_frames.get_frame_count(_current_anim)
	if frame_count < 1:
		return

	var loops := sprite_frames.get_animation_loop(_current_anim)
	if not loops and frame_count == 1:
		_finish_one_shot_if_needed()
		return

	if frame_count < 2 and loops:
		return

	_frame_time += delta
	var sec_per_frame := 1.0 / speed

	while _frame_time >= sec_per_frame:
		_frame_time -= sec_per_frame

		if loops:
			_current_frame = (_current_frame + 1) % frame_count
			_apply_frame()
			continue

		var next_frame := _current_frame + 1
		if next_frame >= frame_count:
			_finish_one_shot_if_needed()
			break

		_current_frame = next_frame
		_apply_frame()


func _finish_one_shot_if_needed() -> void:
	if _return_animation.is_empty():
		return

	var return_anim := _return_animation
	_return_animation = ""
	play(return_anim)


func _apply_frame() -> void:
	if not _sprite or not sprite_frames or _current_anim.is_empty():
		return

	var frame_tex := sprite_frames.get_frame_texture(_current_anim, _current_frame)
	if frame_tex == null:
		push_warning("UnitSpriteVisual: missing frame %s#%d" % [_current_anim, _current_frame])
		return

	_sprite.texture = frame_tex

	if use_outline_shader and _shader_material:
		_shader_material.set_shader_parameter("albedo_texture", frame_tex)
		_sprite.material_override = _shader_material
	else:
		_sprite.material_override = null
