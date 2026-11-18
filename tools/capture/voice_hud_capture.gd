extends SceneTree
## The stamina meter's runner card and the team voice marks as the game draws
## them (camcorder_osd.gd, hotel_ui.draw_voice), over a frame of the office, at
## 1280x720 and a 4x crop of the corner: evidence/voz/hud_*.png.

const OSD := preload("res://game/presentation/camcorder_osd.gd")
const STYLE := preload("res://game/ui/osd_style.gd")

class Marks extends Control:
	var shot: Texture2D
	func _draw() -> void:
		draw_texture_rect(shot, Rect2(Vector2.ZERO, size), false)
		# The meter as camcorder_osd draws it, half spent.
		var right := size.x - 48.0
		var bottom := size.y - 60.0
		var cell := Vector2(14, 22)
		var width := 12 * (cell.x + 5.0) - 5.0
		for i in 12:
			var rect := Rect2(Vector2(right - width + i * (cell.x + 5.0), bottom - cell.y), cell)
			draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size), Color(0, 0, 0, 0.6))
			draw_rect(rect, Color(STYLE.INK, 0.9 if i < 6 else 0.18))
		var card := Rect2(Vector2(right - width, bottom - cell.y - 8.0 - OSD.RUN_CARD), Vector2(OSD.RUN_CARD, OSD.RUN_CARD))
		draw_rect(Rect2(card.position + Vector2(2, 2), card.size), Color(0, 0, 0, 0.6))
		draw_rect(card, Color(STYLE.INK, 0.9))
		draw_rect(card, Color(0, 0, 0, 0.9), false, 2.0)
		OSD.draw_icon(self, OSD.runner_icon(), card.position + Vector2(3, 3), OSD.RUN_CARD - 6.0, Color(0, 0, 0, 0.9))
		# The voice marks: this player sending, one teammate by radio, one near.
		var at := Vector2(size.x - 76.0, size.y - 124.0)
		for icon in [OSD.microphone_icon(), OSD.radio_icon(), OSD.voice_icon()]:
			OSD.draw_icon(self, icon, at, 28.0, Color(0, 0, 0, 0.85), 3.0)
			OSD.draw_icon(self, icon, at, 28.0, Color(STYLE.INK, 0.95))
			at.x -= 38.0

func _initialize() -> void: run.call_deferred()

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var marks := Marks.new()
	marks.shot = ImageTexture.create_from_image(Image.load_from_file("res://evidence/planta/ronda11/vistas/emergencia_1.png"))
	marks.size = Vector2(1280, 720)
	root.add_child(marks)
	for _frame in 6: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://evidence/voz/hud_entero.png")
	var corner := image.get_region(Rect2i(1280 - 340, 720 - 140, 330, 110))
	corner.resize(330 * 4, 110 * 4, Image.INTERPOLATE_NEAREST)
	corner.save_png("res://evidence/voz/hud_esquina_x4.png")
	quit(0)
