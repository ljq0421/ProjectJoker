class_name IronAbacusSliceSession
extends RefCounted

enum Phase {
	NOT_STARTED,
	NORMAL_ROOM,
	SHOP,
	DEALER,
	ENGRAVING_REWARD,
	ENGRAVING_INSTALL,
	VERIFICATION,
	COMPLETE,
	FAILED,
}

const VERIFICATION_HAND_SIZE := 4

var phase: Phase = Phase.NOT_STARTED
var seed_value: int
var normal_target: int
var dealer_target: int
var card_catalog := CardCatalog.new()
var dealer_catalog := DealerCatalog.new()
var engraving_catalog := EngravingCatalog.new()
var run_rng: RunRng
var encounter_session: ThreeRoundEncounterSession
var shop_session: ShopSession
var verification_session: SingleEncounterSession
var deck_ids: Array[StringName] = []
var intel_tickets: int = 0
var die_profiles: Array[DieState] = []
var engraving_offer_ids: Array[StringName] = []
var selected_engraving_id: StringName = &""
var installed_die_id: StringName = &""
var installed_face: int = 0
var failure_origin: Phase = Phase.NOT_STARTED
var last_error: String = ""

var _dealer_boundary: Dictionary = {}
var _verification_boundary: Dictionary = {}
var _shop_left: bool = false
var _verification_report_accepted: bool = false

func _init(
	p_seed_value: int = 20260726,
	p_normal_target: int = 100,
	p_dealer_target: int = 150
) -> void:
	seed_value = p_seed_value
	normal_target = p_normal_target
	dealer_target = p_dealer_target

func start() -> OperationResult:
	if phase != Phase.NOT_STARTED:
		return _fail("完整切片已经开始")
	var content_errors: Array[String] = []
	content_errors.append_array(card_catalog.validate())
	content_errors.append_array(dealer_catalog.validate())
	content_errors.append_array(engraving_catalog.validate())
	if not content_errors.is_empty():
		return _fail("切片内容无效：%s" % "；".join(content_errors))

	run_rng = RunRng.new(seed_value)
	deck_ids = card_catalog.starter_ids()
	intel_tickets = 0
	die_profiles = _blank_profiles()
	var setup := EncounterRunSetup.new()
	setup.run_rng = run_rng
	setup.deck_ids = deck_ids
	setup.encounter = SingleEncounterFixture.make_encounter()
	setup.resolution_context = ResolutionContext.empty()
	setup.success_intel_reward = ThreeRoundEncounterSession.SUCCESS_INTEL_REWARD
	setup.prepare_shop_offers = true
	setup.die_profiles = _clone_profiles(die_profiles)
	encounter_session = ThreeRoundEncounterSession.new(
		card_catalog,
		seed_value,
		normal_target,
		setup
	)
	var start_result := encounter_session.start()
	if not start_result.accepted:
		return _fail(start_result.reason)
	phase = Phase.NORMAL_ROOM
	last_error = ""
	return OperationResult.new(true)

func accept_encounter_report(report: ResolutionReport) -> OperationResult:
	if phase != Phase.NORMAL_ROOM and phase != Phase.DEALER:
		return _fail("当前阶段不接受三轮遭遇报告")
	var active_phase := phase
	var result := encounter_session.accept_committed_report(report)
	if not result.accepted:
		return _fail(result.reason)
	if encounter_session.status == ThreeRoundEncounterSession.Status.FAILED:
		failure_origin = active_phase
		phase = Phase.FAILED
	elif (
		active_phase == Phase.DEALER
		and encounter_session.status == ThreeRoundEncounterSession.Status.SUCCEEDED
	):
		var shuffled := run_rng.shuffle(engraving_catalog.all_ids())
		engraving_offer_ids.clear()
		for index in range(3):
			engraving_offer_ids.append(shuffled[index])
		selected_engraving_id = &""
		phase = Phase.ENGRAVING_REWARD
	last_error = ""
	return OperationResult.new(true)

func advance_encounter_round() -> OperationResult:
	if phase != Phase.NORMAL_ROOM and phase != Phase.DEALER:
		return _fail("当前阶段不能进入下一轮")
	var result := encounter_session.advance_round()
	if not result.accepted:
		return _fail(result.reason)
	last_error = ""
	return OperationResult.new(true)

func open_shop() -> OperationResult:
	if (
		phase != Phase.NORMAL_ROOM
		or encounter_session == null
		or encounter_session.status != ThreeRoundEncounterSession.Status.SUCCEEDED
	):
		return _fail("只有普通房成功后才能进入商店")
	deck_ids = encounter_session.starter_deck_ids.duplicate()
	intel_tickets = encounter_session.intel_tickets
	shop_session = ShopSession.new(
		card_catalog,
		deck_ids,
		encounter_session.shop_offer_ids,
		intel_tickets
	)
	_shop_left = false
	phase = Phase.SHOP
	last_error = ""
	return OperationResult.new(true)

func leave_shop() -> OperationResult:
	if phase != Phase.SHOP or shop_session == null:
		return _fail("当前不在可离开的商店中")
	if _shop_left:
		return _fail("商店已经结算，等待挑战庄家")
	deck_ids = shop_session.deck_ids.duplicate()
	intel_tickets = shop_session.intel_tickets
	_dealer_boundary = _capture_boundary()
	_shop_left = true
	last_error = ""
	return OperationResult.new(true)

func start_dealer() -> OperationResult:
	if phase != Phase.SHOP or not _shop_left:
		return _fail("必须先结算商店才能挑战铁算盘")
	var restore_result := _restore_boundary(_dealer_boundary)
	if not restore_result.accepted:
		return restore_result
	return _create_dealer_encounter()

func retry_dealer() -> OperationResult:
	if phase != Phase.FAILED or failure_origin != Phase.DEALER:
		return _fail("只有铁算盘失败后才能从庄家边界重试")
	var restore_result := _restore_boundary(_dealer_boundary)
	if not restore_result.accepted:
		return restore_result
	return _create_dealer_encounter()

func select_engraving(engraving_id: StringName) -> OperationResult:
	if phase != Phase.ENGRAVING_REWARD and phase != Phase.ENGRAVING_INSTALL:
		return _fail("当前不能选择刻印")
	if engraving_id not in engraving_offer_ids:
		return _fail("所选刻印不在本次候选中")
	selected_engraving_id = engraving_id
	phase = Phase.ENGRAVING_INSTALL
	last_error = ""
	return OperationResult.new(true)

func install_selected_engraving(
	die_id: StringName,
	face: int
) -> OperationResult:
	if phase != Phase.ENGRAVING_INSTALL:
		return _fail("请先从候选中选择一个刻印")
	var install_result := EngravingInstallationService.new().install(
		die_profiles,
		engraving_offer_ids,
		selected_engraving_id,
		die_id,
		face,
		engraving_catalog
	)
	if not install_result.accepted:
		return _fail(install_result.reason)
	die_profiles = install_result.profiles
	installed_die_id = die_id
	installed_face = face
	_verification_boundary = _capture_boundary()
	var verification_result := _create_verification()
	if not verification_result.accepted:
		return verification_result
	last_error = ""
	return OperationResult.new(true)

func accept_verification_report(report: ResolutionReport) -> OperationResult:
	if phase != Phase.VERIFICATION or verification_session == null:
		return _fail("当前不接受刻印验证报告")
	if _verification_report_accepted:
		return _fail("当前刻印验证报告已经处理")
	if not verification_session.controller.committed:
		return _fail("刻印验证尚未正式结算")
	var committed_report := verification_session.commit()
	if report == null or report != committed_report:
		return _fail("提交的刻印验证报告不是当前正式结果")
	_verification_report_accepted = true

	var applied := report.events.any(
		func(event: ResolutionEvent) -> bool: return (
			event.source_id == selected_engraving_id
			and event.effect_applied
		)
	)
	if applied:
		phase = Phase.COMPLETE
		last_error = ""
		return OperationResult.new(true)

	var diagnostics: Array[String] = []
	for event in report.events:
		if event.source_id == selected_engraving_id and not event.effect_applied:
			diagnostics.append(event.label)
	if not diagnostics.is_empty():
		last_error = "刻印未完成验证：%s" % "；".join(diagnostics)
	elif not _is_assigned(verification_session.controller.state, installed_die_id):
		last_error = "刻印未完成验证：刻印骰尚未分配到规则台"
	else:
		last_error = "刻印未完成验证：规则台未通过或刻印面未命中"
	return OperationResult.new(true, last_error)

func retry_verification() -> OperationResult:
	if phase != Phase.VERIFICATION or not _verification_report_accepted:
		return _fail("只有未触发的正式刻印验证才能重试")
	var restore_result := _restore_boundary(_verification_boundary)
	if not restore_result.accepted:
		return restore_result
	return _create_verification()

func restart_slice() -> OperationResult:
	if phase == Phase.NOT_STARTED:
		return _fail("完整切片尚未开始")
	_reset_owned_state()
	return start()

func _create_dealer_encounter() -> OperationResult:
	var setup := EncounterRunSetup.new()
	setup.run_rng = run_rng
	setup.deck_ids = deck_ids
	setup.encounter = SingleEncounterFixture.make_encounter()
	setup.resolution_context = ResolutionContext.new(
		dealer_catalog.iron_abacus(),
		engraving_catalog
	)
	setup.success_intel_reward = 0
	setup.prepare_shop_offers = false
	setup.die_profiles = _clone_profiles(die_profiles)
	var next_encounter := ThreeRoundEncounterSession.new(
		card_catalog,
		seed_value,
		dealer_target,
		setup
	)
	var result := next_encounter.start()
	if not result.accepted:
		return _fail(result.reason)
	encounter_session = next_encounter
	failure_origin = Phase.NOT_STARTED
	phase = Phase.DEALER
	last_error = ""
	return OperationResult.new(true)

func _create_verification() -> OperationResult:
	var restore_result := _restore_boundary(_verification_boundary)
	if not restore_result.accepted:
		return restore_result
	var deck := CardDeck.new()
	deck.start_encounter(deck_ids, run_rng)
	var hand_ids := deck.draw_round()
	if hand_ids.size() != VERIFICATION_HAND_SIZE:
		return _fail("刻印验证没有抽到四张手法牌")
	var hand: Array[CardDefinition] = []
	for card_id in hand_ids:
		var card := card_catalog.find_card(card_id)
		if card == null:
			return _fail("刻印验证手牌包含未知卡牌：%s" % card_id)
		hand.append(card)

	var state := RoundState.new()
	for die_index in range(1, 7):
		var die_id := StringName("d%d" % die_index)
		var rolled_value := (
			installed_face
			if die_id == installed_die_id
			else run_rng.roll_die()
		)
		var profile := _find_profile(die_profiles, die_id)
		if profile == null:
			return _fail("刻印验证缺少骰子配置：%s" % die_id)
		state.dice.append(DieState.new(
			die_id,
			rolled_value,
			profile.engraving_id,
			profile.engraved_face
		))
	verification_session = SingleEncounterSession.new(
		state,
		SingleEncounterFixture.make_encounter(),
		hand,
		ResolutionContext.new(null, engraving_catalog)
	)
	_verification_report_accepted = false
	phase = Phase.VERIFICATION
	last_error = ""
	return OperationResult.new(true)

func _capture_boundary() -> Dictionary:
	return {
		"rng_state": run_rng.snapshot_state(),
		"deck_ids": deck_ids.duplicate(),
		"intel_tickets": intel_tickets,
		"die_profiles": _clone_profiles(die_profiles),
	}

func _restore_boundary(boundary: Dictionary) -> OperationResult:
	var boundary_error := _boundary_error(boundary)
	if not boundary_error.is_empty():
		return _fail(boundary_error)
	var next_deck: Array[StringName] = []
	next_deck.assign(boundary["deck_ids"])
	var next_profiles: Array[DieState] = _clone_profiles(boundary["die_profiles"])
	var next_tickets: int = boundary["intel_tickets"]
	var next_rng_state: int = boundary["rng_state"]
	run_rng.restore_state(next_rng_state)
	deck_ids = next_deck
	intel_tickets = next_tickets
	die_profiles = next_profiles
	return OperationResult.new(true)

func _boundary_error(boundary: Dictionary) -> String:
	if run_rng == null:
		return "随机流尚未初始化，不能恢复边界"
	for key in ["rng_state", "deck_ids", "intel_tickets", "die_profiles"]:
		if not boundary.has(key):
			return "重试边界缺少字段：%s" % key
	if not boundary["rng_state"] is int:
		return "重试边界的随机状态无效"
	if not boundary["deck_ids"] is Array or boundary["deck_ids"].size() != 12:
		return "重试边界的牌组必须包含十二张牌"
	var seen_cards: Dictionary = {}
	for card_id in boundary["deck_ids"]:
		if card_catalog.find_card(card_id) == null or seen_cards.has(card_id):
			return "重试边界的牌组包含未知或重复卡牌"
		seen_cards[card_id] = true
	if not boundary["intel_tickets"] is int or boundary["intel_tickets"] < 0:
		return "重试边界的情报券无效"
	if not boundary["die_profiles"] is Array:
		return "重试边界的骰子配置无效"
	return _profiles_error(boundary["die_profiles"])

func _profiles_error(profiles: Array) -> String:
	if profiles.size() != 6:
		return "骰子配置必须包含 d1 到 d6 六颗骰子"
	var seen: Dictionary = {}
	for profile in profiles:
		if not profile is DieState:
			return "骰子配置包含无效条目"
		if not _is_die_id(profile.id) or seen.has(profile.id):
			return "骰子配置包含未知或重复骰子"
		seen[profile.id] = true
		if profile.engraving_id == &"":
			if profile.engraved_face != 0:
				return "未刻印骰子的刻印面必须为 0"
		elif (
			engraving_catalog.find_engraving(profile.engraving_id) == null
			or profile.engraved_face < 1
			or profile.engraved_face > 6
		):
			return "骰子配置包含未知刻印或非法刻印面"
	return ""

func _blank_profiles() -> Array[DieState]:
	var profiles: Array[DieState] = []
	for die_index in range(1, 7):
		profiles.append(DieState.new(StringName("d%d" % die_index), 1))
	return profiles

func _clone_profiles(profiles: Array) -> Array[DieState]:
	var copies: Array[DieState] = []
	for profile in profiles:
		copies.append(profile.clone())
	return copies

func _find_profile(profiles: Array, die_id: StringName) -> DieState:
	for profile in profiles:
		if profile.id == die_id:
			return profile
	return null

func _is_die_id(die_id: StringName) -> bool:
	return die_id in [&"d1", &"d2", &"d3", &"d4", &"d5", &"d6"]

func _is_assigned(state: RoundState, die_id: StringName) -> bool:
	for table_id in state.assignments:
		if die_id in state.assignments[table_id]:
			return true
	return false

func _reset_owned_state() -> void:
	phase = Phase.NOT_STARTED
	run_rng = null
	encounter_session = null
	shop_session = null
	verification_session = null
	deck_ids.clear()
	intel_tickets = 0
	die_profiles.clear()
	engraving_offer_ids.clear()
	selected_engraving_id = &""
	installed_die_id = &""
	installed_face = 0
	failure_origin = Phase.NOT_STARTED
	last_error = ""
	_dealer_boundary.clear()
	_verification_boundary.clear()
	_shop_left = false
	_verification_report_accepted = false

func _fail(reason: String) -> OperationResult:
	last_error = reason
	return OperationResult.new(false, reason)
