extends "res://tests/test_case.gd"

func run() -> void:
	var catalog := RuleArchiveCatalog.new()
	assert_equal(
		catalog.validate(),
		[],
		"the six rule archives should validate as one complete catalog"
	)
	var entries := catalog.all_entries()
	assert_equal(entries.size(), 6, "archive catalog should expose six entries")
	var template_ids: Array[StringName] = []
	for entry in entries:
		assert_equal(
			entry.encounter.rules.size(),
			3,
			"each archive should expose three rule tables"
		)
		var total_slots := 0
		for rule in entry.encounter.rules:
			total_slots += rule.slot_count
			template_ids.append(rule.template.id)
		assert_equal(total_slots, 6, "each archive should use all six dice slots")
		assert_equal(
			entry.calibration_points,
			2,
			"each archive should expose two calibration points"
		)
	assert_equal(
		template_ids.size(),
		18,
		"the archive should contain exactly eighteen template instances"
	)
	var unique: Dictionary = {}
	for template_id in template_ids:
		unique[template_id] = true
	assert_equal(
		unique.size(),
		18,
		"every rule template should appear exactly once"
	)
