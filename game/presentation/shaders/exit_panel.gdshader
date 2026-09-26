shader_type spatial;
// The refuge's exit sign (docs/REALISM.md, phase 4): a sheet of clear acrylic
// with a row of diodes buried in its top edge. The sheet guides that light,
// and where it is engraved it stops guiding it and scatters it out, which is
// what the lettering is. So the lettering is drawn by the light, not painted:
// it is brightest under the diodes and loses a little towards the bottom, the
// cut rims catch more than the flat of the engraving, and the sheet's own cut
// edges glow, the bottom one brightest of all.
//
// The engraving comes from tools/textures/make_exit_sign.py: R the engraved
// face, G the rim of the cut.
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform sampler2D engraving : filter_linear_mipmap, repeat_disable;
/// A sign whose two faces say different things (the corridors' way out:
/// each face tells whoever looks at it where the exit is for them).
uniform bool two_faced = false;
uniform sampler2D engraving_back : filter_linear_mipmap, repeat_disable;
/// The light the diodes put into the sheet, and the whiter core of it.
uniform vec3 glow : source_color = vec3(0.07, 1.0, 0.33);
uniform vec3 core : source_color = vec3(0.62, 1.0, 0.8);
uniform float energy = 5.0;
/// How many diodes there are along the top edge.
uniform int diodes = 5;
/// The acrylic itself: what of the room behind it still comes through, and
/// how much of the front it catches at a glancing angle.
uniform float sheet = 0.09;
uniform float sheen = 0.45;
/// Dimmed with the rest of the floor's lamps (switch_off, the flicker).
uniform float level = 1.0;

void fragment() {
	// Engraved on both faces, as these signs are, so it reads the same way
	// round from behind.
	vec2 uv = UV;
	if (!FRONT_FACING) uv.x = 1.0 - uv.x;
	vec4 cut = (two_faced && !FRONT_FACING) ? texture(engraving_back, uv) : texture(engraving, uv);
	float depth = uv.y;
	// The diodes: a bright point each at the top edge, and the cone each one
	// throws down into the sheet, widening as it goes.
	float cones = 0.0;
	float lamps = 0.0;
	for (int i = 0; i < diodes; i++) {
		float at = (float(i) + 0.5) / float(diodes);
		float across = abs(uv.x - at);
		cones += exp(-across * across / (0.0006 + depth * depth * 0.07));
		lamps += exp(-across * across / 0.00004) * exp(-depth * 90.0);
	}
	cones *= exp(-depth * 2.6) / float(diodes);
	// What the sheet still carries at this depth: the lettering goes with it.
	float guided = mix(0.62, 1.0, exp(-depth * 1.1));
	// The flat of the engraving scatters; its cut rims catch much more.
	float letters = (cut.r * 0.7 + cut.g * 2.1) * guided;
	// The cut edges of the sheet, where the guided light leaves it.
	vec2 border = min(uv, 1.0 - uv);
	float edge = smoothstep(0.02, 0.0, min(border.x, border.y));
	edge *= mix(0.5, 1.6, smoothstep(0.7, 1.0, uv.y));
	// The sheet is never quite dark: some of what it guides leaves it all
	// the way along.
	float lit = (letters + edge * 0.8 + cones * 0.22 + lamps * 3.0 + guided * 0.05) * level;
	// The brightest of it loses its green, as an overexposed light does.
	vec3 colour = mix(glow, core, clamp(lit * 0.55, 0.0, 1.0));
	// The sheet itself: barely there, but it catches the eye at an angle.
	float grazing = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.0);
	ALBEDO = colour * lit * energy + vec3(0.35, 0.45, 0.4) * grazing * sheen * level;
	ALPHA = clamp(sheet + grazing * sheen + lit * 1.4, 0.0, 1.0);
}
