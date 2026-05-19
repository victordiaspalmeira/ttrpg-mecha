shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

uniform sampler2D albedo_texture : filter_nearest, repeat_disable;
uniform vec4 modulate : source_color = vec4(1.0);
uniform vec4 outline_color : source_color = vec4(0.35, 0.65, 1.0, 1.0);
uniform float outline_width = 2.5;

void fragment() {
	vec2 tex_size = vec2(textureSize(albedo_texture, 0));
	vec2 px = vec2(1.0) / tex_size;
	vec4 tex = texture(albedo_texture, UV);

	if (tex.a > 0.45) {
		ALBEDO = tex.rgb * modulate.rgb;
		ALPHA = tex.a * modulate.a;
		return;
	}

	float edge = 0.0;
	int radius = int(ceil(outline_width));

	for (int x = -4; x <= 4; x++) {
		if (abs(x) > radius) {
			continue;
		}
		for (int y = -4; y <= 4; y++) {
			if (abs(y) > radius) {
				continue;
			}
			if (x == 0 && y == 0) {
				continue;
			}
			vec2 offset = vec2(float(x), float(y)) * px * outline_width;
			edge = max(edge, texture(albedo_texture, UV + offset).a);
		}
	}

	if (edge > 0.45) {
		ALBEDO = outline_color.rgb;
		ALPHA = outline_color.a;
	} else {
		ALPHA = 0.0;
	}
}
