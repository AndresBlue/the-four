extends CompositorEffect
## The camcorder's HDR stage (docs/REALISM.md, phase 1): what a camera does to
## the light before it is a video signal. It runs after the transparent pass
## and before TAA and the tonemapper (Godot's POST_TRANSPARENT), so it only
## does what is stable per pixel; the lens and the sensor noise come later, on
## the canvas (lens.gdshader).
##   meter    a centre-weighted average of the scene's luminance, on a grid
##   iris     the automatic iris and gain: opens slowly, closes quicker, never
##            past its range, so a room with no light stays black
##   smear    per column, the charge a saturated highlight spills down the
##            CCD: a faint vertical streak through a bare bulb
##   grade    exposure, smear, white balance and the video knee that replaces
##            the tonemapper (the environment is set to linear while it runs)
## Without a RenderingDevice (headless, Compatibility) it does nothing, and the
## game keeps AgX and its fixed exposure.

## Metering grid.
const GRID := Vector2i(64, 36)

## Target average (centre-weighted, linear) the iris aims the picture at.
var key := 0.065
## Range of the iris and gain, in stops round the base exposure.
var min_ev := -1.5
var max_ev := 0.8
## How quickly it follows, per second: brightening (opening the iris, adding
## gain) is slower than darkening, as in a camera.
var speed_up := 1.1
var speed_down := 2.4
## CCD smear strength (0 off) and the level above which a pixel spills.
var smear := 0.04
var smear_threshold := 4.0
## White balance multipliers (a fixed camera white point) and the knee: from
## `knee` up the signal is compressed into what is left below clipping.
var white_balance := Vector3.ONE
var knee := 0.72
## Black toe: the lowest levels sink a little (x * x / (x + toe)), which keeps
## the depth of the shadows the old tonemapper gave.
var toe := 0.008
## Set to jump to the metered exposure on the next frame (a cut, a new floor).
var reset := true
## The gain the iris added last time it was read back (1 at or below the base
## exposure): the sensor noise on the canvas grows with it.
static var gain := 1.0
## The exposure the iris settled on, in stops over the base (read back too).
static var ev := 0.0

var rd: RenderingDevice
var shaders := {}
var pipelines := {}
var samples: RID
var state: RID
var columns: RID
var column_count := 0
var last_usec := 0
static var reading := false
## The game's frame time, set every frame by the level (see motion_blur_effect).
var frame_delta := 0.0

const HEADER := "#version 450\n"
const METER := """
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D color_image;
layout(set = 0, binding = 1, std430) restrict writeonly buffer Samples { float data[]; } samples;
layout(push_constant, std430) uniform Params { vec2 size; vec2 grid; } p;
void main() {
	ivec2 cell = ivec2(gl_GlobalInvocationID.xy);
	if (cell.x >= int(p.grid.x) || cell.y >= int(p.grid.y)) return;
	vec2 uv = (vec2(cell) + 0.5) / p.grid;
	// Four taps per cell, so a cell sees more than one pixel.
	vec3 c = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		vec2 o = vec2(float(i & 1), float(i >> 1)) - 0.5;
		ivec2 pix = ivec2(clamp((uv + o * 0.5 / p.grid) * p.size, vec2(0.0), p.size - 1.0));
		c += imageLoad(color_image, pix).rgb;
	}
	float lum = dot(c * 0.25, vec3(0.2126, 0.7152, 0.0722));
	vec2 d = (uv - 0.5) * vec2(1.6, 1.0);
	float w = exp(-dot(d, d) * 3.0);
	int i = (cell.y * int(p.grid.x) + cell.x) * 2;
	samples.data[i] = min(lum, 16.0) * w;
	samples.data[i + 1] = w;
}
"""
const IRIS := """
layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;
layout(set = 0, binding = 0, std430) restrict readonly buffer Samples { float data[]; } samples;
layout(set = 0, binding = 1, std430) restrict buffer State { float ev; float target; float gain; float pad; } state;
layout(push_constant, std430) uniform Params { float count; float dt; float key; float min_ev; float max_ev; float speed_up; float speed_down; float reset; } p;
shared float sums[256];
shared float weights[256];
void main() {
	uint t = gl_LocalInvocationID.x;
	float s = 0.0;
	float w = 0.0;
	for (uint i = t; i < uint(p.count); i += 256u) {
		s += samples.data[i * 2u];
		w += samples.data[i * 2u + 1u];
	}
	sums[t] = s;
	weights[t] = w;
	barrier();
	for (uint stride = 128u; stride > 0u; stride >>= 1u) {
		if (t < stride) {
			sums[t] += sums[t + stride];
			weights[t] += weights[t + stride];
		}
		barrier();
	}
	if (t == 0u) {
		float mean = sums[0] / max(weights[0], 1e-6);
		float target = clamp(log2(p.key / max(mean, 1e-5)), p.min_ev, p.max_ev);
		float rate = target > state.ev ? p.speed_up : p.speed_down;
		state.ev = p.reset > 0.5 ? target : mix(state.ev, target, 1.0 - exp(-p.dt * rate));
		state.target = target;
		state.gain = exp2(max(state.ev, 0.0));
	}
}
"""
const SMEAR := """
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D color_image;
layout(set = 0, binding = 1, std430) restrict readonly buffer State { float ev; float target; float gain; float pad; } state;
layout(set = 0, binding = 2, std430) restrict writeonly buffer Columns { float data[]; } columns;
layout(push_constant, std430) uniform Params { vec2 size; float threshold; float pad; } p;
void main() {
	int x = int(gl_GlobalInvocationID.x);
	if (x >= int(p.size.x)) return;
	float exposure = exp2(state.ev);
	float spill = 0.0;
	for (int y = 0; y < int(p.size.y); y += 2) {
		float lum = dot(imageLoad(color_image, ivec2(x, y)).rgb, vec3(0.2126, 0.7152, 0.0722)) * exposure;
		spill += max(lum - p.threshold, 0.0);
	}
	columns.data[x] = spill * 2.0 / p.size.y;
}
"""
const GRADE := """
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(rgba16f, set = 0, binding = 0) uniform restrict image2D color_image;
layout(set = 0, binding = 1, std430) restrict readonly buffer State { float ev; float target; float gain; float pad; } state;
layout(set = 0, binding = 2, std430) restrict readonly buffer Columns { float data[]; } columns;
layout(push_constant, std430) uniform Params { vec2 size; float smear; float knee; vec3 white; float toe; } p;
vec3 shoulder(vec3 x) {
	// Linear up to the knee, then compressed into what is left below 1.
	vec3 over = max(x - p.knee, 0.0);
	float room = 1.0 - p.knee;
	return min(x, vec3(p.knee)) + room * (1.0 - exp(-over / room));
}
void main() {
	ivec2 pix = ivec2(gl_GlobalInvocationID.xy);
	if (pix.x >= int(p.size.x) || pix.y >= int(p.size.y)) return;
	vec4 source = imageLoad(color_image, pix);
	vec3 c = source.rgb * exp2(state.ev);
	if (p.smear > 0.0) {
		// The streak, a touch wider than a column and faintly cold.
		float s = columns.data[pix.x] * 0.5;
		if (pix.x > 0) s += columns.data[pix.x - 1] * 0.25;
		if (pix.x < int(p.size.x) - 1) s += columns.data[pix.x + 1] * 0.25;
		c += s * p.smear * vec3(0.95, 0.95, 1.05);
	}
	c *= p.white;
	c = c * c / (c + p.toe);
	c = shoulder(c);
	// Highlights lose their colour before they clip, as on video.
	float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c = mix(c, vec3(luma), smoothstep(0.85, 1.0, luma) * 0.6);
	imageStore(color_image, pix, vec4(c, source.a));
}
"""

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	RenderingServer.call_on_render_thread(setup)

func setup() -> void:
	rd = RenderingServer.get_rendering_device()
	if rd == null: return
	var sources := {"meter": METER, "iris": IRIS, "smear": SMEAR, "grade": GRADE}
	for name in sources:
		var source := RDShaderSource.new()
		source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
		source.source_compute = HEADER + sources[name]
		var spirv := rd.shader_compile_spirv_from_source(source)
		if spirv.compile_error_compute != "":
			push_error("camcorder_effect %s: %s" % [name, spirv.compile_error_compute])
			rd = null
			return
		shaders[name] = rd.shader_create_from_spirv(spirv)
		pipelines[name] = rd.compute_pipeline_create(shaders[name])
	samples = rd.storage_buffer_create(GRID.x * GRID.y * 2 * 4)
	state = rd.storage_buffer_create(16, PackedFloat32Array([0.0, 0.0, 1.0, 0.0]).to_byte_array())

## Frees what it made on the GPU. The level calls it when it leaves the tree:
## on quitting, the effect itself outlives the RenderingDevice, and freeing
## then crashed the game on exit.
func release() -> void:
	if rd == null: return
	enabled = false
	for rid in [samples, state, columns]:
		if rid.is_valid(): rd.free_rid(rid)
	for name in shaders: rd.free_rid(shaders[name])
	shaders.clear()
	rd = null

## Inline, not release(): a method call on an instance being deleted fails.
func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE or rd == null: return
	for rid in [samples, state, columns]:
		if rid.is_valid(): rd.free_rid(rid)
	for name in shaders: rd.free_rid(shaders[name])

func storage(binding: int, rid: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = binding
	uniform.add_id(rid)
	return uniform

func image(binding: int, rid: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(rid)
	return uniform

func dispatch(name: String, uniforms: Array, push: PackedFloat32Array, groups: Vector3i) -> void:
	var list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(list, pipelines[name])
	rd.compute_list_bind_uniform_set(list, UniformSetCacheRD.get_cache(shaders[name], 0, uniforms), 0)
	rd.compute_list_set_push_constant(list, push.to_byte_array(), push.size() * 4)
	rd.compute_list_dispatch(list, groups.x, groups.y, groups.z)
	rd.compute_list_end()

func _render_callback(_type: int, data: RenderData) -> void:
	if rd == null: return
	var buffers: RenderSceneBuffersRD = data.get_render_scene_buffers()
	if buffers == null: return
	var size := buffers.get_internal_size()
	if size.x == 0 or size.y == 0: return
	if column_count != size.x:
		if columns.is_valid(): rd.free_rid(columns)
		columns = rd.storage_buffer_create(size.x * 4)
		column_count = size.x
	var now := Time.get_ticks_usec()
	var dt := frame_delta if frame_delta > 0.0 else (clampf((now - last_usec) / 1000000.0, 0.0, 0.25) if last_usec > 0 else 0.0)
	last_usec = now
	var color := buffers.get_color_layer(0)
	var sizef := Vector2(size)
	dispatch("meter", [image(0, color), storage(1, samples)], PackedFloat32Array([sizef.x, sizef.y, GRID.x, GRID.y]), Vector3i((GRID.x + 7) / 8, (GRID.y + 7) / 8, 1))
	dispatch("iris", [storage(0, samples), storage(1, state)], PackedFloat32Array([GRID.x * GRID.y, dt, key, min_ev, max_ev, speed_up, speed_down, 1.0 if reset else 0.0]), Vector3i(1, 1, 1))
	reset = false
	if smear > 0.0:
		dispatch("smear", [image(0, color), storage(1, state), storage(2, columns)], PackedFloat32Array([sizef.x, sizef.y, smear_threshold, 0.0]), Vector3i((size.x + 63) / 64, 1, 1))
	dispatch("grade", [image(0, color), storage(1, state), storage(2, columns)], PackedFloat32Array([sizef.x, sizef.y, smear, knee, white_balance.x, white_balance.y, white_balance.z, toe]), Vector3i((size.x + 7) / 8, (size.y + 7) / 8, 1))
	# The gain for the sensor noise, a frame or two late, which is plenty.
	if not reading:
		reading = true
		rd.buffer_get_data_async(state, receive)

## Where the iris readback lands. Static on purpose: a readback still pending
## when the game quits is answered after the effect is gone, and a callback
## into a freed object crashed the exit. The script outlives the device.
static func receive(bytes: PackedByteArray) -> void:
	var values := bytes.to_float32_array()
	if values.size() >= 3:
		ev = values[0]
		gain = values[2]
	reading = false
