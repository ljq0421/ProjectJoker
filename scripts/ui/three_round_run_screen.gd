class_name ThreeRoundRunScreen
extends Control

@export var run_seed: int = ThreeRoundEncounterSession.DEFAULT_SEED
@export var run_target: int = ThreeRoundEncounterSession.DEFAULT_TARGET

@onready var encounter_screen: SingleEncounterScreen = %EncounterScreen
@onready var summary_panel: RoundSummaryPanel = %RoundSummaryPanel
@onready var shop_screen: ShopScreen = %ShopScreen

var catalog := CardCatalog.new()
var run_session: ThreeRoundEncounterSession
var shop_session: ShopSession

func _ready() -> void:
	encounter_screen.round_committed.connect(_on_round_committed)
	summary_panel.next_round_requested.connect(_on_next_round_requested)
	summary_panel.shop_requested.connect(open_shop)
	summary_panel.retry_requested.connect(_on_retry_requested)
	summary_panel.return_requested.connect(_on_return_requested)
	shop_screen.leave_requested.connect(_on_shop_leave_requested)
	start_run()

func start_run() -> void:
	run_session = ThreeRoundEncounterSession.new(catalog, run_seed, run_target)
	var result := run_session.start()
	if not result.accepted:
		encounter_screen.show_external_error(result.reason)
		return
	_bind_current_round()

func open_shop() -> void:
	if run_session.status != ThreeRoundEncounterSession.Status.SUCCEEDED:
		encounter_screen.show_external_error("只有达成三轮目标后才能进入商店")
		return
	shop_session = ShopSession.new(
		catalog,
		run_session.starter_deck_ids,
		run_session.shop_offer_ids,
		run_session.intel_tickets
	)
	summary_panel.close()
	encounter_screen.visible = false
	shop_screen.bind_session(shop_session, catalog)
	SfxAccess.play(self, &"panel_open")

func _bind_current_round() -> void:
	encounter_screen.visible = true
	shop_screen.visible = false
	summary_panel.close()
	encounter_screen.bind_external_session(
		run_session.current_session,
		"三轮试局 · 种子 %d" % run_session.seed_value,
		"累计：%d / %d　轮次 %d / 3　情报券：%d" % [
			run_session.cumulative_total,
			run_session.target_total,
			run_session.current_round,
			run_session.intel_tickets,
		]
	)

func _on_round_committed(report: ResolutionReport) -> void:
	var result := run_session.accept_committed_report(report)
	if not result.accepted:
		encounter_screen.show_external_error(result.reason)
		return
	encounter_screen.set_run_status(
		"三轮试局 · 种子 %d" % run_session.seed_value,
		"累计：%d / %d　轮次 %d / 3　情报券：%d" % [
			run_session.cumulative_total,
			run_session.target_total,
			run_session.current_round,
			run_session.intel_tickets,
		]
	)
	summary_panel.show_run_state(run_session)

func _on_next_round_requested() -> void:
	var result := run_session.advance_round()
	if not result.accepted:
		encounter_screen.show_external_error(result.reason)
		return
	SfxAccess.play(self, &"ui_confirm")
	_bind_current_round()

func _on_shop_leave_requested() -> void:
	shop_screen.visible = false
	summary_panel.show_stage_complete(
		shop_session.deck_ids,
		shop_session.intel_tickets
	)

func _on_retry_requested() -> void:
	SfxAccess.play(self, &"page_transition")
	get_tree().reload_current_scene()

func _on_return_requested() -> void:
	SfxAccess.play(self, &"page_transition")
	get_tree().change_scene_to_file("res://scenes/run/single_encounter_screen.tscn")
