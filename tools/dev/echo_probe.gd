extends SceneTree
## Diagnostic for the acoustic view: turns it off one layer at a time and keeps
## a frame of each, so a "why is this bright" question gets answered by looking
## instead of by guessing. Whatever is still on screen once the field is black
## is something else rendering, not the echo. Needs a window.
##
##   godot --path . --script res://tools/dev/echo_probe.gd -- ##       --automation --silent --test-profile
##
## Writes evidence/probe_all, _no_clouds, _no_self, _field_black, _no_field.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level

func _initialize() -> void: run.call_deferred()

func shot(name: String) -> void:
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/probe_%s.png" % name)
	print("SHOT ", name)

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await level.take_locust(81)
	level.settings.values.quality = 2
	level.apply_settings()
	var echo = level.locust.driver.echo
	var corridor: Dictionary = level.manifest.rooms[0]
	for room in level.manifest.rooms:
		if int(room.type) in [11, 12] and int(room.get("hall", -1)) == -1:
			corridor = room
			break
	var centre: Vector3 = FLOOR.position_of(corridor)
	level.locust.global_position = centre + Vector3(0, 0.04, 4.0)
	level.locust.rotation.y = 0.0
	for i in 180: await physics_frame
	await shot("all")
	echo.clouds.visible = false
	await shot("no_clouds")
	echo.self_material.set_shader_parameter("gain", 0.0)
	await shot("no_self")
	echo.field_material.set_shader_parameter("base_level", 0.0)
	echo.field_material.set_shader_parameter("front_level", 0.0)
	echo.field_material.set_shader_parameter("grain_amount", 0.0)
	echo.field_material.set_shader_parameter("contact_count", 0)
	await shot("field_black")
	echo.field.visible = false
	await shot("no_field")
	print("AMBIENT ", level.environment.ambient_light_energy, " lights_visible ", level.hotel.lights.filter(func(l): return l.visible).size(), " fog ", level.environment.fog_enabled)
	paused = false
	level.queue_free()
	await process_frame
	quit()
