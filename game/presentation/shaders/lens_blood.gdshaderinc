// Blood on the lens of a camcorder (docs/EXECUTION.md, 8.7): what the picture
// of one looks like with drops of it on its glass. Included by the tape's
// filter (analog.gdshader) and by the page tools/dev/lens_blood_look.gd
// draws to look at the drops by themselves.

// Seconds since the first of it landed on the glass (0: none), and which
// drops they are.
uniform float lens_blood = 0.0;
uniform float lens_seed = 0.0;
// Which way is down on that glass, as the picture has it (x to the right, y
// down the screen), and how much of the pull of the earth lies in it: a
// camcorder on its side has its floor to one side of the picture, and that
// is the way a drop on its lens runs. 0: the glass lies flat, nothing runs.
uniform vec2 lens_down = vec2(0.0, 1.0);

float lens_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// One of the drops on the glass: where its middle is (in a picture one
// high and `wide` across), and how big it is. Each of the five has a fifth
// of the picture's width to itself -- which fifth is the capture's draw --
// so that no two land on top of each other.
vec3 lens_drop(float which, float wide) {
	float slot = mod(which * 2.0 + floor(lens_seed), 5.0);
	float across = (slot + 0.2 + 0.6 * lens_hash(vec2(which * 12.9898 + lens_seed * 3.7, 4.1))) / 5.0;
	float up = 0.17 + 0.6 * lens_hash(vec2(lens_seed * 9.1 + which * 78.233, 17.3));
	return vec3(across * wide, up, 0.06 + 0.065 * lens_hash(vec2(lens_seed + which * 5.3, 9.0)));
}

float lens_grain(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(lens_hash(i), lens_hash(i + vec2(1.0, 0.0)), f.x), mix(lens_hash(i + vec2(0.0, 1.0)), lens_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Two shapes run into one, with a fillet `soft` wide where they meet.
float lens_join(float one, float other, float soft) {
	float h = clamp(0.5 + 0.5 * (other - one) / soft, 0.0, 1.0);
	return mix(other, one, h) - soft * h * (1.0 - h);
}

// How deep the blood lies on the glass at a point of that picture (0: none;
// about 1: as deep as a bead of it gets). It is what a drop of something
// thick does on a pane that stands nearly upright:
//  - it lands and spreads to its size in a few frames: a disc, all but --
//    its edge wanders a few hundredths of its radius, as the edge of a drop
//    on glass that is not quite clean does;
//  - it is one colour nearly all through, a little thinner at its edge,
//    and what is in it sags to its low side, which is the darkest of it;
//  - held a moment by the glass, the low side gives: the drop draws out
//    into a short thread straight down the pane -- as wide as it leaves the
//    drop and narrower after --, quick at first and slower as the drop
//    empties, with a bead at its end that is the deepest of it all;
//  - and the drop it runs from grows paler for what it has lost.
// Round each there are the specks it threw as it landed, too light to run.
float blood_on_lens(vec2 p, float wide) {
	float film = 0.0;
	float pull = clamp(length(lens_down), 0.0, 1.0);
	vec2 down = pull > 0.001 ? lens_down / length(lens_down) : vec2(0.0, 1.0);
	// How wide the edge of anything on the lens is in the picture: it is
	// nearer than the lens can focus.
	float blur = 0.0055;
	for (int index = 0; index < 5; index++) {
		float which = float(index);
		// Three with the blow, one after another; two as the chest wells.
		float since = lens_blood - (index < 3 ? 0.07 * which : 0.32 + 0.23 * (which - 3.0));
		if (since <= 0.0) continue;
		vec3 drop = lens_drop(which, wide);
		float weight = (drop.z - 0.06) / 0.065;
		float size = drop.z * (0.5 + 0.5 * (1.0 - exp(-since * 30.0)));
		// When its low side gives, and how far the thread has got.
		float runs = step(0.3, pull) * step(0.25, weight + lens_hash(vec2(which * 1.7, lens_seed + 2.0)) * 0.6);
		float held = 0.1 + 0.28 * lens_hash(vec2(which + 5.0, lens_seed));
		float running = max(0.0, since - held);
		float reach = drop.z * (0.9 + 1.5 * lens_hash(vec2(lens_seed * 1.3, which + 11.0))) * pull;
		float run = runs * reach * (1.0 - exp(-running * running * 3.0));
		float spent = reach > 0.0 ? run / reach : 0.0;
		// The drop: creeping down a little under its own weight.
		vec2 at = drop.xy + down * pull * 0.012 * (0.5 + weight) * since;
		vec2 off = p - at;
		float around = atan(off.y, off.x);
		float edge = size * (1.0 + 0.055 * sin(around * 2.0 + which * 2.1 + lens_seed) + 0.04 * sin(around * 3.0 + which * 4.7) + 0.022 * sin(around * 5.0 + lens_seed * 3.0) + 0.012 * sin(around * 9.0 + which));
		float in_drop = length(off) - edge;
		float shape = in_drop;
		float in_thread = 1.0;
		float in_bead = 1.0;
		float thick = drop.z * (0.14 + 0.04 * weight);
		if (run > 0.0005) {
			// From inside the low side of the drop, straight down the glass.
			vec2 root = at + down * size * 0.55;
			vec2 tip = at + down * (size * 0.92 + run);
			vec2 way = tip - root;
			float along = clamp(dot(p - root, way) / dot(way, way), 0.0, 1.0);
			in_thread = length(p - (root + way * along)) - mix(thick * 1.7, thick, smoothstep(0.0, 0.5, along));
			in_bead = length(p - tip) - thick * 1.5;
			shape = lens_join(in_drop, lens_join(in_thread, in_bead, thick * 0.6), size * 0.3);
		}
		float cover = smoothstep(blur, -blur, shape);
		if (cover <= 0.0) continue;
		// How deep: the drop thin at its edge and full a little way in, fuller
		// on its low side; the thread fuller than the drop; the bead most.
		float sag = smoothstep(-0.3, 0.9, dot(off, down) / edge) * pull;
		// Not the same all over: thinner where it was spread by landing, and
		// that is not the same place in any two.
		float mottle = 0.78 + 0.3 * lens_grain(p * 30.0 + lens_seed + which * 13.0) + 0.14 * lens_grain(p * 85.0 + which * 7.0);
		float deep = (0.4 - 0.16 * spent + 0.44 * sag) * smoothstep(0.0, size * 0.25, -in_drop) * mottle;
		deep = max(deep, 0.85 * smoothstep(0.0, thick * 0.7, -in_thread));
		deep = max(deep, 1.2 * smoothstep(0.0, thick * 1.1, -in_bead));
		film = max(film, cover * max(deep, 0.3));
	}
	// The specks: each beside one of the first three, there when it is.
	for (int index = 0; index < 11; index++) {
		float which = float(index) + 20.0;
		float parent = float(index % 3);
		if (lens_blood - 0.07 * parent <= 0.02) continue;
		vec3 drop = lens_drop(parent, wide);
		float turn = TAU * lens_hash(vec2(which, lens_seed));
		float far = drop.z * (1.35 + 1.9 * lens_hash(vec2(lens_seed, which * 1.9)));
		float speck = 0.004 + 0.012 * pow(lens_hash(vec2(which * 2.3, lens_seed + 6.0)), 2.0);
		float there = smoothstep(blur, -blur, length(p - (drop.xy + vec2(cos(turn), sin(turn)) * far)) - speck);
		film = max(film, there * (0.45 + 0.4 * lens_hash(vec2(which, 3.0))));
	}
	return film;
}

// The picture seen through it: in front of everything. Light that goes
// through blood comes out red and less of it, the more the deeper it lies --
// a film of it tints what is behind, a bead of it hides it -- and what
// little it gives back of the light that falls on it is its own dark red.
// `at` is the point of the picture (0 to 1 each way) and `wide` how many
// times wider the picture is than it is high.
vec3 through_lens_blood(vec3 color, vec2 at, float wide) {
	if (lens_blood <= 0.0) return color;
	float film = blood_on_lens(at * vec2(wide, 1.0), wide);
	if (film <= 0.0) return color;
	float lit = dot(color, vec3(0.299, 0.587, 0.114));
	return color * exp(-film * vec3(1.1, 5.2, 5.8)) + vec3(0.13, 0.006, 0.005) * (1.0 - exp(-film * 2.4)) * (0.45 + 1.1 * lit);
}
