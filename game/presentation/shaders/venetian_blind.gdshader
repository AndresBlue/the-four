shader_type spatial;
render_mode cull_disabled;
// A venetian blind on one quad (spec_f1_geometry.md 6.4): slats every
// `pitch` metres down `height`, the gap between them `open` of the pitch, and
// only the top `drop` of the pane covered (a raised blind is a short stack).
uniform float pitch = 0.022;
uniform float open = 0.3;
uniform float drop = 1.0;
uniform float height = 1.7;
uniform vec4 color : source_color = vec4(0.8, 0.78, 0.72, 1.0);

void fragment() {
	if (UV.y > drop) discard;
	if (fract(UV.y * height / pitch) < open) discard;
	ALBEDO = color.rgb;
	ROUGHNESS = 0.6;
}
