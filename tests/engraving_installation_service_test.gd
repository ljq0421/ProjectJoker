extends "res://tests/test_case.gd"

func run() -> void:
	_test_success_is_detached()
	_test_rejections_are_atomic()

func _test_success_is_detached() -> void:
	var before := _blank_profiles()
	var before_signature := _signature(before)
	var result := EngravingInstallationService.new().install(
		before,
		[&"engraving_anchor"],
		&"engraving_anchor",
		&"d2",
		4,
		EngravingCatalog.new()
	)
	assert_true(result.accepted, "valid installation should succeed")
	assert_equal(_signature(before), before_signature, "input profiles must remain untouched")
	assert_equal(result.profiles.size(), 6, "accepted result should return six profiles")
	assert_equal(result.profiles[1].engraving_id, &"engraving_anchor", "target gets engraving")
	assert_equal(result.profiles[1].engraved_face, 4, "target gets engraved face")
	assert_equal(result.profiles[0].engraving_id, &"", "other profiles remain blank")
	assert_true(result.profiles[0] != before[0], "accepted profiles should be clones")

func _test_rejections_are_atomic() -> void:
	var catalog := EngravingCatalog.new()
	_assert_rejected(
		_blank_profiles(),
		[&"engraving_anchor"],
		&"engraving_prism",
		&"d1",
		2,
		catalog,
		"selection outside offers should reject"
	)
	_assert_rejected(
		_blank_profiles(),
		[&"missing_engraving"],
		&"missing_engraving",
		&"d1",
		2,
		catalog,
		"missing engraving definition should reject"
	)
	_assert_rejected(
		_blank_profiles(),
		[&"engraving_anchor"],
		&"engraving_anchor",
		&"missing_die",
		2,
		catalog,
		"unknown die should reject"
	)
	_assert_rejected(
		_blank_profiles(),
		[&"engraving_anchor"],
		&"engraving_anchor",
		&"d1",
		7,
		catalog,
		"invalid face should reject"
	)

	var installed := _blank_profiles()
	installed[0].engraving_id = &"engraving_anchor"
	installed[0].engraved_face = 4
	_assert_rejected(
		installed,
		[&"engraving_prism"],
		&"engraving_prism",
		&"d1",
		1,
		catalog,
		"already engraved die should reject"
	)

	var malformed := _blank_profiles()
	malformed[5].id = &"d5"
	_assert_rejected(
		malformed,
		[&"engraving_anchor"],
		&"engraving_anchor",
		&"d1",
		2,
		catalog,
		"duplicate profile IDs should reject"
	)

func _assert_rejected(
	profiles: Array[DieState],
	offer_ids: Array[StringName],
	selected_id: StringName,
	die_id: StringName,
	face: int,
	catalog: EngravingCatalog,
	message: String
) -> void:
	var before := _signature(profiles)
	var result := EngravingInstallationService.new().install(
		profiles,
		offer_ids,
		selected_id,
		die_id,
		face,
		catalog
	)
	assert_false(result.accepted, message)
	assert_false(result.reason.is_empty(), "%s; reason should be visible" % message)
	assert_equal(_signature(profiles), before, "%s; input should remain untouched" % message)
	assert_equal(result.profiles, [], "%s; rejected result should expose no profiles" % message)

func _blank_profiles() -> Array[DieState]:
	var profiles: Array[DieState] = []
	for die_index in range(1, 7):
		profiles.append(DieState.new(StringName("d%d" % die_index), 1))
	return profiles

func _signature(profiles: Array[DieState]) -> Array:
	var result: Array = []
	for profile in profiles:
		result.append([
			profile.id,
			profile.rolled_value,
			profile.value,
			profile.engraving_id,
			profile.engraved_face,
		])
	return result
