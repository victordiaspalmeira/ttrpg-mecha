shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_opaque;

uniform vec4 outline_color : source_color = vec4(0.35, 0.65, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 8.0) = 2.5;

void fragment() {
	// TEXTURE is the built-in uniform that Sprite3D populates from its texture property.
	// NO custom sampler2D uniform needed — Sprite3D handles the binding automatically.
	vec4 tex = texture(TEXTURE, UV);

	if (tex.a > 0.1) {
		ALBEDO = tex.rgb;
		ALPHA = tex.a;
		return;
	}

	vec2 px = TEXTURE_PIXEL_SIZE * outline_width;

	float e = 0.0;
	e = max(e, texture(TEXTURE, UV + vec2( px.x,  0.0)).a);
	e = max(e, texture(TEXTURE, UV + vec2(-px.x,  0.0)).a);
	e = max(e, texture(TEXTURE, UV + vec2( 0.0,   px.y)).a);
	e = max(e, texture(TEXTURE, UV + vec2( 0.0,  -px.y)).a);
	e = max(e, texture(TEXTURE, UV + vec2( px.x,  px.y)).a);
	e = max(e, texture(TEXTURE, UV + vec2(-px.x,  px.y)).a);
	e = max(e, texture(TEXTURE, UV + vec2( px.x, -px.y)).a);
	e = max(e, texture(TEXTURE, UV + vec2(-px.x, -px.y)).a);

	if (e > 0.1 && outline_color.a > 0.0) {
		ALBEDO = outline_color.rgb;
		ALPHA = outline_color.a;
	} else {
		ALPHA = 0.0;
		discard;
	}
}