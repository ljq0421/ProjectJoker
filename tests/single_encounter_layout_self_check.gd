extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var screen = load("res://scenes/run/single_encounter_screen.tscn").instantiate()
	screen.tutorial_auto_start = false
	root.add_child(screen)
	await process_frame
	await process_frame

	var dealer: Control = screen.get_node("SafeArea/RootColumn/Body/DealerPanel")
	var left: Control = screen.get_node("%LeftLane")
	var middle: Control = screen.get_node("%MiddleLane")
	var right: Control = screen.get_node("%RightLane")
	var left_gap: Control = screen.get_node("%LeftGap")
	var right_gap: Control = screen.get_node("%RightGap")
	var tray: Control = screen.get_node("%DiceTray")
	var resolution: Control = screen.get_node("%ResolutionPanel")
	var hand: Control = screen.get_node("%Hand")
	var run_trial: Control = screen.get_node("%RunTrialButton")

	_assert_inside(screen.get_rect(), dealer.get_global_rect(), "dealer")
	_assert_inside(screen.get_rect(), left.get_global_rect(), "left lane")
	_assert_inside(screen.get_rect(), middle.get_global_rect(), "middle lane")
	_assert_inside(screen.get_rect(), right.get_global_rect(), "right lane")
	_assert_inside(screen.get_rect(), left_gap.get_global_rect(), "left gap")
	_assert_inside(screen.get_rect(), right_gap.get_global_rect(), "right gap")
	_assert_inside(screen.get_rect(), tray.get_global_rect(), "dice tray")
	_assert_inside(screen.get_rect(), resolution.get_global_rect(), "resolution")
	_assert_inside(screen.get_rect(), hand.get_global_rect(), "hand")
	_assert_inside(screen.get_rect(), run_trial.get_global_rect(), "three round trial button")
	_assert_true(
		absf(left.size.x - middle.size.x) <= 2.0
		and absf(middle.size.x - right.size.x) <= 2.0,
		"three lanes should have equal widths"
	)
	_assert_true(
		dealer.get_global_rect().end.x < left.get_global_rect().position.x,
		"dealer must not overlap lanes"
	)
	_assert_true(
		right.get_global_rect().end.x < resolution.get_global_rect().position.x,
		"lanes must not overlap resolution"
	)

	screen.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS single_encounter_layout_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _assert_inside(parent_rect: Rect2, child_rect: Rect2, label: String) -> void:
	_assert_true(
		parent_rect.encloses(child_rect),
		"%s must remain inside 1920x1080 root" % label
	)

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
