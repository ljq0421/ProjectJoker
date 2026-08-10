class_name AreaRunSession
extends RefCounted

const ExpeditionConfigs = preload("res://scripts/run/expedition_config_catalog.gd")
const ChallengeRules = preload("res://scripts/run/expedition_challenge_rules.gd")
const ModifierCatalog = preload("res://scripts/run/area_run_modifier_catalog.gd")

enum Phase {
	NOT_STARTED,
	ROUTE_CHOICE,
	NORMAL_ROOM,
	AFTER_NORMAL_ROOM,
	SHOP,
	DEALER,
	ENGRAVING_REWARD,
	ENGRAVING_INSTALL,
	COMPLETE,
	FAILED,
}

const DEFAULT_SEED := 20260726

var phase: Phase = Phase.NOT_STARTED
var seed_value: int
var area_definition: AreaDefinition
var card_catalog: CardCatalog
var dealer_catalog: DealerCatalog
var engraving_catalog: EngravingCatalog
var run_rng: RunRng
var room_index := 0
var route_ids: Array[StringName] = []
var selected_room_ids: Array[StringName] = []
var completed_rooms: Array[Dictionary] = []
var dealer_summary: Dictionary = {}
var deck_ids: Array[StringName] = []
var market_ids: Array[StringName] = []
var pending_route_ids: Array[StringName] = []
var intel_tickets := 0
var die_profiles: Array[DieState] = []
var lucky_faces: Dictionary = {}
var area_modifier_id: StringName = &""
var encounter_session: ThreeRoundEncounterSession
var shop_session: ShopSession
var shop_purchase_history: Array[ShopPurchaseRecord] = []
var shop_service_history: Array[ShopServiceRecord] = []
var rare_card_offer_ids: Array[StringName] = []
var engraving_offer_ids: Array[StringName] = []
var selected_reward_kind: StringName = &""
var selected_reward_card_id: StringName = &""
var replaced_reward_card_id: StringName = &""
var selected_engraving_id: StringName = &""
var installed_die_id: StringName = &""
var installed_face := 0
var challenge_ids: Array[StringName] = []
var failure_origin: Phase = Phase.NOT_STARTED
var last_error := ""
var _entry_state: Dictionary = {}
var _encounter_entry_checkpoint: Dictionary = {}

func _init(
	p_seed_value: int = DEFAULT_SEED,
	p_area_definition: AreaDefinition = null,
	p_card_catalog: CardCatalog = null,
	p_dealer_catalog: DealerCatalog = null,
	p_engraving_catalog: EngravingCatalog = null
) -> void:
	seed_value = p_seed_value
	area_definition = (
		p_area_definition
		if p_area_definition != null
		else AreaCatalog.new().gold_corridor()
	)
	card_catalog = p_card_catalog if p_card_catalog != null else CardCatalog.new()
	dealer_catalog = p_dealer_catalog if p_dealer_catalog != null else DealerCatalog.new()
	engraving_catalog = (
		p_engraving_catalog
		if p_engraving_catalog != null
		else EngravingCatalog.new()
	)

func start() -> OperationResult:
	if phase != Phase.NOT_STARTED:
		return _fail("%s已经开始" % area_definition.display_name)
	var content_errors: Array[String] = []
	content_errors.append_array(card_catalog.validate())
	content_errors.append_array(dealer_catalog.validate())
	content_errors.append_array(engraving_catalog.validate())
	if area_definition == null:
		content_errors.append("区域定义不存在")
	else:
		content_errors.append_array(
			area_definition.validate(
				card_catalog,
				dealer_catalog,
				engraving_catalog
			)
		)
	if not content_errors.is_empty():
		return _fail("区域内容无效：%s" % "；".join(content_errors))
	if not _entry_state.is_empty() and _entry_state.has("challenge_ids"):
		challenge_ids.assign(_entry_state["challenge_ids"])
	var challenge_error := ExpeditionConfigs.new().selection_error(
		ExpeditionConfigs.DICE_CONTROL,
		challenge_ids,
		true
	)
	if not challenge_error.is_empty():
		return _fail(challenge_error)

	var first_ids := area_definition.first_route_ids
	var route_error := _route_error(first_ids)
	if not route_error.is_empty():
		return _fail(route_error)
	var next_deck: Array[StringName] = []
	if _entry_state.is_empty():
		next_deck.assign(area_definition.starting_deck_ids)
	else:
		next_deck.assign(_entry_state["deck_ids"])
	var deck_error := _deck_error(next_deck)
	if not deck_error.is_empty():
		return _fail(deck_error)
	var next_market := _build_market(next_deck, _entry_market_offer_ids())
	var market_error := _market_error(next_market, next_deck)
	if not market_error.is_empty():
		return _fail(market_error)
	var next_profiles := (
		_blank_profiles()
		if _entry_state.is_empty()
		else _profiles_from_snapshots(_entry_state["die_profiles"])
	)
	var next_rng := RunRng.new(seed_value)
	if not _entry_state.is_empty():
		next_rng.restore_state(_entry_state["rng_state"])
	var next_lucky_faces: Dictionary = (
		_entry_state.get("lucky_faces", {}).duplicate(true)
		if not _entry_state.is_empty()
		else {}
	)
	if next_lucky_faces.is_empty():
		next_lucky_faces = _roll_lucky_faces(next_rng)
	var next_modifier_id := ModifierCatalog.new().choose_for_area(
		area_definition.id,
		next_rng
	)
	if next_modifier_id == &"":
		return _fail("区域没有可用的随机异变")
	var next_routes: Array[StringName] = []
	next_routes.assign(next_rng.shuffle(first_ids))

	run_rng = next_rng
	route_ids.assign(next_routes)
	deck_ids.assign(next_deck)
	market_ids.assign(next_market)
	intel_tickets = (
		area_definition.starting_intel_tickets
		if _entry_state.is_empty()
		else _entry_state["intel_tickets"]
	)
	die_profiles = next_profiles
	lucky_faces = next_lucky_faces
	area_modifier_id = next_modifier_id
	room_index = 0
	phase = Phase.ROUTE_CHOICE
	last_error = ""
	return OperationResult.new(true)

func configure_entry_state(state: Dictionary) -> OperationResult:
	if phase != Phase.NOT_STARTED:
		return _fail("区域开始后不能修改跨区入口状态")
	var error := _entry_state_error(state)
	if not error.is_empty():
		return _fail(error)
	_entry_state = state.duplicate(true)
	last_error = ""
	return OperationResult.new(true)

func configure_challenges(p_challenge_ids: Array[StringName]) -> OperationResult:
	if phase != Phase.NOT_STARTED:
		return _fail("区域开始后不能修改挑战配置")
	var error := ExpeditionConfigs.new().selection_error(
		ExpeditionConfigs.DICE_CONTROL,
		p_challenge_ids,
		true
	)
	if not error.is_empty():
		return _fail(error)
	challenge_ids.assign(p_challenge_ids)
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
	var room := area_definition.find_room(room_id)
	if room == null:
		return _fail("所选房间定义不存在")
	var entry_checkpoint := _state_snapshot()
	entry_checkpoint["entry_kind"] = &"normal_room"
	entry_checkpoint["entry_room_id"] = room_id
	var result := _create_normal_room(room)
	if result.accepted:
		_encounter_entry_checkpoint = entry_checkpoint
	return result

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
		phase = Phase.AFTER_NORMAL_ROOM
	elif (
		active_phase == Phase.DEALER
		and encounter_session.status == ThreeRoundEncounterSession.Status.SUCCEEDED
	):
		var reward_result := _prepare_dealer_rewards()
		if not reward_result.accepted:
			return reward_result
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

func choose_dealer_restriction(
	restriction_id: StringName
) -> OperationResult:
	if phase != Phase.DEALER:
		return _fail("只有庄家阶段可以选择最终限制")
	if encounter_session == null:
		return _fail("当前三轮遭遇不存在")
	var result := encounter_session.choose_final_restriction(restriction_id)
	if not result.accepted:
		return _fail(result.reason)
	last_error = ""
	return OperationResult.new(true)

func open_shop() -> OperationResult:
	if (
		phase != Phase.AFTER_NORMAL_ROOM
	):
		return _fail("只有成功完成普通房后才能进入商店")
	var market_error := _market_error(market_ids, deck_ids)
	if not market_error.is_empty():
		return _fail(market_error)
	var rng_before := run_rng.snapshot_state()
	var priority: Array[StringName] = []
	priority.assign(run_rng.shuffle(market_ids))
	var next_pending_routes: Array[StringName] = []
	var intel: ShopIntelSnapshot
	if room_index == 0:
		var second_ids := area_definition.second_route_ids
		var route_error := _route_error(second_ids)
		if not route_error.is_empty():
			run_rng.restore_state(rng_before)
			return _fail(route_error)
		next_pending_routes.assign(run_rng.shuffle(second_ids))
		intel = ShopIntelSnapshot.routes(next_pending_routes)
	elif room_index == 1:
		intel = ShopIntelSnapshot.dealer(
			area_definition.dealer_id,
			area_definition.dealer_target
		)
	else:
		run_rng.restore_state(rng_before)
		return _fail("普通房序号无效")
	var intel_error := intel.validate(area_definition, dealer_catalog)
	if not intel_error.is_empty():
		run_rng.restore_state(rng_before)
		return _fail(intel_error)
	var next_shop := ShopSession.new(
		card_catalog,
		deck_ids,
		priority,
		intel_tickets,
		intel,
		room_index,
		true,
		ChallengeRules.new(challenge_ids).shop_price(0)
	)
	if not next_shop.initialization_error.is_empty():
		run_rng.restore_state(rng_before)
		return _fail(next_shop.initialization_error)
	shop_session = next_shop
	pending_route_ids.assign(next_pending_routes)
	phase = Phase.SHOP
	last_error = ""
	return OperationResult.new(true)

func current_shop_intel() -> ShopIntelSnapshot:
	if phase != Phase.SHOP or shop_session == null:
		return null
	return shop_session.intel_snapshot

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
	var next_service_history := _clone_service_history(shop_service_history)
	next_service_history.append_array(
		_clone_service_history(shop_session.service_records)
	)

	if room_index == 0:
		var route_error := _route_error(pending_route_ids)
		if not route_error.is_empty():
			return _fail(route_error)
		deck_ids.assign(next_deck)
		intel_tickets = next_tickets
		shop_purchase_history = next_history
		shop_service_history = next_service_history
		route_ids.assign(pending_route_ids)
		pending_route_ids.clear()
		room_index = 1
		shop_session = null
		phase = Phase.ROUTE_CHOICE
		last_error = ""
		return OperationResult.new(true)
	if room_index == 1:
		var entry_checkpoint := _state_snapshot()
		entry_checkpoint["entry_kind"] = &"dealer"
		var result := _create_dealer(
			next_deck,
			next_tickets,
			next_history,
			next_service_history
		)
		if result.accepted:
			_encounter_entry_checkpoint = entry_checkpoint
		return result
	return _fail("普通房序号无效")

func select_engraving(engraving_id: StringName) -> OperationResult:
	if phase != Phase.ENGRAVING_REWARD and phase != Phase.ENGRAVING_INSTALL:
		return _fail("当前不能选择刻印")
	if engraving_id not in engraving_offer_ids:
		return _fail("所选刻印不在本次候选中")
	selected_engraving_id = engraving_id
	phase = Phase.ENGRAVING_INSTALL
	last_error = ""
	return OperationResult.new(true)

func select_rare_card_reward(card_id: StringName) -> OperationResult:
	if phase != Phase.ENGRAVING_REWARD:
		return _fail("当前不能选择稀有手法牌")
	if card_id not in rare_card_offer_ids:
		return _fail("所选稀有手法牌不在本次候选中")
	selected_reward_card_id = card_id
	last_error = ""
	return OperationResult.new(true)

func select_reward_replacement(card_id: StringName) -> OperationResult:
	if phase != Phase.ENGRAVING_REWARD:
		return _fail("当前不能选择待替换手法牌")
	if card_id not in deck_ids:
		return _fail("待替换手法牌不在当前牌组中")
	replaced_reward_card_id = card_id
	last_error = ""
	return OperationResult.new(true)

func claim_rare_card_reward(
	card_id: StringName,
	replaced_id: StringName
) -> OperationResult:
	if phase != Phase.ENGRAVING_REWARD:
		return _fail("当前不能领取稀有手法牌")
	if dealer_summary.is_empty():
		return _fail("庄家完成摘要不存在")
	if card_id not in rare_card_offer_ids:
		return _fail("所选稀有手法牌不在本次候选中")
	if replaced_id not in deck_ids:
		return _fail("待替换手法牌不在当前牌组中")
	if card_id in deck_ids:
		return _fail("稀有手法牌已在当前牌组中")
	if not select_rare_card_reward(card_id).accepted:
		return _fail(last_error)
	if not select_reward_replacement(replaced_id).accepted:
		return _fail(last_error)
	var card := card_catalog.find_card(card_id)
	if card == null or card.rarity != CardDefinition.Rarity.RARE:
		return _fail("所选奖励不是有效稀有手法牌")
	var index := deck_ids.find(replaced_id)
	deck_ids[index] = card_id
	var deck_error := _deck_error(deck_ids)
	if not deck_error.is_empty():
		deck_ids[index] = replaced_id
		return _fail(deck_error)
	selected_reward_kind = &"rare_card"
	selected_reward_card_id = card_id
	replaced_reward_card_id = replaced_id
	selected_engraving_id = &""
	installed_die_id = &""
	installed_face = 0
	phase = Phase.COMPLETE
	last_error = ""
	return OperationResult.new(true)

func install_selected_engraving(
	die_id: StringName,
	face: int
) -> OperationResult:
	if phase != Phase.ENGRAVING_INSTALL:
		return _fail("请先从候选中选择一个刻印")
	if dealer_summary.is_empty():
		return _fail("庄家完成摘要不存在")
	var result := EngravingInstallationService.new().install(
		die_profiles,
		engraving_offer_ids,
		selected_engraving_id,
		die_id,
		face,
		engraving_catalog
	)
	if not result.accepted:
		return _fail(result.reason)
	die_profiles = result.profiles
	installed_die_id = die_id
	installed_face = face
	selected_reward_kind = &"engraving"
	selected_reward_card_id = &""
	replaced_reward_card_id = &""
	phase = Phase.COMPLETE
	last_error = ""
	return OperationResult.new(true)

func completion_snapshot() -> Dictionary:
	if phase != Phase.COMPLETE:
		return {}
	if dealer_summary.is_empty():
		return {}
	var purchases: Array[Dictionary] = []
	for record in shop_purchase_history:
		purchases.append({
			"offer_id": record.offer_id,
			"replaced_id": record.replaced_id,
			"price": record.price,
		})
	var services: Array[Dictionary] = []
	for record in shop_service_history:
		services.append({
			"shop_index": record.shop_index,
			"service_type": record.service_type,
			"price": record.price,
			"intel_kind": record.intel_kind,
		})
	return {
		"area_id": area_definition.id,
		"rng_state": run_rng.snapshot_state(),
		"rooms": completed_rooms.duplicate(true),
		"dealer": dealer_summary.duplicate(true),
		"purchases": purchases,
		"services": services,
		"deck_ids": deck_ids.duplicate(),
		"intel_tickets": intel_tickets,
		"reward_kind": selected_reward_kind,
		"reward_card_id": selected_reward_card_id,
		"replaced_card_id": replaced_reward_card_id,
		"engraving_id": selected_engraving_id,
		"die_id": installed_die_id,
		"face": installed_face,
		"die_profiles": _profile_snapshots(),
		"lucky_faces": lucky_faces.duplicate(true),
		"area_modifier_id": area_modifier_id,
	}

func checkpoint_snapshot() -> Dictionary:
	if (
		phase in [Phase.NORMAL_ROOM, Phase.DEALER]
		and not _encounter_entry_checkpoint.is_empty()
	):
		return _encounter_entry_checkpoint.duplicate(true)
	return _state_snapshot()

func restore_checkpoint(snapshot: Dictionary) -> OperationResult:
	var candidate := AreaRunSession.new(
		seed_value,
		area_definition,
		card_catalog,
		dealer_catalog,
		engraving_catalog
	)
	var result := candidate._restore_checkpoint_in_place(snapshot)
	if not result.accepted:
		return _fail(result.reason)
	_copy_runtime_from(candidate)
	last_error = ""
	return OperationResult.new(true)

func restart() -> OperationResult:
	if phase == Phase.NOT_STARTED:
		return _fail("%s尚未开始" % area_definition.display_name)
	_reset_owned_state()
	return start()

func _create_normal_room(room: RoomDefinition) -> OperationResult:
	var rng_before := run_rng.snapshot_state()
	var challenges := ChallengeRules.new(challenge_ids)
	var setup := EncounterRunSetup.new()
	setup.run_rng = run_rng
	setup.deck_ids = deck_ids.duplicate()
	setup.encounter = room.encounter
	setup.round_count = room.round_count
	setup.fixed_hand_ids.assign(room.fixed_hand_ids)
	setup.round_plans.assign(room.round_plans)
	setup.fixed_restriction = room.restriction
	setup.resolution_context = ResolutionContext.new(
		null,
		engraving_catalog,
		area_modifier_id,
		lucky_faces
	)
	setup.success_intel_reward = challenges.intel_reward(room.success_intel_reward)
	setup.prepare_shop_offers = false
	setup.die_profiles = _clone_profiles(die_profiles)
	setup.hand_size = challenges.hand_size(not room.fixed_hand_ids.is_empty())
	setup.undo_allowed = challenges.undo_allowed()
	var extra_restriction := challenges.full_table_restriction()
	if extra_restriction != null:
		setup.additional_restrictions.append(extra_restriction)
	var next := ThreeRoundEncounterSession.new(
		card_catalog,
		seed_value,
		challenges.target_total(room.target_total),
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

func _prepare_dealer_rewards() -> OperationResult:
	if phase != Phase.DEALER:
		return _fail("只有庄家成功后才能准备奖励")
	if encounter_session == null:
		return _fail("当前庄家遭遇不存在")
	var rare_candidates: Array[StringName] = []
	for card_id in area_definition.rare_reward_card_ids:
		if card_id not in deck_ids:
			rare_candidates.append(card_id)
	if rare_candidates.is_empty():
		return _fail("当前牌组外没有可用的区域稀有手法牌")
	var shuffled_cards := run_rng.shuffle(rare_candidates)
	var shuffled_engravings := run_rng.shuffle(area_definition.engraving_offer_ids)
	if shuffled_engravings.size() < 2:
		return _fail("区域刻印奖励候选不足两枚")
	dealer_summary = {
		"id": area_definition.dealer_id,
		"target_total": encounter_session.target_total,
		"cumulative_total": encounter_session.cumulative_total,
	}
	rare_card_offer_ids.assign(shuffled_cards.slice(0, 1))
	engraving_offer_ids.assign(shuffled_engravings.slice(0, 2))
	selected_reward_kind = &""
	selected_reward_card_id = &""
	replaced_reward_card_id = &""
	selected_engraving_id = &""
	installed_die_id = &""
	installed_face = 0
	phase = Phase.ENGRAVING_REWARD
	last_error = ""
	return OperationResult.new(true)

func _create_dealer(
	next_deck: Array[StringName],
	next_tickets: int,
	next_history: Array[ShopPurchaseRecord],
	next_service_history: Array[ShopServiceRecord]
) -> OperationResult:
	var rng_before := run_rng.snapshot_state()
	var challenges := ChallengeRules.new(challenge_ids)
	var setup := EncounterRunSetup.new()
	setup.run_rng = run_rng
	setup.deck_ids = next_deck.duplicate()
	setup.encounter = area_definition.dealer_encounter
	setup.round_schedule = area_definition.dealer_round_schedule
	setup.resolution_context = ResolutionContext.new(
		dealer_catalog.find_dealer(area_definition.dealer_id),
		engraving_catalog,
		area_modifier_id,
		lucky_faces
	)
	setup.success_intel_reward = 0
	setup.prepare_shop_offers = false
	setup.die_profiles = _clone_profiles(die_profiles)
	setup.hand_size = challenges.hand_size(false)
	setup.undo_allowed = challenges.undo_allowed()
	var extra_restriction := challenges.full_table_restriction()
	if extra_restriction != null:
		setup.additional_restrictions.append(extra_restriction)
	var next := ThreeRoundEncounterSession.new(
		card_catalog,
		seed_value,
		challenges.target_total(area_definition.dealer_target),
		setup
	)
	var result := next.start()
	if not result.accepted:
		run_rng.restore_state(rng_before)
		return _fail(result.reason)
	deck_ids.assign(next_deck)
	intel_tickets = next_tickets
	shop_purchase_history = next_history
	shop_service_history = next_service_history
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
		if area_definition.find_room(room_id) == null:
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

func _build_market(
	entry_deck_ids: Array[StringName],
	shop_ids: Array[StringName]
) -> Array[StringName]:
	var result: Array[StringName] = entry_deck_ids.duplicate()
	for card_id in shop_ids:
		if card_id not in result:
			result.append(card_id)
	return result

func _entry_market_offer_ids() -> Array[StringName]:
	var result: Array[StringName] = area_definition.shop_offer_ids.duplicate()
	if _entry_state.is_empty():
		return result
	var regional_ids: Array[StringName] = []
	match area_definition.id:
		&"mirror_hall":
			regional_ids = card_catalog.mirror_hall_card_ids()
		&"faceless_hub":
			regional_ids = card_catalog.faceless_hub_card_ids()
	for card_id in regional_ids:
		if card_id not in result:
			result.append(card_id)
	return result

func _market_error(
	ids: Array[StringName],
	current_deck_ids: Array[StringName]
) -> String:
	var seen: Dictionary = {}
	for card_id in ids:
		if card_catalog.find_card(card_id) == null:
			return "地区市场包含未知卡牌：%s" % card_id
		if seen.has(card_id):
			return "地区市场包含重复卡牌：%s" % card_id
		seen[card_id] = true
	for card_id in current_deck_ids:
		if card_id not in ids:
			return "当前牌组包含不属于地区市场的卡牌：%s" % card_id
	var outside_count := 0
	for card_id in ids:
		if card_id not in current_deck_ids:
			outside_count += 1
	if outside_count < 6:
		return "当前牌组之外的地区市场牌不足六张"
	return ""

func _blank_profiles() -> Array[DieState]:
	var profiles: Array[DieState] = []
	for die_index in range(1, 7):
		var die_id := StringName("d%d" % die_index)
		profiles.append(DieState.new(
			die_id,
			1,
			(
				area_definition.initial_engraving_id
				if die_id == area_definition.initial_engraving_die_id
				else &""
			),
			(
				area_definition.initial_engraving_face
				if die_id == area_definition.initial_engraving_die_id
				else 0
			)
		))
	return profiles

func _profile_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for profile in die_profiles:
		snapshots.append({
			"id": profile.id,
			"rolled_value": profile.rolled_value,
			"value": profile.value,
			"engraving_id": profile.engraving_id,
			"engraved_face": profile.engraved_face,
		})
	return snapshots

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

func _clone_service_history(
	history: Array[ShopServiceRecord]
) -> Array[ShopServiceRecord]:
	var copies: Array[ShopServiceRecord] = []
	for record in history:
		copies.append(record.clone())
	return copies

func _restore_checkpoint_in_place(snapshot: Dictionary) -> OperationResult:
	if not snapshot is Dictionary:
		return _fail("区域检查点格式无效")
	var entry_kind: StringName = snapshot.get("entry_kind", &"")
	var base := snapshot.duplicate(true)
	base.erase("entry_kind")
	base.erase("entry_room_id")
	var result := _restore_base_snapshot(base)
	if not result.accepted:
		return result
	if entry_kind == &"":
		return OperationResult.new(true)
	if entry_kind == &"normal_room":
		var room_id: StringName = snapshot.get("entry_room_id", &"")
		return select_route(room_id)
	if entry_kind == &"dealer":
		return leave_shop()
	return _fail("区域检查点包含未知房间入口类型")

func _restore_base_snapshot(snapshot: Dictionary) -> OperationResult:
	for key in [
		"area_id",
		"phase",
		"rng_state",
		"room_index",
		"route_ids",
		"selected_room_ids",
		"completed_rooms",
		"deck_ids",
		"market_ids",
		"pending_route_ids",
		"intel_tickets",
		"die_profiles",
		"challenge_ids",
		"purchases",
		"services",
		"engraving_offer_ids",
		"selected_engraving_id",
		"installed_die_id",
		"installed_face",
	]:
		if not snapshot.has(key):
			return _fail("区域检查点缺少字段：%s" % key)
	if snapshot["area_id"] != area_definition.id:
		return _fail("区域检查点与地区定义不匹配")
	if not snapshot["phase"] is int or snapshot["phase"] not in [
		Phase.ROUTE_CHOICE,
		Phase.AFTER_NORMAL_ROOM,
		Phase.SHOP,
		Phase.ENGRAVING_REWARD,
		Phase.ENGRAVING_INSTALL,
		Phase.COMPLETE,
	]:
		return _fail("区域检查点阶段无效")
	if not snapshot["rng_state"] is int:
		return _fail("区域检查点随机状态无效")
	if not snapshot["deck_ids"] is Array:
		return _fail("区域检查点牌组格式无效")
	var next_deck: Array[StringName] = []
	next_deck.assign(snapshot["deck_ids"])
	var deck_error := _deck_error(next_deck)
	if not deck_error.is_empty():
		return _fail(deck_error)
	if not snapshot["die_profiles"] is Array:
		return _fail("区域检查点骰子配置格式无效")
	var next_profiles := _profiles_from_snapshots(snapshot["die_profiles"])
	var profiles_error := _profiles_error(next_profiles)
	if not profiles_error.is_empty():
		return _fail(profiles_error)
	if not snapshot["intel_tickets"] is int or snapshot["intel_tickets"] < 0:
		return _fail("区域检查点情报券无效")
	if not snapshot["room_index"] is int or snapshot["room_index"] not in [0, 1]:
		return _fail("区域检查点房间序号无效")
	var next_lucky_faces: Dictionary = snapshot.get(
		"lucky_faces",
		{}
	).duplicate(true)
	if not next_lucky_faces.is_empty():
		var lucky_error := _lucky_faces_error(next_lucky_faces)
		if not lucky_error.is_empty():
			return _fail(lucky_error)
	var next_modifier_id: StringName = snapshot.get("area_modifier_id", &"")
	if (
		next_modifier_id != &""
		and not ModifierCatalog.new().is_valid_for_area(
			next_modifier_id,
			area_definition.id
		)
	):
		return _fail("区域检查点随机异变无效")
	if not snapshot["challenge_ids"] is Array:
		return _fail("区域检查点挑战格式无效")
	var next_challenge_ids: Array[StringName] = []
	next_challenge_ids.assign(snapshot["challenge_ids"])
	var challenge_error := ExpeditionConfigs.new().selection_error(
		ExpeditionConfigs.DICE_CONTROL,
		next_challenge_ids,
		true
	)
	if not challenge_error.is_empty():
		return _fail(challenge_error)

	var snapshot_phase: Phase = snapshot["phase"]
	var next_dealer_summary: Dictionary = {}
	if snapshot.has("dealer_summary"):
		if not snapshot["dealer_summary"] is Dictionary:
			return _fail("区域检查点庄家摘要格式无效")
		next_dealer_summary = snapshot["dealer_summary"].duplicate(true)
	if next_dealer_summary.is_empty() and snapshot_phase == Phase.COMPLETE:
		var completion = snapshot.get("completion", {})
		if completion is Dictionary and completion.get("dealer", {}) is Dictionary:
			next_dealer_summary = completion.get("dealer", {}).duplicate(true)
	var dealer_completed := snapshot_phase in [
		Phase.ENGRAVING_REWARD,
		Phase.ENGRAVING_INSTALL,
		Phase.COMPLETE,
	]
	if next_dealer_summary.is_empty() and dealer_completed:
		next_dealer_summary = {
			"id": area_definition.dealer_id,
			"target_total": ChallengeRules.new(next_challenge_ids).target_total(
				area_definition.dealer_target
			),
			"cumulative_total": null,
		}
	var dealer_error := _dealer_summary_error(
		next_dealer_summary,
		dealer_completed
	)
	if not dealer_error.is_empty():
		return _fail(dealer_error)

	var next_shop: ShopSession
	if snapshot["phase"] == Phase.SHOP:
		if not snapshot.has("shop"):
			return _fail("商店检查点缺少商店状态")
		var restored_shop := ShopSession.from_snapshot(
			card_catalog,
			snapshot["shop"]
		)
		if not restored_shop.accepted:
			return _fail(restored_shop.reason)
		next_shop = restored_shop.session

	run_rng = RunRng.new(seed_value)
	run_rng.restore_state(snapshot["rng_state"])
	if next_lucky_faces.is_empty():
		next_lucky_faces = _roll_lucky_faces(run_rng)
	if next_modifier_id == &"":
		next_modifier_id = ModifierCatalog.new().choose_for_area(
			area_definition.id,
			run_rng
		)
	phase = snapshot["phase"]
	room_index = snapshot["room_index"]
	route_ids.assign(snapshot["route_ids"])
	selected_room_ids.assign(snapshot["selected_room_ids"])
	completed_rooms.assign(snapshot["completed_rooms"].duplicate(true))
	deck_ids = next_deck
	market_ids.assign(snapshot["market_ids"])
	pending_route_ids.assign(snapshot["pending_route_ids"])
	intel_tickets = snapshot["intel_tickets"]
	challenge_ids = next_challenge_ids
	die_profiles = next_profiles
	lucky_faces = next_lucky_faces
	area_modifier_id = next_modifier_id
	dealer_summary = next_dealer_summary
	shop_purchase_history = _purchase_history_from_snapshots(snapshot["purchases"])
	shop_service_history = _service_history_from_snapshots(snapshot["services"])
	engraving_offer_ids.assign(snapshot["engraving_offer_ids"])
	rare_card_offer_ids.assign(snapshot.get("rare_card_offer_ids", []))
	selected_reward_kind = snapshot.get("selected_reward_kind", &"")
	selected_reward_card_id = snapshot.get("selected_reward_card_id", &"")
	replaced_reward_card_id = snapshot.get("replaced_reward_card_id", &"")
	selected_engraving_id = snapshot["selected_engraving_id"]
	installed_die_id = snapshot["installed_die_id"]
	installed_face = snapshot["installed_face"]
	encounter_session = null
	shop_session = next_shop
	failure_origin = Phase.NOT_STARTED
	_encounter_entry_checkpoint = {}
	return OperationResult.new(true)

func _state_snapshot() -> Dictionary:
	var purchases: Array[Dictionary] = []
	for record in shop_purchase_history:
		purchases.append({
			"offer_id": record.offer_id,
			"replaced_id": record.replaced_id,
			"price": record.price,
		})
	var services: Array[Dictionary] = []
	for record in shop_service_history:
		services.append({
			"shop_index": record.shop_index,
			"service_type": record.service_type,
			"price": record.price,
			"intel_kind": record.intel_kind,
		})
	var snapshot := {
		"area_id": area_definition.id,
		"phase": phase,
		"rng_state": run_rng.snapshot_state() if run_rng != null else 0,
		"room_index": room_index,
		"route_ids": route_ids.duplicate(),
		"selected_room_ids": selected_room_ids.duplicate(),
		"completed_rooms": completed_rooms.duplicate(true),
		"dealer_summary": dealer_summary.duplicate(true),
		"deck_ids": deck_ids.duplicate(),
		"market_ids": market_ids.duplicate(),
		"pending_route_ids": pending_route_ids.duplicate(),
		"intel_tickets": intel_tickets,
		"die_profiles": _profile_snapshots(),
		"lucky_faces": lucky_faces.duplicate(true),
		"area_modifier_id": area_modifier_id,
		"challenge_ids": challenge_ids.duplicate(),
		"purchases": purchases,
		"services": services,
		"rare_card_offer_ids": rare_card_offer_ids.duplicate(),
		"engraving_offer_ids": engraving_offer_ids.duplicate(),
		"selected_reward_kind": selected_reward_kind,
		"selected_reward_card_id": selected_reward_card_id,
		"replaced_reward_card_id": replaced_reward_card_id,
		"selected_engraving_id": selected_engraving_id,
		"installed_die_id": installed_die_id,
		"installed_face": installed_face,
	}
	if phase == Phase.SHOP and shop_session != null:
		snapshot["shop"] = shop_session.to_snapshot()
	return snapshot

func _copy_runtime_from(other: AreaRunSession) -> void:
	phase = other.phase
	run_rng = other.run_rng
	room_index = other.room_index
	route_ids = other.route_ids
	selected_room_ids = other.selected_room_ids
	completed_rooms = other.completed_rooms
	dealer_summary = other.dealer_summary
	deck_ids = other.deck_ids
	market_ids = other.market_ids
	pending_route_ids = other.pending_route_ids
	intel_tickets = other.intel_tickets
	challenge_ids = other.challenge_ids
	die_profiles = other.die_profiles
	lucky_faces = other.lucky_faces
	area_modifier_id = other.area_modifier_id
	encounter_session = other.encounter_session
	shop_session = other.shop_session
	shop_purchase_history = other.shop_purchase_history
	shop_service_history = other.shop_service_history
	rare_card_offer_ids = other.rare_card_offer_ids
	engraving_offer_ids = other.engraving_offer_ids
	selected_reward_kind = other.selected_reward_kind
	selected_reward_card_id = other.selected_reward_card_id
	replaced_reward_card_id = other.replaced_reward_card_id
	selected_engraving_id = other.selected_engraving_id
	installed_die_id = other.installed_die_id
	installed_face = other.installed_face
	failure_origin = other.failure_origin
	_entry_state = other._entry_state
	_encounter_entry_checkpoint = other._encounter_entry_checkpoint

func _entry_state_error(state: Dictionary) -> String:
	for key in ["deck_ids", "intel_tickets", "die_profiles", "rng_state"]:
		if not state.has(key):
			return "跨区入口状态缺少字段：%s" % key
	var ids: Array[StringName] = []
	if not state["deck_ids"] is Array:
		return "跨区入口牌组格式无效"
	ids.assign(state["deck_ids"])
	var deck_error := _deck_error(ids)
	if not deck_error.is_empty():
		return deck_error
	if not state["intel_tickets"] is int or state["intel_tickets"] < 0:
		return "跨区入口情报券无效"
	if not state["rng_state"] is int:
		return "跨区入口随机状态无效"
	if not state["die_profiles"] is Array:
		return "跨区入口骰子配置无效"
	if state.has("challenge_ids"):
		if not state["challenge_ids"] is Array:
			return "跨区入口挑战格式无效"
		var challenge_error := ExpeditionConfigs.new().selection_error(
			ExpeditionConfigs.DICE_CONTROL,
			state["challenge_ids"],
			true
		)
		if not challenge_error.is_empty():
			return challenge_error
	if state.has("lucky_faces") and not state["lucky_faces"].is_empty():
		var lucky_error := _lucky_faces_error(state["lucky_faces"])
		if not lucky_error.is_empty():
			return lucky_error
	return _profiles_error(_profiles_from_snapshots(state["die_profiles"]))

func _dealer_summary_error(summary: Dictionary, required: bool) -> String:
	if summary.is_empty():
		return "区域检查点缺少庄家完成摘要" if required else ""
	for key in ["id", "target_total", "cumulative_total"]:
		if not summary.has(key):
			return "庄家完成摘要缺少字段：%s" % key
	if summary["id"] != area_definition.dealer_id:
		return "庄家完成摘要与地区定义不匹配"
	if not summary["target_total"] is int or summary["target_total"] <= 0:
		return "庄家完成摘要目标分无效"
	var cumulative_total = summary["cumulative_total"]
	if cumulative_total != null and not cumulative_total is int:
		return "庄家完成摘要累计分无效"
	if cumulative_total is int and cumulative_total < summary["target_total"]:
		return "庄家完成摘要与已成功状态矛盾"
	return ""

func _roll_lucky_faces(rng: RunRng) -> Dictionary:
	var result: Dictionary = {}
	for die_index in range(1, 7):
		result[StringName("d%d" % die_index)] = rng.roll_die()
	return result

func _lucky_faces_error(faces) -> String:
	if not faces is Dictionary or faces.size() != 6:
		return "幸运面必须包含 d1 到 d6 六颗骰子"
	for die_index in range(1, 7):
		var die_id := StringName("d%d" % die_index)
		if not faces.has(die_id):
			return "幸运面缺少骰子：%s" % die_id
		if not faces[die_id] is int or faces[die_id] < 1 or faces[die_id] > 6:
			return "幸运面必须是 1 到 6 的整数"
	return ""

func _profiles_from_snapshots(snapshots: Array) -> Array[DieState]:
	var profiles: Array[DieState] = []
	for entry in snapshots:
		if entry is DieState:
			profiles.append(entry.clone())
			continue
		if not entry is Dictionary:
			return []
		for key in ["id", "rolled_value", "engraving_id", "engraved_face"]:
			if not entry.has(key):
				return []
		profiles.append(DieState.new(
			entry["id"],
			entry["rolled_value"],
			entry["engraving_id"],
			entry["engraved_face"]
		))
	return profiles

func _profiles_error(profiles: Array[DieState]) -> String:
	if profiles.size() != 6:
		return "骰子配置必须包含 d1 到 d6 六颗骰子"
	var seen: Dictionary = {}
	for profile in profiles:
		if (
			profile == null
			or profile.id not in [&"d1", &"d2", &"d3", &"d4", &"d5", &"d6"]
			or seen.has(profile.id)
		):
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

func _purchase_history_from_snapshots(entries: Array) -> Array[ShopPurchaseRecord]:
	var result: Array[ShopPurchaseRecord] = []
	for entry in entries:
		if not entry is Dictionary:
			return []
		result.append(ShopPurchaseRecord.new(
			entry.get("offer_id", &""),
			entry.get("replaced_id", &""),
			entry.get("price", -1)
		))
	return result

func _service_history_from_snapshots(entries: Array) -> Array[ShopServiceRecord]:
	var result: Array[ShopServiceRecord] = []
	for entry in entries:
		if not entry is Dictionary:
			return []
		result.append(ShopServiceRecord.new(
			entry.get("shop_index", -1),
			entry.get("service_type", -1),
			entry.get("price", -1),
			entry.get("intel_kind", -1)
		))
	return result

func _reset_owned_state() -> void:
	phase = Phase.NOT_STARTED
	run_rng = null
	room_index = 0
	route_ids.clear()
	selected_room_ids.clear()
	completed_rooms.clear()
	dealer_summary.clear()
	deck_ids.clear()
	market_ids.clear()
	pending_route_ids.clear()
	intel_tickets = 0
	die_profiles.clear()
	lucky_faces.clear()
	area_modifier_id = &""
	encounter_session = null
	shop_session = null
	shop_purchase_history.clear()
	shop_service_history.clear()
	rare_card_offer_ids.clear()
	engraving_offer_ids.clear()
	selected_reward_kind = &""
	selected_reward_card_id = &""
	replaced_reward_card_id = &""
	selected_engraving_id = &""
	installed_die_id = &""
	installed_face = 0
	failure_origin = Phase.NOT_STARTED
	last_error = ""
	_encounter_entry_checkpoint = {}

func _fail(reason: String) -> OperationResult:
	last_error = reason
	return OperationResult.new(false, reason)
