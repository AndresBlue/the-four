// A CRT's face, as the game's opening draws it (game/intro/tv_screen.gdshader):
// a picture (any texture) under tuner snow, interlace, aperture grille, a
// rolling hum bar and sync tears, blow flashes and glass cracks; plus the
// set being switched on (the line opening out) and off. Unlit: it is a light.
import * as THREE from "three";

const FRAG = /* glsl */ `
uniform vec4 screen_rect;
uniform float time;
uniform float power;
uniform float warm;
uniform float static_amount;
uniform sampler2D image;
uniform float image_amount;
uniform sampler2D cracks;
uniform float crack_level;
uniform float flash;
uniform float roll;
uniform float unstable;
uniform float flicker;
uniform float brightness;
uniform float tint_blue;
uniform float grille;
varying vec2 vUv;
float hash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float crack_at(vec2 uv) {
	vec4 c = texture2D(cracks, uv);
	return max(max(c.r * step(0.5, crack_level), c.g * step(1.5, crack_level)), max(c.b * step(2.5, crack_level), c.a * step(3.5, crack_level)));
}
void main() {
	vec2 uv = (vUv - screen_rect.xy) / screen_rect.zw;
	uv.y = 1.0 - uv.y;
	vec2 tube = uv;
	float t = time;
	float field = floor(t * 60.0);
	vec2 px = vec2(1.0 / 1024.0, 1.0 / 768.0);
	float c = crack_at(tube);
	float cx = crack_at(tube + vec2(px.x * 1.5, 0.0)) - crack_at(tube - vec2(px.x * 1.5, 0.0));
	float cy = crack_at(tube + vec2(0.0, px.y * 1.5)) - crack_at(tube - vec2(0.0, px.y * 1.5));
	uv += vec2(cx, cy) * 0.012;
	uv.y = fract(uv.y + roll);
	float line = floor(uv.y * 240.0);
	float jitter = (hash(vec2(line, field)) - 0.5) * 0.004 * (static_amount + unstable);
	float tear = step(0.985 - unstable * 0.06, hash(vec2(floor(uv.y * 24.0), floor(t * 12.0))));
	uv.x += jitter + tear * (hash(vec2(line, floor(t * 20.0))) - 0.3) * 0.06 * (0.3 + unstable);
	vec2 iuv = vec2(uv.x, 1.0 - uv.y);
	vec3 picture = vec3(texture2D(image, iuv + vec2(0.0015, 0.0)).r, texture2D(image, iuv).g, texture2D(image, iuv - vec2(0.0015, 0.0)).b);
	float snow = hash(floor(uv * vec2(260.0, 240.0)) + field * 7.0);
	float streak = hash(vec2(line, field * 3.0));
	vec3 noise = vec3(snow * 0.85 + step(0.93, streak) * 0.45);
	vec3 colour = mix(noise * 0.9, picture * 1.25, image_amount);
	colour = mix(colour, noise, static_amount * image_amount * 0.55);
	colour += (snow - 0.5) * 0.08 * max(static_amount, 0.15);
	float bar = smoothstep(0.0, 0.12, abs(fract(uv.y - t * 0.11) - 0.5) - 0.28);
	colour *= 0.82 + 0.18 * bar;
	float lines = 0.5 + 0.5 * sin((tube.y * 480.0 + mod(field, 2.0)) * 3.14159);
	colour *= 0.62 + 0.38 * lines;
	float stripe = mod(floor(tube.x * 1100.0), 3.0);
	vec3 g = vec3(stripe == 0.0 ? 1.0 : 0.55, stripe == 1.0 ? 1.0 : 0.55, stripe == 2.0 ? 1.0 : 0.55);
	colour *= mix(vec3(1.0), g * 1.35, 0.45 * grille);
	vec2 centred = tube - 0.5;
	colour *= 1.0 - smoothstep(0.16, 0.5, dot(centred * vec2(1.0, 1.25), centred * vec2(1.0, 1.25))) * 0.75;
	colour *= 1.0 - flicker;
	colour += flash * vec3(0.9, 0.95, 1.0);
	// Switching on: a bright line in the middle opens out into the picture;
	// switching off, the picture folds back into a dot.
	float open = smoothstep(0.0, 1.0, power);
	float band = abs(tube.y - 0.5) * 2.0;
	float shown = smoothstep(open + 0.02, open - 0.02, band);
	float lineGlow = exp(-pow(band / max(0.004, open * 0.08 + 0.003), 2.0)) * (1.0 - open) * step(0.001, power) * 3.0;
	colour = colour * shown + vec3(0.9, 0.95, 1.0) * lineGlow;
	colour *= brightness * (0.7 + 0.3 * warm);
	colour = mix(colour, colour * vec3(0.78, 0.86, 1.08), tint_blue);
	float glint = clamp(abs(cx) + abs(cy), 0.0, 1.0);
	colour = mix(colour, colour * 0.2, c * 0.75);
	colour += (glint * 0.3 + c * 0.05) * (0.35 + 0.65 * power) * vec3(0.95, 0.97, 1.0);
	if (uv.x < 0.0 || uv.x > 1.0) colour *= 0.0;
	gl_FragColor = vec4(max(colour, vec3(0.0)), 1.0);
}`;

const VERT = /* glsl */ `varying vec2 vUv; void main() { vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }`;

let blank = null;
function blankTexture() {
	if (!blank) {
		blank = new THREE.DataTexture(new Uint8Array([0, 0, 0, 255]), 1, 1);
		blank.needsUpdate = true;
	}
	return blank;
}

// rect: the part of the mesh UVs the tube face covers (old_tv: the game's value).
export function crtMaterial({ rect = [0.0128, 0.1364, 0.9745, 0.7213], image = null, strength = 3.2 } = {}) {
	const m = new THREE.ShaderMaterial({
		vertexShader: VERT,
		fragmentShader: FRAG,
		uniforms: {
			screen_rect: { value: new THREE.Vector4(...rect) }, time: { value: 0 }, power: { value: 0 }, warm: { value: 1 },
			static_amount: { value: 1 }, image: { value: image ?? blankTexture() }, image_amount: { value: image ? 1 : 0 },
			cracks: { value: blankTexture() }, crack_level: { value: 0 }, flash: { value: 0 }, roll: { value: 0 }, unstable: { value: 0 },
			flicker: { value: 0 }, brightness: { value: strength }, tint_blue: { value: 0.35 }, grille: { value: 1 },
		},
	});
	m.toneMapped = false;
	return m;
}

// A dead channel's light in the room (hotel_television.gd: cold, breathing,
// stuttering), for a PointLight next to the screen.
export function channelWave(t) {
	const f = t % 100;
	return 0.86 + 0.14 * Math.sin(f * 9.7) + ((f % 1.7) < 0.06 ? 0.16 : 0) + (Math.sin(f * 31.3) * 0.5 + 0.5) * 0.06;
}

export const GLOW = new THREE.Color().setRGB(0.72, 0.82, 1.0, THREE.SRGBColorSpace);
