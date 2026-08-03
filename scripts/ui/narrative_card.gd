class_name NarrativeCard
extends Control

signal confirmed
signal exit_requested

@onready var card_panel: PanelContainer = %NarrativeCard
@onready var kind_label: Label = %NarrativeKindLabel
@onready var title_label: Label = %NarrativeTitle
@onready var speaker_label: Label = %NarrativeSpeaker
@onready var body_label: Label = %NarrativeBody
@onready var context_label: Label = %NarrativeContextLabel
@onready var rule_label: Label = %NarrativeRuleLabel
@onready var continue_button: Button = %NarrativeContinueButton
@onready var exit_button: Button = %NarrativeExitButton

var _reduce_flashes := false
var _disable_distortion := false
var _opening_tween: Tween

func _ready() -> void:
	continue_button.pressed.connect(_on_confirmed)
	exit_button.pressed.connect(func() -> void: exit_requested.emit())
	close()

func show_area_transition(
	area: AreaDefinition,
	inherited_state: Dictionary,
	accessibility: Dictionary = {}
) -> bool:
	if area == null:
		return false
	_apply_accessibility(accessibility)
	kind_label.text = "连续远征 · 区域转换"
	title_label.text = area.expedition_entry_title
	speaker_label.visible = false
	body_label.text = area.expedition_entry_text
	context_label.visible = true
	var deck_count: int = inherited_state.get(
		"deck_ids",
		area.starting_deck_ids
	).size()
	var tickets: int = int(inherited_state.get(
		"intel_tickets",
		area.starting_intel_tickets
	))
	var engraving_count: int = _count_engravings(
		inherited_state.get("die_profiles", [])
	)
	if (
		not inherited_state.has("die_profiles")
		and area.initial_engraving_id != &""
	):
		engraving_count = 1
	context_label.text = "继承构筑  ·  手牌 %d 张  ·  情报券 %d  ·  刻印 %d 项" % [
		deck_count,
		tickets,
		engraving_count,
	]
	rule_label.visible = false
	continue_button.text = "进入区域"
	exit_button.visible = true
	_open()
	return true

func show_dealer_opening(
	dealer: DealerDefinition,
	accessibility: Dictionary = {}
) -> bool:
	if dealer == null:
		return false
	_apply_accessibility(accessibility)
	kind_label.text = "庄家开场"
	title_label.text = "公开规则已经入场"
	speaker_label.visible = true
	speaker_label.text = dealer.display_name
	body_label.text = dealer.opening_text
	context_label.visible = false
	rule_label.visible = true
	rule_label.text = "庄家规则  ·  %s" % dealer.rule_text
	continue_button.text = "确认规则"
	exit_button.visible = false
	_open()
	return true

func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func is_open() -> bool:
	return visible

func _open() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	move_to_front()
	card_panel.set_meta("flash_suppressed", _reduce_flashes)
	card_panel.set_meta("motion_suppressed", _disable_distortion)
	_play_opening_motion()
	SfxAccess.play(self, &"page_transition")
	continue_button.grab_focus()

func _on_confirmed() -> void:
	close()
	SfxAccess.play(self, &"ui_confirm")
	confirmed.emit()

func _apply_accessibility(accessibility: Dictionary) -> void:
	_reduce_flashes = bool(accessibility.get("reduce_flashes", false))
	_disable_distortion = bool(
		accessibility.get("disable_distortion", false)
	)

func _play_opening_motion() -> void:
	if _opening_tween != null:
		_opening_tween.kill()
		_opening_tween = null
	card_panel.modulate = Color.WHITE
	card_panel.scale = Vector2.ONE
	if _reduce_flashes and _disable_distortion:
		return
	call_deferred("_start_opening_motion")

func _start_opening_motion() -> void:
	if not visible:
		return
	card_panel.pivot_offset = card_panel.size * 0.5
	_opening_tween = create_tween()
	_opening_tween.set_parallel(true)
	if not _reduce_flashes:
		card_panel.modulate = Color(1.12, 1.12, 1.12, 1.0)
		_opening_tween.tween_property(
			card_panel,
			"modulate",
			Color.WHITE,
			0.2
		)
	if not _disable_distortion:
		card_panel.scale = Vector2(0.985, 0.985)
		_opening_tween.tween_property(
			card_panel,
			"scale",
			Vector2.ONE,
			0.2
		)

func _count_engravings(profiles: Array) -> int:
	var count := 0
	for profile in profiles:
		if (
			profile is Dictionary
			and profile.get("engraving_id", &"") != &""
		):
			count += 1
	return count
