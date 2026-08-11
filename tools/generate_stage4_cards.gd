extends SceneTree

const OUTPUT_DIR := "res://resources/cards/stage4"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if directory_error != OK:
		push_error("Cannot create stage 4 card directory: %s" % error_string(directory_error))
		quit(1)
		return

	var definitions: Array[Dictionary] = [
		_spec(&"starter_nudge_down_1", "拨码", "令一颗骰子的点数 -1，最终点数限制在 1..6。", CardDefinition.TargetType.DIE, ["骰值", "微调"], [[EffectSpec.Operation.ADJUST_DIE, -1]]),
		_spec(&"starter_nudge_up_1", "推码", "令一颗骰子的点数 +1，最终点数限制在 1..6。", CardDefinition.TargetType.DIE, ["骰值", "微调"], [[EffectSpec.Operation.ADJUST_DIE, 1]]),
		_spec(&"starter_nudge_down_2", "深降", "令一颗骰子的点数 -2，最终点数限制在 1..6。", CardDefinition.TargetType.DIE, ["骰值", "强调"], [[EffectSpec.Operation.ADJUST_DIE, -2]]),
		_spec(&"starter_nudge_up_2", "跃升", "令一颗骰子的点数 +2，最终点数限制在 1..6。", CardDefinition.TargetType.DIE, ["骰值", "强调"], [[EffectSpec.Operation.ADJUST_DIE, 2]]),
		_spec(&"starter_map_1", "映射", "令一张规则台的系数 +1。", CardDefinition.TargetType.TABLE, ["规则台", "系数"], [[EffectSpec.Operation.MODIFY_COEFFICIENT, 1]]),
		_spec(&"starter_map_2", "增幅映射", "令一张规则台的系数 +2。", CardDefinition.TargetType.TABLE, ["规则台", "系数"], [[EffectSpec.Operation.MODIFY_COEFFICIENT, 2]]),
		_spec(&"starter_repeat_1", "复写", "令一张规则台额外结算 1 次。", CardDefinition.TargetType.TABLE, ["规则台", "重复"], [[EffectSpec.Operation.REPEAT_TABLE, 1]]),
		_spec(&"starter_repeat_2", "双重复写", "令一张规则台额外结算 2 次。", CardDefinition.TargetType.TABLE, ["规则台", "重复"], [[EffectSpec.Operation.REPEAT_TABLE, 2]]),
		_spec(&"starter_stable_repeat", "稳态复写", "令一张规则台的系数 -1（最低为 1），并额外结算 1 次。", CardDefinition.TargetType.TABLE, ["规则台", "权衡"], [[EffectSpec.Operation.MODIFY_COEFFICIENT, -1], [EffectSpec.Operation.REPEAT_TABLE, 1]]),
		_spec(&"starter_amplified_repeat", "增幅复写", "令一张规则台的系数 +1，并额外结算 1 次。", CardDefinition.TargetType.TABLE, ["规则台", "联动"], [[EffectSpec.Operation.MODIFY_COEFFICIENT, 1], [EffectSpec.Operation.REPEAT_TABLE, 1]]),
		_spec(&"starter_reverse", "倒序", "反转本轮规则台的解析顺序。", CardDefinition.TargetType.GLOBAL, ["全局", "顺序"], [[EffectSpec.Operation.REVERSE_RESOLUTION, 0]]),
		_spec(&"starter_link", "桥接", "左台先通过并结算，右台也通过时，复制左台本轮结算分。", CardDefinition.TargetType.GAP, ["桌间", "传递"], [[EffectSpec.Operation.LINK_NEIGHBORS, 1]]),
		_spec(&"shop_precision_map", "精密映射", "令一张规则台的系数 +3。", CardDefinition.TargetType.TABLE, ["商店", "系数"], [[EffectSpec.Operation.MODIFY_COEFFICIENT, 3]]),
		_spec(&"shop_triple_repeat", "三重复写", "令一张规则台额外结算 3 次。", CardDefinition.TargetType.TABLE, ["商店", "重复"], [[EffectSpec.Operation.REPEAT_TABLE, 3]]),
		_spec(&"shop_long_push", "长距推码", "令一颗骰子的点数 +3，最终点数限制在 1..6。", CardDefinition.TargetType.DIE, ["商店", "骰值"], [[EffectSpec.Operation.ADJUST_DIE, 3]]),
	]

	var failures: Array[String] = []
	for definition in definitions:
		var card := _make_card(definition)
		var path := OUTPUT_DIR.path_join("%s.tres" % String(card.id))
		var save_error := ResourceSaver.save(card, path, ResourceSaver.FLAG_CHANGE_PATH)
		if save_error != OK:
			failures.append("%s: %s" % [path, error_string(save_error)])

	if failures.is_empty():
		print("GENERATED %d STAGE 4 CARDS" % definitions.size())
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _spec(
	id: StringName,
	display_name: String,
	rule_text: String,
	target_type: CardDefinition.TargetType,
	tags: Array,
	effects: Array
) -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"rule_text": rule_text,
		"target_type": target_type,
		"tags": tags,
		"effects": effects,
	}

func _make_card(spec: Dictionary) -> CardDefinition:
	var card := CardDefinition.new()
	card.id = spec.id
	card.display_name = spec.display_name
	card.rule_text = spec.rule_text
	card.target_type = spec.target_type
	card.tags = PackedStringArray(spec.tags)
	var effects: Array[EffectSpec] = []
	for effect_spec in spec.effects:
		var effect := EffectSpec.new()
		effect.operation = effect_spec[0]
		effect.amount = effect_spec[1]
		effects.append(effect)
	card.effects = effects
	return card
