class_name RuleTableCatalog
extends RefCounted

const TEMPLATE_PATHS := [
	"res://resources/rules/templates/rule_exact_sum.tres",
	"res://resources/rules/templates/rule_minimum_sum.tres",
	"res://resources/rules/templates/rule_maximum_sum.tres",
	"res://resources/rules/templates/rule_sum_range.tres",
	"res://resources/rules/templates/rule_all_equal.tres",
	"res://resources/rules/templates/rule_all_distinct.tres",
	"res://resources/rules/templates/rule_all_even.tres",
	"res://resources/rules/templates/rule_all_odd.tres",
	"res://resources/rules/templates/rule_same_parity.tres",
	"res://resources/rules/templates/rule_consecutive.tres",
	"res://resources/rules/templates/rule_fixed_difference.tres",
	"res://resources/rules/templates/rule_strict_ascending.tres",
	"res://resources/rules/templates/rule_strict_descending.tres",
	"res://resources/rules/templates/rule_mirrored.tres",
	"res://resources/rules/templates/rule_slot_targets.tres",
	"res://resources/rules/templates/rule_echo_table.tres",
	"res://resources/rules/templates/rule_reverse_table.tres",
	"res://resources/rules/templates/rule_bridge_table.tres",
]

const EXPECTED_CATEGORY_COUNTS := {
	RuleTableTemplate.Category.POINT: 4,
	RuleTableTemplate.Category.RELATION: 7,
	RuleTableTemplate.Category.POSITION: 4,
	RuleTableTemplate.Category.DISTORTION: 3,
}

var _templates: Array[RuleTableTemplate] = []
var _by_id: Dictionary = {}
var _load_errors: Array[String] = []

func _init() -> void:
	for path in TEMPLATE_PATHS:
		var resource := load(path)
		if not resource is RuleTableTemplate:
			_load_errors.append("failed to load rule template: %s" % path)
			continue
		var template := resource as RuleTableTemplate
		_templates.append(template)
		if _by_id.has(template.id):
			_load_errors.append("duplicate rule template ID: %s" % template.id)
		else:
			_by_id[template.id] = template

func all_templates() -> Array[RuleTableTemplate]:
	return _templates.duplicate()

func all_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for template in _templates:
		ids.append(template.id)
	return ids

func find_template(template_id: StringName) -> RuleTableTemplate:
	return _by_id.get(template_id) as RuleTableTemplate

func templates_for_category(
	category: RuleTableTemplate.Category
) -> Array[RuleTableTemplate]:
	var matches: Array[RuleTableTemplate] = []
	for template in _templates:
		if template.category == category:
			matches.append(template)
	return matches

func validate() -> Array[String]:
	var errors := _load_errors.duplicate()
	if _templates.size() != 18:
		errors.append("rule table catalog must contain exactly eighteen templates")
	for template in _templates:
		errors.append_array(template.validate())
	for category in EXPECTED_CATEGORY_COUNTS:
		var actual := templates_for_category(category).size()
		var expected: int = EXPECTED_CATEGORY_COUNTS[category]
		if actual != expected:
			errors.append(
				"rule table category %d must contain %d templates, got %d"
				% [category, expected, actual]
			)
	return errors

