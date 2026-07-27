class_name FinalRestrictionPanel
extends Control

signal restriction_confirmed(restriction_id: StringName)

@onready var operation_button: Button = %OperationRestrictionButton
@onready var distribution_button: Button = %DistributionRestrictionButton
@onready var confirm_button: Button = %RestrictionConfirmButton
@onready var error_label: Label = %RestrictionErrorLabel

var selected_restriction_id: StringName = &""
var _options: Dictionary = {}

func _ready() -> void:
	operation_button.pressed.connect(
		func() -> void: _select_category(
			FinalRestrictionDefinition.Category.OPERATION
		)
	)
	distribution_button.pressed.connect(
		func() -> void: _select_category(
			FinalRestrictionDefinition.Category.DISTRIBUTION
		)
	)
	confirm_button.pressed.connect(_confirm)
	close()

func open_options(options: Array[FinalRestrictionDefinition]) -> bool:
	_options.clear()
	for option in options:
		if option != null:
			_options[option.category] = option
	if (
		not _options.has(FinalRestrictionDefinition.Category.OPERATION)
		or not _options.has(FinalRestrictionDefinition.Category.DISTRIBUTION)
	):
		close()
		return false
	var operation: FinalRestrictionDefinition = _options[
		FinalRestrictionDefinition.Category.OPERATION
	]
	var distribution: FinalRestrictionDefinition = _options[
		FinalRestrictionDefinition.Category.DISTRIBUTION
	]
	operation_button.text = "%s\n%s" % [
		operation.display_name,
		operation.rule_text,
	]
	distribution_button.text = "%s\n%s" % [
		distribution.display_name,
		distribution.rule_text,
	]
	selected_restriction_id = &""
	operation_button.button_pressed = false
	distribution_button.button_pressed = false
	confirm_button.disabled = true
	error_label.text = ""
	visible = true
	operation_button.grab_focus()
	SfxAccess.play(self, &"panel_open")
	return true

func close() -> void:
	visible = false
	selected_restriction_id = &""
	if is_node_ready():
		confirm_button.disabled = true
		error_label.text = ""

func show_error(message: String) -> void:
	error_label.text = message
	SfxAccess.play(self, &"error")

func _select_category(category: FinalRestrictionDefinition.Category) -> void:
	var option: FinalRestrictionDefinition = _options.get(category)
	if option == null:
		show_error("这个限制候选不可用")
		return
	selected_restriction_id = option.id
	operation_button.button_pressed = (
		category == FinalRestrictionDefinition.Category.OPERATION
	)
	distribution_button.button_pressed = (
		category == FinalRestrictionDefinition.Category.DISTRIBUTION
	)
	confirm_button.disabled = false
	error_label.text = ""
	SfxAccess.play(self, &"route_select")

func _confirm() -> void:
	if selected_restriction_id == &"":
		show_error("请先选择一项最终限制")
		return
	restriction_confirmed.emit(selected_restriction_id)
