// The looks a developed image goes through before it is shown.
//  TAPE  the guests' camcorder on VHS: the game's own analog.gdshader
//        (game/presentation/shaders/analog.gdshader) ported line by line, with
//        what a trailer also needs from a tape (tracking breaking, rewind,
//        rolling, the picture dragging, a torn frame, full snow).
//  CLEAN the archive room as a camera sees it today: grain and a soft edge.
import * as THREE from "three";
import { shaderPass } from "./core.js";

const COMMON = /* glsl */ `
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
`;

const TAPE = /* glsl */ `
uniform sampler2D image;
uniform sampler2D osd;
uniform sampler2D history;
uniform vec2 resolution;
uniform float time;
uniform float vhs;
uniform float grain;
uniform float chromatic;
uniform float scanlines;
uniform vec3 tint;
uniform float vignette;
uniform float enclosure;
uniform float threat_glitch;
uniform float signal_loss;
uniform float strike_fill;
uniform vec2 strike_point;
// Trailer additions.
uniform float tracking;   // the tape's tracking breaking: 0..1
uniform float rewind;     // shuttle search/rewind picture: 0..1
uniform float roll;       // vertical hold lost: the picture's vertical offset (0..1 of a frame)
uniform float drag;       // the head going: colour smear and the picture dragging behind
uniform float jerk;       // one frame of the tape jumping sideways
uniform float tear;       // the frame torn into horizontal strips (0..1)
uniform float snow;       // tuner snow mixed over everything
uniform float fade;       // to black
uniform float osd_level;  // how strongly the burned-in OSD shows
varying vec2 vUv;
${COMMON}
vec3 raw(vec2 uv) {
	vec2 c = clamp(uv, vec2(0.0005), vec2(0.9995));
	vec3 img = texture2D(image, c).rgb;
	vec4 o = texture2D(osd, c);
	return mix(img, o.rgb, o.a * osd_level);
}
vec3 tap(vec2 uv) {
	vec3 c = raw(uv);
	if (drag > 0.0) {
		// The picture dragging: last frame's image left behind, a little to the right.
		vec3 h = texture2D(history, clamp(uv - vec2(drag * 0.004, 0.0), vec2(0.0005), vec2(0.9995))).rgb;
		c = mix(c, max(c, h * 0.92), drag * 0.55);
	}
	return c;
}
void main() {
	vec2 px = 1.0 / resolution;
	float t = time;
	vec2 uv = vUv;
	vec2 screen = vUv;
	vec2 centred = uv - 0.5;
	uv = 0.5 + centred * (1.0 - enclosure * 0.12 * (1.0 - dot(centred, centred) * 2.0));
	// Vertical hold: the picture rolls, the blanking bar between frames shows.
	uv.y = fract(uv.y + roll);
	float blank = roll > 0.0 ? smoothstep(0.0, 0.025, abs(fract(screen.y + roll) - 0.0)) * smoothstep(0.0, 0.025, abs(1.0 - fract(screen.y + roll))) : 1.0;
	float line = floor(uv.y / px.y);
	float wobble = (noise1(uv.y * 38.0 + t * 1.3) - 0.5) * 0.0022 + sin(uv.y * 190.0 + t * 3.0) * 0.00035;
	float band_pos = fract(t * 0.043);
	float band = smoothstep(0.06, 0.0, abs(uv.y - band_pos)) * (0.6 + 0.4 * noise1(t * 4.0));
	// Tracking breaking: the band grows, multiplies and throws lines about.
	float tb = 0.0;
	if (tracking > 0.0) {
		float p1 = fract(t * 0.61 + 0.2);
		float p2 = fract(-t * 0.37 + 0.7);
		tb = max(smoothstep(0.16, 0.0, abs(uv.y - p1)), smoothstep(0.1, 0.0, abs(uv.y - p2)) * 0.8) * tracking;
		tb = max(tb, step(0.82, hash(vec2(floor(uv.y * 60.0), floor(t * 30.0)))) * tracking * 0.7);
		band = max(band, tb);
	}
	float jitter = (hash(vec2(line, floor(t * 30.0))) - 0.5) * 0.004 * band;
	float head = smoothstep(0.035, 0.0, 1.0 - uv.y);
	float head_tear = head * (0.012 + (hash(vec2(floor(t * 24.0), line)) - 0.5) * 0.01);
	uv.x += (wobble + jitter) * vhs + head_tear * vhs;
	uv.x += (hash(vec2(line * 0.5, floor(t * 30.0))) - 0.5) * 0.06 * tb;
	float glitch_row = step(0.6, hash(vec2(floor(uv.y * 38.0), floor(t * 20.0))));
	uv.x += (hash(vec2(floor(uv.y * 90.0), floor(t * 30.0))) - 0.5) * 0.05 * threat_glitch * glitch_row;
	// Rewind: the picture skews and slides, broken by noise bars.
	if (rewind > 0.0) {
		uv.x += (uv.y - 0.5) * 0.08 * rewind + (noise1(uv.y * 12.0 + t * 40.0) - 0.5) * 0.04 * rewind;
		uv.y = fract(uv.y + t * 3.7 * rewind);
	}
	uv.x += jerk * 0.035;
	// Torn frame: strips of the picture pulled sideways, more and more.
	if (tear > 0.0) {
		float strip = floor(screen.y * 26.0);
		float pull = (hash(vec2(strip, 4.0)) - 0.5) * 2.0;
		uv.x += pull * tear * tear * 1.4 + (hash(vec2(line, floor(t * 30.0))) - 0.5) * 0.02 * tear;
	}
	float soft = 1.0 + vhs * 2.5;
	vec3 center = tap(uv);
	vec3 blur_l = tap(uv - vec2(px.x * soft, 0.0));
	vec3 blur_r = tap(uv + vec2(px.x * soft, 0.0));
	float luma = rgb_to_yiq(center * 0.5 + (blur_l + blur_r) * 0.25).x;
	if (vhs > 0.0) {
		float far_luma = rgb_to_yiq(tap(uv - vec2(px.x * soft * 3.0, 0.0)) * 0.5 + tap(uv + vec2(px.x * soft * 3.0, 0.0)) * 0.5).x;
		luma += (luma - far_luma) * 0.35 * vhs;
	}
	vec2 chroma = vec2(0.0);
	float chroma_width = px.x * (1.5 + vhs * 9.0) * (1.0 + drag * 2.5);
	float chroma_delay = px.x * vhs * 3.0 + px.x * drag * 14.0;
	for (int i = 0; i < 7; i++) {
		vec3 sample_yiq = rgb_to_yiq(tap(uv + vec2((-3.0 + float(i)) * chroma_width + chroma_delay, 0.0)));
		chroma += sample_yiq.yz;
	}
	chroma /= 7.0;
	chroma *= 1.0 - vhs * 0.25;
	// Chroma noise: VHS colour wanders along each line in long streaks.
	float cn = (noise1(uv.x * 40.0 + line * 7.13 + floor(t * 30.0) * 3.1) - 0.5) * vhs * 0.05;
	chroma += vec2(cn, -cn * 0.6);
	vec3 color = yiq_to_rgb(vec3(luma, chroma));
	vec2 from_center = vUv - 0.5;
	vec2 fringe = from_center * dot(from_center, from_center) * chromatic * 0.045 + vec2(chromatic * px.x * 2.0, 0.0);
	if (chromatic > 0.0) {
		color.r = mix(color.r, tap(uv + fringe).r, clamp(chromatic * 3.0, 0.0, 1.0));
		color.b = mix(color.b, tap(uv - fringe).b, clamp(chromatic * 3.0, 0.0, 1.0));
	}
	float grade = clamp(vhs * 2.2, 0.0, 1.0);
	color = mix(color, color * tint, grade);
	color = mix(color, vec3(0.035, 0.035, 0.03) + color * 0.93, grade);
	color = mix(color, 1.0 - exp(-color * 1.25), grade * 0.6);
	float sn = hash(vec2(uv.x * 900.0 + t * 60.0, line));
	color += (sn - 0.5) * band * 0.25 * vhs;
	color += (sn - 0.5) * tb * 0.9;
	float field_row = floor(vUv.y * 240.0);
	float dropout_frame = floor(t * 30.0);
	float chance = vhs * 0.0012 + tracking * 0.01;
	float hit = step(1.0 - chance, hash(vec2(dropout_frame, field_row)));
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
	color = mix(color, vec3(sn * 0.8), head * vhs * 0.55);
	// Rewind noise bars: bright torn lines racing through the picture.
	if (rewind > 0.0) {
		// Two or three narrow bands of noise racing down a skewed picture.
		float bars = smoothstep(0.41, 0.47, abs(fract(vUv.y * 1.6 - t * 5.0) - 0.5));
		float grit = hash(vec2(floor(vUv.x * 300.0), line + floor(t * 60.0)));
		color = mix(color, vec3(grit * 0.9), bars * rewind);
		color = mix(color, vec3(dot(color, vec3(0.33))), rewind * 0.3);
	}
	float g = hash(vUv * vec2(1731.0, 977.0) + fract(t * 23.0)) - 0.5;
	float dark = 1.0 - clamp(dot(color, vec3(0.333)) * 1.6, 0.0, 1.0);
	color += g * grain * (0.08 + dark * 0.14);
	float scan = 0.5 + 0.5 * cos(vUv.y * 240.0 * 6.28318);
	color *= 1.0 - scanlines * 0.28 * scan;
	color *= 1.0 + scanlines * 0.06;
	float edge = dot(from_center * vec2(1.1, 1.0), from_center * vec2(1.1, 1.0));
	color *= 1.0 - smoothstep(0.12, 0.6, edge) * vignette * clamp(vhs * 3.0, 0.3, 1.0);
	color *= 1.0 - (noise1(t * 11.0) - 0.5) * 0.03 * vhs;
	float closed_in = smoothstep(0.05, 0.42, edge);
	color *= 1.0 - closed_in * enclosure * 0.85;
	if (strike_fill > 0.0) {
		vec2 away = (vUv - strike_point) * vec2(1.0, 0.78);
		float angle = atan(away.y, away.x);
		float ragged = 1.0 + (hash(vec2(floor(angle * 2.5), floor(t * 18.0))) - 0.5) * 0.3 + (hash(vec2(floor(angle * 6.0), 3.0)) - 0.5) * 0.12;
		float radius = pow(strike_fill, 2.2) * 2.0 * ragged;
		float covered = 1.0 - smoothstep(radius * 0.9, radius, length(away));
		color *= 1.0 - covered;
	}
	float loss = clamp(max(signal_loss, snow), 0.0, 1.0);
	if (loss > 0.0) {
		float field = floor(t * 50.0);
		vec2 rolled = vec2(uv.x, fract(vUv.y + t * (0.02 + signal_loss * 0.55)));
		float row = floor(rolled.y * 240.0);
		float rip = step(0.96 - loss * 0.05, hash(vec2(floor(rolled.y * 24.0), floor(t * 12.0))));
		rolled.x += (hash(vec2(row, field)) - 0.5) * 0.02 * loss + rip * (hash(vec2(row, floor(t * 20.0))) - 0.3) * 0.12 * loss;
		vec3 torn = tap(vec2(fract(rolled.x), uv.y));
		color = mix(color, torn, signal_loss * 0.85);
		color = mix(color, vec3(dot(color, vec3(0.333))), signal_loss * 0.85);
		float s2 = hash(floor(rolled * vec2(260.0, 240.0)) + field * 7.0);
		float streak = hash(vec2(row, field * 3.0));
		vec3 dead = vec3(s2 * 0.85 + step(0.93, streak) * 0.45);
		float bar = smoothstep(0.0, 0.12, abs(fract(rolled.y - t * 0.11) - 0.5) - 0.28);
		dead *= 0.82 + 0.18 * bar;
		float lines = 0.5 + 0.5 * sin((vUv.y * 480.0 + mod(field, 2.0)) * 3.14159);
		dead *= 0.62 + 0.38 * lines;
		color = mix(color, dead, smoothstep(0.1, 0.85, loss));
		color *= 1.0 - (noise1(t * 21.0) - 0.5) * 0.22 * loss;
	}
	color *= blank;
	color *= 1.0 - fade;
	gl_FragColor = vec4(max(color, vec3(0.0)), 1.0);
}`;

const CLEAN = /* glsl */ `
uniform sampler2D image;
uniform sampler2D osd;
uniform vec2 resolution;
uniform float time;
uniform float grain;
uniform float vignette;
uniform float chromatic;
uniform float fade;
uniform float osd_level;
varying vec2 vUv;
${COMMON}
void main() {
	vec2 from_center = vUv - 0.5;
	vec2 fringe = from_center * dot(from_center, from_center) * chromatic * 0.02;
	vec3 c = vec3(texture2D(image, vUv + fringe).r, texture2D(image, vUv).g, texture2D(image, vUv - fringe).b);
	vec4 o = texture2D(osd, vUv);
	c = mix(c, o.rgb, o.a * osd_level);
	// Fine, soft film grain that lives in the mid-tones.
	float g = (hash(vUv * resolution + fract(time * 17.0) * 311.0) + hash(vUv * resolution * 0.5 + fract(time * 29.0) * 97.0)) * 0.5 - 0.5;
	float l = dot(c, vec3(0.333));
	c += g * grain * (0.35 + 0.65 * (1.0 - abs(l * 2.0 - 1.0)));
	float edge = dot(from_center * vec2(1.2, 1.0), from_center * vec2(1.2, 1.0));
	c *= 1.0 - smoothstep(0.1, 0.7, edge) * vignette;
	c *= 1.0 - fade;
	gl_FragColor = vec4(max(c, vec3(0.0)), 1.0);
}`;

export const TAPE_DEFAULTS = {
	vhs: 0.42, grain: 0.22, chromatic: 0.1, scanlines: 0.3, tint: [1.02, 1.0, 0.9], vignette: 0.5,
	enclosure: 0, threat_glitch: 0, signal_loss: 0, strike_fill: 0, strike_point: [0.3, 0.5],
	tracking: 0, rewind: 0, roll: 0, drag: 0, jerk: 0, tear: 0, snow: 0, fade: 0, osd_level: 1,
};
export const CLEAN_DEFAULTS = { grain: 0.035, vignette: 0.35, chromatic: 0.4, fade: 0, osd_level: 1 };

export class Looks {
	constructor(renderer) {
		this.renderer = renderer;
		const u = (v) => ({ value: v });
		this.tape = shaderPass(TAPE, {
			image: u(null), osd: u(null), history: u(null), resolution: u(new THREE.Vector2()), time: u(0),
			vhs: u(0), grain: u(0), chromatic: u(0), scanlines: u(0), tint: u(new THREE.Vector3(1, 1, 1)), vignette: u(0),
			enclosure: u(0), threat_glitch: u(0), signal_loss: u(0), strike_fill: u(0), strike_point: u(new THREE.Vector2(0.5, 0.5)),
			tracking: u(0), rewind: u(0), roll: u(0), drag: u(0), jerk: u(0), tear: u(0), snow: u(0), fade: u(0), osd_level: u(1),
		});
		this.clean = shaderPass(CLEAN, {
			image: u(null), osd: u(null), resolution: u(new THREE.Vector2()), time: u(0), grain: u(0), vignette: u(0), chromatic: u(0), fade: u(0), osd_level: u(1),
		});
	}

	// Runs a look from `image` into `out` (a render target), with an OSD texture.
	apply(kind, image, osd, out, time, params, history) {
		const pass = kind === "tape" ? this.tape : this.clean;
		const defaults = kind === "tape" ? TAPE_DEFAULTS : CLEAN_DEFAULTS;
		const u = pass.material.uniforms;
		u.image.value = image;
		u.osd.value = osd;
		u.resolution.value.set(out.width, out.height);
		u.time.value = time;
		if (u.history) u.history.value = history ?? image;
		for (const [k, v0] of Object.entries(defaults)) {
			const v = params[k] ?? v0;
			if (!u[k]) continue;
			if (Array.isArray(v)) u[k].value.fromArray(v);
			else u[k].value = v;
		}
		this.renderer.setRenderTarget(out);
		pass.render(this.renderer);
	}
}
