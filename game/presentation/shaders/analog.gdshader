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
// Blood on the glass of a camcorder lying where its owner is being killed
// (death_tape.gd): lens_blood, lens_seed and lens_down, and what they draw.
#include "res://game/presentation/shaders/lens_blood.gdshaderinc"
// What the camcorder writes over a picture that is all snow: that the signal
// is lost, that the tape is running back (hotel_ui.gd, marks_view). In the
// picture the snow would cover them, so they come apart from it, as a
// picture of their own with its cover (colour times cover, as a viewport
// keeps it), are laid over the snow, and the tape has them as it has the
// rest: soft, their colour run sideways, scanned, grained, dark at the
// corners. What it does not do to them is what it does to a signal that is
// going, or to a tape that is struck.
uniform bool marked = false;
uniform sampler2D marks : filter_linear, repeat_disable;
// Screen reads for the chroma smear, over the same width (graphics preset
// chroma_taps): 7, or 4 on the lowest preset.
uniform int chroma_taps : hint_range(2, 7) = 7;
// The lowest preset (tape_lite): three reads of the picture a pixel and no
// more -- the luma as it comes, the chroma from either side of it. A full
// screen of reads is what an integrated GPU has least of.
uniform bool lite = false;
// The picture's place on the screen: all of it (0), or a narrower one in its
// middle with black either side of it and the whole screen drawn into it.
// The boot plays in 4:3 (hotel_ui.play_intro): 0.125 of a 16:9 screen a side.
uniform float inset : hint_range(0.0, 0.45) = 0.0;
// The deck finding the picture as a tape starts (the author's references 09
// and 10): 1 is the first field, cut into slanted bands; 0 is the picture held.
uniform float entry : hint_range(0.0, 1.0) = 0.0;
// One field whose colour comes off the tape wrong (references 11 and 13).
// The tape does it by itself once in a long while; 1 here makes it do it now.
uniform float chroma_slip : hint_range(0.0, 1.0) = 0.0;
// hash, noise1, line_noise and tape_snow: the snow of a tape with nothing on it.
#include "res://game/presentation/shaders/tape_snow.gdshaderinc"

vec3 rgb_to_yiq(vec3 c) {
	return vec3(dot(c, vec3(0.299, 0.587, 0.114)), dot(c, vec3(0.596, -0.274, -0.322)), dot(c, vec3(0.211, -0.523, 0.312)));
}

vec3 yiq_to_rgb(vec3 c) {
	return vec3(c.x + 0.956 * c.y + 0.621 * c.z, c.x - 0.272 * c.y - 0.647 * c.z, c.x - 1.106 * c.y + 1.703 * c.z);
}

vec3 tap(vec2 uv) {
	return texture(screen_texture, clamp(uv, vec2(0.0005), vec2(0.9995))).rgb;
}

vec4 mark_tap(vec2 uv) {
	return texture(marks, clamp(uv, vec2(0.0005), vec2(0.9995)));
}

// Tape grade: lifted blacks, compressed highlights, slight warm/green cast.
vec3 graded(vec3 color) {
	float grade = clamp(vhs * 2.2, 0.0, 1.0);
	color = mix(color, color * tint, grade);
	color = mix(color, vec3(0.035, 0.035, 0.03) + color * 0.93, grade);
	return mix(color, 1.0 - exp(-color * 1.25), grade * 0.6);
}

void fragment() {
	// Where this pixel is in the picture, which is where the screen is read.
	float wide = 1.0 - 2.0 * inset;
	vec2 at = vec2((SCREEN_UV.x - inset) / wide, SCREEN_UV.y);
	vec2 uv = at;
	vec2 px = SCREEN_PIXEL_SIZE;
	float t = TIME;
	// How much of a tape's frame there is: all of it from a little wear up.
	float frame = clamp(vhs * 5.0, 0.0, 1.0);
	vec2 centred = uv - 0.5;
	uv = 0.5 + centred * (1.0 - enclosure * 0.12 * (1.0 - dot(centred, centred) * 2.0));
	// Tape transport: slow line wobble, a drifting tracking band and the
	// head-switching tear at the bottom of the frame.
	float line = floor(uv.y / px.y);
	float wobble = (noise1(uv.y * 38.0 + t * 1.3) - 0.5) * 0.0022 + sin(uv.y * 190.0 + t * 3.0) * 0.00035;
	float band_pos = fract(t * 0.043);
	float band = smoothstep(0.06, 0.0, abs(uv.y - band_pos)) * (0.6 + 0.4 * noise1(t * 4.0));
	float field_line = floor(at.y * 240.0);
	float jitter = (hash(vec2(field_line, floor(t * 30.0))) - 0.5) * 0.006 * band;
	uv.x += (wobble + jitter) * vhs;
	// Where the picture has nothing to show: past the end of a line.
	float blank = 0.0;
	// A bar of noise across the picture: where one head hands over to the other.
	float bar = 0.0;
	if (entry > 0.0) {
		// The drum is not yet in step with the tape. The bars where the heads
		// switch stand close together at first and end far apart, the last of
		// them under the picture, where it stays (the strip below). It gets
		// there in jerks, a dozen or so a second, each landing the bars
		// somewhere else: quick and rough (the author, on a first version
		// that glided: too slow, too fluid).
		float jerk = floor(t * 14.0);
		float rough = clamp(entry * (1.0 + (hash(vec2(jerk, 41.0)) - 0.5) * 0.5), 0.0, 1.0);
		float done = 1.0 - rough;
		float apart = 0.2 + 1.1 * done * done;
		float lowest = 0.2 + 0.8 * done * (2.0 - done) + (hash(vec2(jerk, 43.0)) - 0.5) * 0.7 * entry;
		float within = fract((at.y - lowest) / apart);
		bar = smoothstep(0.035, 0.0, min(within, 1.0 - within) * apart) * smoothstep(0.0, 0.2, entry);
		// Each stretch between two bars is pulled sideways, by more the lower
		// in it, and round the end of the line, so the black between lines
		// crosses it as a slanted bar; the top of the picture flags over until
		// the tension settles, and every line is a little out of its place.
		float pull = within * rough * (0.25 + 1.15 * rough) + exp(-at.y * 11.0) * 0.09 * entry * (0.75 + 0.25 * sin(t * 31.0)) + (hash(vec2(field_line, jerk)) - 0.5) * 0.03 * entry;
		float wrapped = fract(uv.x + pull);
		blank = smoothstep(0.075, 0.045, wrapped) * smoothstep(0.02, 0.2, entry);
		uv.x = wrapped;
		// And the whole of it bounces before the vertical hold has it.
		uv.y += 0.05 * entry * entry * sin(entry * 19.0);
		blank = max(blank, max(step(uv.y, 0.0), step(1.0, uv.y)));
	}
	// Where the heads switch, under the last lines of the picture (references
	// 04 and 12): a strip a few lines tall that the deck draws out of step
	// with the rest, pulled along by more the lower the line, with the black
	// of the line's start showing at its end. It is always there, and it
	// starts a line higher or lower from one frame to the next.
	float switch_from = 1.0 - (0.013 + 0.004 * hash(vec2(floor(t * 30.0), 21.0))) * frame;
	float head = step(switch_from, at.y);
	if (head > 0.0) {
		float deep = (at.y - switch_from) / max(1.0 - switch_from, 0.0001);
		uv.x -= 0.03 + deep * 0.08 + (hash(vec2(field_line, floor(t * 30.0))) - 0.5) * 0.025;
		blank = max(blank, step(uv.x, 0.0));
	}
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
	// A tape's softness is a share of its picture's width, whatever the screen:
	// counted in pixels, a bigger screen showed a sharper tape. `unit` is one
	// pixel of the 1280 the interface is laid out on.
	float unit = 1.0 / 1280.0;
	float soft = 1.6 + vhs * 5.0 + entry * 4.0;
	vec3 center = tap(uv);
	float luma;
	vec2 chroma = vec2(0.0);
	float chroma_width = unit * (1.5 + vhs * 9.0);
	float chroma_delay = unit * vhs * 3.0;
	if (lite) {
		vec3 here = rgb_to_yiq(center);
		luma = here.x;
		chroma = here.yz * 0.5 + (rgb_to_yiq(tap(uv + vec2(chroma_delay - chroma_width * 2.0, 0.0))).yz + rgb_to_yiq(tap(uv + vec2(chroma_delay + chroma_width * 2.0, 0.0))).yz) * 0.25;
	} else {
		// Five reads across it: with three this far apart an edge came out
		// twice over instead of soft.
		vec3 near = tap(uv - vec2(unit * soft * 0.5, 0.0)) + tap(uv + vec2(unit * soft * 0.5, 0.0));
		vec3 far = tap(uv - vec2(unit * soft, 0.0)) + tap(uv + vec2(unit * soft, 0.0));
		luma = rgb_to_yiq(center * 0.3 + near * 0.22 + far * 0.13).x;
		// Terms whose slider is at 0 read nothing (the result would be the same).
		if (vhs > 0.0) {
			float far_luma = rgb_to_yiq(tap(uv - vec2(unit * soft * 3.0, 0.0)) * 0.5 + tap(uv + vec2(unit * soft * 3.0, 0.0)) * 0.5).x;
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
	// The colour locks after the picture does, and the picture comes up a
	// touch dim. Its contrast is left as it is: pushed up, as the references
	// have it, the bright bands crossing the whole screen came to three
	// flashes a second (film_check.py).
	chroma *= 1.0 - smoothstep(0.25, 0.4, entry);
	luma *= 1.0 - 0.1 * smoothstep(0.0, 0.5, entry);
	vec3 color = yiq_to_rgb(vec3(luma, chroma)) * (1.0 - blank);
	if (lens_blood > 0.0) {
		float lens_wide = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
		float lens_film = blood_on_lens(SCREEN_UV * vec2(lens_wide, 1.0), lens_wide);
		// How bright it is round about, which is what lights the blood: four
		// reads of the picture a good way off, only where there is blood.
		if (lens_film > 0.0) color = through_lens_blood(color, lens_film, (tap(SCREEN_UV + vec2(0.12, 0.09)) + tap(SCREEN_UV + vec2(-0.12, 0.09)) + tap(SCREEN_UV + vec2(0.12, -0.09)) + tap(SCREEN_UV + vec2(-0.12, -0.09))) * 0.25);
	}
	// Lens colour fringing, stronger towards the corners.
	vec2 from_center = at - 0.5;
	vec2 fringe = from_center * dot(from_center, from_center) * chromatic * 0.045 + vec2(chromatic * px.x * 2.0, 0.0);
	if (chromatic > 0.0) {
		color.r = mix(color.r, tap(uv + fringe).r, clamp(chromatic * 3.0, 0.0, 1.0));
		color.b = mix(color.b, tap(uv - fringe).b, clamp(chromatic * 3.0, 0.0, 1.0));
	}
	color = graded(color);
	// The tape's own noise, over all of the picture. A fine hiss in the luma,
	// streaked along the lines and never the same on the next one, and more
	// of it in the dark; and blotches of colour that run along a line, as the
	// low band the colour is recorded on has them. Neither has an edge.
	if (vhs > 0.0) {
		float hiss_field = floor(t * 60.0);
		float hiss_row = floor(at.y * 480.0);
		float dim = 1.0 - clamp(dot(color, vec3(0.333)) * 1.4, 0.0, 1.0);
		color += (line_noise(at.x * 420.0 + hash(vec2(hiss_row, hiss_field)) * 37.0, hiss_row + hiss_field * 3.0) - 0.5) * vhs * (0.05 + 0.12 * dim);
		if (!lite) {
			float blotch_row = floor(at.y * 240.0);
			vec2 blotch = vec2(line_noise(at.x * 28.0 + hash(vec2(blotch_row, hiss_field + 5.0)) * 19.0, blotch_row + hiss_field * 5.0), line_noise(at.x * 28.0 + hash(vec2(blotch_row, hiss_field + 9.0)) * 23.0, blotch_row * 3.0 + hiss_field * 7.0)) - 0.5;
			color += yiq_to_rgb(vec3(0.0, blotch * vhs * (0.03 + 0.09 * dim)));
		}
	}
	// Tracking band noise, dropouts and interference.
	vec3 snow = vec3(0.0);
	if (band * vhs > 0.001 || head > 0.0 || damage > 0.0 || bar > 0.0) snow = tape_snow(at, floor(t * 60.0), !lite);
	color += (snow - 0.22) * band * 0.85 * vhs;
	color = mix(color, snow, bar * 0.85);
	// One field in a great many, the colour of the picture comes off the tape
	// wrong: bands of it down the screen, or from some height down, over a
	// luma that is still right. Worn tape does it more.
	float tick = floor(t * 30.0);
	float worn = clamp(vhs / 0.3, 0.0, 3.0);
	float slip = max(chroma_slip, step(1.0 - 0.0013 * worn * worn, hash(vec2(tick, 71.0))));
	slip = max(slip, 0.8 * smoothstep(0.42, 0.34, entry) * smoothstep(0.2, 0.28, entry));
	if (slip > 0.0) {
		float from = step(0.5, hash(vec2(tick, 5.0))) * hash(vec2(tick, 9.0)) * 0.6;
		float turn = (at.y * (16.0 + 16.0 * hash(vec2(tick, 13.0))) + noise1(at.y * 11.0 + tick) * 1.4 + hash(vec2(floor(at.y * 240.0), tick)) * 0.06) * 6.28318;
		vec3 here = rgb_to_yiq(color);
		color = mix(color, yiq_to_rgb(vec3(here.x, here.yz * 0.5 + vec2(cos(turn), sin(turn)) * (0.03 + here.x * 0.13))), slip * step(from, at.y));
	}
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
		// Bright as fast as the luma can rise, and dying away along the line.
		float ragged = 0.6 + 0.4 * noise1(uv.x * 140.0 + dropout_frame);
		float strength = inside * smoothstep(0.0, 0.05, along) * smoothstep(1.0, 0.8, along) * exp(-along * 2.2) * ragged;
		if (hash(vec2(row, dropout_frame + 11.0)) < 0.33) {
			color = mix(color, tap(uv - vec2(0.0, 1.0 / 240.0)), inside);
		} else {
			color = mix(color, vec3(0.92, 0.92, 0.9), strength * clamp(0.5 + vhs, 0.0, 0.9));
		}
	}
	color = mix(color, snow, head * vhs * 0.5 * (1.0 - blank));
	if (damage > 0.0) {
		// The band is noise, not picture; and the colour, the first thing a
		// tape loses, goes with a blow and comes and goes with a failing one.
		color = mix(color, snow, struck_band * 0.8);
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
	// (As one figure, `lit`: what is written over the snow is lit by it too.)
	float lit = (1.0 - scanlines * 0.28 * scan) * (1.0 + scanlines * 0.06);
	// Vignette and slight flicker of the whole frame.
	float edge = dot(from_center * vec2(1.1, 1.0), from_center * vec2(1.1, 1.0));
	lit *= 1.0 - smoothstep(0.12, 0.6, edge) * vignette * clamp(vhs * 3.0, 0.3, 1.0);
	lit *= 1.0 - (noise1(t * 11.0) - 0.5) * 0.03 * vhs;
	float closed_in = smoothstep(0.05, 0.42, edge);
	lit *= 1.0 - closed_in * enclosure * 0.85;
	color *= lit;
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
		// A blank tape's snow (tape_snow): fat dashes along the lines, struck
		// again every field, with the odd bright line torn across.
		vec3 dead = tape_snow(rolled, field, !lite);
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
		float unsteady = 1.0 - (noise1(t * 21.0) - 0.5) * 0.22 * loss;
		color *= unsteady;
		lit *= unsteady;
	}
	if (marked) {
		// Read where the picture was read, so they wander with its lines:
		// their luma a little soft and ringing at its edges, their colour
		// over a wider stretch and a little late.
		vec4 here = mark_tap(uv);
		vec4 body = here;
		vec2 run;
		if (lite) {
			run = rgb_to_yiq(here.rgb).yz * 0.5 + (rgb_to_yiq(mark_tap(uv + vec2(chroma_delay - chroma_width * 2.0, 0.0)).rgb).yz + rgb_to_yiq(mark_tap(uv + vec2(chroma_delay + chroma_width * 2.0, 0.0)).rgb).yz) * 0.25;
		} else {
			body = here * 0.5 + (mark_tap(uv - vec2(unit * soft, 0.0)) + mark_tap(uv + vec2(unit * soft, 0.0))) * 0.25;
			run = vec2(0.0);
			float apart = 6.0 / float(max(chroma_taps - 1, 1));
			for (int i = 0; i < chroma_taps; i++) run += rgb_to_yiq(mark_tap(uv + vec2((-3.0 + float(i) * apart) * chroma_width + chroma_delay, 0.0)).rgb).yz;
			run /= float(chroma_taps);
		}
		float written_luma = rgb_to_yiq(body.rgb).x;
		if (vhs > 0.0 && !lite) written_luma += (written_luma - rgb_to_yiq((mark_tap(uv - vec2(unit * soft * 3.0, 0.0)).rgb + mark_tap(uv + vec2(unit * soft * 3.0, 0.0)).rgb) * 0.5).x) * 0.35 * vhs;
		vec3 written = yiq_to_rgb(vec3(written_luma, run * (1.0 - vhs * 0.25)));
		// Graded as if on black, less what the grade makes of black itself
		// where nothing is written: the snow beside a word keeps its own.
		written = graded(written) - graded(vec3(0.0)) * (1.0 - body.a);
		written += g * grain * (0.08 + (1.0 - clamp(dot(written, vec3(0.333)) * 1.6, 0.0, 1.0)) * 0.14) * body.a;
		color = color * (1.0 - body.a) + written * lit;
	}
	// The edges of a tape's picture (references 01 and 04): black down both
	// sides, and the line between the black and the picture neither sharp nor
	// still -- it swells, creeps and shivers line by line. Inside the left one
	// the colour is burnt, dark and off its hue; inside the right one there is
	// a thin glow. As wide on the screen whatever the picture's own width.
	if (frame > 0.0 && (at.x < 0.07 || at.x > 0.93)) {
		float edge_row = floor(at.y * 240.0);
		float flick = floor(t * 30.0);
		// The deck's own picture (the boot's, narrower than the screen) keeps the
		// wide ragged black it was liked with; the camera's has less of it, and a
		// shorter, lighter burn (the author, on both, 19 November 2026). Thinner
		// than the straight cut of the narrow picture, the ragged edge showed as
		// a second one inside it.
		float deck = step(0.001, inset);
		float left = mix(0.005 + 0.004 * noise1(at.y * 7.0 + t * 1.9) + 0.0025 * noise1(at.y * 53.0 - t * 6.0) + 0.0012 * noise1(at.y * 150.0 + flick * 7.3), 0.011 + 0.006 * noise1(at.y * 7.0 + t * 1.9) + 0.004 * noise1(at.y * 53.0 - t * 6.0) + 0.0016 * noise1(at.y * 150.0 + flick * 7.3), deck) / wide;
		float right = 1.0 - (0.008 + 0.005 * noise1(at.y * 9.0 - t * 1.4 + 40.0) + 0.003 * noise1(at.y * 61.0 + t * 7.0) + 0.0014 * noise1(at.y * 130.0 - flick * 5.1)) / wide;
		float burn = 1.0 - smoothstep(left, left + mix(0.007, 0.017, deck) / wide, at.x);
		float scorch = 0.75 + 0.5 * line_noise(at.x * 300.0 * wide + flick, edge_row);
		color = mix(color, color * vec3(0.5, 0.34, 0.6) * scorch, burn * mix(0.5, 0.85, deck) * frame);
		float glow = smoothstep(right - 0.009 / wide, right - 0.002 / wide, at.x);
		color += (vec3(0.05, 0.055, 0.07) + color * 0.45) * glow * frame * (0.55 + 0.45 * noise1(at.y * 90.0 + flick * 3.1));
		float open = smoothstep(left - 0.004 / wide, left + 0.004 / wide, at.x) * (1.0 - smoothstep(right - 0.003 / wide, right + 0.003 / wide, at.x));
		color *= mix(1.0, open, frame);
	}
	// Beside the picture, where it is narrower than the screen: nothing.
	color *= step(0.0, at.x) * step(at.x, 1.0);
	COLOR = vec4(max(color, vec3(0.0)), 1.0);
}
