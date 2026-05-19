class_name Gr1PlaceholderFrames
extends RefCounted

const FRAME_SIZE := Vector2i(80, 80)

const TEX_IDLE: Texture2D = preload("res://assets/sprites/units/placeholder/Gr1_Idle.png")
const TEX_IDLE_POWERED: Texture2D = preload("res://assets/sprites/units/placeholder/Gr1_Idle2.png")
const TEX_TRANS: Texture2D = preload("res://assets/sprites/units/placeholder/Gr1_Trans.png")
const TEX_REVERT: Texture2D = preload("res://assets/sprites/units/placeholder/Gr1_Revert.png")
const TEX_FULL: Texture2D = preload("res://assets/sprites/units/placeholder/Gr1_Full.png")

const SHEETS := {
	"idle": {"texture": TEX_IDLE, "fps": 8.0, "loop": true},
	"idle_powered": {"texture": TEX_IDLE_POWERED, "fps": 8.0, "loop": true},
	"transform": {"texture": TEX_TRANS, "fps": 6.0, "loop": false},
	"revert": {"texture": TEX_REVERT, "fps": 6.0, "loop": false},
	"full": {"texture": TEX_FULL, "fps": 10.0, "loop": false},
}


static func build() -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()

	for anim_name in SHEETS:
		var cfg: Dictionary = SHEETS[anim_name]
		_add_horizontal_strip(sprite_frames, anim_name, cfg.texture, cfg.fps, cfg.loop)

	return sprite_frames


static func _add_horizontal_strip(
	sprite_frames: SpriteFrames,
	anim_name: String,
	sheet: Texture2D,
	fps: float,
	loop: bool
) -> void:
	if sheet == null:
		push_error("Gr1PlaceholderFrames: missing texture for '%s'" % anim_name)
		return

	var frame_w := FRAME_SIZE.x
	var frame_h := FRAME_SIZE.y
	var frame_count: int = sheet.get_width() / frame_w
	if frame_count < 1:
		push_error(
			"Gr1PlaceholderFrames: no frames in '%s' (%dx%d)"
			% [anim_name, sheet.get_width(), sheet.get_height()]
		)
		return

	sprite_frames.add_animation(anim_name)
	sprite_frames.set_animation_speed(anim_name, fps)
	sprite_frames.set_animation_loop(anim_name, loop)

	var sheet_image := sheet.get_image()
	var use_image_textures := not sheet_image.is_empty()

	for i in frame_count:
		var frame_tex: Texture2D
		if use_image_textures:
			var region := Rect2i(i * frame_w, 0, frame_w, frame_h)
			frame_tex = ImageTexture.create_from_image(sheet_image.get_region(region))
		else:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
			frame_tex = atlas
		sprite_frames.add_frame(anim_name, frame_tex)
