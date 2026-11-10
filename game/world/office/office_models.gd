extends RefCounted
## The offices' things that are a download or its stand-in (spec_rediseno
## 5.1, area 4c): each kind's model where the project has one (baked by
## tools/props/build_catalogue.gd: the offices' own in assets/props/office/,
## ingested by ingest_models.py --set=office, or the hotel's in
## assets/props/hotel/), and the piece made in code that stands in for it
## where there is none or its file is missing (pieces/stand_ins.gd,
## pieces/desk_things.gd and areas 4a's and 5's pieces). put() lays either
## with builder.place(): one MultiMesh per room and mesh, its front to +Z and
## its feet on the floor.
const STAND := preload("res://game/world/office/pieces/stand_ins.gd")
const THINGS := preload("res://game/world/office/pieces/desk_things.gd")
const MACHINES := preload("res://game/world/office/pieces/machines.gd")
const STATIONERY := preload("res://game/world/office/pieces/stationery.gd")
const WALL := preload("res://game/world/office/pieces/wall.gd")
const EQ_MAIL := preload("res://game/world/office/pieces/mail_equipment.gd")
## kind -> "paths" (its models, one by pick) and, where it says so, "scale"
## (1: as baked), "height" (the height it is brought to), "seat" (a chair or a
## sofa: its front found from where its back is, backed()) and "pot" (the key
## of the pot a plant that comes without one stands in).
const MODELS := {
	"stacking_chair": {"paths": ["res://assets/props/hotel/SchoolChair_01.res"], "scale": 0.8, "seat": true},
	"waiting_chair": {"paths": ["res://assets/props/hotel/GreenChair_01.res"], "height": 0.9, "seat": true},
	"armchair": {"paths": ["res://assets/props/hotel/ArmChair_01.res"], "seat": true},
	"dining_chair": {"paths": ["res://assets/props/hotel/dining_chair_02.res"], "seat": true},
	# sofa_02 is baked facing +Z, its arms reaching out past its back: backed() would turn it round.
	"sofa": {"paths": ["res://assets/props/office/sofa_02.res"]},
	"lounge_chair": {"paths": ["res://assets/props/office/mid_century_lounge_chair.res"], "seat": true},
	"office_chair": {"paths": []},
	"exec_chair": {"paths": []},
	"visitor_chair": {"paths": []},
	"plant": {"paths": ["res://assets/props/office/potted_plant_01.res", "res://assets/props/hotel/potted_plant_02.res"]},
	"plant_bare": {"paths": ["res://assets/props/office/anthurium_botany_01_a.res", "res://assets/props/office/pachira_aquatica_01_c.res", "res://assets/props/office/calathea_orbifolia_01_a.res"], "pot": "steel_dark"},
	"plant_tall": {"paths": ["res://assets/props/office/pachira_aquatica_01_d.res"], "height": 1.45, "pot": "steel_dark"},
	"plant_small": {"paths": ["res://assets/props/office/calathea_orbifolia_01_c.res", "res://assets/props/office/anthurium_botany_01_c.res"], "height": 0.25, "pot": "ceramic"},
	"wall_clock": {"paths": ["res://assets/props/hotel/wall_clock.res"]},
	"fire_alarm": {"paths": ["res://assets/props/hotel/fire_alarm.res"]},
	"bin": {"paths": ["res://assets/props/hotel/metal_trash_can_clean.res"], "scale": 0.62},
	"books": {"paths": ["res://assets/props/hotel/book_encyclopedia_set_01.res"]},
	"box": {"paths": ["res://assets/props/hotel/cardboard_box_01.res"]},
	"clipboard": {"paths": ["res://assets/props/hotel/clipboard.res"]},
	"stationery": {"paths": ["res://assets/props/hotel/stationery_supplies.res"]},
	"notepad": {"paths": ["res://assets/props/hotel/office_notepads_pad.res"]},
	"jug": {"paths": ["res://assets/props/hotel/jug_01.res"]},
}
## The pots by key (stand_ins.gd plant_pot()).
const POTS := {"steel_dark": Vector3(0.4, 0.38, 0.4), "ceramic": Vector3(0.2, 0.16, 0.2)}
## A lamp's light in the lamp's own frame: where it is, the point it is aimed
## at, its colour, energy, reach and angle (office_geometry.accent_spot()).
## The floor lamp's sits between its pole's tip and its shade's disc, so that
## neither shadows it.
const LIGHTS := {
	"desk_lamp_banker": {"at": Vector3(0, 0.28, 0.02), "aim": Vector3(0, 0, 0.35), "colour": Color(1.0, 0.84, 0.62), "energy": 1.4, "reach": 2.8, "angle": 42.0},
	"desk_lamp_arm": {"at": Vector3(0, 0.4, 0.1), "aim": Vector3(0, 0, 0.32), "colour": Color(1.0, 0.86, 0.66), "energy": 1.4, "reach": 2.6, "angle": 40.0},
	"floor_lamp": {"at": Vector3(0, 1.277, 0), "aim": Vector3(0, 0, 0.2), "colour": Color(1.0, 0.82, 0.6), "energy": 1.0, "reach": 2.4, "angle": 70.0},
	"vending": {"at": Vector3(0, 1.65, 0.45), "aim": Vector3(0, 0.2, 1.6), "colour": Color(0.86, 0.92, 1.0), "energy": 0.7, "reach": 3.5, "angle": 70.0},
}
## The models loaded, by path (null: not in the project).
static var models := {}
## Whether each seat model's back is on its +Z side, by instance.
static var backs := {}

## The kind's model (by pick among its paths) if its file is there, else its
## stand-in; null for a kind with neither.
static func mesh_of(builder: Node3D, kind: String, pick := 0) -> Mesh:
	var spec: Dictionary = MODELS.get(kind, {})
	var paths: Array = spec.get("paths", [])
	if not paths.is_empty():
		var path: String = paths[posmod(pick, paths.size())]
		if not models.has(path): models[path] = load(path) if ResourceLoader.exists(path) else null
		if models[path] != null: return models[path]
	return stand_in(builder, kind)

## Lays the kind's model or stand-in at `xform` in `parent` (pick: which of
## its models), a plant that comes without a pot in its pot; returns the
## transform it is drawn with.
static func put(builder: Node3D, parent: Node3D, kind: String, xform: Transform3D, pick := 0) -> Transform3D:
	var mesh := mesh_of(builder, kind, pick)
	if mesh == null: return xform
	var spec: Dictionary = MODELS.get(kind, {})
	var base := xform
	var pot := String(spec.get("pot", ""))
	if not pot.is_empty() and not mesh.has_meta("piece"):
		var pot_size: Vector3 = POTS.get(pot, Vector3(0.4, 0.38, 0.4))
		builder.place(parent, STAND.plant_pot(builder, pot_size, pot), xform)
		base = xform * Transform3D(Basis.IDENTITY, Vector3(0, pot_size.y - 0.01, 0))
	var drawn := base * fit_of(kind, mesh)
	builder.place(parent, mesh, drawn)
	return drawn

## The kind's size as drawn (its model's or stand-in's, brought to scale).
static func size_of(builder: Node3D, kind: String) -> Vector3:
	var mesh := mesh_of(builder, kind)
	if mesh == null: return Vector3.ZERO
	return mesh.get_aabb().size * fit_of(kind, mesh).basis.get_scale().x

## How a kind's model is brought to its place: its scale, and a half turn for
## a seat baked facing -Z. A stand-in is drawn as it was made.
static func fit_of(kind: String, mesh: Mesh) -> Transform3D:
	if mesh.has_meta("piece"): return Transform3D.IDENTITY
	var spec: Dictionary = MODELS.get(kind, {})
	var factor := float(spec.get("scale", 1.0))
	var height := float(spec.get("height", 0.0))
	if height > 0.0 and mesh.get_aabb().size.y > 0.001: factor = height / mesh.get_aabb().size.y
	var yaw: float = PI if bool(spec.get("seat", false)) and backed(mesh) else 0.0
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * factor), Vector3.ZERO)

## Whether a seat's back is on its +Z side as baked (its front then is -Z):
## the mean z of what stands in its top third.
static func backed(mesh: Mesh) -> bool:
	var id := mesh.get_instance_id()
	if backs.has(id): return backs[id]
	var top := mesh.get_aabb().end.y * 0.66
	var sum := 0.0
	var count := 0
	for s in mesh.get_surface_count():
		var vertices: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for v in vertices:
			if v.y > top:
				sum += v.z
				count += 1
	backs[id] = count > 0 and sum / count > 0.0
	return backs[id]

## The stand-in made in code for a kind (spec_rediseno 5.1: every kind has
## one); null for a kind that has only its model.
static func stand_in(builder: Node3D, kind: String) -> Mesh:
	match kind:
		"office_chair": return STAND.office_chair(builder, Vector3(0.6, 0.95, 0.6))
		"exec_chair": return STAND.exec_chair(builder, Vector3(0.68, 1.15, 0.66))
		"visitor_chair", "stacking_chair", "waiting_chair", "armchair", "dining_chair", "sofa", "lounge_chair": return STAND.visitor_chair(builder, Vector3(0.56, 0.88, 0.56))
		"plant", "plant_bare", "plant_tall", "plant_small": return STAND.plant_stand_in(builder, Vector3(0.6, 0.9, 0.6))
		"desk_lamp_banker": return STAND.desk_lamp(builder, Vector3(0.36, 0.42, 0.22), "banker")
		"desk_lamp_arm": return STAND.desk_lamp(builder, Vector3(0.3, 0.5, 0.36), "arm")
		"floor_lamp": return STAND.floor_lamp(builder, Vector3(0.45, 1.6, 0.45))
		"vending": return STAND.vending_machine(builder, Vector3(0.9, 1.8, 0.8))
		"cooler": return STAND.water_cooler(builder, Vector3(0.34, 1.45, 0.34))
		"fridge": return STAND.fridge(builder, Vector3(0.6, 1.6, 0.65))
		"coffee_maker": return STAND.coffee_maker(builder, Vector3(0.22, 0.36, 0.26))
		"microwave": return STAND.microwave(builder, Vector3(0.5, 0.3, 0.38))
		"globe": return STAND.globe(builder, Vector3(0.36, 0.5, 0.36))
		"extinguisher": return STAND.extinguisher(builder, Vector3(0.2, 0.62, 0.18))
		"work_light": return STAND.work_light(builder, Vector3(0.4, 1.5, 0.4))
		"step_ladder": return STAND.step_ladder(builder, Vector3(0.5, 1.4, 0.6))
		"fire_alarm": return STAND.thermostat(builder, Vector3(0.09, 0.13, 0.03))
		"wall_clock": return WALL.clock_square(builder, Vector3(0.3, 0.3, 0.06))
		"phone": return THINGS.phone(builder, Vector3(0.22, 0.1, 0.24), false)
		"phone_off": return THINGS.phone(builder, Vector3(0.22, 0.1, 0.24), true)
		"typewriter": return EQ_MAIL.typewriter(builder, EQ_MAIL.TYPEWRITER)
		"microfiche": return THINGS.microfiche_reader(builder, Vector3(0.45, 0.55, 0.5))
		"mug": return THINGS.mug(builder, Vector3(0.11, 0.1, 0.09))
		"ashtray": return THINGS.ashtray(builder, Vector3(0.14, 0.03, 0.14))
		"pen_cup": return THINGS.pen_cup(builder, Vector3(0.08, 0.16, 0.08))
		"paper_scatter": return THINGS.paper_scatter(builder, Vector3(0.9, 0.01, 0.7))
		"cable": return THINGS.cable_run(builder, Vector3(1.2, 0.012, 0.3))
		"crt": return MACHINES.crt_monitor(builder, Vector3(0.38, 0.36, 0.4), "plastic_beige")
		"keyboard": return MACHINES.keyboard(builder, Vector3(0.46, 0.035, 0.17))
		"tray": return STATIONERY.tray(builder, Vector3(0.26, 0.07, 0.34), false)
		"tray_wire": return STATIONERY.tray(builder, Vector3(0.26, 0.07, 0.34), true)
		"folders": return STATIONERY.folders(builder, Vector3(0.35, 0.05, 0.25))
		"paper_stack": return STATIONERY.paper_stack(builder, Vector3(0.22, 0.05, 0.31))
		"binders": return STATIONERY.binders(builder, Vector3(0.4, 0.32, 0.29))
		"archive_box": return STATIONERY.archive_box(builder, Vector3(0.33, 0.25, 0.39))
		"register": return STATIONERY.register_book(builder, Vector3(0.5, 0.03, 0.35))
	return null

## A lamp (or the vending machine) and its light (light()).
static func lamp(builder: Node3D, parent: Node3D, room_id: int, kind: String, xform: Transform3D) -> void:
	put(builder, parent, kind, xform)
	light(builder, parent, room_id, kind, xform)

## A lamp's light, an accent of its room (office_accents.gd: three at most to a
## room, none past them); none in a room the builder does not know.
static func light(builder: Node3D, parent: Node3D, room_id: int, kind: String, xform: Transform3D) -> void:
	var spec: Dictionary = LIGHTS.get(kind, {})
	if spec.is_empty() or room_id < 0: return
	var at: Vector3 = spec.at
	var aim: Vector3 = spec.aim
	builder.accent_spot(parent, room_id, xform * at, xform * aim, spec.colour, float(spec.energy), float(spec.reach), float(spec.angle))
