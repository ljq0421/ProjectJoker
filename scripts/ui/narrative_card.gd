class_name NarrativeCard
extends Control

const ModifierCatalog = preload("res://scripts/run/area_run_modifier_catalog.gd")

signal confirmed
signal exit_requested

@onready var card_panel: PanelContainer = %NarrativeCard
@onready var kind_label: Label = %NarrativeKindLabel
@onready var title_label: Label = %NarrativeTitle
@onready var speaker_label: Label = %NarrativeSpeaker
@onready var body_label: Label = %NarrativeBody
@onready var modifier_candidates: RichTextLabel = %ModifierCandidates
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
	modifier_candidates.visible = false
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
	modifier_candidates.visible = false
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

func show_area_modifier_reveal(
	area: AreaDefinition,
	modifier_id: StringName,
	lucky_faces: Dictionary,
	accessibility: Dictionary = {}
) -> bool:
	if area == null:
		return false
	var catalog := ModifierCatalog.new()
	var selected: Dictionary = catalog.find(modifier_id)
	if selected.is_empty() or selected.get("area_id", &"") != area.id:
		return false
	_apply_accessibility(accessibility)
	kind_label.text = "区域异变 · 随机揭示"
	title_label.text = "%s 已锁定" % selected["display_name"]
	speaker_label.visible = false
	body_label.text = "本区从候选异变中随机锁定一条；本次生效项已用金色标记。"
	modifier_candidates.visible = true
	modifier_candidates.text = _modifier_candidates_copy(
		catalog.ids_for_area(area.id),
		modifier_id,
		catalog
	)
	context_label.visible = true
	context_label.text = "幸运面  ·  %s" % _lucky_faces_copy(lucky_faces)
	rule_label.visible = true
	rule_label.text = "已锁定至本区结束，不能更换；结算轨迹会显示实际触发。"
	continue_button.text = "确认异变，进入路线"
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

func _modifier_candidates_copy(
	ids: Array[StringName],
	selected_id: StringName,
	catalog: AreaRunModifierCatalog
) -> String:
	var lines: Array[String] = []
	for candidate_id in ids:
		var definition := catalog.find(candidate_id)
		if definition.is_empty():
			continue
		if candidate_id == selected_id:
			lines.append("[b][color=#f5c94d]★ %s：%s[/color][/b]" % [
				definition["display_name"],
				definition["description"],
			])
		else:
			lines.append("[color=#858ba3]○ %s：%s[/color]" % [
				definition["display_name"],
				definition["description"],
			])
	return "[center]%s[/center]" % "\n".join(lines)

func _lucky_faces_copy(lucky_faces: Dictionary) -> String:
	var parts: Array[String] = []
	for die_index in range(1, 7):
		parts.append("D%d=%d" % [
			die_index,
			lucky_faces.get(StringName("d%d" % die_index), 0),
		])
	return "　".join(parts)
