extends SceneTree

var failures: Array[String] = []
var screen: RuleArchiveScreen

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	screen = load("res://scenes/run/rule_archive_screen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame
	_check_control(screen.get_node("%SelectionPanel"), "selection panel")
	for node_name in [
		"Archive01Button",
		"Archive02Button",
		"Archive03Button",
		"Archive04Button",
		"Archive05Button",
		"Archive06Button",
	]:
		var button := screen.get_node("%" + node_name) as Button
		_check_control(button, node_name)
		_assert_true(button.size.x > 300, "%s should remain readable" % node_name)
		_assert_true(button.size.y >= 240, "%s should expose its summary" % node_name)

	_assert_true(screen.open_archive(&"archive_05"), "position archive should open")
	await process_frame
	await process_frame
	var target_hints: Array[String] = []
	for slot in screen.find_children("*", "RuleSlot", true, false):
		var label := slot.get_node_or_null("%SlotIndex") as Label
		if label != null:
			target_hints.append(label.text)
	_assert_true(
		"位 1 = 1" in target_hints and "位 2 = 2" in target_hints,
		"slot-target archive should show explicit position targets"
	)
	_check_control(screen.get_node("%EncounterScreen"), "archive encounter")
	_assert_true(
		screen.encounter_screen.get_node("%DealerRule").text.contains("指定槽位台"),
		"position explanation should be visible before commit"
	)

	screen.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS rule_archive_layout_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_control(control: Control, label: String) -> void:
	_assert_true(control != null, "%s should exist" % label)
	if control == null:
		return
	var rect := control.get_global_rect()
	_assert_true(rect.size.x > 0 and rect.size.y > 0, "%s should have size" % label)
	_assert_true(rect.position.x >= -1 and rect.position.y >= -1, "%s should not overflow top-left" % label)
	_assert_true(rect.end.x <= 1921 and rect.end.y <= 1081, "%s should not overflow viewport" % label)

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
