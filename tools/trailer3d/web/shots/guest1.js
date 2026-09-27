// GUEST 01 — he ran. The run, first person, the torch swinging with each
// step; then a long, perfectly still shot down a huge corridor: The Locust
// with its back turned under a lamp, the steps still coming, it stops, the
// head turns alone, it screams and comes. Snow.
import * as THREE from "three";
import { Kit } from "../engine/kit.js";
import { corridor } from "../engine/sets.js";
import { Locust } from "../engine/locust.js";
import { Volumetrics } from "../engine/volumetric.js";
import { camcorder, burnIn, typed } from "../engine/osd.js";
import { clamp, smooth, smoothstep, easeIn, easeOut, keys, lerp, fbm1 } from "../engine/util.js";
import { V, handheld, steps, aimCamera, makeTorch, holdTorch, tape } from "./common.js";

export const CUT = 1.9;
export const STOP = 2.35;
export const TURN = [2.6, 3.45];
export const SCREAM = 3.55;
export const LAUNCH = 3.8;
export const SNOW = 4.32;

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
			if (t < CUT) {
				camera.fov = 56;
				// The run: about 5.5 m/s down the corridor, the lens thrown about.
				const z = -1.5 - t * 5.6;
				const st = steps(t, { rate: 2.6, amp: 2.2 });
				const hh = handheld(t, { amp: 3, seed: 5, rate: 2 });
				const pos = V(-0.2 + Math.sin(t * 2.6 * Math.PI * 0.5) * 0.05, 1.6, z).add(st.pos).add(hh.pos);
				aimCamera(camera, pos, V(0.1, 1.45, z - 12), { yaw: hh.yaw * 2 + Math.sin(t * 4.1) * 0.02, pitch: st.pitch + hh.pitch * 2, roll: st.roll + hh.roll * 2 });
				torch.visible = true;
				torch.intensity = 150;
				holdTorch(torch, camera, { swayT: t * 3, sway: 2.2, ahead: 11 });
				locust.root.visible = false;
			} else {
				// Still, zoomed in: the whole length of the corridor stacked up.
				camera.fov = 24;
				aimCamera(camera, V(-0.55, 1.45, -2.0), V(0.35, 1.55, -36.0));
				torch.visible = false;
				torch.intensity = 0;
				locust.root.visible = true;
				poseLocust(locust, t);
			}
		},
		look(t) {
			const L = tape({ exposure: t < CUT ? 1.05 : 1.15 });
			if (t >= CUT && t < CUT + 0.1) L.tracking = 0.6;
			if (t >= SCREAM && t < SCREAM + 0.3) L.threat_glitch = 0.5 * (1 - (t - SCREAM) / 0.3);
			if (t >= LAUNCH) L.tracking = smoothstep(LAUNCH, SNOW, t) * 0.5;
			if (t >= SNOW) {
				L.snow = 1;
				L.signal_loss = 1;
			}
			return L;
		},
		overlay(g, t, size) {
			if (t < SNOW) {
				const running = t < CUT;
				camcorder(g, t, size, { clock: 2 * 3600 + 14 * 60 + 37 + (running ? 0 : 3), date: "OCT. 27 1993", stamina: running ? clamp(0.93 - t * 0.08) : null });
			}
			if (t < 1.7) burnIn(g, [typed("TAPE 81 · GUEST 01", t, 0.05, 40)], size, { alpha: 1 - smoothstep(1.4, 1.7, t) });
			if (t >= SNOW + 0.08) {
				const u = size.h / 720;
				burnIn(g, [typed("GUEST 01 — LOST", t, SNOW + 0.08, 45)], size, { x: size.w / 2 - 150 * u, y: size.h / 2 - 22 * u, size: 24 });
			}
		},
	};
	return shot;
}

// Back turned under the far lamp; drifts a step, stops; the head alone turns
// round to the lens; the scream; it wheels and runs at the camera.
function poseLocust(L, t) {
	const base = V(0.45, 0, -36.2);
	let yaw = Math.PI; // back to the camera (the model faces +z)
	let speed = 0;
	let z = base.z;
	if (t < STOP) {
		// A slow step away, as it was going.
		speed = 0.9 * (1 - smooth((t - CUT) / (STOP - CUT)));
		z = base.z - (t - CUT) * 0.45;
	} else z = base.z - (STOP - CUT) * 0.45;
	let runPhase = 0;
	if (t >= LAUNCH) {
		const k = t - LAUNCH;
		// It wheels round and comes, 2.5 m/s building at 3.2 m/s^2... faster, for the cut.
		yaw = Math.PI - Math.PI * smooth(k / 0.16);
		const v = Math.min(6.4, 3.0 + k * 9);
		z += (3.0 * k + 4.5 * k * k);
		speed = v;
		runPhase = k * 2.3 + 0.2;
	}
	L.root.position.set(base.x, 0, z);
	L.root.rotation.y = yaw;
	if (t < LAUNCH) {
		L.reset();
		if (speed > 0.05) L.poseGait(speed, (t - CUT) * 1.1);
		else L.stand({ hunch: 0.12 });
		L.hangArms();
		// The head alone: round toward the lens while the body keeps its way.
		const turn = smoothstep(TURN[0], TURN[1], t);
		const k = turn * turn * (3 - 2 * turn);
		const twist = k * 2.55;
		L.turn("Neck1", [0, 1, 0], twist * 0.45);
		L.turn("Head1", [0, 1, 0], twist * 0.55);
		L.turn("Head1", [0, 0, 1], k * 0.28 + Math.sin(t * 23) * 0.015 * k);
		// The scream: the jaw drops, the head juts.
		const s = smoothstep(SCREAM - 0.05, SCREAM + 0.12, t);
		L.turn("Head1", [1, 0, 0], -s * 0.25);
		L.jaw(s);
		if (s > 0) L.poseArms({ aggression: s });
	} else {
		L.poseGait(speed, runPhase, { aggression: 1 });
		L.turn("Head1", [1, 0, 0], -0.15);
		L.jaw(1);
	}
}
