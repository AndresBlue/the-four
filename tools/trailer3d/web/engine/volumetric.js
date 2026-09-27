// Haze lit by the lamps: torch beams marched through the air with their own
// shadow (anything in the beam, the creature too, cuts it), and the glow of
// point lights round their bulbs (closed form). The start of the march is
// jittered per subframe, so the average of the subframes is smooth.
import * as THREE from "three";
import { shaderPass } from "./core.js";

const MAX_SPOTS = 4;
const MAX_POINTS = 24;

const FRAG = /* glsl */ `
precision highp float;
uniform sampler2D depthTex;
uniform mat4 projInv;
uniform mat4 camWorld;
uniform vec3 camPos;
uniform float near;
uniform float far;
uniform float density;
uniform float g;
uniform float noiseAmount;
uniform float noiseScale;
uniform float time;
uniform float jitter;
uniform float maxDist;
uniform int steps;
uniform int spotCount;
uniform vec3 spotPos[${MAX_SPOTS}];
uniform vec3 spotDir[${MAX_SPOTS}];
uniform vec3 spotColor[${MAX_SPOTS}];
uniform vec2 spotCone[${MAX_SPOTS}];
uniform float spotRange[${MAX_SPOTS}];
uniform mat4 spotMatrix[${MAX_SPOTS}];
uniform sampler2D spotDepth0;
uniform sampler2D spotDepth1;
uniform sampler2D spotDepth2;
uniform sampler2D spotDepth3;
uniform int pointCount;
uniform vec3 pointPos[${MAX_POINTS}];
uniform vec3 pointColor[${MAX_POINTS}];
uniform float pointRadius[${MAX_POINTS}];
varying vec2 vUv;

float hash13(vec3 p) { p = fract(p * 0.1031); p += dot(p, p.zyx + 31.32); return fract((p.x + p.y) * p.z); }
float vnoise3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), u.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), u.x), u.y),
		mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), u.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), u.x), u.y), u.z);
}
float hazeAt(vec3 p) {
	if (noiseAmount <= 0.0) return 1.0;
	vec3 q = p * noiseScale + vec3(time * 0.05, time * 0.015, -time * 0.03);
	float n = vnoise3(q) * 0.6 + vnoise3(q * 2.3 + 7.0) * 0.4;
	return max(0.0, 1.0 + (n - 0.5) * 2.0 * noiseAmount);
}
float hg(float c) { float g2 = g * g; return (1.0 - g2) / (12.566 * pow(1.0 + g2 - 2.0 * g * c, 1.5)); }
float spotShadow(int i, vec3 p) {
	vec4 s = spotMatrix[i] * vec4(p, 1.0);
	vec3 n = s.xyz / s.w;
	vec2 uv = n.xy * 0.5 + 0.5;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0 || n.z > 1.0) return 0.0;
	float d = n.z * 0.5 + 0.5;
	float stored = i == 0 ? texture2D(spotDepth0, uv).r : i == 1 ? texture2D(spotDepth1, uv).r : i == 2 ? texture2D(spotDepth2, uv).r : texture2D(spotDepth3, uv).r;
	return d - 0.0008 > stored ? 0.0 : 1.0;
}
void main() {
	float z = texture2D(depthTex, vUv).r;
	vec4 clip = vec4(vUv * 2.0 - 1.0, z * 2.0 - 1.0, 1.0);
	vec4 view = projInv * clip;
	view /= view.w;
	vec3 world = (camWorld * vec4(view.xyz, 1.0)).xyz;
	vec3 rd = world - camPos;
	float T = length(rd);
	rd /= T;
	if (z >= 1.0) T = maxDist;
	T = min(T, maxDist);
	vec3 total = vec3(0.0);
	// Torch beams: marched, with their shadow.
	if (spotCount > 0) {
		float stepLen = T / float(steps);
		for (int k = 0; k < 96; k++) {
			if (k >= steps) break;
			float t = (float(k) + jitter) * stepLen;
			vec3 p = camPos + rd * t;
			float h = hazeAt(p);
			for (int i = 0; i < ${MAX_SPOTS}; i++) {
				if (i >= spotCount) break;
				vec3 L = spotPos[i] - p;
				float d = length(L);
				if (d > spotRange[i]) continue;
				vec3 l = L / d;
				float cosA = dot(-l, spotDir[i]);
				float cone = smoothstep(spotCone[i].x, spotCone[i].y, cosA);
				if (cone <= 0.0) continue;
				// A torch's beam is hottest down its middle: a shaft, not a wedge.
				cone *= 0.35 + 0.65 * smoothstep(spotCone[i].x, 1.0, cosA);
				float fade = 1.0 - smoothstep(spotRange[i] * 0.6, spotRange[i], d);
				float sh = spotShadow(i, p);
				total += spotColor[i] * cone * fade * sh * hg(dot(l, rd)) / (d * d + 0.3) * h * stepLen;
			}
		}
	}
	// Bulbs: the closed-form in-scatter of a point light along the ray.
	for (int i = 0; i < ${MAX_POINTS}; i++) {
		if (i >= pointCount) break;
		vec3 oc = pointPos[i] - camPos;
		float t0 = dot(oc, rd);
		vec3 closest = camPos + rd * clamp(t0, 0.0, T);
		float hh = length(camPos + rd * t0 - pointPos[i]);
		float r = pointRadius[i];
		float h2 = sqrt(hh * hh + r * r * 0.02);
		float integral = (atan((T - t0) / h2) - atan((0.0 - t0) / h2)) / h2;
		// Only the air near the bulb: the lamp's own reach, not the whole hall.
		float reach = exp(-hh * hh / (r * r));
		total += pointColor[i] * integral * reach * 0.0796 * hazeAt(closest);
	}
	gl_FragColor = vec4(total * density, 1.0);
}`;

export class Volumetrics {
	constructor(renderer, { density = 0.04, g = 0.35, noise = 0.5, noiseScale = 0.35, steps = 48, maxDist = 40 } = {}) {
		this.renderer = renderer;
		this.options = { density, g, noise, noiseScale, steps, maxDist };
		this.spots = [];
		this.points = [];
		const u = (v) => ({ value: v });
		this.pass = shaderPass(FRAG, {
			depthTex: u(null), projInv: u(new THREE.Matrix4()), camWorld: u(new THREE.Matrix4()), camPos: u(new THREE.Vector3()),
			near: u(0.05), far: u(100), density: u(density), g: u(g), noiseAmount: u(noise), noiseScale: u(noiseScale), time: u(0), jitter: u(0.5),
			maxDist: u(maxDist), steps: u(steps), spotCount: u(0),
			spotPos: u(Array.from({ length: MAX_SPOTS }, () => new THREE.Vector3())), spotDir: u(Array.from({ length: MAX_SPOTS }, () => new THREE.Vector3(0, 0, -1))),
			spotColor: u(Array.from({ length: MAX_SPOTS }, () => new THREE.Vector3())), spotCone: u(Array.from({ length: MAX_SPOTS }, () => new THREE.Vector2(0.9, 0.95))),
			spotRange: u(new Array(MAX_SPOTS).fill(20)), spotMatrix: u(Array.from({ length: MAX_SPOTS }, () => new THREE.Matrix4())),
			spotDepth0: u(null), spotDepth1: u(null), spotDepth2: u(null), spotDepth3: u(null),
			pointCount: u(0), pointPos: u(Array.from({ length: MAX_POINTS }, () => new THREE.Vector3())), pointColor: u(Array.from({ length: MAX_POINTS }, () => new THREE.Vector3())),
			pointRadius: u(new Array(MAX_POINTS).fill(1)),
		});
		this.depthMaterial = new THREE.MeshDepthMaterial();
	}

	// A torch (THREE.SpotLight) whose beam shows in the haze; strength scales it.
	addSpot(light, { strength = 1, resolution = 512 } = {}) {
		const rt = new THREE.WebGLRenderTarget(resolution, resolution, { depthBuffer: true });
		rt.depthTexture = new THREE.DepthTexture(resolution, resolution, THREE.FloatType);
		const cam = new THREE.PerspectiveCamera(60, 1, 0.05, 40);
		const spot = { light, strength, rt, cam };
		this.spots.push(spot);
		return spot;
	}

	// A bulb's glow: any object with a world position; radius is its reach (m).
	addPoint(light, { strength = 1, radius = 1.2 } = {}) {
		const p = { light, strength, radius };
		this.points.push(p);
		return p;
	}

	render(pipe, camera, scene, { time = 0, random = Math.random } = {}) {
		const r = this.renderer;
		const u = this.pass.material.uniforms;
		let n = 0;
		const saveOverride = scene.overrideMaterial;
		for (const s of this.spots) {
			if (n >= MAX_SPOTS) break;
			const L = s.light;
			if (!L.visible || L.intensity <= 0) continue;
			L.updateMatrixWorld();
			L.target.updateMatrixWorld();
			const pos = new THREE.Vector3().setFromMatrixPosition(L.matrixWorld);
			const tgt = new THREE.Vector3().setFromMatrixPosition(L.target.matrixWorld);
			const dir = tgt.clone().sub(pos).normalize();
			s.cam.position.copy(pos);
			s.cam.fov = THREE.MathUtils.radToDeg(L.angle) * 2 + 2;
			s.cam.far = L.distance > 0 ? L.distance : 40;
			s.cam.updateProjectionMatrix();
			s.cam.lookAt(tgt);
			s.cam.updateMatrixWorld();
			scene.overrideMaterial = this.depthMaterial;
			r.setRenderTarget(s.rt);
			r.clear();
			r.render(scene, s.cam);
			u.spotPos.value[n].copy(pos);
			u.spotDir.value[n].copy(dir);
			const c = L.color;
			u.spotColor.value[n].set(c.r, c.g, c.b).multiplyScalar(L.intensity * s.strength);
			u.spotCone.value[n].set(Math.cos(L.angle), Math.cos(L.angle * (1 - L.penumbra)));
			u.spotRange.value[n] = s.cam.far;
			u.spotMatrix.value[n].multiplyMatrices(s.cam.projectionMatrix, s.cam.matrixWorldInverse);
			u[`spotDepth${n}`].value = s.rt.depthTexture;
			n++;
		}
		scene.overrideMaterial = saveOverride;
		u.spotCount.value = n;
		let m = 0;
		for (const p of this.points) {
			if (m >= MAX_POINTS) break;
			const L = p.light;
			if (L.visible === false || (L.intensity !== undefined && L.intensity <= 0)) continue;
			L.updateMatrixWorld?.();
			const pos = new THREE.Vector3().setFromMatrixPosition(L.matrixWorld);
			u.pointPos.value[m].copy(pos);
			const c = L.color ?? new THREE.Color(1, 1, 1);
			u.pointColor.value[m].set(c.r, c.g, c.b).multiplyScalar((L.intensity ?? 1) * p.strength);
			u.pointRadius.value[m] = p.radius;
			m++;
		}
		u.pointCount.value = m;
		camera.updateMatrixWorld();
		u.depthTex.value = pipe.scene.depthTexture;
		u.projInv.value.copy(camera.projectionMatrixInverse);
		u.camWorld.value.copy(camera.matrixWorld);
		u.camPos.value.setFromMatrixPosition(camera.matrixWorld);
		u.density.value = this.options.density;
		u.g.value = this.options.g;
		u.noiseAmount.value = this.options.noise;
		u.noiseScale.value = this.options.noiseScale;
		u.steps.value = this.options.steps;
		u.maxDist.value = this.options.maxDist;
		u.time.value = time;
		u.jitter.value = random();
		r.setRenderTarget(pipe.vol);
		r.setClearColor(0x000000, 1);
		r.clear();
		this.pass.render(r);
	}
}
