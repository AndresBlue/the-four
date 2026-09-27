// Four guests checked in. The dark reception: the red emergency beacon on the
// ceiling beating slowly (the game's own marker of where a floor starts), a
// light haze, three torch beams crossing the room; the fourth guest is the
// camera. Nothing happens for a moment. Far off, a door: clack. The beams stop.
import * as THREE from "three";
import { Kit } from "../engine/kit.js";
import { hotelRoom } from "../engine/sets.js";
import * as P from "../engine/props.js";
import { polyhaven, shadows } from "../engine/assets.js";
import { Survivor, poseTorch } from "../engine/survivor.js";
import { Detective, detectiveTorch } from "../engine/detective.js";
import { Volumetrics } from "../engine/volumetric.js";
import { camcorder } from "../engine/osd.js";
import { clamp, smooth, smoothstep, lerp, fbm1 } from "../engine/util.js";
import { V, handheld, aimCamera, makeTorch, holdTorch, tape } from "./common.js";

export const CLACK = 1.35;
// Where the clack came from: the far door, ahead on the right.
const SOUND = V(4.2, 1.4, -10.6);

// Where each guest stands and where their torch wanders before the clack.
// Backs to the lens, all facing into the room, the beams searching ahead:
// silhouettes against what their own beams find. Two of them in the
// detective's hat and coat, the third the other detective.
const GUESTS = [
	{ at: V(-2.4, 0, -2.6), yaw: Math.PI + 0.12, aims: [V(-3.6, 0.4, -10.6), V(-1.0, 1.2, -10.4)], who: "man" },
	{ at: V(2.3, 0, -1.6), yaw: Math.PI - 0.12, aims: [V(3.8, 1.8, -10.6), V(1.2, 0.8, -10.2)], who: "man" },
	{ at: V(0.7, 0, -5.6), yaw: Math.PI, aims: [V(-1.4, 2.2, -10.8), V(1.9, 1.2, -10.8)], who: "woman" },
];

export function create(ctx) {
	const scene = new THREE.Scene();
	const camera = new THREE.PerspectiveCamera(58, 4 / 3, 0.05, 60);
	const guests = [];
	let beacon;
	let torch;
	const shot = {
		scene, camera, frame: "tape", samples: 32, shutter: 0.5,
		async setup() {
			const kit = await new Kit(scene, { ceiling: 4.2 }).load();
			await hotelRoom(kit, { x0: -7, x1: 7, z0: -11, z1: 3, height: 4.2, doors: [{ wall: "n", at: 3.0, open: 0 }, { wall: "e", at: 4.0, open: 0.3 }, { wall: "w", at: 5.5, open: 0 }] });
			// The desk: dark wood on a panelled front, the register on it.
			kit.box(4.2, 1.08, 0.7, kit.m.panel, 0, 0.54, -9.4);
			kit.box(4.4, 0.06, 0.85, kit.m.trim, 0, 1.11, -9.35);
			const register = await polyhaven("CashRegister_01");
			shadows(register);
			register.position.set(1.2, 1.14, -9.4);
			scene.add(register);
			// The key board behind it.
			kit.box(2.4, 1.2, 0.05, kit.m.panel, 0, 1.9, -10.95);
			const brass = kit.m.brass;
			for (let i = 0; i < 24; i++) kit.box(0.02, 0.07, 0.03, brass, -1.05 + (i % 8) * 0.3, 2.25 - Math.floor(i / 8) * 0.35, -10.9, { cast: false });
			for (const [x, z, r] of [[-5.2, -1.5, 0.6], [-4.6, 1.2, 2.2], [4.9, 0.6, -2.6]]) {
				const chair = await polyhaven("ArmChair_01");
				shadows(chair);
				chair.position.set(x, 0, z);
				chair.rotation.y = r;
				scene.add(chair);
			}
			const sofa = await P.sofa();
			sofa.position.set(5.9, 0, -5.0);
			sofa.rotation.y = -Math.PI / 2;
			scene.add(sofa);
			for (const [x, z] of [[-6.3, -10.3], [6.3, -10.3]]) {
				const plant = await P.monstera();
				plant.position.set(x, 0, z);
				scene.add(plant);
			}
			const chandelier = await polyhaven("Chandelier_01");
			shadows(chandelier);
			chandelier.position.set(0, 3.2, -4.5);
			scene.add(chandelier);
			await kit.painting(-7.0, -6.0, 1, 0, 5);
			await kit.painting(7.0, -8.0, -1, 0, 9);
			beacon = kit.beacon(0.6, -7.6, { height: 4.2 });
			for (const g of GUESTS) {
				const s = g.who === "man" ? await Detective.create() : await Survivor.create();
				s.root.position.copy(g.at);
				s.root.rotation.y = g.yaw;
				scene.add(s.root);
				const lamp = new THREE.Mesh(new THREE.CylinderGeometry(0.022, 0.018, 0.22, 12), new THREE.MeshStandardMaterial({ color: 0x151515, metalness: 0.7, roughness: 0.4 }));
				scene.add(lamp);
				const light = makeTorch(scene, { intensity: 110, angle: 24 });
				guests.push({ ...g, s, lamp, light });
			}
			torch = makeTorch(scene, { intensity: 60, angle: 24 });
			// Dust more than fog: it scatters as much back toward the lens as on,
			// so beams pointed away still show as shafts.
			shot.volumetrics = new Volumetrics(ctx.renderer, { density: 0.035, g: 0.15, noise: 0.85, noiseScale: 0.35, maxDist: 20, steps: 44 });
			for (const g of guests) shot.volumetrics.addSpot(g.light, { strength: 0.85 });
			shot.volumetrics.addSpot(torch, { strength: 0.3 });
			shot.volumetrics.addPoint(beacon.light, { radius: 2.2, strength: 0.6 });
		},
		update(time) {
			// Subframes can reach a hair before the shot's start.
			const t = Math.max(0, time);
			beacon.set(t + 0.6);
			// Searching, afraid: each beam darts from place to place and shakes
			// where it rests. At the clack, every beam whips to the sound.
			const heard = smoothstep(CLACK + 0.05, CLACK + 0.28, t);
			for (const [i, g] of guests.entries()) {
				const pts = [g.aims[0], g.aims[1], g.aims[0].clone().lerp(g.aims[1], 0.5).add(V(0, 0.6, 0))];
				const hop = t * (1.6 + i * 0.35) + i * 0.7;
				const n = Math.floor(hop);
				const f = hop - n;
				const dart = f < 0.3 ? smooth(f / 0.3) : 1;
				const aim = pts[n % 3].clone().lerp(pts[(n + 1) % 3], dart);
				aim.add(V(fbm1(t * 6, 60 + i) * 0.18, fbm1(t * 5.5, 70 + i) * 0.14, 0));
				aim.lerp(SOUND.clone().add(V(fbm1(t * 9, 80 + i) * 0.12, fbm1(t * 8, 90 + i) * 0.1, i * 0.4 - 0.4)), heard);
				// Facing into the room, all of them: only the beams go to the sound.
				g.s.root.rotation.y = g.yaw;
				const pose = g.who === "man" ? detectiveTorch : poseTorch;
				const { hand, dir } = pose(g.s, aim, { breathe: Math.sin(t * 5 + i) });
				g.lamp.position.copy(hand).add(dir.clone().multiplyScalar(0.08));
				g.lamp.quaternion.setFromUnitVectors(V(0, 1, 0), dir);
				g.light.position.copy(hand).add(dir.clone().multiplyScalar(0.2));
				g.light.target.position.copy(aim);
			}
			// The camera's torch passes over the others' backs, looking too.
			const hh = handheld(t, { amp: 1.8, seed: 11 });
			const sweep = [V(-2.2, 1.4, -2.9), V(0.6, 1.3, -5.9), V(2.4, 1.5, -2.0), V(-1.5, 1.0, -9.5)];
			const hop = t * 1.9;
			const n = Math.floor(hop);
			const f = hop - n;
			const mine = sweep[n % 4].clone().lerp(sweep[(n + 1) % 4], f < 0.35 ? smooth(f / 0.35) : 1).lerp(SOUND, heard);
			const look = V(-0.4, 1.4, -8.0).lerp(mine.clone().setY(1.35), 0.35);
			aimCamera(camera, V(0.6, 1.62, 1.8).add(hh.pos), look, { yaw: hh.yaw, pitch: hh.pitch, roll: hh.roll });
			holdTorch(torch, camera, { ahead: 3 });
			torch.target.position.copy(mine.add(V(fbm1(t * 7, 5) * 0.1, fbm1(t * 6, 6) * 0.08, 0)));
			torch.target.updateMatrixWorld();
			torch.intensity = 60;
		},
		look(t) {
			return tape({ exposure: 1.6, grain: 0.3, halation: 0.35 });
		},
		overlay(g, t, size) {
			camcorder(g, t, size, { clock: 2 * 3600 + 3 * 60 + 41, date: "OCT. 27 1993" });
		},
	};
	return shot;
}
