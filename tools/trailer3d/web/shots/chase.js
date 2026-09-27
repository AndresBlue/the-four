// The chase, in the dark: the torch sweeps and catches The Locust running at
// the lens, stooping under a fire door; cut: a door slammed; cut: a guest
// turns and it is already on top of them — the thrust.
import * as THREE from "three";
import { Kit } from "../engine/kit.js";
import { corridor } from "../engine/sets.js";
import { Locust } from "../engine/locust.js";
import { Volumetrics } from "../engine/volumetric.js";
import { camcorder } from "../engine/osd.js";
import { clamp, smooth, smoothstep, lerp } from "../engine/util.js";
import { V, handheld, steps, aimCamera, makeTorch, holdTorch, tape } from "./common.js";

export const SLAM = 0.8;
export const TURN = 1.1;
export const THRUST = 1.42;

export function create(ctx) {
	const scene = new THREE.Scene();
	const camera = new THREE.PerspectiveCamera(56, 4 / 3, 0.03, 80);
	let locust;
	let torch;
	let slamDoor;
	const shot = {
		scene, camera, frame: "tape", samples: 32, shutter: 0.6,
		async setup() {
			const kit = await new Kit(scene).load();
			// A corridor in the blackout: lamps dead, a fire door stood open.
			const doors = [{ side: 1, at: 3.0, number: 231 }, { side: -1, at: 6.0, number: 232 }, { side: 1, at: 16.0, number: 233 }];
			const art = [{ side: -1, at: 9.8 }, { side: 1, at: 12.6 }];
			const set = await corridor(kit, { length: 24, width: 3.5, doors, art, lit: false, fireDoors: [{ at: 11.0, open: 1 }], signs: [{ at: 5.5 }] });
			for (const s of set.signs) s.userData.spill.intensity = 0.3;
			// The door to be slammed, somewhere else.
			const g = new THREE.Group();
			g.position.set(40, 0, 0);
			scene.add(g);
			const kb = await new Kit(g).load();
			kb.floor(-3, -4, 3, 3);
			kb.ceilingSlab(-3, -4, 3, 3);
			kb.wall(-3, -1.0, 3, -1.0, { openings: [[3 - 0.65, 3 + 0.65]], dress: [1] });
			slamDoor = await kb.door(0, -1.0, 0, { open: 1.2, number: 238 });
			locust = await Locust.create();
			scene.add(locust.root);
			torch = makeTorch(scene, { intensity: 120 });
			// Thin haze: a thick one veils what the beam finds.
			shot.volumetrics = new Volumetrics(ctx.renderer, { density: 0.012, noise: 0.8, maxDist: 24, steps: 36 });
			shot.volumetrics.addSpot(torch, { strength: 0.22 });
		},
		update(t) {
			if (t < SLAM) {
				// Backing off down the corridor, the torch sweeping, finding it.
				const hh = handheld(t, { amp: 2.4, seed: 61, rate: 1.6 });
				const st = steps(t, { rate: 2.4, amp: 1.2 });
				aimCamera(camera, V(0.1, 1.55, -1.0 + t * 1.2).add(st.pos).add(hh.pos), V(0.3, 1.5, -16), { yaw: hh.yaw * 2, pitch: hh.pitch + st.pitch, roll: hh.roll + st.roll });
				holdTorch(torch, camera, { ahead: 12, swayT: t, sway: 0.2 });
				// The sweep: from the right wall across to it.
				const sweep = smooth(t / 0.35);
				torch.target.position.add(V((1 - sweep) * 5.5, (1 - sweep) * -0.5, 0));
				torch.visible = true;
				torch.intensity = 120;
				// It comes at 6.4 m/s, stooping under the fire door's head.
				const z = -15.5 + t * 6.4;
				locust.root.visible = true;
				locust.root.position.set(-0.2, 0, z);
				locust.root.rotation.y = 0;
				const duck = 1 - smoothstep(0.6, 2.4, Math.abs(z + 11.0));
				locust.poseGait(6.4, t * 2.3, { aggression: 1, duck });
				locust.turn("Head1", [1, 0, 0], -0.1);
			} else if (t < TURN) {
				// Slammed: the leaf flung shut, the frame jumping.
				locust.root.visible = false;
				const k = smoothstep(SLAM, SLAM + 0.13, t);
				slamDoor.leaf.rotation.y = 1.2 * (1 - k * k);
				const jolt = t > SLAM + 0.13 ? Math.exp(-(t - SLAM - 0.13) * 30) * 0.03 : 0;
				aimCamera(camera, V(40.9, 1.5, 1.6).add(V(0, jolt, 0)), V(40.1, 1.3, -1.0), { roll: jolt * 2 });
				holdTorch(torch, camera, { ahead: 3, sway: 0.1 });
				torch.intensity = 120;
			} else {
				// Turning round: it is right there.
				const k = smooth((t - TURN) / 0.2);
				const yaw = Math.PI * 0.85 * k;
				const eye = V(0.1, 1.55, -6.0);
				const dir = V(Math.sin(yaw), -0.05 + k * 0.15, -Math.cos(yaw));
				aimCamera(camera, eye, eye.clone().add(dir), { roll: (1 - k) * 0.12 });
				holdTorch(torch, camera, { ahead: 2, sway: 0.4, swayT: t * 3 });
				torch.intensity = 26;
				locust.root.visible = true;
				locust.root.position.set(0.35, 0, -4.65);
				locust.root.rotation.y = Math.PI + 0.1;
				locust.reset();
				const a = smoothstep(TURN + 0.05, THRUST, t);
				const rec = smoothstep(THRUST, THRUST + 0.08, t);
				locust.stand({ attack: a * (1 - rec), recovering: rec, aggression: 1 });
				locust.poseArms({ attack: a * (1 - rec), recovering: rec, aggression: 1 });
				locust.turn("Head1", [1, 0, 0], 0.2);
				locust.jaw(0.4);
			}
		},
		look(t) {
			const L = tape({ exposure: t >= TURN ? 1.25 : 2.3, grain: 0.32 });
			if (t < 0.05 || (t >= SLAM && t < SLAM + 0.06) || (t >= TURN && t < TURN + 0.05)) L.tracking = 0.8;
			if (t >= THRUST - 0.1) L.threat_glitch = smoothstep(THRUST - 0.1, THRUST + 0.1, t);
			return L;
		},
		overlay(g, t, size) {
			camcorder(g, t, size, { clock: 3 * 3600 + 44 * 60 + 2, date: "OCT. 27 1993", stamina: t < SLAM ? 0.35 - t * 0.2 : null, exhausted: false });
		},
	};
	return shot;
}
