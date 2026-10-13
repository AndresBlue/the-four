shader_type canvas_item;
// Consumer camcorder / VHS playback look. Applied to the 3D image and the
// in-world camcorder overlay; menus, subtitles and hints are drawn above it.
// Every term scales with the user's sliders, and reduced effects set them to 0.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float vhs : hint_range(0.0, 1.0) = 0.18;
uniform float grain : hint_range(0.0, 1.0) = 0.12;
uniform float chromatic : hint_range(0.0, 1.0) = 0.08;
uniform float scanlines : hint_range(0.0, 1.0) = 0.35;
// Stable colour treatment of old tape: lifted blacks, soft highlights, warm cast.
uniform vec3 tint = vec3(1.02, 1.0, 0.9);
uniform float vignette : hint_range(0.0, 1.0) = 0.45;
// Inside a wardrobe: dark closing edges and a slight fish-eye bulge.
uniform float enclosure : hint_range(0.0, 1.0) = 0.0;
// The creature's strike wind-up: a brief tape tear across the image.
// The victim's own camera giving out: the picture tears, rolls and is eaten
// by the snow of a dead channel. 1 is no picture left at all.
uniform float signal_loss : hint_range(0.0, 1.0) = 0.0;
// A blow to the camcorder itself (death_tape.gd): while it lasts the top of
// the picture flags sideways, the band at the bottom where the heads switch
// jumps, the colour drops out and dots streak across it. tape_band is where
// a band of noise stands as it climbs the picture once (1 the bottom, 0 the
// top, under 0 none). Everything a tape does wrong it does along its lines
// and field by field: never in blocks, never one colour apart from another.
uniform float tape_hit : hint_range(0.0, 1.0) = 0.0;
uniform float tape_band = -1.0;
// The mechanism that no longer settles: bands climbing more and more often,
// the hold slipping, the colour coming and going. 1 is the last field.
uniform float tape_fray : hint_range(0.0, 1.0) = 0.0;
// The tape running back (a stage given back): over the snow, the bars of a
// search in reverse race up the picture.
uniform float rewinding : hint_range(0.0, 1.0) = 0.0;
// Screen reads for the chroma smear, over the same width (graphics preset
// chroma_taps): 7, or 4 on the lowest preset.
uniform int chroma_taps : hint_range(2, 7) = 7;
// The lowest preset (tape_lite): three reads of the picture a pixel and no
// more -- the luma as it comes, the chroma from either side of it. A full
// screen of reads is what an integrated GPU has least of.
uniform bool lite = false;

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

vec3 rgb_to_yiq(vec3 c) {
	return vec3(dot(c, vec3(0.299, 0.587, 0.114)), dot(c, vec3(0.596, -0.274, -0.322)), dot(c, vec3(0.211, -0.523, 0.312)));
}

vec3 yiq_to_rgb(vec3 c) {
	return vec3(c.x + 0.956 * c.y + 0.621 * c.z, c.x - 0.272 * c.y - 0.647 * c.z, c.x - 1.106 * c.y + 1.703 * c.z);
}

vec3 tap(vec2 uv) {
	return texture(screen_texture, clamp(uv, vec2(0.0005), vec2(0.9995))).rgb;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	float t = TIME;
	vec2 centred = uv - 0.5;
	uv = 0.5 + centred * (1.0 - enclosure * 0.12 * (1.0 - dot(centred, centred) * 2.0));
	// Tape transport: slow line wobble, a drifting tracking band and the
	// head-switching tear at the bottom of the frame.
	float line = floor(uv.y / px.y);
	float wobble = (noise1(uv.y * 38.0 + t * 1.3) - 0.5) * 0.0022 + sin(uv.y * 190.0 + t * 3.0) * 0.00035;
	float band_pos = fract(t * 0.043);
	float band = smoothstep(0.06, 0.0, abs(uv.y - band_pos)) * (0.6 + 0.4 * noise1(t * 4.0));
	float jitter = (hash(vec2(line, floor(t * 30.0))) - 0.5) * 0.004 * band;
	float head = smoothstep(0.035, 0.0, 1.0 - uv.y);
	float tear = head * (0.012 + (hash(vec2(floor(t * 24.0), line)) - 0.5) * 0.01);
	uv.x += (wobble + jitter) * vhs + tear * vhs;
	// The camcorder struck, or coming apart.
	float damage = max(tape_hit, tape_fray);
	float struck_band = 0.0;
	if (damage > 0.0) {
		float field = floor(t * 60.0);
		// Flagging: the top lines pulled sideways, the more the higher up.
		float flag = smoothstep(0.2, 0.0, uv.y);
		uv.x += flag * flag * (0.07 * tape_hit * (0.6 + 0.4 * sin(t * 41.0)) + 0.05 * tape_fray * step(0.45, hash(vec2(field, 2.0))));
		// The band of noise: once up the picture for a blow, and for a tape that
		// is going, again and again and faster.
		if (tape_band >= 0.0) struck_band = smoothstep(0.075, 0.0, abs(uv.y - tape_band)) * clamp(tape_hit * 2.0, 0.0, 1.0);
		float going = fract(1.0 - t * (0.5 + tape_fray * 3.2));
		struck_band = max(struck_band, smoothstep(0.04 + 0.1 * tape_fray, 0.0, abs(uv.y - going)) * tape_fray);
		uv.x += (hash(vec2(line, field)) - 0.5) * 0.14 * struck_band;
		// Where the heads switch, at the bottom, the tear jumps.
		uv.x += smoothstep(0.1, 0.0, 1.0 - uv.y) * (hash(vec2(line, field + 3.0)) - 0.5) * 0.09 * damage;
		// The hold slipping: the whole picture hops a few lines, now and then.
		uv.y = fract(uv.y + tape_fray * tape_fray * 0.07 * step(0.72, hash(vec2(floor(t * 14.0), 9.0))));
	}
	// Luma: slightly soft with edge ringing; chroma: much lower horizontal
	// resolution and a small delay, like composite video on tape.
	float soft = 1.0 + vhs * 2.5;
	vec3 center = tap(uv);
	float luma;
	vec2 chroma = vec2(0.0);
	float chroma_width = px.x * (1.5 + vhs * 9.0);
	float chroma_delay = px.x * vhs * 3.0;
	if (lite) {
		vec3 here = rgb_to_yiq(center);
		luma = here.x;
		chroma = here.yz * 0.5 + (rgb_to_yiq(tap(uv + vec2(chroma_delay - chroma_width * 2.0, 0.0))).yz + rgb_to_yiq(tap(uv + vec2(chroma_delay + chroma_width * 2.0, 0.0))).yz) * 0.25;
	} else {
		vec3 blur_l = tap(uv - vec2(px.x * soft, 0.0));
		vec3 blur_r = tap(uv + vec2(px.x * soft, 0.0));
		luma = rgb_to_yiq(center * 0.5 + (blur_l + blur_r) * 0.25).x;
		// Terms whose slider is at 0 read nothing (the result would be the same).
		if (vhs > 0.0) {
			float far_luma = rgb_to_yiq(tap(uv - vec2(px.x * soft * 3.0, 0.0)) * 0.5 + tap(uv + vec2(px.x * soft * 3.0, 0.0)) * 0.5).x;
			luma += (luma - far_luma) * 0.35 * vhs;
		}
		// Taps spread evenly from -3 to +3 chroma widths, however many there are.
		float spacing = 6.0 / float(max(chroma_taps - 1, 1));
		for (int i = 0; i < chroma_taps; i++) {
			vec3 sample_yiq = rgb_to_yiq(tap(uv + vec2((-3.0 + float(i) * spacing) * chroma_width + chroma_delay, 0.0)));
			chroma += sample_yiq.yz;
		}
		chroma /= float(chroma_taps);
	}
	chroma *= 1.0 - vhs * 0.25;
	vec3 color = yiq_to_rgb(vec3(luma, chroma));
	// Lens colour fringing, stronger towards the corners.
	vec2 from_center = SCREEN_UV - 0.5;
	vec2 fringe = from_center * dot(from_center, from_center) * chromatic * 0.045 + vec2(chromatic * px.x * 2.0, 0.0);
	if (chromatic > 0.0) {
		color.r = mix(color.r, tap(uv + fringe).r, clamp(chromatic * 3.0, 0.0, 1.0));
		color.b = mix(color.b, tap(uv - fringe).b, clamp(chromatic * 3.0, 0.0, 1.0));
	}
	// Tape grade: lifted blacks, compressed highlights, slight warm/green cast.
	float grade = clamp(vhs * 2.2, 0.0, 1.0);
	color = mix(color, color * tint, grade);
	color = mix(color, vec3(0.035, 0.035, 0.03) + color * 0.93, grade);
	color = mix(color, 1.0 - exp(-color * 1.25), grade * 0.6);
	// Tracking band noise, dropouts and interference.
	float snow = hash(vec2(uv.x * 900.0 + t * 60.0, line));
	color += (snow - 0.5) * band * 0.25 * vhs;
	// Oxide dropouts: for a moment the head reads no signal and the line
	// flashes white, brightest where it starts, with a ragged tail; one field
	// line tall (240 a frame), sometimes two, lasting one frame. Worn tape
	// (vhs) drops out more. A third of them the deck's dropout compensation
	// hides by repeating the line above instead.
	float field_row = floor(SCREEN_UV.y * 240.0);
	float dropout_frame = floor(t * 30.0);
	float chance = vhs * 0.0012 + tape_hit * 0.03 + tape_fray * 0.02;
	float hit = step(1.0 - chance, hash(vec2(dropout_frame, field_row)));
	// The line below a dropout often goes too.
	hit = max(hit, step(1.0 - chance, hash(vec2(dropout_frame, field_row - 1.0))) * step(0.6, hash(vec2(field_row, dropout_frame + 5.0))));
	if (hit > 0.0) {
		float row = field_row - (1.0 - step(1.0 - chance, hash(vec2(dropout_frame, field_row))));
		float start = hash(vec2(row, dropout_frame + 3.0)) * 1.1 - 0.05;
		float span = 0.02 + 0.13 * hash(vec2(row, dropout_frame + 7.0));
		float along = (uv.x - start) / span;
		float inside = step(0.0, along) * step(along, 1.0);
		float ragged = 0.55 + 0.45 * hash(vec2(floor(uv.x / px.x / 3.0), dropout_frame));
		float strength = inside * (1.0 - along * 0.75) * ragged;
		if (hash(vec2(row, dropout_frame + 11.0)) < 0.33) {
			color = mix(color, tap(uv - vec2(0.0, 1.0 / 240.0)), inside);
		} else {
			color = mix(color, vec3(0.92, 0.92, 0.9), strength * clamp(0.5 + vhs, 0.0, 0.9));
		}
	}
	color = mix(color, vec3(snow * 0.8), head * vhs * 0.55);
	if (damage > 0.0) {
		// The band is noise, not picture; and the colour, the first thing a
		// tape loses, goes with a blow and comes and goes with a failing one.
		color = mix(color, vec3(snow * 0.9), struck_band * 0.8);
		float grey = dot(color, vec3(0.299, 0.587, 0.114));
		float drained = max(clamp(tape_hit * 1.6, 0.0, 1.0), tape_fray * step(0.4, hash(vec2(floor(t * 9.0), 4.0))));
		color = mix(color, vec3(grey), drained);
	}
	// Grain: stronger in the shadows, as with auto-gain in the dark.
	float g = hash(uv * vec2(1731.0, 977.0) + fract(t * 23.0)) - 0.5;
	float dark = 1.0 - clamp(dot(color, vec3(0.333)) * 1.6, 0.0, 1.0);
	color += g * grain * (0.08 + dark * 0.14);
	// Static 240-line field structure (no temporal alternation, to avoid flicker).
	float scan = 0.5 + 0.5 * cos(SCREEN_UV.y * 240.0 * 6.28318);
	color *= 1.0 - scanlines * 0.28 * scan;
	color *= 1.0 + scanlines * 0.06;
	// Vignette and slight flicker of the whole frame.
	float edge = dot(from_center * vec2(1.1, 1.0), from_center * vec2(1.1, 1.0));
	color *= 1.0 - smoothstep(0.12, 0.6, edge) * vignette * clamp(vhs * 3.0, 0.3, 1.0);
	color *= 1.0 - (noise1(t * 11.0) - 0.5) * 0.03 * vhs;
	float closed_in = smoothstep(0.05, 0.42, edge);
	color *= 1.0 - closed_in * enclosure * 0.85;
	// The signal going, as a dead channel on a big set: the picture loses its
	// hold and rolls, sync tears drag lines sideways, and fat interlaced snow
	// with a rolling hum bar takes it over.
	if (signal_loss > 0.0) {
		float loss = clamp(signal_loss, 0.0, 1.0);
		float field = floor(t * 50.0);
		vec2 rolled = vec2(uv.x, fract(SCREEN_UV.y + t * (0.02 + loss * 0.55)));
		float row = floor(rolled.y * 240.0);
		float tear = step(0.96 - loss * 0.05, hash(vec2(floor(rolled.y * 24.0), floor(t * 12.0))));
		rolled.x += (hash(vec2(row, field)) - 0.5) * 0.02 * loss + tear * (hash(vec2(row, floor(t * 20.0))) - 0.3) * 0.12 * loss;
		vec3 torn = tap(vec2(fract(rolled.x), uv.y));
		color = mix(color, torn, loss * 0.85);
		color = mix(color, vec3(dot(color, vec3(0.333))), loss * 0.85);
		// Tuner snow: fat dots on a 260 x 240 grid, restruck every field, with
		// the odd bright horizontal streak across a whole line.
		float snow = hash(floor(rolled * vec2(260.0, 240.0)) + field * 7.0);
		float streak = hash(vec2(row, field * 3.0));
		vec3 dead = vec3(snow * 0.85 + step(0.93, streak) * 0.45);
		// Rolling hum bar and the alternating field of interlaced lines.
		float bar = smoothstep(0.0, 0.12, abs(fract(rolled.y - t * 0.11) - 0.5) - 0.28);
		dead *= 0.82 + 0.18 * bar;
		float lines = 0.5 + 0.5 * sin((SCREEN_UV.y * 480.0 + mod(field, 2.0)) * 3.14159);
		dead *= 0.62 + 0.38 * lines;
		if (rewinding > 0.0) {
			// Dark between the bars, and the bars are the noise itself, torn.
			// Two of them up the picture, each point of it lit twice a
			// second: at 5.5, which is nearer what a deck does, the whole
			// picture flashed over three times a second (tools/capture/
			// film_check.py), which nothing in the game is to do.
			float bars = smoothstep(0.62, 0.7, fract(SCREEN_UV.y * 2.0 + t * 1.9 + (hash(vec2(row, field)) - 0.5) * 0.03));
			dead = mix(dead, dead * (0.16 + 0.95 * bars), rewinding);
		}
		color = mix(color, dead, smoothstep(0.1, 0.85, loss));
		color *= 1.0 - (noise1(t * 21.0) - 0.5) * 0.22 * loss;
	}
	COLOR = vec4(max(color, vec3(0.0)), 1.0);
}
