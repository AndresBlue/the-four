// What a deck shows of a tape with nothing on it, and of the lines it reads
// badly (the author's references, evidence/referencias/vhs/05 to 08, and his
// word on the first attempt: "too digital"). Nothing in it has an edge: a
// tape's luma cannot change faster than its bandwidth lets it, so along a
// line everything is soft, and it is only from one line to the next that
// there is nothing in common. A hiss of greys; dropouts, where the head reads
// nothing for a moment and the line goes white and fades along itself as the
// deck recovers, a comet two lines thick; a whole line torn bright now and
// then; and here and there the colour, with nothing to lock to.
// The mean of a field is the same as the next one's: it is the streaks that
// flash, never the picture as a whole.
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise1(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(vec2(i, 1.7)), hash(vec2(i + 1.0, 1.7)), f * f * (3.0 - 2.0 * f));
}

// Smooth noise along a line, another for every `seed`.
float line_noise(float x, float seed) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(vec2(i, seed)), hash(vec2(i + 1.0, seed)), f * f * (3.0 - 2.0 * f));
}

// One field line of it: `along` runs 0 to 1 across the picture.
vec3 snow_line(float along, float row, float field) {
	float start = hash(vec2(row, field)) * 53.0;
	// The hiss: grain as narrow as the luma lets it be, and no narrower.
	float hiss = line_noise(along * 120.0 + start, row * 3.0 + field * 7.0) * 0.45 + line_noise(along * 340.0 + start * 3.0, row * 5.0 + field * 11.0) * 0.55;
	vec3 snow = vec3(0.09 + 0.62 * smoothstep(0.25, 0.9, hiss));
	// The dropouts: a quarter of the stretches of each pair of lines, lit
	// where they start (as fast as the luma can rise) and dying away along
	// the line.
	float pair = floor(row * 0.5);
	float run = along * 7.0 + hash(vec2(pair, field + 31.0)) * 17.0;
	float stretch = floor(run);
	float lit = hash(vec2(stretch, pair * 3.0 + field * 13.0));
	if (lit > 0.75) {
		float tail = fract(run);
		float comet = smoothstep(0.0, 0.05, tail) * exp(-tail * (1.5 + 7.0 * hash(vec2(stretch, pair + field * 17.0))));
		// One in twenty of them in some colour.
		vec3 ink = lit > 0.99 ? 0.6 + 0.3 * cos(6.28318 * (lit * 50.0 + vec3(0.0, 0.33, 0.67))) : vec3(1.0);
		snow += ink * comet * 0.85;
	}
	// The torn line: a line or two a field, bright along most of itself.
	if (hash(vec2(row, field * 3.0 + 1.0)) > 0.992) {
		float from = hash(vec2(row, field + 17.0)) * 0.6 - 0.1;
		float lasts = 0.3 + 0.8 * hash(vec2(row, field + 23.0));
		float inside = smoothstep(from, from + 0.02, along) * smoothstep(from + lasts, from + lasts - 0.15, along);
		snow = mix(snow, vec3(1.0), inside * smoothstep(0.25, 0.6, line_noise(along * 60.0 + start, row + field * 19.0)) * 0.9);
	}
	return snow;
}

// `at` runs 0 to 1 over the picture, `field` counts the fields so far. With
// `soft`, one line runs into the next, as a tube's beam draws them; without
// it (the lowest preset) each of the 240 is cut off square, at half the cost.
vec3 tape_snow(vec2 at, float field, bool soft) {
	float lines = at.y * 240.0;
	float row = floor(lines);
	vec3 snow = snow_line(at.x, row, field);
	if (soft) snow = mix(snow, snow_line(at.x, row + 1.0, field), smoothstep(0.25, 0.75, fract(lines)));
	// Runs of lines brighter or darker, drifting down the picture.
	return snow * (0.55 + 0.75 * noise1(at.y * 6.0 - field * 0.11));
}
