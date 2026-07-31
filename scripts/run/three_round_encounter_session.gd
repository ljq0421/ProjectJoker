class_name ThreeRoundEncounterSession
extends RefCounted

enum Status {
	NOT_STARTED,
	PLAYING,
	ROUND_SUMMARY,
	AWAITING_RESTRICTION,
	SUCCEEDED,
	FAILED,
}

const DEFAULT_SEED := 20260726
const DEFAULT_TARGET := 100
const ROUND_COUNT := 3
const SUCCESS_INTEL_REWARD := 2

var catalog: CardCatalog
var seed_value: int
var target_total: int
var setup: EncounterRunSetup
var round_count: int
var status: Status = Status.NOT_STARTED
var current_round: int = 0
var current_session: SingleEncounterSession
var current_hand_ids: Array[StringName] = []
var starter_deck_ids: Array[StringName] = []
var committed_reports: Array[ResolutionReport] = []
var cumulative_total: int = 0
var intel_tickets: int = 0
var earned_intel_tickets: int = 0
var shop_offer_ids: Array[StringName] = []
var last_error: String = ""
var selected_final_restriction: FinalRestrictionDefinition

var _run_rng: RunRng
var _deck := CardDeck.new()

func _init(
	p_catalog: CardCatalog,
	p_seed_value: int = DEFAULT_SEED,
	p_target_total: int = DEFAULT_TARGET,
	p_setup: EncounterRunSetup = null
) -> void:
	catalog = p_catalog
	seed_value = p_seed_value
	target_total = p_target_total
	setup = p_setup if p_setup != null else EncounterRunSetup.new()
	round_count = setup.round_count

func start() -> OperationResult:
	if status != Status.NOT_STARTED:
		return _fail("三轮试局已经开始")
	var content_errors := catalog.validate()
	if not content_errors.is_empty():
		return _fail("卡牌内容无效：%s" % "；".join(content_errors))
	var setup_error := _validate_setup()
	if not setup_error.is_empty():
		return _fail(setup_error)

	_run_rng = setup.run_rng if setup.run_rng != null else RunRng.new(seed_value)
	starter_deck_ids = (
		setup.deck_ids.duplicate()
		if not setup.deck_ids.is_empty()
		else catalog.starter_ids()
	)
	_deck.start_encounter(starter_deck_ids, _run_rng)
	current_round = 1
	var begin_result := _begin_round()
	if not begin_result.accepted:
		return begin_result
	status = Status.PLAYING
	last_error = ""
	return OperationResult.new(true)

func accept_committed_report(report: ResolutionReport) -> OperationResult:
	if status != Status.PLAYING:
		return _fail("当前不接受轮次结算")
	if current_session == null or not current_session.controller.committed:
		return _fail("当前轮尚未正式结算")
	var committed_report := current_session.commit()
	if report == null or report != committed_report:
		return _fail("提交的结算报告不是当前轮正式结果")

	committed_reports.append(report)
	cumulative_total += report.total
	earned_intel_tickets += report.intel_delta
	if current_round < round_count:
		if setup.round_schedule != null and current_round == 2:
			status = Status.AWAITING_RESTRICTION
		else:
			status = Status.ROUND_SUMMARY
	else:
		if cumulative_total >= target_total:
			status = Status.SUCCEEDED
			intel_tickets = (
				setup.success_intel_reward
				+ earned_intel_tickets
			)
			if setup.prepare_shop_offers:
				var shuffled_shop_ids := _run_rng.shuffle(catalog.shop_ids())
				shop_offer_ids.assign(shuffled_shop_ids.slice(0, 3))
			else:
				shop_offer_ids.clear()
		else:
			status = Status.FAILED
	last_error = ""
	return OperationResult.new(true)

func advance_round() -> OperationResult:
	if status != Status.ROUND_SUMMARY:
		return _fail("当前不能进入下一轮")
	var rng_snapshot := _run_rng.snapshot_state()
	var deck_snapshot := _deck.snapshot_draw_pile()
	current_round += 1
	var begin_result := _begin_round()
	if not begin_result.accepted:
		current_round -= 1
		_run_rng.restore_state(rng_snapshot)
		_deck.restore_draw_pile(deck_snapshot)
		return begin_result
	status = Status.PLAYING
	last_error = ""
	return OperationResult.new(true)

func choose_final_restriction(
	restriction_id: StringName
) -> OperationResult:
	if status != Status.AWAITING_RESTRICTION:
		return _fail("当前不能选择最终限制")
	var chosen: FinalRestrictionDefinition
	for option in public_restriction_options():
		if option.id == restriction_id:
			chosen = option
			break
	if chosen == null:
		return _fail("所选限制不在公开候选中")

	var rng_snapshot := _run_rng.snapshot_state()
	var deck_snapshot := _deck.snapshot_draw_pile()
	var previous_hand := current_hand_ids.duplicate()
	var previous_session := current_session
	var previous_restriction := selected_final_restriction
	var previous_round := current_round

	selected_final_restriction = chosen
	current_round = 3
	var begin_result := _begin_round()
	if not begin_result.accepted:
		_run_rng.restore_state(rng_snapshot)
		_deck.restore_draw_pile(deck_snapshot)
		current_hand_ids.assign(previous_hand)
		current_session = previous_session
		selected_final_restriction = previous_restriction
		current_round = previous_round
		status = Status.AWAITING_RESTRICTION
		return begin_result
	status = Status.PLAYING
	last_error = ""
	return OperationResult.new(true)

func current_round_plan() -> EncounterRoundPlan:
	var plans: Array[EncounterRoundPlan] = setup.round_plans
	if plans.is_empty() and setup.round_schedule != null:
		plans = setup.round_schedule.round_plans
	if current_round < 1 or current_round > plans.size():
		return null
	return plans[current_round - 1]

func public_restriction_options() -> Array[FinalRestrictionDefinition]:
	if setup.round_schedule == null:
		return []
	return setup.round_schedule.restriction_options()

func active_restriction() -> FinalRestrictionDefinition:
	if current_round == round_count and selected_final_restriction != null:
		return selected_final_restriction
	return setup.fixed_restriction

func _begin_round() -> OperationResult:
	var next_hand_ids: Array[StringName] = (
		setup.fixed_hand_ids.duplicate()
		if not setup.fixed_hand_ids.is_empty()
		else _deck.draw_round()
	)
	if next_hand_ids.size() != CardDeck.HAND_SIZE:
		return _fail("当前轮没有抽到四张手法牌")

	var hand: Array[CardDefinition] = []
	for card_id in next_hand_ids:
		var card := catalog.find_card(card_id)
		if card == null:
			return _fail("手牌包含未知卡牌：%s" % card_id)
		hand.append(card)

	var state := RoundState.new()
	for die_index in range(1, 7):
		var die_id := StringName("d%d" % die_index)
		var rolled_value: int
		if setup.forced_rolls.has(die_id):
			rolled_value = int(setup.forced_rolls[die_id])
		else:
			rolled_value = _run_rng.roll_die()
		var profile := _profile_for(die_id)
		state.dice.append(DieState.new(
			die_id,
			rolled_value,
			profile.engraving_id if profile != null else &"",
			profile.engraved_face if profile != null else 0
		))
	var round_plan := current_round_plan()
	var encounter: EncounterDefinition
	if round_plan != null:
		encounter = round_plan.encounter
	elif setup.encounter != null:
		encounter = setup.encounter
	else:
		encounter = SingleEncounterFixture.make_encounter()
	if encounter == null:
		return _fail("当前回合遭遇不存在")
	var context := (
		setup.resolution_context
		if setup.resolution_context != null
		else ResolutionContext.empty()
	)
	var next_session := SingleEncounterSession.new(
		state,
		encounter,
		hand,
		context,
		active_restriction()
	)
	current_hand_ids.assign(next_hand_ids)
	current_session = next_session
	return OperationResult.new(true)

func _profile_for(die_id: StringName) -> DieState:
	for profile in setup.die_profiles:
		if profile.id == die_id:
			return profile
	return null

func _validate_setup() -> String:
	if setup.success_intel_reward < 0:
		return "成功情报券奖励不能为负数"
	if setup.round_count < 1 or setup.round_count > ROUND_COUNT:
		return "遭遇轮数必须为一到三轮"
	if setup.round_schedule != null and setup.round_count != ROUND_COUNT:
		return "庄家公开日程必须保持三轮"
	if not setup.round_plans.is_empty():
		if setup.round_schedule != null:
			return "普通房逐轮计划不能与庄家日程并存"
		if setup.round_plans.size() != setup.round_count:
			return "普通房逐轮计划数量必须等于遭遇轮数"
		for plan in setup.round_plans:
			var plan_errors := plan.validate()
			if not plan_errors.is_empty():
				return "普通房逐轮计划无效：%s" % "；".join(plan_errors)
	if setup.round_schedule != null:
		var schedule_errors := setup.round_schedule.validate()
		if not schedule_errors.is_empty():
			return "回合日程无效：%s" % "；".join(schedule_errors)
	if setup.fixed_restriction != null:
		var restriction_errors := setup.fixed_restriction.validate()
		if not restriction_errors.is_empty():
			return "固定限制无效：%s" % "；".join(restriction_errors)

	var candidate_deck := (
		setup.deck_ids
		if not setup.deck_ids.is_empty()
		else catalog.starter_ids()
	)
	if candidate_deck.size() != 12:
		return "遭遇牌组必须正好包含十二张牌"
	var deck_ids: Dictionary = {}
	for card_id in candidate_deck:
		if catalog.find_card(card_id) == null:
			return "遭遇牌组包含未知卡牌：%s" % card_id
		if deck_ids.has(card_id):
			return "遭遇牌组包含重复卡牌：%s" % card_id
		deck_ids[card_id] = true
	if not setup.fixed_hand_ids.is_empty():
		if setup.fixed_hand_ids.size() != CardDeck.HAND_SIZE:
			return "固定手牌必须正好包含四张牌"
		var fixed_ids: Dictionary = {}
		for card_id in setup.fixed_hand_ids:
			if catalog.find_card(card_id) == null:
				return "固定手牌包含未知卡牌：%s" % card_id
			if fixed_ids.has(card_id):
				return "固定手牌包含重复卡牌：%s" % card_id
			fixed_ids[card_id] = true

	if setup.round_schedule == null and setup.encounter != null:
		var encounter_errors := ContentValidator.new().validate(setup.encounter.rules, [])
		if not encounter_errors.is_empty():
			return "遭遇规则无效：%s" % "；".join(encounter_errors)

	var expected_die_ids: Dictionary = {}
	for die_index in range(1, 7):
		expected_die_ids[StringName("d%d" % die_index)] = true
	if not setup.die_profiles.is_empty():
		if setup.die_profiles.size() != 6:
			return "骰子配置必须包含 d1 到 d6 六颗骰子"
		var seen_profiles: Dictionary = {}
		for profile in setup.die_profiles:
			if not expected_die_ids.has(profile.id):
				return "骰子配置包含未知骰子：%s" % profile.id
			if seen_profiles.has(profile.id):
				return "骰子配置包含重复骰子：%s" % profile.id
			seen_profiles[profile.id] = true
			if profile.engraving_id == &"":
				if profile.engraved_face != 0:
					return "未刻印骰子的刻印面必须为 0"
			else:
				if profile.engraved_face < 1 or profile.engraved_face > 6:
					return "刻印骰面必须在 1 到 6 之间"
				if (
					setup.resolution_context == null
					or setup.resolution_context.engraving_catalog == null
					or setup.resolution_context.engraving_catalog.find_engraving(
						profile.engraving_id
					) == null
				):
					return "骰子配置包含未知刻印：%s" % profile.engraving_id

	for die_id_value in setup.forced_rolls:
		var die_id := StringName(die_id_value)
		if not expected_die_ids.has(die_id):
			return "强制骰面包含未知骰子：%s" % die_id
		var forced_value := int(setup.forced_rolls[die_id_value])
		if forced_value < 1 or forced_value > 6:
			return "强制骰面必须在 1 到 6 之间"
	return ""

func _fail(reason: String) -> OperationResult:
	last_error = reason
	return OperationResult.new(false, reason)
