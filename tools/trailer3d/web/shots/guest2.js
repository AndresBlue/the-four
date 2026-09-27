// GUEST 02 — every live screen is a door. A dark room; click, the set comes
// on and its snow lights the room blue. In the snow something comes up to
// the glass: the mask, filling the picture, the picture breaking up. A flash
// of static: it is out, standing in front of the set. Another: it is over
// the lens.
import * as THREE from "three";
import { Kit } from "../engine/kit.js";
import { hotelRoom, tvSet } from "../engine/sets.js";
import { Locust } from "../engine/locust.js";
import * as P from "../engine/props.js";
import { channelWave } from "../engine/screens.js";
import { Volumetrics } from "../engine/volumetric.js";
import { camcorder, burnIn, typed } from "../engine/osd.js";
import { clamp, smooth, smoothstep, lerp } from "../engine/util.js";
import { V, handheld, aimCamera, makeTorch, holdTorch, tape } from "./common.js";
import { makeBroadcast } from "./archive.js";

export const CLICK = 0.5;
// In the picture: it comes out of the snow and up to the glass.
export const INSIDE = [1.0, 1.95];
// The flashes of static; after each, it is further out.
export const FLASHES = [1.95, 2.4, 2.8, 3.35];
export const OUT = 2.8;
export const CLOSER = 3.35;

export function create(ctx) {
	const scene = new THREE.Scene();
	const camera = new THREE.PerspectiveCamera(50, 4 / 3, 0.05, 60);
	let locust;
	let a;
	let face;
	let torch;
	let broadcast;
	const shot = {
		scene, camera, frame: "tape", samples: 32, shutter: 0.5,
		async setup() {
			ctx.renderer.localClippingEnabled = true;
			const kit = await new Kit(scene).load();
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
			a.group.updateMatrixWorld(true);
			const box = new THREE.Box3().setFromObject(a.screen);
			face = new THREE.Vector3((box.min.x + box.max.x) / 2, (box.min.y + box.max.y) / 2, box.max.z);
			shot.screenBox = box;
			locust = await Locust.create();
			scene.add(locust.root);
			// What the set shows: the creature in its corner, coming to the glass.
			broadcast = await makeBroadcast(ctx);
			a.mat.uniforms.image.value = broadcast.rt.texture;
			// The guest's torch, low and shaking, on the set.
			torch = makeTorch(scene, { intensity: 22, angle: 24 });
			shot.volumetrics = new Volumetrics(ctx.renderer, { density: 0.012, noise: 0.5, maxDist: 12, steps: 24 });
			shot.volumetrics.addSpot(a.glow, { strength: 0.08 });
			shot.volumetrics.addSpot(torch, { strength: 0.12 });
		},
		beforeRender() {
			if (!shot.inPicture) return;
			const r = ctx.renderer;
			r.setRenderTarget(broadcast.rt);
			r.setClearColor(0x000000, 1);
			r.clear();
			r.render(broadcast.scene, broadcast.camera);
		},
		update(t) {
			const wave = channelWave(t);
			const hh = handheld(t, { amp: 1.2, seed: 21 });
			// Creeping in toward the set as it builds; backing off when it is out.
			const near = smoothstep(CLICK, FLASHES[0], t) * 0.35 - smoothstep(OUT, OUT + 0.4, t) * 0.5;
			const eye = V(0.2, 1.5, -1.0 - near).add(hh.pos);
			camera.position.copy(eye);
			const on = t >= CLICK;
			const k = clamp((t - CLICK) / 0.35);
			const flash = FLASHES.some((f) => t >= f && t < f + 0.07);
			const swell = smoothstep(CLICK + 0.3, FLASHES[0], t);
			const u = a.mat.uniforms;
			u.power.value = on ? k : 0;
			u.time.value = t;
			u.unstable.value = swell * 0.6 + (flash ? 1 : 0) + smoothstep(FLASHES[0], OUT, t) * 0.6;
			u.brightness.value = flash ? 2.4 : 0.85 + swell * 0.3;
			// The picture: snow, then the creature out of it and up to the glass;
			// once it is out, snow again.
			shot.inPicture = on && t < OUT;
			const seen = smoothstep(INSIDE[0], INSIDE[1], t);
			u.image_amount.value = shot.inPicture ? 0.25 + seen * 0.65 : 0;
			u.static_amount.value = shot.inPicture ? 1 - seen * 0.55 : 1;
			if (shot.inPicture) posePicture(broadcast, t);
			a.glow.intensity = on ? 14 * smooth(k) * wave * (flash ? 3 : 1) : 0;
			a.fill.intensity = on ? 2.2 * smooth(k) * wave * (flash ? 3 : 1) : 0;
			// In the room: out in front of the set; at the last flash, over the lens.
			locust.root.visible = t >= OUT;
			if (t >= OUT) poseOut(locust, face, t, eye, t >= CLOSER);
			// The lens on the set; once it is out, up to its mask.
			const mask = t >= OUT ? locust.point("Head1").add(V(0, 0.2, 0)) : V(0.35, 1.15, -3.6);
			aimCamera(camera, eye, mask, { yaw: hh.yaw, pitch: hh.pitch, roll: hh.roll });
			holdTorch(torch, camera, { ahead: 2.2, swayT: t * 1.5, sway: 0.6, aimOffset: V(0, 0.1, 0) });
			torch.intensity = 22;
		},
		look(t) {
			// Night gain, kept low: the room stays dark round the set.
			const L = tape({ exposure: 1.45, whiteBalance: [0.96, 1.0, 1.08], grain: 0.34, halation: 0.15, bloom: 0.035 });
			for (const f of FLASHES) {
				if (t >= f - 0.02 && t < f + 0.09) {
					L.snow = 0.85;
					L.tracking = 1;
					L.jerk = 0.6;
					L.exposure = 3.2;
				}
			}
			if (t >= OUT && t < OUT + 0.15) L.threat_glitch = 0.6;
			return L;
		},
		overlay(g, t, size) {
			camcorder(g, t, size, { clock: 2 * 3600 + 31 * 60 + 9, date: "OCT. 27 1993", focus: t < CLICK + 0.1 ? 1 - smoothstep(CLICK, CLICK + 0.1, t) : 0, word: "TURN ON" });
			if (t < 1.4) burnIn(g, [typed("TAPE 81 · GUEST 02", t, 0.05, 40)], size, { alpha: 1 - smoothstep(1.1, 1.4, t) });
		},
	};
	return shot;
}

// In the picture: out of the dark of its corner, up to the glass.
function posePicture(b, t) {
	const L = b.locust;
	const near = smoothstep(INSIDE[0], FLASHES[0] + 0.3, t);
	L.root.position.set(0.06, 0, lerp(-0.9, 0.45, near));
	L.root.rotation.set(0, 0, 0);
	L.reset();
	L.stand({ hunch: 0.2 + near * 0.2 });
	L.hangArms();
	L.turn("Head1", [0, 0, 1], -0.2 + Math.sin(t * 23) * 0.03 * near);
	L.turn("Head1", [1, 0, 0], 0.12 + near * 0.1);
	const head = L.point("Head1");
	b.camera.lookAt(head.x, head.y + 0.22, head.z);
}

// Out: standing in front of the set, stooped, the mask turned to the lens;
// then right over it.
function poseOut(L, face, t, lens, close) {
	const head = L.bones.Head1;
	L.root.rotation.set(0, 0, 0);
	L.root.position.set(0, 0, 0);
	L.reset();
	L.root.updateMatrixWorld(true);
	const rest = head.getWorldQuaternion(new THREE.Quaternion());
	L.stand({ duck: 0.6, hunch: close ? 0.75 : 0.45 });
	if (close) L.poseArms({ attack: 1 });
	else L.hangArms();
	L.root.position.set(face.x + 0.1, 0, close ? lens.z - 1.5 : face.z + 0.9);
	L.root.updateMatrixWorld(true);
	const look = lens.clone().sub(L.point("Head1")).normalize();
	const turnTo = new THREE.Quaternion().setFromUnitVectors(V(0, 0, 1), look);
	const tilt = new THREE.Quaternion().setFromAxisAngle(look, 0.3 + Math.sin(t * 29) * 0.04);
	const wanted = tilt.multiply(turnTo).multiply(rest);
	const parent = head.parent.getWorldQuaternion(new THREE.Quaternion());
	head.quaternion.copy(parent.invert().multiply(wanted));
	L.root.updateMatrixWorld(true);
}
