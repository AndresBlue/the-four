shader_type canvas_item;
// The Lurker herself over her own sight (.claude/specs/lurker_versus.md
// 13.9): her real body and its ink, drawn alone with her camera
// (lurker_view.gd), laid over the recording with a thin cold rim round her
// shape, the light that picks her out of the dark navy.
uniform vec4 rim : source_color = vec4(0.6, 0.76, 1.0, 0.9);
// The rim's width, in pixels of the screen.
uniform float width = 2.0;

void fragment() {
	vec4 her = texture(TEXTURE, UV);
	float around = 0.0;
	for (int k = 0; k < 8; k++) {
		float a = float(k) * 0.785398;
		around = max(around, texture(TEXTURE, UV + vec2(cos(a), sin(a)) * TEXTURE_PIXEL_SIZE * width).a);
	}
	float edge = clamp(around - her.a, 0.0, 1.0) * rim.a;
	COLOR = vec4(mix(rim.rgb, her.rgb, her.a), max(her.a, edge));
}
