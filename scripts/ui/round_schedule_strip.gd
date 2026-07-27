class_name RoundScheduleStrip
extends PanelContainer

const CURRENT_TINT := Color(0.68, 1.0, 0.96, 1.0)
const COMPLETE_TINT := Color(0.58, 0.86, 0.68, 0.82)
const FUTURE_TINT := Color(0.68, 0.68, 0.78, 0.66)
const RESTRICTED_TINT := Color(1.0, 0.76, 0.38, 1.0)

@onready var round_cards: Array[PanelContainer] = [
	%RoundOneCard,
	%RoundTwoCard,
	%RoundThreeCard,
]
@onready var round_titles: Array[Label] = [
	%RoundOneTitle,
	%RoundTwoTitle,
	%RoundThreeTitle,
]
@onready var round_details: Array[Label] = [
	%RoundOneDetail,
	%RoundTwoDetail,
	%RoundThreeDetail,
]

func bind_schedule(
	schedule: DealerRoundSchedule,
	run_session: ThreeRoundEncounterSession
) -> bool:
	if (
		schedule == null
		or run_session == null
		or schedule.round_plans.size() != 3
	):
		visible = false
		return false
	for index in range(3):
		var plan := schedule.round_plans[index]
		round_titles[index].text = "%d · %s" % [index + 1, plan.display_name]
		round_details[index].text = plan.public_summary
		var round_number := index + 1
		if round_number < run_session.current_round:
			round_cards[index].self_modulate = COMPLETE_TINT
			round_titles[index].text += "　✓ 已完成"
		elif round_number == run_session.current_round:
			round_cards[index].self_modulate = CURRENT_TINT
			round_titles[index].text += "　当前"
		else:
			round_cards[index].self_modulate = FUTURE_TINT
	if (
		run_session.status
		== ThreeRoundEncounterSession.Status.AWAITING_RESTRICTION
	):
		round_cards[2].self_modulate = RESTRICTED_TINT
		round_titles[2].text += "　待选择限制"
	if run_session.selected_final_restriction != null:
		round_cards[2].self_modulate = (
			CURRENT_TINT
			if run_session.current_round == 3
			else COMPLETE_TINT
		)
		round_details[2].text += "\n限制：%s" % (
			run_session.selected_final_restriction.display_name
		)
	visible = true
	return true
