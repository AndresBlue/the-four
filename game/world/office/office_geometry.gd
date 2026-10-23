extends "res://game/world/hotel/hotel_geometry.gd"
## The offices' geometry (.claude/specs/spec_f1_geometry.md) as step 1d begins
## it: the hotel's, through its hooks, on the office's finishes. Until the
## office's own materials are ingested (spec 4.4 and 10), each finish the
## palette names stands in as the nearest hotel material, marked "stand_in".
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
## A finish of the office palette (floor_finish(), wall_material()) and the
## hotel material that stands in for it.
const STAND_INS := {"vinyl": "tile", "terrazzo": "tile", "concrete": "ceiling_service", "office_paint": "plaster", "block": "plaster_decrepit", "veneer": "panel", "laminate": "wood", "enamel": "ceramic", "steel_olive": "metal", "steel_frame": "metal", "cardboard": "fabric", "bottle": "mirror"}
const PROPS := preload("res://game/world/office/office_props.gd")

func _init() -> void:
	super()
	for key in STAND_INS:
		var path := "res://game/presentation/materials/office/%s.tres" % key
		if ResourceLoader.exists(path):
			materials[key] = load(path).duplicate()
			materials[key].set_meta("lite", key)
			apply_scan(materials[key], small_maps)
		else:
			materials[key] = materials[STAND_INS[key]].duplicate()
			materials[key].set_meta("stand_in", true)

## The office's corner pieces first (9.3); the hotel's own kinds as the hotel.
func build_prop(node: Node3D, kind: String) -> void:
	if not PROPS.build(self, node, kind): super(node, kind)

## Archives are all shelving: no dressing on their walls (9.5).
func wall_stretches(room: Dictionary) -> Array:
	if int(room.type) == OFFICE.ARCHIVE or int(room.type) == OFFICE.MOBILE_ARCHIVE: return []
	return super(room)

## Furniture keeps clear of the walls by less in an office (H3).
func nav_agent_radius() -> float: return 0.3
