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

static func name_of(kind: int) -> String:
	return NAMES[kind] if kind >= 0 and kind < NAMES.size() else "Algo"
