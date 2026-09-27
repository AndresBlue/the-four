// The blackout. A gloved hand presses the last set's button: click, it comes
// on, and it draws the power: the picture flares, the lamp by it stutters
// with the surge and dies. Cut to the corridor: its lamps shudder in time
// and go out one after the other, away down the hall. Black; what is left:
// the sets, the torches, the green signs.
import * as THREE from "three";
import { Kit } from "../engine/kit.js";
import { corridor, tvSet } from "../engine/sets.js";
import { Survivor } from "../engine/survivor.js";
import { channelWave } from "../engine/screens.js";
import { Volumetrics } from "../engine/volumetric.js";
import { camcorder } from "../engine/osd.js";
import { clamp, smooth, smoothstep } from "../engine/util.js";
import { V, handheld, aimCamera, makeTorch, holdTorch, tape } from "./common.js";

export const CLICK = 0.35;
export const SURGE = 0.55;
export const POP = 1.05;
export const CUT = 1.3;
export const POWER = 1.55;
export const TORCH = 2.35;
// How far apart the corridor's lamps go, one after the next.
const STEP = 0.075;

export function create(ctx) {
	const scene = new THREE.Scene();
	const camera = new THREE.PerspectiveCamera(50, 4 / 3, 0.02, 80);
	let kit;
	let set;
	let tvA;
	let tvB;
	let hand;
	let torch;
	const shot = {
		scene, camera, frame: "tape", samples: 28, shutter: 0.5,
		async setup() {
			kit = await new Kit(scene).load();
			// The corridor, lit until the power goes; a room off it where a set is on.
			const doors = [{ side: 1, at: 6.5, number: 221, open: 1.3, room: { depth: 5 } }, { side: -1, at: 9.0, number: 222 }, { side: 1, at: 14.0, number: 223 }, { side: -1, at: 17.0, number: 224 }];
			const art = [{ side: -1, at: 3.6, intensity: 2.2 }, { side: 1, at: 10.4, intensity: 2.2 }, { side: -1, at: 13.0, intensity: 2.2 }, { side: 1, at: 18.2, intensity: 2.2 }];
			set = await corridor(kit, { length: 24, width: 3.5, doors, art, signs: [{ at: 15 }] });
			for (const z of [-4.5, -12, -19.5]) set.lights.push(kit.dome(0, z, { intensity: 3.5 }));
			// The set in the side room, already on, lighting the doorway blue.
			tvB = await tvSet(scene, 5.6, -6.5, -Math.PI / 2);
			// The last set, somewhere else, and the hand at its button.
			const g = new THREE.Group();
			g.position.set(50, 0, 0);
			scene.add(g);
			const kb = await new Kit(g).load();
			kb.floor(-3, -3, 3, 3);
			kb.wall(-3, -2.0, 3, -2.0, { dress: [1] });
			tvA = await tvSet(scene, 50.3, -1.55, 0);
			// The lamp on the wall by it.
			shot.near = await kb.sconce(-0.45, 1.66, -2.0, 0, 1, { intensity: 2.4 });
			shot.nearMats = [];
			shot.near.lamp.traverse((o) => { if (o.isMesh && o.material.userData.lit !== undefined) shot.nearMats.push(o.material); });
			hand = await Survivor.create();
			scene.add(hand.root);
			torch = makeTorch(scene, { intensity: 70, angle: 26 });
			shot.volumetrics = new Volumetrics(ctx.renderer, { density: 0.02, noise: 0.7, maxDist: 26, steps: 32 });
			for (const l of set.lights) if (l) shot.volumetrics.addPoint(l, { radius: 0.9 });
			shot.volumetrics.addSpot(torch, { strength: 0.45 });
			shot.volumetrics.addSpot(tvB.glow, { strength: 0.08 });
			// Each corridor lamp with its own glass, in the order they go out:
			// nearest the room with the set first.
			scene.updateMatrixWorld(true);
			const glass = [];
			scene.traverse((o) => {
				if (!o.isMesh || !o.material || !kit.emissive.includes(o.material)) return;
				glass.push({ m: o.material, p: o.getWorldPosition(new THREE.Vector3()) });
			});
			shot.lamps = kit.lights.filter(Boolean).map((l) => {
				const p = l.getWorldPosition(new THREE.Vector3());
				return { l, full: l.intensity, mats: glass.filter((g) => g.p.distanceTo(p) < 0.7).map((g) => g.m), d: Math.hypot(p.x - 3, p.z + 6.5) };
			}).sort((x, y) => x.d - y.d);
		},
		update(t) {
			const hh = handheld(t, { amp: 1.0, seed: 51 });
			const wave = channelWave(t);
			tvB.mat.uniforms.power.value = 1;
			tvB.mat.uniforms.time.value = t;
			tvB.glow.intensity = 22 * wave;
			tvB.fill.intensity = 3 * wave;
			if (t < CUT) {
				// The button: the survivor stands out of frame, the gloved hand in it.
				hand.root.visible = true;
				// Standing off to the right, only the arm reaching in.
				hand.root.position.set(51.05, 0, -0.1);
				hand.root.rotation.y = Math.PI + 0.35;
				hand.reset();
				const press = smooth(t / CLICK) - smooth((t - CLICK - 0.08) / 0.2) * 0.4;
				const button = V(50.62, tvA.top + 0.12, -1.28);
				hand.reachWrist("R", button.clone().add(V(0.02, 0.02, 0.2 - press * 0.12)), [0.4, -1, -0.3]);
				hand.fingers("R", 0.95, { point: true, thumb: 0.8 });
				aimCamera(camera, V(50.12, 1.4, 0.4).add(hh.pos), V(50.2, tvA.top + 0.32, -1.5), { yaw: hh.yaw, pitch: hh.pitch, roll: hh.roll });
				camera.fov = 58;
				// On: the tube comes up and flares as it draws the power.
				const on = clamp((t - CLICK) / 0.22);
				const surge = t >= SURGE ? Math.exp(-(t - SURGE) * 3) : 0;
				const u = tvA.mat.uniforms;
				u.power.value = t > CLICK ? on : 0;
				u.time.value = t;
				u.brightness.value = 1 + surge * 1.6;
				u.unstable.value = surge * 0.8;
				tvA.glow.intensity = t > CLICK ? 22 * smooth(on) * wave * (1 + surge * 2) : 0;
				tvA.fill.intensity = t > CLICK ? 3 * smooth(on) * (1 + surge * 2) : 0;
				// The lamp by it stutters with the surge and dies.
				const stutter = t >= SURGE && t < POP ? (Math.sin(t * 90) > 0.2 ? 0.25 : 1.3) : 1;
				const lamp = t >= POP ? 0 : stutter;
				shot.near.light.intensity = 2.4 * lamp;
				for (const m of shot.nearMats) m.emissiveIntensity = m.userData.lit * lamp;
				torch.visible = true;
				torch.intensity = 26;
				holdTorch(torch, camera, { ahead: 1.6, sway: 0.1, swayT: t });
			} else {
				hand.root.visible = false;
				tvA.glow.intensity = 0;
				tvA.fill.intensity = 0;
				shot.near.light.intensity = 0;
				// Down the corridor: the lamps shudder, then go, one after another.
				aimCamera(camera, V(-0.4, 1.6, -0.8).add(hh.pos), V(0.2, 1.45, -20), { yaw: hh.yaw, pitch: hh.pitch, roll: hh.roll });
				for (const [i, L] of shot.lamps.entries()) {
					const off = POWER + i * STEP;
					const shudder = t >= POWER - 0.2 && t < off ? (Math.sin(t * 70 + i) > 0.5 ? 0.45 : 1) : 1;
					const k = t >= off ? 0 : shudder;
					L.l.intensity = L.full * k;
					for (const m of L.mats) m.emissiveIntensity = m.userData.lit * k;
				}
				torch.visible = t >= TORCH;
				torch.intensity = t >= TORCH ? 70 * clamp((t - TORCH) / 0.05) * (t < TORCH + 0.12 ? 0.6 + 0.4 * Math.abs(Math.sin(t * 90)) : 1) : 0;
				holdTorch(torch, camera, { ahead: 8, swayT: t, sway: 0.7, aimOffset: V(0, -0.6, 0) });
			}
		},
		look(t) {
			const L = tape({ exposure: t < CUT ? 1.7 : t < POWER ? 1.3 : 2.2 });
			if (t >= CUT && t < CUT + 0.07) L.tracking = 0.6;
			if (t >= SURGE && t < SURGE + 0.12) L.tracking = 0.7;
			const last = POWER + (shot.lamps?.length ?? 0) * STEP;
			if (t >= last && t < last + 0.1) L.threat_glitch = 0.6;
			return L;
		},
		overlay(g, t, size) {
			camcorder(g, t, size, { clock: 3 * 3600 + 41 * 60 + 12, date: "OCT. 27 1993", focus: t < CLICK ? 1 : 0, word: "TURN ON" });
		},
	};
	return shot;
}
