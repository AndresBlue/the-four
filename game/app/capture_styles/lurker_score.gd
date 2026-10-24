extends RefCounted
## The Lurker's capture, beat by beat (spec_f3_integration 5.2; OFICINAS 6):
## the same names as capture_score.gd, the hotel's, so that whatever reads a
## score reads hers as it reads that one, and a check can hold the two side by
## side. Seconds from the grab, all of them. She takes somebody from behind,
## or from above in a high room or an archive aisle: two hands close on the
## shoulders, the body is turned round on them, her face hangs upside down in
## front of the lens until the camera is let go, she pulls them up into the
## dark, the bite is out of the picture, and the body is let fall.

const ENTRIES := ["back", "above"]

## The two hands close on the shoulders.
const GRAB := 0.3
## Caught from behind, the body is turned round on her hands.
const BACK_TURN_FROM := 0.35
const BACK_TURN_TO := 0.8
## Her face, upside down, until the camera is let go.
const FACE_TIME := 2.33
const BACK_FACE_TIME := 2.33
const SCREAM_AFTER := 0.05
## From above, the face comes down into the picture.
const ARRIVE := 0.25
const JERK_TIME := 0.9
const JERK_LENGTH := 0.06
## The camera is let go at the end of the face plus SWIPE_REACH (2.4).
const SWIPE_REACH := 0.07
const SWIPE_LENGTH := 0.2
## She pulls them up: the picture rises into the dark.
const LIFT_FROM := 1.6
const LIFT_TO := 2.6
## The bite, out of the picture, and the body let fall.
const ARM_TIME := 3.0
const KILL_TIME := 3.15
const DROP_TIME := 3.6
## The fall, as the hotel's.
const FALL_LENGTH := 0.9
const FALL_AIR := 0.5
const FALL_SINK := Vector2(0.5, 0.66)
const FALL_BACK := Vector2(0.62, 0.88)
## She looks at the fallen camera from the ceiling.
const GLANCE_FROM := 4.4
const GLANCE_COCK := 4.68
const CUT_TIME := 5.4
const END_TIME := 5.7

## How far from her the body is held, horizontally; how high she lifts it at
## the most (each capture's own is its extra.lift, under what is overhead).
const HOLD_FAR := Vector2(0.35, 0.55)
const HOLD_NEAR := 0.45
const LIFT_HEIGHT := 1.0
const HOLD_STAND := 0.0

## Laid out or folded up where it drops, as the hotel's.
const LIE_ROOM := 1.4
const FLAT := 1.57
const SEAT_HEIGHT := 0.13

static func seat_back(room: float) -> float:
	return clampf(room - 0.5, 0.08, 0.35)

static func seat_lean(room: float) -> float:
	var back := seat_back(room)
	var shoulders := asin(clampf((room - back - 0.14) / 0.55, 0.0, 1.0))
	var head := asin(clampf((room - back - 0.16) / 0.9, 0.0, 1.0))
	return clampf(minf(shoulders, head), 0.08, FLAT)

static func smooth(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func ramp(time: float, from: float, to: float) -> float:
	return clampf((time - from) / maxf(to - from, 0.0001), 0.0, 1.0)

static func face_end(entry: String) -> float:
	return BACK_FACE_TIME if entry == "back" else FACE_TIME

## From behind the face is there once the body has turned; from above, at once.
static func face_start(entry: String) -> float:
	return BACK_TURN_TO if entry == "back" else 0.0

static func scream_time(entry: String, covered := false) -> float:
	return (0.0 if covered else face_start(entry)) + SCREAM_AFTER

## Her hands closing on the shoulders: 0 open, 1 holding.
static func grab(time: float) -> float:
	return smooth(ramp(time, 0.0, GRAB))

## The hotel's stoop, with her times (nothing of hers bends over: kept for
## the parity of names).
static func stoop(time: float) -> float:
	var down := smooth(ramp(time, 0.0, ARRIVE))
	var up := smooth(ramp(time, LIFT_FROM - 0.1, LIFT_TO - 0.25))
	var over := smooth(ramp(time, DROP_TIME, DROP_TIME + 0.3)) * (1.0 - smooth(ramp(time, GLANCE_FROM - 0.2, GLANCE_FROM + 0.25)))
	return maxf(down * (1.0 - up), over * 0.3)

static func lift(time: float) -> float:
	var dropped := ramp(time, DROP_TIME, DROP_TIME + FALL_LENGTH * FALL_AIR)
	return smooth(ramp(time, LIFT_FROM, LIFT_TO)) * (1.0 - dropped * dropped)

## Never drawn in: she holds them where they are.
static func closing(_time: float) -> float:
	return 0.0

static func limp(time: float) -> float:
	return ramp(time, KILL_TIME, KILL_TIME + 0.3)

static func fall(time: float) -> float:
	return ramp(time, DROP_TIME, DROP_TIME + FALL_LENGTH)

static func sunk(falling: float) -> float:
	return 1.0 - pow(1.0 - ramp(falling, FALL_SINK.x, FALL_SINK.y), 1.6)

static func toppled(falling: float) -> float:
	var t := ramp(falling, FALL_BACK.x, FALL_BACK.y)
	return t * t

static func jolt(falling: float) -> float:
	var t := ramp(falling, FALL_BACK.y, 1.0)
	return sin(PI * t) * (1.0 - t)

## The camera let go: 0 before it, 1 once it is out of the hands.
static func swipe(entry: String, time: float) -> float:
	return ramp(time, face_end(entry), face_end(entry) + SWIPE_LENGTH)

## The bite: 0 before it, 1 landed.
static func thrust(time: float) -> float:
	return ramp(time, ARM_TIME, KILL_TIME)

static func turned(entry: String, time: float) -> float:
	if entry != "back": return 1.0
	return smooth(ramp(time, BACK_TURN_FROM, BACK_TURN_TO))

static func glance(time: float) -> float:
	return smooth(ramp(time, GLANCE_FROM, GLANCE_FROM + 0.3))
