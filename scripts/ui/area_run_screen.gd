class_name AreaRunScreen
extends Control

const AreaPresentation = preload(
	"res://scripts/ui/area_presentation_catalog.gd"
)
const AreaThemeFactory = preload("res://scripts/ui/area_theme_factory.gd")
const BASE_THEME = preload("res://resources/themes/neon_dream_theme.tres")

signal expedition_checkpoint_reached(snapshot: Dictionary)
signal expedition_failed(reason: String)
signal expedition_area_completed(summary: Dictionary)
signal expedition_continue_requested
signal expedition_exit_requested

@export var run_seed: int = 0

@onready var encounter_screen: SingleEncounterScreen = %EncounterScreen
@onready var shop_screen: ShopScreen = %ShopScreen
@onready var summary_panel: RoundSummaryPanel = %RoundSummaryPanel
@onready var route_panel: RouteChoicePanel = %RouteChoicePanel
@onready var reward_panel: EngravingRewardPanel = %EngravingRewardPanel
@onready var complete_panel: AreaCompletePanel = %AreaCompletePanel
@onready var intel_panel: ShopIntelPanel = %ShopIntelPanel
@onready var narrative_card: Control = %NarrativeCard
@onready var navigation_bar: Control = $NavigationBar
@onready var home_button: Button = %HomeButton
@onready var area_chrome_label: Label = %AreaChromeLabel

var area_session: AreaRunSession
var _configured_area: AreaDefinition
var _configured_seed := 0
var _configured_entry_state: Dictionary = {}
var _configured_checkpoint: Dictionary = {}
var _expedition_mode := false
var _expedition_has_next_area := false
var _dealer_opening_shown := false

func _ready() -> void:
	move_child(navigation_bar, get_child_count() - 1)
	_reserve_top_chrome()
	home_button.pressed.connect(_on_home_pressed)
	encounter_screen.round_committed.connect(_on_round_committed)
	encounter_screen.card_selected.connect(_after_card_selected)
	summary_panel.next_round_requested.connect(_on_next_round_requested)
	summary_panel.shop_requested.connect(_on_shop_requested)
	summary_panel.retry_requested.connect(_on_restart_requested)
	summary_panel.return_requested.connect(_on_return_requested)
	shop_screen.leave_requested.connect(_on_shop_leave_requested)
	shop_screen.state_changed.connect(_on_shop_state_changed)
	shop_screen.intel_view_requested.connect(_on_shop_intel_view_requested)
	route_panel.route_selected.connect(_on_route_selected)
	reward_panel.engraving_selected.connect(_on_engraving_selected)
	reward_panel.install_requested.connect(_on_install_requested)
	reward_panel.card_reward_requested.connect(_on_card_reward_requested)
	reward_panel.reward_card_selected.connect(_on_reward_card_selected)
	reward_panel.replacement_card_selected.connect(
		_on_reward_replacement_selected
	)
	complete_panel.restart_requested.connect(_on_restart_requested)
	complete_panel.return_requested.connect(_on_return_requested)
	complete_panel.continue_requested.connect(
		func() -> void: expedition_continue_requested.emit()
	)
	narrative_card.confirmed.connect(_on_dealer_opening_confirmed)
	summary_panel.get_node("%ReturnTeachingButton").text = "返回入口"
	reward_panel.get_node("%InstallEngravingButton").text = "安装刻印并封存区域"
	start_run()

func _reserve_top_chrome() -> void:
	for embedded_screen in [encounter_screen, shop_screen]:
		var embedded_safe_area: Control = embedded_screen.get_node_or_null(
			"SafeArea"
		)
		if embedded_safe_area is MarginContainer:
			embedded_safe_area.offset_top = 96.0

func configure(area_definition: AreaDefinition, seed: int) -> void:
	_configured_area = area_definition
	_configured_seed = seed
	if is_node_ready():
		start_run()

func configure_for_expedition(
	area_definition: AreaDefinition,
	seed: int,
	entry_state: Dictionary,
	checkpoint: Dictionary,
	has_next_area: bool
) -> void:
	_configured_area = area_definition
	_configured_seed = seed
	_configured_entry_state = entry_state.duplicate(true)
	_configured_checkpoint = checkpoint.duplicate(true)
	_expedition_mode = true
	_expedition_has_next_area = has_next_area
	if is_node_ready():
		start_run()

func build_area_definition() -> AreaDefinition:
	return AreaCatalog.new().gold_corridor()

func build_seed() -> int:
	return AreaRunSession.DEFAULT_SEED

func start_run() -> void:
	var definition := (
		_configured_area
		if _configured_area != null
		else build_area_definition()
	)
	var seed := (
		_configured_seed
		if _configured_seed != 0
		else (run_seed if run_seed != 0 else build_seed())
	)
	area_session = AreaRunSession.new(seed, definition)
	var result: OperationResult
	if not _configured_checkpoint.is_empty():
		result = area_session.restore_checkpoint(_configured_checkpoint)
	elif not _configured_entry_state.is_empty():
		result = area_session.configure_entry_state(_configured_entry_state)
		if result.accepted:
			result = area_session.start()
	else:
		result = area_session.start()
	if not result.accepted:
		_show_start_error(result.reason)
		return
	_apply_area_presentation()
	complete_panel.configure_expedition(
		_expedition_mode,
		_expedition_has_next_area
	)
	_show_current_phase()
	_emit_expedition_checkpoint()

func _apply_area_presentation() -> void:
	var area := area_session.area_definition
	var presentation: Dictionary = AreaPresentation.new().find(area.id)
	if presentation.is_empty():
		return
	var area_theme := AreaThemeFactory.build(BASE_THEME, presentation)
	theme = area_theme
	var settings_button := get_node_or_null(
		"SettingsLayer/SettingsRoot/SettingsButton"
	) as Button
	if settings_button != null:
		settings_button.theme = area_theme
	area_chrome_label.text = "%s　%s" % [
		presentation["eyebrow"],
		area.display_name,
	]
	area_chrome_label.add_theme_color_override(
		"font_color",
		presentation["secondary"]
	)
	home_button.add_theme_color_override(
		"font_color",
		presentation["primary"]
	)
	encounter_screen.apply_area_presentation(area.id)
	shop_screen.apply_area_presentation(area.id, area.display_name)

func _show_current_phase() -> void:
	match area_session.phase:
		AreaRunSession.Phase.ROUTE_CHOICE:
			_show_route_choice()
		AreaRunSession.Phase.NORMAL_ROOM, AreaRunSession.Phase.DEALER:
			bind_current_encounter()
		AreaRunSession.Phase.AFTER_NORMAL_ROOM:
			encounter_screen.visible = false
			if area_session.completed_rooms.is_empty():
				_show_start_error("恢复的普通房结算摘要不存在")
			else:
				summary_panel.show_room_checkpoint(
					area_session.completed_rooms[-1]
				)
		AreaRunSession.Phase.SHOP:
			encounter_screen.visible = false
			_request_music_for_phase(&"shop")
			shop_screen.bind_session(
				area_session.shop_session,
				area_session.card_catalog
			)
		AreaRunSession.Phase.ENGRAVING_REWARD, AreaRunSession.Phase.ENGRAVING_INSTALL:
			encounter_screen.visible = false
			_request_music_for_phase(
				&"engraving_install"
				if area_session.phase == AreaRunSession.Phase.ENGRAVING_INSTALL
				else &"engraving_reward"
			)
			reward_panel.bind_reward(
				area_session.engraving_offer_ids,
				area_session.die_profiles,
				area_session.engraving_catalog,
				area_session.rare_card_offer_ids,
				area_session.deck_ids,
				area_session.card_catalog,
				area_session.selected_reward_card_id,
				area_session.replaced_reward_card_id
			)
			if area_session.selected_engraving_id != &"":
				reward_panel.restore_engraving_selection(
					area_session.selected_engraving_id
				)
		AreaRunSession.Phase.COMPLETE:
			_show_restored_completion()
		_:
			_show_start_error("恢复的区域阶段不受支持")

func _show_route_choice() -> void:
	_request_music_for_phase(&"route_choice")
	intel_panel.close()
	shop_screen.visible = false
	reward_panel.close()
	complete_panel.close()
	summary_panel.close()
	var bound := route_panel.bind_routes(
		area_session.current_route_ids(),
		area_session.area_definition,
		area_session.deck_ids,
		area_session.card_catalog,
		area_session.challenge_ids,
		area_session.room_index
	)
	if not bound:
		encounter_screen.visible = true
		encounter_screen.show_external_error("路线资料无法显示")
		return
	SfxAccess.play(self, &"panel_open")
	call_deferred("_request_context_hint", &"route")

func _on_route_selected(room_id: StringName) -> void:
	_close_context_hint()
	var result := area_session.select_route(room_id)
	if not result.accepted:
		route_panel.show_error(result.reason)
		return
	SfxAccess.play(self, &"route_select")
	route_panel.close()
	bind_current_encounter()
	_emit_expedition_checkpoint()

func bind_current_encounter() -> void:
	if (
		area_session.encounter_session == null
		or (
			area_session.phase != AreaRunSession.Phase.NORMAL_ROOM
			and area_session.phase != AreaRunSession.Phase.DEALER
		)
	):
		encounter_screen.show_external_error("当前阶段没有可绑定的遭遇")
		return
	_request_music_for_phase(
		&"dealer"
		if area_session.phase == AreaRunSession.Phase.DEALER
		else &"normal_room"
	)
	route_panel.close()
	intel_panel.close()
	shop_screen.visible = false
	reward_panel.close()
	complete_panel.close()
	summary_panel.close()
	encounter_screen.visible = true
	if area_session.phase == AreaRunSession.Phase.DEALER:
		encounter_screen.bind_dealer(
			area_session.dealer_catalog.find_dealer(
				area_session.area_definition.dealer_id
			)
		)
	else:
		encounter_screen.bind_area_brief(area_session.area_definition.id)
	encounter_screen.bind_external_session(
		area_session.encounter_session.current_session,
		_area_copy(),
		_encounter_goal_copy()
	)
	_after_encounter_bound()
	if area_session.phase == AreaRunSession.Phase.DEALER:
		_after_dealer_bound()
		if not _dealer_opening_shown:
			_close_context_hint()
			var dealer := area_session.dealer_catalog.find_dealer(
				area_session.area_definition.dealer_id
			)
			if narrative_card.show_dealer_opening(
				dealer,
				_accessibility_snapshot()
			):
				return
		call_deferred("_request_context_hint", &"dealer")

func _area_copy() -> String:
	var area_name := area_session.area_definition.display_name
	if area_session.phase == AreaRunSession.Phase.DEALER:
		var dealer := area_session.dealer_catalog.find_dealer(
			area_session.area_definition.dealer_id
		)
		return "%s · %s" % [area_name, dealer.display_name]
	var room := area_session.area_definition.find_room(
		area_session.selected_room_ids[-1]
	)
	return "%s · %s" % [area_name, room.display_name]

func _encounter_goal_copy() -> String:
	var base := "累计：%d / %d　轮次 %d / %d　情报券：%d" % [
		area_session.encounter_session.cumulative_total,
		area_session.encounter_session.target_total,
		area_session.encounter_session.current_round,
		area_session.encounter_session.round_count,
		area_session.intel_tickets,
	]
	if area_session.challenge_ids.is_empty():
		return base
	return "%s　挑战：%s" % [
		base,
		preload("res://scripts/run/expedition_challenge_rules.gd").new(
			area_session.challenge_ids
		).display_copy(),
	]

func _on_round_committed(report: ResolutionReport) -> void:
	_close_context_hint()
	var result := area_session.accept_encounter_report(report)
	if not result.accepted:
		encounter_screen.show_external_error(result.reason)
		return
	_after_round_report_accepted()
	if area_session.phase == AreaRunSession.Phase.FAILED:
		var dealer := area_session.dealer_catalog.find_dealer(
			area_session.area_definition.dealer_id
		)
		summary_panel.show_area_failure(
			area_session.encounter_session,
			area_session.failure_origin == AreaRunSession.Phase.DEALER,
			area_session.area_definition.display_name,
			dealer.display_name
		)
		if _expedition_mode:
			summary_panel.get_node("%RetryRunButton").visible = false
			expedition_failed.emit(area_session.last_error)
		return
	if area_session.phase == AreaRunSession.Phase.ENGRAVING_REWARD:
		summary_panel.close()
		SfxAccess.play(self, &"round_success")
		_request_music_for_phase(&"engraving_reward")
		reward_panel.bind_reward(
			area_session.engraving_offer_ids,
			area_session.die_profiles,
			area_session.engraving_catalog,
			area_session.rare_card_offer_ids,
			area_session.deck_ids,
			area_session.card_catalog,
			area_session.selected_reward_card_id,
			area_session.replaced_reward_card_id
		)
		call_deferred("_request_context_hint", &"engraving")
		_emit_expedition_checkpoint()
		return
	if _show_restriction_choice_if_needed():
		return
	encounter_screen.set_run_status(_area_copy(), _encounter_goal_copy())
	summary_panel.show_run_state(area_session.encounter_session)
	if area_session.phase == AreaRunSession.Phase.AFTER_NORMAL_ROOM:
		_emit_expedition_checkpoint()

func _on_next_round_requested() -> void:
	_close_context_hint()
	var result := area_session.advance_encounter_round()
	if not result.accepted:
		encounter_screen.show_external_error(result.reason)
		return
	SfxAccess.play(self, &"ui_confirm")
	bind_current_encounter()

func _on_shop_requested() -> void:
	_close_context_hint()
	intel_panel.close()
	var result := area_session.open_shop()
	if not result.accepted:
		encounter_screen.show_external_error(result.reason)
		return
	summary_panel.close()
	encounter_screen.visible = false
	_request_music_for_phase(&"shop")
	shop_screen.bind_session(area_session.shop_session, area_session.card_catalog)
	SfxAccess.play(self, &"panel_open")
	call_deferred("_request_context_hint", &"shop")
	_emit_expedition_checkpoint()

func _on_shop_intel_view_requested(snapshot: ShopIntelSnapshot) -> void:
	if area_session == null or area_session.shop_session == null:
		shop_screen.get_node("%ShopErrorLabel").text = "当前没有可查看情报的商店"
		SfxAccess.play(self, &"error")
		return
	var bound := intel_panel.bind_snapshot(
		snapshot,
		area_session.area_definition,
		area_session.shop_session.deck_ids,
		area_session.card_catalog,
		area_session.dealer_catalog,
		area_session.challenge_ids
	)
	if bound:
		SfxAccess.play(self, &"panel_open")
	else:
		shop_screen.get_node("%ShopErrorLabel").text = "商店情报无法显示"
		SfxAccess.play(self, &"error")

func _on_shop_leave_requested() -> void:
	_close_context_hint()
	intel_panel.close()
	var result := area_session.leave_shop()
	if not result.accepted:
		shop_screen.get_node("%ShopErrorLabel").text = result.reason
		SfxAccess.play(self, &"error")
		return
	shop_screen.visible = false
	if area_session.phase == AreaRunSession.Phase.ROUTE_CHOICE:
		_show_route_choice()
	elif area_session.phase == AreaRunSession.Phase.DEALER:
		SfxAccess.play(self, &"ui_back")
		bind_current_encounter()
	else:
		encounter_screen.show_external_error("商店结算后的区域阶段无效")
	_emit_expedition_checkpoint()

func _on_shop_state_changed() -> void:
	_emit_expedition_checkpoint()

func _on_engraving_selected(engraving_id: StringName) -> void:
	var result := area_session.select_engraving(engraving_id)
	if not result.accepted:
		reward_panel.show_error(result.reason)
	else:
		SfxAccess.play(self, &"engraving_select")
		_emit_expedition_checkpoint()

func _on_install_requested(
	engraving_id: StringName,
	die_id: StringName,
	face: int
) -> void:
	_close_context_hint()
	if engraving_id != area_session.selected_engraving_id:
		reward_panel.show_error("界面选择与待安装刻印不一致，请重新选择")
		return
	var result := area_session.install_selected_engraving(die_id, face)
	if not result.accepted:
		reward_panel.show_error(result.reason)
		return
	_show_area_completion()

func _on_card_reward_requested(
	card_id: StringName,
	replaced_id: StringName
) -> void:
	_close_context_hint()
	var result := area_session.claim_rare_card_reward(card_id, replaced_id)
	if not result.accepted:
		reward_panel.show_error(result.reason)
		return
	_show_area_completion()

func _on_reward_card_selected(card_id: StringName) -> void:
	var result := area_session.select_rare_card_reward(card_id)
	if not result.accepted:
		reward_panel.show_error(result.reason)
		return
	_emit_expedition_checkpoint()

func _on_reward_replacement_selected(card_id: StringName) -> void:
	var result := area_session.select_reward_replacement(card_id)
	if not result.accepted:
		reward_panel.show_error(result.reason)
		return
	_emit_expedition_checkpoint()

func _show_area_completion() -> void:
	reward_panel.close()
	_request_music_for_phase(&"complete")
	var bound := complete_panel.bind_summary(
		area_session.completion_snapshot(),
		area_session.area_definition,
		area_session.card_catalog,
		area_session.dealer_catalog,
		area_session.engraving_catalog
	)
	if not bound:
		encounter_screen.show_external_error("区域完成摘要无法显示")
		return
	_emit_expedition_checkpoint()
	if _expedition_mode:
		expedition_area_completed.emit(area_session.completion_snapshot())

func _on_restart_requested() -> void:
	_close_context_hint()
	intel_panel.close()
	var result := area_session.restart()
	if not result.accepted:
		summary_panel.get_node("%SummaryDetail").text = result.reason
		return
	_show_route_choice()

func _on_return_requested() -> void:
	_close_context_hint()
	intel_panel.close()
	SfxAccess.play(self, &"page_transition")
	if _expedition_mode:
		expedition_exit_requested.emit()
	else:
		get_tree().change_scene_to_file("res://scenes/run/main_menu_screen.tscn")

func _on_home_pressed() -> void:
	_on_return_requested()

func _show_start_error(message: String) -> void:
	_close_context_hint()
	intel_panel.close()
	route_panel.close()
	shop_screen.visible = false
	reward_panel.close()
	complete_panel.close()
	summary_panel.close()
	encounter_screen.visible = true
	encounter_screen.show_external_error(message)

func confirm_dealer_restriction(restriction_id: StringName) -> bool:
	var result := area_session.choose_dealer_restriction(restriction_id)
	if not result.accepted:
		encounter_screen.show_external_error(result.reason)
		return false
	SfxAccess.play(self, &"ui_confirm")
	bind_current_encounter()
	_after_restriction_confirmed()
	return true

func _after_encounter_bound() -> void:
	pass

func _after_card_selected(
	_card_index: int,
	_card: CardDefinition,
	_token: Control
) -> void:
	pass

func _after_dealer_bound() -> void:
	pass

func _after_round_report_accepted() -> void:
	pass

func _show_restriction_choice_if_needed() -> bool:
	return false

func _after_restriction_confirmed() -> void:
	pass

func _request_context_hint(_checkpoint_id: StringName) -> void:
	pass

func _close_context_hint() -> void:
	pass

func _on_dealer_opening_confirmed() -> void:
	if (
		area_session == null
		or area_session.phase != AreaRunSession.Phase.DEALER
	):
		return
	_dealer_opening_shown = true
	call_deferred("_request_context_hint", &"dealer")

func _accessibility_snapshot() -> Dictionary:
	var service := get_tree().root.get_node_or_null("SettingsService")
	if service == null or not service.has_method("settings_snapshot"):
		return {}
	var settings: Dictionary = service.settings_snapshot()
	return settings.get("accessibility", {}).duplicate(true)

func _show_restored_completion() -> void:
	var summary: Dictionary = _configured_checkpoint.get("completion", {})
	if summary.is_empty():
		_show_start_error("恢复的区域完成摘要不存在")
		return
	encounter_screen.visible = false
	_request_music_for_phase(&"complete")
	complete_panel.bind_summary(
		summary,
		area_session.area_definition,
		area_session.card_catalog,
		area_session.dealer_catalog,
		area_session.engraving_catalog
	)

func _request_music_for_phase(phase_name: StringName) -> void:
	var service := get_tree().root.get_node_or_null("MusicService")
	if service != null and service.has_method("play_area_phase"):
		var area_id: StringName = (
			area_session.area_definition.id
			if area_session != null and area_session.area_definition != null
			else &""
		)
		service.call("play_area_phase", phase_name, area_id)

func _emit_expedition_checkpoint() -> void:
	if not _expedition_mode or area_session == null:
		return
	var snapshot := area_session.checkpoint_snapshot()
	if area_session.phase == AreaRunSession.Phase.COMPLETE:
		var completion: Dictionary = _configured_checkpoint.get(
			"completion",
			{}
		).duplicate(true)
		if completion.is_empty():
			completion = area_session.completion_snapshot()
		snapshot["completion"] = completion.duplicate(true)
	expedition_checkpoint_reached.emit(snapshot)
