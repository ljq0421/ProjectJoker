extends "res://tests/test_case.gd"

const EXPECTED_IDS := [
	"rule_exact_sum",
	"rule_minimum_sum",
	"rule_maximum_sum",
	"rule_sum_range",
	"rule_all_equal",
	"rule_all_distinct",
	"rule_all_even",
	"rule_all_odd",
	"rule_same_parity",
	"rule_consecutive",
	"rule_fixed_difference",
	"rule_strict_ascending",
	"rule_strict_descending",
	"rule_mirrored",
	"rule_slot_targets",
	"rule_echo_table",
	"rule_reverse_table",
	"rule_bridge_table",
]

func run() -> void:
	var catalog := RuleTableCatalog.new()
	assert_equal(catalog.validate(), [], "rule table catalog should validate")
	assert_equal(catalog.all_templates().size(), 18, "catalog should contain eighteen templates")

	var actual_ids := PackedStringArray()
	for template in catalog.all_templates():
		actual_ids.append(String(template.id))
	actual_ids.sort()
	var expected_ids := PackedStringArray(EXPECTED_IDS)
	expected_ids.sort()
	assert_equal(actual_ids, expected_ids, "catalog should expose the exact template IDs")

	var expected_category_counts := {
		RuleTableTemplate.Category.POINT: 4,
		RuleTableTemplate.Category.RELATION: 7,
		RuleTableTemplate.Category.POSITION: 4,
		RuleTableTemplate.Category.DISTORTION: 3,
	}
	for category in expected_category_counts:
		assert_equal(
			catalog.templates_for_category(category).size(),
			expected_category_counts[category],
			"catalog category count should match the design"
		)

	for template in catalog.all_templates():
		assert_true(
			not template.display_name.strip_edges().is_empty(),
			"template %s should have a display name" % template.id
		)
		assert_true(
			not template.description.strip_edges().is_empty(),
			"template %s should have a description" % template.id
		)
		assert_true(
			template.minimum_slot_count >= 1,
			"template %s should have a positive minimum slot count" % template.id
		)
		assert_true(
			template.maximum_slot_count <= 6,
			"template %s should fit the six-die round" % template.id
		)
		assert_true(
			catalog.find_template(template.id) == template,
			"catalog lookup should return the loaded template"
		)

	assert_true(
		catalog.find_template(&"missing_rule_template") == null,
		"unknown template IDs should return null"
	)

	var echo := catalog.find_template(&"rule_echo_table")
	var reverse := catalog.find_template(&"rule_reverse_table")
	var bridge := catalog.find_template(&"rule_bridge_table")
	assert_equal(
		echo.condition_kind,
		RuleTableTemplate.ConditionKind.ANY_FILLED,
		"echo should pass when filled"
	)
	assert_equal(
		echo.post_pass_effect,
		RuleTableTemplate.PostPassEffect.ECHO_SELF,
		"echo should repeat its base result"
	)
	assert_equal(
		reverse.post_pass_effect,
		RuleTableTemplate.PostPassEffect.REVERSE_DIRECTION,
		"reverse should toggle resolution direction"
	)
	assert_equal(
		bridge.post_pass_effect,
		RuleTableTemplate.PostPassEffect.BRIDGE_FORWARD,
		"bridge should transfer in final direction"
	)
