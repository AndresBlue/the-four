// GUEST 03 — he hid. Inside a wardrobe, in the dark: his breath, his heart.
// He pushes one door open a hair, slowly: nothing out there, nothing to see.
// Then the door is torn open and it is on him, all at once, barely seen; the
// picture goes dark at once.
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

export const AJAR = [0.9, 2.9];
export const OPEN = 3.35;
export const LUNGE = 3.38;
export const CATCH = 3.58;

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
			// The room's light off the open leaf, back onto its mask.
			const bounce = new THREE.PointLight(new THREE.Color().setRGB(1, 0.78, 0.55, THREE.SRGBColorSpace), 0.9, 2.2, 2);
			bounce.position.set(4.55, 1.75, 3.05);
			scene.add(bounce);
			shot.volumetrics = new Volumetrics(ctx.renderer, { density: 0.01, noise: 0.4, maxDist: 10, steps: 24 });
			shot.volumetrics.addPoint(lampLight, { radius: 0.8, strength: 0.7 });
			if (hall.light) shot.volumetrics.addPoint(hall.light, { radius: 0.8, strength: 0.6 });
		},
		update(t) {
			// Shut; pushed a hair open, slowly; then torn open from outside.
			const crack = smoothstep(AJAR[0], AJAR[1], t) * 0.07;
			const open = smoothstep(OPEN, OPEN + 0.06, t);
			ward.left.rotation.y = -0.02;
			ward.right.rotation.y = 0.02 + crack + open * 1.5;
			// Inside, against the back, looking out; leaning to the crack.
			const hh = handheld(t, { amp: 0.5, seed: 31 });
			const breathe = Math.sin(t * 2.2) * 0.004;
			const lean = smoothstep(AJAR[0], AJAR[1] + 0.3, t) * 0.12;
			aimCamera(camera, V(5.0 - lean, 1.6 + breathe, 3.36 + lean * 0.4).add(hh.pos), V(0.0, 1.62, 3.3), { yaw: hh.yaw * 0.5, pitch: hh.pitch * 0.5, roll: hh.roll * 0.4 });
			poseLocust(locust, t);
		},
		look(t) {
			const L = tape({ exposure: 2.2, enclosure: t < OPEN ? 1 : 1 - smoothstep(OPEN, OPEN + 0.2, t), grain: 0.32 });
			// Shut in: black but for the grain; the crack lets in a line.
			L.fadeAll = t < AJAR[0] ? 0.96 : 0.96 - smoothstep(AJAR[0], AJAR[1], t) * 0.4;
			if (t >= OPEN) {
				L.fadeAll = smoothstep(OPEN + 0.08, CATCH, t);
				L.threat_glitch = 0.8;
				L.jerk = 0.8;
			}
			if (t >= CATCH) L.fadeAll = 1;
			return L;
		},
		overlay(g, t, size) {
			if (t < CATCH) camcorder(g, t, size, { clock: 2 * 3600 + 47 * 60 + 52, date: "OCT. 27 1993" });
			if (t < 1.4) burnIn(g, [typed("TAPE 81 · GUEST 03", t, 0.05, 40)], size, { alpha: 1 - smoothstep(1.1, 1.4, t) });
		},
	};
	return shot;
}

// Bent to the doors, waiting, the mask level with the crack and turned to
// it, the head on one side; when the door opens it comes through it.
const MASK = V(4.12, 1.66, 3.2);
const LENS = V(4.95, 1.6, 3.4);

function poseLocust(L, t) {
	const head = L.bones.Head1;
	L.root.position.set(0, 0, 0);
	L.root.rotation.set(0, Math.PI / 2, 0);
	L.reset();
	L.root.updateMatrixWorld(true);
	const rest = head.getWorldQuaternion(new THREE.Quaternion());
	L.stand({ duck: 0.55, hunch: 0.6 });
	L.hangArms();
	L.aim("L_UpperArm", "L_Forearm", [0.25, -1.0, -0.25]);
	L.aim("R_UpperArm", "R_Forearm", [-0.25, -1.0, -0.25]);
	L.turn("Spine2", [1, 0, 0], 0.42);
	L.turn("Spine4", [1, 0, 0], 0.3);
	const lunge = smoothstep(LUNGE, CATCH, t);
	if (lunge > 0) L.poseArms({ attack: lunge, aggression: 1 });
	L.root.updateMatrixWorld(true);
	// Put the head where the crack is (the feet go where they must).
	// Out of sight of the crack, to one side, until the door goes; then
	// straight at the lens.
	const want = t < OPEN ? V(4.0, 1.66, 1.6) : MASK.clone().setY(1.42).lerp(LENS, 0.2 + lunge * 0.55);
	L.root.position.copy(want.sub(L.point("Head1")));
	L.root.updateMatrixWorld(true);
	// The mask to the crack; still, now and then the head ticks further over.
	const tick = Math.sin(t * 1.7) > 0.93 ? 0.12 : 0;
	const look = LENS.clone().sub(L.point("Head1")).normalize();
	const turnTo = new THREE.Quaternion().setFromUnitVectors(V(0, 0, 1), look);
	const tilt = new THREE.Quaternion().setFromAxisAngle(look, 0.42 + tick + Math.sin(t * 17) * 0.015);
	const wanted = tilt.multiply(turnTo).multiply(rest);
	const parent = head.parent.getWorldQuaternion(new THREE.Quaternion());
	head.quaternion.copy(parent.invert().multiply(wanted));
	L.root.updateMatrixWorld(true);
	if (lunge > 0) L.jaw(lunge);
}
