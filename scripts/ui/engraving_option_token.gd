class_name EngravingOptionToken
extends Button

signal engraving_selected(engraving_id: StringName)

var engraving_id: StringName

func _ready() -> void:
	pressed.connect(func() -> void: engraving_selected.emit(engraving_id))

func bind_engraving(definition: EngravingDefinition, selected: bool) -> void:
	engraving_id = definition.id
	button_pressed = selected
	text = "%s\n%s\n%s" % [
		definition.display_name,
		" · ".join(definition.tags),
		definition.rule_text,
	]
	tooltip_text = definition.rule_text
