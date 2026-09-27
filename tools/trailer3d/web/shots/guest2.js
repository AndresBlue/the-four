// GUEST 02 — every live screen is a door. A pitch-dark room; click, the set
// comes on and its snow lights the room blue; a moment in front of it. Cut:
// another room, another set already on, a still shot. The static swells, the
// tape's tracking breaks for half a second, and when it comes back The Locust
// is standing next to the set. It did not come through the glass: it simply
// was not there before. It turns to the lens.
import * as THREE from "three";
import { Kit } from "../engine/kit.js";
import { hotelRoom, tvSet } from "../engine/sets.js";
import { Locust } from "../engine/locust.js";
import * as P from "../engine/props.js";
import { polyhaven, shadows } from "../engine/assets.js";
import { channelWave } from "../engine/screens.js";
import { Volumetrics } from "../engine/volumetric.js";
import { camcorder, burnIn, typed } from "../engine/osd.js";
import { clamp, smooth, smoothstep } from "../engine/util.js";
import { V, handheld, aimCamera, tape } from "./common.js";

export const CLICK = 0.4;
export const CUT = 1.85;
export const BREAK = [2.55, 3.05];
export const TURN = [3.95, 4.55];

export function create(ctx) {
	const scene = new THREE.Scene();
	const camera = new THREE.PerspectiveCamera(52, 4 / 3, 0.05, 80);
	let locust;
	let a;
	let b;
	const shot = {
		scene, camera, frame: "tape", samples: 32, shutter: 0.5,
		async setup() {
			const kit = await new Kit(scene).load();
			// Room A: a bedroom with the lights off.
			await hotelRoom(kit, { x0: -3, x1: 3, z0: -4, z1: 3, doors: [{ wall: "s", at: 4.6, open: 0 }] });
			a = await tvSet(scene, 0.35, -3.55, 0);
			const bed = await P.bed();
			bed.position.set(2.0, 0, 0.4);
			bed.rotation.y = -Math.PI / 2;
			scene.add(bed);
			const w = await P.wardrobe();
			w.group.position.set(-2.55, 0, -1.2);
			w.group.rotation.y = Math.PI / 2;
			scene.add(w.group);
			// Room B, somewhere else in the hotel: a set already on.
			await hotelRoom(kit, { x0: 20, x1: 26, z0: -4, z1: 3, doors: [{ wall: "w", at: 5.4, open: 0.9 }] });
			b = await tvSet(scene, 25.55, -1.4, -Math.PI / 2);
			const chair = await polyhaven("ArmChair_01");
			shadows(chair);
			chair.position.set(23.4, 0, 1.9);
			chair.rotation.y = Math.PI * 0.85;
			scene.add(chair);
			const lamp = await polyhaven("ClassicNightstand_01");
			shadows(lamp);
			lamp.position.set(25.6, 0, 1.4);
			lamp.rotation.y = -Math.PI / 2;
			scene.add(lamp);
			locust = await Locust.create();
			scene.add(locust.root);
			shot.volumetrics = new Volumetrics(ctx.renderer, { density: 0.012, noise: 0.5, maxDist: 12, steps: 24 });
			shot.volumetrics.addSpot(a.glow, { strength: 0.08 });
			shot.volumetrics.addSpot(b.glow, { strength: 0.08 });
		},
		update(t) {
			const wave = channelWave(t * 1.0);
			if (t < CUT) {
				// In front of the set, close; it comes on.
				const hh = handheld(t, { amp: 1.2, seed: 21 });
				aimCamera(camera, V(0.15, 1.52, -1.2).add(hh.pos), V(0.35, 1.05, -3.6), { yaw: hh.yaw, pitch: hh.pitch, roll: hh.roll });
				const on = t >= CLICK;
				const k = clamp((t - CLICK) / 0.35);
				a.mat.uniforms.power.value = on ? k : 0;
				a.mat.uniforms.time.value = t;
				a.mat.uniforms.static_amount.value = 1;
				a.glow.intensity = on ? 22 * smooth(k) * wave : 0;
				a.fill.intensity = on ? 3.5 * smooth(k) * wave : 0;
				b.fill.intensity = 0;
				b.glow.intensity = 0;
				locust.root.visible = false;
			} else {
				// Still, from by the door of room B.
				camera.fov = 50;
				aimCamera(camera, V(21.6, 1.45, 1.6), V(25.0, 1.72, -1.9));
				const swell = smoothstep(CUT, BREAK[0], t);
				b.mat.uniforms.power.value = 1;
				b.mat.uniforms.time.value = t;
				b.mat.uniforms.static_amount.value = 1;
				b.mat.uniforms.unstable.value = swell * 0.8 + (t > BREAK[0] && t < BREAK[1] ? 1 : 0);
				b.glow.intensity = 22 * wave * (1 + swell * 0.6);
				b.fill.intensity = 3 * wave * (1 + swell * 0.6);
				a.fill.intensity = 0;
				b.mat.uniforms.brightness.value = 1.1 * (1 + swell * 0.5);
				a.glow.intensity = 0;
				// It is there once the tape comes back.
				locust.root.visible = t >= BREAK[1] - 0.12;
				const turn = smoothstep(TURN[0], TURN[1], t);
				locust.root.position.set(24.55, 0, -2.45 + turn * 0.1);
				// Looking at the set, side on to the lens; then round to it.
				locust.root.rotation.y = Math.PI * 0.72 + turn * 0.9;
				locust.reset();
				locust.stand({ hunch: 0.1 + turn * 0.08 });
				locust.hangArms();
				locust.turn("Neck1", [0, 1, 0], -turn * 0.35);
				locust.turn("Head1", [0, 0, 1], 0.2 + turn * 0.18);
				locust.turn("Head1", [1, 0, 0], 0.12);
			}
		},
		look(t) {
			// Night gain: the camcorder lifts a dark room until its noise shows.
			const L = tape({ exposure: t < CUT ? 2.0 : 2.7, whiteBalance: [0.96, 1.0, 1.08], grain: 0.34, halation: 0.15, bloom: 0.035 });
			if (t >= CUT && t < CUT + 0.08) L.tracking = 0.5;
			if (t >= BREAK[0] && t < BREAK[1]) {
				const k = (t - BREAK[0]) / (BREAK[1] - BREAK[0]);
				L.tracking = 1;
				L.roll = 0.04 * Math.sin(k * Math.PI);
				L.snow = 0.1 * Math.sin(k * Math.PI);
				L.jerk = Math.sin(k * 37) * 0.5;
			}
			return L;
		},
		overlay(g, t, size) {
			camcorder(g, t, size, { clock: 2 * 3600 + 31 * 60 + 9 + (t >= CUT ? 7 : 0), date: "OCT. 27 1993", focus: t < CLICK + 0.1 ? 1 - smoothstep(CLICK, CLICK + 0.1, t) : 0, word: "TURN ON" });
			if (t < 1.4) burnIn(g, [typed("TAPE 81 · GUEST 02", t, 0.05, 40)], size, { alpha: 1 - smoothstep(1.1, 1.4, t) });
		},
	};
	return shot;
}
