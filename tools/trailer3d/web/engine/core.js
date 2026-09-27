// The render core: each output frame is the average of many subframes, each
// with its own sub-pixel jitter (anti-aliasing), point on the lens (depth of
// field), instant inside the shutter (motion blur) and, if the shot asks, its
// own light jitter (soft shadows). Then bloom, the camera's response and the
// shot's "look" (tape, clean or screen) on the result.
import * as THREE from "three";
import { FullScreenQuad } from "three/addons/postprocessing/Pass.js";
import { halton, rng } from "./util.js";

export const FPS = 30;

const VERT = /* glsl */ `
varying vec2 vUv;
void main() { vUv = uv; gl_Position = vec4(position.xy, 0.0, 1.0); }`;

export function shaderPass(fragmentShader, uniforms = {}, extra = {}) {
	return new FullScreenQuad(new THREE.ShaderMaterial({ vertexShader: VERT, fragmentShader, uniforms, depthTest: false, depthWrite: false, ...extra }));
}

function target(w, h, type = THREE.HalfFloatType, extra = {}) {
	const rt = new THREE.WebGLRenderTarget(w, h, { type, format: THREE.RGBAFormat, minFilter: THREE.LinearFilter, magFilter: THREE.LinearFilter, depthBuffer: false, ...extra });
	rt.texture.generateMipmaps = false;
	return rt;
}

const ACCUMULATE = /* glsl */ `
uniform sampler2D previous;
uniform sampler2D current;
uniform sampler2D haze;
uniform float hasHaze;
uniform float weight;
uniform float first;
varying vec2 vUv;
void main() {
	vec4 c = texture2D(current, vUv);
	if (hasHaze > 0.5) c.rgb += texture2D(haze, vUv).rgb;
	// A NaN or an infinity anywhere would spread through the bloom to everything.
	if (any(isnan(c)) || any(isinf(c))) c = vec4(0.0);
	c = min(c, vec4(65000.0)) * weight;
	gl_FragColor = first > 0.5 ? c : texture2D(previous, vUv) + c;
}`;

// Bloom: a mip chain (13-tap down, tent up), as a physically based glare.
const DOWN = /* glsl */ `
uniform sampler2D src;
uniform vec2 texel;
uniform float first;
varying vec2 vUv;
vec3 s(vec2 o) { return texture2D(src, vUv + o * texel).rgb; }
void main() {
	vec3 a = s(vec2(-2.0, 2.0)), b = s(vec2(0.0, 2.0)), c = s(vec2(2.0, 2.0));
	vec3 d = s(vec2(-2.0, 0.0)), e = s(vec2(0.0)), f = s(vec2(2.0, 0.0));
	vec3 g = s(vec2(-2.0, -2.0)), h = s(vec2(0.0, -2.0)), i = s(vec2(2.0, -2.0));
	vec3 j = s(vec2(-1.0, 1.0)), k = s(vec2(1.0, 1.0)), l = s(vec2(-1.0, -1.0)), m = s(vec2(1.0, -1.0));
	vec3 col = e * 0.125 + (a + c + g + i) * 0.03125 + (b + d + f + h) * 0.0625 + (j + k + l + m) * 0.125;
	if (first > 0.5) col = min(col, vec3(64.0));
	gl_FragColor = vec4(col, 1.0);
}`;
const UP = /* glsl */ `
uniform sampler2D src;
uniform sampler2D base;
uniform vec2 texel;
uniform float radius;
varying vec2 vUv;
vec3 s(vec2 o) { return texture2D(src, vUv + o * texel * radius).rgb; }
void main() {
	vec3 col = s(vec2(0.0)) * 4.0 + (s(vec2(-1.0, 0.0)) + s(vec2(1.0, 0.0)) + s(vec2(0.0, -1.0)) + s(vec2(0.0, 1.0))) * 2.0
		+ s(vec2(-1.0, -1.0)) + s(vec2(1.0, -1.0)) + s(vec2(-1.0, 1.0)) + s(vec2(1.0, 1.0));
	gl_FragColor = vec4(texture2D(base, vUv).rgb + col / 16.0, 1.0);
}`;

// Exposure, bloom mix, halation, a filmic curve and the grade, then sRGB.
const DEVELOP = /* glsl */ `
uniform sampler2D image;
uniform sampler2D glow;
uniform float exposure;
uniform float bloom;
uniform float halation;
uniform vec3 white_balance;
uniform float saturation;
uniform float contrast;
uniform vec3 lift;
uniform vec3 gain;
uniform float shoulder;
varying vec2 vUv;
vec3 tonemap(vec3 x) {
	// A soft filmic shoulder that never clips abruptly (camcorder CCD-like when high).
	vec3 a = x * (1.0 + x / (shoulder * shoulder));
	return a / (1.0 + a);
}
vec3 to_srgb(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
}
void main() {
	vec3 c = texture2D(image, vUv).rgb;
	// The up chain sums its six levels: back to one image's energy.
	vec3 g = texture2D(glow, vUv).rgb / 6.0;
	c = mix(c, g, bloom);
	// Halation: the reddish bloom film and old tubes leave round highlights.
	vec3 hot = max(g - 0.6, vec3(0.0));
	c += hot * vec3(1.0, 0.35, 0.18) * halation;
	c *= exposure * white_balance;
	c = tonemap(c);
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(vec3(l), c, saturation);
	c = (c - 0.18) * contrast + 0.18;
	c = max(c, vec3(0.0));
	c = c * gain + lift * (1.0 - c);
	gl_FragColor = vec4(to_srgb(c), 1.0);
}`;

export class Pipeline {
	constructor(renderer, w, h) {
		this.renderer = renderer;
		this.w = w;
		this.h = h;
		this.scene = target(w, h, THREE.HalfFloatType, { depthBuffer: true });
		this.scene.depthTexture = new THREE.DepthTexture(w, h, THREE.FloatType);
		this.acc = [target(w, h, THREE.FloatType), target(w, h, THREE.FloatType)];
		// The haze lit by the lamps (volumetric.js), added to each subframe.
		this.vol = target(w, h, THREE.HalfFloatType);
		this.ldr = target(w, h, THREE.HalfFloatType);
		this.look = target(w, h, THREE.HalfFloatType);
		this.mips = [];
		let mw = w;
		let mh = h;
		for (let i = 0; i < 6; i++) {
			mw = Math.max(1, Math.floor(mw / 2));
			mh = Math.max(1, Math.floor(mh / 2));
			this.mips.push({ down: target(mw, mh), up: target(mw, mh), w: mw, h: mh });
		}
		this.accumulate = shaderPass(ACCUMULATE, { previous: { value: null }, current: { value: null }, haze: { value: null }, hasHaze: { value: 0 }, weight: { value: 1 }, first: { value: 1 } });
		this.down = shaderPass(DOWN, { src: { value: null }, texel: { value: new THREE.Vector2() }, first: { value: 0 } });
		this.up = shaderPass(UP, { src: { value: null }, base: { value: null }, texel: { value: new THREE.Vector2() }, radius: { value: 1 } });
		this.develop = shaderPass(DEVELOP, {
			image: { value: null }, glow: { value: null }, exposure: { value: 1 }, bloom: { value: 0.04 }, halation: { value: 0.0 },
			white_balance: { value: new THREE.Vector3(1, 1, 1) }, saturation: { value: 1 }, contrast: { value: 1 },
			lift: { value: new THREE.Vector3(0, 0, 0) }, gain: { value: new THREE.Vector3(1, 1, 1) }, shoulder: { value: 2.5 },
		});
		this.current = 0;
		this.count = 0;
	}

	begin() {
		this.count = 0;
	}

	// Adds this.scene's colour to the average with the given weight.
	add(weight, haze = false) {
		const r = this.renderer;
		const src = this.acc[this.current];
		const dst = this.acc[1 - this.current];
		const u = this.accumulate.material.uniforms;
		u.previous.value = src.texture;
		u.current.value = this.scene.texture;
		u.haze.value = this.vol.texture;
		u.hasHaze.value = haze ? 1 : 0;
		u.weight.value = weight;
		u.first.value = this.count === 0 ? 1 : 0;
		r.setRenderTarget(dst);
		this.accumulate.render(r);
		this.current = 1 - this.current;
		this.count++;
	}

	get average() {
		return this.acc[this.current].texture;
	}

	// Loads an already-made linear image (a 2D shot) as the average.
	setAverage(texture) {
		this.count = 1;
		this.accumulate.material.uniforms.previous.value = texture;
		this.accumulate.material.uniforms.current.value = texture;
		this.accumulate.material.uniforms.weight.value = 0;
		this.accumulate.material.uniforms.first.value = 0;
		this.accumulate.material.uniforms.hasHaze.value = 0;
		this.renderer.setRenderTarget(this.acc[1 - this.current]);
		this.accumulate.render(this.renderer);
		this.current = 1 - this.current;
	}

	// Bloom and development of the average into this.ldr (sRGB).
	developImage(p) {
		const r = this.renderer;
		let src = this.average;
		let sw = this.w;
		let sh = this.h;
		for (let i = 0; i < this.mips.length; i++) {
			const m = this.mips[i];
			const u = this.down.material.uniforms;
			u.src.value = src;
			u.texel.value.set(1 / sw, 1 / sh);
			u.first.value = i === 0 ? 1 : 0;
			r.setRenderTarget(m.down);
			this.down.render(r);
			src = m.down.texture;
			sw = m.w;
			sh = m.h;
		}
		let up = this.mips[this.mips.length - 1].down.texture;
		for (let i = this.mips.length - 2; i >= 0; i--) {
			const m = this.mips[i];
			const u = this.up.material.uniforms;
			u.src.value = up;
			u.base.value = m.down.texture;
			u.texel.value.set(1 / this.mips[i + 1].w, 1 / this.mips[i + 1].h);
			u.radius.value = p.bloomRadius ?? 1;
			r.setRenderTarget(m.up);
			this.up.render(r);
			up = m.up.texture;
		}
		const u = this.develop.material.uniforms;
		u.image.value = this.average;
		u.glow.value = up;
		u.exposure.value = p.exposure ?? 1;
		u.bloom.value = p.bloom ?? 0.04;
		u.halation.value = p.halation ?? 0;
		u.white_balance.value.fromArray(p.whiteBalance ?? [1, 1, 1]);
		u.saturation.value = p.saturation ?? 1;
		u.contrast.value = p.contrast ?? 1;
		u.lift.value.fromArray(p.lift ?? [0, 0, 0]);
		u.gain.value.fromArray(p.gain ?? [1, 1, 1]);
		u.shoulder.value = p.shoulder ?? 2.5;
		r.setRenderTarget(this.ldr);
		this.develop.render(r);
		return this.ldr.texture;
	}
}

// Renders a shot's scene for local time t into pipeline.average.
export function renderSubframes(engine, pipe, shot, t, samples) {
	const r = engine.renderer;
	const cam = shot.camera;
	const shutter = shot.shutter ?? 0.5;
	pipe.begin();
	const seedBase = Math.floor(t * FPS * 97) >>> 0;
	for (let s = 0; s < samples; s++) {
		const u = samples > 1 ? (s + 0.5) / samples : 0.5;
		const ts = t + (u - 0.5) * (shutter / FPS);
		shot.update(ts, { sample: s, samples, frameTime: t });
		cam.updateMatrixWorld();
		cam.updateProjectionMatrix();
		// Lens: a point on the aperture disk, re-aimed so the focus plane holds.
		const jx = samples > 1 ? halton(s + 1, 2) - 0.5 : 0;
		const jy = samples > 1 ? halton(s + 1, 3) - 0.5 : 0;
		const P = cam.projectionMatrix.elements;
		const saved = [P[8], P[9]];
		const aperture = shot.aperture ?? 0;
		const focus = shot.focus ?? 5;
		let offset = null;
		if (aperture > 0 && samples > 1) {
			const a = halton(s + 1, 5) * Math.PI * 2;
			const rr = Math.sqrt(halton(s + 1, 7)) * aperture;
			const dx = Math.cos(a) * rr;
			const dy = Math.sin(a) * rr;
			offset = new THREE.Vector3(dx, dy, 0).applyQuaternion(cam.quaternion);
			cam.position.add(offset);
			cam.updateMatrixWorld();
			P[8] -= (P[0] * dx) / focus;
			P[9] -= (P[5] * dy) / focus;
		}
		P[8] += (jx * 2) / pipe.w;
		P[9] += (jy * 2) / pipe.h;
		cam.projectionMatrixInverse.copy(cam.projectionMatrix).invert();
		if (shot.beforeRender) shot.beforeRender({ sample: s, samples, random: rng(seedBase + s * 7919), jitter: [jx, jy] });
		// Shadow maps once a frame: the lamps do not move within a shutter.
		r.shadowMap.autoUpdate = false;
		r.shadowMap.needsUpdate = s === 0 || !!shot.shadowsEverySample;
		r.setRenderTarget(pipe.scene);
		r.setClearColor(0x000000, 1);
		r.clear();
		r.render(shot.scene, cam);
		if (shot.afterRender) shot.afterRender(pipe, { sample: s, samples, random: rng(seedBase + s * 104729) });
		if (shot.volumetrics) shot.volumetrics.render(pipe, cam, shot.scene, { time: ts, random: rng(seedBase + s * 15485863) });
		pipe.add(1 / samples, !!shot.volumetrics);
		P[8] = saved[0];
		P[9] = saved[1];
		if (offset) cam.position.sub(offset);
	}
	cam.updateProjectionMatrix();
}
