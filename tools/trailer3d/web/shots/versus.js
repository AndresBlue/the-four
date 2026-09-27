// The occupant's view — versus, where one player is The Locust. As the game
// draws it (game/enemies/locust/echo_view.gd, echo_points.gdshader): no light
// at all, only grey grains stamped in the world by clicks twice a second, each
// a shell spreading at 16 m/s; door frames answer brighter; a body in sight
// frozen in its last pose; lit sets glowing yellow through everything. It
// turns. It screams: the whole acoustic world goes red; the one who was
// running shows as a cloud, the one standing still gives back nothing. It
// goes for the first, and runs him down the corridor, clicking as it goes,
// the red cloud of him fleeing ahead. VERSUS — PLAY AS THE LOCUST.
import * as THREE from "three";
import { Survivor, poseRun } from "../engine/survivor.js";
import { text, AMBER } from "../engine/osd.js";
import { clamp, smooth, smoothstep, lerp, rng, fbm1 } from "../engine/util.js";
import { V, aimCamera, tape } from "./common.js";

export const CLICKS = [0.22, 0.7, 1.2, 1.66];
export const TURN = [1.3, 1.6];
export const SHRIEK = 1.78;
export const LUNGE = 2.35;
export const TITLE = 2.25;
// The chase: clicks as it runs, each finding him further down, and nearer.
export const CHASE = [2.8, 3.25, 3.7, 4.15];
const RUN = 5.2;

const WAVE = 16;
// How far down the corridor it has run by time t.
const chaseAt = (t) => (t > LUNGE ? RUN * (t - LUNGE) * smooth((t - LUNGE) / 0.4) : 0);
const EYE = 2.35;

const VERT = /* glsl */ `
attribute float a_click;
attribute float a_span;
attribute float a_kind;
attribute float a_energy;
attribute float a_life;
uniform float time;
uniform float shriek;
uniform float gain;
uniform float residue;
uniform float flare;
uniform float wave;
uniform vec3 cold;
uniform vec3 hot;
uniform vec3 shriekCold;
uniform vec3 shriekHot;
uniform float pixel;
uniform float through;
varying vec3 vColor;
void main() {
	float age = time - a_click;
	float since = max(age - a_span / wave, 0.0);
	float lit = step(0.0, age) * step(a_span / wave, age + 0.0001);
	float flash = exp(-pow(age * wave - a_span, 2.0) / 2.5);
	float memory = clamp(1.0 - since / a_life, 0.0, 1.0);
	float live = (residue + flare * flash) * memory * a_energy * gain * step(0.0, age);
	// Before the front reaches it, nothing.
	live *= smoothstep(-0.2, 0.0, age * wave - a_span);
	vec3 c = mix(mix(cold, hot, a_kind), mix(shriekCold, shriekHot, a_kind), shriek);
	vColor = c * live;
	vec4 mv = modelViewMatrix * vec4(position, 1.0);
	gl_Position = projectionMatrix * mv;
	float grow = 1.0 + 0.8 * flash;
	gl_PointSize = clamp(pixel * grow, 1.0, 6.0);
	if (live < 0.002) gl_PointSize = 0.0;
}`;
const FRAG = /* glsl */ `
varying vec3 vColor;
void main() {
	vec2 d = gl_PointCoord - 0.5;
	float r = length(d) * 2.0;
	float disc = smoothstep(1.0, 0.15, r);
	if (disc <= 0.0) discard;
	gl_FragColor = vec4(vColor * disc, 1.0);
}`;

const lin = (r, g, b) => new THREE.Vector3(...new THREE.Color().setRGB(r, g, b, THREE.SRGBColorSpace).toArray());

function cloud({ gain = 0.95, residue = 0.24, flare = 1.9, wave = WAVE, cold = [0.7, 0.75, 0.78], hot = [1.0, 0.94, 0.88], sc = [1.3, 0.06, 0.03], sh = [1.4, 0.34, 0.22], pixel = 2.4, capacity = 200000 } = {}) {
	const geo = new THREE.BufferGeometry();
	const pos = new Float32Array(capacity * 3);
	const click = new Float32Array(capacity);
	const span = new Float32Array(capacity);
	const kind = new Float32Array(capacity);
	const energy = new Float32Array(capacity);
	const life = new Float32Array(capacity);
	geo.setAttribute("position", new THREE.BufferAttribute(pos, 3));
	geo.setAttribute("a_click", new THREE.BufferAttribute(click, 1));
	geo.setAttribute("a_span", new THREE.BufferAttribute(span, 1));
	geo.setAttribute("a_kind", new THREE.BufferAttribute(kind, 1));
	geo.setAttribute("a_energy", new THREE.BufferAttribute(energy, 1));
	geo.setAttribute("a_life", new THREE.BufferAttribute(life, 1));
	geo.setDrawRange(0, 0);
	const mat = new THREE.ShaderMaterial({
		vertexShader: VERT, fragmentShader: FRAG, transparent: true, depthTest: false, depthWrite: false, blending: THREE.AdditiveBlending,
		uniforms: { time: { value: 0 }, shriek: { value: 0 }, gain: { value: gain }, residue: { value: residue }, flare: { value: flare }, wave: { value: wave },
			cold: { value: lin(...cold) }, hot: { value: lin(...hot) }, shriekCold: { value: lin(...sc) }, shriekHot: { value: lin(...sh) }, pixel: { value: pixel }, through: { value: 1 } },
	});
	const points = new THREE.Points(geo, mat);
	points.frustumCulled = false;
	let n = 0;
	return {
		points, mat,
		add(p, t, s, k = 0, e = 1, l = 9) {
			if (n >= capacity) return;
			pos[n * 3] = p.x; pos[n * 3 + 1] = p.y; pos[n * 3 + 2] = p.z;
			click[n] = t; span[n] = s; kind[n] = k; energy[n] = e; life[n] = l;
			n++;
		},
		done() {
			for (const a of Object.values(geo.attributes)) a.needsUpdate = true;
			geo.setDrawRange(0, n);
		},
	};
}

// The corridor the hunter stands in, as surfaces to stamp grains on.
const HALF = 1.75;
const LEN = 30;
const DOORS = [[1, 5.5], [-1, 8.0], [1, 12.5], [-1, 15.5], [1, 19.0], [-1, 23.0]];

function surfacePoint(r) {
	// Floor, ceiling, walls and the far end, by area.
	const a = r();
	if (a < 0.28) return { p: V(lerp(-HALF, HALF, r()), 0, -r() * LEN), n: V(0, 1, 0) };
	if (a < 0.44) return { p: V(lerp(-HALF, HALF, r()), 3.15, -r() * LEN), n: V(0, -1, 0) };
	if (a < 0.96) {
		const s = r() < 0.5 ? -1 : 1;
		return { p: V(s * HALF, r() * 3.15, -r() * LEN), n: V(-s, 0, 0) };
	}
	return { p: V(lerp(-HALF, HALF, r()), r() * 3.15, -LEN), n: V(0, 0, 1) };
}

export function create(ctx) {
	const scene = new THREE.Scene();
	const camera = new THREE.PerspectiveCamera(66, 16 / 9, 0.05, 120);
	const walls = cloud({ residue: 0.3, gain: 1.1, capacity: 320000 });
	const frames = cloud({ gain: 1.5, residue: 0.5, flare: 2.0, cold: [1.0, 0.97, 0.9], hot: [1.0, 0.97, 0.9], pixel: 3.0 });
	const bodies = cloud({ gain: 1.6, residue: 0.32, flare: 2.4, pixel: 2.4 });
	const finds = cloud({ gain: 1.35, residue: 0.85, flare: 1.1, wave: 4.5, cold: [0.86, 0.9, 0.95], hot: [1.0, 0.97, 0.92], sc: [1.4, 0.18, 0.1], sh: [1.5, 0.4, 0.24], pixel: 2.6 });
	const guides = cloud({ gain: 1.2, residue: 0.9, flare: 1.6, wave: 9, cold: [1.5, 1.05, 0.03], hot: [1.5, 1.05, 0.03], sc: [1.5, 1.05, 0.03], sh: [1.5, 1.05, 0.03], pixel: 3.4 });
	let still;
	let runner;
	const shot = {
		scene, camera, frame: "wide", samples: 12, shutter: 0.5,
		async setup() {
			for (const c of [walls, frames, guides, finds, bodies]) scene.add(c.points);
			still = await Survivor.create();
			still.root.position.set(-0.4, 0, -9.5);
			still.root.rotation.y = 0.3;
			runner = await Survivor.create();
			const random = rng(81);
			const origin = V(0, EYE, 0);
			for (const [ci, click] of CLICKS.entries()) {
				const shriek = click >= SHRIEK - 0.2;
				const count = shriek ? 36000 : 20000;
				for (let i = 0; i < count; i++) {
					const s = surfacePoint(random);
					const dir = s.p.clone().sub(origin);
					const d = dir.length();
					dir.normalize();
					// Most rays go where it faces.
					if (dir.z > -0.2 && random() < 0.55) continue;
					const e = 0.3 + 0.7 * Math.abs(s.n.dot(dir));
					walls.add(s.p, click, d, 0, e * (0.8 + random() * 0.2), 9);
				}
				// Door frames: jambs, heads and shut leaves, brighter and bigger.
				for (const [side, at] of DOORS) {
					for (let k = 0; k < 60; k++) {
						const u = random();
						let p;
						if (k < 44) p = V(side * HALF, u * 2.65, -at + (k % 2 ? 0.65 : -0.65));
						else p = V(side * HALF, 2.65, -at + lerp(-0.65, 0.65, u));
						walls.add(p, click, p.clone().sub(origin).length(), 0, 1, 9);
						frames.add(p, click, p.clone().sub(origin).length(), 0, 1, 5);
					}
				}
				// Lit sets beyond the walls, yellow through everything.
				for (const tv of [V(4.2, 1.2, -7.0), V(-4.5, 1.2, -16.0), V(5.0, 1.2, -24.0)]) {
					for (let k = 0; k < 48; k++) guides.add(tv.clone().add(V((random() - 0.5) * 0.1, (random() - 0.5) * 0.45, (random() - 0.5) * 0.6)), click, tv.clone().sub(origin).length(), 0, 1.6, 60);
					for (let k = 0; k < 14; k++) guides.add(tv.clone().add(V(0, random() * 1.4, 0)), click, tv.clone().sub(origin).length(), 0, 1.2, 60);
				}
				// A body in sight, frozen as the front passed it (not after the scream:
				// it stood still, and the scream only finds what moves).
				if (!shriek && ci >= 1) {
					still.reset();
					still.aim("LeftArm", "LeftForeArm", [0.15, -1, 0.1]);
					still.aim("RightArm", "RightForeArm", [-0.15, -1, 0.1]);
					still.root.updateMatrixWorld(true);
					for (const m of still.meshes) {
						if (!m.isSkinnedMesh) continue;
						const v = new THREE.Vector3();
						const count2 = m.geometry.attributes.position.count;
						for (let k = 0; k < 90; k++) {
							m.getVertexPosition(Math.floor(random() * count2), v);
							const w = v.clone().applyMatrix4(m.matrixWorld);
							bodies.add(w, click, w.clone().sub(origin).length(), 1, 1, 0.75);
						}
					}
				}
			}
			// The scream finds the one running across the room past the far door.
			const random2 = rng(7);
			runner.root.position.set(4.2, 0, -13.0);
			runner.root.rotation.y = -Math.PI / 2;
			runner.reset();
			runner.aim("LeftArm", "LeftForeArm", [0.3, -0.8, 0.5]);
			runner.aim("RightArm", "RightForeArm", [-0.3, -0.8, -0.5]);
			runner.root.updateMatrixWorld(true);
			for (const m of runner.meshes) {
				if (!m.isSkinnedMesh) continue;
				const v = new THREE.Vector3();
				const count2 = m.geometry.attributes.position.count;
				for (let k = 0; k < 260; k++) {
					m.getVertexPosition(Math.floor(random2() * count2), v);
					const w = v.clone().applyMatrix4(m.matrixWorld).add(V((random2() - 0.5) * 0.08, (random2() - 0.5) * 0.08, (random2() - 0.5) * 0.08));
					finds.add(w, SHRIEK + 0.05, w.clone().sub(origin).length() * 0.25, 1, 1, 3.2);
				}
			}
			// Running him down: each click from where it is by then, the corridor
			// red around it, and him a little further on, a little nearer.
			const random3 = rng(19);
			for (const [ci, click] of CHASE.entries()) {
				const from = V(0, EYE, -chaseAt(click));
				for (let i = 0; i < 16000; i++) {
					const s = surfacePoint(random3);
					const dir = s.p.clone().sub(from);
					if (dir.z > 1.0 && random3() < 0.7) continue;
					const d = dir.length();
					dir.normalize();
					walls.add(s.p, click, d, 0, (0.3 + 0.7 * Math.abs(s.n.dot(dir))) * (0.8 + random3() * 0.2), 3);
				}
				runner.root.position.set(0.35 + Math.sin(ci * 1.7) * 0.4, 0, -chaseAt(click) - lerp(7.0, 3.2, ci / (CHASE.length - 1)));
				runner.root.rotation.y = Math.PI + Math.sin(ci * 2.3) * 0.2;
				poseRun(runner, ci * 1.6 + 0.4);
				runner.root.updateMatrixWorld(true);
				for (const m of runner.meshes) {
					if (!m.isSkinnedMesh) continue;
					const v = new THREE.Vector3();
					const count2 = m.geometry.attributes.position.count;
					for (let k = 0; k < 220; k++) {
						m.getVertexPosition(Math.floor(random3() * count2), v);
						const w = v.clone().applyMatrix4(m.matrixWorld).add(V((random3() - 0.5) * 0.06, (random3() - 0.5) * 0.06, (random3() - 0.5) * 0.06));
						finds.add(w, click, w.clone().sub(from).length() * 0.25, 1, 1, 0.9);
					}
				}
			}
			for (const c of [walls, frames, guides, finds, bodies]) c.done();
		},
		update(t) {
			for (const c of [walls, frames, guides, finds, bodies]) {
				c.mat.uniforms.time.value = t;
				c.mat.uniforms.shriek.value = t < SHRIEK ? 0 : clamp((t - SHRIEK) * 6);
			}
			// Its eyes: a slow sway; the turn toward the room; then it goes.
			// Round to the room, then back down the corridor after him.
			const yaw = smoothstep(TURN[0], TURN[1], t) * -0.32 * (1 - smoothstep(LUNGE, LUNGE + 0.45, t));
			const go = chaseAt(t);
			const eye = V(0.15 + fbm1(t * 0.8, 3) * 0.04, EYE + Math.sin(t * (go > 0 ? 9 : 4.2)) * (go > 0 ? 0.035 : 0.01), -go);
			const dir = V(-Math.sin(yaw), -0.06, -Math.cos(yaw));
			aimCamera(camera, eye, eye.clone().add(dir), { roll: fbm1(t * 0.6, 9) * 0.01 });
		},
		look(t) {
			return tape({ exposure: 1.15, vhs: 0.45, grain: 0.35, chromatic: 0.15, vignette: 0.45, scanlines: 0.35, bloom: 0.08, halation: 0.2, tint: [1, 1, 1] });
		},
		overlay(g, t, size) {
			if (t < TITLE) return;
			const u = size.h / 720;
			const a = smoothstep(TITLE, TITLE + 0.2, t);
			text(g, "VERSUS", size.w / 2, size.h * 0.44, { size: 64, align: "center", u, alpha: a, spacing: 10 });
			text(g, "PLAY AS THE LOCUST", size.w / 2, size.h * 0.53, { size: 26, align: "center", color: AMBER, u, alpha: smoothstep(TITLE + 0.2, TITLE + 0.45, t), spacing: 4 });
		},
	};
	return shot;
}
