class_name AreaRunSession
extends RefCounted

enum Phase {
	NOT_STARTED,
	ROUTE_CHOICE,
	NORMAL_ROOM,
	SHOP,
	DEALER,
	ENGRAVING_REWARD,
	ENGRAVING_INSTALL,
	COMPLETE,
	FAILED,
}

const DEFAULT_SEED := 20260726
const DEALER_TARGET := 150

var phase: Phase = Phase.NOT_STARTED
var seed_value: int
var room_catalog: GoldCorridorCatalog
var card_catalog: CardCatalog
var dealer_catalog: DealerCatalog
var engraving_catalog: EngravingCatalog
var run_rng: RunRng
var room_index := 0
var route_ids: Array[StringName] = []
var selected_room_ids: Array[StringName] = []
var completed_rooms: Array[Dictionary] = []
var deck_ids: Array[StringName] = []
var intel_tickets := 0
var die_profiles: Array[DieState] = []
var encounter_session: ThreeRoundEncounterSession
var shop_session: ShopSession
var shop_purchase_history: Array[ShopPurchaseRecord] = []
var engraving_offer_ids: Array[StringName] = []
var selected_engraving_id: StringName = &""
var installed_die_id: StringName = &""
var installed_face := 0
var failure_origin: Phase = Phase.NOT_STARTED
var last_error := ""

func _init(
	p_seed_value: int = DEFAULT_SEED,
	p_room_catalog: GoldCorridorCatalog = null,
	p_card_catalog: CardCatalog = null,
	p_dealer_catalog: DealerCatalog = null,
	p_engraving_catalog: EngravingCatalog = null
) -> void:
	seed_value = p_seed_value
	room_catalog = p_room_catalog if p_room_catalog != null else GoldCorridorCatalog.new()
	card_catalog = p_card_catalog if p_card_catalog != null else CardCatalog.new()
	dealer_catalog = p_dealer_catalog if p_dealer_catalog != null else DealerCatalog.new()
	engraving_catalog = (
		p_engraving_catalog
		if p_engraving_catalog != null
		else EngravingCatalog.new()
	)

func start() -> OperationResult:
	if phase != Phase.NOT_STARTED:
		return _fail("金线回廊已经开始")
	var content_errors: Array[String] = []
	content_errors.append_array(room_catalog.validate())
	content_errors.append_array(card_catalog.validate())
	content_errors.append_array(dealer_catalog.validate())
	content_errors.append_array(engraving_catalog.validate())
	if not content_errors.is_empty():
		return _fail("区域内容无效：%s" % "；".join(content_errors))

	var first_ids := room_catalog.first_route_ids()
	var route_error := _route_error(first_ids)
	if not route_error.is_empty():
		return _fail(route_error)
	var next_deck := card_catalog.starter_ids()
	var deck_error := _deck_error(next_deck)
	if not deck_error.is_empty():
		return _fail(deck_error)
	var next_profiles := _blank_profiles()
	var next_rng := RunRng.new(seed_value)
	var next_routes: Array[StringName] = []
	next_routes.assign(next_rng.shuffle(first_ids))

	run_rng = next_rng
	route_ids.assign(next_routes)
	deck_ids.assign(next_deck)
	intel_tickets = 0
	die_profiles = next_profiles
	room_index = 0
	phase = Phase.ROUTE_CHOICE
	last_error = ""
	return OperationResult.new(true)

func current_route_ids() -> Array[StringName]:
	return route_ids.duplicate()

func select_route(room_id: StringName) -> OperationResult:
	if phase != Phase.ROUTE_CHOICE:
		return _fail("当前不能选择路线")
	if room_id not in route_ids:
		return _fail("所选房间不在当前路线候选中")
	if room_id in selected_room_ids:
		return _fail("这个房间已经完成")
	var room := room_catalog.find_room(room_id)
	if room == null:
		return _fail("所选房间定义不存在")
	return _create_normal_room(room)

func accept_encounter_report(report: ResolutionReport) -> OperationResult:
	if phase != Phase.NORMAL_ROOM and phase != Phase.DEALER:
		return _fail("当前阶段不接受三轮遭遇报告")
	if encounter_session == null:
		return _fail("当前三轮遭遇不存在")
	var active_phase := phase
	var result := encounter_session.accept_committed_report(report)
	if not result.accepted:
		return _fail(result.reason)
	if encounter_session.status == ThreeRoundEncounterSession.Status.FAILED:
		failure_origin = active_phase
		phase = Phase.FAILED
	elif (
		active_phase == Phase.NORMAL_ROOM
		and encounter_session.status == ThreeRoundEncounterSession.Status.SUCCEEDED
	):
		completed_rooms.append({
			"room_id": selected_room_ids[-1],
			"target_total": encounter_session.target_total,
			"cumulative_total": encounter_session.cumulative_total,
		})
		intel_tickets += encounter_session.intel_tickets
	last_error = ""
	return OperationResult.new(true)

func advance_encounter_round() -> OperationResult:
	if phase != Phase.NORMAL_ROOM and phase != Phase.DEALER:
		return _fail("当前阶段不能进入下一轮")
	if encounter_session == null:
		return _fail("当前三轮遭遇不存在")
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
		return _fail("只有成功完成普通房后才能进入商店")
	var available: Array[StringName] = []
	for card_id in card_catalog.shop_ids():
		if card_id not in deck_ids:
			available.append(card_id)
	if available.size() < 3:
		return _fail("当前牌组之外的商店牌不足三张")
	var shuffled := run_rng.shuffle(available)
	var offers: Array[StringName] = []
	offers.assign(shuffled.slice(0, 3))
	shop_session = ShopSession.new(
		card_catalog,
		deck_ids,
		offers,
		intel_tickets
	)
	phase = Phase.SHOP
	last_error = ""
	return OperationResult.new(true)

func leave_shop() -> OperationResult:
	if phase != Phase.SHOP or shop_session == null:
		return _fail("当前没有可以离开的商店")
	var next_deck: Array[StringName] = shop_session.deck_ids.duplicate()
	var deck_error := _deck_error(next_deck)
	if not deck_error.is_empty():
		return _fail(deck_error)
	var next_tickets := shop_session.intel_tickets
	if next_tickets < 0:
		return _fail("商店结算后的情报券不能为负数")
	var next_history := _clone_purchase_history(shop_purchase_history)
	next_history.append_array(_clone_purchase_history(shop_session.purchase_records))

	if room_index == 0:
		var second_ids := room_catalog.second_route_ids()
		var route_error := _route_error(second_ids)
		if not route_error.is_empty():
			return _fail(route_error)
		var next_routes: Array[StringName] = []
		next_routes.assign(run_rng.shuffle(second_ids))
		deck_ids.assign(next_deck)
		intel_tickets = next_tickets
		shop_purchase_history = next_history
		route_ids.assign(next_routes)
		room_index = 1
		shop_session = null
		phase = Phase.ROUTE_CHOICE
		last_error = ""
		return OperationResult.new(true)
	if room_index == 1:
		return _create_dealer(next_deck, next_tickets, next_history)
	return _fail("普通房序号无效")

func _create_normal_room(room: RoomDefinition) -> OperationResult:
	var rng_before := run_rng.snapshot_state()
	var setup := EncounterRunSetup.new()
	setup.run_rng = run_rng
	setup.deck_ids = deck_ids.duplicate()
	setup.encounter = room.encounter
	setup.resolution_context = ResolutionContext.empty()
	setup.success_intel_reward = room.success_intel_reward
	setup.prepare_shop_offers = false
	setup.die_profiles = _clone_profiles(die_profiles)
	var next := ThreeRoundEncounterSession.new(
		card_catalog,
		seed_value,
		room.target_total,
		setup
	)
	var result := next.start()
	if not result.accepted:
		run_rng.restore_state(rng_before)
		return _fail(result.reason)
	encounter_session = next
	selected_room_ids.append(room.id)
	route_ids.clear()
	phase = Phase.NORMAL_ROOM
	last_error = ""
	return OperationResult.new(true)

func _create_dealer(
	next_deck: Array[StringName],
	next_tickets: int,
	next_history: Array[ShopPurchaseRecord]
) -> OperationResult:
	var rng_before := run_rng.snapshot_state()
	var setup := EncounterRunSetup.new()
	setup.run_rng = run_rng
	setup.deck_ids = next_deck.duplicate()
	setup.encounter = SingleEncounterFixture.make_encounter()
	setup.resolution_context = ResolutionContext.new(
		dealer_catalog.iron_abacus(),
		engraving_catalog
	)
	setup.success_intel_reward = 0
	setup.prepare_shop_offers = false
	setup.die_profiles = _clone_profiles(die_profiles)
	var next := ThreeRoundEncounterSession.new(
		card_catalog,
		seed_value,
		DEALER_TARGET,
		setup
	)
	var result := next.start()
	if not result.accepted:
		run_rng.restore_state(rng_before)
		return _fail(result.reason)
	deck_ids.assign(next_deck)
	intel_tickets = next_tickets
	shop_purchase_history = next_history
	encounter_session = next
	shop_session = null
	phase = Phase.DEALER
	last_error = ""
	return OperationResult.new(true)

func _route_error(ids: Array[StringName]) -> String:
	if ids.size() != 2:
		return "路线候选必须恰好包含两个房间"
	var seen: Dictionary = {}
	for room_id in ids:
		if room_catalog.find_room(room_id) == null:
			return "路线候选包含未知房间：%s" % room_id
		if seen.has(room_id):
			return "路线候选包含重复房间：%s" % room_id
		seen[room_id] = true
	return ""

func _deck_error(ids: Array[StringName]) -> String:
	if ids.size() != 12:
		return "区域牌组必须正好包含十二张牌"
	var seen: Dictionary = {}
	for card_id in ids:
		if card_catalog.find_card(card_id) == null:
			return "区域牌组包含未知卡牌：%s" % card_id
		if seen.has(card_id):
			return "区域牌组包含重复卡牌：%s" % card_id
		seen[card_id] = true
	return ""

func _blank_profiles() -> Array[DieState]:
	var profiles: Array[DieState] = []
	for die_index in range(1, 7):
		profiles.append(DieState.new(StringName("d%d" % die_index), 1))
	return profiles

func _clone_profiles(profiles: Array[DieState]) -> Array[DieState]:
	var copies: Array[DieState] = []
	for profile in profiles:
		copies.append(profile.clone())
	return copies

func _clone_purchase_history(
	history: Array[ShopPurchaseRecord]
) -> Array[ShopPurchaseRecord]:
	var copies: Array[ShopPurchaseRecord] = []
	for record in history:
		copies.append(record.clone())
	return copies

func _fail(reason: String) -> OperationResult:
	last_error = reason
	return OperationResult.new(false, reason)
