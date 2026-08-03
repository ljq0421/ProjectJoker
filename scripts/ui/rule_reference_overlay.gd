class_name RuleReferenceOverlay
extends Control

signal close_requested
signal practice_requested(archive_id: StringName)

const RuleCopy = preload("res://scripts/ui/rule_copy_formatter.gd")
const ARCHIVE_SHORT_LABELS := [
	"点数",
	"集合",
	"奇偶",
	"序列",
	"槽位",
	"扭曲",
]

@onready var current_rules_button: Button = %CurrentRulesButton
@onready var context_label: Label = %ArchiveContextLabel
@onready var summary_label: Label = %ArchiveSummaryLabel
@onready var detail_eyebrow: Label = %RuleDetailEyebrow
@onready var detail_title: Label = %RuleDetailTitle
@onready var detail_formula: Label = %RuleDetailFormula
@onready var detail_description: Label = %RuleDetailDescription
@onready var detail_metrics: Label = %RuleDetailMetrics
@onready var detail_timing: Label = %RuleDetailTiming
@onready var handbook_hint: Label = %HandbookHint
@onready var practice_button: Button = %PracticeArchiveButton

var catalog := RuleArchiveCatalog.new()
var _entries: Array[RuleArchiveDefinition] = []
var _current_rules: Array[RuleDefinition] = []
var _active_rules: Array[RuleDefinition] = []
var _active_context: StringName = &""
var _practice_enabled := false

func _ready() -> void:
	_entries = catalog.all_entries()
	%CloseRuleReferenceButton.pressed.connect(
		func() -> void: close_requested.emit()
	)
	practice_button.pressed.connect(_request_practice)
	current_rules_button.pressed.connect(show_current_rules)
	var archive_buttons := _archive_buttons()
	for index in range(mini(archive_buttons.size(), _entries.size())):
		var entry := _entries[index]
		archive_buttons[index].text = ARCHIVE_SHORT_LABELS[index]
		archive_buttons[index].tooltip_text = entry.summary
		archive_buttons[index].pressed.connect(show_archive.bind(entry.id))
	var rule_buttons := _rule_buttons()
	for index in range(rule_buttons.size()):
		rule_buttons[index].pressed.connect(_show_rule.bind(index))
	visible = false

func open_reference(
	current_rules: Array = [],
	practice_enabled := false,
	preferred_archive: StringName = &"",
	close_copy := "关闭"
) -> void:
	_current_rules.clear()
	_practice_enabled = practice_enabled
	%CloseRuleReferenceButton.text = close_copy
	for rule in current_rules:
		if rule is RuleDefinition:
			_current_rules.append(rule)
	current_rules_button.visible = not _current_rules.is_empty()
	visible = true
	if not _current_rules.is_empty():
		show_current_rules()
	elif preferred_archive != &"" and catalog.find_entry(preferred_archive) != null:
		show_archive(preferred_archive)
	elif not _entries.is_empty():
		show_archive(_entries[0].id)
	%CloseRuleReferenceButton.grab_focus()

func close_reference() -> void:
	visible = false

func show_current_rules() -> void:
	if _current_rules.is_empty():
		return
	_active_context = &"current"
	context_label.text = "当前牌局"
	summary_label.text = "这是当前桌面的只读快照。关闭档案后，骰子、手法牌与结算进度保持不变。"
	_bind_rules(_current_rules)
	_update_category_selection()
	_update_practice_action()

func show_archive(archive_id: StringName) -> void:
	var entry := catalog.find_entry(archive_id)
	if entry == null or entry.encounter == null:
		return
	_active_context = entry.id
	context_label.text = entry.display_name
	summary_label.text = "%s\n%s" % [entry.summary, entry.explanation]
	_bind_rules(entry.encounter.rules)
	_update_category_selection()
	_update_practice_action()

func _bind_rules(rules: Array[RuleDefinition]) -> void:
	_active_rules.assign(rules)
	var buttons := _rule_buttons()
	for index in range(buttons.size()):
		var has_rule := index < _active_rules.size()
		buttons[index].visible = has_rule
		buttons[index].disabled = not has_rule
		buttons[index].button_pressed = index == 0 and has_rule
		if has_rule:
			buttons[index].text = _active_rules[index].display_name
	if not _active_rules.is_empty():
		_show_rule(0)
	else:
		_clear_detail()

func _show_rule(index: int) -> void:
	if index < 0 or index >= _active_rules.size():
		return
	var rule := _active_rules[index]
	var template := rule.template
	for button_index in range(_rule_buttons().size()):
		_rule_buttons()[button_index].button_pressed = button_index == index
	detail_eyebrow.text = "%s / OPEN RULE" % RuleCopy.category_label(template)
	detail_title.text = rule.display_name
	detail_formula.text = RuleCopy.formula(rule)
	detail_description.text = (
		template.description
		if template != null
		else "按当前规则台公开条件判断。"
	)
	detail_metrics.text = "骰位 %d　·　基础系数 ×%d" % [
		rule.slot_count,
		rule.coefficient,
	]
	detail_timing.text = RuleCopy.timing_copy(template)

func _clear_detail() -> void:
	detail_eyebrow.text = "RULE HANDBOOK"
	detail_title.text = "没有可显示的规则"
	detail_formula.text = ""
	detail_description.text = "当前页面没有绑定牌局规则。"
	detail_metrics.text = ""
	detail_timing.text = ""
	_update_practice_action()

func _update_category_selection() -> void:
	current_rules_button.button_pressed = _active_context == &"current"
	for index in range(mini(_archive_buttons().size(), _entries.size())):
		_archive_buttons()[index].button_pressed = (
			_entries[index].id == _active_context
		)

func _archive_buttons() -> Array[Button]:
	return [
		%Archive01Button,
		%Archive02Button,
		%Archive03Button,
		%Archive04Button,
		%Archive05Button,
		%Archive06Button,
	]

func _rule_buttons() -> Array[Button]:
	return [%Rule01Button, %Rule02Button, %Rule03Button]


func _update_practice_action() -> void:
	var can_practice := (
		_practice_enabled
		and _active_context != &""
		and _active_context != &"current"
	)
	practice_button.visible = can_practice
	practice_button.disabled = not can_practice
	if can_practice:
		var entry := catalog.find_entry(_active_context)
		practice_button.text = "开始“%s”演练" % entry.display_name
		handbook_hint.text = (
			"先查看规则，再进入本组固定单轮演练。"
			+ "演练不发放奖励，也不保存进度。"
		)
	elif _active_context == &"current":
		handbook_hint.text = "当前牌局已暂停；关闭手册后，桌面状态保持不变。"
	else:
		handbook_hint.text = "选择左侧分类和中间规则，查看完整条件与结算时机。"


func _request_practice() -> void:
	if practice_button.disabled or _active_context == &"current":
		return
	practice_requested.emit(_active_context)
