// The engine: finds the shot on the timeline at a given frame, renders it
// (subframes for a 3D shot), develops it, draws its OSD, puts it through its
// look and composes it into the 1920x1080 canvas (a tape shot is 4:3 in the
// middle, as the camcorder recorded it).
import * as THREE from "three";
import { FPS, Pipeline, renderSubframes, shaderPass } from "./core.js";
import { Looks } from "./looks.js";

const COMPOSE = /* glsl */ `
uniform sampler2D look;
uniform sampler2D over;
uniform vec4 rect;
uniform float tear;
uniform float time;
uniform float fade;
varying vec2 vUv;
float hash(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
void main() {
	vec2 p = vUv;
	if (tear > 0.0) {
		// The 4:3 picture torn into strips that are pulled sideways off the frame.
		float strip = floor(p.y * 27.0);
		float dir = hash(vec2(strip, 1.0)) < 0.5 ? -1.0 : 1.0;
		float delay = hash(vec2(strip, 2.0)) * 0.5;
		float k = clamp((tear - delay) / (1.0 - delay + 1e-4), 0.0, 1.0);
		p.x -= dir * k * k * 1.3 + (hash(vec2(floor(p.y * 540.0), floor(time * 30.0))) - 0.5) * 0.01 * tear;
	}
	vec3 c = vec3(0.0);
	vec2 q = (p - rect.xy) / (rect.zw - rect.xy);
	if (q.x >= 0.0 && q.x <= 1.0 && q.y >= 0.0 && q.y <= 1.0) c = texture2D(look, q).rgb;
	vec4 o = texture2D(over, vUv);
	c = mix(c, o.rgb, o.a);
	c *= 1.0 - fade;
	gl_FragColor = vec4(c, 1.0);
}`;

const COPY = /* glsl */ `
uniform sampler2D src;
varying vec2 vUv;
void main() { gl_FragColor = texture2D(src, vUv); }`;

export class Engine {
	constructor(timeline, options = {}) {
		this.timeline = timeline;
		this.scale = options.scale ?? 1;
		this.samples = options.samples ?? null;
		this.W = Math.round(1920 * this.scale);
		this.H = Math.round(1080 * this.scale);
		const renderer = new THREE.WebGLRenderer({ antialias: false, preserveDrawingBuffer: true, alpha: false, powerPreference: "high-performance" });
		renderer.setPixelRatio(1);
		renderer.setSize(this.W, this.H);
		renderer.outputColorSpace = THREE.LinearSRGBColorSpace;
		renderer.toneMapping = THREE.NoToneMapping;
		renderer.shadowMap.enabled = true;
		renderer.shadowMap.type = THREE.PCFSoftShadowMap;
		renderer.autoClear = false;
		document.body.appendChild(renderer.domElement);
		this.renderer = renderer;
		this.pipes = new Map();
		this.looks = new Looks(renderer);
		this.compose = shaderPass(COMPOSE, { look: { value: null }, over: { value: null }, rect: { value: new THREE.Vector4(0, 0, 1, 1) }, tear: { value: 0 }, time: { value: 0 }, fade: { value: 0 } });
		this.copy = shaderPass(COPY, { src: { value: null } });
		this.shots = new Map();
		this.canvases = new Map();
		this.over = this.canvas(this.W, this.H, "over");
		this.context = { THREE, engine: this, renderer, FPS, debug: new URLSearchParams(location.search).has("debug") };
	}

	pipe(w, h) {
		const key = `${w}x${h}`;
		if (!this.pipes.has(key)) {
			const p = new Pipeline(this.renderer, w, h);
			p.history = new THREE.WebGLRenderTarget(w, h, { type: THREE.HalfFloatType, depthBuffer: false });
			this.pipes.set(key, p);
		}
		return this.pipes.get(key);
	}

	canvas(w, h, name) {
		const key = `${name}:${w}x${h}`;
		if (!this.canvases.has(key)) {
			const c = document.createElement("canvas");
			c.width = w;
			c.height = h;
			const tex = new THREE.CanvasTexture(c);
			tex.colorSpace = THREE.NoColorSpace;
			tex.minFilter = THREE.LinearFilter;
			tex.generateMipmaps = false;
			this.canvases.set(key, { canvas: c, ctx: c.getContext("2d"), texture: tex });
		}
		return this.canvases.get(key);
	}

	entryAt(time) {
		const shots = this.timeline.shots;
		for (const e of shots) if (time >= e.start && time < e.end) return e;
		return shots[shots.length - 1];
	}

	get length() {
		return this.timeline.shots[this.timeline.shots.length - 1].end;
	}

	async prepare(entry) {
		if (this.shots.has(entry.id)) return this.shots.get(entry.id);
		// Keep memory down: a shot is dropped once the timeline has moved past it.
		for (const [id, s] of this.shots) {
			const e = this.timeline.shots.find((x) => x.id === id);
			if (e && e.end <= entry.start && !(entry.keep ?? []).includes(id)) {
				s.dispose?.();
				this.shots.delete(id);
			}
		}
		const module = await import(`../shots/${entry.module}.js`);
		const shot = module.create({ ...this.context, entry, marks: entry.marks ?? {}, params: entry.params ?? {} });
		if (shot.setup) await shot.setup();
		this.shots.set(entry.id, shot);
		return shot;
	}

	async renderFrame(frame) {
		const time = frame / FPS;
		const entry = this.entryAt(time);
		const shot = await this.prepare(entry);
		const t = time - entry.start;
		const kind = shot.frame ?? "tape";
		const h = this.H;
		const w = kind === "tape" ? Math.round((h * 4) / 3) : this.W;
		const pipe = this.pipe(w, h);
		const samples = Math.max(1, Math.round(this.samples ?? shot.samples ?? 32));
		if (shot.render2D) {
			pipe.setAverage(shot.render2D(t, pipe) ?? null);
		} else if (shot.scene) {
			if (shot.camera.aspect !== w / h) {
				shot.camera.aspect = w / h;
				shot.camera.updateProjectionMatrix();
			}
			renderSubframes(this, pipe, shot, t, samples);
		} else {
			pipe.begin();
			this.renderer.setRenderTarget(pipe.acc[pipe.current]);
			this.renderer.setClearColor(0x000000, 1);
			this.renderer.clear();
		}
		const params = shot.look ? shot.look(t) : {};
		const ldr = pipe.developImage(params);
		const osd = this.canvas(w, h, "osd");
		osd.ctx.setTransform(1, 0, 0, 1, 0, 0);
		osd.ctx.clearRect(0, 0, w, h);
		if (shot.overlay) shot.overlay(osd.ctx, t, { w, h, time });
		osd.texture.needsUpdate = true;
		const lookKind = params.kind ?? (kind === "tape" ? "tape" : "clean");
		this.looks.apply(lookKind, ldr, osd.texture, pipe.look, time, params, pipe.history.texture);
		// This frame's picture is next frame's history (the tape dragging).
		this.copy.material.uniforms.src.value = pipe.look.texture;
		this.renderer.setRenderTarget(pipe.history);
		this.copy.render(this.renderer);
		const over = this.over;
		over.ctx.setTransform(1, 0, 0, 1, 0, 0);
		over.ctx.clearRect(0, 0, this.W, this.H);
		if (shot.overlayClean) shot.overlayClean(over.ctx, t, { w: this.W, h: this.H, time });
		over.texture.needsUpdate = true;
		const u = this.compose.material.uniforms;
		u.look.value = pipe.look.texture;
		u.over.value = over.texture;
		const x0 = (this.W - w) / 2 / this.W;
		u.rect.value.set(x0, 0, 1 - x0, 1);
		u.tear.value = params.frameTear ?? 0;
		u.time.value = time;
		u.fade.value = params.fadeAll ?? 0;
		this.renderer.setRenderTarget(null);
		this.compose.render(this.renderer);
		return { shot: entry.id, t };
	}

	async save(path) {
		const blob = await new Promise((resolve) => this.renderer.domElement.toBlob(resolve, "image/png"));
		const res = await fetch(`/save?path=${encodeURIComponent(path)}`, { method: "POST", body: blob });
		if (!res.ok) throw new Error(`save failed: ${await res.text()}`);
	}
}
