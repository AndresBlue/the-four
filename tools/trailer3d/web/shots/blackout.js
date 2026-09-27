// The blackout. A gloved hand presses the set's button: click, the last set
// comes on. The motif hits and all the power in the hotel goes at once — the
// lamps, the sconces, the beacon, everything. Black; a moment without music.
// What is left: the sets, the torches, the green signs.
import * as THREE from "three";
import { Kit } from "../engine/kit.js";
import { corridor, tvSet } from "../engine/sets.js";
import { Survivor } from "../engine/survivor.js";
import { channelWave } from "../engine/screens.js";
import { Volumetrics } from "../engine/volumetric.js";
import { camcorder } from "../engine/osd.js";
import { clamp, smooth, smoothstep } from "../engine/util.js";
import { V, handheld, aimCamera, makeTorch, holdTorch, tape } from "./common.js";

export const CLICK = 0.3;
export const CUT = 0.6;
export const POWER = 0.74;
export const TORCH = 1.12;

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
			hand = await Survivor.create();
			scene.add(hand.root);
			torch = makeTorch(scene, { intensity: 70, angle: 26 });
			shot.volumetrics = new Volumetrics(ctx.renderer, { density: 0.02, noise: 0.7, maxDist: 26, steps: 32 });
			for (const l of set.lights) if (l) shot.volumetrics.addPoint(l, { radius: 0.9 });
			shot.volumetrics.addSpot(torch, { strength: 0.45 });
			shot.volumetrics.addSpot(tvB.glow, { strength: 0.08 });
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
				hand.root.position.set(50.72, 0, 0.12);
				hand.root.rotation.y = Math.PI + 0.35;
				hand.reset();
				const press = smooth(t / CLICK) - smooth((t - CLICK - 0.08) / 0.2) * 0.4;
				// The set's own panel, right of the tube.
				const button = V(50.62, tvA.top + 0.12, -1.28);
				hand.reachWrist("R", button.clone().add(V(0.02, 0.02, 0.2 - press * 0.12)), [0.4, -1, -0.3]);
				hand.fingers("R", 0.95, { point: true, thumb: 0.8 });
				aimCamera(camera, V(50.12, 1.4, 0.4).add(hh.pos), V(50.34, tvA.top + 0.28, -1.5), { yaw: hh.yaw, pitch: hh.pitch, roll: hh.roll });
				const on = clamp((t - CLICK) / 0.22);
				tvA.mat.uniforms.power.value = t > CLICK ? on : 0;
				tvA.mat.uniforms.time.value = t;
				tvA.glow.intensity = t > CLICK ? 22 * smooth(on) * wave : 0;
				tvA.fill.intensity = t > CLICK ? 3 * smooth(on) : 0;
				// The torch on the set, so the hand shows.
				torch.visible = true;
				torch.intensity = 26;
				holdTorch(torch, camera, { ahead: 1.6, sway: 0.1, swayT: t });
			} else {
				hand.root.visible = false;
				tvA.glow.intensity = 0;
				tvA.fill.intensity = 0;
				// Down the corridor; the power goes; the torch comes on.
				aimCamera(camera, V(-0.4, 1.6, -0.8).add(hh.pos), V(0.2, 1.45, -20), { yaw: hh.yaw, pitch: hh.pitch, roll: hh.roll });
				const lit = t < POWER;
				for (const l of kit.lights) if (l) l.intensity = lit ? l.userData.full ?? (l.userData.full = l.intensity) : 0;
				for (const m of kit.emissive) m.emissiveIntensity = lit ? m.userData.lit : 0;
				torch.visible = t >= TORCH;
				torch.intensity = t >= TORCH ? 70 * clamp((t - TORCH) / 0.05) * (t < TORCH + 0.12 ? 0.6 + 0.4 * Math.abs(Math.sin(t * 90)) : 1) : 0;
				holdTorch(torch, camera, { ahead: 8, swayT: t, sway: 0.7, aimOffset: V(0, -0.6, 0) });
			}
		},
		look(t) {
			const L = tape({ exposure: t < CUT ? 2.0 : t < POWER ? 1.3 : 2.4 });
			if (t >= CUT && t < CUT + 0.07) L.tracking = 0.6;
			if (t >= POWER && t < POWER + 0.1) L.threat_glitch = 0.6;
			return L;
		},
		overlay(g, t, size) {
			camcorder(g, t, size, { clock: 3 * 3600 + 41 * 60 + 12, date: "OCT. 27 1993", focus: t < CLICK ? 1 : 0, word: "TURN ON" });
		},
	};
	return shot;
}
