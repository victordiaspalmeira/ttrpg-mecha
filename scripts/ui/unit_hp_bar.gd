extends Sprite3D

@export var max_segments := 6

@export var segment_width := 5
@export var segment_height := 2

@export var segment_spacing := 1

@export var full_color := Color(
	0.35,
	0.9,
	1.0,
	1.0
)

@export var empty_color := Color(
	0.12,
	0.14,
	0.18,
	0.85
)

var current_hp := 6
var max_hp := 6


func _ready() -> void:

	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	update_texture()


func set_colors(p_full_color: Color, p_empty_color: Color) -> void:
	full_color = p_full_color
	empty_color = p_empty_color
	update_texture()


func set_hp(
	p_current_hp: int,
	p_max_hp: int
) -> void:

	current_hp = p_current_hp
	max_hp = maxi(1, p_max_hp)

	update_texture()


func update_texture() -> void:

	var total_width = (
		max_segments
		*
		(segment_width + segment_spacing)
	)

	var image = Image.create(
		total_width,
		segment_height,
		false,
		Image.FORMAT_RGBA8
	)

	image.fill(Color(0, 0, 0, 0))

	var hp_ratio = (
		float(current_hp)
		/
		float(max_hp)
	)

	var filled_segments = int(
		round(hp_ratio * max_segments)
	)

	for i in range(max_segments):

		var color = empty_color

		if i < filled_segments:
			color = full_color

		var start_x = (
			i
			*
			(segment_width + segment_spacing)
		)

		for x in range(segment_width):

			for y in range(segment_height):

				image.set_pixel(
					start_x + x,
					y,
					color
				)

	var image_texture = (
		ImageTexture.create_from_image(image)
	)

	texture = image_texture
