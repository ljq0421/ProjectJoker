class_name DiceFirstPrototypeScreen
extends Control

const MAIN_MENU_SCENE := "res://scenes/run/main_menu_screen.tscn"
const ControllerScript = preload("res://scripts/dice_first/dice_first_controller.gd")
# DiceFirstResolver is the sole authority behind controller.preview/commit.

const INACTIVE_COLOR := Color(0.48, 0.58, 0.68, 1.0)
const VIOLET := Color(0.92, 0.68, 1.0, 1.0)
const GOLD := Color(1.0, 0.78, 0.34, 1.0)
const LOST := Color(1.0, 0.48, 0.42, 1.0)

@onready var back_button: Button = %BackButton
@onready var settings_layer: CanvasLayer = %SettingsLayer
@onready var phase_label: Label = %PhaseLabel
@onready var roll_button: Button = %RollButton
@onready var reroll_button: Button = %RerollButton
@onready var keep_all_button: Button = %KeepAllButton
@onready var dice_tray: HBoxContainer = %DiceTray
@onready var body: HBoxContainer = %Body
@onready var board_column: VBoxContainer = %BoardColumn
@onready var board_header: Label = %BoardHeader
@onready var right_rail: VBoxContainer = %RightRail
@onready var selection_panel: PanelContainer = %SelectionPanel
@onready var selection_title: Label = %SelectionTitle
@onready var selection_summary_label: Label = %SelectionSummaryLabel
@onready var cross_table_panel: PanelContainer = %CrossTablePanel
@onready var cross_table_title: Label = %CrossTableTitle
@onready var cross_table_rule: Label = %CrossTableRule
@onready var left_table_button: Button = %LeftTableButton
@onready var right_table_button: Button = %RightTableButton
@onready var clear_table_button: Button = %ClearTableButton
@onready var left_table_dice_label: Label = %LeftTableDiceLabel
@onready var right_table_dice_label: Label = %RightTableDiceLabel
@onready var cross_table_echo_label: Label = %CrossTableEchoLabel
@onready var instruction_header: Label = %InstructionHeader
@onready var instruction_row: HBoxContainer = %InstructionRow
@onready var preview_total_label: Label = %PreviewTotalLabel
@onready var energy_label: Label = %EnergyLabel
@onready var choice_preview_label: Label = %UpgradePreviewLabel
@onready var cost_label: Label = %CostLabel
@onready var event_summary: Label = %EventSummary
@onready var preview_panel: PanelContainer = %PreviewPanel
@onready var action_hint_label: Label = %ActionHintLabel
@onready var footer: HBoxContainer = %Footer
@onready var breakthrough_button: Button = %BreakthroughButton
@onready var commit_button: Button = %CommitButton
@onready var restart_button: Button = %RestartButton
@onready var breakthrough_overlay: Control = %BreakthroughOverlay
@onready var break_delta_label: Label = %BreakDeltaLabel
@onready var break_final_label: Label = %BreakFinalLabel
@onready var triplet_label: Label = %TripletResonance
@onready var pair_label: Label = %PairResonance
@onready var straight_label: Label = %StraightResonance
@onready var polar_label: Label = %PolarResonance

var controller
var selected_die_id: StringName = &""
var selected_instruction_index := -1
var instructions: Array[CardDefinition] = []
var _dice_tokens: Array[Button] = []
var _motion_reduced := false
var _flash_reduced := false
var _climax_tween: Tween

func _ready() -> void:
	_read_accessibility()
	_build_instructions()
	_bind_stable_scene_nodes()
	_new_encounter()

func _read_accessibility() -> void:
	var service := get_tree().root.get_node_or_null("SettingsService")
	if service != null and service.has_method("accessibility_value"):
		_motion_reduced = bool(service.accessibility_value(&"disable_distortion"))
		_flash_reduced = bool(service.accessibility_value(&"reduce_flashes"))

func _build_instructions() -> void:
	instructions = [
		_make_instruction(&"rewrite_flip", "翻到另一面", EffectSpec.Operation.FLIP_DIE, 0),
		_make_instruction(&"rewrite_up", "点数 +1", EffectSpec.Operation.ADJUST_DIE, 1),
		_make_instruction(&"rewrite_down", "点数 −1", EffectSpec.Operation.ADJUST_DIE, -1),
	]

func _make_instruction(id: StringName, display_name: String, operation: EffectSpec.Operation, amount: int) -> CardDefinition:
	var effect := EffectSpec.new()
	effect.operation = operation
	effect.amount = amount
	var definition := CardDefinition.new()
	definition.id = id
	definition.display_name = display_name
	definition.rule_text = "改一颗骰子的最终点数"
	definition.target_type = CardDefinition.TargetType.DIE
	definition.effects = [effect]
	return definition

func _bind_stable_scene_nodes() -> void:
	back_button.pressed.connect(_on_back_pressed)
	roll_button.pressed.connect(_on_roll_pressed)
	reroll_button.pressed.connect(_on_reroll_pressed)
	keep_all_button.pressed.connect(_on_keep_all_pressed)
	left_table_button.pressed.connect(_on_table_pressed.bind(&"left"))
	right_table_button.pressed.connect(_on_table_pressed.bind(&"right"))
	clear_table_button.pressed.connect(_on_clear_table_pressed)
	breakthrough_button.pressed.connect(_on_breakthrough_pressed)
	commit_button.pressed.connect(_on_commit_pressed)
	restart_button.pressed.connect(_new_encounter)
	for child in dice_tray.get_children():
		var token := child as Button
		if token == null: continue
		_dice_tokens.append(token)
		token.connect("die_activated", _on_die_activated)
		token.set_motion_reduced(_motion_reduced)
	for index in range(instruction_row.get_child_count()):
		(instruction_row.get_child(index) as Button).pressed.connect(_on_instruction_pressed.bind(index))

func _new_encounter() -> void:
	if _climax_tween != null and _climax_tween.is_valid(): _climax_tween.kill()
	controller = ControllerScript.new(
		int(get_tree().root.get_meta("dice_first_seed", 0)),
		StringName(get_tree().root.get_meta("dice_first_rule_id", &""))
	)
	selected_die_id = &""
	selected_instruction_index = -1
	breakthrough_overlay.visible = false
	settings_layer.visible = true
	restart_button.visible = false
	_refresh()
	roll_button.grab_focus()

func _on_back_pressed() -> void:
	SfxAccess.play(self, &"ui_back")
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _on_roll_pressed() -> void:
	if not controller.roll_initial(): return _reject("当前不能再次投骰")
	SfxAccess.play(self, &"die_place")
	_refresh()
	for index in range(_dice_tokens.size()): _dice_tokens[index].play_roll_feedback(float(index) * 0.055)

func _on_die_activated(die_id: StringName) -> void:
	match controller.state.phase:
		DiceFirstState.Phase.REROLL_DECISION:
			if not controller.toggle_reroll_die(die_id): return _reject("最多选择 3 颗骰子重投")
			SfxAccess.play(self, &"die_select")
		DiceFirstState.Phase.BUILD:
			if selected_instruction_index >= 0:
				if not controller.play_instruction(instructions[selected_instruction_index], die_id): return _reject("每局只能改一颗骰子")
				selected_instruction_index = -1
				selected_die_id = &""
				SfxAccess.play(self, &"card_play")
			else:
				selected_die_id = &"" if selected_die_id == die_id else die_id
				SfxAccess.play(self, &"die_select")
		_:
			return
	_refresh()

func _on_reroll_pressed() -> void:
	var rerolled_ids: Array[StringName] = []
	rerolled_ids.assign(controller.state.selected_reroll_die_ids)
	if not controller.confirm_reroll(): return _reject("选择 1–3 颗骰子；每颗扣 2 分和 1 能量")
	SfxAccess.play(self, &"resolution_impact")
	_refresh()
	for die_id in rerolled_ids:
		var token := _find_die_token(die_id)
		if token != null: token.play_roll_feedback()

func _on_keep_all_pressed() -> void:
	if not controller.keep_all(): return _reject("当前不能保留骰子")
	SfxAccess.play(self, &"ui_confirm")
	_refresh()

func _on_instruction_pressed(index: int) -> void:
	if controller.state.phase != DiceFirstState.Phase.BUILD: return _reject("先完成重投决定")
	if not controller.state.played_cards.is_empty(): return _reject("本局已经改过一颗骰子")
	selected_instruction_index = -1 if selected_instruction_index == index else index
	selected_die_id = &""
	SfxAccess.play(self, &"card_select")
	_refresh()

func _on_table_pressed(table_id: StringName) -> void:
	if selected_die_id == &"": return _reject("先选择一颗骰子，再放入规则台")
	if not controller.assign_die_to_table(selected_die_id, table_id): return _reject("该规则台已经放满 3 颗骰子")
	selected_die_id = &""
	SfxAccess.play(self, &"die_place")
	_refresh()

func _on_clear_table_pressed() -> void:
	if selected_die_id == &"": return _reject("先选择一颗已分配的骰子")
	if not controller.clear_die_table(selected_die_id): return _reject("这颗骰子还没有进入规则台")
	selected_die_id = &""
	SfxAccess.play(self, &"undo")
	_refresh()

func _on_breakthrough_pressed() -> void:
	if not controller.toggle_breakthrough(): return _reject("破局需要 2 能量，并且至少有一个组合")
	SfxAccess.play(self, &"resolution_impact" if controller.state.breakthrough_requested else &"undo")
	_refresh()
	if controller.state.breakthrough_requested: _pulse_breakthrough_preview()

func _on_commit_pressed() -> void:
	var preview_signature: Array[String] = controller.preview().event_signature()
	var report = controller.commit()
	if report == null: return _reject("当前不能结算")
	if report.event_signature() != preview_signature: return _reject("显示结果与最终结算不一致，已中止")
	SfxAccess.play(self, &"round_commit")
	_refresh()
	_play_upgrade_feedback(report)
	if report.breakthrough_applied: _show_breakthrough_climax(report)
	else: SfxAccess.play(self, &"resolution_climax")

func _refresh() -> void:
	var report = controller.preview()
	action_hint_label.remove_theme_color_override("font_color")
	_refresh_phase()
	_refresh_dice(report)
	_refresh_combo_plan(report)
	_refresh_table_allocation(report)
	_refresh_resonances(report)
	_refresh_instructions()
	_refresh_preview(report)

func _refresh_phase() -> void:
	var phase = controller.state.phase
	var reroll_visible: bool = phase == DiceFirstState.Phase.REROLL_DECISION
	var build_visible: bool = phase in [DiceFirstState.Phase.BUILD, DiceFirstState.Phase.COMMITTED]
	body.visible = phase != DiceFirstState.Phase.AWAITING_ROLL
	board_column.visible = reroll_visible or build_visible
	selection_panel.visible = reroll_visible or build_visible
	cross_table_panel.visible = reroll_visible or build_visible
	instruction_header.visible = build_visible
	instruction_row.visible = build_visible
	preview_panel.visible = build_visible
	footer.visible = phase != DiceFirstState.Phase.AWAITING_ROLL
	breakthrough_button.visible = build_visible
	commit_button.visible = build_visible
	roll_button.disabled = phase != DiceFirstState.Phase.AWAITING_ROLL
	reroll_button.disabled = not reroll_visible or controller.state.selected_reroll_die_ids.is_empty()
	keep_all_button.disabled = not reroll_visible
	commit_button.disabled = not build_visible or phase == DiceFirstState.Phase.COMMITTED or not controller.preview().table_allocation_complete
	restart_button.visible = phase == DiceFirstState.Phase.COMMITTED
	match phase:
		DiceFirstState.Phase.AWAITING_ROLL:
			phase_label.text = "第 1 步：投掷 6 颗骰子"
			action_hint_label.text = ""
		DiceFirstState.Phase.REROLL_DECISION:
			var count: int = controller.state.selected_reroll_die_ids.size()
			phase_label.text = "第 2 步：选择 1–3 颗骰子重投"
			reroll_button.text = "重投 %d 颗（−%d分 / −%d能量）" % [count, count * 2, count]
			action_hint_label.text = "已选择 %d 颗；没选的骰子不会变化。" % count
		DiceFirstState.Phase.BUILD:
			phase_label.text = "第 3 步：按“%s”分配左右台，然后结算" % controller.preview().table_display_name
			action_hint_label.text = "本局规则会改变得分与破局能量；改骰后预览即时更新。"
		DiceFirstState.Phase.COMMITTED:
			phase_label.text = "已结算：结果不会再随机变化"
			action_hint_label.text = "本局结果已经确定。"

func _refresh_dice(report) -> void:
	var resonant_ids: Array[StringName] = report.resonant_die_ids()
	for index in range(_dice_tokens.size()):
		var die_id := StringName("d%d" % (index + 1))
		var token := _dice_tokens[index]
		var assignment_copy := "左台" if die_id in controller.state.left_table_die_ids else "右台" if die_id in controller.state.right_table_die_ids else ""
		token.bind_die(die_id, int(report.effective_die_values.get(die_id, 0)), selected_die_id == die_id, die_id in resonant_ids, assignment_copy, die_id in controller.state.selected_reroll_die_ids)
		token.disabled = controller.state.phase in [DiceFirstState.Phase.AWAITING_ROLL, DiceFirstState.Phase.COMMITTED]

func _refresh_table_allocation(report) -> void:
	if controller.state.phase not in [DiceFirstState.Phase.REROLL_DECISION, DiceFirstState.Phase.BUILD, DiceFirstState.Phase.COMMITTED]: return
	cross_table_title.text = "行为规则 · %s" % report.table_display_name
	cross_table_rule.text = "左台 3 颗 · 右台 3 颗\n%s" % report.table_rule_copy
	left_table_dice_label.text = _table_copy("左台", controller.state.left_table_die_ids, report.effective_die_values)
	right_table_dice_label.text = _table_copy("右台", controller.state.right_table_die_ids, report.effective_die_values)
	left_table_button.text = "放入左台（%d/3）" % controller.state.left_table_die_ids.size()
	right_table_button.text = "放入右台（%d/3）" % controller.state.right_table_die_ids.size()
	var has_selected: bool = controller.state.phase == DiceFirstState.Phase.BUILD and selected_die_id != &"" and selected_instruction_index < 0
	left_table_button.disabled = not has_selected or controller.state.left_table_die_ids.size() >= 3
	right_table_button.disabled = not has_selected or controller.state.right_table_die_ids.size() >= 3
	clear_table_button.disabled = not has_selected or (selected_die_id not in controller.state.left_table_die_ids and selected_die_id not in controller.state.right_table_die_ids)
	if controller.state.phase == DiceFirstState.Phase.REROLL_DECISION:
		cross_table_echo_label.text = "本局规则已公开 · 重投后进行左右分配"
	elif not report.table_allocation_complete:
		cross_table_echo_label.text = "%s · 先选骰，再放入左右台" % report.table_reason
	elif report.table_detail_lines.is_empty():
		cross_table_echo_label.text = "分配完成 · 本次没有触发规则台效果"
	else:
		var score_copy := "+%d" % report.table_score if report.table_score >= 0 else str(report.table_score)
		cross_table_echo_label.text = "%s\n规则台合计 %s分 / +%d能量" % ["\n".join(report.table_detail_lines), score_copy, report.table_energy]

func _table_copy(title: String, die_ids: Array[StringName], values: Dictionary) -> String:
	var entries: Array[String] = []
	for die_id in die_ids: entries.append("%s=%d" % [String(die_id).to_upper(), int(values.get(die_id, 0))])
	return "%s %d/3\n%s" % [title, die_ids.size(), " · ".join(entries) if not entries.is_empty() else "—"]

func _refresh_combo_plan(report) -> void:
	if controller.state.phase == DiceFirstState.Phase.REROLL_DECISION:
		board_header.text = "选择 1–3 颗骰子重投；没选的骰子保持不变"
		selection_title.text = "当前选择会怎样？"
		if controller.state.selected_reroll_die_ids.is_empty():
			selection_summary_label.text = "点击骰子选择重投\n每颗 −2分 / −1能量"
			return
		var lines: Array[String] = []
		var preserved_labels := _candidate_labels(report.preserved_candidates)
		var broken_labels := _candidate_labels(report.broken_candidates)
		lines.append("不动：%s" % ("、".join(preserved_labels) if not preserved_labels.is_empty() else "没有初始组合"))
		if not broken_labels.is_empty(): lines.append("会拆散：%s" % "、".join(broken_labels))
		selection_summary_label.text = "\n".join(lines)
		return
	selection_title.text = "组合升级奖励"
	if report.upgraded:
		var initial_label: String = report.upgraded_candidate.get("label", "初始组合")
		board_header.text = "组合升级成功 / 还可改一颗骰子"
		selection_summary_label.text = "初始的 %s 没被重投拆散\n%s\n+1能量" % [initial_label, report.upgrade_label]
	else:
		board_header.text = "可改一颗骰子，然后确认结算"
		selection_summary_label.text = "本局没有组合升级\n初始组合没被重投拆散，并且变大时，+1能量"

func _candidate_labels(candidates: Array[Dictionary]) -> Array[String]:
	var labels: Array[String] = []
	for candidate in candidates: labels.append(String(candidate.get("label", "组合")))
	return labels

func _refresh_resonances(report) -> void:
	_set_resonance_label(triplet_label, report.has_resonance(&"triplet"), "三个相同 · +10分 / +2能量")
	_set_resonance_label(pair_label, report.has_resonance(&"pair"), "一个对子 · +4分 / +1能量")
	_set_resonance_label(straight_label, report.has_resonance(&"straight"), "四个连续 · +8分 / +2能量")
	_set_resonance_label(polar_label, report.has_resonance(&"polar_loop"), "三对都凑成 7 · +12分 / +3能量")

func _set_resonance_label(label: Label, active: bool, copy: String) -> void:
	label.text = "%s %s" % ["◆" if active else "○", copy]
	label.add_theme_color_override("font_color", VIOLET if active else INACTIVE_COLOR)

func _refresh_instructions() -> void:
	var used: bool = not controller.state.played_cards.is_empty()
	for index in range(instruction_row.get_child_count()):
		var button := instruction_row.get_child(index) as Button
		button.disabled = controller.state.phase != DiceFirstState.Phase.BUILD or used
		button.self_modulate = GOLD if selected_instruction_index == index else Color.WHITE

func _refresh_preview(report) -> void:
	preview_total_label.text = "%d 分" % report.total
	energy_label.text = "破局 %d / 2（组合%d + 升级%d + 规则台%d − 重投%d）" % [report.energy, report.resonance_energy, report.upgrade_energy, report.table_energy, report.reroll_energy_cost]
	if report.upgraded:
		choice_preview_label.text = "组合升级：%s，能量 +1" % report.upgrade_label
	else:
		choice_preview_label.text = "组合未升级：初始组合必须没有被重投拆散，并且变大"
	cost_label.text = "骰子 %d + 组合 %d + 规则台 %d − 重投 %d%s" % [
		report.base_total,
		report.resonance_score,
		report.table_score,
		report.reroll_score_cost,
		" + 破局 %d" % report.breakthrough_delta if report.breakthrough_applied else "",
	]
	breakthrough_button.disabled = controller.state.phase != DiceFirstState.Phase.BUILD or not report.table_allocation_complete or (not report.breakthrough_available and not controller.state.breakthrough_requested)
	breakthrough_button.text = (
		"先完成左右规则台"
		if not report.table_allocation_complete
		else "撤销破局（当前 +%d）" % report.breakthrough_delta
		if controller.state.breakthrough_requested
		else "能量已满：让 %s 再计 +%d" % [String(report.breakthrough_die_id).to_upper(), report.breakthrough_delta]
		if report.breakthrough_available
		else "破局需要 2 能量"
	)
	breakthrough_button.self_modulate = GOLD if controller.state.breakthrough_requested else Color.WHITE
	event_summary.text = "点击“确认结算”后不会再出现随机变化。"

func _find_die_token(die_id: StringName) -> Button:
	for token in _dice_tokens:
		if StringName(token.get("die_id")) == die_id: return token
	return null

func _pulse_breakthrough_preview() -> void:
	if _motion_reduced: return
	breakthrough_button.pivot_offset = breakthrough_button.size * 0.5
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(breakthrough_button, "scale", Vector2(1.08, 1.08), 0.14)
	tween.tween_property(breakthrough_button, "scale", Vector2.ONE, 0.18)

func _play_upgrade_feedback(report) -> void:
	if not report.upgraded or _motion_reduced: return
	selection_summary_label.pivot_offset = selection_summary_label.size * 0.5
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(selection_summary_label, "scale", Vector2(1.08, 1.08), 0.14)
	tween.tween_property(selection_summary_label, "scale", Vector2.ONE, 0.2)

func _show_breakthrough_climax(report) -> void:
	break_delta_label.text = "%s  +%d" % [String(report.breakthrough_die_id).to_upper(), report.breakthrough_delta]
	break_final_label.text = "最终 %d 分 · 能量 %d" % [report.total, report.energy]
	breakthrough_overlay.visible = true
	settings_layer.visible = false
	breakthrough_overlay.modulate.a = 1.0 if _flash_reduced else 0.0
	var panel := breakthrough_overlay.get_node("BreakPanel") as Control
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2.ONE if _motion_reduced else Vector2(0.72, 0.72)
	SfxAccess.play(self, &"resolution_climax")
	_climax_tween = create_tween()
	if not _flash_reduced: _climax_tween.tween_property(breakthrough_overlay, "modulate:a", 1.0, 0.18)
	if not _motion_reduced:
		_climax_tween.parallel().tween_property(panel, "scale", Vector2(1.04, 1.04), 0.36).set_trans(Tween.TRANS_BACK)
		_climax_tween.tween_property(panel, "scale", Vector2.ONE, 0.16)
	_climax_tween.tween_interval(1.15)
	_climax_tween.tween_property(breakthrough_overlay, "modulate:a", 0.0, 0.24)
	_climax_tween.tween_callback(_finish_breakthrough_climax)

func _finish_breakthrough_climax() -> void:
	breakthrough_overlay.visible = false
	settings_layer.visible = true

func _reject(message: String) -> void:
	action_hint_label.text = message
	action_hint_label.add_theme_color_override("font_color", LOST)
	SfxAccess.play(self, &"error")
	if _motion_reduced: return
	var tween := create_tween()
	tween.tween_property(action_hint_label, "position:x", action_hint_label.position.x - 8.0, 0.04)
	tween.tween_property(action_hint_label, "position:x", action_hint_label.position.x + 16.0, 0.06)
	tween.tween_property(action_hint_label, "position:x", action_hint_label.position.x, 0.05)
