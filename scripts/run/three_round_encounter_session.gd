class_name ThreeRoundEncounterSession
extends RefCounted

enum Status {
	NOT_STARTED,
	PLAYING,
	ROUND_SUMMARY,
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
var status: Status = Status.NOT_STARTED
var current_round: int = 0
var current_session: SingleEncounterSession
var current_hand_ids: Array[StringName] = []
var starter_deck_ids: Array[StringName] = []
var committed_reports: Array[ResolutionReport] = []
var cumulative_total: int = 0
var intel_tickets: int = 0
var shop_offer_ids: Array[StringName] = []
var last_error: String = ""

var _run_rng: RunRng
var _deck := CardDeck.new()

func _init(
	p_catalog: CardCatalog,
	p_seed_value: int = DEFAULT_SEED,
	p_target_total: int = DEFAULT_TARGET
) -> void:
	catalog = p_catalog
	seed_value = p_seed_value
	target_total = p_target_total

func start() -> OperationResult:
	if status != Status.NOT_STARTED:
		return _fail("三轮试局已经开始")
	var content_errors := catalog.validate()
	if not content_errors.is_empty():
		return _fail("卡牌内容无效：%s" % "；".join(content_errors))

	_run_rng = RunRng.new(seed_value)
	starter_deck_ids = catalog.starter_ids()
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
	if current_round < ROUND_COUNT:
		status = Status.ROUND_SUMMARY
	else:
		if cumulative_total >= target_total:
			status = Status.SUCCEEDED
			intel_tickets = SUCCESS_INTEL_REWARD
			shop_offer_ids.assign(_run_rng.shuffle(catalog.shop_ids()))
		else:
			status = Status.FAILED
	last_error = ""
	return OperationResult.new(true)

func advance_round() -> OperationResult:
	if status != Status.ROUND_SUMMARY:
		return _fail("当前不能进入下一轮")
	current_round += 1
	var begin_result := _begin_round()
	if not begin_result.accepted:
		current_round -= 1
		return begin_result
	status = Status.PLAYING
	last_error = ""
	return OperationResult.new(true)

func _begin_round() -> OperationResult:
	current_hand_ids = _deck.draw_round()
	if current_hand_ids.size() != CardDeck.HAND_SIZE:
		return _fail("当前轮没有抽到四张手法牌")

	var hand: Array[CardDefinition] = []
	for card_id in current_hand_ids:
		var card := catalog.find_card(card_id)
		if card == null:
			return _fail("手牌包含未知卡牌：%s" % card_id)
		hand.append(card)

	var state := RoundState.new()
	for die_index in range(1, 7):
		state.dice.append(DieState.new(
			StringName("d%d" % die_index),
			_run_rng.roll_die()
		))
	current_session = SingleEncounterSession.new(
		state,
		SingleEncounterFixture.make_encounter(),
		hand
	)
	return OperationResult.new(true)

func _fail(reason: String) -> OperationResult:
	last_error = reason
	return OperationResult.new(false, reason)
