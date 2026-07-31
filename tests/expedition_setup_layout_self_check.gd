extends SceneTree

const ExpeditionMeta = preload("res://scripts/run/expedition_meta_store.gd")
const LOGICAL_SIZE := Vector2i(1920, 1080)

var failed := false
var meta_path := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	meta_path = OS.get_temp_dir().path_join(
		"project-joker-setup-layout-%d.cfg" % Time.get_ticks_usec()
	)
	var store = ExpeditionMeta.new(meta_path)
	store.clear()
	store.record_run(_complete_record())
	root.set_meta("expedition_meta_path", meta_path)
	root.content_scale_size = LOGICAL_SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = viewport_size
		var screen: Control = load(
			"res://scenes/run/expedition_setup_screen.tscn"
		).instantiate()
		root.add_child(screen)
		current_scene = screen
		await _settle()
		_assert(Vector2i(screen.size) == LOGICAL_SIZE, "logical canvas should remain 1920x1080")
		_assert(screen.get_node("%DeckChoiceRow").get_child_count() == 3, "three deck choices should render")
		_assert(screen.get_node("%ChallengeGrid").get_child_count() == 6, "six challenges should render")
		for node in [
			screen.get_node("%ReturnFromSetupButton"),
			screen.get_node("%StartConfiguredExpeditionButton"),
			screen.get_node("%ExpeditionSeedInput"),
			screen.get_node("SafeArea/Page/Columns/HistoryPanel"),
		]:
			_assert(
				_inside_rect(node, screen.get_global_rect()),
				"%s should remain inside the logical canvas at %s; rect=%s" % [
					node.name,
					viewport_size,
					node.get_global_rect(),
				]
			)
		_assert(
			screen.get_node("%StartConfiguredExpeditionButton").get_global_rect().intersects(
				screen.get_node("%ExpeditionSeedInput").get_global_rect()
			) == false,
			"seed input and start button should not overlap"
		)
		screen.queue_free()
		await process_frame
	store.clear()
	if failed:
		quit(1)
	else:
		print("PASS expedition_setup_layout_self_check")
		quit(0)

func _inside_rect(control: Control, outer: Rect2) -> bool:
	var rect := control.get_global_rect()
	return (
		rect.position.x >= outer.position.x - 0.5
		and rect.position.y >= outer.position.y - 0.5
		and rect.end.x <= outer.end.x + 0.5
		and rect.end.y <= outer.end.y + 0.5
	)

func _complete_record() -> Dictionary:
	return {
		"run_id": &"layout-complete",
		"ended_at": 1,
		"result": &"complete",
		"seed_value": 12345,
		"starting_deck_id": &"dice_control",
		"challenge_ids": [],
		"completed_areas": [],
		"route_ids": [],
		"reward_ids": [],
		"final_deck_count": 12,
		"intel_tickets": 0,
		"failure_reason": "",
	}

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
