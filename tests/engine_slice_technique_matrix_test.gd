extends "res://tests/test_case.gd"

const Catalog = preload("res://scripts/engine_slice/engine_slice_catalog.gd")

func run() -> void:
	var catalog = Catalog.new()
	var expected_names := {
		&"nudge_down": ["拨码", "深拨", "借力"],
		&"nudge_up": ["推码", "连推", "冒进"],
		&"flip_value": ["翻面", "镜面蓄能", "反照泄压"],
		&"set_four": ["定标", "稳态标尺", "三台校准"],
		&"odd_lift": ["奇数跃迁", "登顶", "越轨"],
		&"even_drop": ["偶数深降", "缓降", "落差反击"],
		&"map_attack": ["破绽映射", "余影映射", "双倍映射"],
		&"map_guard": ["护契映射", "回流映射", "尖契映射"],
		&"repeat_attack": ["破绽复写", "留档复写", "三联复写"],
		&"repeat_guard": ["护契复写", "回单", "追索"],
		&"engine_charge": ["蓄能并轨", "闭环", "超额并轨"],
		&"gold_stamp": ["金线盖印", "双印", "总账印"],
	}
	assert_equal(catalog.technique_ids().size(), 12, "matrix should contain twelve techniques")
	for technique_id in expected_names:
		var definition = catalog.technique(technique_id)
		for index in 3:
			var branch: StringName = [&"", &"a", &"b"][index]
			var profile: Dictionary = definition.profile_for(branch)
			assert_equal(definition.branch_name(branch), expected_names[technique_id][index], "%s branch %d should have independent name" % [technique_id, index])
			assert_true(not String(profile.get("description", "")).is_empty(), "%s branch %d needs complete copy" % [technique_id, index])
			assert_true(profile.has("returns_die"), "%s branch %d needs explicit return policy" % [technique_id, index])
			assert_true(profile.has("activation") and profile.has("riders"), "%s branch %d needs declarative effects" % [technique_id, index])
