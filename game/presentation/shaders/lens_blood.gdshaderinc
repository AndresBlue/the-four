// Blood on the lens of a camcorder (docs/EXECUTION.md, 8.7): what the picture
// of one looks like with drops of it on its glass. Included by the tape's
// filter (analog.gdshader) and by the page tools/dev/lens_blood_look.gd
// draws to look at the drops by themselves.
//
// What a drop of blood does on a pane that stands nearly upright, and so
// what is drawn here:
//  - It is there at once. A drop that hits glass is flat against it before
//    the next frame: a stain, all but round, with the few short fingers it
//    threw out as it flattened and the specks that left it altogether.
//  - It is thick, and blood that thick lets very little through: the stain
//    is dense and dark all over, lighter only where it is a film.
//  - Then it runs, and the stain and what runs from it are one thing. Its
//    low side swells and gives; a head of blood moves down the glass,
//    straight, and behind it the stain is drawn out into the thread that
//    feeds it -- wide where it leaves the stain, narrow after.
//  - What goes into the head comes out of the stain, from the top first.
//    Where it has gone there is only a film left, streaked the way it ran,
//    with the darker line of where the stain's edge was; the low side, the
//    thread and above all the head are where the blood now is.

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

// One of the drops on the glass: where its middle is (in a picture one
// high and `wide` across), and how big it is. Each of the five has a fifth
// of the picture's width to itself -- which fifth is the capture's draw --
// so that no two land on top of each other.
vec3 lens_drop(float which, float wide) {
	float slot = mod(which * 2.0 + floor(lens_seed), 5.0);
	float across = (slot + 0.2 + 0.6 * lens_hash(vec2(which * 12.9898 + lens_seed * 3.7, 4.1))) / 5.0;
	float up = 0.15 + 0.5 * lens_hash(vec2(lens_seed * 9.1 + which * 78.233, 17.3));
	return vec3(across * wide, up, 0.06 + 0.065 * lens_hash(vec2(lens_seed + which * 5.3, 9.0)));
}

// How deep the blood lies on the glass at a point of that picture (0: none;
// about 1: a stain as it lands; more: where it has gathered).
float blood_on_lens(vec2 p, float wide) {
	float film = 0.0;
	float pull = clamp(length(lens_down), 0.0, 1.0);
	vec2 down = pull > 0.001 ? lens_down / length(lens_down) : vec2(0.0, 1.0);
	vec2 across = vec2(-down.y, down.x);
	// How wide the edge of anything on the lens is in the picture: it is
	// nearer than the lens can focus.
	float blur = 0.007;
	for (int index = 0; index < 5; index++) {
		float which = float(index);
		// Three with the blow, one after another; two as the chest wells.
		float since = lens_blood - (index < 3 ? 0.07 * which : 0.32 + 0.23 * (which - 3.0));
		if (since <= 0.0) continue;
		vec3 drop = lens_drop(which, wide);
		float size = drop.z;
		float weight = (size - 0.06) / 0.065;
		vec2 off = p - drop.xy;
		// Nothing of it is further off than this.
		if (length(off) > size * 6.0) continue;
		// The stain: where it hit, and it does not move -- its edge holds to
		// the glass. A disc whose edge wanders a little, with a soft bulge or
		// two where it went a little further as it flattened.
		float around = atan(off.y, off.x);
		float wander = 0.05 * sin(around * 2.0 + which * 2.1 + lens_seed) + 0.035 * sin(around * 3.0 + which * 4.7) + 0.02 * sin(around * 5.0 + lens_seed * 3.0) + 0.05 * pow(max(0.0, sin(around * 3.0 + lens_seed * 2.0 + which * 1.9)), 3.0);
		float in_stain = length(off) - size * (1.0 + wander);
		// How it runs: held a moment, then the head sets off -- slowly, and
		// faster, to the pace a head that size keeps; and no further than
		// what the stain has to give will take it.
		float runs = step(0.3, pull) * step(0.2, weight + lens_hash(vec2(which * 1.7, lens_seed + 2.0)) * 0.7);
		float held = 0.06 + 0.2 * lens_hash(vec2(which + 5.0, lens_seed));
		float running = max(0.0, since - held);
		float pace = size * (2.6 + 1.8 * lens_hash(vec2(lens_seed * 1.3, which + 11.0))) * pull;
		float most = size * (1.7 + 1.7 * weight + 0.9 * lens_hash(vec2(which * 2.9, lens_seed + 8.0)));
		float gone = runs * most * (1.0 - exp(-pace * (running - (1.0 - exp(-running * 3.2)) / 3.2) / most));
		// How much of the stain has left with it: none, to all it will give.
		float spent = clamp(gone / (size * 2.2), 0.0, 1.0);
		float along = dot(off, down);
		float aside = dot(off, across);
		float shape = in_stain;
		float in_head = 1.0;
		float head = size * (0.3 + 0.05 * weight - 0.05 * spent);
		if (runs > 0.0) {
			// The head starts inside the low half of the stain -- where it
			// swells before it gives -- and goes straight down; the thread is
			// what joins them: as wide as the stain lets it be where it leaves
			// it, drawn narrower the further it has gone, never much narrower
			// than the head it feeds.
			float head_at = size * 0.45 + gone;
			in_head = length(vec2(aside, along - head_at)) - head;
			float thread = head * 0.72;
			float down_it = clamp(along, size * 0.2, head_at);
			float in_thread = length(vec2(aside, along - down_it)) - thread * mix(1.5, 1.0, smoothstep(size * 0.5, max(head_at, size * 0.51), along));
			shape = lens_join(in_stain, lens_join(in_thread, in_head, head * 0.5), size * 0.34);
		}
		float cover = smoothstep(blur, -blur, shape);
		if (cover <= 0.0) continue;
		// How deep it lies, and it is one body of blood from the top of the
		// stain to the head: full all through as it lands; and as it runs,
		// less at the top and more the further down -- nowhere a line between
		// the two, because there is none. Where it has thinned it shows the
		// way it went, in streaks.
		float level = along / size;
		float fill = mix(mix(1.0, 0.42, spent), 1.0 + 0.4 * spent, smoothstep(-1.0, 1.1, level));
		float upper = spent * (1.0 - smoothstep(-1.0, 0.6, level));
		fill *= mix(1.0, 0.82 + 0.36 * lens_grain(vec2(aside * 46.0 + which * 17.0, along * 6.0 + lens_seed)), upper);
		fill *= 0.94 + 0.12 * lens_grain(p * 34.0 + lens_seed + which * 13.0);
		// A film only at its very edge, and a little deeper towards its middle.
		float deep = fill * smoothstep(0.0, size * 0.05, -shape) * (0.86 + 0.14 * smoothstep(0.0, size * 0.6, -shape));
		// And the head, once it is out, is the deepest of it: deepest in its
		// middle, and no line round it -- it is the same blood.
		deep += (0.25 + 0.3 * spent) * smoothstep(-head * 0.2, head * 0.9, -in_head) * smoothstep(0.0, 0.5, gone / size);
		film = max(film, cover * max(deep, 0.45));
	}
	// The specks it threw: each beside one of the first three, there when it
	// is, and too light to run. Most are dots; one in three is drawn out a
	// little, away from the drop it left.
	for (int index = 0; index < 14; index++) {
		float which = float(index) + 20.0;
		float parent = float(index % 3);
		if (lens_blood - 0.07 * parent <= 0.0) continue;
		vec3 drop = lens_drop(parent, wide);
		float turn = TAU * lens_hash(vec2(which, lens_seed));
		float far = drop.z * (1.25 + 1.6 * lens_hash(vec2(lens_seed, which * 1.9)));
		float speck = 0.0025 + 0.0075 * pow(lens_hash(vec2(which * 2.3, lens_seed + 6.0)), 2.0);
		vec2 out_way = vec2(cos(turn), sin(turn));
		vec2 from = p - (drop.xy + out_way * far);
		float drawn = speck * 1.1 * step(0.66, lens_hash(vec2(which * 3.7, 2.0)));
		from -= out_way * clamp(dot(from, out_way), -drawn, drawn);
		film = max(film, smoothstep(blur, -blur, length(from) - speck) * (0.8 + 0.3 * lens_hash(vec2(which, 3.0))));
	}
	return film;
}

// The picture seen through blood that deep. Blood lets little light through
// and what it lets through is red: a film of it tints what is behind, a
// stain of it hides it. What is seen of the blood itself is the light of
// the whole place scattered in it (`around`: how bright the picture is
// thereabouts, not at that point) -- red, and a darker red the deeper it
// lies, because the light has further to go in it.
vec3 through_lens_blood(vec3 color, float film, vec3 around) {
	if (film <= 0.0) return color;
	float lit = dot(around, vec3(0.299, 0.587, 0.114));
	vec3 passed = color * exp(-film * vec3(2.0, 8.0, 9.0));
	vec3 own = vec3(0.66, 0.034, 0.024) * exp(-film * vec3(0.4, 1.6, 1.6)) * (1.0 - exp(-film * 3.0)) * (0.16 + 0.95 * lit);
	return passed + own;
}
