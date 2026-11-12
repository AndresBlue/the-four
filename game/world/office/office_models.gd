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
	# The hotel's carved chair read out of its time in a 1990 office: the walnut and leather stand-in.
	"waiting_chair": {"paths": []},
	"armchair": {"paths": ["res://assets/props/hotel/ArmChair_01.res"], "seat": true},
	"dining_chair": {"paths": ["res://assets/props/hotel/dining_chair_02.res"], "seat": true},
	# sofa_02 is baked facing +Z, its arms reaching out past its back: backed() would turn it round.
	"sofa": {"paths": ["res://assets/props/office/sofa_02.res"]},
	"lounge_chair": {"paths": ["res://assets/props/office/mid_century_lounge_chair.res"], "seat": true},
	# The blue cloth task chair and the plywood one, light enough for the naves (4 k each): office_props.chair() picks one by where it stands.
	"office_chair": {"paths": ["res://assets/props/office/silla_tela_projectkaizen.res", "res://assets/props/office/silla_giratoria_old_computer_chair.res"], "height": 0.95, "seat": true},
	"exec_chair": {"paths": ["res://assets/props/office/silla_banquero_zamzam.res"], "height": 1.15, "seat": true},
	"visitor_chair": {"paths": ["res://assets/props/office/butaca_madera_renend.res"], "height": 0.88, "seat": true},
	"plant": {"paths": ["res://assets/props/office/potted_plant_01.res", "res://assets/props/hotel/potted_plant_02.res"]},
	"plant_bare": {"paths": ["res://assets/props/office/anthurium_botany_01_a.res", "res://assets/props/office/pachira_aquatica_01_c.res", "res://assets/props/office/calathea_orbifolia_01_a.res"], "pot": "steel_dark"},
	"plant_tall": {"paths": ["res://assets/props/office/pachira_aquatica_01_d.res"], "height": 1.45, "pot": "steel_dark"},
	"plant_small": {"paths": ["res://assets/props/office/calathea_orbifolia_01_c.res", "res://assets/props/office/anthurium_botany_01_c.res"], "height": 0.25, "pot": "ceramic"},
	"wall_clock": {"paths": ["res://assets/props/hotel/wall_clock.res"]},
	"fire_alarm": {"paths": ["res://assets/props/hotel/fire_alarm.res"]},
	"bin": {"paths": ["res://assets/props/hotel/metal_trash_can_clean.res"], "scale": 0.62},
	# Rows of books stood up, one with a pair laid on top (libros_frodoundead).
	"books": {"paths": ["res://assets/props/office/libros_frodoundead_row_c.res", "res://assets/props/office/libros_frodoundead_row_a.res", "res://assets/props/office/libros_frodoundead_row_d.res"]},
	"box": {"paths": ["res://assets/props/hotel/cardboard_box_01.res", "res://assets/props/office/caja_carton_krolzuzanna.res"]},
	"clipboard": {"paths": ["res://assets/props/hotel/clipboard.res"]},
	"stationery": {"paths": ["res://assets/props/hotel/stationery_supplies.res"]},
	"notepad": {"paths": ["res://assets/props/hotel/office_notepads_pad.res"]},
	"jug": {"paths": ["res://assets/props/hotel/jug_01.res"]},
	# On its hook only: the one off its hook stays the piece made in code.
	"phone": {"paths": ["res://assets/props/office/rotary_phone_black_sketchfab.res"]},
	# Baked in its own units: brought to the stand-in's height.
	"crt": {"paths": ["res://assets/props/office/crt_terminal_ibm3278_sketchfab.res"], "height": 0.36},
	"cooler": {"paths": ["res://assets/props/office/water_cooler_bottle_tboiston.res"]},
	# Rounds 3 and 4 of the downloads (tools/props/fit_models.json): baked at their pieces' measure.
	"fridge": {"paths": ["res://assets/props/office/nevera_dylanheyes.res"]},
	"desk_lamp_banker": {"paths": ["res://assets/props/office/lampara_banquero_meunier.res"]},
	"desk_lamp_arm": {"paths": ["res://assets/props/office/flexo_sousinho.res"]},
	"ashtray": {"paths": ["res://assets/props/office/cenicero_vidrio_red2000.res"]},
	# The wire cup of pencils (portalapices_aspectstudio) is baked but not used: its 4.8 k triangles on every desk of a nave cost 48 k.
	"tray": {"paths": ["res://assets/props/office/bandeja_sinnervoncrawsz.res"]},
	"archive_box": {"paths": ["res://assets/props/office/cajas_archivo_cozmoth.res"]},
	"globe": {"paths": ["res://assets/props/office/globo_collings.res"]},
	"binders": {"paths": ["res://assets/props/office/archivadores_palanca_janexx.res"]},
	"step_ladder": {"paths": ["res://assets/props/office/wooden_ladder_02.res"]},
	"dot_matrix_printer": {"paths": ["res://assets/props/office/impresora_okidata_papaj.res"]},
	"bookcase_model": {"paths": ["res://assets/props/office/libreria_libros_collings.res"]},
	"desk_walnut_suite": {"paths": ["res://assets/props/office/escritorio_madera_collings.res"]},
	"vending": {"paths": ["res://assets/props/office/expendedora_attheseedof.res"]},
	"desk_clock": {"paths": ["res://assets/props/office/reloj_mesa_sousinho.res"]},
	"desk_fan": {"paths": ["res://assets/props/office/ventilador_joshsmith.res"]},
	"stapler": {"paths": ["res://assets/props/office/vintage_stapler.res"]},
	"thermos": {"paths": ["res://assets/props/office/plastic_thermos.res"]},
	"spectacles": {"paths": ["res://assets/props/office/round_spectacles.res"]},
	"magnifier": {"paths": ["res://assets/props/office/magnifying_glass_01.res"]},
	"cord_floor": {"paths": ["res://assets/props/office/alargador_evan4129.res"]},
	"shoes": {"paths": ["res://assets/props/office/zapato_inciprocal.res"]},
	"toolbox": {"paths": ["res://assets/props/office/metal_toolbox.res"]},
	"broom": {"paths": ["res://assets/props/office/wooden_broom.res"]},
	"dustpan": {"paths": ["res://assets/props/office/dustpan.res"]},
	"mousetrap": {"paths": ["res://assets/props/office/mousetrap.res"]},
	"television": {"paths": ["res://assets/props/office/Television_01.res"]},
	"boombox": {"paths": ["res://assets/props/office/boombox.res"]},
	"projector_screen": {"paths": ["res://assets/props/office/projector_screen.res"]},
	# The standing coat rack of an office's and the director's corner (office_props.gd); no stand-in.
	"coat_stand": {"paths": ["res://assets/props/office/perchero_coat_rack_whostea.res"]},
	# Six grey lockers in a row, at locker_bank's measure (office_props.gd); no stand-in.
	"lockers": {"paths": ["res://assets/props/office/taquilla_zambur.res"]},
	# The ceiling's smoke detector (office_fittings.gd), its light off; no stand-in.
	"smoke_detector": {"paths": ["res://assets/props/office/detector_humo_sousinho.res"]},
	# The grey filing cabinet: shut, and its body and a drawer for one left out,
	# baked in register (office_props.filing()); no stand-in.
	"filing_grey": {"paths": ["res://assets/props/office/archivador_gris_ahmagh2e_shut4.res"]},
	"filing_grey_body": {"paths": ["res://assets/props/office/archivador_gris_ahmagh2e_body4.res"]},
	"filing_grey_drawer": {"paths": ["res://assets/props/office/archivador_gris_ahmagh2e_drawer.res"]},
}
## The grey cabinet's drawers stand GREY_PITCH apart up from the lowest, as
## its drawer is baked; one left out stands GREY_OUT before the rest.
const GREY_PITCH := 0.2988
const GREY_OUT := 0.3

## Whether a filing cabinet in this finish is the grey download: a grey room's, once baked.
static func grey_filing(builder: Node3D, key: String) -> bool:
	return key == "steel_grey" and mesh_of(builder, "filing_grey") != null
## The pots by key (stand_ins.gd plant_pot()).
const POTS := {"steel_dark": Vector3(0.4, 0.38, 0.4), "ceramic": Vector3(0.2, 0.16, 0.2)}
## The lamps of furniture lit to a room at most (light()).
const LIT_MOST := 1
## A lamp's light in the lamp's own frame: where it is, the point it is aimed
## at, its colour, energy, reach and angle (office_geometry.accent_spot()).
## The floor lamp's sits between its pole's tip and its shade's disc, so that
## neither shadows it.
const LIGHTS := {
	"desk_lamp_banker": {"at": Vector3(0, 0.28, 0.02), "aim": Vector3(0, 0, 0.35), "colour": Color(1.0, 0.84, 0.62), "energy": 1.4, "reach": 2.8, "angle": 42.0},
	"desk_lamp_arm": {"at": Vector3(0, 0.42, 0.17), "aim": Vector3(0, 0, 0.4), "colour": Color(1.0, 0.86, 0.66), "energy": 1.4, "reach": 2.6, "angle": 40.0},
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
	# From the one picked on, the first whose file is there.
	for k in paths.size():
		var path: String = paths[posmod(pick + k, paths.size())]
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
	builder.place(parent, mesh, drawn, casts(mesh, drawn))
	return drawn

## Whether a piece placed so casts a shadow on the offices' floor (the
## director, 12 November 2026: 60 fps at Alto with the rooms full): only the
## big pieces on the floor as drawn (CAST_LEAST: a desk, a cabinet, a counter,
## a machine), not a chair, a plant, a lamp, what stands on a top or what is
## flat on a wall; or a mesh that says it does.
const CAST_LEAST := Vector3(0.9, 0.6, 0.2)
static func casts(mesh: Mesh, xform: Transform3D) -> bool:
	if mesh.has_meta("casts"): return true
	var size := mesh.get_aabb().size * xform.basis.get_scale().y
	return size.y >= CAST_LEAST.y and maxf(size.x, size.z) >= CAST_LEAST.x and minf(size.x, size.z) >= CAST_LEAST.z

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
	# One lit lamp of furniture to a room: each is a spot with its shadow, and
	# the full rooms of the 12th had the floor at 20 ms on Alto (dens6).
	var lit: Array = builder.accents.of_room(room_id).filter(func(e: Dictionary) -> bool: return int(e.sconce) < 0)
	if lit.size() >= LIT_MOST: return
	var at: Vector3 = spec.at
	var aim: Vector3 = spec.aim
	builder.accent_spot(parent, room_id, xform * at, xform * aim, spec.colour, float(spec.energy), float(spec.reach), float(spec.angle))
