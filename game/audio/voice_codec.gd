extends RefCounted
## One independently decodable 20 ms block of 16 kHz mono IMA ADPCM. The header
## carries the predictor and step index, so a lost datagram needs no decoder
## reset, and the block fits below either transport's MTU.

const RATE := 16000
const SAMPLES := 320
const PERIOD := float(SAMPLES) / RATE
## Predictor (int16) and step index, then one nibble for each later sample.
const HEADER := 3
const BYTES := HEADER + SAMPLES / 2
const INDEX_STEP: Array[int] = [-1, -1, -1, -1, 2, 4, 6, 8]
const STEPS: Array[int] = [7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45,
	50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307,
	337, 371, 408, 449, 494, 544, 598, 658, 724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
	2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899,
	15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767]

## frames: one block of capture at any rate, resampled here to RATE.
static func encode(frames: PackedVector2Array) -> PackedByteArray:
	var pcm := resample(frames)
	var packet := PackedByteArray()
	packet.resize(BYTES)
	var predictor := pcm[0]
	# Start the step near the block's opening slope: no state is carried over.
	var slope := 0
	for i in range(1, 17): slope += absi(pcm[i] - pcm[i - 1])
	var index := mini(STEPS.bsearch(slope / 16), 88)
	packet.encode_s16(0, predictor)
	packet[2] = index
	for i in range(1, SAMPLES):
		var step: int = STEPS[index]
		var diff := pcm[i] - predictor
		var nibble := 0
		if diff < 0:
			nibble = 8
			diff = -diff
		var moved := step >> 3
		if diff >= step:
			nibble |= 4
			diff -= step
			moved += step
		if diff >= step >> 1:
			nibble |= 2
			diff -= step >> 1
			moved += step >> 1
		if diff >= step >> 2:
			nibble |= 1
			moved += step >> 2
		predictor = clampi(predictor - moved if (nibble & 8) != 0 else predictor + moved, -32768, 32767)
		index = clampi(index + INDEX_STEP[nibble & 7], 0, 88)
		var at := HEADER + ((i - 1) >> 1)
		packet[at] = packet[at] | (nibble << 4 if ((i - 1) & 1) == 1 else nibble)
	return packet

static func decode(packet: PackedByteArray) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(SAMPLES)
	var predictor := packet.decode_s16(0)
	var index := clampi(packet[2], 0, 88)
	out[0] = predictor / 32768.0
	for i in range(1, SAMPLES):
		var nibble: int = (packet[HEADER + ((i - 1) >> 1)] >> (4 if ((i - 1) & 1) == 1 else 0)) & 15
		var step: int = STEPS[index]
		var moved := step >> 3
		if (nibble & 4) != 0: moved += step
		if (nibble & 2) != 0: moved += step >> 1
		if (nibble & 1) != 0: moved += step >> 2
		predictor = clampi(predictor - moved if (nibble & 8) != 0 else predictor + moved, -32768, 32767)
		index = clampi(index + INDEX_STEP[nibble & 7], 0, 88)
		out[i] = predictor / 32768.0
	return out

## Mono int16 at RATE. A triangular window two input periods wide is the
## anti-alias filter: from 48 kHz it keeps the 8-16 kHz band 19 dB down.
static func resample(frames: PackedVector2Array) -> PackedInt32Array:
	var pcm := PackedInt32Array()
	pcm.resize(SAMPLES)
	var count := frames.size()
	var step := float(count) / SAMPLES
	for index in SAMPLES:
		var centre := (index + 0.5) * step - 0.5
		var from := maxi(0, ceili(centre - step))
		var until := mini(count - 1, floori(centre + step))
		var sum := 0.0
		var weight := 0.0
		for input in range(from, until + 1):
			var w := 1.0 - absf(input - centre) / step
			if w <= 0.0: continue
			var stereo := frames[input]
			sum += (stereo.x + stereo.y) * 0.5 * w
			weight += w
		pcm[index] = clampi(roundi(sum / maxf(weight, 0.0001) * 32767.0), -32768, 32767)
	return pcm
