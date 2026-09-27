// In the car: only its motor, a shiver of the floor; it starts down. The
// picture loses its hold and rolls away into black.
import * as THREE from "three";
import { Kit } from "../engine/kit.js";
import { Detective, detectiveTorch } from "../engine/detective.js";
import { camcorder } from "../engine/osd.js";
import { clamp, smooth, smoothstep, fbm1 } from "../engine/util.js";
import { V, aimCamera, tape } from "./common.js";

export const DOWN = 0.18;
export const LOSE = 0.42;

export function create(ctx) {
	const scene = new THREE.Scene();
	const camera = new THREE.PerspectiveCamera(56, 4 / 3, 0.02, 30);
	let other;
	const shot = {
		scene, camera, frame: "tape", samples: 24, shutter: 0.5,
		async setup() {
			const kit = await new Kit(scene).load();
			// The car from inside, doors shut: brushed metal, a mirror, dark wood, brass.
			const metal = kit.m.metal;
			kit.box(2.3, 0.3, 2.6, metal, 0, -0.15, 0, { cast: false });
			kit.box(2.3, 0.12, 2.6, metal, 0, 2.51, 0);
			kit.box(0.12, 2.45, 2.6, new THREE.MeshStandardMaterial({ color: 0x8c8c86, metalness: 1, roughness: 0.06 }), -1.21, 1.225, 0);
			for (const s of [-1, 1]) {
				kit.box(2.3, 2.45, 0.12, metal, 0, 1.225, s * 1.36);
				kit.box(2.0, 0.9, 0.03, kit.m.panel, 0, 0.45, s * 1.28);
				kit.box(2.1, 0.05, 0.05, kit.m.brass, 0, 0.92, s * 1.24);
			}
			// The doors: brushed steel, the grain running up, so the lamp draws a
			// long soft streak on them rather than a spot.
			const brushed = new THREE.MeshPhysicalMaterial({ color: 0x8a8a84, metalness: 1, roughness: 0.36, anisotropy: 0.85, anisotropyRotation: Math.PI / 2 });
			kit.box(0.08, 2.45, 2.6, brushed, 1.19, 1.225, 0);
			kit.box(0.02, 2.35, 0.008, kit.m.black, 1.14, 1.175, 0);
			const panelLight = new THREE.Mesh(new THREE.BoxGeometry(0.7, 0.04, 1.0), new THREE.MeshStandardMaterial({ color: 0xeed8b0, emissive: 0xffe0b0, emissiveIntensity: 2.2 }));
			panelLight.position.set(0, 2.43, 0);
			scene.add(panelLight);
			const lamp = new THREE.PointLight(new THREE.Color().setRGB(0.96, 0.94, 0.86, THREE.SRGBColorSpace), 5, 6, 2);
			lamp.position.set(0, 2.2, 0);
			lamp.castShadow = true;
			scene.add(lamp);
			shot.lamp = lamp;
			other = await Detective.create();
			// The other one at the left of the frame, hat and coat, facing the doors.
			other.root.position.set(0.5, 0, -0.52);
			other.root.rotation.y = Math.PI / 2 + 0.12;
			scene.add(other.root);
		},
		update(t) {
			const shiver = t > DOWN ? Math.exp(-(t - DOWN) * 6) * 0.012 + 0.002 : 0;
			const j = V(fbm1(t * 40, 2) * shiver, fbm1(t * 37, 4) * shiver, 0);
			aimCamera(camera, V(-0.55, 1.6, 0.35).add(j), V(1.2, 1.35, -0.15), { roll: fbm1(t * 20, 6) * shiver * 2 });
			detectiveTorch(other, V(1.1, 0.0, -0.4), { breathe: Math.sin(t * 3), raise: 0.1 });
			shot.lamp.intensity = 5 * (t > DOWN && t < DOWN + 0.08 ? 0.7 : 1);
		},
		look(t) {
			const L = tape({ exposure: 1.4 });
			if (t > LOSE) {
				const k = smoothstep(LOSE, 0.72, t);
				L.roll = k * k * 0.9;
				L.tracking = 0.5 + k * 0.5;
				L.fade = smoothstep(0.62, 0.78, t);
			}
			return L;
		},
		overlay(g, t, size) {
			camcorder(g, t, size, { clock: 3 * 3600 + 52 * 60 + 44, date: "OCT. 27 1993" });
		},
	};
	return shot;
}
