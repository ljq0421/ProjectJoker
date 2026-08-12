extends SceneTree

const OUTPUT_DIR := "res://tmp/engine-slice-captures"
const Scene = preload("res://scenes/run/engine_slice_screen.tscn")
const Catalog = preload("res://scripts/engine_slice/engine_slice_catalog.gd")

var viewport: SubViewport
var screen

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.set_meta("engine_slice_save_path", OS.get_environment("TEMP").path_join("project-joker-engine-visual.cfg"))
	viewport = SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	await _setup_screen(Vector2i(1920, 1080))
	_save("01-setup-1920x1080.png")
	screen.session.start_new(20260811, Catalog.DICE_CONTROL)
	screen.session.choose_route(&"gold_precise_steps")
	screen._refresh()
	await _settle(3)
	_save("02-battle-1920x1080.png")
	screen.session._begin_battle(&"dealer_iron_abacus_engine")
	screen._refresh()
	await _settle(3)
	_save("02b-iron-abacus-1920x1080.png")
	await _setup_screen(Vector2i(1280, 720))
	screen.session.start_new(20260811, Catalog.TABLE_CHAIN)
	screen.session.choose_route(&"gold_even_split")
	screen._refresh()
	await _settle(3)
	_save("03-battle-1280x720.png")
	await _setup_screen(Vector2i(2560, 1080))
	screen.session.start_new(20260811, Catalog.DICE_CONTROL)
	screen.session.choose_route(&"gold_precise_steps")
	screen._refresh()
	await _settle(3)
	_save("04-battle-2560x1080.png")
	print("ENGINE_SLICE_VISUAL_CAPTURE: PASS -> %s" % OUTPUT_DIR)
	quit(0)

func _setup_screen(size: Vector2i) -> void:
	if screen != null:
		screen.queue_free()
		await _settle(2)
	viewport.size = size
	screen = Scene.instantiate()
	viewport.add_child(screen)
	await _settle(3)

func _settle(frames: int) -> void:
	for _index in frames:
		await process_frame

func _save(file_name: String) -> void:
	var image := viewport.get_texture().get_image()
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	if image == null or image.save_png(path) != OK:
		push_error("failed to capture engine slice frame: %s" % file_name)
		quit(1)
