// What a deck shows of a tape with nothing on it, and of the lines it reads
// badly, as the author's references have it (evidence/referencias/vhs/05 to
// 07): not the snow of a tube, but a video of that snow, 480 lines and thirty
// frames a second, and most of what one sees in it is what the video's
// coding left. It was drawn here by a formula, as a fine hiss with comets
// first and then as stretches of grey with the levels and the lengths the
// references measure, and both times he saw pixel art with digital noise in
// it: what was missing is the coding itself. So that is done once, outside
// (tools/dev/tape_snow.py: a tape's lines, predicted and corrected in blocks
// as a video is, each frame with the levels the references have), and this
// shows the frames it made:
//   - one of three, read from anywhere in it and either way round, another
//     every two fields. Two of them are sharp (dashes of light and of black
//     a line or two tall over stretches of grey, flat across their blocks of
//     four pixels) and one is of a moment with no bits to spare (smooth, a
//     shade off from one block of sixteen to the next, only the strongest
//     dashes left): the noise bigger than the rest that he pointed at;
//   - a line read all wrong, bright from somewhere along it to its end, in
//     dashes: ragged, thicker here and thinner there, two or three lines
//     with its glow, and the tape darker under it half the times;
//   - the colour, with nothing to lock to. A tape's colour has no fine
//     detail, and a video's has less, in blocks of eight pixels: a stain of
//     blue or violet over a ragged patch of those blocks, with a point of
//     yellow in some; and, some of the time, where the heads change over
//     towards the foot, two runs of two or three lines each, one right under
//     the other, every one a stretch of one dark hue after another with
//     gaps, over a tape gone dark and flat. (As thin lines of clean, bright
//     colour, and then as lines whose hue turned smoothly along them, they
//     were the first thing he saw that no tape does.)
// The mean of a frame is the same as the next one's: it is the noise that
// flashes, never the picture as a whole (tools/capture/film_check.py).
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

// Stretches along a line: `x` counts them, each holds one level and steps to
// the next over the last `edge` of itself. Another set for every `seed`.
float stretches(float x, float edge, float seed) {
	float i = floor(x);
	return mix(hash(vec2(i, seed)), hash(vec2(i + 1.0, seed)), smoothstep(1.0 - edge, 1.0, fract(x)));
}

// The frames, one a channel (project.godot, shader_globals), and how many of
// the video's pixels one is.
global uniform sampler2D tape_snow_frames : repeat_enable, filter_linear;
const vec2 SNOW_FRAME = vec2(864.0, 480.0);

// A colour of its hue around no colour at all: what is added to a grey. (0
// red, a third blue, two thirds green; yellow is past green, purple before
// blue.)
vec3 chroma_of(float hue) {
	vec3 ink = 0.5 + 0.5 * cos(6.28318 * (hue + vec3(0.0, 0.33, 0.67)));
	return ink - dot(ink, vec3(0.299, 0.587, 0.114));
}

// The same from the two signals a tape's colour is carried as.
vec3 chroma_from(vec2 iq) {
	return vec3(0.956 * iq.x + 0.621 * iq.y, -0.272 * iq.x - 0.647 * iq.y, -1.106 * iq.x + 1.703 * iq.y);
}

// One frame of the video, by its number: `p` in the video's pixels.
float snow_frame(vec2 p, float frame) {
	vec2 q = p / SNOW_FRAME;
	if (hash(vec2(frame, 3.0)) > 0.5) q.x = -q.x;
	vec3 three = textureLod(tape_snow_frames, q + vec2(hash(vec2(frame, 1.0)), hash(vec2(frame, 2.0))), 0.0).rgb;
	float which = hash(vec2(frame, 4.0));
	return which < 0.36 ? three.r : which < 0.72 ? three.g : three.b;
}

// `at` runs 0 to 1 over the picture, `field` counts the fields so far. With
// `soft` the colour is there; without it (the lowest preset) it is the
// frames and the bright line.
vec3 tape_snow(vec2 at, float field, bool soft) {
	// In the pixels of the video: 480 lines, and as many across as a wide
	// picture has of them. The fields are counted round (a hash of a big
	// number is no hash), and a frame is two of them.
	vec2 p = at * vec2(853.0, 480.0);
	float frame = floor(mod(field, 502.0) * 0.5);
	float light = snow_frame(p, frame);
	// The line read all wrong, for two frames.
	float turn = floor(frame * 0.5);
	if (hash(vec2(turn, 11.0)) > 0.55) {
		float off = p.y - hash(vec2(turn, 9.0)) * 480.0;
		// Under it the tape is darker, half the times.
		light *= 1.0 - 0.3 * step(0.5, hash(vec2(turn, 15.0))) * smoothstep(-1.0, 3.0, off);
		float start = hash(vec2(turn, 13.0)) * 0.7 - 0.2;
		float along = smoothstep(start, start + 0.02, at.x) * smoothstep(0.1, 0.22, stretches(p.x / 21.0 + turn * 3.7, 0.3, 1757.0));
		light += 0.06 * along * smoothstep(6.0, 1.0, abs(off));
		// (How thick it is just here, and how far off its line: it has teeth.)
		float girth = 0.3 + 0.8 * stretches(p.x / 6.0 + turn * 5.1, 0.5, 1506.0);
		off += stretches(p.x / 4.0 + turn * 2.9, 0.3, 1255.0) - 0.5;
		light = mix(light, 0.45 + 0.55 * stretches(p.x / 7.0 + turn, 0.5, 2008.0), along * smoothstep(girth + 0.8, girth, abs(off)));
	}
	vec3 snow = vec3(light);
	if (soft) {
		// A stain of colour, for three frames: the blocks of a patch, more
		// of them towards its middle.
		float held = floor(frame / 3.0);
		vec2 cell = p / vec2(72.0, 40.0) + held * vec2(0.37, 0.61);
		float there = hash(floor(cell) + held * vec2(11.0, 3.0));
		if (there > 0.994) {
			vec2 block = floor(p / 8.0);
			vec2 f = (block * 8.0 + 4.0) / vec2(72.0, 40.0) + held * vec2(0.37, 0.61) - floor(cell) - 0.5;
			float stain = step(0.42, 1.0 - length(f) * 2.2 + (hash(block + held) - 0.5) * 0.7);
			// (`there` is all but 1 here: only its last figures tell one from another.)
			float shade = fract(there * 4513.0);
			snow += chroma_of(shade < 0.75 ? 0.33 - 0.08 * shade : 0.1) * stain * (0.05 + light * 0.3);
			if (fract(there * 997.0) > 0.6) snow += (chroma_of(0.83) * 0.5 + 0.2) * smoothstep(0.1, 0.03, length((fract(cell) - 0.5 - vec2(0.05, -0.04)) * vec2(1.0, 0.6)));
		}
		// The foot, where the heads change over.
		float slow = floor(frame * 0.25);
		if (at.y > 0.8 && hash(vec2(slow, 21.0)) > 0.65) {
			float top = (0.855 + 0.03 * hash(vec2(slow, 23.0))) * 480.0;
			snow = mix(snow, vec3(0.09 + 0.2 * light), 0.8 * smoothstep(top - 2.0, top + 2.0, p.y));
			// (Its colour is in blocks of eight pixels along the line.)
			float along = floor(p.x / 8.0) * 8.0;
			for (int k = 0; k < 2; k++) {
				float off = p.y - top - 5.0 - float(k) * 17.0;
				float band = smoothstep(4.4, 3.4, abs(off));
				if (band <= 0.0) continue;
				// Which of its lines this is: each has stretches and hues of its own.
				float which = float(k) * 3.0 + floor(off / 2.5 + 1.5);
				band *= step(0.42, stretches(along / 75.0 + slow * 1.7, 0.01, which + 4016.0));
				vec2 iq = vec2(stretches(along / 55.0 + slow * 3.1, 0.01, which + 3514.0), stretches(along / 55.0 - slow * 2.3, 0.01, which + 3765.0)) - 0.5;
				snow = mix(snow, vec3(0.03 + 0.3 * light), 0.9 * band) + chroma_from(iq) * 0.42 * band;
			}
		}
	}
	return snow;
}
