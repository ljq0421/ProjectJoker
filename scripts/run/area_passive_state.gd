class_name AreaPassiveState
extends RefCounted

const GOLD_CAP := 3
const MIRROR_REFRESH_CAP := 2
const FACELESS_RELIEF_CAP := 3

var gold_category_bonuses: Dictionary = {}
var mirror_refresh_tokens := 0
var faceless_target_relief := 0

func begin_encounter(area_id: StringName) -> void:
	if area_id == &"faceless_hub":
		faceless_target_relief = 0

func coefficient_bonus(category: int) -> int:
	return int(gold_category_bonuses.get(category, 0))

func record_gold_report(
	encounter: EncounterDefinition,
	report: ResolutionReport
) -> void:
	if encounter == null or report == null:
		return
	var failed: Dictionary = {}
	for entry in report.rule_failures:
		failed[entry.get("rule_id", &"")] = true
	for rule in encounter.rules:
		if rule == null or failed.has(rule.id) or rule.template == null:
			continue
		var category := int(rule.template.category)
		gold_category_bonuses[category] = mini(
			coefficient_bonus(category) + 1,
			GOLD_CAP
		)

func award_mirror_refresh() -> bool:
	if mirror_refresh_tokens >= MIRROR_REFRESH_CAP:
		return false
	mirror_refresh_tokens += 1
	return true

func consume_mirror_refresh() -> bool:
	if mirror_refresh_tokens <= 0:
		return false
	mirror_refresh_tokens -= 1
	return true

func apply_faceless_failures(failed_count: int, has_next_round: bool) -> int:
	if not has_next_round or failed_count <= 0:
		return 0
	var granted := mini(
		failed_count,
		FACELESS_RELIEF_CAP - faceless_target_relief
	)
	granted = maxi(granted, 0)
	faceless_target_relief += granted
	return granted

func to_snapshot() -> Dictionary:
	return {
		"gold_category_bonuses": gold_category_bonuses.duplicate(true),
		"mirror_refresh_tokens": mirror_refresh_tokens,
		"faceless_target_relief": faceless_target_relief,
	}

func restore_snapshot(snapshot: Dictionary) -> OperationResult:
	var next_gold: Dictionary = snapshot.get(
		"gold_category_bonuses", {}
	).duplicate(true)
	for category in next_gold:
		var amount = next_gold[category]
		if not amount is int or amount < 0 or amount > GOLD_CAP:
			return OperationResult.new(false, "金线区域被动层数无效")
	var next_refresh := int(snapshot.get("mirror_refresh_tokens", 0))
	if next_refresh < 0 or next_refresh > MIRROR_REFRESH_CAP:
		return OperationResult.new(false, "反照免费刷新数量无效")
	var next_relief := int(snapshot.get("faceless_target_relief", 0))
	if next_relief < 0 or next_relief > FACELESS_RELIEF_CAP:
		return OperationResult.new(false, "无面目标减免无效")
	gold_category_bonuses = next_gold
	mirror_refresh_tokens = next_refresh
	faceless_target_relief = next_relief
	return OperationResult.new(true)

func status_copy(area_id: StringName) -> String:
	match area_id:
		&"gold_corridor":
			return "区域协议｜点数 +%d · 关系 +%d · 位置 +%d · 异变 +%d" % [
				coefficient_bonus(RuleTableTemplate.Category.POINT),
				coefficient_bonus(RuleTableTemplate.Category.RELATION),
				coefficient_bonus(RuleTableTemplate.Category.POSITION),
				coefficient_bonus(RuleTableTemplate.Category.DISTORTION),
			]
		&"mirror_hall":
			return "区域协议｜免费刷新 %d / %d" % [
				mirror_refresh_tokens, MIRROR_REFRESH_CAP,
			]
		&"faceless_hub":
			return "区域协议｜本遭遇目标宽限 %d / %d" % [
				faceless_target_relief, FACELESS_RELIEF_CAP,
			]
	return ""
