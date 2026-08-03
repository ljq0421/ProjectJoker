extends SceneTree

const TEST_FILES := [
	"interaction_motion_contract_test.gd",
	"resolution_playback_test.gd",
	"resolution_playback_ui_contract_test.gd",
	"sfx_service_test.gd",
	"sfx_ui_contract_test.gd",
	"ui_component_contract_test.gd",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failure_count := 0
	for file_name in TEST_FILES:
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
		print("INTERACTION MOTION TESTS PASSED (%d suites)" % TEST_FILES.size())
		quit(0)
	else:
		push_error("%d INTERACTION MOTION TEST FAILURE(S)" % failure_count)
		quit(1)
