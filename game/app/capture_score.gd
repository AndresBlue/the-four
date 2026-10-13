extends RefCounted
## The capture, beat by beat (docs/EXECUTION.md, section 6): every time of the
## scene and every curve that is a function of nothing but its clock. One
## place, read by whoever plays a part in it -- the level, which puts the
## bodies (executions.gd); the creature, which poses itself (locust_visual.gd);
## and the tape of whoever dies (death_tape.gd) -- so that on every machine,
## at any frame rate, the same second of the scene is the same picture.
## Seconds from the grab (`T0`), all of them.

## How somebody is caught, which is the first second of the scene. The host
## chooses (executions.choose_entry); "busy" is not one of these: it is the
## victim's own tape laid over whichever the host chose.
const ENTRIES := ["front", "back", "side", "above", "wardrobe", "ambush"]

## The face: how long the mask is held in front of the lens before the swipe.
## Caught from behind there is no face at first: the arm comes through, the
## body is turned round on it, and the face is there when it has turned.
const FACE_TIME := 0.55
const BACK_TURN_FROM := 0.12
const BACK_TURN_TO := 0.34
const BACK_FACE_TIME := 0.68
## The scream comes this long after the mask is first in front of the lens,
## never before it: caught from behind, it used to start a third of a second
## ahead of anything to scream at.
const SCREAM_AFTER := 0.05
## The head arrives: how long the creature takes to be bent over its victim,
## which on the tape is the mask reaching its place (three to five frames).
const ARRIVE := 0.07
## The last jerk of the face towards the lens, with the head cocking.
const JERK_TIME := 0.22
const JERK_LENGTH := 0.04
## The swipe: from the end of the face, the arm is at the lens after
## SWIPE_REACH and through it by SWIPE_LENGTH.
const SWIPE_REACH := 0.07
const SWIPE_LENGTH := 0.24
## The body is lifted only once the camera is on the floor to see it -- and
## a camcorder takes what a thing takes to fall from a hand, hop and roll
## over to where it stays (camera_fall.route): the creature straightens up
## and brings the body up with it, slowly.
const LIFT_FROM := 1.6
const LIFT_TO := 2.7
## The blow: the arm starts, lands, and the body is let fall.
const ARM_TIME := 3.08
const KILL_TIME := 3.3
const DROP_TIME := 3.6
## How long the body takes to be on the floor once it is let go.
const FALL_LENGTH := 0.42
## The look at the lens, when there is one: the head turns, cocks, and stays.
const GLANCE_FROM := 4.0
const GLANCE_COCK := 4.28
## The tape ends: the picture and the creature's hold are the same second
## (hotel_locust.EXECUTION_TIME).
const CUT_TIME := 4.7
## And the death is the level's to register, a moment after (the snow covers
## whatever the network is late with).
const END_TIME := 5.0

## How far the victim is held from the creature (metres along its facing):
## during the face no nearer and no further than this, and drawn in to
## HOLD_NEAR as it is lifted. How high it is lifted.
const HOLD_FAR := Vector2(0.75, 1.05)
const HOLD_NEAR := 0.6
const LIFT_HEIGHT := 1.0
const HOLD_STAND := 0.1

## The floor a body needs behind it to be laid out (metres from where it is
## let go). With less than that it folds up where it drops: sitting, its hips
## a little back from there and its back against whatever stopped it.
const LIE_ROOM := 1.9
## How high the hips of somebody sitting on the floor are.
const SEAT_HEIGHT := 0.13

## Folded up with `room` metres behind it: how far back the hips come down.
static func seat_back(room: float) -> float:
	return clampf(room - 0.5, 0.08, 0.35)

## And how far back the trunk leans (radians from upright): until the
## shoulders, or the head, meet what is behind; flat on its back, knees up,
## where the nearest thing behind is further than it reaches.
static func seat_lean(room: float) -> float:
	var back := seat_back(room)
	var shoulders := asin(clampf((room - back - 0.14) / 0.55, 0.0, 1.0))
	var head := asin(clampf((room - back - 0.16) / 0.9, 0.0, 1.0))
	return clampf(minf(shoulders, head), 0.08, 1.45)

static func smooth(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

static func ramp(time: float, from: float, to: float) -> float:
	return clampf((time - from) / maxf(to - from, 0.0001), 0.0, 1.0)

## When the face ends and the swipe starts, for an entry.
static func face_end(entry: String) -> float:
	return BACK_FACE_TIME if entry == "back" else FACE_TIME

## When the mask is first in front of the lens.
static func face_start(entry: String) -> float:
	return BACK_TURN_TO if entry == "back" else 0.0

## When the scream starts: `covered`, something was up over the victim's
## picture and the face is there from the first frame, however it was caught.
static func scream_time(entry: String, covered := false) -> float:
	return (0.0 if covered else face_start(entry)) + SCREAM_AFTER

## 0 upright, 1 bent over its victim with the mask at the lens. It is there
## at once and stays until it straightens to lift; over the body, afterwards,
## it stoops a little to look at it.
static func stoop(time: float) -> float:
	var down := smooth(ramp(time, 0.0, ARRIVE))
	var up := smooth(ramp(time, LIFT_FROM - 0.1, LIFT_TO - 0.25))
	var over := smooth(ramp(time, DROP_TIME, DROP_TIME + 0.3)) * (1.0 - smooth(ramp(time, GLANCE_FROM - 0.2, GLANCE_FROM + 0.25)))
	return maxf(down * (1.0 - up), over * 0.3)

## 0 on its feet, 1 held up, and back to 0 as it is let fall.
static func lift(time: float) -> float:
	return smooth(ramp(time, LIFT_FROM, LIFT_TO)) * (1.0 - ramp(time, DROP_TIME, DROP_TIME + FALL_LENGTH * 0.45))

## 0 at arm's length, 1 drawn in to the creature's face.
static func closing(time: float) -> float:
	return smooth(ramp(time, LIFT_FROM, ARM_TIME - 0.15))

## 0 alive on the arm, 1 hanging from it.
static func limp(time: float) -> float:
	return ramp(time, KILL_TIME, KILL_TIME + 0.3)

## 0 held, 1 lying on the floor.
static func fall(time: float) -> float:
	return ramp(time, DROP_TIME, DROP_TIME + FALL_LENGTH)

## The swipe that takes the camera, 0 before it and 1 once the arm is past.
static func swipe(entry: String, time: float) -> float:
	return ramp(time, face_end(entry), face_end(entry) + SWIPE_LENGTH)

## The arm that kills: 0 drawn back, 1 through.
static func thrust(time: float) -> float:
	var t := ramp(time, ARM_TIME, KILL_TIME)
	return t * t * t

## How far round the body has been turned on the arm, caught from behind.
static func turned(entry: String, time: float) -> float:
	if entry != "back": return 1.0
	return smooth(ramp(time, BACK_TURN_FROM, BACK_TURN_TO))

## The look at the lens: 0 not looking, 1 turned to it.
static func glance(time: float) -> float:
	return smooth(ramp(time, GLANCE_FROM, GLANCE_FROM + 0.3))
