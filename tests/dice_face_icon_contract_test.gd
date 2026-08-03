extends "res://tests/test_case.gd"

const FACE_ROOT := "res://resources/ui/dream_glass/icons/dice/"

func run() -> void:
	var token: DieToken = load(
		"res://scenes/components/die_token.tscn"
	).instantiate()
	assert_true(
		token.has_method("face_icon_path"),
		"die token should expose the deterministic face-icon mapping"
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
			token.icon != null,
			"die face %d should be visible on the actual token" % value
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
		token.get_theme_constant("icon_max_width"),
		68,
		"die face should nearly fill an 82 px token"
	)
	assert_true(token.clip_text, "engraving copy should not expand the compact die token")
	assert_equal(
		token.autowrap_mode,
		TextServer.AUTOWRAP_OFF,
		"engraving copy should stay single-line and defer detail to the tooltip"
	)
	token.free()
