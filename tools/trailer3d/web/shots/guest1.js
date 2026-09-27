// GUEST 01 — he ran. One shot, first person: the run down the corridor, the
// torch swinging with each step; he looks back over his shoulder and it is
// there, running after him, closing; it throws itself at the lens. Black,
// then snow.
import * as THREE from "three";
import { Kit } from "../engine/kit.js";
import { corridor } from "../engine/sets.js";
import { Locust } from "../engine/locust.js";
import { Volumetrics } from "../engine/volumetric.js";
import { camcorder, burnIn, typed } from "../engine/osd.js";
import { clamp, smooth, smoothstep, easeIn, easeOut, keys, lerp, fbm1 } from "../engine/util.js";
import { V, handheld, steps, aimCamera, makeTorch, holdTorch, tape } from "./common.js";

export const LOOK = [2.1, 2.55];
export const LUNGE = 3.45;
export const CATCH = 3.7;
export const SNOW = 4.05;
// How fast they go: him, and it gaining on him.
const RUN = 5.6;
const CHASE = 12.0;

export function create(ctx) {
	const scene = new THREE.Scene();
	const camera = new THREE.PerspectiveCamera(56, 4 / 3, 0.05, 120);
	let locust;
	let torch;
	const shot = {
		scene, camera, frame: "tape", samples: 32, shutter: 0.5, aperture: 0, focus: 12,
		async setup() {
			const kit = await new Kit(scene).load();
			const doors = [];
			const art = [];
			let num = 311;
			for (let at = 4; at < 34; at += 7.6) {
				doors.push({ side: 1, at, number: num });
				doors.push({ side: -1, at: at + 3.4, number: num + 1, open: at > 18 && at < 24 ? 0.5 : 0, room: at > 18 && at < 24 ? { depth: 6 } : null });
				num += 2;
				art.push({ side: -1, at: at + 0.2, intensity: 1.4 });
				// The painting it stands under, at the far end, is lit a little more.
				art.push({ side: 1, at: at + 3.8, intensity: 1.4 });
			}
			// The lamp it stands under, on the left, just short of it.
			art.push({ side: -1, at: 35.4, intensity: 2.4 });
			const set = await corridor(kit, { length: 41, width: 3.5, doors, art, signs: [{ at: 13 }], sconceShadows: 3 });
			// The end wall lit behind it: a painting and its two lamps, so it stands
			// out black against them.
			await kit.painting(0, -41.0, 0, 1, 7);
			for (const sx of [-0.98, 0.98]) {
				const sc = await kit.sconce(sx, 1.6, -41.0, 0, 1, { intensity: 2.8, shadow: true });
				set.lights.push(sc.light);
			}
			locust = await Locust.create();
			scene.add(locust.root);
			torch = makeTorch(scene, { intensity: 230 });
			shot.volumetrics = new Volumetrics(ctx.renderer, { density: 0.02, noise: 0.7, noiseScale: 0.25, maxDist: 55, steps: 40 });
			for (const l of set.lights) shot.volumetrics.addPoint(l, { radius: 0.9 });
			shot.volumetrics.addSpot(torch, { strength: 0.3 });
		},
		update(t) {
			camera.fov = 56;
			const k = Math.min(t, CATCH);
			const z = -1.5 - k * RUN;
			const st = steps(k, { rate: 2.6, amp: 2.2 });
			const hh = handheld(k, { amp: 3, seed: 5, rate: 2 });
			const pos = V(-0.2 + Math.sin(k * 2.6 * Math.PI * 0.5) * 0.05, 1.6, z).add(st.pos).add(hh.pos);
			// Over his shoulder: the head comes round (by the right) and stays.
			const back = smoothstep(LOOK[0], LOOK[1], k);
			const yaw = back * Math.PI * 0.94;
			const dir = V(Math.sin(yaw) * 0.9, -0.02 - back * 0.03, -Math.cos(yaw));
			aimCamera(camera, pos, pos.clone().add(dir.multiplyScalar(12)), { yaw: hh.yaw * 2 + Math.sin(k * 4.1) * 0.02, pitch: st.pitch + hh.pitch * 2, roll: st.roll + hh.roll * 2 + back * 0.08 });
			torch.visible = true;
			torch.intensity = 150;
			holdTorch(torch, camera, { swayT: k * 3, sway: 2.2 * (1 - back * 0.6), ahead: 9 });
			// It: behind him from the start, seen once he looks.
			const gap = lerp(15.0, 1.2, easeIn(clamp((k - LOOK[0]) / (LUNGE - LOOK[0]))));
			locust.root.visible = k > LOOK[0];
			poseLocust(locust, k, z + gap);
		},
		look(t) {
			const L = tape({ exposure: 1.05 });
			if (t >= LOOK[0] && t < LOOK[0] + 0.1) L.tracking = 0.4;
			if (t >= LUNGE) L.threat_glitch = 0.6;
			// Caught: the picture shuts to black, then the tape shows only snow.
			if (t >= CATCH) L.fadeAll = 1;
			if (t >= SNOW) {
				L.fadeAll = 0;
				L.snow = 1;
				L.signal_loss = 1;
			}
			return L;
		},
		overlay(g, t, size) {
			if (t < CATCH) camcorder(g, t, size, { clock: 2 * 3600 + 14 * 60 + 37, date: "OCT. 27 1993", stamina: clamp(0.93 - t * 0.12) });
			if (t < 1.7) burnIn(g, [typed("TAPE 81 · GUEST 01", t, 0.05, 40)], size, { alpha: 1 - smoothstep(1.4, 1.7, t) });
			if (t >= SNOW + 0.15) {
				const u = size.h / 720;
				burnIn(g, [typed("GUEST 01 — LOST", t, SNOW + 0.15, 30)], size, { x: size.w / 2 - 150 * u, y: size.h / 2 - 22 * u, size: 24 });
			}
		},
	};
	return shot;
}

// Running after him, flat out, arms up; the last strides a leap at the lens.
function poseLocust(L, t, z) {
	L.root.position.set(0.1 + Math.sin(t * 3.1) * 0.12, 0, z);
	// Facing down the corridor after him (the model faces +z).
	L.root.rotation.y = Math.PI;
	L.reset();
	L.poseGait(CHASE, t * 2.4, { aggression: 1 });
	const leap = smoothstep(LUNGE - 0.1, CATCH, t);
	if (leap > 0) L.poseArms({ aggression: 1, attack: leap });
	L.turn("Head1", [1, 0, 0], -0.12 - leap * 0.15);
	L.jaw(0.4 + leap * 0.6);
}
