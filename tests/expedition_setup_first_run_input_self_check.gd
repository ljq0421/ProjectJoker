extends SceneTree

const ExpeditionMeta = preload("res://scripts/run/expedition_meta_store.gd")

var failures: Array[String] = []
var meta_path := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	meta_path = OS.get_temp_dir().path_join(
		"project-joker-first-run-setup-%d.cfg" % Time.get_ticks_usec()
	)
	ExpeditionMeta.new(meta_path).clear()
	root.set_meta("expedition_meta_path", meta_path)
	var setup: ExpeditionSetupScreen = load(
		"res://scenes/run/expedition_setup_screen.tscn"
	).instantiate()
	root.add_child(setup)
	await _settle()

	_assert_false(setup.challenges_unlocked, "fresh profile should use the first-run setup")
	_assert_false(
		setup.get_node("%ChallengeGrid").visible,
		"locked challenge controls should not compete with the first-run decision"
	)
	_assert_true(
		setup.get_node("%FirstRunJourneyPanel").visible,
		"fresh setup should preview the three-area demo route"
	)
	_assert_false(
		setup.get_node("%HistoryPanel").visible,
		"an empty history column should not consume first-run space"
	)
	var recommended := _button_with_meta(
		setup.get_node("%DeckChoiceRow"),
		&"deck_id",
		&"dice_control"
	)
	_assert_true(recommended != null, "the recommended deck should exist")
	if recommended != null:
		_assert_true(recommended.button_pressed, "the recommended deck should start selected")
		_assert_true("首局推荐" in recommended.text, "the recommended deck should be labeled")
	_assert_true(
		"标准难度（推荐首局）" in setup.get_node("%SelectionSummaryLabel").text,
		"fresh setup should summarize the recommended standard configuration"
	)
	var alternate := _button_with_meta(
		setup.get_node("%DeckChoiceRow"),
		&"deck_id",
		&"table_chain"
	)
	if alternate != null:
		alternate.emit_signal("pressed")
		await _settle()
		_assert_true(
			"规则台连锁 · 标准难度" in setup.get_node("%SelectionSummaryLabel").text,
			"changing deck should immediately update the configuration summary"
		)

	setup.queue_free()
	await process_frame
	ExpeditionMeta.new(meta_path).clear()
	_finish()

func _button_with_meta(parent: Node, meta_name: StringName, value: Variant) -> Button:
	for child in parent.get_children():
		if child is Button and child.get_meta(meta_name, null) == value:
			return child
	return null

func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func _assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _assert_false(value: bool, message: String) -> void:
	_assert_true(not value, message)

func _finish() -> void:
	if failures.is_empty():
		print("PASS expedition_setup_first_run_input_self_check")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
