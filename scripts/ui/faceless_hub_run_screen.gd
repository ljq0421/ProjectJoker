class_name FacelessHubRunScreen
extends AreaRunScreen

const FACELESS_SEED := 20260727

@onready var round_schedule_strip: RoundScheduleStrip = %RoundScheduleStrip
@onready var final_restriction_panel: FinalRestrictionPanel = %FinalRestrictionPanel

func _ready() -> void:
	final_restriction_panel.restriction_confirmed.connect(
		_on_restriction_confirmed
	)
	super._ready()
	var host: CenterContainer = encounter_screen.get_node("%RunStatusSlot")
	round_schedule_strip.reparent(host)
	round_schedule_strip.visible = false
	host.visible = false

func build_area_definition() -> AreaDefinition:
	return AreaCatalog.new().faceless_hub()

func build_seed() -> int:
	return FACELESS_SEED

func _show_route_choice() -> void:
	_hide_schedule()
	final_restriction_panel.close()
	super._show_route_choice()

func _after_encounter_bound() -> void:
	if area_session.phase != AreaRunSession.Phase.DEALER:
		_hide_schedule()
		return
	_bind_schedule()

func _after_dealer_bound() -> void:
	_bind_schedule()

func _after_round_report_accepted() -> void:
	if area_session.phase == AreaRunSession.Phase.DEALER:
		_bind_schedule()

func _show_restriction_choice_if_needed() -> bool:
	if (
		area_session.phase != AreaRunSession.Phase.DEALER
		or area_session.encounter_session.status
		!= ThreeRoundEncounterSession.Status.AWAITING_RESTRICTION
	):
		return false
	summary_panel.close()
	var opened := final_restriction_panel.open_options(
		area_session.encounter_session.public_restriction_options()
	)
	if not opened:
		encounter_screen.show_external_error("最终限制候选无法显示")
	return opened

func _after_restriction_confirmed() -> void:
	final_restriction_panel.close()
	_bind_schedule()

func _on_restriction_confirmed(restriction_id: StringName) -> void:
	if not confirm_dealer_restriction(restriction_id):
		final_restriction_panel.show_error(area_session.last_error)

func _bind_schedule() -> void:
	if (
		area_session == null
		or area_session.encounter_session == null
		or area_session.area_definition.dealer_round_schedule == null
	):
		_hide_schedule()
		return
	var host: Control = encounter_screen.get_node("%RunStatusSlot")
	host.visible = round_schedule_strip.bind_schedule(
		area_session.area_definition.dealer_round_schedule,
		area_session.encounter_session
	)

func _hide_schedule() -> void:
	if is_instance_valid(round_schedule_strip):
		round_schedule_strip.visible = false
	if is_instance_valid(encounter_screen):
		var host := encounter_screen.get_node_or_null("%RunStatusSlot")
		if host != null:
			host.visible = false
