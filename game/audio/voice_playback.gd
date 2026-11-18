extends RefCounted
## A teammate's packets, independent of other talkers. The two paths share a
## sample clock so crossing from a voice in the room to the radio has no echo.
## The radio is a 1980s handheld FM set: band-limited, its modulation limiter
## always working, a roger beep at each end and the squelch tail on release.

const CODEC := preload("res://game/audio/voice_codec.gd")
const VOICE_BUS := &"Voices"
const MAX_QUEUE := 12
const WAIT_MS := 55
const HOLD_MS := 155
## On the radio a pause shorter than this is the same call: a talker keeps the
## key down through a sentence, so no beeps between phrases, only the hiss.
const OVER_MS := 700
## Blocks late this long are a pause, not jitter.
const PAUSE_MS := 150
const OPEN := 1.0 - exp(-TAU * 7200.0 / CODEC.RATE)
const MUFFLED := 1.0 - exp(-TAU * 1150.0 / CODEC.RATE)
const DC := 1.0 - exp(-TAU * 95.0 / CODEC.RATE)
## Above this blend the beeps and the squelch tail belong to the call.
const RADIO_EVENTS := 0.42
## Microphone AGC and modulation limiter: fast attack, 60 ms release.
const AGC_ATTACK := 1.0 - exp(-1.0 / (0.001 * CODEC.RATE))
const AGC_RELEASE := 1.0 - exp(-1.0 / (0.06 * CODEC.RATE))
const AGC_TARGET := 0.45
const AGC_MAX := 6.0
const DRIVE := 5.0
const RADIO_OUT := 0.25
## Roger beeps: higher on key-up, lower on release.
const BEEP_OPEN := Vector2(1350.0, 0.08)
const BEEP_CLOSE := Vector2(1050.0, 0.1)
const BEEP_LEVEL := 0.15
const BEEP_RAMP := 0.004 * CODEC.RATE
## About 35 dB under the voice, as on a real CB FM recording (evidence/voz).
const HISS := 0.08 * RADIO_OUT
const TAIL_SECONDS := 0.15
const TAIL_LEVEL := RADIO_OUT

var player: AudioStreamPlayer
var output: AudioStreamGeneratorPlayback
var queue := {}
var last_sequence := -1
var next_sequence := -1
var last_packet := 0
var first_packet := 0
var capacity := 0
var started := false
var ending := false
var was_audible := false
var updated_at := 0
var frame_peak := 17.0
## The driver pulls this much at a time (ms): the buffer must outlast it too.
var latency := 0.0
var last_voice := PackedFloat32Array()
var concealed := false
var radio := 0.0
var direct := 0.0
var pan := 0.0
var obstruction := 0.0
var direct_low := 0.0
var dc_offset := 0.0
var noise_state := 9031
var agc := 0.0
var carrier := false
var beep_hz := 0.0
var beep_left := 0
var beep_done := 0
var beep_phase := 0.0
var tail_left := 0
## A steep 330 Hz high-pass (6th order, as the tone-squelch filter of an FM
## set) split around the limiter, so its second part also drops the
## difference tones the limiter makes; the small speaker's presence peak; a
## 4th-order 3 kHz low-pass, the splatter filter.
var stages: Array[PackedFloat64Array] = []
var memory := PackedFloat64Array()

func _init(parent: Node) -> void:
	stages.append(biquad(true, 330.0, 1.9319))
	stages.append(peak(2200.0, 0.7, 6.0))
	stages.append(biquad(true, 330.0, 0.7071))
	stages.append(biquad(true, 330.0, 0.5176))
	for q in [0.5412, 1.3066]: stages.append(biquad(false, 3000.0, q))
	memory.resize(stages.size() * 2)
	latency = AudioServer.get_output_latency() * 1000.0
	if parent == null: return
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = CODEC.RATE
	# Room for a 15 fps frame on top of the jitter allowance.
	stream.buffer_length = 0.2
	player = AudioStreamPlayer.new()
	player.name = "TeamVoice"
	player.bus = VOICE_BUS
	player.stream = stream
	parent.add_child(player)

func dispose() -> void:
	if player == null: return
	player.stop()
	player.queue_free()

func enqueue(sequence: int, packet: PackedByteArray, now: int) -> void:
	if sequence <= last_sequence or queue.has(sequence): return
	if queue.is_empty(): first_packet = now
	queue[sequence] = packet
	last_packet = now
	while queue.size() > MAX_QUEUE:
		var oldest: int = queue.keys().min()
		queue.erase(oldest)
		last_sequence = oldest
		if next_sequence <= oldest: next_sequence = -1

func talking(now: int) -> bool:
	return started and not ending and now - last_packet < HOLD_MS

func hold_ms() -> int:
	return OVER_MS if was_audible and radio > RADIO_EVENTS else HOLD_MS

func ringing() -> bool:
	return beep_left > 0 or tail_left > 0

func update(now: int, route: Vector4) -> void:
	# The slowest recent frame and the driver's own pull set how far ahead the
	# generator is kept, so a low frame rate never lets it run dry.
	var frame: float = clampf(float(now - updated_at), 0.0, 120.0) if updated_at > 0 else 17.0
	updated_at = now
	frame_peak = maxf(frame, frame_peak * 0.98)
	var lead := ceili((frame_peak + latency) / (CODEC.PERIOD * 1000.0)) + 1
	if not started:
		if queue.is_empty() or (queue.size() < lead and now - first_packet < WAIT_MS + frame_peak): return
		if output == null:
			player.play()
			output = player.get_stream_playback() as AudioStreamGeneratorPlayback
			if output == null: return
			capacity = output.get_frames_available()
		started = true
		ending = false
		next_sequence = -1
		radio = route.x
		direct = route.y
		pan = route.z
		obstruction = route.w
		was_audible = false
		last_voice = PackedFloat32Array()
	if not ending and now - last_packet >= hold_ms():
		ending = true
		queue.clear()
		if was_audible: close_carrier()
	var target := mini(lead * CODEC.SAMPLES, capacity - CODEC.SAMPLES)
	# Blocks piling up here mean the device pulls in bigger gulps than the
	# target: feed them anyway rather than let the queue drop them.
	while output.get_frames_available() >= CODEC.SAMPLES and (capacity - output.get_frames_available() < target or queue.size() > lead + 2):
		if ending:
			if not ringing(): break
			output.push_buffer(render(PackedFloat32Array(), route))
			continue
		if queue.is_empty():
			# A pause in the call, not late packets (the sender's hang time is
			# longer than PAUSE_MS): the open carrier keeps hissing.
			if carrier and now - last_packet > PAUSE_MS:
				output.push_buffer(render(PackedFloat32Array(), route))
				continue
			break
		var first: int = queue.keys().min()
		if next_sequence < 0 or first > next_sequence + 2: next_sequence = first
		var packet: PackedByteArray = queue.get(next_sequence, PackedByteArray())
		queue.erase(next_sequence)
		last_sequence = next_sequence
		next_sequence += 1
		var voice := take(packet)
		if not was_audible and not voice.is_empty():
			open_carrier()
			was_audible = true
		output.push_buffer(render(voice, route))
	if ending and not ringing():
		started = false
		ending = false
		was_audible = false
		carrier = false

## packet empty: lost. The block before plays once more at -6 dB, then silence.
func take(packet: PackedByteArray) -> PackedFloat32Array:
	if not packet.is_empty():
		last_voice = CODEC.decode(packet)
		concealed = false
		return last_voice
	if concealed or last_voice.is_empty(): return PackedFloat32Array()
	concealed = true
	var quieter := last_voice.duplicate()
	for index in quieter.size(): quieter[index] *= 0.5
	return quieter

func open_carrier() -> void:
	carrier = true
	if radio > RADIO_EVENTS: beep(BEEP_OPEN)

func close_carrier() -> void:
	if radio <= RADIO_EVENTS:
		carrier = false
		return
	beep(BEEP_CLOSE)
	tail_left = roundi(TAIL_SECONDS * CODEC.RATE)

func beep(tone: Vector2) -> void:
	beep_hz = tone.x
	beep_left = roundi(tone.y * CODEC.RATE)
	beep_done = 0
	beep_phase = 0.0

## voice: decoded samples, empty for silence. route: radio blend, direct gain,
## pan, wall obstruction. Interpolate per block to keep turning, leaning and
## moving through a doorway click-free.
func render(voice: PackedFloat32Array, route: Vector4) -> PackedVector2Array:
	var frames := PackedVector2Array()
	frames.resize(CODEC.SAMPLES)
	var next_radio := lerpf(radio, route.x, 0.22)
	var next_direct := lerpf(direct, route.y, 0.28)
	var next_pan := lerpf(pan, route.z, 0.45)
	var next_obstruction := lerpf(obstruction, route.w, 0.25)
	var low := lerpf(OPEN, MUFFLED, next_obstruction)
	var clean := PackedFloat32Array()
	clean.resize(CODEC.SAMPLES)
	for index in CODEC.SAMPLES:
		var raw: float = voice[index] if not voice.is_empty() else 0.0
		dc_offset += DC * (raw - dc_offset)
		clean[index] = raw - dc_offset
	var air := PackedFloat32Array()
	if maxf(radio, next_radio) > 0.001 or ringing(): air = transmit(clean)
	for index in CODEC.SAMPLES:
		direct_low += low * (clean[index] - direct_low)
		var t := float(index + 1) / CODEC.SAMPLES
		var blend := lerpf(radio, next_radio, t)
		var position := lerpf(pan, next_pan, t)
		var room := direct_low * lerpf(direct, next_direct, t) * (1.0 - blend)
		var centre: float = air[index] * blend if not air.is_empty() else 0.0
		frames[index] = Vector2(centre + room * (1.0 - maxf(position, 0.0)), centre + room * (1.0 + minf(position, 0.0)))
	radio = next_radio
	direct = next_direct
	pan = next_pan
	obstruction = next_obstruction
	return frames

## The radio path: microphone band, AGC into a soft limiter, the beeps keyed
## in by the transmitter, the receiver's hiss and squelch tail, then the
## audio band of the receiver over all of it.
func transmit(clean: PackedFloat32Array) -> PackedFloat32Array:
	var air := filter(filter(clean, 0), 1)
	var tail_length := TAIL_SECONDS * CODEC.RATE
	for index in CODEC.SAMPLES:
		var sample := air[index]
		var size := absf(sample)
		agc += (AGC_ATTACK if size > agc else AGC_RELEASE) * (size - agc)
		sample *= minf(AGC_MAX, AGC_TARGET / maxf(agc, 0.0001))
		var tone := 0.0
		var noise := 0.0
		if beep_left > 0 or tail_left > 0 or carrier:
			noise_state = (noise_state * 16807) % 2147483647
			noise = float(noise_state & 1023) / 511.5 - 1.0
		if beep_left > 0:
			var edge := minf(1.0, minf(beep_done, beep_left) / BEEP_RAMP)
			beep_phase += TAU * beep_hz / CODEC.RATE
			tone = sin(beep_phase) * BEEP_LEVEL * edge
			sample *= 1.0 - 0.8 * edge
			beep_left -= 1
			beep_done += 1
			noise *= HISS
		elif tail_left > 0:
			# Carrier gone: full receiver noise until the squelch shuts.
			var left := float(tail_left) / tail_length
			noise *= TAIL_LEVEL * minf(1.0, left * 4.0) * minf(1.0, (1.0 - left) * tail_length / BEEP_RAMP + 0.2)
			tail_left -= 1
			if tail_left == 0: carrier = false
		else:
			noise *= HISS
		air[index] = tanh((sample + tone) * DRIVE) * RADIO_OUT + noise
	return filter(filter(filter(filter(air, 2), 3), 4), 5)

func filter(block: PackedFloat32Array, stage: int) -> PackedFloat32Array:
	var c: PackedFloat64Array = stages[stage]
	var b0 := c[0]
	var b1 := c[1]
	var b2 := c[2]
	var a1 := c[3]
	var a2 := c[4]
	var z1 := memory[stage * 2]
	var z2 := memory[stage * 2 + 1]
	for index in block.size():
		var x := block[index]
		var y := b0 * x + z1
		z1 = b1 * x - a1 * y + z2
		z2 = b2 * x - a2 * y
		block[index] = y
	memory[stage * 2] = z1
	memory[stage * 2 + 1] = z2
	return block

## RBJ cookbook section, normalised: b0, b1, b2, a1, a2.
static func biquad(high: bool, hz: float, q: float) -> PackedFloat64Array:
	var w := TAU * hz / CODEC.RATE
	var alpha := sin(w) / (2.0 * q)
	var c := cos(w)
	var a0 := 1.0 + alpha
	var edge: float = (1.0 + c) * 0.5 if high else (1.0 - c) * 0.5
	var middle: float = -(1.0 + c) if high else 1.0 - c
	return PackedFloat64Array([edge / a0, middle / a0, edge / a0, -2.0 * c / a0, (1.0 - alpha) / a0])

static func peak(hz: float, q: float, db: float) -> PackedFloat64Array:
	var w := TAU * hz / CODEC.RATE
	var alpha := sin(w) / (2.0 * q)
	var gain := pow(10.0, db / 40.0)
	var a0 := 1.0 + alpha / gain
	return PackedFloat64Array([(1.0 + alpha * gain) / a0, -2.0 * cos(w) / a0, (1.0 - alpha * gain) / a0, -2.0 * cos(w) / a0, (1.0 - alpha / gain) / a0])
