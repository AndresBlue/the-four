extends RefCounted
## What made a noise. The AI ignores this (it only cares where and how loud),
## but the player who drives The Locust sees the noises it hears as part of its
## acoustic image, and the image has to answer "what was that": a footstep does
## not look like a door slamming. One source of truth for the player, the
## doors, the wardrobes, the network and the shader.
enum Kind { FOOTSTEP, RUN, JUMP, DOOR, SLAM, WARDROBE, PEEK, HUM }

## For captions and debugging; never shown as a label in the acoustic image.
const NAMES := ["Pasos", "Carrera", "Salto", "Una puerta", "Un portazo", "Un armario", "Una rendija", "Un zumbido"]

## How sharp the contact reads: a footstep is a point, a slam floods the room.
const SPREAD := [0.8, 1.0, 1.0, 1.15, 1.6, 0.9, 0.6, 0.5]

## How far The Locust hears each noise, in metres: straight when it has the
## spot in sight, otherwise along the walking route. A noise's radius (what
## everything passes around) is this over HEARING_SCALE, which is the one
## place that turns a radius back into metres (hotel_locust.hear_route).
## "_hard" is the same noise on tile (bathrooms, laundry, maintenance).
## "wardrobe_hunter" is getting in or out of a wardrobe as a human Locust
## hears it: from the next rooms, where the AI only hears it close.
const HEARING_SCALE := 2.6
const HEARD := {
	"peek": 10.5,
	"crouch": 8.0, "crouch_hard": 12.0,
	"door_slow": 9.0,
	"wardrobe": 12.0,
	"walk": 20.0, "walk_hard": 25.0,
	"jump": 32.0,
	"door": 45.0,
	"wardrobe_hunter": 45.0,
	"slam": 62.0,
	"run": 52.0, "run_hard": 64.0,
}

static func radius(noise: String) -> float:
	return float(HEARD[noise]) / HEARING_SCALE
