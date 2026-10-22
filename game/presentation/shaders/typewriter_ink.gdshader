shader_type canvas_item;
// The ink of a typewriter's cloth ribbon (game/ui/hotel_form.gd): never even.
// Where the ribbon was worn or the key came down soft a letter is thinner,
// and the cloth's weave shows through the strokes as a fine grain. Measured
// in the form's own pixels (VERTEX, before the form is scaled), so a sheet
// held up and its miniature on the sheet carry the same speckle.
uniform float grain : hint_range(0.0, 1.0) = 0.5;

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
	// The weave, and the ribbon drier along some stretches than others.
	float weave = noise(local * 0.85);
	float dry = noise(local * vec2(0.012, 0.05));
	float ink = mix(1.0, 0.45 + 0.55 * weave, grain) * mix(0.72, 1.0, dry);
	COLOR.a *= clamp(ink, 0.0, 1.0);
}
