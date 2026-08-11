extends SceneTree

var failures: Array[String] = []

const DISPLAY_SIZES := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(1600, 1200),
	Vector2i(2560, 1080),
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_factor = 1.0
	for display_size in DISPLAY_SIZES:
		await _check_display_size(display_size)
	root.size = Vector2i(1920, 1080)
	if failures.is_empty():
		print("PASS fixed_formal_encounter_layout_self_check")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_display_size(display_size: Vector2i) -> void:
	root.size = display_size
	await process_frame
	var host: Control = load("res://scenes/run/area_run_screen.tscn").instantiate()
	root.add_child(host)
	for _frame in range(4):
		await process_frame
	var encounter: Control = host.get_node("%EncounterScreen")
	var safe_area: Control = encounter.get_node("SafeArea")
	_assert_rect(
		host.get_node("NavigationBar"),
		Rect2(32, 24, 1640, 48),
		"formal navigation",
		display_size,
		true
	)
	_assert_rect(
		safe_area,
		Rect2(32, 96, 1856, 960),
		"formal SafeArea",
		display_size,
		true
	)
	for fixed_size in [
		[host.get_node("%HomeButton"), Vector2(192, 48), "home button"],
		[host.get_node("%AreaChromeLabel"), Vector2(884, 48), "area name"],
		[host.get_node("%AreaProtocolLabel"), Vector2(292, 48), "area protocol"],
		[host.get_node("%RandomContractLabel"), Vector2(248, 48), "mutation summary"],
		[host.get_node("SettingsLayer/SettingsRoot/RuleReferenceButton"), Vector2(96, 48), "rule reference button"],
		[host.get_node("SettingsLayer/SettingsRoot/SettingsButton"), Vector2(96, 48), "settings button"],
		[encounter.get_node("SafeArea/RootColumn/TopBar"), Vector2(1856, 32), "status bar"],
		[encounter.get_node("SafeArea/RootColumn/AreaDirectiveSlot"), Vector2(1856, 40), "area directive"],
		[encounter.get_node("SafeArea/RootColumn/Body"), Vector2(1856, 836), "body"],
		[encounter.get_node("SafeArea/RootColumn/Body/DealerPanel"), Vector2(230, 836), "dealer column"],
		[encounter.get_node("SafeArea/RootColumn/Body/Center"), Vector2(1290, 836), "center column"],
		[encounter.get_node("%LeftLane"), Vector2(371, 302), "left lane"],
		[encounter.get_node("%MiddleLane"), Vector2(372, 302), "middle lane"],
		[encounter.get_node("%RightLane"), Vector2(371, 302), "right lane"],
		[encounter.get_node("%LeftGap"), Vector2(72, 256), "left gap button"],
		[encounter.get_node("%RightGap"), Vector2(72, 256), "right gap button"],
		[encounter.get_node("SafeArea/RootColumn/Body/Center/DiceRow"), Vector2(1290, 102), "dice row"],
		[encounter.get_node("%Hand"), Vector2(1290, 126), "hand"],
		[encounter.get_node("%CardDetailPanel"), Vector2(1290, 150), "card detail"],
		[encounter.get_node("SafeArea/RootColumn/Body/Center/ActionBar"), Vector2(1290, 42), "actions"],
		[encounter.get_node("SafeArea/RootColumn/Body/Center/EmergencyBar"), Vector2(1290, 42), "emergency actions"],
		[encounter.get_node("%ResolutionPanel"), Vector2(300, 836), "prediction column"],
		[encounter.get_node("SafeArea/RootColumn/ErrorLabel"), Vector2(1856, 28), "error row"],
	]:
		_assert_size(fixed_size[0], fixed_size[1], fixed_size[2], display_size)
	_assert_size(host.get_node("EncounterScreen/Background"), host.size, "full background", display_size)
	_assert_size(host.get_node("EncounterScreen/AreaAtmosphere"), host.size, "full atmosphere", display_size)
	host.queue_free()
	await process_frame


func _assert_rect(
	control: Control,
	expected: Rect2,
	label: String,
	display_size: Vector2i,
	use_global_rect: bool = false
) -> void:
	var actual := control.get_global_rect() if use_global_rect else control.get_rect()
	if not (
		actual.position.is_equal_approx(expected.position)
		and actual.size.is_equal_approx(expected.size)
	):
		failures.append(
			"%s changed at %s: %s, expected %s"
			% [label, display_size, actual, expected]
		)


func _assert_size(
	control: Control,
	expected: Vector2,
	label: String,
	display_size: Vector2i
) -> void:
	if not control.size.is_equal_approx(expected):
		failures.append(
			"%s changed size at %s: %s, expected %s"
			% [label, display_size, control.size, expected]
		)
