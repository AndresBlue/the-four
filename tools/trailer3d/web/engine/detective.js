// The game's "Detective Masculino" (assets/players/detective): a Fuse OBJ with
// no skeleton, standing in a T pose, in centimetres, facing +z. The game bakes
// its arms down on import (tools/avatars/build_detective.gd); the same bake is
// done here, and a few joints are cut into it by region -- shoulders, elbows,
// hips, knees, the waist -- so it can hold a torch out, walk and run. Seen in
// the dark, in a hat and a long coat, it is the guests' silhouette.
import * as THREE from "three";
import { OBJLoader } from "three/addons/loaders/OBJLoader.js";
import { repo } from "./assets.js";
import { smoothstep } from "./util.js";

const DIR = "assets/players/detective/";
const PARTS = { Body: "Body", Glove: "Glove", Top: "Top", Bottom: "Bottom", Shoes: "Shoes", Hat: "Hat", Eyewear: "Eyewear" };
let source = null;

async function loadSource() {
	const obj = await new OBJLoader().loadAsync(repo(DIR + "model.obj"));
	const loader = new THREE.TextureLoader();
	const materials = {};
	const material = async (name) => {
		const part = PARTS[name] ?? "Body";
		if (materials[part]) return materials[part];
		const [map, normalMap] = await Promise.all([
			loader.loadAsync(repo(`${DIR}textures/detective_${part}_diffuse.png`)),
			loader.loadAsync(repo(`${DIR}textures/detective_${part}_normal.png`)).catch(() => null),
		]);
		map.colorSpace = THREE.SRGBColorSpace;
		map.anisotropy = 8;
		materials[part] = new THREE.MeshStandardMaterial({ map, normalMap, roughness: part === "Shoes" ? 0.5 : 0.85, metalness: 0 });
		return materials[part];
	};
	const meshes = [];
	for (const child of obj.children) {
		if (!child.isMesh || /Eyelash/i.test(child.name)) continue;
		const names = (Array.isArray(child.material) ? child.material : [child.material]).map((m) => m.name);
		const mats = await Promise.all(names.map(material));
		meshes.push({ geometry: child.geometry, material: Array.isArray(child.material) ? mats : mats[0] });
	}
	return meshes;
}

const S = 0.01;
// Joints, in the T pose (cm). Right is -x: it faces +z.
const SHOULDER = (s) => new THREE.Vector3(s * 19, 143, -5);
const ELBOW = (s) => new THREE.Vector3(s * 50, 136, -7);
const HAND = (s) => new THREE.Vector3(s * 84, 134, -4);
const HIP = (s) => new THREE.Vector3(s * 9, 95, -1);
const KNEE = (s) => new THREE.Vector3(s * 9, 50, -2);
const WAIST = new THREE.Vector3(0, 100, -2);
const X = new THREE.Vector3(1, 0, 0);
const Y = new THREE.Vector3(0, 1, 0);

// The game's bake: each arm swung 73 degrees down about the shoulder.
function relax(v, s, w) {
	const q = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 0, 1), -s * THREE.MathUtils.degToRad(73) * w);
	return v.clone().sub(new THREE.Vector3(s * 19, 143, 0)).applyQuaternion(q).add(new THREE.Vector3(s * 19, 143, 0));
}

export class Detective {
	static async create() {
		const d = new Detective();
		await d.load();
		return d;
	}

	async load() {
		source ??= loadSource();
		const meshes = await source;
		this.root = new THREE.Group();
		this.model = new THREE.Group();
		this.model.scale.setScalar(S);
		this.root.add(this.model);
		this.parts = [];
		for (const m of meshes) {
			const geometry = m.geometry.clone();
			const mesh = new THREE.Mesh(geometry, m.material);
			mesh.castShadow = true;
			mesh.receiveShadow = true;
			mesh.frustumCulled = false;
			this.model.add(mesh);
			const pos = geometry.attributes.position;
			const nor = geometry.attributes.normal;
			const n = pos.count;
			const rest = new Float32Array(pos.array);
			const restN = nor ? new Float32Array(nor.array) : null;
			// Region weights, from the T pose.
			const arm = new Float32Array(n);
			const fore = new Float32Array(n);
			const leg = new Float32Array(n);
			const shin = new Float32Array(n);
			const upper = new Float32Array(n);
			const side = new Int8Array(n);
			for (let i = 0; i < n; i++) {
				const x = rest[i * 3];
				const y = rest[i * 3 + 1];
				side[i] = x >= 0 ? 1 : -1;
				arm[i] = smoothstep(20, 36, Math.abs(x)) * smoothstep(105, 125, y);
				fore[i] = arm[i] * smoothstep(44, 56, Math.abs(x));
				leg[i] = (1 - smoothstep(86, 100, y));
				shin[i] = 1 - smoothstep(44, 56, y);
				upper[i] = smoothstep(92, 112, y);
			}
			// The relaxed rest, as the game shows it.
			const relaxed = new Float32Array(rest.length);
			const relaxedN = restN ? new Float32Array(restN.length) : null;
			const v = new THREE.Vector3();
			for (let i = 0; i < n; i++) {
				v.fromArray(rest, i * 3);
				relax(v, side[i], arm[i]).toArray(relaxed, i * 3);
				if (relaxedN) {
					const q = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 0, 1), -side[i] * THREE.MathUtils.degToRad(73) * arm[i]);
					v.fromArray(restN, i * 3).applyQuaternion(q).toArray(relaxedN, i * 3);
				}
			}
			this.parts.push({ mesh, pos, nor, n, relaxed, relaxedN, arm, fore, leg, shin, upper, side });
		}
		this.joints = {};
		for (const s of [-1, 1]) {
			this.joints[s] = { shoulder: SHOULDER(s), elbow: relax(ELBOW(s), s, 1), hand: relax(HAND(s), s, 1), hip: HIP(s), knee: KNEE(s) };
		}
		this.pose({});
		return this;
	}

	// Pose it. Arms: { R|L: { upper: dir, fore: dir } } as unit directions in the
	// model's frame (+z forward), or null to hang. Legs: { R|L: { hip, knee } }
	// in radians (hip forward positive, knee bent positive). Lean forward and
	// twist of the upper body in radians.
	pose({ arms = {}, legs = {}, lean = 0, twist = 0 } = {}) {
		const rot = {};
		for (const [key, s] of [["R", -1], ["L", 1]]) {
			const J = this.joints[s];
			const hang = J.elbow.clone().sub(J.shoulder).normalize();
			const hangFore = J.hand.clone().sub(J.elbow).normalize();
			const a = arms[key];
			const qu = a?.upper ? new THREE.Quaternion().setFromUnitVectors(hang, a.upper.clone().normalize()) : new THREE.Quaternion();
			// The forearm turns first, in the hanging arm's frame, so that the
			// shoulder's turn then carries it onto `fore`.
			const foreRel = a?.fore ? a.fore.clone().normalize().applyQuaternion(qu.clone().invert()) : null;
			const qf = foreRel ? new THREE.Quaternion().setFromUnitVectors(hangFore, foreRel) : new THREE.Quaternion();
			const elbow = J.elbow.clone().sub(J.shoulder).applyQuaternion(qu).add(J.shoulder);
			const l = legs[key] ?? { hip: 0, knee: 0 };
			rot[s] = {
				qu, qf, elbow, shoulder: J.shoulder,
				qh: new THREE.Quaternion().setFromAxisAngle(X, -(l.hip ?? 0)),
				qk: new THREE.Quaternion().setFromAxisAngle(X, l.knee ?? 0),
				hip: J.hip,
				knee: J.knee,
			};
		}
		const qBody = new THREE.Quaternion().setFromAxisAngle(Y, twist).multiply(new THREE.Quaternion().setFromAxisAngle(X, lean));
		const I = new THREE.Quaternion();
		const v = new THREE.Vector3();
		const nv = new THREE.Vector3();
		const q = new THREE.Quaternion();
		const turn = (vec, normal, pivot, quat, w) => {
			if (w <= 0) return;
			if (w >= 1) q.copy(quat);
			else q.copy(I).slerp(quat, w);
			vec.sub(pivot).applyQuaternion(q).add(pivot);
			if (normal) normal.applyQuaternion(q);
		};
		for (const p of this.parts) {
			const out = p.pos.array;
			const outN = p.nor ? p.nor.array : null;
			for (let i = 0; i < p.n; i++) {
				v.fromArray(p.relaxed, i * 3);
				const hasN = !!outN;
				if (hasN) nv.fromArray(p.relaxedN, i * 3);
				const r = rot[p.side[i]];
				// Legs first (knee, then hip), from the side the vertex is on, blended
				// across the middle so the coat shears rather than tears.
				const x = p.relaxed[i * 3];
				const lw = p.leg[i];
				if (lw > 0) {
					const mix = smoothstep(-6, 6, x);
					for (const [s, share] of [[1, mix], [-1, 1 - mix]]) {
						if (share <= 0) continue;
						const R = rot[s];
						turn(v, hasN ? nv : null, R.knee, R.qk, lw * p.shin[i] * share);
						turn(v, hasN ? nv : null, R.hip, R.qh, lw * share);
					}
				}
				// Arms: forearm about the elbow, then the whole arm about the shoulder.
				const aw = p.arm[i];
				if (aw > 0) {
					const J = this.joints[p.side[i]];
					turn(v, hasN ? nv : null, J.elbow, r.qf, p.fore[i]);
					turn(v, hasN ? nv : null, r.shoulder, r.qu, aw);
				}
				// The upper body leans and twists at the waist.
				turn(v, hasN ? nv : null, WAIST, qBody, p.upper[i]);
				v.toArray(out, i * 3);
				if (hasN) nv.toArray(outN, i * 3);
			}
			p.pos.needsUpdate = true;
			if (p.nor) p.nor.needsUpdate = true;
		}
		// Where the hands are now, in the model's frame (cm).
		this.hands = {};
		for (const [key, s] of [["R", -1], ["L", 1]]) {
			const r = rot[s];
			const J = this.joints[s];
			const hand = J.hand.clone().sub(J.elbow).applyQuaternion(r.qf).add(J.elbow).sub(r.shoulder).applyQuaternion(r.qu).add(r.shoulder).sub(WAIST).applyQuaternion(qBody).add(WAIST);
			const elbow = r.elbow.clone().sub(WAIST).applyQuaternion(qBody).add(WAIST);
			this.hands[key] = { hand, dir: hand.clone().sub(elbow).normalize() };
		}
		this.root.updateMatrixWorld(true);
	}

	// A world point from the model's frame (cm).
	world(local) {
		this.root.updateMatrixWorld(true);
		return local.clone().applyMatrix4(this.model.matrixWorld);
	}

	// A world point into the model's frame (cm).
	local(world) {
		this.root.updateMatrixWorld(true);
		return world.clone().applyMatrix4(this.model.matrixWorld.clone().invert());
	}
}

// A guest with a torch out toward `aim` (world), the other arm hanging.
// Returns the world position of the hand and the direction the torch points.
export function detectiveTorch(D, aim, { breathe = 0, lean = 0.04, side = "R", raise = 0.55 } = {}) {
	const s = side === "R" ? -1 : 1;
	const J = D.joints[s];
	// First unposed, to measure from the shoulder.
	const target = D.local(aim);
	const dir = target.clone().sub(J.shoulder).normalize();
	const down = new THREE.Vector3(0, -1, 0);
	const upper = down.clone().lerp(dir, raise).normalize();
	D.pose({ arms: { [side]: { upper, fore: dir } }, lean: lean + breathe * 0.01 });
	const h = D.hands[side];
	const hand = D.world(h.hand);
	const tip = D.world(h.hand.clone().add(h.dir.clone().multiplyScalar(10)));
	return { hand, dir: tip.sub(hand).normalize() };
}

// A guest running: `phase` in radians runs the stride.
export function detectiveRun(D, phase, { lean = 0.2, stride = 0.62 } = {}) {
	const s = Math.sin(phase);
	const legs = {
		L: { hip: stride * s, knee: 0.25 + 0.75 * Math.max(0, -s) + 0.2 * Math.max(0, s) },
		R: { hip: -stride * s, knee: 0.25 + 0.75 * Math.max(0, s) + 0.2 * Math.max(0, -s) },
	};
	const arm = (k) => ({ upper: new THREE.Vector3(0, -1, 0.8 * k).normalize(), fore: new THREE.Vector3(0, -0.2 + 0.3 * Math.max(0, k), 1).normalize() });
	D.pose({ arms: { L: arm(-s), R: arm(s) }, legs, lean, twist: s * 0.12 });
}
