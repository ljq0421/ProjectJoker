extends "res://tests/test_case.gd"

func run() -> void:
	assert_equal(2 + 2, 4, "assert_equal should accept equal values")
	assert_true(true, "assert_true should accept true")
	assert_false(false, "assert_false should accept false")
