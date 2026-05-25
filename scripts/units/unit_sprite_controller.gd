class_name UnitSpriteController
extends Node3D

const FRAME_SIZE_PX := 80
const SURFACE_CLEARANCE := 0.03
const IDLE_ANIMATION := "idle"
const ATTACK_ANIMATION := "transform"

# Maps sprite_variant -> {dir, prefix}
const VARIANT_MAP := {
	"grey": { "dir": "Grey_1", "prefix": "Gr1" },
	"cyan": { "dir": "Cyan_1", "prefix": "C1" },
	"yellow": { "dir": "Yellow_1", "prefix": "Y1" },
	"orange": { "dir": "Orange_1/Sprite_Sheets", "prefix": "O1" },
	"red": { "dir": "Red_1/Sprite_Sheets", "prefix": "R1" },
}

## Animation config: anim_name -> {texture, fps, loop, frame_count}
var animations: Dictionary = {}

@export var default_animation := IDLE_ANIMATION
@export var pixel_size := 0.022
@export var y_offset := 0.0
@export var use_placeholder_sheets := true
@export var sprite_variant := "grey"

var _frame_count := 1
var _material: StandardMaterial3D
var _mesh: MeshInstance3D
var _current_anim := ""
var _current_frame := 0
var _frame_time := 0.0
var _return_animation := ""
var _surface_y := 0.13
var _anim_speed := 1.0
var _anim_loop := true
var _base_color := Color(1, 1, 1, 1)
var _team_color := Color(1, 1, 1, 1)


func _ready() -> void:
	var size := FRAME_SIZE_PX * pixel_size

	# QuadMesh FACE_Y = XZ plane (lying flat), perfect for BILLBOARD_FIXED_Y
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.orientation = QuadMesh.FACE_Y

	_mesh = MeshInstance3D.new()
	_mesh.mesh = quad
	add_child(_mesh)
	if Engine.is_editor_hint():
		var root = get_tree().edited_scene_root
		if root: _mesh.owner = root
	else:
		_mesh.owner = owner

	# Offset up so sprite bottom aligns with origin
	_mesh.position.y = size / 2.0

	_material = StandardMaterial3D.new()
	_material.billboard_mode = StandardMaterial3D.BILLBOARD_FIXED_Y
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh.material_override = _material
	apply_material_settings()

	# Don't load sheets here — UnitBase.apply_class_data() will call configure_variant()
	# with the correct sprite variant from class_data.


func apply_material_settings() -> void:
	if _material:
		_material.billboard_mode = StandardMaterial3D.BILLBOARD_FIXED_Y
		_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


## Called by UnitBase after class_data is applied.
## Loads the correct sprite sheets for the given variant and plays the default animation.
func configure_variant(variant: String) -> void:
	sprite_variant = variant
	animations.clear()
	_load_variant_sheets()
	if animations.has(default_animation):
		_apply_anim(default_animation)
		play(default_animation)


func apply_team_data(team_data, _team_id: String) -> void:
	if team_data == null or _material == null: return
	var t: Color = team_data.outline_color
	t.a = 1.0
	_team_color = Color(lerpf(1.0, t.r, 0.1), lerpf(1.0, t.g, 0.1), lerpf(1.0, t.b, 0.1), 1.0)
	_base_color = _team_color
	_material.albedo_color = _base_color


func configure_surface(grid_config: GridConfig) -> void:
	if grid_config == null: return
	_surface_y = grid_config.get_surface_y() + SURFACE_CLEARANCE + y_offset
	position.y = _surface_y


func get_sprite_top_y() -> float:
	return _surface_y + FRAME_SIZE_PX * pixel_size


func play(name: String) -> void:
	if not animations.has(name):
		push_warning("UnitSpriteController: unknown '%s'" % name)
		return
	_current_anim = name
	_current_frame = 0
	_frame_time = 0.0
	_apply_anim(name)


func play_attack() -> void:
	play_one_shot(ATTACK_ANIMATION if animations.has(ATTACK_ANIMATION) else IDLE_ANIMATION, default_animation)


func play_one_shot(anim: String, ret: String) -> void:
	if not animations.has(anim): play(ret); return
	_return_animation = ret
	play(anim)


func flash_white(duration := 0.25) -> void:
	if _material == null: return
	_material.albedo_color = Color(1, 1, 1, 1)
	var tween: Tween = create_tween()
	tween.tween_property(_material, "albedo_color", _base_color, duration)


func shake(intensity := 0.08, duration := 0.4) -> void:
	var orig := position
	var tween: Tween = create_tween()
	var t := 0.0
	while t < duration:
		tween.tween_property(self, "position", orig + Vector3(randf_range(-intensity, intensity), randf_range(-intensity, intensity), randf_range(-intensity, intensity)), 0.05)
		t += 0.05
	tween.tween_property(self, "position", orig, 0.05)


func play_death() -> Tween:
	var tween: Tween = create_tween()
	if _material: tween.tween_property(_material, "albedo_color", Color(1, 1, 1, 0), 0.5)
	return tween


func set_status_tint(c: Color) -> void:
	if _material: _material.albedo_color = c


func reset_status_tint() -> void:
	if _material: _material.albedo_color = _base_color


# --- Animation ---

func _apply_anim(name: String) -> void:
	var anim: Dictionary = animations.get(name)
	if anim.is_empty(): return
	var tex: Texture2D = anim.get("texture") as Texture2D
	if tex == null: return

	_material.albedo_texture = tex
	_anim_speed = anim.get("fps", 8.0)
	_anim_loop = anim.get("loop", true)
	_frame_count = anim.get("frame_count", 1)

	_material.uv1_scale = Vector3(1.0 / float(_frame_count), 1.0, 1.0)
	_material.uv1_offset = Vector3(0.0, 0.0, 0.0)
	_current_frame = 0
	_material.albedo_color = _base_color


func _process(delta: float) -> void:
	if _current_anim.is_empty() or _anim_speed <= 0.0 or _frame_count < 1: return
	if not _anim_loop and _frame_count == 1: _finish_shot(); return

	_frame_time += delta
	var spf := 1.0 / _anim_speed
	while _frame_time >= spf:
		_frame_time -= spf
		if _anim_loop:
			_current_frame = (_current_frame + 1) % _frame_count
			_update_uv()
			continue
		if _current_frame + 1 >= _frame_count: _finish_shot(); break
		_current_frame += 1
		_update_uv()


func _update_uv() -> void:
	if _frame_count > 0 and _material:
		_material.uv1_offset = Vector3(float(_current_frame) / float(_frame_count), 0.0, 0.0)


func _finish_shot() -> void:
	if _return_animation.is_empty(): return
	var ret := _return_animation
	_return_animation = ""
	play(ret)


# --- Sprite sheets loading ---

## Loads the correct sprite sheets based on sprite_variant.
func _load_variant_sheets() -> void:
	var variant_info = VARIANT_MAP.get(sprite_variant, VARIANT_MAP["grey"])
	var base_path := "res://assets/sprites/units/%s/%s" % [variant_info.dir, variant_info.prefix]

	var sheet_names := ["_Idle.png", "_Idle2.png", "_Trans.png", "_Revert.png", "_Full.png"]
	var anim_names := ["idle", "idle_powered", "transform", "revert", "full"]
	var fps_values := [8.0, 8.0, 6.0, 6.0, 10.0]
	var loop_values := [true, true, false, false, false]

	# Check if there's a combined atlas (Ember-style)
	var ember_path := base_path + "_Ember.png"
	if ResourceLoader.exists(ember_path):
		_build_from_ember(ember_path)
		return

	for i in range(sheet_names.size()):
		var path: String = base_path + sheet_names[i]
		if not ResourceLoader.exists(path):
			continue
		var tex := load(path) as Texture2D
		if tex == null:
			continue
		var fc := int(float(tex.get_width()) / float(FRAME_SIZE_PX))
		if fc < 1:
			continue
		animations[anim_names[i]] = {"texture": tex, "fps": fps_values[i], "loop": loop_values[i], "frame_count": fc}


## Builds animations from a combined Ember-style atlas strip.
func _build_from_ember(ember_path: String) -> void:
	var sheet := load(ember_path) as Texture2D
	if sheet == null: return
	var total := int(float(sheet.get_width()) / float(FRAME_SIZE_PX))
	var defs := {
		"idle": {"f": 13, "fps": 8.0, "loop": true},
		"idle_powered": {"f": 13, "fps": 8.0, "loop": true},
		"transform": {"f": 3, "fps": 6.0, "loop": false},
		"revert": {"f": 3, "fps": 6.0, "loop": false},
	}
	var rem := total
	for k in ["idle", "idle_powered", "transform", "revert"]: rem -= defs[k].f
	defs["full"] = {"f": maxi(0, rem), "fps": 10.0, "loop": false}
	var idx := 0
	for name in defs:
		var d: Dictionary = defs[name]
		if d.f <= 0: continue
		var atl := AtlasTexture.new()
		atl.atlas = sheet
		atl.region = Rect2(idx * FRAME_SIZE_PX, 0, FRAME_SIZE_PX * d.f, FRAME_SIZE_PX)
		animations[name] = {"texture": atl, "fps": d.fps, "loop": d.loop, "frame_count": d.f}
		idx += d.f