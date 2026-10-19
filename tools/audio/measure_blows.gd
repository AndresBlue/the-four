extends SceneTree
## How loud each blow on the television is in the opening scene, on its own:
## the scene's set and voices, the camera where the timeline has it at each
## blow, nothing else playing (no static, no drone, no heartbeat), through the
## real mixer. Peak and the loudest tenth of a second on the Master bus; each
## should be louder than the last (intro_sequence.HIT_DB). Real time.
##
##     godot --path . --script res://tools/audio/measure_blows.gd -- --test-profile
const INTRO := preload("res://game/intro/intro_sequence.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var intro = INTRO.new()
	root.add_child(intro)
	intro.set_process(false)
	await process_frame
	for title in ["static", "whine"]: intro.voices[title].stop()
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 3.0
	AudioServer.add_bus_effect(0, capture)
	var hundredth := int(AudioServer.get_mix_rate() * 0.01)
	var said: Array[float] = []
	for index in intro.BLOWS.size():
		intro.time = intro.BLOWS[index][0]
		var where: Dictionary = intro.sample_keys()
		intro.cam_pos = where.pos
		intro.cam_yaw = where.yaw
		intro.cam_pitch = where.pitch
		intro.cam_vel = Vector3.ZERO
		intro.update_camera(0.0)
		for frame in 10: await process_frame
		capture.clear_buffer()
		intro.blow(index)
		var peak := 0.0
		var last_ten: Array[float] = []
		var block := 0.0
		var in_block := 0
		var loudest := 0.0
		var waited := 0.0
		while waited < 0.9:
			await process_frame
			waited += root.get_process_delta_time()
			for frame in capture.get_buffer(capture.get_frames_available()):
				peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
				block += frame.length_squared() * 0.5
				in_block += 1
				if in_block == hundredth:
					last_ten.append(block / hundredth)
					if last_ten.size() > 10: last_ten.pop_front()
					loudest = maxf(loudest, last_ten.reduce(func(a, b): return a + b, 0.0) / 10.0)
					block = 0.0
					in_block = 0
		said.append(linear_to_db(maxf(sqrt(loudest), 1e-6)))
		print("blow %d at %.2f s, %.1f m from the set: peak %6.1f  loudest 0.1 s %6.1f dBFS" % [index + 1, intro.BLOWS[index][0], intro.camera.global_position.distance_to(intro.SCREEN), linear_to_db(maxf(peak, 1e-6)), said[-1]])
	var rising := true
	for index in range(1, said.size()): rising = rising and said[index] > said[index - 1]
	print("BLOWS ", "each louder than the last" if rising else "NOT each louder than the last")
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	intro.queue_free()
	await process_frame
	quit()
