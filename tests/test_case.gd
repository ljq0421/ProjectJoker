class_name TestCase
extends RefCounted

var failures: Array[String] = []

func assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s; expected=%s actual=%s" % [message, expected, actual])

func assert_true(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func assert_false(value: bool, message: String) -> void:
	if value:
		failures.append(message)
