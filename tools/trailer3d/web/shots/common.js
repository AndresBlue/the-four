// What the hotel shots share: a camcorder held by a person (drift, breath,
// steps), the torch as the game has it, and the tape's look.
import * as THREE from "three";
import { fbm1, lerp, clamp } from "../engine/util.js";

const V = (x, y, z) => new THREE.Vector3(x, y, z);

// Drift of a hand-held camera: position (m) and rotation (rad) offsets.
export function handheld(t, { amp = 1, seed = 1, rate = 1 } = {}) {
	const s = t * rate;
	return {
		pos: V(fbm1(s * 0.6, seed) * 0.012 * amp, fbm1(s * 0.5, seed + 3) * 0.01 * amp, fbm1(s * 0.4, seed + 7) * 0.008 * amp),
		yaw: fbm1(s * 0.45, seed + 11) * 0.006 * amp,
		pitch: fbm1(s * 0.5, seed + 13) * 0.005 * amp,
		roll: fbm1(s * 0.35, seed + 17) * 0.007 * amp,
	};
}

// The bob of walking or running: steps per second, how hard.
export function steps(t, { rate = 1.9, amp = 1, phase = 0 } = {}) {
	const p = (t * rate + phase) * Math.PI;
	return {
		pos: V(Math.sin(p) * 0.012 * amp, -Math.abs(Math.sin(p)) * 0.035 * amp, 0),
		roll: Math.sin(p) * 0.012 * amp,
		pitch: Math.abs(Math.cos(p)) * 0.01 * amp,
	};
}

// Points the camera from `pos` at `target`, then adds the small rotations.
export function aimCamera(camera, pos, target, { yaw = 0, pitch = 0, roll = 0 } = {}) {
	camera.position.copy(pos);
	camera.up.set(0, 1, 0);
	camera.lookAt(target);
	camera.rotateY(yaw);
	camera.rotateX(pitch);
	camera.rotateZ(roll);
	camera.updateMatrixWorld();
}

let cookie = null;
// The game's torch pattern (hotel_player.gd beam_pattern()): hot centre, a
// faint reflector ring at about half the radius, soft falloff.
export function torchCookie() {
	if (cookie) return cookie;
	const c = document.createElement("canvas");
	c.width = c.height = 256;
	const g = c.getContext("2d");
	const grad = g.createRadialGradient(128, 128, 0, 128, 128, 128);
	const stops = [[0, 1], [0.22, 0.9], [0.42, 0.62], [0.52, 0.74], [0.62, 0.4], [0.85, 0.1], [1, 0]];
	for (const [o, v] of stops) grad.addColorStop(o, `rgb(${v * 255},${v * 255},${v * 255})`);
	g.fillStyle = grad;
	g.fillRect(0, 0, 256, 256);
	cookie = new THREE.CanvasTexture(c);
	cookie.colorSpace = THREE.NoColorSpace;
	return cookie;
}

// A survivor's torch: (1, 0.9, 0.74), a 32 degree half-angle cone, 24 m.
export function makeTorch(scene, { intensity = 220, angle = 30, penumbra = 0.35, shadow = true, cookie: useCookie = true } = {}) {
	const light = new THREE.SpotLight(new THREE.Color().setRGB(1, 0.9, 0.74, THREE.SRGBColorSpace), intensity, 24, THREE.MathUtils.degToRad(angle), penumbra, 2);
	if (useCookie) light.map = torchCookie();
	light.castShadow = shadow;
	light.shadow.mapSize.set(1024, 1024);
	light.shadow.bias = -0.0004;
	light.shadow.camera.near = 0.1;
	scene.add(light, light.target);
	return light;
}

// Holds the torch the way the player does: in the right hand below the lens,
// aimed where the camera looks some metres ahead, lagging a little.
export function holdTorch(torch, camera, { offset = V(0.24, -0.3, -0.25), ahead = 7, swayT = 0, sway = 1, aimOffset = V(0, 0, 0) } = {}) {
	const hand = offset.clone().applyMatrix4(camera.matrixWorld);
	const fwd = V(0, 0, -1).applyQuaternion(camera.quaternion);
	const up = V(0, 1, 0).applyQuaternion(camera.quaternion);
	const right = V(1, 0, 0).applyQuaternion(camera.quaternion);
	const aim = camera.position.clone().add(fwd.multiplyScalar(ahead)).add(aimOffset);
	aim.add(right.multiplyScalar(fbm1(swayT * 0.8, 91) * 0.25 * sway)).add(up.multiplyScalar(fbm1(swayT * 0.7, 97) * 0.18 * sway));
	torch.position.copy(hand);
	torch.target.position.copy(aim);
	torch.target.updateMatrixWorld();
}

// The tape look for the hotel footage (vhs a little above the game's 0.45 so
// it reads on a big screen), with per-shot overrides.
export function tape(extra = {}) {
	return { kind: "tape", exposure: 1.0, bloom: 0.05, halation: 0.35, contrast: 1.1, saturation: 0.88, vhs: 0.5, grain: 0.24, chromatic: 0.12, scanlines: 0.32, ...extra };
}

export { V, lerp, clamp };
