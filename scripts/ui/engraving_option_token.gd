class_name EngravingOptionToken
extends Button

const ICON_ROOT := "res://resources/ui/dream_glass/icons/engravings/"

signal engraving_selected(engraving_id: StringName)

var engraving_id: StringName

func _ready() -> void:
	pressed.connect(func() -> void: engraving_selected.emit(engraving_id))

func bind_engraving(definition: EngravingDefinition, selected: bool) -> void:
	engraving_id = definition.id
	button_pressed = selected
	text = ""
	%EngravingIcon.texture = load(_icon_path(definition.operation))
	tooltip_text = "%s｜%s｜%s" % [
		definition.display_name,
		" · ".join(definition.tags),
		definition.rule_text,
	]
	set_meta("display_name", definition.display_name)
	set_meta("rule_text", definition.rule_text)


func _icon_path(operation: EngravingDefinition.Operation) -> String:
	var icon_name := "prism.svg"
	if operation in [
		EngravingDefinition.Operation.ECHO_ADJACENT,
		EngravingDefinition.Operation.ECHO_LOWER_ADJACENT,
	]:
		icon_name = "echo.svg"
	elif operation in [
		EngravingDefinition.Operation.ANCHOR_DIE,
		EngravingDefinition.Operation.ANCHOR_LAST_TABLE,
	]:
		icon_name = "anchor.svg"
	elif operation in [
		EngravingDefinition.Operation.BRIDGE_FORWARD,
		EngravingDefinition.Operation.BRIDGE_BACKWARD,
		EngravingDefinition.Operation.BRIDGE_BIDIRECTIONAL,
	]:
		icon_name = "bridge.svg"
	return "%s%s" % [ICON_ROOT, icon_name]
