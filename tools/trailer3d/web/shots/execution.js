// The execution, first person, as the game plays it (hotel_main.gd,
// locust_visual.pose_arms): lifted on one arm and brought slowly to its mask;
// the music gone, only breath and the creature; the other arm drawn back and
// still, a fraction of a second too long; then it comes for the lens. Black.
// A dead channel: SIGNAL LOST.
import * as THREE from "three";
import { Kit } from "../engine/kit.js";
import { corridor } from "../engine/sets.js";
import { Locust } from "../engine/locust.js";
import { Volumetrics } from "../engine/volumetric.js";
import { camcorder, signalLost } from "../engine/osd.js";
import { clamp, smooth, smoothstep, lerp, easeOut, fbm1 } from "../engine/util.js";
import { V, aimCamera, makeTorch, tape } from "./common.js";

export const LIFT = 0.35;
export const ARM = 2.2;
export const HIT = 2.43;
export const STATIC = 2.47;

// This shot's time onto the game's execution clock (grab 0, arm 2.58, kill 2.8).
const gameTime = (t) => (t < ARM ? (t * 2.58) / ARM : 2.58 + ((t - ARM) * 0.22) / (HIT - ARM));

export function create(ctx) {
	const scene = new THREE.Scene();
	const camera = new THREE.PerspectiveCamera(62, 4 / 3, 0.02, 60);
	let locust;
	let torch;
	const L0 = V(0.2, 0, -8.0);
	const shot = {
		scene, camera, frame: "tape", samples: 32, shutter: 0.5,
		async setup() {
			const kit = await new Kit(scene).load();
			const set = await corridor(kit, { length: 20, width: 3.5, doors: [{ side: 1, at: 6.0, number: 241 }, { side: -1, at: 10.0, number: 242 }], art: [{ side: -1, at: 7.4 }, { side: 1, at: 12.0 }], lit: false, signs: [{ at: 14 }] });
			for (const s of set.signs) s.userData.spill.intensity = 0.3;
			locust = await Locust.create();
			locust.root.position.copy(L0);
			locust.root.rotation.y = 0;
			scene.add(locust.root);
			torch = makeTorch(scene, { intensity: 16, angle: 34 });
			shot.volumetrics = new Volumetrics(ctx.renderer, { density: 0.02, noise: 0.8, maxDist: 12, steps: 28 });
			shot.volumetrics.addSpot(torch, { strength: 0.3 });
		},
		update(t) {
			const g = gameTime(Math.min(t, HIT + 0.2));
			const lift = clamp(g / 0.5);
			const closing = 1 - Math.pow(1 - clamp((g - 0.5) / (2.8 - 0.5)), 1 / 0.45);
			// Where it holds the body: in front of it, lifted a metre, drawn in.
			const fwd = V(0, 0, 1);
			const hold = L0.clone().add(fwd.clone().multiplyScalar(lerp(1.15, 0.6, closing))).add(V(0, 0.1 + lift * 1.0, 0));
			const shake = V(fbm1(t * 9, 3) * 0.02, fbm1(t * 8, 5) * 0.015, 0).multiplyScalar(1 + lift);
			const eye = hold.clone().add(V(0, 1.58, 0)).add(shake);
			const head = L0.clone().add(V(0, 2.3, 0));
			aimCamera(camera, eye, head.clone().add(V(-0.05, 0.05 - (1 - lift) * 0.4, 0)), { roll: (1 - lift) * 0.2 + fbm1(t * 5, 9) * 0.04 * lift });
			// The victim's torch, still in its hand, shaking up at the mask.
			torch.position.copy(eye).add(V(0.22, -0.55, 0.05));
			torch.target.position.copy(head).add(V(fbm1(t * 7, 11) * 0.3, fbm1(t * 6, 13) * 0.25 - 0.2, 0));
			// It: holding with its left, the right drawn back, then through the lens.
			locust.reset();
			const e = g / 4.2;
			locust.stand({ execute: e, aggression: 1, hunch: 0.05 });
			locust.poseArms({ execute: e, aggression: 1 });
			const look = eye.clone().sub(locust.point("Head1"));
			locust.lookToward([look.x, look.y, look.z], { limit: 1.2 });
			locust.turn("Head1", [0, 0, 1], 0.12 + Math.sin(t * 13) * 0.015);
			locust.jaw(0.25 + closing * 0.2);
		},
		look(t) {
			// Held up to it, the camcorder's gain comes right down.
			const L = tape({ exposure: 1.05, grain: 0.3 });
			if (t >= ARM) {
				L.strike_fill = clamp((t - ARM) / (HIT - ARM));
				L.strike_point = [0.3, 0.52];
			}
			if (t >= HIT) L.fade = 1;
			if (t >= STATIC) {
				L.fade = 0;
				L.strike_fill = 0;
				L.signal_loss = 1;
				L.snow = 1;
			}
			return L;
		},
		overlay(g, t, size) {
			if (t < ARM) camcorder(g, t, size, { clock: 3 * 3600 + 44 * 60 + 9, date: "OCT. 27 1993" });
		},
		// Written over the snow, legible, as the failure title is.
		overlayClean(g, t, size) {
			if (t >= STATIC + 0.05) {
				const blink = t > STATIC + 0.2 && (t * 2.5) % 1 > 0.62 ? 0.25 : 1;
				signalLost(g, { w: size.w, h: size.h }, { alpha: blink });
			}
		},
	};
	return shot;
}
