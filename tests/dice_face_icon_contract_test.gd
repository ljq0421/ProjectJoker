extends "res://tests/test_case.gd"

const FACE_ROOT := "res://resources/ui/dream_glass/icons/dice/"

func run() -> void:
	var token: DieToken = load(
		"res://scenes/components/die_token.tscn"
	).instantiate()
	var face_icon := token.get_node_or_null("%FaceIcon") as TextureRect
	assert_true(
		token.has_method("face_icon_path"),
		"die token should expose the deterministic face-icon mapping"
	)
	assert_true(
		face_icon != null,
		"die token should own an icon layer independent from Button margins"
	)
	for value in range(1, 7):
		var expected_path := "%sdie_%d.svg" % [FACE_ROOT, value]
		assert_true(
			ResourceLoader.exists(expected_path),
			"die face %d should have an imported SVG" % value
		)
		if token.has_method("face_icon_path"):
			assert_equal(
				token.call("face_icon_path", value),
				expected_path,
				"die face %d should map to its SVG" % value
			)
		var state := DieState.new(StringName("d%d" % value), value)
		token.bind_die(state, false)
		assert_true(
			face_icon != null and face_icon.texture != null,
			"die face %d should be visible on the actual token" % value
		)
		assert_true(
			token.icon == null,
			"Button content margins should not resize the die face"
		)
		assert_equal(
			token.text,
			"",
			"die face should not be shrunk by duplicate numeric copy"
		)
		assert_true(
			("点数 %d" % value) in token.tooltip_text,
			"die face should retain its exact value in the tooltip"
		)
	assert_equal(
		token.custom_minimum_size,
		Vector2(60, 60),
		"the outer frame should shrink to 60 px"
	)
	assert_equal(
		face_icon.custom_minimum_size if face_icon != null else Vector2.ZERO,
		Vector2(54, 54),
		"the existing 54 px die face should stay unchanged"
	)
	for style_name in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		assert_true(
			token.get_theme_stylebox(style_name) is StyleBoxEmpty,
			"die token %s state should not draw a frame around the face" % style_name
		)
	token.bind_die(DieState.new(&"selected", 4), true)
	assert_true(
		face_icon != null and face_icon.self_modulate != Color.WHITE,
		"selected dice should keep a face-level cue after the outer frame is removed"
	)
	assert_true(token.clip_text, "engraving copy should not expand the compact die token")
	assert_equal(
		token.autowrap_mode,
		TextServer.AUTOWRAP_OFF,
		"engraving copy should stay single-line and defer detail to the tooltip"
	)
	token.free()
