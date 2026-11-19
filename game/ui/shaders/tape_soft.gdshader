shader_type canvas_item;
// The softness of an old recording over what is drawn outside the tape (the
// menus): luma that cannot turn a corner, and colour that runs wider still
// and a little late. As wide on the screen at any resolution (the camera's
// own filter, analog.gdshader, measures it the same way). `amount` is the
// player's VHS slider: 0 leaves the screen as it is.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.3;

vec3 read(vec2 uv) {
	return texture(screen_texture, clamp(uv, vec2(0.0005), vec2(0.9995))).rgb;
}

void fragment() {
	vec2 soft = vec2((1.6 + amount * 5.0) / 1280.0, 0.0);
	vec3 near = read(SCREEN_UV - soft * 0.5) + read(SCREEN_UV + soft * 0.5);
	vec3 far = read(SCREEN_UV - soft) + read(SCREEN_UV + soft);
	vec3 luma_from = read(SCREEN_UV) * 0.3 + near * 0.22 + far * 0.13;
	vec3 chroma_from = (near + far + read(SCREEN_UV - soft * 1.2) + read(SCREEN_UV + soft * 3.2)) / 6.0;
	float luma = dot(luma_from, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(max(chroma_from - dot(chroma_from, vec3(0.299, 0.587, 0.114)) + luma, vec3(0.0)), 1.0);
}
