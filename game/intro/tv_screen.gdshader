shader_type spatial;
render_mode unshaded, cull_back;
// CRT screen of the opening scene. The picture comes from a SubViewport (the
// creature's room); on top of it: tuner static, interlaced scanlines, an
// aperture grille, a rolling hum bar, sync tears, brightness flicker, blow
// flashes and glass cracks with refraction and glints.
// Driven by intro_sequence.gd; the hotel's sets (hotel_television.gd) show
// its dead channel, and are switched on with it (`open`).

// Part of the mesh UVs covered by the visible tube face (min, size).
uniform vec4 screen_rect = vec4(0.0128, 0.1364, 0.9745, 0.7213);
uniform float power : hint_range(0.0, 1.0) = 1.0;
uniform float static_amount : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D image : source_color, filter_linear;
uniform float image_amount : hint_range(0.0, 1.0) = 0.0;
// Cracks per blow that cracked it in R, G, B, A; crack_level counts those
// blows so far (0..4).
uniform sampler2D cracks : filter_linear;
uniform float crack_level = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
// 0..1 vertical roll of the picture, and extra instability (tears, jitter).
uniform float roll = 0.0;
uniform float unstable : hint_range(0.0, 1.0) = 0.0;
// Brightness dips of a failing set, set per frame by the script.
uniform float flicker : hint_range(0.0, 1.0) = 0.0;
uniform float brightness = 1.0;
// Switching on, 0..1: a bright line across the middle opens out into the
// picture (as the trailer draws it, tools/trailer3d/web/engine/screens.js).
// 1, the opening scene: the set is on from the start.
uniform float open : hint_range(0.0, 1.0) = 1.0;
// A cold cast over everything, the dead channel of a hotel set.
uniform float tint_blue : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float crack_at(vec2 uv) {
	vec4 c = texture(cracks, uv);
	return max(max(c.r * step(0.5, crack_level), c.g * step(1.5, crack_level)), max(c.b * step(2.5, crack_level), c.a * step(3.5, crack_level)));
}

void fragment() {
	vec2 uv = (UV - screen_rect.xy) / screen_rect.zw;
	vec2 tube = uv;
	float t = TIME;
	float field = floor(t * 60.0);
	// Glass cracks bend what is behind them.
	vec2 px = vec2(1.0 / 1024.0, 1.0 / 768.0);
	float c = crack_at(tube);
	float cx = crack_at(tube + vec2(px.x * 1.5, 0.0)) - crack_at(tube - vec2(px.x * 1.5, 0.0));
	float cy = crack_at(tube + vec2(0.0, px.y * 1.5)) - crack_at(tube - vec2(0.0, px.y * 1.5));
	uv += vec2(cx, cy) * 0.012;
	// Signal: vertical roll, per-line jitter and occasional sync tears.
	uv.y = fract(uv.y + roll);
	float line = floor(uv.y * 240.0);
	float jitter = (hash(vec2(line, field)) - 0.5) * 0.004 * (static_amount + unstable);
	float tear = step(0.985 - unstable * 0.06, hash(vec2(floor(uv.y * 24.0), floor(t * 12.0))));
	uv.x += jitter + tear * (hash(vec2(line, floor(t * 20.0))) - 0.3) * 0.06 * (0.3 + unstable);
	// Picture with slight misconvergence between the guns.
	vec3 picture = vec3(
		texture(image, uv + vec2(0.0015, 0.0)).r,
		texture(image, uv).g,
		texture(image, uv - vec2(0.0015, 0.0)).b);
	// Tuner snow in fat interlaced dots with horizontal streaks.
	float snow = hash(floor(uv * vec2(260.0, 240.0)) + field * 7.0);
	float streak = hash(vec2(line, field * 3.0));
	vec3 noise = vec3(snow * 0.85 + step(0.93, streak) * 0.45);
	vec3 colour = mix(noise * 0.9, picture * 1.25, image_amount);
	colour = mix(colour, noise, static_amount * image_amount * 0.55);
	colour += (snow - 0.5) * 0.08;
	// Rolling hum bar and the alternating field of interlaced scanlines.
	float bar = smoothstep(0.0, 0.12, abs(fract(uv.y - t * 0.11) - 0.5) - 0.28);
	colour *= 0.82 + 0.18 * bar;
	float lines = 0.5 + 0.5 * sin((tube.y * 480.0 + mod(field, 2.0)) * 3.14159);
	colour *= 0.62 + 0.38 * lines;
	// Aperture grille: vertical red, green and blue phosphor stripes.
	float stripe = mod(floor(tube.x * 1100.0), 3.0);
	vec3 grille = vec3(stripe == 0.0 ? 1.0 : 0.55, stripe == 1.0 ? 1.0 : 0.55, stripe == 2.0 ? 1.0 : 0.55);
	colour *= mix(vec3(1.0), grille * 1.35, 0.45);
	// Tube shape: darker, softer corners.
	vec2 centred = tube - 0.5;
	colour *= 1.0 - smoothstep(0.16, 0.5, dot(centred * vec2(1.0, 1.25), centred * vec2(1.0, 1.25))) * 0.75;
	colour *= 1.0 - flicker;
	colour += flash * vec3(0.9, 0.95, 1.0);
	float opened = smoothstep(0.0, 1.0, open);
	float band = abs(tube.y - 0.5) * 2.0;
	// (Fully open, the whole face: the opening scene's picture is untouched.)
	float shown = open >= 1.0 ? 1.0 : 1.0 - smoothstep(opened - 0.02, opened + 0.02, band);
	float line_glow = exp(-pow(band / max(0.004, opened * 0.08 + 0.003), 2.0)) * (1.0 - opened) * step(0.001, open) * 3.0;
	colour = colour * shown + vec3(0.9, 0.95, 1.0) * line_glow;
	colour = mix(colour, colour * vec3(0.78, 0.86, 1.08), tint_blue);
	colour *= brightness * power;
	// Cracks: dark refracting cores with bright glints on their edges, lit by the tube.
	float glint = clamp(abs(cx) + abs(cy), 0.0, 1.0);
	colour = mix(colour, colour * 0.2, c * 0.75);
	colour += (glint * 0.3 + c * 0.05) * (0.35 + 0.65 * power) * vec3(0.95, 0.97, 1.0);
	ALBEDO = colour;
}
