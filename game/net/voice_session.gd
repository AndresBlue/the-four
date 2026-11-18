extends Node
## The host admits voice from live teammates and relays it to the whole team,
## the dead included: they listen through the teammate they watch, and never
## speak. The local mixer owns distance, occlusion and the player's volumes.

const CODEC := preload("res://game/audio/voice_codec.gd")
const PLAYBACK := preload("res://game/audio/voice_playback.gd")
const DETECTION := preload("res://game/audio/voice_detection.gd")
const ACTION := &"team_voice"
const PACKETS_PER_SECOND := 55.0
const BURST := 9.0
## Enough for a 15 fps frame; more than that is a hitch and is dropped.
const MAX_CAPTURE_BLOCKS := 6
const ROUTE_PERIOD_MS := 90
## speakers(): above this blend a teammate counts as heard over the radio.
const RADIO_SHOWN := 0.56

var net
var streams := {}
var routes := {}
var budgets := {}
## Seat -> the name it had when muted: someone else in that seat is heard.
var muted_seats := {}
var microphone: AudioStreamPlayer
var capture: AudioEffectCapture
var capture_bus := &""
var capture_frames := 0
var detector := DETECTION.new()
var capture_automatic := true
var monitoring := false
var sequence := 0
var next_route := 0
var last_sent := -1000

func _process(_delta: float) -> void:
	if not is_instance_valid(net.level): return
	var level = net.level
	var listening: bool = net.active() and listener(net.local_seat)
	# Always open in a match: push to talk only gates what is already heard.
	var wanted: bool = monitoring or (listening and admitted(net.local_seat) and level.settings.values.voice_mic and not level.automation)
	if not wanted or not safe_window():
		stop_microphone()
	else:
		if microphone == null or not microphone.playing: start_microphone()
		var automatic: bool = level.settings.values.voice_automatic
		if capture_automatic != automatic:
			capture_automatic = automatic
			detector.reset()
		send_capture()
	forget_replaced_mutes()
	if listening and float(level.settings.values.voice_volume) > 0.0:
		mix_streams(Time.get_ticks_msec())
	else:
		clear_streams()

## A living survivor in play: may speak, and is heard.
func admitted(seat: int) -> bool:
	return listener(seat) and net.level.session.participants.get(seat, net.level.session.Life.DEAD) != net.level.session.Life.DEAD

## A survivor still connected to the floor in play, alive or dead.
func listener(seat: int) -> bool:
	if seat <= 0 or not net.active() or not net.match_net.floor_live: return false
	var session = net.level.session
	return session.state == session.State.PLAYING and net.match_net.is_survivor(seat) \
		and net.players.get(seat, {}).get("connected", false)

func safe_window() -> bool:
	return DisplayServer.get_name() != "headless" and (monitoring or get_tree().root.has_focus())

func action_held() -> bool:
	return InputMap.has_action(ACTION) and Input.is_action_pressed(ACTION)

# --- What the menus read --------------------------------------------------------

func input_level() -> float:
	return detector.meter if microphone != null and microphone.playing else 0.0

func gate_level() -> float:
	return DETECTION.scale(gate_db())

func gate_db() -> float:
	var values: Dictionary = net.level.settings.values
	var variable: bool = values.voice_automatic and values.get("voice_auto_sensitivity", false)
	return detector.gate_db(float(values.voice_sensitivity), variable)

## The settings meter: the microphone open without sending, in or out of a match.
func monitor(on: bool) -> void:
	monitoring = on

func transmitting() -> bool:
	return Time.get_ticks_msec() - last_sent < 100

func speakers() -> Dictionary:
	var now := Time.get_ticks_msec()
	var heard := {}
	for seat: int in streams:
		if streams[seat].talking(now): heard[seat] = float(streams[seat].radio) > RADIO_SHOWN
	return heard

# --- Capture ----------------------------------------------------------------------

func start_microphone() -> void:
	if microphone == null:
		# Effects run before the bus mute. There is no local mic monitor.
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		capture_bus = StringName("MicCapture%d" % get_instance_id())
		AudioServer.set_bus_name(index, capture_bus)
		AudioServer.set_bus_mute(index, true)
		capture = AudioEffectCapture.new()
		capture.buffer_length = 0.25
		AudioServer.add_bus_effect(index, capture)
		microphone = AudioStreamPlayer.new()
		microphone.stream = AudioStreamMicrophone.new()
		microphone.bus = capture_bus
		add_child(microphone)
	capture.clear_buffer()
	# AudioEffectCapture taps the audio mix, after resampling the input stream.
	var rate := AudioServer.get_mix_rate()
	capture_frames = maxi(1, roundi(rate * CODEC.PERIOD))
	detector.configure(rate)
	microphone.play()

func stop_microphone() -> void:
	if microphone == null or not microphone.playing: return
	microphone.stop()
	capture.clear_buffer()
	detector.reset()
	detector.meter = 0.0

func send_capture() -> void:
	var blocks := int(float(capture.get_frames_available()) / capture_frames)
	# The oldest go: the gate carries on as it was, mid-word or not.
	if blocks > MAX_CAPTURE_BLOCKS: capture.get_buffer((blocks - MAX_CAPTURE_BLOCKS) * capture_frames)
	for _block in mini(blocks, MAX_CAPTURE_BLOCKS):
		var frames := capture.get_buffer(capture_frames)
		if frames.is_empty(): break
		forward_input(frames)

func forward_input(frames: PackedVector2Array) -> void:
	var level = net.level
	var heard: Array[PackedVector2Array]
	var open: bool = net.active() and admitted(net.local_seat) and not level.online_menu
	if not open:
		heard = detector.press(frames, false)
	elif capture_automatic:
		heard = detector.feed(frames, gate_db())
	else:
		heard = detector.press(frames, action_held())
	for block in heard: send_block(CODEC.encode(block))

func send_block(packet: PackedByteArray) -> void:
	if not admitted(net.local_seat): return
	sequence += 1
	last_sent = Time.get_ticks_msec()
	var round_id := int(net.match_net.config.get("voice_round", 0))
	if net.is_host:
		relay_block(net.local_seat, round_id, sequence, packet)
	else:
		offer_voice.rpc_id(1, round_id, sequence, packet)

# --- Relay ------------------------------------------------------------------------

func round_accepts(round_id: int, serial: int, packet: PackedByteArray) -> bool:
	return round_id > 0 and int(net.match_net.config.get("voice_round", 0)) == round_id \
		and serial > 0 and packet.size() == CODEC.BYTES

@rpc("any_peer", "call_remote", "unreliable")
func offer_voice(round_id: int, serial: int, packet: PackedByteArray) -> void:
	if not net.is_host: return
	var seat: int = net.seat_of_peer(multiplayer.get_remote_sender_id())
	relay_block(seat, round_id, serial, packet)

func relay_block(seat: int, round_id: int, serial: int, packet: PackedByteArray) -> void:
	if not admitted(seat) or not round_accepts(round_id, serial, packet): return
	var now := Time.get_ticks_msec()
	var budget: Vector2 = budgets.get(seat, Vector2(BURST, now))
	var credit := minf(BURST, budget.x + (now - budget.y) * PACKETS_PER_SECOND / 1000.0)
	if credit < 1.0: return
	budgets[seat] = Vector2(credit - 1.0, now)
	for heard in net.match_net.config.survivors:
		var other := int(heard)
		if other == seat or not listener(other): continue
		if other == net.local_seat:
			hear(seat, serial, packet)
		else:
			play_voice.rpc_id(int(net.players[other].peer), seat, round_id, serial, packet)

@rpc("authority", "call_remote", "unreliable")
func play_voice(seat: int, round_id: int, serial: int, packet: PackedByteArray) -> void:
	if round_accepts(round_id, serial, packet): hear(seat, serial, packet)

func hear(seat: int, serial: int, packet: PackedByteArray) -> void:
	if not listener(net.local_seat) or not admitted(seat) or seat == net.local_seat: return
	if muted_seats.has(seat) or float(net.level.settings.values.voice_volume) <= 0.0: return
	var now := Time.get_ticks_msec()
	if not streams.has(seat):
		streams[seat] = PLAYBACK.new(self)
		routes[seat] = route_for(seat)
	streams[seat].enqueue(serial, packet, now)

# --- Mixing -----------------------------------------------------------------------

func mix_streams(now: int) -> void:
	if streams.is_empty(): return
	var refresh := now >= next_route
	if refresh: next_route = now + ROUTE_PERIOD_MS
	for seat: int in streams.keys():
		var stream = streams[seat]
		if not admitted(seat) or now - int(stream.last_packet) > 1800:
			drop_stream(seat)
		else:
			if refresh: routes[seat] = route_for(seat)
			stream.update(now, routes[seat])

## Heard from the camera on screen: the player's own, or while dead the
## teammate being watched, whose floor then decides "another floor".
func route_for(seat: int) -> Vector4:
	var talker: Node3D = net.match_net.body_of(seat)
	if not is_instance_valid(talker): return Vector4(1.0, 0.0, 0.0, 0.0)
	var audio = net.level.world_audio
	var camera: Camera3D = audio.listener_camera()
	var eye: Vector3 = audio.listener_position()
	var mouth := talker.global_position + Vector3.UP * (1.18 if talker.crouched else 1.56)
	var offset := mouth - eye
	var distance := offset.length()
	var rotated := camera.global_basis.inverse() * offset
	var position := clampf(rotated.x / maxf(distance, 0.6), -1.0, 1.0) * 0.64
	var separated := absf(offset.y) > 3.0
	var blocked: bool = not separated and distance < 13.0 and audio.occluded(mouth, RID(), eye)
	var route := acoustic_route(distance, position, separated, blocked)
	if not blocked and not separated:
		route.w = 0.28 * smoothstep(0.0, 1.0, rotated.z / maxf(distance, 0.6))
	return route

static func acoustic_route(distance: float, position: float, separated: bool, blocked: bool) -> Vector4:
	if separated: return Vector4(1.0, 0.0, 0.0, 0.0)
	var radio := smoothstep(3.2, 12.0, distance)
	var direct := lerpf(0.96, 0.55, smoothstep(1.2, 10.0, distance))
	if blocked:
		radio = maxf(radio, lerpf(0.16, 0.88, smoothstep(1.0, 7.5, distance)))
		direct *= 0.47
	return Vector4(radio, direct, position, 1.0 if blocked else 0.0)

func mute(seat: int, value: bool) -> void:
	if value:
		muted_seats[seat] = net.player_name(seat)
		if streams.has(seat): drop_stream(seat)
	else:
		muted_seats.erase(seat)

func forget_replaced_mutes() -> void:
	for seat: int in muted_seats.keys():
		if muted_seats[seat] != net.player_name(seat): muted_seats.erase(seat)

func drop_stream(seat: int) -> void:
	streams[seat].dispose()
	streams.erase(seat)
	routes.erase(seat)

func clear_streams() -> void:
	for seat: int in streams.keys(): drop_stream(seat)

func reset_round() -> void:
	detector.reset()
	clear_streams()
	budgets.clear()

func _exit_tree() -> void:
	var index := AudioServer.get_bus_index(capture_bus)
	if not capture_bus.is_empty() and index > 0: AudioServer.remove_bus(index)
