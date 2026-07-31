class_name FailureReviewBuilder
extends RefCounted

const MAX_SUGGESTIONS := 3

func build(
	reports: Array,
	target_total: int,
	dealer_failure: bool
) -> Dictionary:
	var cumulative_total := 0
	var weakest_round := 0
	var weakest_total := 0
	var unassigned_dice := 0
	var dealer_reward_lost := 0
	var rule_failures: Array[Dictionary] = []
	var missed_effects: Array[String] = []
	var seen_failures: Dictionary = {}
	var seen_effects: Dictionary = {}

	for index in range(reports.size()):
		var report := reports[index] as ResolutionReport
		if report == null:
			continue
		cumulative_total += report.total
		if weakest_round == 0 or report.total < weakest_total:
			weakest_round = index + 1
			weakest_total = report.total
		unassigned_dice += report.unassigned_dice
		dealer_reward_lost += report.dealer_reward_lost
		for failure in report.rule_failures:
			var key := "%s|%s" % [
				failure.get("rule_id", &""),
				failure.get("reason", ""),
			]
			if seen_failures.has(key):
				continue
			seen_failures[key] = true
			rule_failures.append(failure.duplicate(true))
		for effect in report.missed_effects:
			if seen_effects.has(effect):
				continue
			seen_effects[effect] = true
			missed_effects.append(effect)

	var target_gap := maxi(target_total - cumulative_total, 0)
	var suggestions: Array[String] = []
	if unassigned_dice > 0:
		suggestions.append(
			(
				"先处理 %d 颗未分配骰；庄家会直接扣减固定奖励。"
				% unassigned_dice
			)
			if dealer_failure
			else "先把 %d 颗未分配骰投入可成立的规则台。" % unassigned_dice
		)
	if not rule_failures.is_empty():
		var failure: Dictionary = rule_failures[0]
		suggestions.append(
			"优先检查“%s”：%s"
			% [
				failure.get("display_name", failure.get("rule_id", "规则台")),
				failure.get("reason", "未满足公开条件"),
			]
		)
	if not missed_effects.is_empty():
		suggestions.append(
			"检查结算方向与相邻目标：%s" % missed_effects[0]
		)
	if target_gap > 0 and suggestions.size() < MAX_SUGGESTIONS:
		suggestions.append(
			"当前仍差 %d 点；可从第 %d 轮的 %d 点低谷开始调整。"
			% [target_gap, weakest_round, weakest_total]
		)
	if suggestions.size() > MAX_SUGGESTIONS:
		suggestions.resize(MAX_SUGGESTIONS)

	return {
		"cumulative_total": cumulative_total,
		"target_total": target_total,
		"target_gap": target_gap,
		"weakest_round": weakest_round,
		"weakest_total": weakest_total,
		"unassigned_dice": unassigned_dice,
		"dealer_reward_lost": dealer_reward_lost,
		"rule_failures": rule_failures,
		"missed_effects": missed_effects,
		"suggestions": suggestions,
	}
