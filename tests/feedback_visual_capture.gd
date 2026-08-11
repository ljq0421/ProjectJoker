extends SceneTree

const OUTPUT_ROOT := "res://tmp"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	for capture in [
		[Vector2i(1280, 720), &"gold_corridor", &"storm", 128],
		[Vector2i(1920, 1080), &"mirror_hall", &"resonance", 256],
	]:
		await _capture(capture[0], capture[1], capture[2], capture[3])
	await _capture_summary(Vector2i(1280, 720))
	print("PASS feedback_visual_capture")
	quit(0)

func _capture(
	window_size: Vector2i,
	area_id: StringName,
	kind: StringName,
	total: int
) -> void:
	root.size = window_size
	var screen: SingleEncounterScreen = load(
		"res://scenes/run/single_encounter_screen.tscn"
	).instantiate()
	screen.tutorial_auto_start = false
	root.add_child(screen)
	screen.apply_area_presentation(area_id)
	await process_frame
	await process_frame
	screen.interaction_motion_layer.play_rare_highlight(kind, total, area_id)
	await create_timer(0.32).timeout
	await process_frame
	var image := root.get_texture().get_image()
	var file_name := "feedback_%s_%dx%d.png" % [area_id, window_size.x, window_size.y]
	var error := image.save_png("%s/%s" % [OUTPUT_ROOT, file_name])
	if error != OK:
		push_error("Failed to save %s: %s" % [file_name, error])
	screen.queue_free()
	await process_frame

func _capture_summary(window_size: Vector2i) -> void:
	root.size = window_size
	var panel: RoundSummaryPanel = load(
		"res://scenes/components/round_summary_panel.tscn"
	).instantiate()
	panel.theme = load("res://resources/themes/neon_dream_theme.tres")
	root.add_child(panel)
	await process_frame
	panel._hide_actions()
	panel.visible = true
	panel.score_block.visible = true
	panel.title_label.text = "本轮契据摘要"
	panel.score_value.text = "128"
	panel.score_ledger.text = "基础 72 · 系数 24 · 卡牌 12 · 连锁 20"
	panel.engraving_total.text = "本轮刻印贡献：+12"
	panel.detail_label.text = "本轮解析：128\n累计解析：275 / 300\n目标差值：25\n契约封印｜◆◆◆◇"
	var report := ResolutionReport.new()
	report.assigned_dice = 6
	report.passed_rule_count = 3
	report.storm_awarded = true
	panel._bind_fact_badges(report)
	await process_frame
	var image := root.get_texture().get_image()
	image.save_png("%s/feedback_summary_%dx%d.png" % [OUTPUT_ROOT, window_size.x, window_size.y])
	panel.queue_free()
	await process_frame
