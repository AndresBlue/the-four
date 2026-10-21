extends SceneTree
## Runs the Lurker's corridor (tools/workbenches/lurker_test.tscn) by itself,
## to see it work without anyone at the keys: the camera keeps on the creature,
## the torch comes on at --torch-at seconds, and every change of what it does is
## printed, with a frame saved to evidence/lurker/<label>_<seconds>_<mood>.jpg.
## --every=3 also saves every third frame, for watching it move
## (evidence/lurker/<label>_f<frame>.jpg). Every two seconds it says how the
## hands did: how many steps, how many of them came straight after landing,
## how far the worst held hand was short of its hold, and how far the worst
## held claw slid.
## --stand=-4.5 puts the camera further down the corridor (z), so that it stops
## to stare under a lamp.
##   godot --path . --fixed-fps 30 --script res://tools/capture/lurker_test_check.gd -- [--label=t1] [--torch-at=26] [--for=40] [--every=3] [--stand=-4.5]
const SCENE := preload("res://tools/workbenches/lurker_test.tscn")
const MOODS := ["coming", "staring", "fleeing", "waiting"]
var out_dir := "res://evidence/lurker"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var label := "test"
	var torch_at := 26.0
	var length := 40.0
	var every := 0
	var stand := INF
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--label="): label = argument.trim_prefix("--label=")
		if argument.begins_with("--torch-at="): torch_at = float(argument.trim_prefix("--torch-at="))
		if argument.begins_with("--for="): length = float(argument.trim_prefix("--for="))
		if argument.begins_with("--every="): every = int(argument.trim_prefix("--every="))
		if argument.begins_with("--stand="): stand = float(argument.trim_prefix("--stand="))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var scene: Node3D = SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	scene.player.active = false
	if stand != INF: scene.player.position.z = stand
	var player = scene.player
	var seconds := 0.0
	var mood := -1
	var shot_at := -1.0
	var frame := 0
	var swinging := {}
	var claws_were := {}
	var steps := 0
	var quick := 0
	var worst_miss := 0.0
	var worst_slide := 0.0
	var stuck := 0
	while seconds < length:
		await process_frame
		seconds += 1.0 / 30.0
		frame += 1
		for limb in scene.lurker.limbs.limbs:
			var name: String = limb.name
			if limb.swing and not swinging.get(name, false):
				steps += 1
				if float(limb.dwell) < 0.4: quick += 1
			swinging[name] = limb.swing
			var holding: bool = not limb.swing and not limb.free
			worst_miss = maxf(worst_miss, float(limb.miss))
			if holding and claws_were.has(name):
				worst_slide = maxf(worst_slide, (limb.claw_at as Vector3).distance_to(claws_were[name]))
			if holding: claws_were[name] = limb.claw_at
			else: claws_were.erase(name)
			if limb.elbow_stuck:
				stuck += 1
				if OS.get_cmdline_user_args().has("--why"):
					var skeleton: Skeleton3D = scene.lurker.skeleton
					var socket: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(limb.upper).origin
					print("STUCK %.1fs %s swing=%s free=%s on %s, hold %.0f%% of its reach, socket %s" % [seconds, name, limb.swing, limb.free, (limb.normal as Vector3).snapped(Vector3.ONE * 0.1),
						(limb.hold as Vector3).distance_to(socket) / (float(limb.reach) * scene.lurker.limbs.size) * 100.0, socket.snapped(Vector3.ONE * 0.01)])
		if frame % 60 == 0:
			print("HANDS %.0fs: %d steps, %d straight after landing; worst wrist short by %.1f cm; worst claw slid %.1f cm; an elbow with no way clear %d times" % [seconds, steps, quick, worst_miss * 100.0, worst_slide * 100.0, stuck])
			stuck = 0
			steps = 0
			quick = 0
			worst_miss = 0.0
			worst_slide = 0.0
		if every > 0 and frame % every == 0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg(out_dir + "/%s_f%04d.jpg" % [label, frame], 0.8)
		# the lens on it, as someone watching it would
		var skeleton: Skeleton3D = scene.lurker.skeleton
		var target: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("head")).origin
		var d: Vector3 = target - player.camera.global_position
		player.rotation.y = atan2(-d.x, -d.z)
		player.camera.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
		player.snap_torch()
		if seconds >= torch_at and not player.torch.visible:
			player.torch.visible = true
			print("CHECK %.1fs torch on, it is %.1f m away" % [seconds, absf(player.global_position.z - scene.z)])
		if int(scene.mood) != mood:
			mood = int(scene.mood)
			print("CHECK %.1fs %s at z=%.2f, %.1f m away" % [seconds, MOODS[mood], scene.z, absf(player.global_position.z - scene.z)])
			shot_at = seconds + 0.6
		if shot_at > 0.0 and seconds >= shot_at:
			shot_at = -1.0
			claws(scene)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg(out_dir + "/%s_%04.1f_%s.jpg" % [label, seconds, MOODS[mood]], 0.86)
	quit()


## How far above what it holds each claw's point is, for every planted hand
## (centimetres; below 0 is into it).
func claws(scene: Node3D) -> void:
	var limbs = scene.lurker.limbs
	var skeleton: Skeleton3D = scene.lurker.skeleton
	var xf := skeleton.global_transform
	for limb in limbs.limbs:
		if limb.swing: continue
		var heights := []
		for height in limb.touch: heights.append("%.1f" % (float(height) * limbs.size * 100.0))
		var socket: Vector3 = xf * skeleton.get_bone_global_pose(limb.upper).origin
		print("CLAWS %s on %s, %.0f%% of its reach: %s" % [limb.name, limb.normal.snapped(Vector3.ONE * 0.1),
			limb.hold.distance_to(socket) / (limb.reach * limbs.size) * 100.0, ", ".join(heights)])
