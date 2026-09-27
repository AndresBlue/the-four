// A survivor: the game's "Detective Femenino" (assets/players/detective_woman,
// Debra by Zukomazi, a Mixamo rig), posed bone by bone in skeleton space like
// the creature. Used for hands and for the other guests' silhouettes.
import * as THREE from "three";
import { FBXLoader } from "three/addons/loaders/FBXLoader.js";
import { repo } from "./assets.js";
import { clamp } from "./util.js";

const M = "mixamorig";

export class Survivor {
	static async create() {
		const s = new Survivor();
		await s.load();
		return s;
	}

	async load() {
		this.root = new THREE.Group();
		// A fresh load per survivor: cloning this file's skins misbinds them.
		const manager = new THREE.LoadingManager();
		const loaded = new Promise((resolve) => { manager.onLoad = resolve; });
		this.model = await new FBXLoader(manager).loadAsync(repo("assets/players/detective_woman/model.fbx"));
		// Its embedded textures arrive after the file: wait for them.
		await loaded;
		this.model.scale.setScalar(0.01);
		this.root.add(this.model);
		this.meshes = [];
		this.model.traverse((o) => {
			if (!o.isMesh) return;
			this.meshes.push(o);
			o.castShadow = true;
			o.receiveShadow = true;
			o.frustumCulled = false;
			const cutout = /Hair|Eyelash/i.test(o.name);
			const convert = (m) => {
				const std = new THREE.MeshStandardMaterial({ map: m.map ?? null, color: 0xffffff, roughness: /Shoes|Eyewear/i.test(o.name) ? 0.45 : 0.8, metalness: 0, alphaTest: cutout ? 0.4 : 0, transparent: false, side: cutout ? THREE.DoubleSide : THREE.FrontSide });
				if (std.map) std.map.colorSpace = THREE.SRGBColorSpace;
				std.name = m.name;
				return std;
			};
			o.material = Array.isArray(o.material) ? o.material.map(convert) : convert(o.material);
		});
		// The FBX nests a zero-offset copy of each bone inside it (a node per skin
		// cluster). The topmost bone of each name is the real joint: posing it
		// carries its copies, so only those are posed.
		this.bones = {};
		this.model.traverse((o) => {
			if (!o.isBone) return;
			const key = o.name.startsWith(M) ? o.name.slice(M.length) : o.name;
			if (!this.bones[key]) this.bones[key] = o;
		});
		this.skeletonRoot = this.bones.Hips.parent;
		this.rest = {};
		for (const [k, b] of Object.entries(this.bones)) this.rest[k] = { q: b.quaternion.clone(), p: b.position.clone() };
		return this;
	}

	reset() {
		for (const [k, b] of Object.entries(this.bones)) {
			b.quaternion.copy(this.rest[k].q);
			b.position.copy(this.rest[k].p);
		}
	}

	worldQ(bone) {
		const q = new THREE.Quaternion();
		const chain = [];
		for (let b = bone; b && b !== this.skeletonRoot; b = b.parent) chain.push(b);
		for (let i = chain.length - 1; i >= 0; i--) q.multiply(chain[i].quaternion);
		return q;
	}

	setWorldQ(bone, wanted) {
		const parentQ = bone.parent === this.skeletonRoot ? new THREE.Quaternion() : this.worldQ(bone.parent);
		bone.quaternion.copy(parentQ.invert().multiply(wanted)).normalize();
	}

	skeletonPoint(bone) {
		const m = new THREE.Matrix4();
		const chain = [];
		for (let b = bone; b && b !== this.skeletonRoot; b = b.parent) chain.push(b);
		for (let i = chain.length - 1; i >= 0; i--) {
			chain[i].updateMatrix();
			m.multiply(chain[i].matrix);
		}
		return new THREE.Vector3().setFromMatrixPosition(m);
	}

	turn(name, axis, angle) {
		const bone = this.bones[name];
		const q = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(...axis).normalize(), angle);
		this.setWorldQ(bone, q.multiply(this.worldQ(bone)));
	}

	aim(name, child, direction) {
		const bone = this.bones[name];
		const cur = this.worldQ(bone);
		// Measured between the joints: copies may sit between a bone and its child.
		const offset = this.skeletonPoint(this.bones[child]).sub(this.skeletonPoint(bone)).normalize();
		const dir = new THREE.Vector3(...direction).normalize();
		if (offset.dot(dir) > 0.99999) return;
		this.setWorldQ(bone, new THREE.Quaternion().setFromUnitVectors(offset, dir).multiply(cur));
	}

	// World point of a bone.
	point(name) {
		this.root.updateMatrixWorld(true);
		return this.bones[name].getWorldPosition(new THREE.Vector3());
	}

	toSkeleton(world) {
		this.root.updateMatrixWorld(true);
		return world.clone().applyMatrix4(this.skeletonRoot.matrixWorld.clone().invert());
	}

	// Two-bone arm IK: the wrist onto a world target, elbow toward `pole` (skeleton space).
	reachWrist(side, target, pole) {
		const S = side === "R" ? "Right" : "Left";
		const upper = this.bones[`${S}Arm`];
		const fore = this.bones[`${S}ForeArm`];
		const hand = this.bones[`${S}Hand`];
		const shoulder = this.skeletonPoint(upper);
		const a = this.skeletonPoint(fore).distanceTo(shoulder);
		const b = this.skeletonPoint(hand).distanceTo(this.skeletonPoint(fore));
		const tip = this.toSkeleton(target);
		const span = tip.clone().sub(shoulder);
		const d = clamp(span.length(), Math.abs(a - b) + 0.001, a + b - 0.001);
		const direction = span.clone().normalize();
		const bend = new THREE.Vector3(...pole).normalize();
		const sideAxis = bend.clone().sub(direction.clone().multiplyScalar(bend.dot(direction))).normalize();
		const along = (a * a - b * b + d * d) / (2 * d);
		const height = Math.sqrt(Math.max(a * a - along * along, 0));
		const elbow = shoulder.clone().add(direction.clone().multiplyScalar(along)).add(sideAxis.multiplyScalar(height));
		this.aim(`${S}Arm`, `${S}ForeArm`, elbow.clone().sub(shoulder).toArray());
		this.aim(`${S}ForeArm`, `${S}Hand`, shoulder.clone().add(direction.multiplyScalar(d)).sub(elbow).toArray());
	}

	// Fingers of one hand curled by `curl` (0 flat, 1 fist); `point` keeps the index straight.
	fingers(side, curl, { point = false, thumb = 0.3, spread = 0 } = {}) {
		const S = side === "R" ? "Right" : "Left";
		const hand = this.bones[`${S}Hand`];
		const hq = this.worldQ(hand);
		// Curl axis: across the palm, from the hand's own frame.
		const across = new THREE.Vector3(1, 0, 0).applyQuaternion(hq);
		for (const f of ["Index", "Middle", "Ring", "Pinky"]) {
			const c = point && f === "Index" ? curl * 0.1 : curl;
			for (let i = 1; i <= 3; i++) {
				const name = `${S}Hand${f}${i}`;
				if (!this.bones[name]) continue;
				this.turn(name, across.toArray(), (side === "R" ? 1 : -1) * c * (i === 1 ? 1.2 : 1.4));
			}
		}
		for (let i = 1; i <= 3; i++) {
			const name = `${S}HandThumb${i}`;
			if (this.bones[name]) this.turn(name, across.toArray(), (side === "R" ? 1 : -1) * thumb * 0.5);
		}
	}
}

// A guest holding a torch: the left arm hangs, the right hand is held out at
// chest height toward `aim` (world), the head looking the same way. Returns
// the world position of the hand and the direction the torch points.
export function poseTorch(S, aim, { reachOut = 0.42, drop = 0.18, breathe = 0 } = {}) {
	S.reset();
	S.turn("Spine1", [1, 0, 0], 0.04 + breathe * 0.01);
	S.aim("LeftArm", "LeftForeArm", [0.12, -1, 0.05]);
	S.aim("LeftForeArm", "LeftHand", [0.05, -1, 0.15]);
	S.root.updateMatrixWorld(true);
	const shoulder = S.point("RightArm");
	const dir = aim.clone().sub(shoulder).normalize();
	const wrist = shoulder.clone().add(dir.clone().multiplyScalar(reachOut)).add(new THREE.Vector3(0, -drop, 0));
	S.reachWrist("R", wrist, [0.3, -1, -0.4]);
	// The head toward what the torch finds.
	const head = S.point("Head");
	const look = S.toSkeleton(aim).sub(S.toSkeleton(head)).normalize();
	const fwd = new THREE.Vector3(0, 0, 1);
	const axis = fwd.clone().cross(look);
	const angle = Math.min(fwd.angleTo(look), 1.0);
	if (axis.length() > 1e-3) {
		S.turn("Neck", axis.normalize().toArray(), angle * 0.4);
		S.turn("Head", axis.toArray(), angle * 0.4);
	}
	S.fingers("R", 0.85, { thumb: 0.6 });
	S.root.updateMatrixWorld(true);
	return { hand: S.point("RightHand"), dir: aim.clone().sub(S.point("RightHand")).normalize() };
}

// A guest running, seen for a moment: legs striding, arms pumping, leaning
// into it. `phase` in radians runs the stride.
export function poseRun(S, phase, { lean = 0.22 } = {}) {
	S.reset();
	const s = Math.sin(phase);
	S.turn("Hips", [1, 0, 0], lean * 0.4);
	S.turn("Spine", [1, 0, 0], lean * 0.5);
	S.turn("Spine1", [0, 1, 0], s * 0.12);
	S.aim("LeftUpLeg", "LeftLeg", [0.04, -1, 0.75 * s]);
	S.aim("RightUpLeg", "RightLeg", [-0.04, -1, -0.75 * s]);
	S.aim("LeftLeg", "LeftFoot", [0, -1, 0.35 * s - 0.55 * Math.max(0, -s) - 0.2]);
	S.aim("RightLeg", "RightFoot", [0, -1, -0.35 * s - 0.55 * Math.max(0, s) - 0.2]);
	S.aim("LeftArm", "LeftForeArm", [0.28, -1, -0.65 * s]);
	S.aim("RightArm", "RightForeArm", [-0.28, -1, 0.65 * s]);
	S.aim("LeftForeArm", "LeftHand", [-0.1, -0.15, 1]);
	S.aim("RightForeArm", "RightHand", [0.1, -0.15, 1]);
	S.turn("Head", [1, 0, 0], -lean * 0.6);
	S.fingers("L", 0.8, { thumb: 0.5 });
	S.fingers("R", 0.8, { thumb: 0.5 });
	S.root.updateMatrixWorld(true);
}
