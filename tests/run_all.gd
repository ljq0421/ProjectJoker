extends SceneTree

func _initialize() -> void:
	call_deferred("_run_all")

func _run_all() -> void:
	var directory := DirAccess.open("res://tests")
	if directory == null:
		push_error("Cannot open res://tests")
		quit(1)
		return

	var test_files: Array[String] = []
	for file_name in directory.get_files():
		if file_name.ends_with("_test.gd"):
			test_files.append(file_name)
	test_files.sort()

	var failure_count := 0
	for file_name in test_files:
		var suite_script := load("res://tests/%s" % file_name)
		if suite_script == null or not suite_script.can_instantiate():
			push_error("%s: failed to load test suite" % file_name)
			failure_count += 1
			continue
		var suite = suite_script.new()
		suite.run()
		if suite.failures.is_empty():
			print("PASS %s" % file_name)
		else:
			for failure in suite.failures:
				push_error("%s: %s" % [file_name, failure])
			failure_count += suite.failures.size()

	if failure_count == 0:
		print("ALL TESTS PASSED (%d suites)" % test_files.size())
		quit(0)
	else:
		push_error("%d TEST FAILURE(S)" % failure_count)
		quit(1)
