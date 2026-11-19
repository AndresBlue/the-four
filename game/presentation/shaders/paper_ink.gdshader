shader_type canvas_item;
render_mode blend_mul;
// Ink that has gone into a sheet of paper (game/ui/office_memo.gd): it
// darkens the paper instead of lying over it, so the paper's own grain shows
// through it. Measured in the sheet's own pixels (VERTEX, before the sheet is
// scaled), so a sheet held up and its miniature carry the same marks. Three
// inks by its uniforms: a typewriter's cloth ribbon, a ballpoint, and a rubber
// stamp that never touches the sheet whole.
uniform float grain : hint_range(0.0, 1.0) = 0.5;
uniform float dry : hint_range(0.0, 1.0) = 0.3;
uniform float bite : hint_range(0.0, 1.0) = 0.3;
uniform float blotch : hint_range(0.0, 1.0) = 0.0;
// How hard it was pressed: over 1, its full strokes are black and only its
// thin ones show the grain.
uniform float press : hint_range(0.5, 2.0) = 1.0;

varying vec2 local;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	local = VERTEX;
}

void fragment() {
	float a = COLOR.a;
	vec3 tone = COLOR.rgb;
	// Its edges, eaten unevenly by the paper's fibres.
	float fibre = noise(local * 1.7);
	a = clamp((a - bite * fibre * 0.7) / max(0.05, 1.0 - bite * fibre * 0.7), 0.0, 1.0);
	// The weave through its strokes, and the stretches where it ran dry.
	float weave = noise(local * 0.85);
	float thin = noise(local * vec2(0.012, 0.05));
	float ink = mix(1.0, 0.4 + 0.6 * weave, grain) * mix(1.0 - dry, 1.0, thin);
	// Patches that never touched the sheet.
	float patch = noise(local * 0.03) * 0.65 + noise(local * 0.11) * 0.35;
	ink *= mix(1.0, smoothstep(blotch * 0.75 - 0.12, blotch * 0.75 + 0.12, patch), step(0.001, blotch));
	COLOR = vec4(mix(vec3(1.0), tone, clamp(a * ink * press, 0.0, 1.0)), 1.0);
}
