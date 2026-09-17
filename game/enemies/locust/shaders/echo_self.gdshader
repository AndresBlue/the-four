shader_type spatial;
// Its own body: the one thing it knows exactly, without having to listen for
// it. Drawn above the echo field and both clouds, and because it is additive
// and writes no depth it contributes nothing to DEPTH_TEXTURE either: the
// field reconstructs the wall behind it and the arms read as an x-ray ghost of
// itself over the reading. That is also why the screen-covering quad never
// blacks its arms out.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform float now = 0.0;
uniform float shriek : hint_range(0.0, 1.0) = 0.0;
uniform float gain : hint_range(0.0, 2.0) = 1.0;
// Horizontal slices up the body, drifting slowly: it feels itself, it does not
// see itself.
uniform float slice_step = 0.16;

void fragment() {
	// In fragment() both NORMAL and VERTEX are already in view space.
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(-VERTEX))), 2.0);
	float height = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
	float slices = pow(1.0 - abs(fract((height + now * 0.05) / slice_step) - 0.5) * 2.0, 6.0);
	float level = (rim * 0.85 + slices * 0.22 + 0.035) * gain;
	ALBEDO = mix(vec3(0.82, 0.86, 0.9), vec3(1.3, 0.10, 0.06), shriek);
	ALPHA = clamp(level, 0.0, 1.0);
}
