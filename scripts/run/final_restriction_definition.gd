class_name FinalRestrictionDefinition
extends Resource

enum Category {
	OPERATION,
	DISTRIBUTION,
}

enum Operation {
	MAX_REAL_CARDS,
	REQUIRE_ALL_TABLES_OCCUPIED,
}

@export var id: StringName
@export var display_name: String
@export_multiline var rule_text: String
@export var category: Category = Category.OPERATION
@export var operation: Operation = Operation.MAX_REAL_CARDS
@export var amount: int

func validate() -> Array[String]:
	var errors: Array[String] = []
	if id == &"":
		errors.append("restriction ID is empty")
	if display_name.strip_edges().is_empty():
		errors.append("restriction %s has no display name" % id)
	if rule_text.strip_edges().is_empty():
		errors.append("restriction %s has no rule text" % id)
	match operation:
		Operation.MAX_REAL_CARDS:
			if category != Category.OPERATION:
				errors.append(
					"restriction %s card limit must use operation category" % id
				)
			if amount < 1:
				errors.append(
					"restriction %s requires a positive card limit" % id
				)
		Operation.REQUIRE_ALL_TABLES_OCCUPIED:
			if category != Category.DISTRIBUTION:
				errors.append(
					"restriction %s all-table rule must use distribution category"
					% id
				)
			if amount != 3:
				errors.append(
					"restriction %s must require exactly three tables" % id
				)
		_:
			errors.append("restriction %s has an unknown operation" % id)
	return errors
