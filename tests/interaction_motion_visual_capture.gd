extends SceneTree

const OUTPUT_DIR := "res://tmp/interaction-motion-captures"

var viewport: SubViewport
var screen: SingleEncounterScreen


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	screen = load("res://scenes/run/single_encounter_screen.tscn").instantiate()
	screen.tutorial_auto_start = false
	viewport.add_child(screen)
	await process_frame
	await process_frame

	screen._on_card_activated(0)
	await create_timer(0.06).timeout
	await process_frame
	if not _save("01-card-selected.png"):
		return

	screen._on_die_activated(&"d1")
	await create_timer(0.14).timeout
	await process_frame
	if not _save("02-card-flight.png"):
		return

	await create_timer(0.32).timeout
	screen.reset_teaching_encounter()
	for assignment in [
		[&"d1", &"left"],
		[&"d6", &"left"],
		[&"d2", &"middle"],
		[&"d3", &"middle"],
		[&"d4", &"right"],
		[&"d5", &"right"],
	]:
		screen.session.activate_die(assignment[0])
		screen.session.activate_table(assignment[1])
	screen.refresh_from_session()
	screen._on_confirm_pressed()
	var report := screen.session.commit()
	if report != null:
		screen.resolution_panel.advance_playback_for_test(
			ResolutionPlayback.NORMAL_EVENT_SECONDS * float(report.events.size())
		)
	await create_timer(0.08).timeout
	await process_frame
	if not _save("03-resolution-climax.png"):
		return

	print("CAPTURED interaction motion frames -> %s" % OUTPUT_DIR)
	quit(0)


func _save(file_name: String) -> bool:
	var image := viewport.get_texture().get_image()
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	if image == null or image.save_png(path) != OK:
		push_error("failed to capture interaction motion frame: %s" % file_name)
		quit(1)
		return false
	return true
