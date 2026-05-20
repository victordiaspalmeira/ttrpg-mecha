class_name UnitSpriteVisual
extends Node3D

const FRAME_HEIGHT_PX := 80
const FRAME_FOOT_OFFSET_Y := float(FRAME_HEIGHT_PX) / 2.0
const SURFACE_CLEARANCE := 0.03
const STAND_UP_ROTATION_X := PI / 2.0
const IDLE_ANIMATION := "idle"
const ATTACK_ANIMATION := "transform"

@export var sprite_frames: SpriteFrames
@export var default_animation := IDLE_ANIMATION
@export var pixel_size := 0.022
@export var y_offset := 0.0
@export var use_placeholder_sheets := true

@onready var _sprite_anchor: Node3D = $SpriteAnchor
@onready var _mesh: MeshInstance3D = $SpriteAnchor/QuadSprite

var _material: StandardMaterial3D = null
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

	_material = StandardMaterial3D.new()
	_material.billboard_mode = StandardMaterial3D.BILLBOARD_FIXED_Y
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_material.transparency = StandardMaterial3D.TRANSPARENCY_ALPHA

	_setup_mesh()

	if sprite_frames == null or not sprite_frames.has_animation(default_animation) \
			or sprite_frames.get_frame_count(default_animation) == 0:
		push_error("UnitSpriteVisual: no usable SpriteFrames; using idle sheet as static fallback")
		_material.albedo_texture = Gr1PlaceholderFrames.TEX_IDLE
		_mesh.material_override = _material
		return

	play(default_animation)


# Kept for compatibility with UnitBase._apply_team_visual().
func apply_team_data(_team_data, _team_id: String) -> void:
	pass


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
	if sprite_frames == null or not sprite_frames.has_animation(animation_name):
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
	if sprite_frames == null or not sprite_frames.has_animation(animation_name):
		play(return_animation)
		return

	_return_animation = return_animation
	play(animation_name)


func _setup_mesh() -> void:
	if _mesh == null or _sprite_anchor == null:
		return

	_sprite_anchor.rotation = Vector3(STAND_UP_ROTATION_X, 0.0, 0.0)
	_sprite_anchor.position = Vector3(0.0, _surface_y, 0.0)

	_mesh.position = Vector3.ZERO
	_mesh.rotation = Vector3.ZERO

	_mesh.mesh.size = Vector2(FRAME_HEIGHT_PX * pixel_size, FRAME_HEIGHT_PX * pixel_size)
	_mesh.material_override = _material


func _process(delta: float) -> void:
	if sprite_frames == null or _current_anim.is_empty():
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
	if _mesh == null or sprite_frames == null or _current_anim.is_empty():
		return

	var frame_tex := sprite_frames.get_frame_texture(_current_anim, _current_frame)
	if frame_tex == null:
		push_warning("UnitSpriteVisual: missing frame %s#%d" % [_current_anim, _current_frame])
		return

	_material.albedo_texture = frame_tex