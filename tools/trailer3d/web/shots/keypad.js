// The code: beep 7, beep 3, beep 9, beep 1, each on its own; the tone;
// UNLOCKED; the last door is pulled open, quick, on the lift's light.
import * as THREE from "three";
import { Kit } from "../engine/kit.js";
import { hotelRoom } from "../engine/sets.js";
import { Locust } from "../engine/locust.js";
import { Detective, detectiveTorch, detectiveRun } from "../engine/detective.js";
import { Volumetrics } from "../engine/volumetric.js";
import { camcorder } from "../engine/osd.js";
import { clamp, smooth, smoothstep, lerp } from "../engine/util.js";
import { V, handheld, steps, aimCamera, makeTorch, holdTorch, tape } from "./common.js";

export const KEYS = [0.3, 0.65, 1.0, 1.35];
export const TONE = 1.7;
export const OPEN = 2.05;
const CODE = [7, 3, 9, 1];

function keypadFace(pressed) {
	const c = document.createElement("canvas");
	c.width = 256;
	c.height = 400;
	const g = c.getContext("2d");
	g.fillStyle = "#17171a";
	g.fillRect(0, 0, 256, 400);
	const labels = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"];
	for (let i = 0; i < 12; i++) {
		const x = 38 + (i % 3) * 64;
		const y = 150 + Math.floor(i / 3) * 60;
		const on = pressed === labels[i];
		g.fillStyle = on ? "#c8e6b4" : "#3a3a3e";
		g.fillRect(x, y, 52, 46);
		g.fillStyle = on ? "#1a2a14" : "#c9c6b8";
		g.font = "600 30px Consolas, monospace";
		g.textAlign = "center";
		g.textBaseline = "middle";
		g.fillText(labels[i], x + 26, y + 24);
	}
	const t = new THREE.CanvasTexture(c);
	t.colorSpace = THREE.SRGBColorSpace;
	return t;
}

function displayTexture() {
	const c = document.createElement("canvas");
	c.width = 320;
	c.height = 140;
	const t = new THREE.CanvasTexture(c);
	t.colorSpace = THREE.SRGBColorSpace;
	return { c, t, g: c.getContext("2d") };
}

export function create(ctx) {
	const scene = new THREE.Scene();
	const camera = new THREE.PerspectiveCamera(46, 4 / 3, 0.02, 80);
	let face;
	let display;
	let lastPressed = null;
	let door;
	let carDoors;
	let other;
	let locust;
	let torch;
	let beam;
	const shot = {
		scene, camera, frame: "tape", samples: 28, shutter: 0.5,
		async setup() {
			// The refuge (x 0..6, z 0..6) with the last door on its west wall and the
			// keypad beside it; the lift vestibule behind that door (x -4..0), the car
			// against its far wall. The refuge's own door to the corridor on its east wall.
			const kit = await new Kit(scene).load();
			await hotelRoom(kit, { x0: 0, x1: 6, z0: 0, z1: 6, doors: [{ wall: "e", at: 3.0, open: 1.56 }, { wall: "w", at: 3.0, leaf: false }] });
			door = await kit.door(-0.09, 3.0, Math.PI / 2, { open: 0 });
			const lamp = kit.dome(3, 3, { intensity: 9, color: 0xb8d4b6 });
			// The refuge's light as it reaches its far door: a pool on the threshold,
			// the edge of where it is safe, and the mask leaning into it.
			const doorway = new THREE.SpotLight(new THREE.Color(0xc4dcc0), 14, 8, THREE.MathUtils.degToRad(24), 0.7, 2);
			doorway.position.set(4.3, 2.95, 3.05);
			doorway.target.position.set(6.4, 1.7, 3.0);
			scene.add(doorway, doorway.target);
			shot.doorway = doorway;
			// The corridor outside the refuge, dark.
			kit.floor(6.2, -2, 18, 8);
			kit.ceilingSlab(6.2, -2, 18, 8);
			kit.wall(6.18, 1.3, 18, 1.3, { dress: [1] });
			kit.wall(6.18, 4.7, 18, 4.7, { dress: [-1] });
			kit.wall(18, 1.3, 18, 4.7, { dress: [-1] });
			// A lamp further down the corridor, dim, behind where it will stand.
			const behind = await kit.sconce(12.5, 1.6, 1.3, 0, 1, { intensity: 1.2 });
			// The vestibule, tiled and lit, and the car.
			kit.floor(-4.4, 0, 0, 6, kit.m.tile);
			kit.ceilingSlab(-4.4, 0, 0, 6);
			kit.wall(-4.4, -0.09, 0, -0.09, { dress: [1], finish: "tile" });
			kit.wall(-4.4, 6.09, 0, 6.09, { dress: [-1], finish: "tile" });
			const carX = -4.4 + 0.1 + 1.15;
			// Car: 2.6 wide (along z), 2.45 high, 2.3 deep (along x), opening facing +x.
			const cx0 = carX - 1.15;
			const cx1 = carX + 1.15;
			const metal = kit.m.metal;
			kit.box(2.3, 0.3, 2.6, metal, carX, -0.15, 3.0, { cast: false });
			kit.box(2.3, 0.12, 2.6, metal, carX, 2.51, 3.0);
			kit.box(0.12, 2.45, 2.6, new THREE.MeshStandardMaterial({ color: 0x8c8c86, metalness: 1, roughness: 0.06 }), cx0 - 0.06, 1.225, 3.0);
			for (const s of [-1, 1]) {
				kit.box(2.3, 2.45, 0.12, metal, carX, 1.225, 3.0 + s * 1.36);
				kit.box(2.0, 0.9, 0.03, kit.m.panel, carX, 0.45, 3.0 + s * 1.28);
				kit.box(2.1, 0.05, 0.05, kit.m.brass, carX, 0.92, 3.0 + s * 1.24);
			}
			kit.box(0.16, 0.06, 2.6, kit.m.brass, cx1, 0.03, 3.0);
			const panelLight = new THREE.Mesh(new THREE.BoxGeometry(0.7, 0.04, 1.0), new THREE.MeshStandardMaterial({ color: 0xeed8b0, emissive: 0xffe0b0, emissiveIntensity: 2.2 }));
			panelLight.position.set(carX, 2.43, 3.0);
			scene.add(panelLight);
			const carLamp = new THREE.PointLight(new THREE.Color().setRGB(0.96, 0.94, 0.86, THREE.SRGBColorSpace), 2.6, 6, 2);
			carLamp.position.set(carX, 2.2, 3.0);
			carLamp.castShadow = true;
			carLamp.shadow.mapSize.set(1024, 1024);
			scene.add(carLamp);
			const vest = kit.dome(-2.2, 3.0, { intensity: 3 });
			// The car's two leaves, sliding in from the sides of the opening.
			carDoors = [];
			// Brushed steel, the grain running up, as in the car from inside.
			const brushed = new THREE.MeshPhysicalMaterial({ color: 0x8a8a84, metalness: 1, roughness: 0.36, anisotropy: 0.85, anisotropyRotation: Math.PI / 2 });
			for (const s of [-1, 1]) {
				const leaf = kit.box(0.06, 2.35, 1.12, brushed, cx1 + 0.02, 1.175, 3.0 + s * 1.62);
				carDoors.push({ leaf, s });
			}
			// The keypad on the refuge's west wall, beside the door.
			face = new THREE.MeshStandardMaterial({ map: keypadFace(null), roughness: 0.5, metalness: 0.3 });
			const pad = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.34, 0.22), [kit.m.black, kit.m.black, kit.m.black, kit.m.black, kit.m.black, kit.m.black]);
			pad.position.set(0.03, 1.3, 1.9);
			scene.add(pad);
			const facePlane = new THREE.Mesh(new THREE.PlaneGeometry(0.2, 0.3125), face);
			facePlane.position.set(0.062, 1.27, 1.9);
			facePlane.rotation.y = Math.PI / 2;
			scene.add(facePlane);
			display = displayTexture();
			const lcd = new THREE.Mesh(new THREE.PlaneGeometry(0.16, 0.07), new THREE.MeshStandardMaterial({ color: 0x000000, emissive: 0xffffff, emissiveMap: display.t, emissiveIntensity: 1.6 }));
			lcd.position.set(0.064, 1.42, 1.9);
			lcd.rotation.y = Math.PI / 2;
			scene.add(lcd);
			shot.lcdLight = new THREE.PointLight(new THREE.Color().setRGB(0.3, 1.0, 0.45, THREE.SRGBColorSpace), 0.25, 1.2, 2);
			shot.lcdLight.position.set(0.2, 1.42, 1.9);
			scene.add(shot.lcdLight);
			other = await Detective.create();
			scene.add(other.root);
			locust = await Locust.create();
			scene.add(locust.root);
			torch = makeTorch(scene, { intensity: 60 });
			// The other one's torch, raised across the refuge onto the far door.
			beam = makeTorch(scene, { intensity: 160, angle: 13, penumbra: 0.5 });
			shot.volumetrics = new Volumetrics(ctx.renderer, { density: 0.012, noise: 0.6, maxDist: 20, steps: 28 });
			shot.volumetrics.addPoint(lamp, { radius: 1.2 });
			shot.volumetrics.addPoint(carLamp, { radius: 0.8, strength: 0.5 });
			shot.volumetrics.addSpot(beam, { strength: 0.35 });
		},
		update(t) {
			// The display and the key that is down.
			const typedN = KEYS.filter((k) => t >= k).length;
			const down = KEYS.find((k) => t >= k && t < k + 0.09);
			const pressed = down !== undefined ? String(CODE[KEYS.indexOf(down)]) : null;
			if (pressed !== lastPressed) {
				face.map = keypadFace(pressed);
				face.needsUpdate = true;
				lastPressed = pressed;
			}
			const g = display.g;
			g.fillStyle = "#0c1f10";
			g.fillRect(0, 0, 320, 140);
			g.font = "600 64px Consolas, monospace";
			g.textAlign = "center";
			g.textBaseline = "middle";
			g.fillStyle = "#5dff86";
			const words = t >= TONE + 0.1 ? "UNLOCKED" : CODE.map((d, i) => (i < typedN ? String(d) : "_")).join(" ");
			g.font = t >= TONE + 0.1 ? "600 46px Consolas, monospace" : "600 64px Consolas, monospace";
			g.fillText(words, 160, 72);
			display.t.needsUpdate = true;
			// Wide open, flat to the wall, so the way back is in sight from the car.
		door.leaf.rotation.y = -smooth((t - OPEN) / 0.35) * 1.3;
			// Back from the wall: the keypad and the door beside it both in view.
			const hh = handheld(t, { amp: 0.8, seed: 71 });
			camera.fov = 50;
			aimCamera(camera, V(1.85, 1.55, 1.05).add(hh.pos), V(0.0, 1.3, 2.55), { yaw: hh.yaw, pitch: hh.pitch, roll: hh.roll });
			holdTorch(torch, camera, { ahead: 1.8, sway: 0.1, swayT: t });
			torch.intensity = 16;
			other.root.visible = false;
			locust.root.visible = false;
			beam.visible = false;
			for (const d of carDoors) d.leaf.position.z = 3.0 + d.s * 1.62;
		},
		look(t) {
			return tape({ exposure: 1.6 });
		},
		overlay(g, t, size) {
			camcorder(g, t, size, { clock: 3 * 3600 + 52 * 60 + 40, date: "OCT. 27 1993", focus: 1, word: "KEYPAD" });
		},
	};
	return shot;
}
