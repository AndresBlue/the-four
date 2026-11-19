extends SceneTree
## The offices' paper filled in (game/ui/office_memo.gd), to look at: each
## memorandum below on the author's sheet, at the sheet's own size. With a
## window:
##   godot --path . --script res://tools/capture/memo_capture.gd --log-file <log> -- --automation --test-profile --silent
## Writes evidence/planta/papeles/<name>.png: two of the proposal's (.claude/
## specs/piso2_documentos.md: not the game's until the author says), and the
## floor's own memorandums as the game shows them (juego_*.png).
const MEMO := preload("res://game/ui/office_memo.gd")
const OUT := "res://evidence/planta/papeles"
const SHEETS := {
	"memo_1_mantencion": {"date": "14.03.19__", "to": "Servicios Generales", "from": "T. Requena, Mantención", "subject": "Ductos sobre la sala R-214", "cc": "Jefatura de planta", "seed": 214,
		"lines": ["Tercera vez este mes con los ductos de encima de la R-214. La climatizadora lleva parada desde el martes y siguen sonando. Suenan cuando alguien habla debajo de la rejilla y callan cuando se calla.", "", "Pido sellar esa rejilla y las dos de al lado."],
		"note": ["No. Las rejillas se quedan abiertas."]},
	"memo_4_medico": {"date": "02.06.19__", "to": "Personal", "from": "Dr. A. Campos, Servicio Médico", "subject": "Solicitud de traslado de I. Barral", "cc": "Registro", "seed": 406,
		"lines": ["La empleada dice ver una cara en el techo de su despacho. Solo cuando levanta la vista. Dice que la cara la mira mientras ella la mire, y que cuanto más la mira peor se encuentra después.", "", "Le he indicado que no mire. Refiere que solo se le pasa con el café de la máquina del pasillo.", "", "Solicita traslado a otra planta."],
		"stamp": "DENEGADO"},
}

func _initialize() -> void: run.call_deferred()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for title in SHEETS:
		var view := SubViewport.new()
		view.size = Vector2i(MEMO.CARD)
		view.transparent_bg = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var sheet := MEMO.new()
		view.add_child(sheet)
		sheet.setup(SHEETS[title])
		for i in 6: await process_frame
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png(OUT + "/" + String(title) + ".png")
		print("MEMO_SHOT " + String(title))
		view.queue_free()
	await in_the_game()
	quit(0)

## The floor's own memorandums as the game shows them: the board's legend
## held up, the one pinned beside the board, and the security post's.
func in_the_game() -> void:
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	level.settings.values = level.settings.DEFAULTS.duplicate()
	level.settings.set_designed(2)
	level.creature_scene = "none"
	await level.start_floor(7, false, [1], "apacible", 2)
	level.apply_settings()
	await level.bounce_ready()
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for i in 30: await process_frame
	level.player.set_physics_process(false)
	level.player.torch.visible = true
	# Pinned to its wall, from 0.6 m in front of it.
	for sheet in get_nodes_in_group("office_memos"):
		# From a metre off, a little to one side: the board and what is beside it.
		var planta: int = level.FLOOR.planta_of(sheet.global_position.y)
		var from: Vector3 = sheet.global_position + sheet.global_basis.z * 1.1 + sheet.global_basis.x * 0.25
		level.hotel.start_bounce(planta)
		level.player.global_position = from - Vector3(0, level.player.camera.position.y, 0)
		level.player.rotation.y = atan2(sheet.global_basis.z.x, sheet.global_basis.z.z)
		level.player.camera.rotation.x = 0.0
		level.hotel.update_visibility(level.player.global_position, true)
		await level.bounce_ready()
		await picture("juego_hoja_en_la_pared_%d" % (planta + 1), 1.5)
	for part: Array in [[&"power", "juego_cuadro"], [&"air", "juego_vigilancia"]]:
		level.interaction.read_paper(level.objective(part[0]).paper_of(0))
		await picture(String(part[1]), 1.5)
		level.interaction.close_document()

func picture(title: String, settle: float) -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(settle * 1000.0): await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGB8)
	image.save_png(OUT + "/" + title + ".png")
	print("MEMO_SHOT " + title)
