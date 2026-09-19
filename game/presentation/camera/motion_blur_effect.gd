extends CompositorEffect
## Motion blur from the camera turning, as a camcorder's 1/60 s shutter
## records it (docs/REALISM.md, phase 1). It runs before the camera's HDR stage
## (the light smears while it is being exposed), after the transparent pass.
##
## Godot's velocity buffer only carries objects' own motion, not the view's,
## and what reads as blur in first person is the view turning. So the blur is
## worked out from the rotation between last frame's camera and this one: each
## pixel's ray is turned back into last frame's view and projected, which is
## exact for a turn and needs no depth. Walking forward barely smears at these
## speeds. The trail length is the motion during 1/60 s, whatever the frame
## rate, and never more than MAX_PIXELS.

## Samples along the trail (0 turns it off); set by the graphics preset.
var samples := 8
## Exposure time of the camcorder's shutter.
const SHUTTER := 1.0 / 60.0
## Longest trail, in pixels of the internal image: a flick is a blur, not a
## smear across the screen.
const MAX_PIXELS := 48.0

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var copy_shader: RID
var copy_pipeline: RID
var sampler: RID
var copy: RID
var copy_size := Vector2i.ZERO
var previous_basis := Basis.IDENTITY
var has_previous := false
var last_usec := 0
## The game's frame time, set every frame by the level (its simulated time,
## which is what Movie Maker records); the wall clock is the fallback.
var frame_delta := 0.0

## Godot's colour buffer cannot be a copy source (no CAN_COPY_FROM), so the
## copy the blur reads from is made by a compute pass.
const COPY := """
#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D color_image;
layout(rgba16f, set = 0, binding = 1) uniform restrict writeonly image2D copy_image;
layout(push_constant, std430) uniform Params { vec2 size; vec2 pad; } p;
void main() {
	ivec2 pix = ivec2(gl_GlobalInvocationID.xy);
	if (pix.x >= int(p.size.x) || pix.y >= int(p.size.y)) return;
	imageStore(copy_image, pix, imageLoad(color_image, pix));
}
"""
const SOURCE := """
#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(set = 0, binding = 0) uniform sampler2D source_image;
layout(rgba16f, set = 0, binding = 1) uniform restrict writeonly image2D color_image;
layout(push_constant, std430) uniform Params { vec4 r0; vec4 r1; vec4 r2; vec2 size; vec2 focal; float shutter; float samples; float max_px; float pad; } p;
void main() {
	ivec2 pix = ivec2(gl_GlobalInvocationID.xy);
	if (pix.x >= int(p.size.x) || pix.y >= int(p.size.y)) return;
	vec2 uv = (vec2(pix) + 0.5) / p.size;
	vec2 ndc = vec2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
	// This pixel's ray in view space, turned into last frame's view.
	vec3 ray = vec3(ndc.x / p.focal.x, ndc.y / p.focal.y, -1.0);
	vec3 before = mat3(p.r0.xyz, p.r1.xyz, p.r2.xyz) * ray;
	vec2 was = before.z < -0.01 ? vec2(p.focal.x * before.x, p.focal.y * before.y) / -before.z : ndc;
	vec2 trail = vec2(ndc.x - was.x, was.y - ndc.y) * 0.5 * p.shutter;
	float length_px = length(trail * p.size);
	if (length_px > p.max_px) trail *= p.max_px / length_px;
	if (length_px < 0.5) {
		imageStore(color_image, pix, texture(source_image, uv));
		return;
	}
	vec3 sum = vec3(0.0);
	int count = int(p.samples);
	for (int i = 0; i < count; i++) {
		float t = (float(i) + 0.5) / float(count) - 0.5;
		sum += texture(source_image, uv - trail * t).rgb;
	}
	imageStore(color_image, pix, vec4(sum / float(count), 1.0));
}
"""

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	RenderingServer.call_on_render_thread(setup)

func setup() -> void:
	rd = RenderingServer.get_rendering_device()
	if rd == null: return
	for code in [SOURCE, COPY]:
		var source := RDShaderSource.new()
		source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
		source.source_compute = code
		var spirv := rd.shader_compile_spirv_from_source(source)
		if spirv.compile_error_compute != "":
			push_error("motion_blur_effect: %s" % spirv.compile_error_compute)
			rd = null
			return
		if code == SOURCE:
			shader = rd.shader_create_from_spirv(spirv)
			pipeline = rd.compute_pipeline_create(shader)
		else:
			copy_shader = rd.shader_create_from_spirv(spirv)
			copy_pipeline = rd.compute_pipeline_create(copy_shader)
	var state := RDSamplerState.new()
	state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler = rd.sampler_create(state)

## Frees what it made on the GPU; see camcorder_effect.release().
func release() -> void:
	if rd == null: return
	enabled = false
	for rid in [copy, sampler, shader, copy_shader]:
		if rid.is_valid(): rd.free_rid(rid)
	rd = null

## Inline, not release(): a method call on an instance being deleted fails.
func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE or rd == null: return
	for rid in [copy, sampler, shader, copy_shader]:
		if rid.is_valid(): rd.free_rid(rid)

func _render_callback(_type: int, data: RenderData) -> void:
	if rd == null or samples <= 0: return
	var buffers: RenderSceneBuffersRD = data.get_render_scene_buffers()
	var scene: RenderSceneData = data.get_render_scene_data()
	if buffers == null or scene == null: return
	var size := buffers.get_internal_size()
	if size.x == 0 or size.y == 0: return
	var now := Time.get_ticks_usec()
	var dt := frame_delta if frame_delta > 0.0 else ((now - last_usec) / 1000000.0 if last_usec > 0 else 0.0)
	last_usec = now
	var basis := scene.get_cam_transform().basis.orthonormalized()
	var turn := previous_basis.transposed() * basis
	var fresh := not has_previous or dt <= 0.0 or dt > 0.25
	previous_basis = basis
	has_previous = true
	if fresh: return
	if copy_size != size:
		if copy.is_valid(): rd.free_rid(copy)
		var format := RDTextureFormat.new()
		format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
		format.width = size.x
		format.height = size.y
		format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		copy = rd.texture_create(format, RDTextureView.new())
		copy_size = size
	var color := buffers.get_color_layer(0)
	var groups := Vector2i((size.x + 7) / 8, (size.y + 7) / 8)
	var copy_from := RDUniform.new()
	copy_from.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	copy_from.binding = 0
	copy_from.add_id(color)
	var copy_to := RDUniform.new()
	copy_to.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	copy_to.binding = 1
	copy_to.add_id(copy)
	var copy_push := PackedFloat32Array([size.x, size.y, 0.0, 0.0])
	var copy_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(copy_list, copy_pipeline)
	rd.compute_list_bind_uniform_set(copy_list, UniformSetCacheRD.get_cache(copy_shader, 0, [copy_from, copy_to]), 0)
	rd.compute_list_set_push_constant(copy_list, copy_push.to_byte_array(), copy_push.size() * 4)
	rd.compute_list_dispatch(copy_list, groups.x, groups.y, 1)
	rd.compute_list_end()
	var projection := scene.get_cam_projection()
	var shutter := SHUTTER / dt
	var push := PackedFloat32Array([
		turn.x.x, turn.x.y, turn.x.z, 0.0,
		turn.y.x, turn.y.y, turn.y.z, 0.0,
		turn.z.x, turn.z.y, turn.z.z, 0.0,
		size.x, size.y, projection.x.x, projection.y.y,
		shutter, samples, MAX_PIXELS * size.y / 1080.0, 0.0])
	var source := RDUniform.new()
	source.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	source.binding = 0
	source.add_id(sampler)
	source.add_id(copy)
	var target := RDUniform.new()
	target.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	target.binding = 1
	target.add_id(color)
	var list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(list, pipeline)
	rd.compute_list_bind_uniform_set(list, UniformSetCacheRD.get_cache(shader, 0, [source, target]), 0)
	rd.compute_list_set_push_constant(list, push.to_byte_array(), push.size() * 4)
	rd.compute_list_dispatch(list, (size.x + 7) / 8, (size.y + 7) / 8, 1)
	rd.compute_list_end()
