class_name Gr1PlaceholderFrames
extends RefCounted

const FRAME_SIZE := Vector2i(80, 80)

const TEX_IDLE: Texture2D = preload("res://assets/sprites/units/placeholder/Gr1_Idle.png")
const TEX_IDLE_POWERED: Texture2D = preload("res://assets/sprites/units/placeholder/Gr1_Idle2.png")
const TEX_TRANS: Texture2D = preload("res://assets/sprites/units/placeholder/Gr1_Trans.png")
const TEX_REVERT: Texture2D = preload("res://assets/sprites/units/placeholder/Gr1_Revert.png")
const TEX_UNIT_PLACEHOLDER: Texture2D = preload("res://assets/sprites/units/placeholder/Gr1_Full.png")

# Loads the ember sprite‑sheet at runtime (returns placeholder when file is absent).
static func get_ember_texture() -> Texture2D:
	if ResourceLoader.exists("res://assets/sprites/units/placeholder/Gr1_Ember.png"):
		return ResourceLoader.load("res://assets/sprites/units/placeholder/Gr1_Ember.png", "Texture2D")
	return TEX_UNIT_PLACEHOLDER

const SHEETS := {
	"idle": {"texture": TEX_IDLE, "fps": 8.0, "loop": true},
	"idle_powered": {"texture": TEX_IDLE_POWERED, "fps": 8.0, "loop": true},
	"transform": {"texture": TEX_TRANS, "fps": 6.0, "loop": false},
	"revert": {"texture": TEX_REVERT, "fps": 6.0, "loop": false},
	"full": {"texture": TEX_UNIT_PLACEHOLDER, "fps": 10.0, "loop": false},
}
# Mapping of animation names to frame counts when using the combined ember sprite sheet.
# Order follows the sequence of frames in Gr1_Ember.png.
const FULL_ANIM_FRAMES := {
	"idle": 13,
	"idle_powered": 13,
	"transform": 3,
	"revert": 3,
	"full": 0  # 0 indicates that the full animation will use all remaining frames.
}


static func build() -> SpriteFrames:
	var sprite_frames := SpriteFrames.new()

	# 1. Add individual animations that use separate texture files.
	for anim_name in SHEETS:
		if anim_name == "full":
			# Skip the combined ember sprite; it will be handled later.
			continue
		var cfg: Dictionary = SHEETS[anim_name]
		_add_horizontal_strip(
			sprite_frames,
			anim_name,
			cfg.texture,
			cfg.fps,
			cfg.loop
		)

	# 2. Handle the combined ember sprite sheet (only if the file actually exists).
	if ResourceLoader.exists("res://assets/sprites/units/placeholder/Gr1_Ember.png"):
		var ember_sheet: Texture2D = load("res://assets/sprites/units/placeholder/Gr1_Ember.png")
		if ember_sheet != null:
			var frame_w := FRAME_SIZE.x
			var frame_h := FRAME_SIZE.y
			var sheet_image := ember_sheet.get_image()
			var use_image_textures := not sheet_image.is_empty()
			var total_frames: int = int(float(ember_sheet.get_width()) / float(frame_w))
			var current_index := 0

			for anim_name in FULL_ANIM_FRAMES:
				var frame_count: int = FULL_ANIM_FRAMES[anim_name]
				if frame_count == 0:
					frame_count = total_frames - current_index
				if frame_count <= 0:
					continue

				# Skip animations already added from individual sheets
				if sprite_frames.has_animation(anim_name):
					# Clear existing frames and replace with ember frames
					var existing_frame_count := sprite_frames.get_frame_count(anim_name)
					for _i in range(existing_frame_count):
						sprite_frames.remove_frame(anim_name, 0)
				else:
					sprite_frames.add_animation(anim_name)

				var cfg: Dictionary = SHEETS[anim_name]
				sprite_frames.set_animation_speed(anim_name, cfg.fps)
				sprite_frames.set_animation_loop(anim_name, cfg.loop)

				for i in frame_count:
					var frame_tex: Texture2D
					if use_image_textures:
						var region := Rect2i((current_index + i) * frame_w, 0, frame_w, frame_h)
						frame_tex = ImageTexture.create_from_image(sheet_image.get_region(region))
					else:
						var atlas := AtlasTexture.new()
						atlas.atlas = ember_sheet
						atlas.region = Rect2((current_index + i) * frame_w, 0, frame_w, frame_h)
						frame_tex = atlas
					sprite_frames.add_frame(anim_name, frame_tex)
				current_index += frame_count

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
	# Use float division to avoid INTEGER_DIVISION warning, then cast to int
	var frame_count: int = int(float(sheet.get_width()) / float(frame_w))
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