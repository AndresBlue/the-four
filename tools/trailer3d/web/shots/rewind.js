// A new hotel every tape. The tape rewound three times, a second each, and
// each time the building going by backward is another: a straight clean
// corridor of paper and warm lamps; one that turns, doors open, a fire door;
// rooms opening into rooms and a ruined lounge. The words stay on it.
import * as THREE from "three";
import { Kit } from "../engine/kit.js";
import { corridor, hotelRoom } from "../engine/sets.js";
import * as P from "../engine/props.js";
import { polyhaven, shadows } from "../engine/assets.js";
import { Volumetrics } from "../engine/volumetric.js";
import { camcorder, text } from "../engine/osd.js";
import { clamp, smooth, smoothstep, lerp } from "../engine/util.js";
import { V, handheld, steps, aimCamera, tape } from "./common.js";

// Each rewind, through its hotel.
export const REWINDS = [[0, 1], [1, 2], [2, 3]];
const ORIGINS = [V(0, 0, 0), V(60, 0, 0), V(120, 0, 0)];

export function create(ctx) {
	const scene = new THREE.Scene();
	const camera = new THREE.PerspectiveCamera(54, 4 / 3, 0.05, 90);
	const shot = {
		scene, camera, frame: "tape", samples: 28, shutter: 0.5,
		async setup() {
			const kit = await new Kit(scene).load();
			const lights = [];
			// A: straight, clean, lamps all along.
			{
				const doors = [];
				const art = [];
				for (let at = 3; at < 30; at += 6.5) {
					doors.push({ side: 1, at, number: 200 + Math.round(at) * 2 + 1 });
					doors.push({ side: -1, at: at + 3.2, number: 200 + Math.round(at) * 2 + 2 });
					art.push({ side: -1, at: at + 0.4, intensity: 2.4 });
					art.push({ side: 1, at: at + 3.6, intensity: 2.4 });
				}
				const set = await corridor(kit, { length: 34, width: 3.0, doors, art, signs: [{ at: 16 }] });
				lights.push(...set.lights);
			}
			// B: turns right after 9 m; doors stood open; a fire door flat to the walls.
			{
				const o = ORIGINS[1];
				const g = new THREE.Group();
				g.position.copy(o);
				scene.add(g);
				const kb = await new Kit(g).load();
				const set = await corridor(kb, { length: 11.5, width: 3.5, doors: [{ side: -1, at: 3.4, number: 312, open: 1.2, room: { depth: 5, lit: 2.2 } }, { side: 1, at: 5.2, number: 315, open: 0.8, room: { depth: 5 } }], art: [{ side: -1, at: 7.4, intensity: 2.4 }], gaps: [{ side: 1, from: 8.0, to: 11.5 }], fireDoors: [{ at: 6.5, open: 1 }] });
				lights.push(...set.lights);
				// The branch off to the right.
				kb.floor(1.7, -11.7, 16, -7.8);
				kb.ceilingSlab(1.7, -11.7, 16, -7.8);
				kb.wall(1.84, -7.91, 16, -7.91, { dress: [-1] });
				kb.wall(-1.9, -11.59, 16, -11.59, { dress: [1] });
				const sc = await kb.sconce(9.0, 1.6, -11.5, 0, 1, { intensity: 2.6 });
				lights.push(sc.light);
				await kb.exitSign(8.0, -9.7, Math.PI / 2, "way_left");
			}
			// C: rooms opening into rooms, and a ruined lounge.
			{
				const o = ORIGINS[2];
				const g = new THREE.Group();
				g.position.copy(o);
				scene.add(g);
				const kc = await new Kit(g, { ceiling: 4.2, wallpaper: "wallpaperDecrepit" }).load();
				await hotelRoom(kc, { x0: -2, x1: 2.5, z0: -3.2, z1: 1.5, height: 3.15, doors: [{ wall: "n", at: 2.0, open: 1.4 }] });
				await hotelRoom(kc, { x0: -6, x1: 7, z0: -15, z1: -3.2 - 0.18, height: 4.2, doors: [{ wall: "s", at: 6.0, leaf: false }] });
				const ruin = [[-3.5, -8.0, 0.4, "Sofa_01"], [3.4, -9.8, -2.2, "ArmChair_01"], [-1.0, -12.5, 1.9, "GreenChair_01"], [4.5, -5.8, 2.8, "ArmChair_01"]];
				for (const [x, z, r, id] of ruin) {
					const m = await polyhaven(id);
					shadows(m);
					m.position.set(o.x + x, 0, z);
					m.rotation.y = r;
					if (id === "GreenChair_01") m.rotation.z = 1.4;
					scene.add(m);
				}
				const ch = await polyhaven("Chandelier_01");
				shadows(ch);
				ch.position.set(o.x + 0.5, 1.2, -9.0);
				ch.rotation.z = 0.9;
				scene.add(ch);
				for (const [x, z] of [[-5.8, -6.0], [6.8, -11.0]]) {
					const sc = await kc.sconce(x, 1.7, z, x < 0 ? 1 : -1, 0, { intensity: 5.5, shadow: true, range: 12 });
					lights.push(sc.light);
				}
				const lamp = kc.dome(0.3, -0.8, { intensity: 1.5, height: 3.15 });
				lights.push(lamp);
				// Two floor lamps someone left on.
				for (const [x, z] of [[-3.8, -10.5], [5.0, -7.0]]) {
					const fl = new THREE.PointLight(new THREE.Color().setRGB(1, 0.7, 0.42, THREE.SRGBColorSpace), 6, 9, 2);
					fl.position.set(o.x + x, 1.55, z);
					fl.castShadow = true;
					fl.shadow.mapSize.set(512, 512);
					scene.add(fl);
					lights.push(fl);
					const shade = new THREE.Mesh(new THREE.CylinderGeometry(0.17, 0.3, 0.4, 20, 1, true), new THREE.MeshStandardMaterial({ color: 0xd8c49a, emissive: new THREE.Color().setRGB(1, 0.72, 0.42, THREE.SRGBColorSpace), emissiveIntensity: 1.6, side: THREE.DoubleSide }));
					shade.position.set(o.x + x, 1.7, z);
					scene.add(shade);
					const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.018, 0.018, 1.62, 8), new THREE.MeshStandardMaterial({ color: 0x3a2a14, metalness: 0.7, roughness: 0.4 }));
					pole.position.set(o.x + x, 0.81, z);
					scene.add(pole);
				}
				// Night coming in through the tall windows of the far wall.
				for (const z of [-7.5, -11.5]) {
					const moon = new THREE.SpotLight(new THREE.Color().setRGB(0.55, 0.66, 0.9, THREE.SRGBColorSpace), 380, 20, 0.36, 0.5, 2);
					moon.position.set(o.x - 5.6, 3.9, z);
					moon.target.position.set(o.x + 1.5, 0, z + 1.0);
					moon.castShadow = true;
					moon.shadow.mapSize.set(1024, 1024);
					scene.add(moon, moon.target);
					shot.moons = [...(shot.moons ?? []), moon];
				}
			}
			shot.volumetrics = new Volumetrics(ctx.renderer, { density: 0.02, noise: 0.7, maxDist: 30, steps: 32 });
			for (const l of lights) if (l) shot.volumetrics.addPoint(l, { radius: 0.9 });
			for (const m of shot.moons) shot.volumetrics.addSpot(m, { strength: 0.35 });
		},
		update(t) {
			// Which hotel, and the walk through it run backward, fast.
			const pass = Math.max(0, Math.min(2, Math.floor(t)));
			const u = 1 - clamp(t - pass);
			const o = ORIGINS[pass];
			const z = pass === 2 ? -2.6 - u * 4.4 : -0.6 - u * 6.0;
			const st = steps(u * 4, { rate: 1.8, amp: 0.7 });
			const hh = handheld(t, { amp: 1.2, seed: 7 });
			const pos = V(o.x + 0.1, 1.62, z).add(st.pos).add(hh.pos);
			const pan = [0, 0.18, -0.12][pass] * u;
			aimCamera(camera, pos, V(o.x + 0.1 + pan * 20, 1.45, z - 20), { yaw: hh.yaw, pitch: hh.pitch + st.pitch, roll: hh.roll + st.roll });
		},
		look(t) {
			const L = tape({ exposure: t >= 2 ? 1.9 : 1.3 });
			const k = t - Math.floor(t);
			L.rewind = 0.4 + 0.15 * Math.sin(k * Math.PI);
			L.tracking = 0.35;
			// The jump from one to the next.
			if (k < 0.06 && t > 0.5) {
				L.tracking = 1;
				L.snow = 0.6;
			}
			return L;
		},
		overlay(g, t, size) {
			camcorder(g, t, size, { clock: 2 * 3600 + 5 * 60 + 2, date: "OCT. 27 1993" });
		},
		// Over the tape, not in it: the words hold still while it rewinds.
		overlayClean(g, t, size) {
			const u = size.h / 1080;
			text(g, "A NEW HOTEL EVERY TAPE", size.w / 2, size.h * 0.64, { size: 34, align: "center", u: u * 1.5, spacing: 3 });
		},
	};
	return shot;
}
