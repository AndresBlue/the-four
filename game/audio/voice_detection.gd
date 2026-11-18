extends RefCounted
## The local gate in front of the always-open microphone. Automatic keeps the
## start of a word and bridges short gaps; push to talk opens at once with the
## last blocks already heard and holds a moment after release. Every block is
## measured either way, for the settings meter and the variable threshold.

const ATTACK_BLOCKS := 2
const PRE_ROLL_BLOCKS := 4
const HOLD_BLOCKS := 10
## Push to talk: 60 ms already captured go out with the press, 160 ms after release.
const PRESS_BLOCKS := 3
const RELEASE_BLOCKS := 8
const STRIDE := 2
## Sensitivity 0 needs -30 dBFS, 1 lets in -80; the default 0.2 asks for -40.
const LOUDEST_DB := -30.0
const QUIETEST_DB := -80.0
## The variable threshold sits this far above the room.
const MARGIN_DB := 12.0
## Its floor is the quietest block of the last 1.5 s: speech always dips
## between words, so a voice cannot drag it up, while a fan that stays does.
const FLOOR_BLOCKS := 75
const FLOOR_RISE_DB := 0.06
const METER_FALL := 0.02

var lead_in: Array[PackedVector2Array] = []
var above_threshold := 0
var blocks_left := 0
var low_band := 0.0
var high_pass := 0.0
var level_db := -100.0
var floor_db := -60.0
var recent: Array[float] = []
## input_level(): smoothed, -60 dBFS = 0, 0 dBFS = 1.
var meter := 0.0

static func threshold_db(sensitivity: float) -> float:
	return lerpf(LOUDEST_DB, QUIETEST_DB, clampf(sensitivity, 0.0, 1.0))

static func scale(db: float) -> float:
	return clampf((db + 60.0) / 60.0, 0.0, 1.0)

func configure(rate: float) -> void:
	high_pass = 1.0 - exp(-TAU * 170.0 * STRIDE / maxf(rate, 1.0))
	low_band = 0.0
	floor_db = -60.0
	recent.clear()
	meter = 0.0
	level_db = -100.0
	reset()

## The gate only: the room's level and the meter carry on.
func reset() -> void:
	lead_in.clear()
	above_threshold = 0
	blocks_left = 0

func transmitting() -> bool:
	return blocks_left > 0

func gate_db(sensitivity: float, variable: bool) -> float:
	return clampf(floor_db + MARGIN_DB, QUIETEST_DB, LOUDEST_DB) if variable else threshold_db(sensitivity)

## Automatic: open after ATTACK_BLOCKS above the threshold.
func feed(frames: PackedVector2Array, threshold: float) -> Array[PackedVector2Array]:
	measure(frames)
	if transmitting():
		# A few dB of hysteresis keeps a falling syllable inside.
		if level_db >= threshold - 3.0:
			blocks_left = HOLD_BLOCKS
		else:
			blocks_left -= 1
		return [frames]
	if level_db < threshold:
		above_threshold = 0
		return remember(frames)
	above_threshold += 1
	if above_threshold < ATTACK_BLOCKS: return remember(frames)
	above_threshold = 0
	return open(frames, PRE_ROLL_BLOCKS - 1, HOLD_BLOCKS)

## Push to talk, or a closed channel (held false): never touches the device.
func press(frames: PackedVector2Array, held: bool) -> Array[PackedVector2Array]:
	measure(frames)
	if held and not transmitting(): return open(frames, PRESS_BLOCKS, RELEASE_BLOCKS)
	if held:
		blocks_left = RELEASE_BLOCKS
		return [frames]
	if transmitting():
		blocks_left -= 1
		return [frames]
	return remember(frames)

func remember(frames: PackedVector2Array) -> Array[PackedVector2Array]:
	lead_in.append(frames)
	if lead_in.size() > PRE_ROLL_BLOCKS: lead_in.pop_front()
	return []

func open(frames: PackedVector2Array, before: int, hold: int) -> Array[PackedVector2Array]:
	var heard: Array[PackedVector2Array] = lead_in.slice(maxi(0, lead_in.size() - before))
	heard.append(frames)
	lead_in.clear()
	blocks_left = hold
	return heard

func measure(frames: PackedVector2Array) -> void:
	var energy := 0.0
	for index in range(0, frames.size(), STRIDE):
		var stereo := frames[index]
		var sample := (stereo.x + stereo.y) * 0.5
		low_band += high_pass * (sample - low_band)
		var bright := sample - low_band
		energy += bright * bright
	level_db = linear_to_db(maxf(sqrt(energy * STRIDE / maxf(float(frames.size()), 1.0)), 0.00001))
	var shown := scale(level_db)
	meter = lerpf(meter, shown, 0.5) if shown > meter else maxf(shown, meter - METER_FALL)
	if recent.is_empty(): floor_db = level_db
	recent.append(level_db)
	if recent.size() > FLOOR_BLOCKS: recent.pop_front()
	var quietest: float = recent.min()
	# Down at once with the room, up slowly (3 dB/s).
	floor_db = lerpf(floor_db, quietest, 0.5) if quietest < floor_db else minf(quietest, floor_db + FLOOR_RISE_DB)
