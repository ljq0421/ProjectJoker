class_name RuleTableTemplate
extends Resource

enum Category {
	POINT,
	RELATION,
	POSITION,
	DISTORTION,
}

enum ConditionKind {
	ANY_FILLED,
	EXACT_SUM,
	MINIMUM_SUM,
	MAXIMUM_SUM,
	SUM_RANGE,
	ALL_EQUAL,
	ALL_DISTINCT,
	ALL_EVEN,
	ALL_ODD,
	SAME_PARITY,
	CONSECUTIVE,
	FIXED_DIFFERENCE,
	STRICT_ASCENDING,
	STRICT_DESCENDING,
	MIRRORED,
	SLOT_TARGETS,
}

enum PostPassEffect {
	NONE,
	ECHO_SELF,
	REVERSE_DIRECTION,
	BRIDGE_FORWARD,
}

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var category: Category = Category.POINT
@export var condition_kind: ConditionKind = ConditionKind.EXACT_SUM
@export var post_pass_effect: PostPassEffect = PostPassEffect.NONE
@export_range(1, 6, 1) var minimum_slot_count: int = 1
@export_range(1, 6, 1) var maximum_slot_count: int = 6
@export var compatible_condition_modifiers: Array[int] = []

func supports_condition_modifier(modifier: int) -> bool:
	return modifier in compatible_condition_modifiers

func validate() -> Array[String]:
	var errors: Array[String] = []
	if id == &"":
		errors.append("template ID is empty")
	if display_name.strip_edges().is_empty():
		errors.append("template %s has no display name" % id)
	if description.strip_edges().is_empty():
		errors.append("template %s has no description" % id)
	if category not in [
		Category.POINT,
		Category.RELATION,
		Category.POSITION,
		Category.DISTORTION,
	]:
		errors.append("template %s has an unknown category" % id)
	if condition_kind not in [
		ConditionKind.ANY_FILLED,
		ConditionKind.EXACT_SUM,
		ConditionKind.MINIMUM_SUM,
		ConditionKind.MAXIMUM_SUM,
		ConditionKind.SUM_RANGE,
		ConditionKind.ALL_EQUAL,
		ConditionKind.ALL_DISTINCT,
		ConditionKind.ALL_EVEN,
		ConditionKind.ALL_ODD,
		ConditionKind.SAME_PARITY,
		ConditionKind.CONSECUTIVE,
		ConditionKind.FIXED_DIFFERENCE,
		ConditionKind.STRICT_ASCENDING,
		ConditionKind.STRICT_DESCENDING,
		ConditionKind.MIRRORED,
		ConditionKind.SLOT_TARGETS,
	]:
		errors.append("template %s has an unknown condition kind" % id)
	if post_pass_effect not in [
		PostPassEffect.NONE,
		PostPassEffect.ECHO_SELF,
		PostPassEffect.REVERSE_DIRECTION,
		PostPassEffect.BRIDGE_FORWARD,
	]:
		errors.append("template %s has an unknown post-pass effect" % id)
	if minimum_slot_count < 1 or minimum_slot_count > 6:
		errors.append("template %s minimum slots are outside 1..6" % id)
	if maximum_slot_count < 1 or maximum_slot_count > 6:
		errors.append("template %s maximum slots are outside 1..6" % id)
	if minimum_slot_count > maximum_slot_count:
		errors.append("template %s minimum slots exceed maximum slots" % id)
	if category == Category.DISTORTION:
		if condition_kind != ConditionKind.ANY_FILLED:
			errors.append("distortion template %s must use ANY_FILLED" % id)
		if post_pass_effect == PostPassEffect.NONE:
			errors.append("distortion template %s requires a post-pass effect" % id)
	else:
		if condition_kind == ConditionKind.ANY_FILLED:
			errors.append("non-distortion template %s cannot use ANY_FILLED" % id)
		if post_pass_effect != PostPassEffect.NONE:
			errors.append("non-distortion template %s cannot have a post-pass effect" % id)
	var seen_modifiers: Dictionary = {}
	for modifier in compatible_condition_modifiers:
		if modifier not in [
			EffectSpec.ConditionModifier.EXACT_TOLERANCE,
			EffectSpec.ConditionModifier.ALLOW_ONE_ODD,
			EffectSpec.ConditionModifier.ALLOW_ONE_GAP,
			EffectSpec.ConditionModifier.INCREASE_SLOT_COUNT,
		]:
			errors.append("template %s has an unknown condition modifier" % id)
		elif seen_modifiers.has(modifier):
			errors.append("template %s repeats a condition modifier" % id)
		else:
			seen_modifiers[modifier] = true
	return errors

