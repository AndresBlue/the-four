extends SceneTree
## Runs the Lurker's corridor (tools/workbenches/lurker_test.tscn) by itself,
## to see it work without anyone at the keys: the camera keeps on the creature,
## the torch comes on at --torch-at seconds, and every change of what it does is
## printed, with a frame saved to evidence/lurker/<label>_<seconds>_<mood>.jpg.
## --every=3 also saves every third frame, for watching it move
## (evidence/lurker/<label>_f<frame>.jpg).
##   godot --path . --fixed-fps 30 --script res://tools/capture/lurker_test_check.gd -- [--label=t1] [--torch-at=26] [--for=40] [--every=3]
const SCENE := preload("res://tools/workbenches/lurker_test.tscn")
const MOODS := ["coming", "staring", "fleeing", "waiting"]
var out_dir := "res://evidence/lurker"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var label := "test"
	var torch_at := 26.0
	var length := 40.0
	var every := 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--label="): label = argument.trim_prefix("--label=")
		if argument.begins_with("--torch-at="): torch_at = float(argument.trim_prefix("--torch-at="))
		if argument.begins_with("--for="): length = float(argument.trim_prefix("--for="))
		if argument.begins_with("--every="): every = int(argument.trim_prefix("--every="))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var scene: Node3D = SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	scene.player.active = false
	var player = scene.player
	var seconds := 0.0
	var mood := -1
	var shot_at := -1.0
	var frame := 0
	while seconds < length:
		await process_frame
		seconds += 1.0 / 30.0
		frame += 1
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
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg(out_dir + "/%s_%04.1f_%s.jpg" % [label, seconds, MOODS[mood]], 0.86)
	quit()
