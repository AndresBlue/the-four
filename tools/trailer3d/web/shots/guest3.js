// GUEST 03 — he hid; it saw him go in. Inside a wardrobe: the gap between
// its two doors lets the lamp-lit bedroom in. Steps. The Locust comes through
// the room's door, stooping under the lintel; stops. Silence. It turns to the
// wardrobe, comes close, its mask in the gap, the head tilting. One door
// opens, then the other. Black.
import * as THREE from "three";
import { Kit } from "../engine/kit.js";
import { hotelRoom } from "../engine/sets.js";
import { Locust } from "../engine/locust.js";
import * as P from "../engine/props.js";
import { polyhaven, shadows } from "../engine/assets.js";
import { Volumetrics } from "../engine/volumetric.js";
import { camcorder, burnIn, typed } from "../engine/osd.js";
import { clamp, smooth, smoothstep, lerp, keys } from "../engine/util.js";
import { V, handheld, aimCamera, tape } from "./common.js";

export const ENTER = [0.55, 1.35];
export const STOP = 1.65;
export const TURN = [2.1, 2.7];
export const CLOSE = [2.75, 3.35];
export const DOOR1 = 4.5;
export const DOOR2 = 4.66;
export const BLACK = 4.84;

// Room: x 0..5.6, z 0..6.4. The wardrobe on the east wall, doors facing -x;
// the room's door on the west wall, straight across.
const WARD = V(5.19, 0, 3.4);

export function create(ctx) {
	const scene = new THREE.Scene();
	const camera = new THREE.PerspectiveCamera(58, 4 / 3, 0.02, 60);
	let locust;
	let ward;
	let lampLight;
	const shot = {
		scene, camera, frame: "tape", samples: 32, shutter: 0.5,
		async setup() {
			const kit = await new Kit(scene).load();
			await hotelRoom(kit, { x0: 0, x1: 5.6, z0: 0, z1: 6.4, doors: [{ wall: "w", at: 3.3, open: 1.35 }] });
			// The corridor outside the door, dim.
			kit.floor(-3.6, 1.5, 0, 5.2);
			kit.ceilingSlab(-3.6, 1.5, 0, 5.2);
			kit.wall(-3.6 - 0.09, 1.5, -3.6 - 0.09, 5.2, { dress: [1] });
			const hall = await kit.sconce(-3.6, 1.6, 2.6, 1, 0, { intensity: 2.2 });
			ward = await P.wardrobe();
			ward.group.position.copy(WARD);
			ward.group.rotation.y = -Math.PI / 2;
			scene.add(ward.group);
			// A set carpenter's gap: the leaves pulled a little apart so the crack
			// between them lets the room in (ajar doors only move outward).
			// The model's right leaf is the wider one and laps over the seam.
			ward.left.position.x -= 0.03;
			ward.right.position.x += 0.1;
			ward.hinges = [ward.left.position.x, ward.right.position.x];
			const bed = await P.bed();
			bed.position.set(2.2, 0, 0.95);
			bed.rotation.y = 0;
			scene.add(bed);
			const stand = await polyhaven("ClassicNightstand_01");
			shadows(stand);
			stand.position.set(3.75, 0, 0.35);
			scene.add(stand);
			const standTop = new THREE.Box3().setFromObject(stand).max.y;
			// The bedside lamp: a shade over a warm bulb.
			const shadeMat = new THREE.MeshStandardMaterial({ color: new THREE.Color().setRGB(0.86, 0.74, 0.52, THREE.SRGBColorSpace), emissive: new THREE.Color().setRGB(1, 0.72, 0.42, THREE.SRGBColorSpace), emissiveIntensity: 1.2, roughness: 0.9, side: THREE.DoubleSide });
			const shade = new THREE.Mesh(new THREE.CylinderGeometry(0.13, 0.2, 0.24, 24, 1, true), shadeMat);
			shade.position.set(3.75, standTop + 0.42, 0.35);
			scene.add(shade);
			const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.012, 0.012, 0.32, 8), kit.m.brass);
			pole.position.set(3.75, standTop + 0.16, 0.35);
			scene.add(pole);
			lampLight = new THREE.PointLight(new THREE.Color().setRGB(1, 0.7, 0.42, THREE.SRGBColorSpace), 9, 10, 2);
			lampLight.position.set(3.75, standTop + 0.38, 0.35);
			lampLight.castShadow = true;
			lampLight.shadow.mapSize.set(1024, 1024);
			lampLight.shadow.bias = -0.002;
			lampLight.shadow.camera.near = 0.05;
			scene.add(lampLight);
			const chair = await polyhaven("ArmChair_01");
			shadows(chair);
			chair.position.set(1.0, 0, 5.4);
			chair.rotation.y = Math.PI * 0.8;
			scene.add(chair);
			await kit.painting(2.6, 0, 0, 1, 4);
			locust = await Locust.create();
			scene.add(locust.root);
			shot.volumetrics = new Volumetrics(ctx.renderer, { density: 0.01, noise: 0.4, maxDist: 10, steps: 24 });
			shot.volumetrics.addPoint(lampLight, { radius: 0.8, strength: 0.7 });
			if (hall.light) shot.volumetrics.addPoint(hall.light, { radius: 0.8, strength: 0.6 });
		},
		update(t) {
			// The doors: a crack between them, then flung open.
			const d1 = smoothstep(DOOR1, DOOR1 + 0.14, t);
			const d2 = smoothstep(DOOR2, DOOR2 + 0.14, t);
			ward.left.rotation.y = -0.03 - d1 * 1.6;
			ward.right.rotation.y = 0.05 + d2 * 1.6;
			// Inside, against the back, looking out through the gap.
			const hh = handheld(t, { amp: 0.5, seed: 31 });
			const breathe = Math.sin(t * 2.2) * 0.004;
			aimCamera(camera, V(5.0, 1.63 + breathe, 3.3735).add(hh.pos), V(0.0, 1.55, 3.3735), { yaw: hh.yaw * 0.5, pitch: hh.pitch * 0.5, roll: hh.roll * 0.4 });
			poseLocust(locust, t);
		},
		look(t) {
			const L = tape({ exposure: 2.6, enclosure: t < DOOR1 ? 1 : 1 - smoothstep(DOOR1, DOOR1 + 0.2, t), grain: 0.32 });
			if (t >= BLACK) L.fade = 1;
			return L;
		},
		overlay(g, t, size) {
			if (t < BLACK) camcorder(g, t, size, { clock: 2 * 3600 + 47 * 60 + 52, date: "OCT. 27 1993" });
			if (t < 1.4) burnIn(g, [typed("TAPE 81 · GUEST 03", t, 0.05, 40)], size, { alpha: 1 - smoothstep(1.1, 1.4, t) });
		},
	};
	return shot;
}

// In through the door stooping, a few steps toward the bed, stops; turns
// to the wardrobe; comes to it and bends to the gap.
function poseLocust(L, t) {
	const stop = V(2.15, 0, 3.32);
	const gap = V(3.92, 0, 3.36);
	let pos;
	let yaw;
	let speed = 0;
	let phase = 0;
	let duck = 0;
	if (t < ENTER[0]) {
		pos = V(-2.2, 0, 3.3);
		yaw = Math.PI / 2;
	} else if (t < STOP) {
		const k = smoothstep(ENTER[0], STOP, t);
		pos = V(lerp(-1.9, stop.x, k), 0, lerp(3.3, stop.z, k));
		// Coming in facing the lens, then its head and body go toward the bed.
		yaw = Math.PI / 2 - k * 1.1;
		speed = 2.6 * (1 - smooth((t - (STOP - 0.3)) / 0.3));
		phase = (t - ENTER[0]) * 1.5;
		duck = 1 - smoothstep(0.1, 1.2, pos.x);
	} else if (t < CLOSE[0]) {
		pos = stop.clone();
		const k = smoothstep(TURN[0], TURN[1], t);
		yaw = Math.PI / 2 - 1.1 + k * 1.1;
	} else {
		const k = smoothstep(CLOSE[0], CLOSE[1], t);
		pos = stop.clone().lerp(gap, k);
		yaw = Math.PI / 2;
		speed = 1.6 * Math.sin(Math.PI * k);
		phase = (t - CLOSE[0]) * 1.2 + 0.2;
	}
	L.root.position.copy(pos);
	L.root.rotation.y = yaw;
	L.reset();
	const bend = smoothstep(CLOSE[0] + 0.3, CLOSE[1], t);
	if (speed > 0.1) L.poseGait(speed, phase, { duck });
	else L.stand({ duck, hunch: 0.1 + bend * 0.35 });
	L.hangArms();
	// Close to the doors the long arms hang back, clear of the wood.
	if (bend > 0) {
		L.aim("L_UpperArm", "L_Forearm", [0.25, -1.0, -0.25 * bend]);
		L.aim("R_UpperArm", "R_Forearm", [-0.25, -1.0, -0.25 * bend]);
		L.aim("L_Forearm", "L_Hand", [0.1, -1.0, -0.3 * bend]);
		L.aim("R_Forearm", "R_Hand", [-0.1, -1.0, -0.3 * bend]);
	}
	// Bent to the gap: the mask down level with the eye inside.
	if (bend > 0) {
		L.turn("Spine2", [1, 0, 0], bend * 0.42);
		L.turn("Spine4", [1, 0, 0], bend * 0.3);
		L.turn("Neck1", [1, 0, 0], -bend * 0.5);
		L.turn("Head1", [1, 0, 0], -bend * 0.25);
	}
	const tilt = smoothstep(CLOSE[1] + 0.15, CLOSE[1] + 0.7, t);
	L.turn("Head1", [0, 0, 1], tilt * 0.42 + Math.sin(t * 17) * 0.02 * tilt);

}
