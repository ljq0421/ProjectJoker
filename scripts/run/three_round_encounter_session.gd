class_name ThreeRoundEncounterSession
extends RefCounted

const SnapshotCodec = preload("res://scripts/run/run_snapshot_codec.gd")

class RestoreResult extends RefCounted:
	var accepted: bool
	var reason: String
	var session: ThreeRoundEncounterSession

	func _init(
		p_accepted: bool,
		p_reason: String = "",
		p_session: ThreeRoundEncounterSession = null
	) -> void:
		accepted = p_accepted
		reason = p_reason
		session = p_session

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
var next_round_calibration_bonus := 0
var retained_card_id: StringName = &""
var queued_search_identity_ids: Array[StringName] = []
var paid_reroll_rounds: Dictionary = {}
var paid_calibration_rounds: Dictionary = {}

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
	next_round_calibration_bonus += setup.initial_calibration_bonus
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
	_queue_played_searches()
	cumulative_total += report.total
	earned_intel_tickets += report.intel_delta
	if report.consolation_awarded and current_round < round_count:
		next_round_calibration_bonus += 1
	elif current_round >= round_count:
		next_round_calibration_bonus = 0
	if report.full_clear_calibration_awarded and current_round < round_count:
		next_round_calibration_bonus += 1
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

func retention_available() -> bool:
	return (
		status == Status.ROUND_SUMMARY
		and current_round < round_count
		and setup.fixed_hand_ids.is_empty()
		and setup.round_schedule == null
	)

func retain_card(card_id: StringName) -> OperationResult:
	if not retention_available():
		return _fail("当前轮次不提供手牌保留")
	if card_id == &"":
		retained_card_id = &""
		last_error = ""
		return OperationResult.new(true)
	if card_id not in current_hand_ids:
		return _fail("只能保留当前手牌中的牌")
	if current_session == null:
		return _fail("当前手牌状态不存在")
	for card_index in range(current_session.hand.size()):
		if current_session.hand[card_index].id == card_id:
			if current_session.is_card_used(card_index):
				return _fail("已经使用的手法牌不能保留")
			retained_card_id = card_id
			last_error = ""
			return OperationResult.new(true)
	return _fail("当前手牌状态不包含这张牌")

func retainable_card_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	if not retention_available() or current_session == null:
		return result
	for card_index in range(current_session.hand.size()):
		if not current_session.is_card_used(card_index):
			result.append(current_session.hand[card_index].id)
	return result

func paid_reroll(die_id: StringName) -> OperationResult:
	if status != Status.PLAYING or current_session == null:
		return _fail("当前不能使用付费重投")
	if paid_reroll_rounds.has(current_round):
		return _fail("本轮已经使用过付费重投")
	var new_value := _run_rng.roll_die()
	var result := current_session.controller.apply_paid_reroll(die_id, new_value)
	if not result.accepted:
		return _fail(result.reason)
	paid_reroll_rounds[current_round] = true
	last_error = ""
	return OperationResult.new(true)

func paid_add_calibration() -> OperationResult:
	if status != Status.PLAYING or current_session == null:
		return _fail("当前不能购买额外校准")
	if paid_calibration_rounds.has(current_round):
		return _fail("本轮已经购买过额外校准")
	var result := current_session.controller.apply_paid_calibration()
	if not result.accepted:
		return _fail(result.reason)
	paid_calibration_rounds[current_round] = true
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
	var next_hand_ids: Array[StringName] = []
	if not setup.fixed_hand_ids.is_empty():
		next_hand_ids.assign(setup.fixed_hand_ids)
	else:
		if retained_card_id != &"":
			next_hand_ids.append(retained_card_id)
			retained_card_id = &""
		for identity_id in queued_search_identity_ids:
			if next_hand_ids.size() >= setup.hand_size:
				break
			var searched_id := _take_first_identity(identity_id)
			if searched_id != &"":
				next_hand_ids.append(searched_id)
		queued_search_identity_ids.clear()
		next_hand_ids.append_array(
			_deck.draw_round(setup.hand_size - next_hand_ids.size())
		)
	var expected_hand_size := (
		setup.fixed_hand_ids.size()
		if not setup.fixed_hand_ids.is_empty()
		else setup.hand_size
	)
	if next_hand_ids.size() != expected_hand_size:
		return _fail("当前轮没有抽到预期数量的手法牌")

	var hand: Array[CardDefinition] = []
	for card_id in next_hand_ids:
		var card := catalog.find_card(card_id)
		if card == null:
			return _fail("手牌包含未知卡牌：%s" % card_id)
		hand.append(card)

	var state := RoundState.new()
	state.calibration_points += next_round_calibration_bonus
	next_round_calibration_bonus = 0
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
		active_restriction(),
		setup.additional_restrictions,
		setup.undo_allowed,
		setup.undo_mode,
		current_round >= round_count
	)
	current_hand_ids.assign(next_hand_ids)
	current_session = next_session
	return OperationResult.new(true)

func _queue_played_searches() -> void:
	if current_round >= round_count or current_session == null:
		return
	for played_card in current_session.controller.state.played_cards:
		if played_card is not PlayedCard or played_card.is_mirror_copy:
			continue
		for effect in played_card.effective_effects():
			if effect.operation == EffectSpec.Operation.QUEUE_SEARCH:
				queued_search_identity_ids.append(effect.search_identity)

func _take_first_identity(identity_id: StringName) -> StringName:
	var identities := BuildIdentityCatalog.new()
	for card_id in _deck.snapshot_draw_pile():
		if identities.identity_for_card(catalog.find_card(card_id)) == identity_id:
			_deck.take_card(card_id)
			return card_id
	return &""

func _profile_for(die_id: StringName) -> DieState:
	for profile in setup.die_profiles:
		if profile.id == die_id:
			return profile
	return null

func _validate_setup() -> String:
	if setup.success_intel_reward < 0:
		return "成功情报券奖励不能为负数"
	if setup.hand_size < 1 or setup.hand_size > CardDeck.HAND_SIZE:
		return "每轮手牌数量必须为一到四张"
	for restriction in setup.additional_restrictions:
		if restriction == null:
			return "附加公开限制不能为空"
		var restriction_errors := restriction.validate()
		if not restriction_errors.is_empty():
			return "附加公开限制无效：%s" % "；".join(restriction_errors)
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
	if (
		candidate_deck.size() < CardDeck.MIN_DECK_SIZE
		or candidate_deck.size() > CardDeck.MAX_DECK_SIZE
	):
		return "遭遇牌组必须包含十二至十五张牌"
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

func to_snapshot() -> Dictionary:
	var reports: Array[Dictionary] = []
	for report in committed_reports:
		reports.append(SnapshotCodec.report_to_snapshot(report))
	return {
		"seed_value": seed_value,
		"target_total": target_total,
		"round_count": round_count,
		"status": status,
		"current_round": current_round,
		"current_hand_ids": current_hand_ids.duplicate(),
		"starter_deck_ids": starter_deck_ids.duplicate(),
		"committed_reports": reports,
		"cumulative_total": cumulative_total,
		"intel_tickets": intel_tickets,
		"earned_intel_tickets": earned_intel_tickets,
		"shop_offer_ids": shop_offer_ids.duplicate(),
		"last_error": last_error,
		"selected_restriction_id": (
			selected_final_restriction.id
			if selected_final_restriction != null
			else &""
		),
		"next_round_calibration_bonus": next_round_calibration_bonus,
		"retained_card_id": retained_card_id,
		"queued_search_identity_ids": queued_search_identity_ids.duplicate(),
		"paid_reroll_rounds": paid_reroll_rounds.duplicate(true),
		"paid_calibration_rounds": paid_calibration_rounds.duplicate(true),
		"rng_state": _run_rng.snapshot_state(),
		"draw_pile": _deck.snapshot_draw_pile(),
		"current_session": (
			current_session.to_snapshot() if current_session != null else {}
		),
	}

static func from_snapshot(
	p_catalog: CardCatalog,
	p_setup: EncounterRunSetup,
	snapshot: Dictionary
) -> RestoreResult:
	if snapshot.is_empty() or not snapshot.get("current_session", {}) is Dictionary:
		return RestoreResult.new(false, "活跃遭遇检查点格式无效")
	var restored := ThreeRoundEncounterSession.new(
		p_catalog,
		int(snapshot.get("seed_value", DEFAULT_SEED)),
		int(snapshot.get("target_total", DEFAULT_TARGET)),
		p_setup
	)
	restored.round_count = int(snapshot.get("round_count", p_setup.round_count))
	restored.status = int(snapshot.get("status", Status.PLAYING))
	restored.current_round = int(snapshot.get("current_round", 1))
	restored.current_hand_ids.assign(snapshot.get("current_hand_ids", []))
	restored.starter_deck_ids.assign(snapshot.get("starter_deck_ids", []))
	restored.cumulative_total = int(snapshot.get("cumulative_total", 0))
	restored.intel_tickets = int(snapshot.get("intel_tickets", 0))
	restored.earned_intel_tickets = int(snapshot.get("earned_intel_tickets", 0))
	restored.shop_offer_ids.assign(snapshot.get("shop_offer_ids", []))
	restored.last_error = String(snapshot.get("last_error", ""))
	restored.next_round_calibration_bonus = int(
		snapshot.get("next_round_calibration_bonus", 0)
	)
	restored.retained_card_id = snapshot.get("retained_card_id", &"")
	restored.queued_search_identity_ids.assign(
		snapshot.get("queued_search_identity_ids", [])
	)
	restored.paid_reroll_rounds = snapshot.get("paid_reroll_rounds", {}).duplicate(true)
	restored.paid_calibration_rounds = snapshot.get(
		"paid_calibration_rounds", {}
	).duplicate(true)
	restored._run_rng = p_setup.run_rng if p_setup.run_rng != null else RunRng.new(restored.seed_value)
	restored._run_rng.restore_state(int(snapshot.get("rng_state", restored.seed_value)))
	var draw_pile: Array[StringName] = []
	draw_pile.assign(snapshot.get("draw_pile", []))
	restored._deck.restore_draw_pile(draw_pile)
	for report_snapshot in snapshot.get("committed_reports", []):
		restored.committed_reports.append(
			SnapshotCodec.report_from_snapshot(report_snapshot)
		)
	var restriction_id: StringName = snapshot.get("selected_restriction_id", &"")
	if restriction_id != &"" and p_setup.round_schedule != null:
		for option in p_setup.round_schedule.restriction_options():
			if option.id == restriction_id:
				restored.selected_final_restriction = option
				break
	var single_snapshot: Dictionary = snapshot["current_session"]
	var controller_snapshot: Dictionary = single_snapshot.get("controller", {})
	var history: Array = controller_snapshot.get("history", [])
	if history.is_empty():
		return RestoreResult.new(false, "活跃遭遇缺少动作历史")
	var state: RoundState = SnapshotCodec.round_state_from_snapshot(
		history[-1].get("state", {}),
		p_catalog
	)
	var hand: Array[CardDefinition] = []
	for card_id in single_snapshot.get("hand_ids", []):
		var card := p_catalog.find_card(card_id)
		if card == null:
			return RestoreResult.new(false, "活跃遭遇手牌包含未知卡牌")
		hand.append(card)
	var encounter := restored._encounter_for_round(restored.current_round)
	if encounter == null:
		return RestoreResult.new(false, "活跃遭遇规则不存在")
	restored.current_session = SingleEncounterSession.new(
		state,
		encounter,
		hand,
		p_setup.resolution_context,
		restored.active_restriction(),
		p_setup.additional_restrictions,
		bool(single_snapshot.get("undo_allowed", true)),
		controller_snapshot.get("undo_mode", p_setup.undo_mode),
		bool(single_snapshot.get("is_final_round", false))
	)
	var single_result := restored.current_session.restore_snapshot(
		single_snapshot,
		p_catalog
	)
	if not single_result.accepted:
		return RestoreResult.new(false, single_result.reason)
	return RestoreResult.new(true, "", restored)

func _encounter_for_round(round_number: int) -> EncounterDefinition:
	var plans: Array[EncounterRoundPlan] = setup.round_plans
	if plans.is_empty() and setup.round_schedule != null:
		plans = setup.round_schedule.round_plans
	if round_number >= 1 and round_number <= plans.size():
		return plans[round_number - 1].encounter
	if setup.encounter != null:
		return setup.encounter
	return SingleEncounterFixture.make_encounter()
