// GUEST 04 — not every sighting was real. A warm corridor, a very slow walk,
// the tape starting to drag its colours. A turn: far off, in an open door,
// head and neck of The Locust out from behind the frame, cocked, looking
// straight here — the title screen's pose (the game's phantom_sight). The
// torch goes to it and the door slams shut. Back round: at the end of the
// straight corridor it stands, looking — and at once it is not there.
import * as THREE from "three";
import { Kit } from "../engine/kit.js";
import { corridor } from "../engine/sets.js";
import { Locust } from "../engine/locust.js";
import { Volumetrics } from "../engine/volumetric.js";
import { camcorder, burnIn, typed, zoomBar } from "../engine/osd.js";
import { clamp, smooth, smoothstep, lerp, keys } from "../engine/util.js";
import { V, handheld, steps, aimCamera, makeTorch, holdTorch, tape } from "./common.js";

export const TURN = [0.55, 1.15];
export const TORCH = 1.55;
export const SLAM = 1.92;
export const LOOK_END = [2.35, 2.95];
export const BLINK = 3.12;
export const ZOOM_IN = [0.95, 1.45];
export const ZOOM_OUT = [2.2, 2.75];
const zoomAt = (t) => smooth((t - ZOOM_IN[0]) / (ZOOM_IN[1] - ZOOM_IN[0])) * (1 - smooth((t - ZOOM_OUT[0]) / (ZOOM_OUT[1] - ZOOM_OUT[0])));

export function create(ctx) {
	const scene = new THREE.Scene();
	const camera = new THREE.PerspectiveCamera(50, 4 / 3, 0.05, 90);
	let peek;
	let stand;
	let torch;
	const shot = {
		scene, camera, frame: "tape", samples: 32, shutter: 0.5,
		async setup() {
			const kit = await new Kit(scene).load();
			const doors = [
				{ side: -1, at: 3.0, number: 402 }, { side: 1, at: 3.2, number: 405 },
				{ side: -1, at: 12.5, number: 404 }, { side: 1, at: 13.0, number: 407 },
				{ side: -1, at: 19.5, number: 406 }, { side: 1, at: 21.5, number: 409 },
			];
			const art = [
				{ side: -1, at: 7.0, intensity: 2.2 }, { side: 1, at: 16.4, intensity: 2.2 },
				{ side: -1, at: 16.0, intensity: 2.2 }, { side: 1, at: 24.2, intensity: 2.2 }, { side: -1, at: 23.2, intensity: 2.2 },
			];
			// A side corridor joins on the right, running off to +x.
			const set = await corridor(kit, { length: 30, width: 3.5, doors, art, gaps: [{ side: 1, from: 6.2, to: 9.0 }], sconceShadows: 3 });
			const T = 0.18;
			kit.floor(1.7, -9.2, 14.2, -6.0);
			kit.ceilingSlab(1.7, -9.2, 14.2, -6.0);
			kit.wall(1.84, -9.0 - T / 2, 14.18, -9.0 - T / 2, { dress: [1] });
			kit.wall(1.84, -6.2 + T / 2, 14.18, -6.2 + T / 2, { dress: [-1] });
			// Its end: a wall facing us with a door stood ajar, hinged on the right.
			kit.wall(14.0 + T / 2, -9.2, 14.0 + T / 2, -6.0, { openings: [[1.6 - 0.65 + 0.2, 1.6 + 0.65 + 0.2]], dress: [-1] });
			shot.endDoor = await kit.door(14.0 + T / 2, -7.6, -Math.PI / 2, { open: 1.25, flip: true });
			// The dark room behind it.
			kit.floor(14.18, -12, 20, -3);
			kit.ceilingSlab(14.18, -12, 20, -3);
			kit.wall(20.09, -12, 20.09, -3, { dress: [-1] });
			kit.wall(14.18, -12.09, 20, -12.09, { dress: [1] });
			kit.wall(14.18, -2.91, 20, -2.91, { dress: [-1] });
			for (const [x, z, nz] of [[10.5, -9.0, 1], [7.0, -6.2, -1], [12.9, -6.2, -1]]) {
				const sc = await kit.sconce(x, 1.6, z, 0, nz, { intensity: 2.4, shadow: x > 12 });
				set.lights.push(sc.light);
			}
			await kit.painting(8.8, -9.0, 0, 1, 2);
			// The sconce light reaching the gap by the door, where the face comes.
			const onGap = new THREE.SpotLight(new THREE.Color().setRGB(1, 0.89, 0.66, THREE.SRGBColorSpace), 9, 6, 0.35, 0.8, 2);
			onGap.position.set(12.6, 2.2, -6.5);
			onGap.target.position.set(14.1, 2.35, -7.05);
			scene.add(onGap, onGap.target);
			// The end of the main corridor, lit: where it stands.
			await kit.painting(0, -30.0, 0, 1, 11);
			for (const sx of [-0.98, 0.98]) {
				const sc = await kit.sconce(sx, 1.6, -30.0, 0, 1, { intensity: 3.0, shadow: true });
				set.lights.push(sc.light);
			}
			peek = await Locust.create();
			scene.add(peek.root);
			stand = await Locust.create();
			scene.add(stand.root);
			torch = makeTorch(scene, { intensity: 32, angle: 24 });
			shot.volumetrics = new Volumetrics(ctx.renderer, { density: 0.014, noise: 0.6, maxDist: 36, steps: 36 });
			for (const l of set.lights) shot.volumetrics.addPoint(l, { radius: 0.9 });
			shot.volumetrics.addSpot(torch, { strength: 0.5 });
		},
		update(t) {
			// The slow walk: 0.8 m/s, toward the junction.
			const z = -6.75 - t * 0.5;
			const st = steps(t, { rate: 1.5, amp: 0.6 });
			const hh = handheld(t, { amp: 1.4, seed: 41 });
			const pos = V(-0.45, 1.6, z).add(st.pos).add(hh.pos);
			// Along the corridor; round to the right, down the side corridor to
			// the door at its end; back down the main corridor to its end.
			const door = V(14.0, 1.75, -7.9);
			const ahead = V(0.1, 1.5, z - 12);
			const end = V(0.2, 1.6, -30);
			let target = ahead.clone().lerp(door, smooth((t - TURN[0]) / (TURN[1] - TURN[0])));
			if (t > LOOK_END[0]) target = door.clone().lerp(end, smooth((t - LOOK_END[0]) / (LOOK_END[1] - LOOK_END[0])));
			// The camcorder zooms in on the door, and back out after the jerk.
			camera.fov = 50 - 36 * zoomAt(t);
			aimCamera(camera, pos, target, { yaw: hh.yaw * (1 + zoomAt(t)), pitch: hh.pitch + st.pitch, roll: hh.roll + st.roll });
			// The torch goes to the doorway, then follows the lens.
			const onDoor = smoothstep(TORCH - 0.2, TORCH + 0.15, t) * (1 - smoothstep(LOOK_END[0], LOOK_END[1], t));
			holdTorch(torch, camera, { ahead: 12, swayT: t, sway: 0.6, aimOffset: V(0, -0.4, 0) });
			if (onDoor > 0) torch.target.position.lerp(V(14.0, 1.9, -7.1), onDoor);
			// The head in the door, out from behind the left jamb in 0.4 s once
			// the lens has come round to it, twitching; gone at the jerk.
			// Slammed: the leaf flung shut, the head behind it.
			shot.endDoor.leaf.rotation.y = 1.25 * (1 - smoothstep(SLAM - 0.1, SLAM, t));
			const shownPeek = t >= TURN[0] + 0.25 && t < SLAM - 0.05;
			peek.root.visible = shownPeek;
			if (shownPeek) {
				// Behind the wall left of the doorway (seen head on, the wall hides the
				// body only if it stands well clear of the jamb).
				peek.root.position.set(14.46, 0, -6.42);
				peek.root.rotation.y = -Math.PI / 2;
				const out = smooth((t - TURN[0] - 0.25) / 0.4);
				const seen = t - TURN[0] - 0.25;
				const twitch = seen > 0.3 && seen % 0.9 < 0.12 ? 1 : 0;
				peek.posePeek(lerp(0.03, 0.44, out), twitch, -1);
				// Whatever the lean, the head ends clear of the jamb, inside the
				// opening, the body behind the wall beside it.
				peek.root.updateMatrixWorld(true);
				const head = peek.point("Head1");
				const want = lerp(-6.75, -7.28, out);
				peek.root.position.z += want - head.z;
				peek.root.position.x += 14.42 - head.x;
			}
			// At the end, standing, looking; gone at the blink.
			const shownStand = t >= LOOK_END[0] && t < BLINK;
			stand.root.visible = shownStand;
			if (shownStand) {
				stand.root.position.set(0.25, 0, -28.9);
				stand.root.rotation.y = Math.atan2(camera.position.x - 0.25, camera.position.z + 28.9);
				const seen = t - LOOK_END[0];
				stand.poseStare(seen > 0.3 && seen % 0.9 < 0.12 ? 1 : 0);
			}
		},
		look(t) {
			// The mind going: the picture drags and its colour runs, more and more.
			const L = tape({ exposure: 1.25, drag: 0.25 + smoothstep(0, 4.5, t) * 0.55 });
			if (t >= SLAM && t < SLAM + 0.08) { L.jerk = 0.6; L.tracking = 0.5; }
			// Gone between one frame and the next, as if never there.
			if (t >= BLINK && t < BLINK + 0.05) { L.tracking = 0.7; L.snow = 0.2; }
			return L;
		},
		overlay(g, t, size) {
			camcorder(g, t, size, { clock: 3 * 3600 + 5 * 60 + 16, date: "OCT. 27 1993" });
			// The rocker shows while the zoom moves and 1.6 s after (ZOOM_HOLD).
			const moving = (t > ZOOM_IN[0] - 0.1 && t < ZOOM_IN[1] + 1.0) || (t > ZOOM_OUT[0] - 0.1 && t < ZOOM_OUT[1] + 0.8);
			zoomBar(g, size, zoomAt(t), moving ? 1 : 0);
			if (t < 1.3) burnIn(g, [typed("TAPE 81 · GUEST 04", t, 0.05, 40)], size, { alpha: 1 - smoothstep(1.0, 1.3, t) });
		},
	};
	return shot;
}
