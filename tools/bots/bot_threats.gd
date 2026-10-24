extends RefCounted
## Which threat model the bots mind the floor's creature with (docs/OFICINAS.md,
## 11.6): one per kind of creature (creature.kind_id()), knowing that
## creature's own measures and what a recording keeps of it. The rest of the
## bots ask the model, and the creature only its contract
## (game/enemies/creature.gd).
## The Lurker's is the null creature's until bot_threat_lurker (phase 3:
## with a person's turn and reaction, spec_f2_mind 13).
const MODELS := {&"locust": preload("res://tools/bots/bot_threat.gd"), &"none": preload("res://tools/bots/bot_threat_none.gd"), &"lurker": preload("res://tools/bots/bot_threat_none.gd")}

## A model of the creature on `level`'s floor. With no creature there, The
## Locust's, which then has nothing to mind (bot_threat.refresh), as it always
## had; null for a creature the bots have no model of.
static func make(level) -> RefCounted:
	var kind: StringName = level.creature.kind_id() if is_instance_valid(level.creature) else &"locust"
	var model: Script = MODELS.get(kind)
	if model == null: return null
	return model.new(level)
