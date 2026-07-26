extends SceneTree

const DealerDefinitionScript = preload("res://scripts/dealers/dealer_definition.gd")
const EngravingDefinitionScript = preload("res://scripts/engravings/engraving_definition.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var errors: Array[String] = []
	for directory in [
		"res://resources/dealers/stage5",
		"res://resources/engravings/stage5",
	]:
		var directory_error := DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(directory)
		)
		if directory_error != OK:
			errors.append("%s: %s" % [directory, error_string(directory_error)])

	var dealer := DealerDefinitionScript.new()
	dealer.id = &"dealer_iron_abacus"
	dealer.display_name = "铁算盘"
	dealer.rule_text = "每轮固定奖励 12；每有一颗骰子未分配，奖励减少 2，最低为 0。"
	dealer.fixed_reward = 12
	dealer.penalty_per_unassigned_die = 2
	dealer.tags = PackedStringArray(["庄家", "全骰利用"])
	_save(dealer, "res://resources/dealers/stage5/dealer_iron_abacus.tres", errors)

	var specs := [
		[&"engraving_echo", "回声",
			"刻印面投出并分配后，规则台通过时获得较高相邻骰点数的一半（向下取整）。",
			EngravingDefinitionScript.Operation.ECHO_ADJACENT, 2,
			PackedStringArray(["相邻", "固定奖励"])],
		[&"engraving_anchor", "锚定",
			"刻印面投出后不能校准或被点数牌修改；规则台通过时固定奖励 +4。",
			EngravingDefinitionScript.Operation.ANCHOR_DIE, 4,
			PackedStringArray(["保护", "固定奖励"])],
		[&"engraving_bridge", "桥接",
			"刻印面投出并分配后，把该骰有效点数传递给结算方向中的下一张有效规则台。",
			EngravingDefinitionScript.Operation.BRIDGE_FORWARD, 1,
			PackedStringArray(["桌间", "传递"])],
		[&"engraving_prism", "棱镜",
			"刻印面投出并分配后，在奇偶条件中同时视为奇数与偶数。",
			EngravingDefinitionScript.Operation.PRISM_PARITY, 0,
			PackedStringArray(["条件", "奇偶"])],
	]
	for spec in specs:
		var engraving := EngravingDefinitionScript.new()
		engraving.id = spec[0]
		engraving.display_name = spec[1]
		engraving.rule_text = spec[2]
		engraving.operation = spec[3]
		engraving.amount = spec[4]
		engraving.tags = spec[5]
		_save(
			engraving,
			"res://resources/engravings/stage5/%s.tres" % String(engraving.id),
			errors
		)

	if errors.is_empty():
		print("GENERATED STAGE5 CONTENT: 1 DEALER, 4 ENGRAVINGS")
		quit(0)
	else:
		for error in errors:
			push_error(error)
		quit(1)

func _save(resource: Resource, path: String, errors: Array[String]) -> void:
	var result := ResourceSaver.save(resource, path, ResourceSaver.FLAG_CHANGE_PATH)
	if result != OK:
		errors.append("%s: %s" % [path, error_string(result)])
