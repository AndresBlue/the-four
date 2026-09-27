// The Locust: the game's model (assets/enemies/locust.glb, by Doumty) at the
// game's scale (1.95, about 2.9 m) with its reference look (ink-black body,
// pale mask; game/enemies/locust/locust_look.gd), posed bone by bone the way
// the game's poser does it (game/enemies/locust/locust_poser.gd): every turn
// and aim in skeleton space, applied in order. The model faces +Z.
import * as THREE from "three";
import { gltfCopy, texture } from "./assets.js";
import { clamp, lerp } from "./util.js";

export const SCALE = 1.95;
const B = "ValveBipedBip01_";
export const BLADE = 0.36;

let lookCache = null;
async function referenceMaterial(original) {
	if (!lookCache) {
		const [albedo, phong, normal] = await Promise.all([
			texture("assets/enemies/locust_reference_basecolor.png", { srgb: true, flipY: false, repeat: false }),
			texture("assets/enemies/locust_locust_by-doumty_phong_tex.png", { flipY: false, repeat: false }),
			texture("assets/enemies/locust_locust_by-doumty_normal_tex.png", { flipY: false, repeat: false }),
		]);
		lookCache = { albedo, phong, normal };
	}
	// locust_reference_material.tres takes metal and roughness from the phong
	// map, which makes the ink glossy as chrome under a torch held close; the
	// picture it is modelled on is matte ink, so it is kept matte here.
	const m = new THREE.MeshStandardMaterial({
		map: lookCache.albedo,
		metalness: 0,
		roughness: 0.72,
		normalMap: lookCache.normal,
		side: THREE.DoubleSide,
	});
	if (original?.normalScale) m.normalScale.copy(original.normalScale);
	return m;
}

export class Locust {
	// Black as oil: the greys of its body pushed down to black, the pale of the
	// mask kept, and a wet clear coat over all of it.
	oil() {
		for (const m of this.meshes) {
			const old = m.material;
			if (!old || old.name === "locust_fibers_mat") continue;
			const oil = new THREE.MeshPhysicalMaterial({
				map: old.map ?? null, normalMap: old.normalMap ?? null, color: old.color?.clone() ?? new THREE.Color(1, 1, 1),
				metalness: 0, roughness: 0.28, clearcoat: 1, clearcoatRoughness: 0.08, side: old.side ?? THREE.FrontSide,
			});
			if (old.normalScale) oil.normalScale.copy(old.normalScale);
			oil.onBeforeCompile = (sh) => {
				sh.fragmentShader = sh.fragmentShader.replace("#include <map_fragment>", "#include <map_fragment>\n\tfloat lum = dot(diffuseColor.rgb, vec3(0.3, 0.59, 0.11));\n\tdiffuseColor.rgb *= mix(0.25, 1.0, smoothstep(0.03, 0.09, lum));");
			};
			if (old.name === "locust_black") oil.color.multiplyScalar(0.4);
			oil.name = old.name;
			m.material = oil;
		}
		return this;
	}

	static async create({ oil = true } = {}) {
		const l = new Locust();
		await l.load();
		return oil ? l.oil() : l;
	}

	async load() {
		this.root = new THREE.Group();
		this.model = await gltfCopy("assets/enemies/locust.glb");
		this.model.scale.setScalar(SCALE);
		this.root.add(this.model);
		this.bones = {};
		this.meshes = [];
		const replace = [];
		this.model.traverse((o) => {
			if (o.isBone) this.bones[o.name.startsWith(B) ? o.name.slice(B.length) : o.name] = o;
			if (o.isMesh) {
				this.meshes.push(o);
				o.castShadow = true;
				o.receiveShadow = true;
				o.frustumCulled = false;
				if (o.material?.name === "locust_mat") replace.push(o);
				if (o.material?.name === "locust_black") {
					o.material.roughness = 0.88;
					if ("specularIntensity" in o.material) o.material.specularIntensity = 0.5;
				}
				if (o.material?.name === "locust_fibers_mat") {
					o.material.depthWrite = false;
					o.castShadow = false;
				}
			}
		});
		for (const o of replace) o.material = await referenceMaterial(o.material);
		// The armature node: skeleton space is this node's space.
		this.skeletonRoot = this.bones.Pelvis.parent;
		this.rest = {};
		for (const [name, bone] of Object.entries(this.bones)) this.rest[name] = { q: bone.quaternion.clone(), p: bone.position.clone() };
		this.reset();
		return this;
	}

	reset() {
		for (const [name, bone] of Object.entries(this.bones)) {
			bone.quaternion.copy(this.rest[name].q);
			bone.position.copy(this.rest[name].p);
		}
	}

	// Rotation of a bone in skeleton space.
	worldQ(bone) {
		const q = new THREE.Quaternion();
		const chain = [];
		for (let b = bone; b && b !== this.skeletonRoot; b = b.parent) chain.push(b);
		for (let i = chain.length - 1; i >= 0; i--) q.multiply(chain[i].quaternion);
		return q;
	}

	// Position of a bone's origin in skeleton space.
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

	setWorldQ(bone, wanted) {
		const parentQ = bone.parent === this.skeletonRoot ? new THREE.Quaternion() : this.worldQ(bone.parent);
		bone.quaternion.copy(parentQ.invert().multiply(wanted)).normalize();
	}

	// locust_poser.turn: a turn about a skeleton-space axis.
	turn(name, axis, angle) {
		const bone = this.bones[name];
		const q = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(...axis).normalize(), angle);
		this.setWorldQ(bone, q.multiply(this.worldQ(bone)));
	}

	// locust_poser.aim: the bone turns so its child lies along `direction`.
	aim(name, child, direction) {
		const bone = this.bones[name];
		const cur = this.worldQ(bone);
		const offset = this.bones[child].position.clone().applyQuaternion(cur).normalize();
		const dir = new THREE.Vector3(...direction).normalize();
		if (offset.dot(dir) > 0.99999) return;
		const r = new THREE.Quaternion().setFromUnitVectors(offset, dir);
		this.setWorldQ(bone, r.multiply(cur));
	}

	// World position of a bone as posed.
	point(name) {
		this.root.updateMatrixWorld(true);
		return this.bones[name].getWorldPosition(new THREE.Vector3());
	}

	// locust_poser.reach: the blade tip (BLADE past the hand) onto a world point.
	reach(side, target, pole, blade = BLADE) {
		this.root.updateMatrixWorld(true);
		const inv = this.skeletonRoot.matrixWorld.clone().invert();
		const tip = target.clone().applyMatrix4(inv);
		const upperRest = this.restPoint(`${side}_UpperArm`);
		const foreRest = this.restPoint(`${side}_Forearm`);
		const handRest = this.restPoint(`${side}_Hand`);
		const a = upperRest.distanceTo(foreRest);
		const b = foreRest.distanceTo(handRest) + blade;
		const shoulder = this.skeletonPoint(this.bones[`${side}_UpperArm`]);
		const span = tip.clone().sub(shoulder);
		const d = clamp(span.length(), Math.abs(a - b) + 0.001, a + b - 0.001);
		const direction = span.clone().normalize();
		const bend = new THREE.Vector3(...pole).normalize();
		const sideAxis = bend.clone().sub(direction.clone().multiplyScalar(bend.dot(direction))).normalize();
		const along = (a * a - b * b + d * d) / (2 * d);
		const height = Math.sqrt(Math.max(a * a - along * along, 0));
		const elbow = shoulder.clone().add(direction.clone().multiplyScalar(along)).add(sideAxis.clone().multiplyScalar(height));
		this.aim(`${side}_UpperArm`, `${side}_Forearm`, elbow.clone().sub(shoulder).toArray());
		const end = shoulder.clone().add(direction.clone().multiplyScalar(d));
		this.aim(`${side}_Forearm`, `${side}_Hand`, end.sub(elbow).toArray());
	}

	restPoint(name) {
		// Skeleton-space rest position (bones reset temporarily).
		const saved = Object.entries(this.bones).map(([n, b]) => [b, b.quaternion.clone(), b.position.clone()]);
		this.reset();
		const p = this.skeletonPoint(this.bones[name]);
		for (const [b, q, pos] of saved) { b.quaternion.copy(q); b.position.copy(pos); }
		return p;
	}

	hangArms() {
		this.aim("L_UpperArm", "L_Forearm", [0.08, -1.0, 0.12]);
		this.aim("L_Forearm", "L_Hand", [-0.02, -1.0, 0.2]);
		this.aim("R_UpperArm", "R_Forearm", [-0.15, -1.0, 0.0]);
		this.aim("R_Forearm", "R_Hand", [-0.05, -1.0, 0.1]);
	}

	// Leaning out from behind a jamb (the title screen, the phantom).
	posePeek(lean, twitch = 0, side = 1, sway = 0) {
		this.reset();
		this.turn("Spine", [0, 0, 1], -lean * side);
		this.turn("Spine2", [0, 0, 1], -lean * side);
		this.turn("Spine2", [1, 0, 0], 0.15);
		this.turn("Spine4", [0, 0, 1], -lean * 0.5 * side);
		this.turn("Neck1", [0, 1, 0], -0.35 * side);
		this.turn("Neck1", [0, 0, 1], lean * 0.4 * side);
		this.turn("Head1", [0, 0, 1], (0.5 + twitch * 0.14 + sway) * side);
		this.turn("Head1", [1, 0, 0], 0.15);
		this.hangArms();
	}

	// Standing, staring straight ahead with the head cocked, arms hanging.
	poseStare(twitch = 0) {
		this.reset();
		this.turn("Spine2", [1, 0, 0], 0.12);
		this.turn("Neck1", [1, 0, 0], 0.1);
		this.turn("Head1", [0, 0, 1], 0.38 + twitch * 0.18);
		this.hangArms();
	}

	// locust_visual.pose_head: head and neck toward a skeleton-space direction
	// (limited to a believable range unless `limit` is raised).
	lookToward(dir, { limit = 1.0, neck = 0.45, head = 0.4, pitchScale = 0.6 } = {}) {
		const target = new THREE.Vector3(...dir);
		target.y *= pitchScale;
		const forward = new THREE.Vector3(0, 0, 1);
		const wanted = target.normalize();
		const angle = Math.min(forward.angleTo(wanted), limit);
		const axis = forward.clone().cross(wanted);
		if (axis.length() < 0.001) return;
		this.turn("Neck1", axis.toArray(), angle * neck);
		this.turn("Head1", axis.toArray(), angle * head);
	}

	// The gameplay body: pelvis drop and hunch (locust_visual.pose_body).
	poseBody({ ratio = 0, attack = 0, duck = 0, bob = 0, hunch = null, aggression = 0, recovering = 0, searching = 0, execute = 0, sway = 0 } = {}) {
		const drop = lerp(0.05, 0.15, ratio) + attack * 0.08 + duck * 0.12 - bob * 0.025;
		this.bones.Pelvis.position.copy(this.rest.Pelvis.p);
		this.bones.Pelvis.position.y -= drop;
		const h = hunch ?? ratio * 0.32 + aggression * 0.12 + attack * 0.25 - recovering * 0.1 + duck * 0.55 + searching * 0.35 - execute * 0.15;
		this.turn("Spine2", [1, 0, 0], h * 0.6);
		this.turn("Spine4", [1, 0, 0], h * 0.4);
		this.turn("Spine", [0, 0, -1], sway * 0.05 * (0.4 + ratio));
	}

	// Two-bone leg IK onto a foot point in skeleton space (locust_visual.solve_leg).
	solveLeg(side, footSkel) {
		const thigh = this.bones[`${side}_Thigh`];
		const calf = this.bones[`${side}_Calf`];
		const upper = this.legLengths[side][0];
		const lower = this.legLengths[side][1];
		const hip = this.skeletonPoint(thigh);
		const reach = footSkel.clone().sub(hip);
		const distance = clamp(reach.length(), 0.05, upper + lower - 0.002);
		const along = reach.clone().normalize();
		const pole = new THREE.Vector3(side === "L" ? 0.15 : -0.15, 0, 1);
		const bend = pole.clone().sub(along.clone().multiplyScalar(pole.dot(along))).normalize();
		const cosHip = clamp((upper * upper + distance * distance - lower * lower) / (2 * upper * distance), -1, 1);
		const knee = hip.clone().add(along.clone().multiplyScalar(upper * cosHip)).add(bend.clone().multiplyScalar(upper * Math.sqrt(1 - cosHip * cosHip)));
		this.aim(`${side}_Thigh`, `${side}_Calf`, knee.clone().sub(hip).toArray());
		const tip = hip.clone().add(along.multiplyScalar(distance));
		this.aim(`${side}_Calf`, `${side}_Foot`, tip.sub(this.skeletonPoint(calf)).toArray());
	}

	get legLengths() {
		if (!this._legs) {
			this._legs = {};
			for (const s of ["L", "R"]) {
				const hip = this.restPoint(`${s}_Thigh`);
				const knee = this.restPoint(`${s}_Calf`);
				const ankle = this.restPoint(`${s}_Foot`);
				this._legs[s] = [hip.distanceTo(knee), knee.distanceTo(ankle)];
			}
		}
		return this._legs;
	}

	// Arms as locust_visual.pose_arms (directions in skeleton space), s = +1 left.
	poseArms({ ratio = 0, swing = 0, aggression = 0, attack = 0, recovering = 0, searching = 0, execute = 0, kill = 2.8 / 4.2 } = {}) {
		const V = (x, y, z) => new THREE.Vector3(x, y, z);
		for (const [key, s] of [["L", 1], ["R", -1]]) {
			let upper = V(s * 0.42, -0.85, 0.28 + swing * s * 0.3 * ratio);
			let fore = V(s * 0.1, -0.55, 0.8);
			upper.lerp(V(s * 0.45, -0.4, 0.8), aggression);
			fore.lerp(V(s * 0.05, -0.2, 1.0), aggression);
			upper.lerp(V(s * 0.55, 0.75, 0.3), attack);
			fore.lerp(V(s * 0.15, 0.95, -0.2), attack);
			upper.lerp(V(s * 0.2, -0.35, 0.95), recovering);
			fore.lerp(V(s * -0.1, -0.8, 0.6), recovering);
			if (searching > 0) {
				const reach = clamp((searching - 0.5) / 0.35);
				upper.lerp(V(s * 0.5, -0.25, 0.9), 0.7);
				fore.lerp(V(s * 0.3, -0.15 + reach * 0.2, 1.0), 0.8);
			}
			if (execute > 0) {
				const lift = clamp(execute / 0.18);
				const closing = clamp((execute - 0.12) / Math.max(kill - 0.12, 0.01));
				const holding = s > 0;
				upper.lerp(V(s * 0.35, lerp(0.1, 0.75, lift), lerp(0.7, 0.45, closing)), 0.85);
				fore.lerp(V(s * 0.1, lerp(0.2, 0.55, lift), lerp(0.95, 0.7, closing)), 0.85);
				if (!holding) {
					const phase = (execute - kill) / 0.05;
					let thrust = Math.max(0, 1 - Math.abs(phase));
					thrust = thrust * thrust * (3 - 2 * thrust);
					const wind = closing * 0.4;
					upper.lerp(V(s * (0.6 + wind) * (1 - thrust), 0.4 - thrust * 0.35, 0.25 - wind * 0.25 + thrust * 1.05), 0.92);
					fore.lerp(V(s * 0.15 * (1 - thrust), 0.6 - thrust * 1.2, 0.1 + thrust * 1.25), 0.92);
				}
			}
			this.aim(`${key}_UpperArm`, `${key}_Forearm`, upper.toArray());
			this.aim(`${key}_Forearm`, `${key}_Hand`, fore.toArray());
		}
	}

	// A walk or run cycle at `speed` m/s, `phase` in cycles (deterministic, no
	// planted-foot state): feet on arcs under the hips, legs by IK, body bob,
	// arms swinging. The game's stride and cadence (locust_visual.step_feet).
	poseGait(speed, phase, extra = {}) {
		const ratio = clamp(speed / 6.4);
		const stride = lerp(0.8, 1.9, ratio) / SCALE; // model units
		const lift = (0.1 + ratio * 0.12) / SCALE;
		const stance = 0.21 / SCALE;
		const feet = {};
		let bob = 0;
		let swingSum = 0;
		for (const [side, off] of [["L", 0], ["R", 0.5]]) {
			const p = (((phase + off) % 1) + 1) % 1;
			// Stance for 60% of the cycle (foot slides back under the body),
			// swing for 40% (lifted and carried forward).
			const stanceFrac = lerp(0.62, 0.5, ratio);
			let z;
			let y = 0;
			if (p < stanceFrac) {
				z = lerp(0.5, -0.5, p / stanceFrac) * stride * 0.55;
			} else {
				const q = (p - stanceFrac) / (1 - stanceFrac);
				const e = q * q * (3 - 2 * q);
				z = lerp(-0.5, 0.5, e) * stride * 0.55;
				y = Math.sin(Math.PI * q) * lift;
				bob = Math.max(bob, Math.sin(Math.PI * q));
				swingSum += (side === "L" ? 1 : -1) * Math.sin(Math.PI * q);
			}
			const x = (side === "L" ? 1 : -1) * stance;
			feet[side] = new THREE.Vector3(x, y, z);
		}
		this.reset();
		this.poseBody({ ratio, bob, sway: -swingSum, ...extra });
		for (const side of ["L", "R"]) this.solveLeg(side, feet[side]);
		this.poseArms({ ratio, swing: swingSum, ...extra });
		return { ratio, bob };
	}

	// Legs standing (feet under the hips) after a body pose.
	stand(extra = {}) {
		this.poseBody(extra);
		const stance = 0.21 / SCALE;
		this.solveLeg("L", new THREE.Vector3(stance, 0, 0));
		this.solveLeg("R", new THREE.Vector3(-stance, 0, 0));
	}

	// Jaw open (0..1): the jaw bone exists but the game never moves it.
	jaw(open) {
		this.turn("jaw", [1, 0, 0], open * 0.45);
	}
}
