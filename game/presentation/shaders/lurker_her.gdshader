shader_type canvas_item;
// The Lurker herself over her own sight (.claude/specs/lurker_versus.md
// 13.9): her real body and its ink, drawn alone with her camera
// (lurker_view.gd), laid over the recording with a thin cold rim round her
// shape, the light that picks her out of the dark navy. Where she would hide
// what matters (her prey; down in a room, what she looks at) her body is a
// faint screen door, its rim kept: she is still there, and it shows through.
uniform vec4 rim : source_color = vec4(0.6, 0.76, 1.0, 0.9);
// The rim's width, in pixels of the screen.
uniform float width = 2.0;
// Up to three ellipses (centre, half size; UV) where she is screened.
uniform int hole_count = 0;
uniform vec4 holes[3];
// What is left of her there, one pixel in two.
const float SCREEN = 0.3;

void fragment() {
	vec4 her = texture(TEXTURE, UV);
	float around = 0.0;
	for (int k = 0; k < 8; k++) {
		float a = float(k) * 0.785398;
		around = max(around, texture(TEXTURE, UV + vec2(cos(a), sin(a)) * TEXTURE_PIXEL_SIZE * width).a);
	}
	float edge = clamp(around - her.a, 0.0, 1.0) * rim.a;
	float cut = 0.0;
	for (int i = 0; i < hole_count; i++) {
		vec2 d = (UV - holes[i].xy) / max(holes[i].zw, vec2(1.0e-4));
		cut = max(cut, 1.0 - smoothstep(0.7, 1.0, length(d)));
	}
	float door = mod(floor(FRAGCOORD.x) + floor(FRAGCOORD.y), 2.0) < 0.5 ? SCREEN : 0.0;
	COLOR = vec4(mix(rim.rgb, her.rgb, her.a), max(her.a * mix(1.0, door, cut), edge));
}
