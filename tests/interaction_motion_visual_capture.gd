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

	# Prime one slot so the captured drop fills the table and legitimately
	# triggers the stronger rule-response beat.
	screen.session.assign_dropped_die_to_slot(&"d3", &"middle", 0)
	screen.session.assign_dropped_die_to_slot(&"d4", &"middle", 1)
	screen.refresh_from_session()
	screen._on_die_drop_to_slot_requested(&"d5", &"middle", 2)
	await create_timer(0.13).timeout
	await process_frame
	if not _save("00-response-source.png"):
		return
	await create_timer(InteractionMotionLayer.RESPONSE_STEP_SECONDS).timeout
	await process_frame
	if not _save("00-response-affected.png"):
		return
	await create_timer(InteractionMotionLayer.RESPONSE_STEP_SECONDS).timeout
	await process_frame
	if not _save("00-response-rule.png"):
		return
	await create_timer(InteractionMotionLayer.RESPONSE_STEP_SECONDS).timeout
	await process_frame
	if not _save("00-response-prediction.png"):
		return
	screen.reset_teaching_encounter()
	screen._on_die_activated(&"d5")
	screen._on_slot_activated(&"middle", 1)
	await create_timer(0.04).timeout
	await process_frame
	if not _save("00-die-landing.png"):
		return
	await create_timer(0.34).timeout
	await process_frame
	if not _save("00-die-settled.png"):
		return
	screen.reset_teaching_encounter()

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
		var summary: RoundSummaryPanel = load(
			"res://scenes/components/round_summary_panel.tscn"
		).instantiate()
		summary.z_index = 80
		viewport.add_child(summary)
		await process_frame
		var summary_session := ThreeRoundEncounterSession.new(null)
		summary_session.status = ThreeRoundEncounterSession.Status.ROUND_SUMMARY
		summary_session.committed_reports.append(report)
		summary_session.cumulative_total = report.total
		summary_session.target_total = 100
		summary.show_run_state(summary_session)
	await create_timer(0.26).timeout
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
