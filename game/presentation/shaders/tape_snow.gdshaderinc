// What a deck shows of a tape with nothing on it (the author's references,
// evidence/referencias/vhs/05 to 08): not fine snow but fat dashes lying along
// the lines, each a couple of lines tall and of any length, struck again
// every field; whole runs of lines brighter or darker than the rest; a white
// line torn across the picture now and then; and on a few lines the colour,
// which has nothing to lock to, comes out as it likes.
// The mean of a field is the same as the next one's: it is the dashes that
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

// `at` runs 0 to 1 over the picture, `field` counts the fields so far.
vec3 tape_snow(vec2 at, float field) {
	float row = floor(at.y * 132.0);
	// Every line starts anywhere, so one line's dashes never sit under the next's.
	float along = at.x * 44.0 + hash(vec2(row, field)) * 61.0;
	// Dashes, and the short blocks that break them up.
	float fat = hash(vec2(floor(along), row * 3.0 + field * 7.0));
	float thin = hash(vec2(floor(along * 3.3), row * 5.0 + field * 11.0));
	// Greys over a floor that is not black, and a few bright blocks.
	float value = 0.07 + 0.5 * smoothstep(0.1, 0.9, fat * 0.55 + thin * 0.45) + 0.4 * smoothstep(0.86, 1.0, thin);
	// Runs of lines brighter or darker, drifting down the picture.
	value *= 0.5 + 0.8 * noise1(at.y * 6.0 - field * 0.11);
	vec3 snow = vec3(value);
	// The torn line: a couple of rows a field, bright along a stretch of the
	// row and ragged, white or (one in three) some dim colour.
	float struck = hash(vec2(row, field * 3.0 + 1.0));
	if (struck > 0.985) {
		float start = hash(vec2(row, field + 17.0)) * 0.8 - 0.1;
		float reach = 0.25 + 0.9 * hash(vec2(row, field + 23.0));
		float inside = step(start, at.x) * step(at.x, start + reach);
		float ragged = step(0.22, hash(vec2(floor(along * 2.3), row + field * 19.0)));
		vec3 ink = vec3(1.0);
		if (struck > 0.995) ink = 0.3 + 0.3 * cos(6.28318 * (hash(vec2(row, floor(along * 0.21) + field)) + vec3(0.0, 0.33, 0.67)));
		snow = mix(snow, ink, inside * ragged * 0.9);
	}
	return snow;
}
